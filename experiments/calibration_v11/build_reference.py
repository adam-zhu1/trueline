"""Build a reference lane calibration for one clip from physical landmarks.

Model: image -> (division-model radial undistort, k free) -> homography H
-> lane coords (x in [0,1] right-to-left gutter, y in feet down-lane).

Constraints (regulation lane geometry):
  - 10 guide dots: boards 3,5,8,11,14 / 26,29,32,35,37 from the right
    gutter, shared unknown distance t_d
  - 7 arrows: boards 5,10,15,20,25,30,35, symmetric-V distances
    t(b) = apex - step*|b-20|/5, apex & step unknown
  - headpin base: board 20 at 60 ft
  - foul-line edge samples: lane y = 0 (board unknown per point)
  - right/left gutter-edge samples: lane x = 0 / 1 (feet unknown per point)

Joint least squares over H (8), t_d, apex, step, k. Residuals in lane
units: x-errors in boards, y-errors in feet (weighted). Robust loss for
edge samples (they can lock onto stickers/shadows).

Usage: python3 build_reference.py landmarks/IMG_5108.json
Writes references/<clip>_ref.json and overlays/<clip>_overlay.png.
"""
import json
import os
import sys

import cv2
import numpy as np
from scipy.optimize import least_squares

DOT_BOARDS = [37, 35, 32, 29, 26, 14, 11, 8, 5, 3]  # left-to-right in image
ARROW_BOARDS = [35, 30, 25, 20, 15, 10, 5]

BOARD_W = 1.0 / 39.0


def board_x(board):
    return (board - 0.5) / 39.0


# ---------------- distortion ----------------

def undistort_pts(pts, k, center, f_norm):
    d = pts - center
    r2 = np.sum(d ** 2, axis=1) / f_norm ** 2
    return center + d / (1 + k * r2)[:, None]


def redistort_pts(pts, k, center, f_norm):
    """Inverse of undistort_pts (division model)."""
    d = pts - center
    ru = np.linalg.norm(d, axis=1) / f_norm
    rd = np.empty_like(ru)
    small = np.abs(k) < 1e-9
    rd[small | (ru < 1e-9)] = ru[small | (ru < 1e-9)]
    m = ~(small | (ru < 1e-9))
    disc = np.maximum(1 - 4 * k * ru[m] ** 2, 0.0)
    rd[m] = (1 - np.sqrt(disc)) / (2 * k * ru[m])
    scale = np.where(ru > 1e-9, rd / ru, 1.0)
    return center + d * scale[:, None]


# ---------------- edge sampling ----------------

def _subpix(grad, i):
    a, b, c = grad[i - 1], grad[i], grad[i + 1]
    den = a - 2 * b + c
    return 0.5 * (a - c) / den if abs(den) > 1e-9 else 0.0


def sample_vertical_edge(gray, y0, y1, x_at, half=18, step=6, mode="dark2light", min_grad=5):
    pts = []
    g = cv2.GaussianBlur(gray, (5, 5), 0).astype(np.float64)
    for y in range(y0, y1, step):
        xc = int(round(x_at(y)))
        lo, hi = max(1, xc - half), min(gray.shape[1] - 2, xc + half)
        grad = np.gradient(g[y, lo:hi])
        i = int(np.argmax(grad)) if mode == "dark2light" else int(np.argmin(grad))
        val = grad[i] if mode == "dark2light" else -grad[i]
        if val < min_grad or i in (0, len(grad) - 1):
            continue
        pts.append((lo + i + _subpix(grad, i), float(y)))
    return np.array(pts)


def sample_horizontal_edge(gray, x0, x1, y_at, half=15, step=6, mode="light2dark", min_grad=5):
    pts = []
    g = cv2.GaussianBlur(gray, (5, 5), 0).astype(np.float64)
    for x in range(x0, x1, step):
        yc = int(round(y_at(x)))
        lo, hi = max(1, yc - half), min(gray.shape[0] - 2, yc + half)
        grad = np.gradient(g[lo:hi, x])
        i = int(np.argmax(grad)) if mode == "dark2light" else int(np.argmin(grad))
        val = grad[i] if mode == "dark2light" else -grad[i]
        if val < min_grad or i in (0, len(grad) - 1):
            continue
        pts.append((float(x), lo + i + _subpix(grad, i)))
    return np.array(pts)


def lerp2(p0, p1):
    (a0, b0), (a1, b1) = p0, p1
    return lambda t: b0 + (b1 - b0) * (t - a0) / (a1 - a0)


# ---------------- model ----------------

def h_from_params(v):
    return np.array([[v[0], v[1], v[2]], [v[3], v[4], v[5]], [v[6], v[7], 1.0]])


