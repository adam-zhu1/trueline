import cv2
import numpy as np
import json

def track_ball(video_path, calibration):
    print("\n=== BALL TRACKING ===")
    print("Press Q to stop playback early.")
    print("When the video ends, the last frame (path, HUD) stays until you press Q.\n")

    # load calibration values
    fps = calibration['fps']
    pixels_per_foot = calibration['pixels_per_foot']
    pixels_per_board = calibration['pixels_per_board']
    foul_line_y = calibration['foul_line_y']
    arrow_line_y = calibration['arrow_line_y']
    pin_line_y = calibration['pin_line_y']
    foul_near_x = calibration['foul_line_near_x']
    foul_far_x = calibration['foul_line_far_x']

    # figure out which direction the lane goes
    # (is near edge on left or right side of frame?)
    lane_goes_right = foul_far_x > foul_near_x

    # open video
    cap = cv2.VideoCapture(video_path)

    # background subtractor
    bg_subtractor = cv2.createBackgroundSubtractorMOG2(
        history=500,
        varThreshold=50,
        detectShadows=False
    )

    # tracking state
    ball_positions = []         # list of (x, y, frame_number)
    foul_line_frame = None      # frame when ball crossed foul line
    arrow_line_frame = None     # frame when ball crossed arrow line
    breakpoint = None           # (x, y) of breakpoint
    speed_mph = None            # calculated speed
    frame_number = 0

    kernel = np.ones((5, 5), np.uint8)
    last_display = None
    video_ended_naturally = False

    while True:
        ret, frame = cap.read()
        if not ret:
            video_ended_naturally = True
            break

        frame_number += 1

        # Step 1: background subtraction
        fg_mask = bg_subtractor.apply(frame)

        # Step 2: build lane mask using calibration points
        # we define the valid tracking zone as between foul line and pins
        # and between near and far edges
        lane_mask = np.zeros(frame.shape[:2], dtype=np.uint8)

        # define trapezoid from calibration points
        foul_near = calibration['points']['foul_line_near']
        foul_far = calibration['points']['foul_line_far']
        pin_near = calibration['points']['pin_line_near']
        pin_far = calibration['points']['pin_line_far']

        lane_corners = np.array([
            foul_near,
            foul_far,
            pin_far,
            pin_near
        ], dtype=np.int32)

        cv2.fillPoly(lane_mask, [lane_corners], 255)

        # Step 3: combine masks
        combined_mask = cv2.bitwise_and(fg_mask, fg_mask, mask=lane_mask)

        # Step 4: clean up
        combined_mask = cv2.morphologyEx(combined_mask, cv2.MORPH_OPEN, kernel)
        combined_mask = cv2.morphologyEx(combined_mask, cv2.MORPH_CLOSE, kernel)

        # Step 5: detect circles
        blurred = cv2.GaussianBlur(combined_mask, (9, 9), 2)
        circles = cv2.HoughCircles(
            blurred,
            cv2.HOUGH_GRADIENT,
            dp=1,
            minDist=50,
            param1=50,
            param2=15,
            minRadius=15,
            maxRadius=80
        )

        # Step 6: find best circle (closest to expected ball size)
        best_circle = None
        if circles is not None:
            circles = np.round(circles[0, :]).astype("int")
            # filter by size and pick the most confident one
            valid = [(x, y, r) for (x, y, r) in circles if 15 <= r <= 60]
            if valid:
                # pick the largest valid circle (most likely the ball)
                best_circle = max(valid, key=lambda c: c[2])

        # Step 7: record position and calculate metrics
        if best_circle is not None:
            x, y, r = best_circle
            ball_positions.append((x, y, frame_number))

            # check if ball just crossed foul line
            if foul_line_frame is None and is_near_line(y, foul_line_y):
                foul_line_frame = frame_number
                print(f"  Ball crossed foul line at frame {frame_number}")

            # check if ball just crossed arrow line
            if foul_line_frame is not None and arrow_line_frame is None:
                if is_near_line(y, arrow_line_y):
                    arrow_line_frame = frame_number

                    # calculate speed
                    if foul_line_frame is not None:
                        frames_taken = arrow_line_frame - foul_line_frame
                        seconds_taken = frames_taken / fps
                        if seconds_taken > 0:
                            speed_fps = ARROW_DISTANCE_FEET / seconds_taken
                            speed_mph = speed_fps * 0.681818
                            print(f"  Speed: {speed_mph:.1f} mph")

            # detect breakpoint (direction change in x)
            if len(ball_positions) >= 10:
                breakpoint = detect_breakpoint(ball_positions)

        # Step 8: draw everything
        draw_overlay(
            frame, calibration, best_circle,
            ball_positions, breakpoint, speed_mph
        )

        last_display = frame.copy()
        cv2.imshow("PinPoint", frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()

    if video_ended_naturally and last_display is not None:
        print("\nVideo ended — final frame (path, HUD) stays open. Press Q to exit.")
        while True:
            cv2.imshow("PinPoint", last_display)
            if cv2.waitKey(50) & 0xFF == ord('q'):
                break

    cv2.destroyAllWindows()
    print("\nTracking complete.")

def is_near_line(y, line_y, threshold=15):
    """check if a y coordinate is close to a reference line"""
    return abs(y - line_y) < threshold

def detect_breakpoint(positions):
    """
    find where the ball changes horizontal direction
    that's the breakpoint
    """
    if len(positions) < 10:
        return None

    # get just x positions from recent history
    xs = [p[0] for p in positions]

    # smooth the x positions to reduce noise
    smoothed = np.convolve(xs, np.ones(5)/5, mode='valid')

    # find direction changes
    diffs = np.diff(smoothed)

    for i in range(1, len(diffs)):
        # if direction flips (positive to negative or vice versa)
        if diffs[i-1] * diffs[i] < 0:
            return positions[i]

    return None

def draw_overlay(frame, calibration, circle, positions, breakpoint, speed_mph):
    """draw all visual elements on the frame"""

    # draw lane boundary
    foul_near = calibration['points']['foul_line_near']
    foul_far = calibration['points']['foul_line_far']
    pin_near = calibration['points']['pin_line_near']
    pin_far = calibration['points']['pin_line_far']
    arrow_near = calibration['points']['arrow_line_near']
    arrow_far = calibration['points']['arrow_line_far']

    # draw foul line
    cv2.line(frame, tuple(foul_near), tuple(foul_far), (0, 255, 255), 2)
    cv2.putText(frame, "Foul Line", (foul_near[0] + 10, foul_near[1]),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 255), 1)

    # draw arrow line
    cv2.line(frame, tuple(arrow_near), tuple(arrow_far), (0, 165, 255), 2)
    cv2.putText(frame, "Arrows (15ft)", (arrow_near[0] + 10, arrow_near[1]),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 165, 255), 1)

    # draw ball trail
    for i in range(1, len(positions)):
        cv2.line(frame,
                 (positions[i-1][0], positions[i-1][1]),
                 (positions[i][0], positions[i][1]),
                 (0, 255, 0), 2)

    # draw current ball position
    if circle is not None:
        x, y, r = circle
        cv2.circle(frame, (x, y), r, (0, 255, 0), 3)
        cv2.circle(frame, (x, y), 3, (0, 0, 255), -1)

    # draw breakpoint
    if breakpoint is not None:
        bx, by = breakpoint[0], breakpoint[1]
        cv2.circle(frame, (bx, by), 10, (255, 0, 255), -1)
        cv2.putText(frame, "Breakpoint", (bx + 12, by),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 0, 255), 2)

    # draw HUD in top left
    hud_y = 30
    if speed_mph is not None:
        cv2.putText(frame, f"Speed: {speed_mph:.1f} mph", (20, hud_y),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
        hud_y += 35

# regulation constant needed for speed
ARROW_DISTANCE_FEET = 15.0