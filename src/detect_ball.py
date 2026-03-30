import cv2
import numpy as np

from calibration import DOT_DISTANCE_FEET

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
    # Balance: trust measurements enough to follow the ball; smooth velocity a bit
    kf.processNoiseCov = np.eye(4, dtype=np.float32) * 7e-3
    kf.measurementNoiseCov = np.eye(2, dtype=np.float32) * 36.0
    kf.errorCovPost = np.eye(4, dtype=np.float32)
    kf.statePost = np.array(
        [[init_x], [init_y], [0.0], [0.0]], dtype=np.float32
    )
    return kf


def board_from_ball_on_line(bx, by, far_pt, near_pt):
    """
    Board 1 at far edge, board 60 at near edge (regulation numbering).
    far_pt / near_pt are (x, y) image coordinates for that line's endpoints.
    """
    far = np.array(far_pt, dtype=np.float64)
    near = np.array(near_pt, dtype=np.float64)
    p = np.array([bx, by], dtype=np.float64)
    w = near - far
    w_len2 = float(np.dot(w, w))
    if w_len2 < 1e-6:
        return 30
    t = float(np.dot(p - far, w) / w_len2)
    t = max(0.0, min(1.0, t))
    board = int(round(1.0 + t * 59.0))
    return max(1, min(60, board))


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


def _lane_axis_vectors(calibration):
    """
    Foul-line midpoint, unit vector toward pins (pin midpoint), and scalar projection
    (pixels) from foul midpoint to dot midpoint along that axis — used for scale.
    """
    fn = np.array(calibration["points"]["foul_line_near"], dtype=np.float64)
    ff = np.array(calibration["points"]["foul_line_far"], dtype=np.float64)
    pn = np.array(calibration["points"]["pin_line_near"], dtype=np.float64)
    pf = np.array(calibration["points"]["pin_line_far"], dtype=np.float64)
    dn = np.array(calibration["points"]["dot_line_near"], dtype=np.float64)
    df = np.array(calibration["points"]["dot_line_far"], dtype=np.float64)
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
    fn = calibration["points"]["foul_line_near"]
    ff = calibration["points"]["foul_line_far"]
    pn = calibration["points"]["pin_line_near"]
    pf = calibration["points"]["pin_line_far"]
    pts = np.array([fn, ff, pf, pn], dtype=np.float64)
    return float(np.mean(pts[:, 0])), float(np.mean(pts[:, 1]))


