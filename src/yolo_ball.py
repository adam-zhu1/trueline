"""
Optional YOLO-based ball detector (Ultralytics).

Why this exists
---------------
The classical pipeline (MOG2 + Hough + blobs) answers "what moved?" — not
"where is the ball?". A small detector trained on *your* lane / lighting learns
appearance (round, reflective, etc.) and is the usual next step for reliability.

How it plugs in
---------------
If a weights file exists at the default path (or PINPOINT_BALL_MODEL), `ball_tracking.track_ball`
uses this module to produce candidate (x, y, r) each frame and skips background
subtraction. If the file is missing or Ultralytics is not installed, PinPoint
falls back to the classical pipeline — so the app still runs for everyone.

You train a **single-class** model (class 0 = bowling_ball). Bounding boxes are
converted to a center and radius for the existing Kalman + refine_ball_center path.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any, List, Optional, Tuple

import cv2
import numpy as np

Candidate = Tuple[float, float, float]  # (cx, cy, radius_px)


def _project_root() -> Path:
    return Path(__file__).resolve().parent.parent


def default_model_path() -> Path:
    """Weights live next to the repo (not under ignored data/)."""
    return _project_root() / "models" / "ball.pt"


def lane_surface_quad(calibration: dict) -> np.ndarray:
    """
    Same corner order as the lane trapezoid in lane_and_approach_mask (lane only):
    foul_near → foul_far → pin_far → pin_near (closed polygon).
    """
    fn = calibration["points"]["foul_line_near"]
    ff = calibration["points"]["foul_line_far"]
    pn = calibration["points"]["pin_line_near"]
    pf = calibration["points"]["pin_line_far"]
    return np.array([fn, ff, pf, pn], dtype=np.float64)


def _center_inside_lane(cx: float, cy: float, calibration: dict) -> bool:
    """True if the point lies inside the calibrated lane quadrilateral."""
    quad = lane_surface_quad(calibration).astype(np.float32)
    return cv2.pointPolygonTest(quad, (float(cx), float(cy)), False) >= 0.0


class BallDetector:
    """
    Thin wrapper around Ultralytics YOLO for one class (bowling ball).

    We run one forward pass per frame, take boxes above a confidence threshold,
    keep detections whose *center* lies inside the lane polygon from calibration,
    and convert each box to (cx, cy, r) for the rest of the pipeline.
    """

    def __init__(
        self,
        weights_path: Path,
        conf: float = 0.35,
        iou: float = 0.45,
    ):
        from ultralytics import YOLO  # import here so classical mode works without it

        self._weights = Path(weights_path)
        self.model = YOLO(str(self._weights))
        self.conf = conf
        self.iou = iou

    @property
    def weights_path(self) -> Path:
        return self._weights

    def candidates_for_frame(
        self,
        frame_bgr: np.ndarray,
        calibration: dict,
    ) -> List[Candidate]:
        """
        Return a list of (cx, cy, r) in pixel coordinates for detections inside the lane.

        Multiple boxes can appear (e.g. reflection); the Kalman association step in
        ball_tracking picks the nearest to the predicted position.
        """
        # predict: single image, no verbose logs each frame
        results = self.model.predict(
            source=frame_bgr,
            conf=self.conf,
            iou=self.iou,
            verbose=False,
        )
        out: List[Candidate] = []
        if not results:
            return out
        r0 = results[0]
        if r0.boxes is None or len(r0.boxes) == 0:
            return out

        boxes = r0.boxes.xyxy.cpu().numpy()
        for x1, y1, x2, y2 in boxes:
            cx = 0.5 * (x1 + x2)
            cy = 0.5 * (y1 + y2)
            if not _center_inside_lane(cx, cy, calibration):
                continue
            w = x2 - x1
            h = y2 - y1
            # Radius for refine_ball_center: use half the smaller side (conservative disk)
            r = 0.5 * float(min(w, h))
            r = max(6.0, min(r, 120.0))
            out.append((float(cx), float(cy), r))
        return out


def resolved_ball_weights_path(weights_path: Optional[Path] = None) -> Path:
    """
    Which weights file we would try to load (may not exist).

    Order: explicit argument, env PINPOINT_BALL_MODEL, then models/ball.pt.
    """
    if weights_path is not None:
        return Path(weights_path)
    env = os.environ.get("PINPOINT_BALL_MODEL", "").strip()
    if env:
        return Path(env)
    return default_model_path()


def load_yolo_ball(
    weights_path: Optional[Path] = None,
    conf: float = 0.35,
) -> tuple[Optional[BallDetector], Optional[str]]:
    """
    Load a trained detector if possible.

    Returns (detector, None) on success, or (None, reason) on failure.
    reason is one of: "no_weights", "import_torch", or a short error message.
    """
    path = resolved_ball_weights_path(weights_path)
    if not path.is_file():
        return None, "no_weights"
    try:
        return BallDetector(path, conf=conf), None
    except ImportError:
        return None, "import_torch"
    except Exception as e:
        return None, str(e)