def apply_model(pts, v, center, f_norm):
    """image pts -> lane coords under params v = [h(8), t_d, apex, step, k]."""
    k = v[11]
    u = undistort_pts(np.asarray(pts, np.float64), k, center, f_norm)
    H = h_from_params(v[:8])
    q = cv2.perspectiveTransform(u.reshape(-1, 1, 2), H).reshape(-1, 2)
    return q


def residuals(v, obs, center, f_norm, w_ft):
    t_d, apex, step = v[8], v[9], v[10]
    res = []
    lane = apply_model(obs["dots"], v, center, f_norm)
    for (lx, ly), b in zip(lane, DOT_BOARDS):
        res += [(lx - board_x(b)) * 39.0, (ly - t_d) * w_ft]
    lane = apply_model(obs["arrows"], v, center, f_norm)
    for (lx, ly), b in zip(lane, ARROW_BOARDS):
        res += [(lx - board_x(b)) * 39.0, (ly - (apex - step * abs(b - 20) / 5.0)) * w_ft]
    lane = apply_model([obs["headpin"]], v, center, f_norm)
    res += [(lane[0][0] - board_x(20)) * 39.0 * 2.0, (lane[0][1] - 60.0) * w_ft * 2.0]
    # pin columns: lateral-only anchors at the rack (board known, depth approximate)
    if obs.get("pin_columns"):
        pts = [(x, y) for x, y, b in obs["pin_columns"]]
        lane = apply_model(pts, v, center, f_norm)
        for (lx, ly), (x, y, b) in zip(lane, obs["pin_columns"]):
            res.append((lx - board_x(b)) * 39.0 * 1.5)
    if len(obs.get("foul_pts", [])):
        lane = apply_model(obs["foul_pts"], v, center, f_norm)
        res += list(lane[:, 1] * w_ft)                       # y = 0 ft
    if len(obs.get("right_edge_pts", [])):
        lane = apply_model(obs["right_edge_pts"], v, center, f_norm)
        res += list(lane[:, 0] * 39.0)                       # x = 0
    if len(obs.get("left_edge_pts", [])):
        lane = apply_model(obs["left_edge_pts"], v, center, f_norm)
        res += list((lane[:, 0] - 1.0) * 39.0)               # x = 1
    # soft priors keep t_d, apex, step physical; k is pinned hard — these
    # landmarks cannot constrain lens distortion (a free k runs to absurd
    # values chasing sub-pixel detection noise; see notes/calibration
    # experiments Aug 21), and variant tests show k=0 fits to ~0.5 board.
    res += [(t_d - 7.0) * 0.5, (apex - 15.0) * 0.3, (step - 1.0) * 0.3, v[11] * 500.0]
    return np.array(res)


def initial_params(lm):
    src = np.array([lm["foul_line_right"], lm["foul_line_left"],
                    lm["pin_line_left"], lm["pin_line_right"]], np.float32)
    dst = np.array([[0, 0], [1, 0], [1, 60], [0, 60]], np.float32)
    H = cv2.getPerspectiveTransform(src, dst).astype(np.float64)
    H /= H[2, 2]
    return np.array(list(H.flatten()[:8]) + [7.0, 15.0, 1.0, 0.0])


# ---------------- overlay ----------------

def draw_overlay(frame, v, center, f_norm, out_path):
    k = v[11]
    Hi = np.linalg.inv(h_from_params(v[:8]))

    def to_img(lane_pts):
        q = cv2.perspectiveTransform(np.asarray(lane_pts, np.float64).reshape(-1, 1, 2), Hi).reshape(-1, 2)
        return redistort_pts(q, k, center, f_norm)

    img = frame.copy()

    def poly(lane_pts, color, thick=2):
        p = to_img(lane_pts).astype(np.int32)
        cv2.polylines(img, [p], False, color, thick, cv2.LINE_AA)

    ft = np.linspace(0, 60, 40)
    poly([(0.0, f) for f in ft], (0, 255, 255), 3)   # right gutter
    poly([(1.0, f) for f in ft], (0, 255, 255), 3)   # left gutter
    for b in range(5, 39, 5):
        poly([(b / 39.0, f) for f in ft], (180, 180, 60), 1)
    poly([(x, 0.0) for x in np.linspace(0, 1, 12)], (0, 128, 255), 3)    # foul line
    poly([(x, 60.0) for x in np.linspace(0, 1, 12)], (0, 255, 0), 2)     # 60 ft pin line
    t_d, apex, step = v[8], v[9], v[10]
    for b in DOT_BOARDS:
        c = to_img([(board_x(b), t_d)])[0].astype(int)
        cv2.circle(img, tuple(c), 6, (255, 0, 255), 2)
    for b in ARROW_BOARDS:
        c = to_img([(board_x(b), apex - step * abs(b - 20) / 5.0)])[0].astype(int)
        cv2.drawMarker(img, tuple(c), (255, 0, 255), cv2.MARKER_TRIANGLE_UP, 14, 2)
    # pin spots: rows at 60, 60.87, 61.73, 62.6 ft
    pin_rows = [([20], 60.0), ([14.36, 25.64], 60.87), ([8.72, 20, 31.28], 61.73),
                ([3.08, 14.36, 25.64, 36.92], 62.60)]
    for boards, f in pin_rows:
        for b in boards:
            c = to_img([(board_x(b), f)])[0].astype(int)
            cv2.circle(img, tuple(c), 4, (255, 255, 255), 1)
    cv2.imwrite(out_path, img)


