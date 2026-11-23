#!/usr/bin/env python3
"""TrueLine accuracy benchmark.

    python3 experiments/accuracy_bench/bench.py run   --tag baseline   # build + run the app tracker on every clip
    python3 experiments/accuracy_bench/bench.py score --tag baseline   # score a run against labels/outcomes
    python3 experiments/accuracy_bench/bench.py compare baseline after # before/after table

`run` compiles the app's Analysis sources with main.swift (the same code the
app ships) and writes out/<tag>.json: per clip metrics, gate counts and the
per-sample trace. `score` reads labels.json (hand-labelled ball positions) and
clips.OUTCOMES (what the pins/notes say happened) and prints a markdown report.
Pure stdlib + numpy.
"""
import argparse
import json
import math
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import clips as corpus  # noqa: E402

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
OUT = HERE / "out"
LABELS = HERE / "labels.json"
BIN = Path(tempfile.gettempdir()) / "trueline_accbench"
INCHES_PER_BOARD = 41.5 / 39


# ---------------------------------------------------------------- run

def build() -> None:
    srcs = sorted(str(p) for p in (REPO / "ios/Trueline/Trueline/Analysis").glob("*.swift"))
    cmd = ["swiftc", "-O", "-o", str(BIN), str(HERE / "main.swift"), *srcs,
           str(REPO / "ios/Trueline/Trueline/Models/LaneCorners.swift")]
    subprocess.run(cmd, check=True, cwd=REPO, stderr=subprocess.DEVNULL)


def run(tag: str, only: list[str] | None, no_build: bool) -> Path:
    if not no_build:
        build()
    clips = [c for c in corpus.manifest() if not only or c["id"] in only]
    OUT.mkdir(exist_ok=True)
    man = OUT / f"{tag}.manifest.json"
    man.write_text(json.dumps(clips, indent=1))
    out = OUT / f"{tag}.json"
    model = REPO / "ios/Trueline/Trueline/ML/ball.mlpackage"
    subprocess.run([str(BIN), str(man), str(out), str(model)], check=True, cwd=REPO)
    return out


# ---------------------------------------------------------------- geometry

def homography(src, dst):
    """4-point DLT (h22 = 1), same as Homography(from:to:) in LaneGeometry.swift."""
    a, b = [], []
    for (x, y), (u, v) in zip(src, dst):
        a.append([x, y, 1, 0, 0, 0, -x * u, -y * u]); b.append(u)
        a.append([0, 0, 0, x, y, 1, -x * v, -y * v]); b.append(v)
    h = np.linalg.solve(np.array(a, float), np.array(b, float))
    return np.append(h, 1.0).reshape(3, 3)


def apply(H, x, y):
    p = H @ np.array([x, y, 1.0])
    return p[0] / p[2], p[1] / p[2]


class Lane:
    """Display-pixel <-> lane mapping from a manifest clip's corners, matching
    LaneGeometry (t 0 = right gutter, feet 0 = foul line; board = t * 39 for
    right-handers)."""

    def __init__(self, clip):
        quad = [clip["nearRight"], clip["nearLeft"], clip["farLeft"], clip["farRight"]]
        lane = [(0, 0), (1, 0), (1, 60), (0, 60)]
        self.H = homography(quad, lane)
        self.Hi = np.linalg.inv(self.H)
        self.hand = clip.get("hand", "R")

    def board_feet(self, x, y):
        t, f = apply(self.H, x, y)
        b = t * 39 if self.hand == "R" else (1 - t) * 39
        return b, f

    def image(self, board, feet):
        t = board / 39 if self.hand == "R" else 1 - board / 39
        return apply(self.Hi, t, feet)

    def px_per_board(self, feet):
        """Pixel length of one board across the lane at this depth."""
        a = np.array(self.image(19.0, feet)); b = np.array(self.image(20.0, feet))
        return float(np.linalg.norm(b - a))


def raw_to_display(x, y, orientation, raw_w, raw_h):
    """Raw buffer px -> display px (BallDetector.rawToOriented, scaled)."""
    if orientation == 6:      # .right: portrait iPhone clip
        return raw_h - y, x
    if orientation == 8:      # .left
        return y, raw_w - x
    if orientation == 3:      # .down
        return raw_w - x, raw_h - y
    return x, y


# ---------------------------------------------------------------- scoring

