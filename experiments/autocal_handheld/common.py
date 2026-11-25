"""Shared helpers for the auto-calibration and handheld experiments.

Clips and calibrations come from the accuracy benchmark (clips.manifest()), so
the videos are read in place from the main checkout's git-ignored data/ tree.
Lane convention matches bench.Lane: t 0 = right gutter, t 1 = left gutter,
feet 0 = foul line, 60 = head pin; board = t * 39 for a right-hander.
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
OUT = HERE / "out"
sys.path.insert(0, str(REPO / "experiments" / "accuracy_bench"))
import clips as corpus  # noqa: E402
import bench  # noqa: E402

LANDMARKS = REPO / "experiments" / "calibration_v11" / "landmarks"
CORNER_KEYS = ["nearRight", "nearLeft", "farLeft", "farRight"]
LANE_QUAD = np.array([(0, 0), (1, 0), (1, 60), (0, 60)], float)   # matches CORNER_KEYS


def manifest():
    return {c["id"]: c for c in corpus.manifest()}


def corners_array(c):
    return np.array([c[k] for k in CORNER_KEYS], float)


def lane_to_image(corners):
    """Homography lane (t, feet) -> display px from the 4 app corners."""
    return cv2.getPerspectiveTransform(LANE_QUAD.astype(np.float32), np.asarray(corners, np.float32)).astype(float)


def project(H, pts):
    pts = np.asarray(pts, float).reshape(-1, 2)
    p = np.c_[pts, np.ones(len(pts))] @ H.T
    return p[:, :2] / p[:, 2:3]


def read_frame(video, index=0):
    cap = cv2.VideoCapture(video)
    cap.set(cv2.CAP_PROP_POS_FRAMES, index)
    ok, fr = cap.read()
    cap.release()
    return fr if ok else None


def board_error(H_true, H_est, feet, boards=np.linspace(0.5, 38.5, 39)):
    """Board error across the lane at one depth: take the true image point of
    every board at `feet`, read it back through the estimated calibration.
    Returns (mean |board err|, max |board err|, mean feet err)."""
    lane = np.c_[boards / 39.0, np.full(len(boards), feet)]
    img = project(H_true, lane)
    back = project(np.linalg.inv(H_est), img)
    db = back[:, 0] * 39 - boards
    df = back[:, 1] - feet
    return float(np.abs(db).mean()), float(np.abs(db).max()), float(df.mean())


def corner_error(c_true, c_est):
    """Mean and max pixel distance over the four corners."""
    d = np.linalg.norm(np.asarray(c_true) - np.asarray(c_est), axis=1)
    return float(d.mean()), float(d.max())


def calib_errors(c_true, c_est):
    Ht, He = lane_to_image(c_true), lane_to_image(c_est)
    cm, cx = corner_error(c_true, c_est)
    a = board_error(Ht, He, 15.0)
    p = board_error(Ht, He, 59.5)
    return {"corner_px_mean": cm, "corner_px_max": cx,
            "arrows_board_mean": a[0], "arrows_board_max": a[1], "arrows_feet": a[2],
            "pins_board_mean": p[0], "pins_board_max": p[1], "pins_feet": p[2]}


def landmarks(cid):
    p = LANDMARKS / f"{cid}.json"
    return json.loads(p.read_text()) if p.exists() else None


def fmt(v, nd=1):
    return "--" if v is None else f"{v:.{nd}f}"
