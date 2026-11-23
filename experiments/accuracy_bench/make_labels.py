#!/usr/bin/env python3
"""Turn label_sheets.py edge-fit proposals into labels.json.

    python3 experiments/accuracy_bench/make_labels.py <run tag> <sheets dir> [--reject CLIP:FRAME ...]

A proposal becomes a label when it passes the automatic checks below AND was
not rejected by eye on the overlay sheet (rejections are listed in
labels.json -> rejected, with the reason). The automatic checks:
  - at least 44 of 64 rays agree on the circle (edge not mostly occluded),
  - circle rms <= 0.08 r + 0.6 px,
  - radius within 25% of the ball's expected radius at that depth, from the
    lane calibration's local scale (8.6 in ball on a 41.5 in lane). This is
    the one place the calibration enters the labels; it only gates, it never
    moves a label.
"""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bench  # noqa: E402

BALL_IN = 8.595


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tag"); ap.add_argument("sheets")
    ap.add_argument("--reject", nargs="*", default=[], help="CLIP:FRAME:reason")
    a = ap.parse_args()
    man = bench.manifest_by_id(a.tag)
    rejected_by_eye = {}
    for r in a.reject:
        cid, fr, *why = r.split(":")
        rejected_by_eye[(cid, int(fr))] = why[0] if why else "rejected by eye"
    out = {"method": __doc__, "clips": {}, "rejected": []}
    for meta_path in sorted(Path(a.sheets).glob("*_meta.json")):
        cid = meta_path.name[:-len("_meta.json")].split("@")[0]
        if cid not in man:
            continue
        lane = bench.Lane(man[cid])
        frames = out["clips"].setdefault(cid, {"frames": []})["frames"]
        seen = {f["frame"] for f in frames} | {r["frame"] for r in out["rejected"] if r["clip"] == cid}
        for m in json.loads(meta_path.read_text()):
            if m["frame"] in seen:
                continue
            fit = m.get("fit")
            key = (cid, m["frame"])
            if fit is None:
                out["rejected"].append({"clip": cid, "frame": m["frame"], "why": "no fit"}); continue
            x, y, r, rms, kept = fit
            _, feet = lane.board_feet(x, y + r)
            lane_px = lane.px_per_board(max(min(feet, 60), 0)) * 39
            r_exp = 0.5 * BALL_IN / 41.5 * lane_px
            why = None
            if kept < 44:
                why = f"only {kept}/64 rays"
            elif rms > 0.08 * r + 0.6:
                why = f"rms {rms:.2f} px"
            elif abs(r - r_exp) > 0.25 * r_exp:
                why = f"radius {r:.1f} vs expected {r_exp:.1f}"
            elif key in rejected_by_eye:
                why = "by eye: " + rejected_by_eye[key]
            if why:
                out["rejected"].append({"clip": cid, "frame": m["frame"], "why": why}); continue
            frames.append({"frame": m["frame"], "x": round(x, 2), "y": round(y, 2), "r": round(r, 2),
                           "rms": rms, "rays": kept, "r_expected": round(r_exp, 2)})
        frames.sort(key=lambda f: f["frame"])
    bench.LABELS.write_text(json.dumps(out, indent=1))
    n = sum(len(c["frames"]) for c in out["clips"].values())
    print(f"{n} labels, {len(out['rejected'])} rejected")
    for r in out["rejected"]:
        print("  reject", r)


if __name__ == "__main__":
    main()