def lane_and_approach_mask(h, w, calibration, approach_extend_px=400):
    """
    Lane surface (foul→pins) plus an approach strip *behind* the foul line so the
    ball is still inside the mask during release (it was only on the lane trapezoid before).
    """
    mask = np.zeros((h, w), dtype=np.uint8)
    fn = calibration["points"]["foul_line_near"]
    ff = calibration["points"]["foul_line_far"]
    pn = calibration["points"]["pin_line_near"]
    pf = calibration["points"]["pin_line_far"]
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
    print("When the video ends, the final frame (path, HUD) stays until you press Q.\n")

    # load calibration values
    pixels_per_foot = calibration["pixels_per_foot"]
    foul_line_y = calibration["foul_line_y"]
    dot_line_y = calibration["dot_line_y"]
    pin_line_y = calibration["pin_line_y"]
    foul_near_pt = calibration["points"]["foul_line_near"]
    foul_far_pt = calibration["points"]["foul_line_far"]
    dot_near_pt = calibration["points"]["dot_line_near"]
    dot_far_pt = calibration["points"]["dot_line_far"]

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
    breakpoint = None
    breakpoint_feet = None
    speed_mph = None
    frame_number = 0
    kalman = None
    last_r = 30
    no_meas_streak = 0
    max_pred_only_frames = 20
    # Per-frame gate: must allow fast balls; also floor so high-FPS metadata does not
    # shrink this to a few pixels and reject every real measurement.
    fps_safe = max(float(fps), 1.0)
    v_cap_ft_s = 62.0
    max_jump_px = float(pixels_per_foot) * v_cap_ft_s / fps_safe
    max_jump_px = max(24.0, min(max_jump_px, 180.0))
    # Breakpoint: lateral hook change — only after ball reaches dot row (avoids early noise)
    bp_tracker = BreakpointTracker(persist_frames=6, dx_eps=1.0)

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
                foul_board,
                dot_board,
                video_fps=fps,
            )
            last_display = frame.copy()
            cv2.imshow("PinPoint", frame)
            if cv2.waitKey(1) & 0xFF == ord("q"):
                break
            continue

        frame_number += 1

        # Faster model update at clip start so foreground appears sooner (release area).
        learn = 0.07 if frame_number <= 55 else -1
        fg_mask = bg_subtractor.apply(frame, learningRate=learn)

        h, w = frame.shape[:2]
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
                # Early clip: MOG2 + swing are noisy — allow a wider catch-up to the ball.
                jump_ok = max_jump_px * (
                    1.28 if frame_number <= 140 else 1.0
                )
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
                a = 0.76
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
            if foul_line_frame is None and is_near_line(sy, foul_line_y):
                foul_line_frame = frame_number
                foul_board = board_from_ball_on_line(
                    sx, sy, foul_far_pt, foul_near_pt
                )
                print(
                    f"  Ball crossed foul line at frame {frame_number} (board {foul_board})"
                )

            if foul_line_frame is not None and dot_line_frame is None:
                if is_near_line(sy, dot_line_y):
                    dot_line_frame = frame_number
                    dot_board = board_from_ball_on_line(
                        sx, sy, dot_far_pt, dot_near_pt
                    )
                    print(
                        f"  Ball crossed dot line at frame {frame_number} (board {dot_board})"
                    )
                    if foul_line_frame is not None:
                        frames_taken = dot_line_frame - foul_line_frame
                        seconds_taken = frames_taken / fps
                        if seconds_taken > 0:
                            speed_fps = DOT_DISTANCE_FEET / seconds_taken
                            speed_mph = speed_fps * 0.681818
                            print(f"  Speed: {speed_mph:.1f} mph")

            new_bp = (
                bp_tracker.update(ball_positions)
                if dot_line_frame is not None
                else None
            )
            if new_bp is not None and breakpoint is None:
                breakpoint = new_bp
                breakpoint_feet = lane_axis_feet_from_foul(
                    new_bp[0], new_bp[1], calibration
                )
                if breakpoint_feet is not None:
                    print(
                        f"  Breakpoint (~{breakpoint_feet:.1f} ft from foul)"
                    )

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
            foul_board,
            dot_board,
            video_fps=fps,
        )

        last_display = frame.copy()
        cv2.imshow("PinPoint", frame)

        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

    cap.release()

    if video_ended_naturally and last_display is not None:
        print("\nVideo ended — final frame (path, HUD) stays open. Press Q to exit.")
        while True:
            cv2.imshow("PinPoint", last_display)
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
    Small margin = stop closer to the real deck (large margin was stopping too early).
    """
    if pin_line_y < foul_line_y:
        return sy <= pin_line_y + margin
    return sy >= pin_line_y - margin


def should_stop_at_pin_deck(sx, sy, foul_line_y, pin_line_y, calibration):
    """
    Require both: far enough down-lane (feet) and pin-line crossing — avoids early cutoffs
    when pin_line_y is miscalibrated or margin was too loose.
    """
    crossed = ball_reached_pin_deck(sy, foul_line_y, pin_line_y, margin=6.0)
    ft = lane_axis_feet_from_foul(sx, sy, calibration)
    if ft is not None:
        return crossed and ft >= 47.0
    return crossed


def draw_overlay(
    frame,
    calibration,
    circle,
    positions,
    breakpoint,
    breakpoint_feet,
    speed_mph,
    foul_board,
    dot_board,
    video_fps=None,
):
    foul_near = calibration["points"]["foul_line_near"]
    foul_far = calibration["points"]["foul_line_far"]
    pin_near = calibration["points"]["pin_line_near"]
    pin_far = calibration["points"]["pin_line_far"]
    dot_near = calibration["points"]["dot_line_near"]
    dot_far = calibration["points"]["dot_line_far"]

    cv2.line(frame, tuple(foul_near), tuple(foul_far), (0, 255, 255), 2)
    cv2.putText(
        frame,
        "Foul Line",
        (foul_near[0] + 10, foul_near[1]),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.5,
        (0, 255, 255),
        1,
    )

    cv2.line(frame, tuple(dot_near), tuple(dot_far), (0, 165, 255), 2)
    cv2.putText(
        frame,
        "Dots (6 ft)",
        (dot_near[0] + 10, dot_near[1]),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.5,
        (0, 165, 255),
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
    if foul_board is not None:
        cv2.putText(
            frame,
            f"Board @ foul: {foul_board}",
            (20, hud_y),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.7,
            (255, 255, 255),
            2,
        )
        hud_y += 32
    if dot_board is not None:
        cv2.putText(
            frame,
            f"Board @ dots: {dot_board}",
            (20, hud_y),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.7,
            (255, 255, 255),
            2,
        )
        hud_y += 32