def load(tag):
    return {c["id"]: c for c in json.loads((OUT / f"{tag}.json").read_text())}


def manifest_by_id(tag):
    return {c["id"]: c for c in json.loads((OUT / f"{tag}.manifest.json").read_text())}


def trace_display(clip):
    """Trace samples as display-px dicts keyed by frame."""
    tr = clip.get("trace")
    if not tr:
        return {}
    w, h = clip["displayWidth"], clip["displayHeight"]
    o = tr["orientation"]
    raw_w, raw_h = (h, w) if o in (6, 8) else (w, h)
    out = {}
    for s in tr["samples"]:
        dx, dy = raw_to_display(s["x"], s["y"], o, raw_w, raw_h)
        d = None
        if s.get("detectionX") is not None:
            d = raw_to_display(s["detectionX"], s["detectionY"], o, raw_w, raw_h)
        ref = None
        if s.get("refinedX") is not None:
            ref = raw_to_display(s["refinedX"], s["refinedY"], o, raw_w, raw_h)
        out[s["frame"]] = {**s, "dx": dx, "dy": dy, "det": d, "ref": ref}
    return out


def label_errors(tag):
    """Per labelled frame: tracker position vs label, in px and boards.

    Both sides go through the same lane mapping and the same contact-point
    rule (center + radius straight down on screen, the app's rule) so this
    isolates tracking error from calibration error. The contact-point rule
    itself is scored separately (contact_rule_errors)."""
    if not LABELS.exists():
        return []
    labels = json.loads(LABELS.read_text())
    runs = load(tag)
    man = manifest_by_id(tag)
    rows = []
    for cid, lab in labels["clips"].items():
        if cid not in runs or cid not in man:
            continue
        lane = Lane(man[cid])
        tr = trace_display(runs[cid])
        fps_scale = lab.get("frame_scale", 1)
        for f in lab["frames"]:
            frame = int(round(f["frame"] * fps_scale))
            s = tr.get(frame)
            lx, ly, lr = f["x"], f["y"], f["r"]
            lb, lf = lane.board_feet(lx, ly + lr)
            ppb = lane.px_per_board(lf)
            row = {"clip": cid, "frame": frame, "label_feet": lf, "label_board": lb,
                   "px_per_board": ppb, "tracked": s is not None}
            if s is not None:
                tb, tf = lane.board_feet(s["dx"], s["dy"] + s["radius"])
                row.update({
                    "err_px": math.hypot(s["dx"] - lx, s["dy"] - ly),
                    "err_board": tb - lb, "err_feet": tf - lf,
                    "err_r": s["radius"] - lr,
                    "measured": s["det"] is not None,
                })
                if s["det"] is not None:
                    db, _ = lane.board_feet(s["det"][0], s["det"][1] + s["detectionRadius"])
                    row["det_err_px"] = math.hypot(s["det"][0] - lx, s["det"][1] - ly)
                    row["det_err_board"] = db - lb
                if s.get("ref") is not None:
                    rb, _ = lane.board_feet(s["ref"][0], s["ref"][1] + s["detectionRadius"])
                    row["ref_err_px"] = math.hypot(s["ref"][0] - lx, s["ref"][1] - ly)
                    row["ref_err_board"] = rb - lb
            rows.append(row)
    return rows


def arrow_feet(board_position):
    """LaneModel.arrowFeet(atBoardPosition:)."""
    return 15.0 - abs(board_position + 0.5 - 20.0) / 5.0 * 0.5


