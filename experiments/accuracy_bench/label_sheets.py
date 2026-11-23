#!/usr/bin/env python3
"""Make zoomed labelling sheets for hand-placing ball edges.

    python3 experiments/accuracy_bench/label_sheets.py <run tag> <clip id> <out dir> [--feet 3 6 10 ...]

For each requested depth it picks the traced frame nearest that depth, crops
a square around the tracker's position (wide enough that a tracker error of a
ball diameter still leaves the ball in view), upsamples it with nearest
neighbour, and draws a pixel grid with absolute display-pixel tick labels. The
tracker's own estimate is NOT drawn, so the labeller reads the ball's left,
right, top and bottom edges off the grid without an anchor. Six crops per sheet.
Frame numbers are the app's (1-based decode count); OpenCV index = frame - 1.
"""
import argparse
import json
import sys
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bench  # noqa: E402

CELL = 420


def crop_tile(img, cx, cy, half, frame, feet, fit=None):
    h, w = img.shape[:2]
    x0 = int(round(cx - half)); y0 = int(round(cy - half))
    size = 2 * half
    tile = np.zeros((size, size, 3), np.uint8)
    sx0, sy0 = max(x0, 0), max(y0, 0)
    sx1, sy1 = min(x0 + size, w), min(y0 + size, h)
    tile[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0] = img[sy0:sy1, sx0:sx1]
    scale = CELL / size
    big = cv2.resize(tile, (CELL, CELL), interpolation=cv2.INTER_NEAREST)
    step = 1 if size <= 48 else 2 if size <= 100 else 5
    major = 10 if size <= 100 else 20
    for k in range(size + 1):
        ax = x0 + k
        ay = y0 + k
        p = int(round(k * scale))
        if ax % major == 0:
            cv2.line(big, (p, 0), (p, CELL), (0, 255, 255), 1)
            cv2.putText(big, str(ax), (p + 2, 12), cv2.FONT_HERSHEY_PLAIN, 0.8, (0, 255, 255), 1)
        elif ax % step == 0 and size <= 100:
            cv2.line(big, (p, 0), (p, 6), (0, 200, 255), 1)
            cv2.line(big, (p, CELL - 6), (p, CELL), (0, 200, 255), 1)
        if ay % major == 0:
            cv2.line(big, (0, p), (CELL, p), (0, 255, 255), 1)
            cv2.putText(big, str(ay), (2, p - 2), cv2.FONT_HERSHEY_PLAIN, 0.8, (0, 255, 255), 1)
        elif ay % step == 0 and size <= 100:
            cv2.line(big, (0, p), (6, p), (0, 200, 255), 1)
            cv2.line(big, (CELL - 6, p), (CELL, p), (0, 200, 255), 1)
    if fit is not None:
        c = (int(round((fit[0] - x0) * scale)), int(round((fit[1] - y0) * scale)))
        cv2.circle(big, c, int(round(fit[2] * scale)), (0, 0, 255), 1)
        cv2.drawMarker(big, c, (0, 0, 255), cv2.MARKER_CROSS, 8, 1)
    cv2.putText(big, f"f{frame} ~{feet:.0f}ft", (4, CELL - 8), cv2.FONT_HERSHEY_PLAIN, 1.1, (255, 0, 255), 1)
    return big