# ---------------- main ----------------

def main():
    lm_path = sys.argv[1]
    lm = json.load(open(lm_path))
    clip = os.path.splitext(os.path.basename(lm["clip"]))[0]
    frame = cv2.imread(lm["frame_path"])
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape
    center = np.array([w / 2.0, h / 2.0])
    f_norm = max(h, w) / 2.0

    obs = {"dots": lm["dots"], "arrows": lm["arrows"], "headpin": lm["headpin"], "pin_columns": lm.get("pin_columns")}
    for key, kind in [("foul_corridor", "foul"), ("right_edge_corridor", "right"),
                      ("left_edge_corridor", "left")]:
        if key not in lm:
            continue
        c = lm[key]
        if kind == "foul":
            pts = sample_horizontal_edge(gray, c["from"][0], c["to"][0],
                                         lerp2(c["from"], c["to"]), mode=c.get("mode", "light2dark"))
            obs["foul_pts"] = pts
        else:
            fn = lerp2((c["from"][1], c["from"][0]), (c["to"][1], c["to"][0]))
            pts = sample_vertical_edge(gray, c["from"][1], c["to"][1], fn, mode=c["mode"])
            obs["right_edge_pts" if kind == "right" else "left_edge_pts"] = pts
    for name in ["foul_pts", "right_edge_pts", "left_edge_pts"]:
        if name in obs:
            print(f"{name}: {len(obs[name])} samples")

    v0 = initial_params(lm)
    fit = least_squares(residuals, v0, args=(obs, center, f_norm, 0.5),
                        loss="soft_l1", f_scale=1.0, max_nfev=4000)
    v = fit.x
    print(f"converged: {fit.status}, cost {fit.cost:.2f}")
    print(f"t_dots {v[8]:.2f} ft, arrow apex {v[9]:.2f} ft, step {v[10]:.2f} ft, k {v[11]:.4f}")

    lane = apply_model(obs["dots"], v, center, f_norm)
    for (lx, ly), b in zip(lane, DOT_BOARDS):
        print(f"  dot b{b:2d}: board {lx*39+0.5:5.2f} (want {b})  {ly:5.2f} ft")
    lane = apply_model(obs["arrows"], v, center, f_norm)
    for (lx, ly), b in zip(lane, ARROW_BOARDS):
        print(f"  arrow b{b:2d}: board {lx*39+0.5:5.2f} (want {b})  {ly:5.2f} ft")
    lane = apply_model([obs["headpin"]], v, center, f_norm)
    print(f"  headpin: board {lane[0][0]*39+0.5:5.2f} (want 20)  {lane[0][1]:5.2f} ft (want 60)")

    # gutter corners in image space (undistorted plane -> redistorted image)
    Hi = np.linalg.inv(h_from_params(v[:8]))
    lanepts = np.array([[0, 0], [1, 0], [1, 60], [0, 60]], np.float64).reshape(-1, 1, 2)
    img_pts = redistort_pts(cv2.perspectiveTransform(lanepts, Hi).reshape(-1, 2), v[11], center, f_norm)
    corners = {"foul_line_right": img_pts[0].tolist(), "foul_line_left": img_pts[1].tolist(),
               "pin_line_left": img_pts[2].tolist(), "pin_line_right": img_pts[3].tolist()}
    for kk, vv in corners.items():
        print(f"  {kk:18s} ({vv[0]:7.2f}, {vv[1]:7.2f})")

    os.makedirs("references", exist_ok=True)
    os.makedirs("overlays", exist_ok=True)
    ref = {"clip": lm["clip"], "frame": lm["frame"], "frame_path": lm["frame_path"],
           "H_undistorted_to_lane": h_from_params(v[:8]).tolist(),
           "distortion": {"model": "division", "k": float(v[11]),
                          "center": center.tolist(), "f_norm": float(f_norm)},
           "fitted": {"dot_row_ft": float(v[8]), "arrow_apex_ft": float(v[9]),
                      "arrow_step_ft": float(v[10])},
           "corners": corners, "landmarks_file": lm_path}
    ref_path = f"references/{clip}_ref.json"
    json.dump(ref, open(ref_path, "w"), indent=2)
    draw_overlay(frame, v, center, f_norm, f"overlays/{clip}_overlay.png")
    print("saved", ref_path, "and overlay")


if __name__ == "__main__":
    main()
