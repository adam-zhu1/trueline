import os

import cv2
import numpy as np

from calibration import (
    DOT_DISTANCE_FEET,
    LANE_LENGTH_FEET,
    LANE_MASK_DILATE_ITERATIONS,
    LANE_WIDTH_INCHES,
)
from yolo_ball import load_yolo_ball, resolved_ball_weights_path

# CV Kalman state: [x, y, vx, vy] (pixels / frame). Sharp backends change (vx, vy) fast;
# higher Q_vel than Q_xy avoids over-smoothing hooks; lower R trusts detections more.
_KF_PROCESS_NOISE_XY = 2.0e-2
_KF_PROCESS_NOISE_VEL = 0.35
_KF_MEASUREMENT_NOISE = 12.0

# USBC arrow V: center arrow (board 20) at 16 ft, outer arrows (boards 5 & 35) at 12 ft.
# Linear slope from center outward: 4 ft over 15 boards.
_ARROW_CENTER_BOARD = 20
_ARROW_CENTER_FEET = 16.0
_ARROW_SLOPE = 4.0 / 15.0


def arrow_feet_at_board(board: float) -> float:
    """Feet from foul line of the arrow V at a given board (extrapolates beyond 5-35)."""
    return _ARROW_CENTER_FEET - abs(board - _ARROW_CENTER_BOARD) * _ARROW_SLOPE


def create_ball_kalman(init_x, init_y):
    """Constant-velocity Kalman filter for (x, y); smooths noisy detections."""
    kf = cv2.KalmanFilter(4, 2)
    kf.transitionMatrix = np.array(
        [[1, 0, 1, 0],
         [0, 1, 0, 1],
         [0, 0, 1, 0],
         [0, 0, 0, 1]], dtype=np.float32
    )
    kf.measurementMatrix = np.array(
        [[1, 0, 0, 0],
         [0, 1, 0, 0]], dtype=np.float32
    )
    kf.processNoiseCov = np.diag(
        [
            _KF_PROCESS_NOISE_XY,
            _KF_PROCESS_NOISE_XY,
            _KF_PROCESS_NOISE_VEL,
            _KF_PROCESS_NOISE_VEL,
        ]
    ).astype(np.float32)
    kf.measurementNoiseCov = np.eye(2, dtype=np.float32) * _KF_MEASUREMENT_NOISE
    kf.errorCovPost = np.eye(4, dtype=np.float32)
    kf.statePost = np.array(
        [[init_x], [init_y], [0.0], [0.0]], dtype=np.float32
    )
    return kf


def board_from_ball_on_line(bx, by, far_pt, near_pt):
    """
    Board 1 at far edge, board 39 at near edge.
    far_pt / near_pt are (x, y) image coordinates for that line's endpoints.
    """
    far = np.array(far_pt, dtype=np.float64)
    near = np.array(near_pt, dtype=np.float64)
    p = np.array([bx, by], dtype=np.float64)
    w = near - far
    w_len2 = float(np.dot(w, w))
    if w_len2 < 1e-6:
        return 20
    t = float(np.dot(p - far, w) / w_len2)
    t = max(0.0, min(1.0, t))
    board = int(round(1.0 + t * 38.0))
    return max(1, min(39, board))


def board_at_position(bx, by, calibration):
    """
    Board number at (bx, by).
    For right-handed bowler: board 1 = right gutter, board 39 = left gutter.
    For left-handed bowler: board 1 = left gutter, board 39 = right gutter.
    """
    fn = np.array(calibration["points"]["foul_line_right"], dtype=np.float64)
    ff = np.array(calibration["points"]["foul_line_left"], dtype=np.float64)
    pn = np.array(calibration["points"]["pin_line_right"], dtype=np.float64)
    pf = np.array(calibration["points"]["pin_line_left"], dtype=np.float64)
    foul_line_y = calibration["foul_line_y"]
    pin_line_y = calibration["pin_line_y"]
    bowler_hand = calibration.get("bowler_hand", "R")

    # interpolate lane edges at this y position
    total = abs(pin_line_y - foul_line_y)
    if total < 1e-6:
        return 20
    t = abs(by - foul_line_y) / total
    t = max(0.0, min(1.0, t))
    right_pt = fn + t * (pn - fn)
    left_pt = ff + t * (pf - ff)

    # right_x and left_x in image space
    right_x = right_pt[0]
    left_x = left_pt[0]

    # fraction from right gutter toward left gutter
    lane_width = abs(left_x - right_x)
    if lane_width < 1e-6:
        return 20
    t_board = (bx - right_x) / (left_x - right_x)
    t_board = max(0.0, min(1.0, t_board))

    # right-handed: board 1 at right gutter, board 39 at left
    # left-handed: board 1 at left gutter, board 39 at right
    if bowler_hand == "R":
        board = int(round(1.0 + t_board * 38.0))
    else:
        board = int(round(1.0 + (1.0 - t_board) * 38.0))

    return max(1, min(39, board))


class BreakpointTracker:
    """
    Detect lateral direction reversal with 5 consecutive frames of the new sign
    on smoothed x-velocity before confirming (reduces noise false triggers).
    """

    def __init__(self, persist_frames=5, dx_eps=0.35):
        self.persist_frames = persist_frames
        self.dx_eps = dx_eps
        self.confirmed = None
        self.last_sign = None
        self.pending_sign = None
        self.pending_count = 0
        self.candidate = None

    @staticmethod
    def _sign(dx, eps):
        if dx > eps:
            return 1
        if dx < -eps:
            return -1
        return 0

    def update(self, positions):
        """positions: list of (x, y, frame_number). Returns (bx, by) or None."""
        if self.confirmed is not None:
            return self.confirmed
        if len(positions) < 10:
            return None

        xs = [p[0] for p in positions]
        smoothed = np.convolve(xs, np.ones(5) / 5.0, mode="valid")
        if len(smoothed) < 2:
            return None

        dx = float(smoothed[-1] - smoothed[-2])
        s = self._sign(dx, self.dx_eps)
        x, y = positions[-1][0], positions[-1][1]

        if self.pending_sign is None:
            if s != 0:
                if self.last_sign is None:
                    self.last_sign = s
                elif self.last_sign != s:
                    self.pending_sign = s
                    self.pending_count = 1
                    self.candidate = (x, y)
                else:
                    self.last_sign = s
        else:
            if s == 0:
                pass
            elif s == self.pending_sign:
                self.pending_count += 1
                if self.pending_count >= self.persist_frames:
                    self.confirmed = self.candidate
                    return self.confirmed
            else:
                self.pending_sign = None
                self.pending_count = 0
                self.candidate = None
                self.last_sign = s

        return None


