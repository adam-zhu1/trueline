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
    kf.processNoiseCov = np.eye(4, dtype=np.float32) * 5e-3
    # Higher = smoother track, less snap to noisy Hough centers (reflections / jitter)
    kf.measurementNoiseCov = np.eye(2, dtype=np.float32) * 64.0
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
        if area < 350.0 or area > 14000.0:
            continue
        peri = cv2.arcLength(c, True)
        if peri < 1e-3:
            continue
        circ = 4.0 * np.pi * area / (peri * peri)
        if circ < 0.48:
            continue
        if area > best_area:
            best_area = area
            best_c = c
    if best_c is None:
        return None
    (x, y), r = cv2.minEnclosingCircle(best_c)
    ri = int(round(r))
    if ri < 12 or ri > 75:
        return None
    return int(round(x)), int(round(y)), ri


def detect_from_hough(blurred_binary):
    circles = cv2.HoughCircles(
        blurred_binary,
        cv2.HOUGH_GRADIENT,
        dp=1,
        minDist=45,
        param1=55,
        param2=22,
        minRadius=12,
        maxRadius=78,
    )
    if circles is None:
        return None
    circles = np.round(circles[0, :]).astype("int")
    valid = [(x, y, r) for (x, y, r) in circles if 12 <= r <= 72]
    if not valid:
        return None
    return max(valid, key=lambda c: c[2])


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
    fps = calibration["fps"]
    pixels_per_foot = calibration["pixels_per_foot"]
    foul_line_y = calibration["foul_line_y"]
    dot_line_y = calibration["dot_line_y"]
    foul_near_pt = calibration["points"]["foul_line_near"]
    foul_far_pt = calibration["points"]["foul_line_far"]
    dot_near_pt = calibration["points"]["dot_line_near"]
    dot_far_pt = calibration["points"]["dot_line_far"]

    cap = cv2.VideoCapture(video_path)

    bg_subtractor = cv2.createBackgroundSubtractorMOG2(
        history=500,
        varThreshold=64,
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
    # Cap per-frame jump ~38 ft/s along lane (~26 mph) to reject spurious jumps ahead
    v_cap_ft_s = 38.0
    max_jump_px = min(
        max(55.0, 4.0 * float(pixels_per_foot)),
        float(pixels_per_foot) * v_cap_ft_s / max(float(fps), 1.0),
    )
    # Breakpoint: lateral hook change — only after ball reaches dot row (avoids early noise)
    bp_tracker = BreakpointTracker(persist_frames=6, dx_eps=1.0)
    # Past foul plane (px along lane axis); real track also needs motion chain below
    past_foul_min_along_px = 4.0
    init_chain_len = 4
    init_max_step_px = 44.0
    init_min_along_delta_px = 8.0

    kernel = np.ones((5, 5), np.uint8)
    last_display = None
    video_ended_naturally = False
    init_buffer = []

    while True:
        ret, frame = cap.read()
        if not ret:
            video_ended_naturally = True
            break

        frame_number += 1

        fg_mask = bg_subtractor.apply(frame)

        lane_mask = np.zeros(frame.shape[:2], dtype=np.uint8)
        foul_near = calibration["points"]["foul_line_near"]
        foul_far = calibration["points"]["foul_line_far"]
        pin_near = calibration["points"]["pin_line_near"]
        pin_far = calibration["points"]["pin_line_far"]

        lane_corners = np.array(
            [foul_near, foul_far, pin_far, pin_near], dtype=np.int32
        )
        cv2.fillPoly(lane_mask, [lane_corners], 255)

        combined_mask = cv2.bitwise_and(fg_mask, fg_mask, mask=lane_mask)
        combined_mask = cv2.morphologyEx(combined_mask, cv2.MORPH_OPEN, kernel)
        combined_mask = cv2.morphologyEx(combined_mask, cv2.MORPH_CLOSE, kernel)

        blurred = cv2.GaussianBlur(combined_mask, (9, 9), 2)
        best_circle = detect_from_motion_blob(combined_mask)
        if best_circle is None:
            best_circle = detect_from_hough(blurred)

        draw_circle = None
        sx = sy = None

        if best_circle is not None:
            no_meas_streak = 0
            mx, my, mr = best_circle
            along = ball_along_lane_px(mx, my, calibration)
            if along is None:
                along = -1e9

            if kalman is None:
                if along < past_foul_min_along_px:
                    init_buffer.clear()
                else:
                    if not init_buffer:
                        init_buffer.append((mx, my, mr))
                    else:
                        lx, ly, _ = init_buffer[-1]
                        if np.hypot(mx - lx, my - ly) <= init_max_step_px:
                            init_buffer.append((mx, my, mr))
                        else:
                            init_buffer = [(mx, my, mr)]
                    while len(init_buffer) > init_chain_len:
                        init_buffer.pop(0)
                    if len(init_buffer) >= init_chain_len:
                        x0, y0, _ = init_buffer[0]
                        x1, y1, mr1 = init_buffer[-1]
                        a0 = ball_along_lane_px(x0, y0, calibration)
                        a1 = ball_along_lane_px(x1, y1, calibration)
                        if (
                            a0 is not None
                            and a1 is not None
                            and (a1 - a0) >= init_min_along_delta_px
                        ):
                            kalman = create_ball_kalman(float(x1), float(y1))
                            last_r = int(mr1)
                            init_buffer.clear()
                            print(f"  Track started at frame {frame_number} (motion confirmed)")
                            sx = int(round(float(kalman.statePost[0, 0])))
                            sy = int(round(float(kalman.statePost[1, 0])))
                            ball_positions.append((sx, sy, frame_number))
                            draw_circle = (sx, sy, last_r)
                        else:
                            init_buffer.pop(0)
            else:
                pred = kalman.predict()
                pred_x = float(pred[0, 0])
                pred_y = float(pred[1, 0])
                dist = np.hypot(float(mx) - pred_x, float(my) - pred_y)
                if dist <= max_jump_px:
                    kalman.correct(
                        np.array([[float(mx)], [float(my)]], dtype=np.float32)
                    )
                    last_r = int(mr)
                    sx = int(round(float(kalman.statePost[0, 0])))
                    sy = int(round(float(kalman.statePost[1, 0])))
                else:
                    sx = int(round(pred_x))
                    sy = int(round(pred_y))
                    kalman.statePost = pred.astype(np.float32).copy()
                    kalman.errorCovPost = kalman.errorCovPre.copy()

                ball_positions.append((sx, sy, frame_number))
                draw_circle = (sx, sy, last_r)

        elif kalman is not None:
            no_meas_streak += 1
            if no_meas_streak > max_pred_only_frames:
                kalman = None
                no_meas_streak = 0
                init_buffer.clear()
            else:
                pred = kalman.predict()
                sx = int(round(float(pred[0, 0])))
                sy = int(round(float(pred[1, 0])))
                kalman.statePost = pred.astype(np.float32).copy()
                kalman.errorCovPost = kalman.errorCovPre.copy()
                ball_positions.append((sx, sy, frame_number))
                draw_circle = (sx, sy, last_r)
        else:
            init_buffer.clear()

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

        draw_overlay(
            frame,
            calibration,
            draw_circle,
            ball_positions,
            breakpoint,
            breakpoint_feet,
            speed_mph,
            foul_board,
            dot_board,
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