def fit_ball(img, cx, cy, half):
    """Silhouette fit used as the labelling PROPOSAL (a human accepts, edits
    or rejects each one on the overlay sheet). Independent of the app's
    methods: Otsu split of the crop on colour distance from the lane's median
    colour, the connected blob nearest the crop centre, then an ellipse fit to
    its outline. Centre = ellipse centre; radius = half the minor axis (motion
    blur stretches the major axis)."""
    h, w = img.shape[:2]
    x0, y0 = max(int(cx - half), 0), max(int(cy - half), 0)
    x1, y1 = min(int(cx + half), w), min(int(cy + half), h)
    crop = cv2.GaussianBlur(img[y0:y1, x0:x1].astype(np.float32), (3, 3), 0)
    # Ball colour = median of a small disk at the crop centre; lane, pins and
    # deck are all far from it, so threshold distance-to-ball-colour.
    ch, cw = crop.shape[:2]
    mid0 = (int(cy - y0), int(cx - x0))
    k = max(2, int(half / 6))
    core = crop[max(mid0[0] - k, 0):mid0[0] + k + 1, max(mid0[1] - k, 0):mid0[1] + k + 1].reshape(-1, 3)
    ball = np.median(core, axis=0)
    dist = np.linalg.norm(crop - ball, axis=2)
    d8 = np.clip(dist * (255.0 / max(dist.max(), 1)), 0, 255).astype(np.uint8)
    _, mask = cv2.threshold(d8, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    n, lab, stats, cents = cv2.connectedComponentsWithStats(mask)
    if n <= 1:
        return None
    mid = np.array([cx - x0, cy - y0])
    best = min(range(1, n), key=lambda i: np.linalg.norm(cents[i] - mid) - 0.02 * stats[i, cv2.CC_STAT_AREA])
    blob = (lab == best).astype(np.uint8)
    cnts, _ = cv2.findContours(blob, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    c = max(cnts, key=cv2.contourArea)
    if len(c) < 6:
        return None
    (ex, ey), (ma, mi), ang = cv2.fitEllipse(c)
    return ex + x0 + 0.5, ey + y0 + 0.5, min(ma, mi) / 2, max(ma, mi) / 2


def _bilinear(img, x, y):
    h, w = img.shape
    x = np.clip(x, 0, w - 1.001); y = np.clip(y, 0, h - 1.001)
    x0 = np.floor(x).astype(int); y0 = np.floor(y).astype(int)
    fx = x - x0; fy = y - y0
    return (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x0 + 1] * fx * (1 - fy)
            + img[y0 + 1, x0] * (1 - fx) * fy + img[y0 + 1, x0 + 1] * fx * fy)


def _kasa(px, py):
    A = np.column_stack([px, py, np.ones_like(px)])
    b = px ** 2 + py ** 2
    sol, *_ = np.linalg.lstsq(A, b, rcond=None)
    cx, cy = sol[0] / 2, sol[1] / 2
    return cx, cy, np.sqrt(max(sol[2] + cx ** 2 + cy ** 2, 1e-6))


def fit_edges(img, cx, cy, r0, rays=64):
    """Radial-edge circle fit (the labelling proposal). Pixel-centre
    convention: pixel (i, j) covers [i, i+1); returns continuous coords like
    the app. From (cx, cy) cast rays, take the strongest luminance step between
    0.45 r and 1.7 r on each, fit a circle by least squares, drop rays whose
    edge is > 2.5 MAD off the circle (pins, reflection, hand), refit; three
    rounds re-centring each time. Returns (x, y, r, rms, rays kept)."""
    g = cv2.GaussianBlur(cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).astype(np.float32), (0, 0), 0.8)
    x, y, r = cx - 0.5, cy - 0.5, r0
    ang = np.linspace(0, 2 * np.pi, rays, endpoint=False)
    keep = np.ones(rays, bool)
    for _ in range(3):
        ts = np.arange(0.45 * r, 1.7 * r, 0.2)
        ex, ey = [], []
        for a in ang:
            px = x + ts * np.cos(a); py = y + ts * np.sin(a)
            prof = _bilinear(g, px, py)
            d = np.abs(np.gradient(prof))
            i = int(np.argmax(d))
            ex.append(px[i]); ey.append(py[i])
        ex = np.array(ex); ey = np.array(ey)
        keep = np.ones(rays, bool)
        for _ in range(3):
            fx, fy, fr = _kasa(ex[keep], ey[keep])
            res = np.hypot(ex - fx, ey - fy) - fr
            mad = np.median(np.abs(res[keep] - np.median(res[keep]))) + 0.15
            keep = np.abs(res - np.median(res[keep])) < 2.5 * 1.4826 * mad
            if keep.sum() < rays // 3:
                return None
        x, y, r = fx, fy, fr
    rms = float(np.sqrt(np.mean(res[keep] ** 2)))
    return x + 0.5, y + 0.5, r, rms, int(keep.sum())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tag"); ap.add_argument("clip"); ap.add_argument("out")
    ap.add_argument("--feet", nargs="*", type=float,
                    default=[3, 6, 9, 12, 14, 16, 18, 22, 30, 38, 45, 50, 53, 55, 57, 58.5])
    ap.add_argument("--frames", nargs="*", type=int)
    ap.add_argument("--overlay", action="store_true", help="draw the edge-fit proposal")
    ap.add_argument("--every", type=int, help="every Nth traced frame instead of --feet")
    ap.add_argument("--min-feet", type=float, default=0.0, help="with --every: only frames past this depth")
    ap.add_argument("--suffix", default="", help="meta/sheet name suffix (a second pass on the same clip)")
    a = ap.parse_args()
    runs = bench.load(a.tag)
    man = bench.manifest_by_id(a.tag)
    c = runs[a.clip]
    tr = bench.trace_display(c)
    frames = sorted(tr)
    chosen = []
    if a.frames:
        chosen = a.frames
    elif a.every:
        chosen = [f for f in frames[::a.every] if tr[f]["feet"] >= a.min_feet]
    else:
        for ft in a.feet:
            f = min(frames, key=lambda k: abs(tr[k]["feet"] - ft))
            if f not in chosen and abs(tr[f]["feet"] - ft) < 4:
                chosen.append(f)
    cap = cv2.VideoCapture(man[a.clip]["video"])
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    tiles, meta = [], []
    for f in chosen:
        cap.set(cv2.CAP_PROP_POS_FRAMES, f - 1)
        ok, img = cap.read()
        if not ok:
            continue
        s = tr.get(f)
        if s is None:
            nearest = min(frames, key=lambda k: abs(k - f)); s = tr[nearest]
        cx, cy = (s["det"] if s["det"] else (s["dx"], s["dy"]))
        r = s["radius"]
        half = int(max(14, round(2.2 * r)))
        fit = fit_edges(img, cx, cy, s["radius"])
        tiles.append(crop_tile(img, cx, cy, half, f, s["feet"], fit if a.overlay else None))
        meta.append({"frame": f, "crop_center": [cx, cy], "half": half,
                     "fit": None if fit is None else [round(v, 2) for v in fit]})
    for i in range(0, len(tiles), 6):
        group = tiles[i:i + 6]
        while len(group) < 6:
            group.append(np.zeros((CELL, CELL, 3), np.uint8))
        sheet = np.vstack([np.hstack(group[0:3]), np.hstack(group[3:6])])
        kind = "fit" if a.overlay else "sheet"
        cv2.imwrite(str(out / f"{a.clip}{a.suffix}_{kind}{i // 6}.png"), sheet)
    (out / f"{a.clip}{a.suffix}_meta.json").write_text(json.dumps(meta, indent=1))
    print(json.dumps(meta))


if __name__ == "__main__":
    main()