def _image_to_lane_H(calibration):
    """
    3×3 homography mapping image pixels → lane world coords (t_across, feet).
    t_across: 0 = right gutter click, 1 = left gutter click.
    feet: 0 = foul line, 60 = pin line.
    Uses the four corner clicks (foul right/left, pin right/left).
    """
    src = np.array([
        calibration["points"]["foul_line_right"],
        calibration["points"]["foul_line_left"],
        calibration["points"]["pin_line_left"],
        calibration["points"]["pin_line_right"],
    ], dtype=np.float32)
    dst = np.array([
        [0.0, 0.0],
        [1.0, 0.0],
        [1.0, 60.0],
        [0.0, 60.0],
    ], dtype=np.float32)
    return cv2.getPerspectiveTransform(src, dst)


def image_to_lane(bx, by, calibration):
    """
    Map an image pixel (bx, by) to (board_float, feet_float) via perspective homography.
    Returns (board, feet) or (None, None) on failure.
    """
    H = _image_to_lane_H(calibration)
    pt = np.array([[[float(bx), float(by)]]], dtype=np.float32)
    out = cv2.perspectiveTransform(pt, H)
    t_across, feet = float(out[0][0][0]), float(out[0][0][1])
    feet = max(0.0, min(60.0, feet))
    t_across = max(0.0, min(1.0, t_across))
    bowler_hand = calibration.get("bowler_hand", "R")
    if bowler_hand == "R":
        board = 1.0 + t_across * 38.0
    else:
        board = 1.0 + (1.0 - t_across) * 38.0
    board = max(1.0, min(39.0, board))
    return board, feet


def _lane_axis_vectors(calibration):
    """
    Foul-line midpoint, unit vector toward pins (pin midpoint), and scalar projection
    (pixels) from foul midpoint to dot midpoint along that axis — used for scale.
    """
    fn = np.array(calibration["points"]["foul_line_right"], dtype=np.float64)
    ff = np.array(calibration["points"]["foul_line_left"], dtype=np.float64)
    pn = np.array(calibration["points"]["pin_line_right"], dtype=np.float64)
    pf = np.array(calibration["points"]["pin_line_left"], dtype=np.float64)
    dn = np.array(calibration["points"]["dot_line_right"], dtype=np.float64)
    df = np.array(calibration["points"]["dot_line_left"], dtype=np.float64)
    foul_m = 0.5 * (fn + ff)
    pin_m = 0.5 * (pn + pf)
    dot_m = 0.5 * (dn + df)
    u = pin_m - foul_m
    u_len = float(np.linalg.norm(u))
    if u_len < 1e-6:
        return None, None, None, None
    u_hat = u / u_len
    s_dot = float(np.dot(dot_m - foul_m, u_hat))
    return foul_m, u_hat, dot_m, s_dot


def ball_along_lane_px(bx, by, calibration):
    """Signed pixels along foul→pins axis (0 ≈ foul plane, increases toward pins)."""
    foul_m, u_hat, _, _ = _lane_axis_vectors(calibration)
    if foul_m is None:
        return None
    return float(np.dot(np.array([bx, by], dtype=np.float64) - foul_m, u_hat))


def detect_from_motion_blob(mask):
    """
    Prefer largest roughly circular foreground blob (actual ball) over Hough on
    flat lane shine / reflections that often fail circularity or size.
    """
    cnts, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    best_c = None
    best_area = 0.0
    for c in cnts:
        area = float(cv2.contourArea(c))
        if area < 120.0 or area > 20000.0:
            continue
        peri = cv2.arcLength(c, True)
        if peri < 1e-3:
            continue
        circ = 4.0 * np.pi * area / (peri * peri)
        if circ < 0.30:
            continue
        if area > best_area:
            best_area = area
            best_c = c
    if best_c is None:
        return None
    (x, y), r = cv2.minEnclosingCircle(best_c)
    ri = int(round(r))
    if ri < 6 or ri > 90:
        return None
    return int(round(x)), int(round(y)), ri


def hough_circle_candidates(blurred_binary):
    """All plausible circles on the motion mask (not just the largest — that often latches onto glare)."""
    circles = cv2.HoughCircles(
        blurred_binary,
        cv2.HOUGH_GRADIENT,
        dp=1,
        minDist=28,
        param1=45,
        param2=11,
        minRadius=6,
        maxRadius=90,
    )
    if circles is None:
        return []
    out = []
    for row in circles[0]:
        x, y, r = int(round(row[0])), int(round(row[1])), int(round(row[2]))
        if 6 <= r <= 90:
            out.append((x, y, r))
    return out


def fg_centroid(mask):
    """Center of foreground motion in the lane ROI."""
    M = cv2.moments(mask)
    if M["m00"] < 35.0:
        return None
    return float(M["m10"] / M["m00"]), float(M["m01"] / M["m00"])


def lane_polygon_centroid(calibration):
    """Fallback reference when motion centroid is weak (center of calibrated trapezoid)."""
    fn = calibration["points"]["foul_line_right"]
    ff = calibration["points"]["foul_line_left"]
    pn = calibration["points"]["pin_line_right"]
    pf = calibration["points"]["pin_line_left"]
    pts = np.array([fn, ff, pf, pn], dtype=np.float64)
    return float(np.mean(pts[:, 0])), float(np.mean(pts[:, 1]))