def label_metrics(tag):
    """Metric values computed from the hand labels alone (same calibration
    and contact rule as the app, no tracker, no smoothing):
      arrows: board where the labelled path crosses the arrow V, linear
              interpolation between the two labels bracketing it;
      entry:  least-squares quadratic through labels at >= 45 ft (>= 6
              labels, last >= 55 ft, spanning >= 8 ft), evaluated at 59.5 ft;
              entry_angle is that quadratic's slope at 59.5 ft;
      speed:  least-squares feet-vs-time slope over labels from release to
              20 ft (>= 5 labels spanning >= 8 ft), in mph.
    Returns {clip: {arrows, entry, speed}} with None where the labels don't
    cover the zone."""
    if not LABELS.exists():
        return {}
    labels = json.loads(LABELS.read_text())
    man = manifest_by_id(tag)
    runs = load(tag)
    out = {}
    for cid, lab in labels["clips"].items():
        if cid not in man or cid not in runs or not runs[cid].get("trace"):
            continue
        lane = Lane(man[cid])
        fps = runs[cid]["trace"]["fps"]
        pts = []
        for f in lab["frames"]:
            b, ft = lane.board_feet(f["x"], f["y"] + f["r"])
            pts.append((f["frame"] / fps, b, ft))
        pts.sort(key=lambda p: p[0])
        m = {"arrows": None, "entry": None, "entry_angle": None, "speed": None}
        for (t0, b0, f0), (t1, b1, f1) in zip(pts, pts[1:]):
            g0, g1 = f0 - arrow_feet(b0), f1 - arrow_feet(b1)
            if g0 < 0 <= g1 and f1 - f0 < 4:
                u = g0 / (g0 - g1)
                m["arrows"] = b0 + u * (b1 - b0)
                break
        tail = [(b, ft) for _, b, ft in pts if ft >= 45]
        if len(tail) >= 6 and tail[-1][1] >= 55 and tail[-1][1] - tail[0][1] >= 8:
            bb, ff = np.array(tail).T
            q = np.polyfit(ff, bb, 2)
            m["entry"] = float(np.polyval(q, 59.5))
            slope = 2 * q[0] * 59.5 + q[1]   # boards per foot at 59.5 ft
            m["entry_angle"] = math.degrees(math.atan(slope * INCHES_PER_BOARD / 12))
        head = [(t, ft) for t, _, ft in pts if ft <= 20]
        if len(head) >= 5 and head[-1][1] - head[0][1] >= 8:
            tt, ff = np.array(head).T
            m["speed"] = np.polyfit(tt, ff, 1)[0] * 0.681818
        out[cid] = m
    return out


# Session truth field -> app result field (see clips.session_clips).
TRUTH_FIELDS = [("arrow_board", "arrowBoard", "boards"), ("entry_board", "entryBoard", "boards"),
                ("entry_angle", "entryAngleDegrees", "deg"), ("launch_speed_mph", "speedMph", "mph"),
                ("foul_line_board", "foulLineBoard", "boards"), ("shot_time_s", "shotTimeSeconds", "s")]


def truth_table(tag, runs):
    """App vs measured truth for session clips (taped boards, 240 fps
    timing, telephoto pin-deck reads). Empty until a session file exists."""
    man = manifest_by_id(tag)
    rows = [(cid, man[cid]["truth"]) for cid in runs if man.get(cid, {}).get("truth")]
    if not rows:
        return []
    lines = ["", "App vs measured truth (alley session):", "",
             "| Clip | " + " | ".join(f"{t} app / truth" for t, _, _ in TRUTH_FIELDS) + " |",
             "|---|" + "---|" * len(TRUTH_FIELDS)]
    errs = {t: [] for t, _, _ in TRUTH_FIELDS}
    for cid, truth in rows:
        cells = []
        for t, k, _ in TRUTH_FIELDS:
            a, b = runs[cid].get(k), truth.get(t)
            cells.append(f"{fmt(a)} / {fmt(b)}")
            if a is not None and b is not None:
                errs[t].append(a - b)
        lines.append(f"| {cid} | " + " | ".join(cells) + " |")
    for t, _, unit in TRUTH_FIELDS:
        if errs[t]:
            e = np.array(errs[t])
            lines.append(f"\n{t}: n {len(e)}, mean signed {e.mean():+.2f} {unit}, mean |err| {np.abs(e).mean():.2f}, "
                         f"p90 |err| {np.percentile(np.abs(e), 90):.2f}")
    return lines


def zone(feet):
    if feet < 10:
        return "0-10 ft"
    if feet < 20:
        return "10-20 ft (arrows)"
    if feet < 40:
        return "20-40 ft"
    if feet < 50:
        return "40-50 ft"
    return "50-60 ft (pins)"


def fmt(v, nd=1):
    return "--" if v is None else f"{v:.{nd}f}"


