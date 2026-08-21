"""Fit a reference lane homography from physical lane landmarks.

Landmarks with certain lane coordinates (board positions are regulation):
  - 10 guide dots, boards 3,5,8,11,14 / 26,29,32,35,37 (from RIGHT gutter),
    all at one unknown shared distance t_d (~6-8 ft)
  - 7 arrows, boards 5,10,15,20,25,30,35, distances form a symmetric V:
    t(b) = t_apex - step * |b-20|/5, t_apex and step unknown
  - headpin base: board 20, 60 ft exactly
  - hand-placed gutter corners (foul + pin line): board 0/39 at 0/60 ft,
    treated as soft observations (they are the least trustworthy)

Board->lane x uses x = board/39 (0 = right gutter, 39 = left gutter),
matching src/calibration.py's homography convention. A board CENTER k is at
(k - 0.5)/39; dots/arrows/pins sit on board centers, so we use that.

Solves min over (t_d, t_apex, step) of weighted homography reprojection
error (Nelder-Mead over the 3 scalars; weighted DLT inside). Outputs the
fitted corner points in the app/prototype calibration.json format plus a
fit report.

Usage: python3 fit_reference.py landmarks/<clip>.json
"""
import json
import sys

import cv2
import numpy as np
from scipy.optimize import minimize

DOT_BOARDS = [37, 35, 32, 29, 26, 14, 11, 8, 5, 3]  # left-to-right in image
ARROW_BOARDS = [35, 30, 25, 20, 15, 10, 5]           # left-to-right in image


def board_x(board):
    """Lane x in [0,1] of a board CENTER, 0 = right gutter edge."""
    return (board - 0.5) / 39.0


def build_correspondences(lm, t_d, t_apex, step):
    src, dst, w = [], [], []
    for (px, py), b in zip(lm["dots"], DOT_BOARDS):
        src.append((px, py)); dst.append((board_x(b), t_d)); w.append(1.0)
    for (px, py), b in zip(lm["arrows"], ARROW_BOARDS):
        src.append((px, py)); dst.append((board_x(b), t_apex - step * abs(b - 20) / 5.0)); w.append(1.0)
    if "headpin" in lm:
        src.append(tuple(lm["headpin"])); dst.append((board_x(20), 60.0)); w.append(1.5)
    for key, (bx, ft) in [
        ("foul_line_right", (0.0, 0.0)), ("foul_line_left", (1.0, 0.0)),
        ("pin_line_right", (0.0, 60.0)), ("pin_line_left", (1.0, 60.0)),
    ]:
        if key in lm:
            src.append(tuple(lm[key])); dst.append((bx, ft)); w.append(lm.get("corner_weight", 0.3))
    return np.array(src, np.float64), np.array(dst, np.float64), np.array(w, np.float64)


def fit_H(src, dst, w):
    """Weighted DLT homography image->lane, then evaluate residual in IMAGE px."""
    # scale lane coords so x and y are comparable during DLT (x in [0,1], y in [0,60])
    S = np.diag([1.0, 1.0 / 60.0])
    d = dst @ S
    A = []
    for (x, y), (u, v), wi in zip(src, d, w):
        A.append(wi * np.array([-x, -y, -1, 0, 0, 0, u * x, u * y, u]))
        A.append(wi * np.array([0, 0, 0, -x, -y, -1, v * x, v * y, v]))
    _, _, Vt = np.linalg.svd(np.array(A))
    H = Vt[-1].reshape(3, 3)
    H = np.diag([1.0, 60.0, 1.0]) @ H  # undo lane scaling
    return H / H[2, 2]


def image_residuals(H, src, dst, w):
    """Residuals in image px: project lane points back through H^-1."""
    Hi = np.linalg.inv(H)
    pts = cv2.perspectiveTransform(dst.reshape(-1, 1, 2), Hi).reshape(-1, 2)
    return np.linalg.norm(pts - src, axis=1) * w


def fit(lm):
    def cost(theta):
        t_d, t_apex, step = theta
        if not (4.0 < t_d < 10.0 and 12.0 < t_apex < 18.0 and 0.0 <= step < 2.5):
            return 1e9
        src, dst, w = build_correspondences(lm, t_d, t_apex, step)
        H = fit_H(src, dst, w)
        r = image_residuals(H, src, dst, w)
        return float(np.sqrt(np.mean(r ** 2)))

    best = minimize(cost, x0=np.array([7.0, 15.0, 1.0]), method="Nelder-Mead",
                    options={"xatol": 1e-4, "fatol": 1e-6, "maxiter": 2000})
    t_d, t_apex, step = best.x
    src, dst, w = build_correspondences(lm, t_d, t_apex, step)
    H = fit_H(src, dst, w)
    return H, best.x, src, dst, w


def corners_from_H(H):
    """Lane gutter corners projected back to image via H^-1."""
    Hi = np.linalg.inv(H)
    lane = np.array([[0, 0], [1, 0], [1, 60], [0, 60]], np.float64).reshape(-1, 1, 2)
    img = cv2.perspectiveTransform(lane, Hi).reshape(-1, 2)
    return {  # same key names as the prototype calibration format
        "foul_line_right": img[0].tolist(),
        "foul_line_left": img[1].tolist(),
        "pin_line_left": img[2].tolist(),
        "pin_line_right": img[3].tolist(),
    }


def main():
    lm_path = sys.argv[1]
    lm = json.load(open(lm_path))
    H, (t_d, t_apex, step), src, dst, w = fit(lm)
    r = image_residuals(H, src, dst, np.ones_like(w))

    labels = (["dot b%d" % b for b in DOT_BOARDS] + ["arrow b%d" % b for b in ARROW_BOARDS]
              + (["headpin"] if "headpin" in lm else [])
              + [k for k in ["foul_line_right", "foul_line_left", "pin_line_right", "pin_line_left"] if k in lm])
    print(f"fitted: dot row {t_d:.2f} ft, arrow apex {t_apex:.2f} ft, arrow step {step:.2f} ft")
    for lab, res in zip(labels, r):
        print(f"  {lab:18s} residual {res:6.2f} px")
    print(f"  rms {np.sqrt(np.mean(r**2)):.2f} px")

    corners = corners_from_H(H)
    for k, v in corners.items():
        print(f"  {k:18s} ({v[0]:7.2f}, {v[1]:7.2f})")

    out = {
        "clip": lm.get("clip"),
        "frame": lm.get("frame"),
        "H_image_to_lane": H.tolist(),
        "fitted_params": {"dot_row_ft": t_d, "arrow_apex_ft": t_apex, "arrow_step_ft": step},
        "corners": corners,
        "landmarks": lm,
        "rms_px": float(np.sqrt(np.mean(r ** 2))),
    }
    out_path = lm_path.replace("landmarks/", "references/").replace(".json", "_ref.json")
    json.dump(out, open(out_path, "w"), indent=2)
    print("saved", out_path)


if __name__ == "__main__":
    main()
