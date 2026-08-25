"""Experiment 1a: tap-noise Monte Carlo over calibration schemes.

For each clip's reference calibration (treated as ground truth), simulate
thousands of imperfect user calibrations under several UI schemes, then
measure entry-board error at 60 ft. The scheme that degrades least under
realistic tap noise wins the iOS calibration screen design.

Schemes (tap targets -> homography):
  corners4      today's flow: 4 gutter corners, exact 4-point homography
  corners4_bias corners4 + the wrong-edge failure mode measured Aug 21:
                deck/gutter corners sometimes snap to a plausible-looking
                specular edge several px outside the true lane
  landmarks6    foul corners + outer arrows + center arrow + headpin,
                least-squares
  landmarks16   landmarks6 + all 10 guide dots (CV-snapped after rough
                taps, so tighter sigma), least-squares
  corners_ref   corners4 with sigma shrunk to overlay-refined precision
                (simulates drag-the-overlay fine-tuning)

Tap noise sigmas (px, isotropic Gaussian):
  foul gutter corners 5, deck gutter corners 10 (tiny + ambiguous),
  arrows 3, headpin 5, CV-snapped dots 1.5, overlay-refined corners 2.5.
The bias variant adds a 35% chance per deck corner of +14 px outward
(the flat-gutter/capping misread), and 20% per foul corner of 10 px.

Error metric: |mapped - true| entry board for true entries at boards
8, 12, 17.5, 22, 30 (60 ft). Reported per scheme: median and p90 over
trials x entry points x clips.

Usage: python3 monte_carlo.py [trials]
"""
import glob
import json
import sys

import cv2
import numpy as np

rng = np.random.default_rng(20260825)

SIG_FOUL, SIG_DECK, SIG_ARROW, SIG_PIN, SIG_DOT, SIG_REFINED = 5.0, 10.0, 3.0, 5.0, 1.5, 2.5
DOT_BOARDS = [37, 35, 32, 29, 26, 14, 11, 8, 5, 3]
ENTRY_BOARDS = [8.0, 12.0, 17.5, 22.0, 30.0]


def board_x(b):
    return (b - 0.5) / 39.0


def lane_pts_for(ref):
    """Ground-truth image positions of every tap target, via the reference."""
    Hi = np.linalg.inv(np.array(ref["H_undistorted_to_lane"]))
    fitted = ref["fitted"]

    def img(pts):
        return cv2.perspectiveTransform(np.asarray(pts, np.float64).reshape(-1, 1, 2), Hi).reshape(-1, 2)

    t_a, st = fitted["arrow_apex_ft"], fitted["arrow_step_ft"]
    return {
        "corners": img([(0, 0), (1, 0), (1, 60), (0, 60)]),          # foulR, foulL, deckL, deckR
        "arrows_out": img([(board_x(35), t_a - 3 * st), (board_x(5), t_a - 3 * st)]),
        "arrow_mid": img([(board_x(20), t_a)]),
        "headpin": img([(board_x(20), 60.0)]),
        "dots": img([(board_x(b), fitted["dot_row_ft"]) for b in DOT_BOARDS]),
        "entries": img([(board_x(b), 60.0) for b in ENTRY_BOARDS]),
        "lane_arrows": [(board_x(35), t_a - 3 * st), (board_x(5), t_a - 3 * st)],
        "lane_arrow_mid": [(board_x(20), t_a)],
        "lane_dots": [(board_x(b), fitted["dot_row_ft"]) for b in DOT_BOARDS],
    }


def noisy(pts, sigma):
    return pts + rng.normal(0, sigma, pts.shape)


def fit_ls(src, dst):
    H, _ = cv2.findHomography(np.asarray(src, np.float32), np.asarray(dst, np.float32), 0)
    return H


def entry_errors(H, entries_img):
    m = cv2.perspectiveTransform(entries_img.reshape(-1, 1, 2).astype(np.float64), H.astype(np.float64)).reshape(-1, 2)
    return np.abs(m[:, 0] * 39.0 - np.array(ENTRY_BOARDS) + 0.5)


def simulate(ref, trials):
    P = lane_pts_for(ref)
    corners_lane = np.array([(0, 0), (1, 0), (1, 60), (0, 60)], np.float64)
    out = {k: [] for k in ["corners4", "corners4_bias", "landmarks6", "landmarks16", "corners_ref"]}
    for _ in range(trials):
        # corners4
        c = np.vstack([noisy(P["corners"][:2], SIG_FOUL), noisy(P["corners"][2:], SIG_DECK)])
        out["corners4"].append(entry_errors(fit_ls(c, corners_lane), P["entries"]))
        # corners4 with wrong-edge bias (outward = away from lane centre, x-direction)
        c = np.vstack([noisy(P["corners"][:2], SIG_FOUL), noisy(P["corners"][2:], SIG_DECK)])
        centre_x = P["corners"][:, 0].mean()
        for i, mag, pr in [(0, 10, .2), (1, 10, .2), (2, 14, .35), (3, 14, .35)]:
            if rng.random() < pr:
                c[i, 0] += np.sign(c[i, 0] - centre_x) * mag
        out["corners4_bias"].append(entry_errors(fit_ls(c, corners_lane), P["entries"]))
        # landmarks6: foul corners + 2 outer arrows + centre arrow + headpin
        src = np.vstack([noisy(P["corners"][:2], SIG_FOUL), noisy(P["arrows_out"], SIG_ARROW),
                         noisy(P["arrow_mid"], SIG_ARROW), noisy(P["headpin"], SIG_PIN)])
        dst = np.vstack([corners_lane[:2], P["lane_arrows"], P["lane_arrow_mid"], [(board_x(20), 60.0)]])
        out["landmarks6"].append(entry_errors(fit_ls(src, dst), P["entries"]))
        # landmarks16: + all dots at CV precision
        src = np.vstack([src, noisy(P["dots"], SIG_DOT)])
        dst = np.vstack([dst, P["lane_dots"]])
        out["landmarks16"].append(entry_errors(fit_ls(src, dst), P["entries"]))
        # overlay-refined corners
        c = noisy(P["corners"], SIG_REFINED)
        out["corners_ref"].append(entry_errors(fit_ls(c, corners_lane), P["entries"]))
    return {k: np.array(v) for k, v in out.items()}


def main():
    trials = int(sys.argv[1]) if len(sys.argv) > 1 else 2000
    allerr = {}
    for path in sorted(glob.glob("references/*_ref.json")):
        ref = json.load(open(path))
        clip = ref["clip"].split(".")[0]
        res = simulate(ref, trials)
        for k, v in res.items():
            allerr.setdefault(k, []).append(v)
        line = "  ".join(f"{k} med {np.median(v):.2f} p90 {np.quantile(v, .9):.2f}" for k, v in res.items())
        print(f"{clip}: {line}")
    print(f"\n=== pooled over all clips ({trials} trials each) — entry-board error in boards ===")
    for k, v in allerr.items():
        v = np.concatenate([a.ravel() for a in v])
        print(f"  {k:14s} median {np.median(v):5.2f}   p90 {np.quantile(v, .9):5.2f}   p99 {np.quantile(v, .99):5.2f}")


if __name__ == "__main__":
    main()
