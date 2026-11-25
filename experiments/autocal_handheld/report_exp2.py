#!/usr/bin/env python3
"""Markdown tables from out/exp2_*.json and out/exp2_detector.json.

    .venv/bin/python experiments/autocal_handheld/report_exp2.py moderate mild_strong
"""
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C  # noqa: E402

f = C.fmt


def load(tag):
    return json.loads((C.OUT / f"exp2_{tag}.json").read_text())


def drift_table(res):
    print("\n#### Real motion in the tripod clips (keyframe KLT on the untouched footage)\n")
    print("| Clip | corner px max | during throw | at last frame | pins board max | entry fixed / drift-corrected | speed fixed / corrected |")
    print("|---|---|---|---|---|---|---|")
    for cid, r in res.items():
        d = r["tripod_drift"]
        mf, md = d["metrics_fixed"], d["metrics_drift_corrected"]
        print(f"| {cid} | {f(d['corner_px_max'])} | {f(d['corner_px_throw_max'])} | {f(d['corner_px_last'])} "
              f"| {f(d['pins_board_max'], 2)} | {f(mf['entry'], 2)} / {f(md['entry'], 2)} "
              f"| {f(mf['speed'], 2)} / {f(md['speed'], 2)} |")


def combo_table(res, level):
    combos = [k for k in next(iter(res.values()))[level] if "/" in k]
    print(f"\n#### {level}: registration error over all frames (median over clips of each clip's median / p95)\n")
    print("| Method / mask | corner px med / p95 | arrows bd med / p95 | pins bd med / p95 | pins bd max in throw (worst clip) | ball board err med / max | lost frames | ms/frame (half res) |")
    print("|---|---|---|---|---|---|---|---|")
    for k in combos:
        rows = [r[level][k] for r in res.values()]
        g = lambda key: np.median([x[key] for x in rows])  # noqa: E731
        print(f"| {k} | {g('corner_px_median'):.1f} / {g('corner_px_p95'):.1f} "
              f"| {g('arrows_board_median'):.2f} / {g('arrows_board_p95'):.2f} "
              f"| {g('pins_board_median'):.2f} / {g('pins_board_p95'):.2f} "
              f"| {max(x['pins_board_throw_max'] for x in rows):.2f} "
              f"| {g('ball_board_median'):.2f} / {max(x['ball_board_max'] for x in rows):.2f} "
              f"| {sum(x['lost_frames'] for x in rows)} | {g('ms_per_frame'):.0f} |")
    print(f"\n#### {level}: metric error vs the true per-frame calibration (mean abs over clips / worst clip)\n")
    print("| Method / mask | entry board | entry angle deg | launch speed mph | arrows board | clips scored |")
    print("|---|---|---|---|---|---|")
    for k in combos:
        cells = []
        n = 0
        for key in ("entry", "entry_angle", "speed", "arrows"):
            e = []
            miss = 0
            for r in res.values():
                mt, me = r[level][k]["metrics_true"], r[level][k]["metrics_est"]
                if mt[key] is None:
                    continue
                if me[key] is None:
                    miss += 1
                    continue
                e.append(abs(me[key] - mt[key]))
            n = max(n, len(e))
            cells.append(("--" if not e else f"{np.mean(e):.2f} / {np.max(e):.2f}") + (f" ({miss} lost)" if miss else ""))
        print(f"| {k} | " + " | ".join(cells) + f" | {n} |")


def per_clip(res, level, combo):
    print(f"\n#### {level}, {combo}: per clip\n")
    print("| Clip | max rotation deg | corner px p95 | pins bd p95 | entry est / true | angle est / true | speed est / true |")
    print("|---|---|---|---|---|---|---|")
    for cid, r in res.items():
        x = r[level][combo]
        me, mt = x["metrics_est"], x["metrics_true"]
        print(f"| {cid} | {r[level]['max_rot_deg']:.1f} | {x['corner_px_p95']:.1f} | {x['pins_board_p95']:.2f} "
              f"| {f(me['entry'], 2)} / {f(mt['entry'], 2)} | {f(me['entry_angle'], 2)} / {f(mt['entry_angle'], 2)} "
              f"| {f(me['speed'], 2)} / {f(mt['speed'], 2)} |")


def detector_table():
    p = C.OUT / "exp2_detector.json"
    if not p.exists():
        return
    d = json.loads(p.read_text())
    print("\n#### Detector on rendered handheld video (app ShotAnalyzer + Core ML, frame-0 corners)\n")
    print("| Clip / variant | tracked (measured) | raw boxes | lane rej | labels detected / within r | det px med | entry from boxes | speed from boxes | app entry / speed |")
    print("|---|---|---|---|---|---|---|---|---|")
    for k, r in d.items():
        bm = r["box_metrics"] or {}
        print(f"| {k.replace('|', ' / ')} | {r['tracked']} ({r['measured']}) | {r['raw_boxes']} | {r['outside_lane']} "
              f"| {r['label_det']}/{r['labels']} ({r['label_hits']}) | {f(r['det_err_px_median'])} "
              f"| {f(bm.get('entry'), 2)} | {f(bm.get('speed'), 2)} | {f(r['app_entry'])} / {f(r['app_speed'])} |")


if __name__ == "__main__":
    tags = sys.argv[1:] or ["moderate"]
    first = True
    for tag in tags:
        res = load(tag)
        if first:
            drift_table(res)
            first = False
        levels = [k for k in next(iter(res.values())) if k != "tripod_drift"]
        for level in levels:
            combo_table(res, level)
            per_clip(res, level, "klt_key/lane" if "klt_key/lane" in next(iter(res.values()))[level] else "klt_key/none")
    detector_table()