def score(tag, quiet=False):
    runs = load(tag)
    lines = [f"### Run `{tag}`", "",
             "| Clip | Tracked fr (meas/coast) | Depth ft | Raw boxes | Lane rej | Low-conf rej | Assoc rej | Speed | Arrows | Breakpt | Entry bd | Entry ° | Outcome check |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    summary = {}
    for cid, c in runs.items():
        tr = c.get("trace") or {}
        samples = tr.get("samples", [])
        depth = (samples[0]["feet"], samples[-1]["feet"]) if samples else (None, None)
        oc = corpus.OUTCOMES.get(cid, {})
        check = ""
        if oc.get("entry_range") and c.get("entryBoard") is not None:
            lo, hi = oc["entry_range"]
            check = "ok" if lo <= c["entryBoard"] <= hi else f"OUT of {lo}-{hi}"
        if oc.get("gutter"):
            leaves = [s for s in samples if s["board"] <= 0.5]
            check = f"gutter seen at {leaves[0]['feet']:.0f} ft" if leaves else "gutter NOT seen"
        summary[cid] = {"entry": c.get("entryBoard"), "arrows": c.get("arrowBoard"),
                        "depth": depth[1], "tracked": c["trackedFrames"]}
        lines.append(
            f"| {cid} | {c['trackedFrames']} ({tr.get('measured', 0)}/{tr.get('coasted', 0)}) "
            f"| {fmt(depth[0])}-{fmt(depth[1])} | {tr.get('rawBoxes', '--')} | {tr.get('outsideLane', '--')} "
            f"| {tr.get('lowConfNear', '--')} | {tr.get('associationRejects', '--')} "
            f"| {fmt(c.get('speedMph'))} | {fmt(c.get('arrowBoard'))} | {fmt(c.get('breakpointBoard'))} "
            f"| {fmt(c.get('entryBoard'))} | {fmt(c.get('entryAngleDegrees'))} | {check or oc.get('note', '')} |")
    rows = label_errors(tag)
    if rows:
        lines += ["", "Per-frame position vs hand labels, three positions the pipeline holds for each "
                  "frame: the Kalman state (what the tracker and the video trail use), the refined "
                  "measurement fed to it, and the raw detector box (what metrics use since Nov 15). "
                  "Same lane mapping and contact rule (centre + own radius, straight down on screen) "
                  "on both sides. px = centre distance; boards = |board difference| at the contact point.", "",
                  "| Zone | Labels | Kalman px | Kalman board (p90) | Refined px | Refined board | Box px | Box board (p90) |",
                  "|---|---|---|---|---|---|---|---|"]

        def med(v, nd=2):
            return fmt(float(np.median(np.abs(v))) if len(v) else None, nd)

        def p90(v):
            return fmt(float(np.percentile(np.abs(v), 90)) if len(v) else None, 2)
        for z in ["0-10 ft", "10-20 ft (arrows)", "20-40 ft", "40-50 ft", "50-60 ft (pins)", "all"]:
            zr = [r for r in rows if (z == "all" or zone(r["label_feet"]) == z) and r["tracked"]]
            if not zr:
                continue
            m = [r for r in zr if "det_err_board" in r]
            k = lambda key, src: np.array([r[key] for r in src if key in r])  # noqa: E731
            lines.append(
                f"| {z} | {len(zr)} | {med(k('err_px', zr), 1)} | {med(k('err_board', zr))} ({p90(k('err_board', zr))}) "
                f"| {med(k('ref_err_px', m), 1)} | {med(k('ref_err_board', m))} "
                f"| {med(k('det_err_px', m), 1)} | {med(k('det_err_board', m))} ({p90(k('det_err_board', m))}) |")
        per = {}
        for r in rows:
            per.setdefault(r["clip"], []).append(r)
        lines += ["", "| Clip | Labels | Kalman board, all / 50+ ft | Box board, all / 50+ ft | Box signed mean 50+ ft |",
                  "|---|---|---|---|---|"]
        for cid, rr in per.items():
            t = [r for r in rr if r["tracked"]]
            kal = np.array([r["err_board"] for r in t])
            kal_far = np.array([r["err_board"] for r in t if r["label_feet"] >= 50])
            box = np.array([r["det_err_board"] for r in t if "det_err_board" in r])
            box_far = np.array([r["det_err_board"] for r in t if "det_err_board" in r and r["label_feet"] >= 50])
            lines.append(f"| {cid} | {len(rr)} | {med(kal)} / {med(kal_far)} | {med(box)} / {med(box_far)} "
                         f"| {fmt(float(box_far.mean()) if len(box_far) else None, 2)} |")
    lm = label_metrics(tag)
    if lm:
        lines += ["", "App metrics vs the same metric computed from the labels (app minus labels):", "",
                  "| Clip | Arrows app / labels | Entry app / labels | Entry angle app / labels | Launch speed app / labels |",
                  "|---|---|---|---|---|"]
        for cid, m in lm.items():
            c = runs[cid]

            def pair(a, b, nd=1):
                if a is None or b is None:
                    return f"{fmt(a, nd)} / {fmt(b, nd)}"
                return f"{fmt(a, nd)} / {fmt(b, nd)} ({a - b:+.{nd}f})"
            lines.append(f"| {cid} | {pair(c.get('arrowBoard'), m['arrows'])} | {pair(c.get('entryBoard'), m['entry'])} "
                         f"| {pair(c.get('entryAngleDegrees'), m['entry_angle'])} "
                         f"| {pair(c.get('speedMph'), m['speed'])} |")
            summary[cid]["label"] = m
        for key, app_key, unit in (("arrows", "arrowBoard", "boards"), ("entry", "entryBoard", "boards"),
                                   ("entry_angle", "entryAngleDegrees", "deg"), ("speed", "speedMph", "mph")):
            errs = [runs[c].get(app_key) - m[key] for c, m in lm.items()
                    if m[key] is not None and runs[c].get(app_key) is not None]
            if errs:
                lines.append(f"\n{key}: mean |app - labels| {np.mean(np.abs(errs)):.2f} {unit}, "
                             f"max {np.max(np.abs(errs)):.2f} over {len(errs)} clips")
    lines += truth_table(tag, runs)
    text = "\n".join(lines)
    if not quiet:
        print(text)
    return summary, rows, text


def compare(a, b):
    """Before/after: every metric per clip, then error against the labels."""
    ra, rb = load(a), load(b)
    lm = label_metrics(b)
    keys = [("trackedFrames", "Tracked", 0), ("speedMph", "Speed", 1), ("arrowBoard", "Arrows", 1),
            ("breakpointBoard", "Breakpt", 1), ("entryBoard", "Entry bd", 1), ("entryAngleDegrees", "Entry °", 1)]
    print("| Clip | " + " | ".join(f"{label} (labels)" if label in ("Speed", "Arrows", "Entry bd", "Entry °")
                                   else label for _, label, _ in keys) + " |")
    print("|---|" + "---|" * len(keys))
    lk = {"speedMph": "speed", "arrowBoard": "arrows", "entryBoard": "entry", "entryAngleDegrees": "entry_angle"}
    for cid in ra:
        cells = []
        for k, _, nd in keys:
            x, y = ra[cid].get(k), rb.get(cid, {}).get(k)
            cell = f"{fmt(x, nd)} → {fmt(y, nd)}" if nd else f"{x} → {y}"
            if k in lk and lm.get(cid, {}).get(lk[k]) is not None:
                cell += f" ({fmt(lm[cid][lk[k]], nd)})"
            cells.append(cell)
        print(f"| {cid} | " + " | ".join(cells) + " |")
    print()
    print("| Metric vs labels | " + f"{a} mean / max | {b} mean / max | clips |")
    print("|---|---|---|---|")
    for app_key, key, unit in (("arrowBoard", "arrows", "boards"), ("entryBoard", "entry", "boards"),
                               ("entryAngleDegrees", "entry_angle", "deg"), ("speedMph", "speed", "mph")):
        cols = []
        n = 0
        for runs in (ra, rb):
            errs = [abs(runs[c][app_key] - m[key]) for c, m in lm.items()
                    if m.get(key) is not None and runs.get(c, {}).get(app_key) is not None]
            n = max(n, len(errs))
            cols.append(f"{np.mean(errs):.2f} / {np.max(errs):.2f}" if errs else "--")
        print(f"| {key} ({unit}) | {cols[0]} | {cols[1]} | {n} |")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["run", "score", "compare"])
    ap.add_argument("tags", nargs="*")
    ap.add_argument("--tag", default="current")
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--no-build", action="store_true")
    a = ap.parse_args()
    if a.cmd == "run":
        run(a.tag, a.only, a.no_build)
        score(a.tag)
    elif a.cmd == "score":
        score(a.tag)
    else:
        compare(*a.tags)


if __name__ == "__main__":
    main()