def lane_and_approach_mask(h, w, calibration, approach_extend_px=400):
    """
    Lane surface (foul→pins) plus an approach strip *behind* the foul line so the
    ball is still inside the mask during release (it was only on the lane trapezoid before).
    """
    mask = np.zeros((h, w), dtype=np.uint8)
    fn = calibration["points"]["foul_line_right"]
    ff = calibration["points"]["foul_line_left"]
    pn = calibration["points"]["pin_line_right"]
    pf = calibration["points"]["pin_line_left"]
    foul_near = np.array(fn, dtype=np.float64)
    foul_far = np.array(ff, dtype=np.float64)
    pin_near = np.array(pn, dtype=np.float64)
    pin_far = np.array(pf, dtype=np.float64)
    foul_mid = (foul_near + foul_far) / 2.0
    pin_mid = (pin_near + pin_far) / 2.0
    to_pins = pin_mid - foul_mid
    u_len = float(np.linalg.norm(to_pins))
    if u_len > 1e-6:
        offset = -(to_pins / u_len) * float(approach_extend_px)
    else:
        offset = np.array([0.0, float(approach_extend_px)], dtype=np.float64)
    back_near = (foul_near + offset).astype(np.int32)
    back_far = (foul_far + offset).astype(np.int32)
    lane_quad = np.array(
        [list(fn), list(ff), list(pf), list(pn)], dtype=np.int32
    )
    approach_quad = np.array([back_near, back_far, foul_far, foul_near], dtype=np.int32)
    cv2.fillPoly(mask, [lane_quad], 255)
    cv2.fillPoly(mask, [approach_quad], 255)
    if LANE_MASK_DILATE_ITERATIONS > 0:
        k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
        cv2.dilate(mask, k, dst=mask, iterations=LANE_MASK_DILATE_ITERATIONS)
    return mask


def pick_nearest_candidate(candidates, px, py):
    if not candidates:
        return None
    return min(candidates, key=lambda c: (c[0] - px) ** 2 + (c[1] - py) ** 2)


def build_candidates(blurred, combined_mask):
    c_list = hough_circle_candidates(blurred)
    blob = detect_from_motion_blob(combined_mask)
    if blob is not None:
        bx, by, br = blob
        if not any(
            np.hypot(float(bx - c[0]), float(by - c[1])) < 22.0 for c in c_list
        ):
            c_list.append(blob)
    return c_list


def pick_init_measurement(candidates, motion_centroid, lane_centroid):
    """First lock: motion centroid if strong; else largest ball-sized circle near lane center."""
    if not candidates:
        return None
    if motion_centroid is not None:
        return pick_nearest_candidate(
            candidates, motion_centroid[0], motion_centroid[1]
        )
    ballish = [c for c in candidates if 10 <= c[2] <= 58]
    if ballish:
        near_lane = pick_nearest_candidate(
            ballish, lane_centroid[0], lane_centroid[1]
        )
        if near_lane is not None:
            return near_lane
    return pick_nearest_candidate(candidates, lane_centroid[0], lane_centroid[1])


def refine_ball_center(frame_bgr, mx, my, mr):
    """
    Snap measurement toward the ball’s visual center using grayscale contrast inside
    the expected disk (Hough/MOG2 centers often sit on the wrong part of the blob).
    """
    h, w = frame_bgr.shape[:2]
    ri = int(np.clip(mr, 10, 92))
    xi, yi = int(round(mx)), int(round(my))
    pad = 14
    x1 = max(0, xi - ri - pad)
    y1 = max(0, yi - ri - pad)
    x2 = min(w, xi + ri + pad)
    y2 = min(h, yi + ri + pad)
    if x2 <= x1 + 2 or y2 <= y1 + 2:
        return float(mx), float(my), float(ri)

    roi = frame_bgr[y1:y2, x1:x2]
    gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (5, 5), 0)
    cx_loc = xi - x1
    cy_loc = yi - y1
    mask = np.zeros(gray.shape, dtype=np.uint8)
    cv2.circle(mask, (cx_loc, cy_loc), ri, 255, -1)
    sel = gray[mask > 0]
    if sel.size < 30:
        return float(mx), float(my), float(ri)
    med = float(np.median(sel))
    g = gray.astype(np.float64)
    # Weight pixels that differ from local median (ball interior + edge vs lane)
    wg = np.abs(g - med) * (mask.astype(np.float64) / 255.0)
    s = float(np.sum(wg))
    if s < 1e-3:
        return float(mx), float(my), float(ri)
    idx_y, idx_x = np.indices(wg.shape)
    rx = float(np.sum(idx_x * wg) / s + x1)
    ry = float(np.sum(idx_y * wg) / s + y1)
    if np.hypot(rx - mx, ry - my) > 42.0:
        return float(mx), float(my), float(ri)
    return rx, ry, float(ri)


def smooth_positions_for_display(positions, window=9):
    """
    Moving average on the polyline for drawing only (metrics use raw `positions`).

    np.convolve(..., mode='same') implicitly pads with zeros at the ends, which pulls
    the first/last points toward (0,0) — top-left of the image — causing bogus long
    green segments toward the corner. Edge-padding fixes that.
    """
    n = len(positions)
    if n < 3:
        return positions
    w = min(window | 1, n)
    if w % 2 == 0:
        w -= 1
    w = max(w, 3)
    xs = np.array([p[0] for p in positions], dtype=np.float64)
    ys = np.array([p[1] for p in positions], dtype=np.float64)
    k = np.ones(w, dtype=np.float64) / float(w)
    pad = w // 2
    xs_s = np.convolve(np.pad(xs, (pad, pad), mode="edge"), k, mode="valid")
    ys_s = np.convolve(np.pad(ys, (pad, pad), mode="edge"), k, mode="valid")
    return [
        (int(round(xs_s[i])), int(round(ys_s[i])), positions[i][2])
        for i in range(n)
    ]


def lane_axis_feet_from_foul(bx, by, calibration):
    """
    Feet down-lane from the foul plane: project (bx,by) onto foul-mid → pin-mid and
    scale using the calibrated foul→dot distance (regulation dot row distance).
    """
    foul_m, u_hat, _, s_dot = _lane_axis_vectors(calibration)
    if foul_m is None or s_dot < 8.0:
        return None
    p = np.array([bx, by], dtype=np.float64)
    s_ball = float(np.dot(p - foul_m, u_hat))
    pixels_per_foot_axis = s_dot / float(DOT_DISTANCE_FEET)
    feet = s_ball / pixels_per_foot_axis
    return max(0.0, min(60.0, feet))


