"""Measure radial lens distortion from world-straight lines in a frame.

Samples high-contrast boundaries that are physically straight (lane/gutter
edges, the foul line), then fits a single-parameter division-model radial
distortion (center = image center) that makes them maximally collinear:

    undistort: p_u = c + (p_d - c) / (1 + k * r^2),  r = |p_d - c| / f_norm

Reports per-line bow (max deviation from the chord, px) before and after,
and the fitted k. Line specs are per-clip since camera placement moves.

Usage: python3 plumbline.py frames/IMG_5108_f0.png
(line specs for the clip are defined in LINES at the bottom)
"""
import sys

import cv2
import numpy as np
from scipy.optimize import minimize_scalar


def sample_vertical_edge(gray, y0, y1, x_at, half=25, step=8, mode="dark2light"):
    """For each y, subpixel x of the strongest edge near x_at(y). mode: sign of gradient."""
    pts = []
    g = cv2.GaussianBlur(gray, (5, 5), 0).astype(np.float64)
    for y in range(y0, y1, step):
        xc = int(round(x_at(y)))
        lo, hi = max(1, xc - half), min(gray.shape[1] - 2, xc + half)
        row = g[y, lo:hi]
        grad = np.gradient(row)
        if mode == "dark2light":
            i = int(np.argmax(grad))
            ok = grad[i] > 4
        else:
            i = int(np.argmin(grad))
            ok = grad[i] < -4
        if not ok or i in (0, len(grad) - 1):
            continue
        # parabolic subpixel refinement
        a, b, c = grad[i - 1], grad[i], grad[i + 1]
        denom = a - 2 * b + c
        off = 0.5 * (a - c) / denom if abs(denom) > 1e-9 else 0.0
        pts.append((lo + i + off, float(y)))
    return np.array(pts)


def sample_horizontal_edge(gray, x0, x1, y_at, half=20, step=8, mode="light2dark"):
    """For each x, subpixel y of the strongest edge near y_at(x)."""
    pts = []
    g = cv2.GaussianBlur(gray, (5, 5), 0).astype(np.float64)
    for x in range(x0, x1, step):
        yc = int(round(y_at(x)))
        lo, hi = max(1, yc - half), min(gray.shape[0] - 2, yc + half)
        col = g[lo:hi, x]
        grad = np.gradient(col)
        if mode == "dark2light":
            i = int(np.argmax(grad))
            ok = grad[i] > 4
        else:
            i = int(np.argmin(grad))
            ok = grad[i] < -4
        if not ok or i in (0, len(grad) - 1):
            continue
        a, b, c = grad[i - 1], grad[i], grad[i + 1]
        denom = a - 2 * b + c
        off = 0.5 * (a - c) / denom if abs(denom) > 1e-9 else 0.0
        pts.append((float(x), lo + i + off))
    return np.array(pts)


def undistort(pts, k, center, f_norm):
    d = pts - center
    r2 = np.sum(d ** 2, axis=1) / f_norm ** 2
    return center + d / (1 + k * r2)[:, None]


def line_rms(pts):
    """RMS distance of points to their best-fit line, and max |deviation|."""
    c = pts.mean(axis=0)
    q = pts - c
    _, _, Vt = np.linalg.svd(q)
    n = Vt[-1]
    d = q @ n
    return float(np.sqrt(np.mean(d ** 2))), float(np.max(np.abs(d)))


def fit_k(lines, shape):
    center = np.array([shape[1] / 2.0, shape[0] / 2.0])
    f_norm = max(shape) / 2.0

    def cost(k):
        return sum(line_rms(undistort(p, k, center, f_norm))[0] ** 2 * len(p) for p in lines)

    res = minimize_scalar(cost, bounds=(-0.3, 0.3), method="bounded",
                          options={"xatol": 1e-6})
    return float(res.x), center, f_norm


def main():
    frame_path = sys.argv[1]
    gray = cv2.imread(frame_path, cv2.IMREAD_GRAYSCALE)
    lines = []
    for name, sampler in LINES:
        pts = sampler(gray)
        if len(pts) < 8:
            print(f"{name}: only {len(pts)} points, skipped")
            continue
        rms, mx = line_rms(pts)
        lines.append((name, pts, rms, mx))
    k, center, f_norm = fit_k([p for _, p, _, _ in lines], gray.shape)
    print(f"fitted k = {k:.5f} (division model, center={center}, f_norm={f_norm})")
    for name, pts, rms, mx in lines:
        rms2, mx2 = line_rms(undistort(pts, k, center, f_norm))
        print(f"  {name:24s} n={len(pts):3d}  bow before rms {rms:5.2f} max {mx:5.2f}  ->  after rms {rms2:5.2f} max {mx2:5.2f}")


# --- line specs for IMG_5108 frame 0 (hand-seeded search corridors) ---
def lerp(y0, x0, y1, x1):
    return lambda y: x0 + (x1 - x0) * (y - y0) / (y1 - y0)


def lerpx(x0, y0, x1, y1):
    return lambda x: y0 + (y1 - y0) * (x - x0) / (x1 - x0)


LINES = [
    # left gutter band's right edge (dark gutter -> light lane wood)
    ("left lane edge", lambda g: sample_vertical_edge(g, 880, 1400, lerp(1442, 210, 850, 855), mode="dark2light")),
    # right gutter band's left edge (light lane wood -> dark gutter)
    ("right lane edge", lambda g: sample_vertical_edge(g, 880, 1430, lerp(1492, 845, 838, 944), mode="light2dark")),
    # foul line: light wood above -> dark line (top edge of the stripe)
    ("foul line", lambda g: sample_horizontal_edge(g, 210, 700, lerpx(199, 1442, 850, 1492), mode="light2dark")),
    # left neighbour lane's right edge for extra leverage further from center
    ("far-left lane edge", lambda g: sample_vertical_edge(g, 900, 1300, lerp(1442, 40, 900, 500), mode="dark2light")),
]

if __name__ == "__main__":
    main()