def track_ball(video_path, calibration):
    print("\n=== BALL TRACKING ===")
    print("Press Q to stop playback early.")
    print("When the video ends, the final frame (path, HUD) stays open until Q is pressed.\n")

    # load calibration values
    pixels_per_foot = calibration["pixels_per_foot"]
    foul_line_y = calibration["foul_line_y"]
    dot_line_y = calibration["dot_line_y"]
    pin_line_y = calibration["pin_line_y"]

    cap = cv2.VideoCapture(video_path)
    vfps = cap.get(cv2.CAP_PROP_FPS)
    cal_fps = float(calibration.get("fps", 30.0))
    try:
        vf_ok = float(vfps) >= 0.5 and not np.isnan(float(vfps))
    except (TypeError, ValueError):
        vf_ok = False
    if vf_ok:
        fps = float(vfps)
        fps_note = "video file metadata (CAP_PROP_FPS)"
    else:
        fps = cal_fps
        fps_note = "calibration.json (fallback — video did not report FPS)"
    print(f"  Frame rate: {fps:.3f} — from {fps_note}")
    print(
        "  Each video can differ; YouTube downloads often still carry a single FPS value in the file.\n"
    )

    # Optional YOLO: if models/ball.pt exists (or PINPOINT_BALL_MODEL), we skip MOG2 for candidates.
    weights_look_here = resolved_ball_weights_path()
    yolo_detector, yolo_fail = load_yolo_ball()
    if yolo_detector is not None:
        print(
            f"  Ball detection: YOLO ({yolo_detector.weights_path}) — PINPOINT_BALL_MODEL overrides default.\n"
        )
    else:
        print("  Ball detection: classical MOG2 + Hough.")
        if yolo_fail == "no_weights":
            print(
                f"    (YOLO skipped: no file at {weights_look_here})\n"
                "    Put trained weights there:  mkdir -p ../models && cp runs/.../best.pt ../models/ball.pt\n"
                "    Or: export PINPOINT_BALL_MODEL=/path/to/best.pt\n"
                "    Needs: pip install -r ../training/requirements-training.txt\n"
            )
        elif yolo_fail == "import_torch":
            print(
                "    (YOLO skipped: ultralytics/torch not installed)\n"
                "    Run: pip install -r ../training/requirements-training.txt\n"
            )
        elif yolo_fail:
            print(f"    (YOLO skipped: could not load weights — {yolo_fail})\n")

    detector_overlay_label = (
        f"YOLO: {yolo_detector.weights_path.name}"
        if yolo_detector is not None
        else "MOG2 + Hough"
    )

    bg_subtractor = cv2.createBackgroundSubtractorMOG2(
        history=400,
        varThreshold=32,
        detectShadows=False,
    )

    ball_positions = []
    foul_line_frame = None
    dot_line_frame = None
    foul_board = None
    dot_board = None
    arrow_board = None
    breakpoint = None
    breakpoint_feet = None
    breakpoint_board = None
    speed_mph = None
    frame_number = 0
    kalman = None
    last_r = 30
    no_meas_streak = 0
    max_pred_only_frames = 75
    # Per-frame gate: must allow fast balls; also floor so high-FPS metadata does not
    # shrink this to a few pixels and reject every real measurement.
    fps_safe = max(float(fps), 1.0)
    v_cap_ft_s = 72.0
    max_jump_px = float(pixels_per_foot) * v_cap_ft_s / fps_safe
    max_jump_px = max(32.0, min(max_jump_px, 320.0))
    # Breakpoint is computed in post-processing (min board along the path).

    kernel = np.ones((3, 3), np.uint8)
    last_display = None
    video_ended_naturally = False
    lane_centroid = lane_polygon_centroid(calibration)
    # Light temporal blend on refined centers — reduces jitter when the mask flickers
    last_meas_smooth = None
    frames_since_track = 0
    track_finished = False
    frozen_positions = []
    frozen_circle = None

    while True:
        ret, frame = cap.read()
        if not ret:
            video_ended_naturally = True
            break

        if track_finished:
            trail_draw = (
                smooth_positions_for_display(frozen_positions)
                if len(frozen_positions) > 2
                else frozen_positions
            )
            draw_overlay(
                frame,
                calibration,
                frozen_circle,
                trail_draw,
                breakpoint,
                breakpoint_feet,
                speed_mph,
                arrow_board,
                video_fps=fps,
                detector_label=detector_overlay_label,
            )
            last_display = frame.copy()
            cv2.imshow("PinPoint", frame)
            lane_view = draw_lane_view(
                ball_positions, calibration,
                breakpoint=breakpoint,
                breakpoint_board=breakpoint_board,
                speed_mph=speed_mph,
                arrow_board=arrow_board,
            )
            cv2.imshow("PinPoint — Lane View", lane_view)
            if cv2.waitKey(1) & 0xFF == ord("q"):
                break
            continue

        frame_number += 1

        h, w = frame.shape[:2]

        if yolo_detector is not None:
            # YOLO: appearance-based boxes; lane mask applied inside yolo_ball.
            candidates = yolo_detector.candidates_for_frame(frame, calibration)
            motion_centroid = None
        else:
            # Faster model update at clip start so foreground appears sooner (release area).
            learn = 0.07 if frame_number <= 55 else -1
            fg_mask = bg_subtractor.apply(frame, learningRate=learn)

            lane_mask = lane_and_approach_mask(h, w, calibration)

            combined_mask = cv2.bitwise_and(fg_mask, fg_mask, mask=lane_mask)
            combined_mask = cv2.morphologyEx(combined_mask, cv2.MORPH_OPEN, kernel)
            combined_mask = cv2.morphologyEx(combined_mask, cv2.MORPH_CLOSE, kernel)
            combined_mask = cv2.dilate(combined_mask, kernel, iterations=1)

            blurred = cv2.GaussianBlur(combined_mask, (7, 7), 1.5)
            motion_centroid = fg_centroid(combined_mask)
            candidates = build_candidates(blurred, combined_mask)

        measurement = None
        coast_pred = None

        if kalman is not None:
            coast_pred = kalman.predict()
            if candidates:
                nc = pick_nearest_candidate(
                    candidates, float(coast_pred[0, 0]), float(coast_pred[1, 0])
                )
                d = float(
                    np.hypot(
                        nc[0] - float(coast_pred[0, 0]),
                        nc[1] - float(coast_pred[1, 0]),
                    )
                )
                # Widen gate early (release noise) and later (hook: prediction can lag YOLO).
                if frame_number <= 140:
                    jump_scale = 1.55
                elif dot_line_frame is not None and frame_number >= dot_line_frame:
                    jump_scale = 1.48
                else:
                    jump_scale = 1.32
                jump_ok = max_jump_px * jump_scale
                if d <= jump_ok:
                    measurement = nc
        else:
            if candidates:
                measurement = pick_init_measurement(
                    candidates, motion_centroid, lane_centroid
                )

        draw_circle = None
        sx = sy = None

        if measurement is not None:
            no_meas_streak = 0
            mx, my, mr = measurement
            rx, ry, rr = refine_ball_center(frame, mx, my, mr)
            if last_meas_smooth is not None and frames_since_track > 7:
                a = 0.42
                rx = a * rx + (1.0 - a) * last_meas_smooth[0]
                ry = a * ry + (1.0 - a) * last_meas_smooth[1]
            last_meas_smooth = (rx, ry)
            if kalman is None:
                kalman = create_ball_kalman(float(rx), float(ry))
                frames_since_track = 0
                last_r = int(round(rr))
                sx = int(round(float(kalman.statePost[0, 0])))
                sy = int(round(float(kalman.statePost[1, 0])))
            else:
                frames_since_track += 1
                kalman.correct(
                    np.array([[float(rx)], [float(ry)]], dtype=np.float32)
                )
                last_r = int(max(6, min(90, round(rr))))
                sx = int(round(float(kalman.statePost[0, 0])))
                sy = int(round(float(kalman.statePost[1, 0])))

            ball_positions.append((sx, sy, frame_number))
            draw_circle = (sx, sy, last_r)

        elif kalman is not None:
            no_meas_streak += 1
            if no_meas_streak > max_pred_only_frames:
                kalman = None
                no_meas_streak = 0
                last_meas_smooth = None
                frames_since_track = 0
            else:
                pred = coast_pred
                sx = int(round(float(pred[0, 0])))
                sy = int(round(float(pred[1, 0])))
                kalman.statePost = pred.astype(np.float32).copy()
                kalman.errorCovPost = kalman.errorCovPre.copy()
                ball_positions.append((sx, sy, frame_number))
                draw_circle = (sx, sy, last_r)

        if sx is not None:
            if os.environ.get("PINPOINT_DEBUG_TRACK"):
                ft_dbg = lane_axis_feet_from_foul(sx, sy, calibration)
                if ft_dbg is not None and ft_dbg > 45.0:
                    mstat = "yes" if measurement is not None else "COASTING"
                    print(f"  frame {frame_number}: ft={ft_dbg:.1f}, measurement={mstat}")

            if foul_line_frame is None and is_near_line(sy, foul_line_y):
                foul_line_frame = frame_number
                foul_board = board_at_position(sx, sy, calibration)
                print(
                    f"  Ball crossed foul line at frame {frame_number} (board {foul_board})"
                )

            if foul_line_frame is not None and dot_line_frame is None:
                if is_near_line(sy, dot_line_y):
                    dot_line_frame = frame_number
                    dot_board = board_at_position(sx, sy, calibration)
                    print(
                        f"  Ball crossed dot line at frame {frame_number} (board {dot_board})"
                    )
                    if foul_line_frame is not None:
                        frames_taken = dot_line_frame - foul_line_frame
                        seconds_taken = frames_taken / fps
                        if seconds_taken > 0:
                            # Regulation 6 ft foul→dots only; not tied to 60 ft overlay extrapolation.
                            speed_fps = DOT_DISTANCE_FEET / seconds_taken
                            speed_mph = speed_fps * 0.681818
                            print(f"  Speed: {speed_mph:.1f} mph")

            if foul_line_frame is not None and arrow_board is None:
                b_h, ft_h = image_to_lane(sx, sy, calibration)
                if b_h is not None and ft_h >= arrow_feet_at_board(b_h):
                    arrow_board = round(b_h, 1)
                    print(f"  Ball crossed arrow V at frame {frame_number} (board {arrow_board})")

            if should_stop_at_pin_deck(sx, sy, foul_line_y, pin_line_y, calibration):
                track_finished = True
                frozen_positions = ball_positions.copy()
                frozen_circle = draw_circle
                kalman = None
                last_meas_smooth = None
                print(f"  Track stopped at pin deck (frame {frame_number})")

        trail_draw = (
            smooth_positions_for_display(ball_positions)
            if len(ball_positions) > 2
            else ball_positions
        )
        draw_overlay(
            frame,
            calibration,
            draw_circle,
            trail_draw,
            breakpoint,
            breakpoint_feet,
            speed_mph,
            arrow_board,
            video_fps=fps,
            detector_label=detector_overlay_label,
        )

        last_display = frame.copy()
        cv2.imshow("PinPoint", frame)

        lane_view = draw_lane_view(
            ball_positions, calibration,
            breakpoint=breakpoint,
            breakpoint_board=breakpoint_board,
            speed_mph=speed_mph,
            arrow_board=arrow_board,
        )
        cv2.imshow("PinPoint — Lane View", lane_view)

        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

    cap.release()

    # Breakpoint = min board along the path (most toward outside gutter).
    # With current numbering, board 1 is outside for both hands, so argmin works for both.
    # Trim first 30% (approach noise) and last 5% (pin deck scatter).
    if len(ball_positions) >= 10:
        n = len(ball_positions)
        start_idx = n // 3
        end_idx = max(start_idx + 1, n - max(1, n // 20))
        window = ball_positions[start_idx:end_idx]
        min_board = None
        min_bp = None
        for px, py_pos, _ in window:
            b, f = image_to_lane(px, py_pos, calibration)
            if b is not None and (min_board is None or b < min_board):
                min_board = b
                min_bp = (px, py_pos, f)
        if min_bp is not None:
            breakpoint = (min_bp[0], min_bp[1])
            breakpoint_board = round(min_board, 1)
            breakpoint_feet = min_bp[2]
            print(f"  Breakpoint: board {breakpoint_board}")

    # Post-processing: extract metrics from ball_positions if not captured during tracking.
    if ball_positions and foul_board is None:
        # Find the tracked position closest to the calibrated foul-line y.
        closest_foul = min(ball_positions, key=lambda p: abs(p[1] - foul_line_y))
        foul_board = board_at_position(closest_foul[0], closest_foul[1], calibration)
        foul_line_frame = closest_foul[2]

    if ball_positions and dot_board is None:
        # Find the tracked position closest to the calibrated dot-line y.
        closest_dot = min(ball_positions, key=lambda p: abs(p[1] - dot_line_y))
        dot_board = board_at_position(closest_dot[0], closest_dot[1], calibration)
        dot_line_frame = closest_dot[2]

    if ball_positions and arrow_board is None:
        for px, py_pos, _ in ball_positions:
            b_h, ft_h = image_to_lane(px, py_pos, calibration)
            if b_h is not None and ft_h >= arrow_feet_at_board(b_h):
                arrow_board = round(b_h, 1)
                print(f"  Arrow board (post-processed): {arrow_board}")
                break

    # Recalculate speed if we have both derived crossing frames.
    if speed_mph is None and foul_line_frame is not None and dot_line_frame is not None:
        frames_taken = abs(dot_line_frame - foul_line_frame)
        seconds_taken = frames_taken / fps
        if seconds_taken > 0:
            speed_fps = DOT_DISTANCE_FEET / seconds_taken
            speed_mph = speed_fps * 0.681818
            print(f"  Speed (post-processed): {speed_mph:.1f} mph")

    print("\n========== SHOT SUMMARY ==========")
    if speed_mph is not None:
        print(f"  Speed:            {speed_mph:.1f} mph")
    else:
        print("  Speed:            --")
    if arrow_board is not None:
        print(f"  Board @ arrows:   {arrow_board}")
    else:
        print("  Board @ arrows:   --")
    if breakpoint_board is not None:
        print(f"  Breakpoint board: {breakpoint_board}")
    else:
        print("  Breakpoint board: --")
    print("===================================\n")

    if video_ended_naturally and last_display is not None:
        final_lane_view = draw_lane_view(
            ball_positions, calibration,
            breakpoint=breakpoint,
            breakpoint_board=breakpoint_board,
            speed_mph=speed_mph,
            arrow_board=arrow_board,
        )
        cv2.imshow("PinPoint — Lane View", final_lane_view)
        print("Final frame on screen — press Q to exit.")
        while True:
            cv2.imshow("PinPoint", last_display)
            cv2.imshow("PinPoint — Lane View", final_lane_view)
            if cv2.waitKey(50) & 0xFF == ord("q"):
                break

    cv2.destroyAllWindows()
    print("\nTracking complete.")


def is_near_line(y, line_y, threshold=15):
    return abs(y - line_y) < threshold


def ball_reached_pin_deck(sy, foul_line_y, pin_line_y, margin=8.0):
    """
    True when the ball center has crossed the calibrated pin-deck line toward the pins.
    Uses relative position of foul vs pin row in the image (works for typical angles).
    margin is extra pixels past the pin line (toward pins) before counting as crossed.
    """
    if pin_line_y < foul_line_y:
        return sy <= pin_line_y - margin
    return sy >= pin_line_y + margin


def should_stop_at_pin_deck(sx, sy, foul_line_y, pin_line_y, calibration):
    """
    Stop when ball y crosses pin_line_y toward the pins.
    foul_line_y > pin_line_y means pins are at top of frame (y decreases toward pins).
    margin_frac scales a pixel margin: larger = require ball farther past the line (stop later).
    """
    margin = (abs(foul_line_y - pin_line_y)) * 0.02
    if pin_line_y < foul_line_y:
        return sy <= pin_line_y - margin
    return sy >= pin_line_y + margin


def _world_to_image(H, x_ft, y_ft):
    pts = np.array([[[x_ft, y_ft]]], dtype=np.float32)
    out = cv2.perspectiveTransform(pts, H)
    return float(out[0, 0, 0]), float(out[0, 0, 1])


def _lane_world_to_image_homography(calibration):
    """
    Map regulation lane plane (feet) → image pixels.

    World axes: x across the lane (0 = far / board 1 side, W = near / board 60),
    y down-lane from the foul line (0 = foul, d = dot row, L = pin deck).

    **Six-point homography** (foul, dot, and pin lines): avoids extrapolating from
    a 6 ft baseline out to 60 ft, which magnifies click error on foot markers.
    """
    W = float(LANE_WIDTH_INCHES) / 12.0
    d = float(DOT_DISTANCE_FEET)
    L = float(LANE_LENGTH_FEET)

    ff = np.array(calibration["points"]["foul_line_left"], dtype=np.float32)
    fn = np.array(calibration["points"]["foul_line_right"], dtype=np.float32)
    df = np.array(calibration["points"]["dot_line_left"], dtype=np.float32)
    dn = np.array(calibration["points"]["dot_line_right"], dtype=np.float32)
    pf = np.array(calibration["points"]["pin_line_left"], dtype=np.float32)
    pn = np.array(calibration["points"]["pin_line_right"], dtype=np.float32)

    world = np.array(
        [
            [0.0, 0.0],
            [W, 0.0],
            [0.0, d],
            [W, d],
            [0.0, L],
            [W, L],
        ],
        dtype=np.float32,
    )
    img = np.array([ff, fn, df, dn, pf, pn], dtype=np.float32)

    H, _ = cv2.findHomography(world, img, method=0)
    if H is None:
        world4 = world[:4].copy()
        img4 = img[:4].copy()
        H = cv2.getPerspectiveTransform(world4, img4)
    return H


def _interpolate_lane_edge(calibration, y_ft):
    """
    For distance down the lane (feet), interpolate near/far image positions from the
    six clicked calibration points (linear between foul row at 0 ft and pin row at 60 ft).
    Returns (far_pt, near_pt) as length-2 float arrays (x, y) in pixels — far = board 1
    side, near = board 60 side.
    """
    L = float(LANE_LENGTH_FEET)
    t = float(np.clip(y_ft / L, 0.0, 1.0))

    fn = np.array(calibration["points"]["foul_line_right"], dtype=np.float64)
    ff = np.array(calibration["points"]["foul_line_left"], dtype=np.float64)
    pn = np.array(calibration["points"]["pin_line_right"], dtype=np.float64)
    pf = np.array(calibration["points"]["pin_line_left"], dtype=np.float64)

    near = fn + t * (pn - fn)
    far = ff + t * (pf - ff)
    return far, near


def _lane_row_segment(H, y_ft, calibration=None):
    """Transverse segment at y_ft (feet): interpolated from clicks if calibration given, else homography."""
    if calibration is not None:
        far_pt, near_pt = _interpolate_lane_edge(calibration, y_ft)
        return (
            (int(round(far_pt[0])), int(round(far_pt[1]))),
            (int(round(near_pt[0])), int(round(near_pt[1]))),
        )
    W = float(LANE_WIDTH_INCHES) / 12.0
    x0, y0 = _world_to_image(H, 0.0, y_ft)
    x1, y1 = _world_to_image(H, W, y_ft)
    return (int(round(x0)), int(round(y0))), (int(round(x1)), int(round(y1)))


def _draw_detector_badge(frame, label: str) -> None:
    """Top-right corner: which ball-detection backend is active."""
    fh, fw = frame.shape[0], frame.shape[1]
    font = cv2.FONT_HERSHEY_SIMPLEX
    scale = 0.5
    thickness = 1
    (tw, th), baseline = cv2.getTextSize(label, font, scale, thickness)
    pad_x, pad_y = 8, 6
    x2 = fw - 10
    x1 = max(0, x2 - tw - 2 * pad_x)
    y1 = 10
    y2 = y1 + th + baseline + 2 * pad_y
    cv2.rectangle(frame, (x1, y1), (x2, y2), (45, 45, 45), -1)
    cv2.rectangle(frame, (x1, y1), (x2, y2), (120, 120, 120), 1)
    cv2.putText(
        frame,
        label,
        (x1 + pad_x, y2 - pad_y - baseline),
        font,
        scale,
        (235, 235, 235),
        thickness,
        cv2.LINE_AA,
    )


def draw_lane_view(
    ball_positions,
    calibration,
    breakpoint=None,
    breakpoint_board=None,
    speed_mph=None,
    arrow_board=None,
    canvas_w=340,
    canvas_h=780,
):
    """Top-down 2D lane diagram: foul at bottom, pins at top, board 1 on the right."""
    canvas = np.zeros((canvas_h, canvas_w, 3), dtype=np.uint8)
    canvas[:] = (30, 30, 30)

    margin_x = 40
    margin_top = 30
    margin_bottom = 80
    lane_w = canvas_w - 2 * margin_x
    lane_h = canvas_h - margin_top - margin_bottom

    # lane surface
    cv2.rectangle(canvas, (margin_x, margin_top),
                  (margin_x + lane_w, margin_top + lane_h), (210, 180, 140), -1)

    # gutters
    cv2.rectangle(canvas, (margin_x - 8, margin_top),
                  (margin_x, margin_top + lane_h), (80, 80, 80), -1)
    cv2.rectangle(canvas, (margin_x + lane_w, margin_top),
                  (margin_x + lane_w + 8, margin_top + lane_h), (80, 80, 80), -1)

    def board_to_x(board):
        t = (board - 1) / 38.0
        return int(margin_x + lane_w * (1.0 - t))

    def feet_to_y(feet):
        t = feet / 60.0
        return int(margin_top + lane_h * (1.0 - t))

    # board lines every 5 boards
    for b in range(5, 39, 5):
        bx = board_to_x(b)
        cv2.line(canvas, (bx, margin_top), (bx, margin_top + lane_h), (180, 160, 120), 1)
        cv2.putText(canvas, str(b), (bx - 6, margin_top + lane_h + 14),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.35, (180, 180, 180), 1)

    # foul line (0 ft)
    fy = feet_to_y(0)
    cv2.line(canvas, (margin_x, fy), (margin_x + lane_w, fy), (0, 255, 255), 2)
    cv2.putText(canvas, "Foul", (margin_x + lane_w + 2, fy + 4),
                cv2.FONT_HERSHEY_SIMPLEX, 0.35, (0, 255, 255), 1)

    # dot line (6 ft)
    dy = feet_to_y(6)
    cv2.line(canvas, (margin_x, dy), (margin_x + lane_w, dy), (0, 165, 255), 1)
    cv2.putText(canvas, "Dots", (margin_x + lane_w + 2, dy + 4),
                cv2.FONT_HERSHEY_SIMPLEX, 0.35, (0, 165, 255), 1)

    # arrow V — 7 arrows at boards 5,10,15,20,25,30,35
    _arrow_boards = [5, 10, 15, 20, 25, 30, 35]
    arrow_pts = []
    for ab in _arrow_boards:
        ax = board_to_x(ab)
        af = arrow_feet_at_board(ab)
        ay2 = feet_to_y(af)
        arrow_pts.append((ax, ay2))
    for i in range(1, len(arrow_pts)):
        cv2.line(canvas, arrow_pts[i - 1], arrow_pts[i], (200, 200, 100), 1)
    for ax, ay2 in arrow_pts:
        tri = np.array([
            [ax, ay2 - 5],
            [ax - 4, ay2 + 4],
            [ax + 4, ay2 + 4],
        ], dtype=np.int32)
        cv2.fillPoly(canvas, [tri], (200, 200, 100))
    cv2.putText(canvas, "Arrows", (margin_x + lane_w + 2, arrow_pts[3][1] + 4),
                cv2.FONT_HERSHEY_SIMPLEX, 0.35, (200, 200, 100), 1)

    # pin line (60 ft)
    py = feet_to_y(60)
    cv2.line(canvas, (margin_x, py), (margin_x + lane_w, py), (0, 200, 0), 2)
    cv2.putText(canvas, "Pins", (margin_x + lane_w + 2, py + 4),
                cv2.FONT_HERSHEY_SIMPLEX, 0.35, (0, 200, 0), 1)

    # ball path (perspective-correct via homography, smoothed)
    if len(ball_positions) >= 2:
        raw_boards = []
        raw_feet = []
        for px, py_pos, _ in ball_positions:
            board, ft = image_to_lane(px, py_pos, calibration)
            if board is not None:
                raw_boards.append(board)
                raw_feet.append(ft)
        if len(raw_boards) >= 3:
            w = min(11, len(raw_boards) // 2 * 2 + 1)
            if w % 2 == 0:
                w -= 1
            w = max(3, w)
            pad = w // 2
            k = np.ones(w) / float(w)
            sb = np.convolve(np.pad(raw_boards, (pad, pad), mode="edge"), k, mode="valid")
            sf = np.convolve(np.pad(raw_feet, (pad, pad), mode="edge"), k, mode="valid")
            pts = [(board_to_x(sb[i]), feet_to_y(sf[i])) for i in range(len(sb))]
        else:
            pts = [(board_to_x(raw_boards[i]), feet_to_y(raw_feet[i]))
                   for i in range(len(raw_boards))]
        for i in range(1, len(pts)):
            cv2.line(canvas, pts[i - 1], pts[i], (0, 255, 0), 2)

    # arrow board marker — on the ball's path at the V crossing
    if arrow_board is not None:
        abx = board_to_x(arrow_board)
        afy = feet_to_y(arrow_feet_at_board(arrow_board))
        cv2.circle(canvas, (abx, afy), 5, (200, 200, 100), -1)
        cv2.putText(canvas, f"Bd {arrow_board}", (abx + 6, afy - 4),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.35, (200, 200, 100), 1)

    # breakpoint marker (perspective-correct via homography)
    if breakpoint is not None and breakpoint_board is not None:
        bx_bp, by_bp = breakpoint
        bp_board_h, ft_bp = image_to_lane(bx_bp, by_bp, calibration)
        if bp_board_h is not None:
            vx = board_to_x(breakpoint_board)
            vy = feet_to_y(ft_bp)
            cv2.circle(canvas, (vx, vy), 7, (255, 0, 255), -1)
            cv2.putText(canvas, f"BP {breakpoint_board}", (vx + 8, vy),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.38, (255, 0, 255), 1)

    # HUD below board numbers
    hud_y = margin_top + lane_h + 30
    if speed_mph is not None:
        cv2.putText(canvas, f"{speed_mph:.1f} mph", (margin_x, hud_y),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
    if arrow_board is not None:
        cv2.putText(canvas, f"Arrows: {arrow_board:.1f}", (margin_x, hud_y + 18),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, (200, 200, 100), 1)
    if breakpoint_board is not None:
        cv2.putText(canvas, f"BP: {breakpoint_board:.1f}", (margin_x, hud_y + 36),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 0, 255), 1)

    return canvas


def draw_overlay(
    frame,
    calibration,
    circle,
    positions,
    breakpoint,
    breakpoint_feet,
    speed_mph,
    arrow_board,
    video_fps=None,
    detector_label: str = "MOG2 + Hough",
):
    _draw_detector_badge(frame, detector_label)

    # Foul line — drawn directly from clicked points
    foul_near = tuple(map(int, calibration["points"]["foul_line_right"]))
    foul_far = tuple(map(int, calibration["points"]["foul_line_left"]))
    cv2.line(frame, foul_near, foul_far, (0, 255, 255), 2)
    lx, ly = foul_near
    cv2.putText(
        frame,
        "Foul Line",
        (lx + 10, ly),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.5,
        (0, 255, 255),
        1,
    )

    # Dot line — drawn directly from clicked points
    dot_near = tuple(map(int, calibration["points"]["dot_line_right"]))
    dot_far = tuple(map(int, calibration["points"]["dot_line_left"]))
    cv2.line(frame, dot_near, dot_far, (0, 165, 255), 2)
    lx, ly = dot_near
    cv2.putText(
        frame,
        "Dots (6 ft)",
        (lx + 10, ly),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.5,
        (0, 165, 255),
        1,
    )

    # Pin line — drawn directly from clicked points
    pin_near = tuple(map(int, calibration["points"]["pin_line_right"]))
    pin_far = tuple(map(int, calibration["points"]["pin_line_left"]))
    cv2.line(frame, pin_near, pin_far, (0, 200, 0), 2)
    lx, ly = pin_near
    cv2.putText(
        frame,
        "Pins (60 ft)",
        (lx + 10, ly),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.5,
        (0, 200, 0),
        1,
    )

    for i in range(1, len(positions)):
        cv2.line(
            frame,
            (positions[i - 1][0], positions[i - 1][1]),
            (positions[i][0], positions[i][1]),
            (0, 255, 0),
            2,
        )

    if video_fps is not None:
        fh, fw = frame.shape[0], frame.shape[1]
        cv2.putText(
            frame,
            f"FPS {video_fps:.2f}",
            (fw - 130, fh - 14),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.55,
            (200, 200, 200),
            1,
        )

    if circle is not None:
        x, y, r = circle
        cv2.circle(frame, (x, y), r, (0, 255, 0), 3)
        cv2.circle(frame, (x, y), 3, (0, 0, 255), -1)

    if breakpoint is not None:
        bx, by = breakpoint[0], breakpoint[1]
        cv2.circle(frame, (bx, by), 10, (255, 0, 255), -1)
        label = "Breakpoint"
        if breakpoint_feet is not None:
            label = f"Breakpoint ~{breakpoint_feet:.1f} ft"
        cv2.putText(
            frame,
            label,
            (bx + 12, by),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            (255, 0, 255),
            2,
        )

    hud_y = 30
    if speed_mph is not None:
        cv2.putText(
            frame,
            f"Speed: {speed_mph:.1f} mph",
            (20, hud_y),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            (255, 255, 255),
            2,
        )
        hud_y += 35
    if arrow_board is not None:
        cv2.putText(
            frame,
            f"Board @ arrows: {arrow_board:.1f}",
            (20, hud_y),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.7,
            (255, 255, 255),
            2,
        )
        hud_y += 32
