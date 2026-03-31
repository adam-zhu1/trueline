import json
import os

import cv2
import numpy as np

# real world bowling lane measurements (regulation)
LANE_LENGTH_FEET = 60.0
LANE_WIDTH_INCHES = 41.5
NUM_BOARDS = 60
DOT_DISTANCE_FEET = 6.0
FOUL_LINE_DISTANCE_FEET = 0.0

# Clicks are never pixel-perfect; the true ball path can sit slightly outside a strict
# quadrilateral in image space. YOLO gate: accept centers up to this far *outside* the
# lane poly (signed distance, pixels). Override: PINPOINT_LANE_MARGIN_PX
LANE_DETECTION_MARGIN_PX = 22.0

# MOG2 path: expand the filled lane mask a few pixels so edge shots are not clipped.
LANE_MASK_DILATE_ITERATIONS = 4


def lane_surface_quad(calibration: dict) -> np.ndarray:
    """
    Closed quad in image space: foul_near → foul_far → pin_far → pin_near.
    Same order as lane_and_approach_mask in ball_tracking.
    """
    fn = calibration["points"]["foul_line_near"]
    ff = calibration["points"]["foul_line_far"]
    pn = calibration["points"]["pin_line_near"]
    pf = calibration["points"]["pin_line_far"]
    return np.array([fn, ff, pf, pn], dtype=np.float64)


def detection_center_in_lane(cx: float, cy: float, calibration: dict) -> bool:
    """True if (cx, cy) is inside the lane surface, or within margin of the boundary."""
    quad = lane_surface_quad(calibration).astype(np.float32)
    d = cv2.pointPolygonTest(quad, (float(cx), float(cy)), True)
    if d is None:
        return False
    try:
        margin = float(os.environ.get("PINPOINT_LANE_MARGIN_PX", str(LANE_DETECTION_MARGIN_PX)))
    except ValueError:
        margin = LANE_DETECTION_MARGIN_PX
    return d >= -margin


def calibrate(video_path, save_path):
    print("\n=== CALIBRATION ===")
    print("Camera setup (read before starting):")
    print("  - Stand on the SIDE of the lane (between ball return and lane edge), at the foul line.")
    print("  - Camera about hip height, landscape orientation.")
    print("  - Frame the full lane from foul line to pin deck — nothing cropped.")
    print("\nClick 6 points on the first frame: foul line, DOT line (6 ft), pin deck.")
    print("\nPress Enter to open the calibration frame...\n")
    input()

    cap = cv2.VideoCapture(video_path)
    ret, frame = cap.read()
    cap.release()

    if not ret:
        print("Could not read video file.")
        return None

    points = {}
    display = frame.copy()

    def draw_instructions(img, message, color=(255, 255, 255)):
        overlay = img.copy()
        cv2.rectangle(overlay, (0, 0), (img.shape[1], 60), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.6, img, 0.4, 0, img)
        cv2.putText(img, message, (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 1.0, color, 2)

    def click_point(label, instruction, color):
        result = {}

        def click(event, x, y, flags, param):
            if event == cv2.EVENT_LBUTTONDOWN:
                result["x"] = x
                result["y"] = y
                cv2.circle(display, (x, y), 6, color, -1)
                cv2.putText(
                    display,
                    label,
                    (x + 10, y),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.6,
                    color,
                    2,
                )
                print(f"  {label} set at ({x}, {y})")

        temp = display.copy()
        draw_instructions(temp, instruction, color)
        cv2.imshow("PinPoint Calibration", temp)
        cv2.setMouseCallback("PinPoint Calibration", click)

        while "x" not in result:
            cv2.imshow("PinPoint Calibration", display)
            draw_instructions(display, instruction, color)
            if cv2.waitKey(50) & 0xFF == ord("q"):
                return None

        return (result["x"], result["y"])

    print("Step 1: Click the FOUL LINE where it meets the near edge of the lane")
    points["foul_line_near"] = click_point(
        "Foul Line (near)",
        "STEP 1: Click where the foul line meets the near lane edge",
        (0, 255, 255),
    )

    if points["foul_line_near"] is None:
        cv2.destroyAllWindows()
        print("Calibration cancelled.")
        return None

    print("Step 2: Click the FOUL LINE where it meets the far edge of the lane")
    points["foul_line_far"] = click_point(
        "Foul Line (far)",
        "STEP 2: Click where the foul line meets the far lane edge",
        (0, 255, 255),
    )
    if points["foul_line_far"] is None:
        cv2.destroyAllWindows()
        print("Calibration cancelled.")
        return None

    print("Step 3: Click the DOT LINE (7 small circles in a row, 6 ft from foul) at the near edge")
    points["dot_line_near"] = click_point(
        "Dot Line (near)",
        "STEP 3: Dot line (6 ft) — near lane edge",
        (0, 165, 255),
    )
    if points["dot_line_near"] is None:
        cv2.destroyAllWindows()
        print("Calibration cancelled.")
        return None

    print("Step 4: Click the DOT LINE at the far edge of the lane")
    points["dot_line_far"] = click_point(
        "Dot Line (far)",
        "STEP 4: Dot line (6 ft) — far lane edge",
        (0, 165, 255),
    )
    if points["dot_line_far"] is None:
        cv2.destroyAllWindows()
        print("Calibration cancelled.")
        return None

    print("Step 5: Click the PIN DECK where it meets the near edge of the lane")
    points["pin_line_near"] = click_point(
        "Pin Line (near)",
        "STEP 5: Click where the pin deck meets the near lane edge",
        (0, 255, 0),
    )
    if points["pin_line_near"] is None:
        cv2.destroyAllWindows()
        print("Calibration cancelled.")
        return None

    print("Step 6: Click the PIN DECK where it meets the far edge of the lane")
    points["pin_line_far"] = click_point(
        "Pin Line (far)",
        "STEP 6: Click where the pin deck meets the far lane edge",
        (0, 255, 0),
    )
    if points["pin_line_far"] is None:
        cv2.destroyAllWindows()
        print("Calibration cancelled.")
        return None

    foul_near = np.array(points["foul_line_near"], dtype=np.int32)
    foul_far = np.array(points["foul_line_far"], dtype=np.int32)
    dot_near = np.array(points["dot_line_near"], dtype=np.int32)
    dot_far = np.array(points["dot_line_far"], dtype=np.int32)
    pin_near = np.array(points["pin_line_near"], dtype=np.int32)
    pin_far = np.array(points["pin_line_far"], dtype=np.int32)

    quad_i = np.array([foul_near, foul_far, pin_far, pin_near], dtype=np.int32)
    preview = frame.copy()
    cv2.polylines(preview, [quad_i], True, (0, 255, 255), 2)
    cv2.line(preview, tuple(foul_near.tolist()), tuple(foul_far.tolist()), (0, 255, 255), 2)
    cv2.line(preview, tuple(dot_near.tolist()), tuple(dot_far.tolist()), (0, 165, 255), 2)
    cv2.line(preview, tuple(pin_near.tolist()), tuple(pin_far.tolist()), (0, 255, 0), 2)
    bar = np.zeros((56, preview.shape[1], 3), dtype=np.uint8)
    bar[:] = (40, 40, 40)
    cv2.putText(
        bar,
        "Yellow quad = ball detection zone (wood should be inside).  S = save   Q = cancel",
        (10, 36),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.55,
        (240, 240, 240),
        1,
        cv2.LINE_AA,
    )
    preview = np.vstack([preview, bar])
    print(
        "\nPreview: yellow outline is the lane used to keep YOLO/MOG2 on the wood.\n"
        "  S = save calibration   Q = cancel (no file written)\n"
    )
    while True:
        cv2.imshow("PinPoint Calibration", preview)
        k = cv2.waitKey(0) & 0xFF
        if k == ord("s"):
            break
        if k == ord("q"):
            cv2.destroyAllWindows()
            print("Calibration discarded.\n")
            return None

    cv2.destroyAllWindows()

    foul_near = np.array(points["foul_line_near"])
    foul_far = np.array(points["foul_line_far"])
    dot_near = np.array(points["dot_line_near"])
    dot_far = np.array(points["dot_line_far"])
    pin_near = np.array(points["pin_line_near"])
    pin_far = np.array(points["pin_line_far"])

    foul_mid = (foul_near + foul_far) / 2
    dot_mid = (dot_near + dot_far) / 2
    pin_mid = (pin_near + pin_far) / 2

    foul_to_dot_pixels = np.linalg.norm(dot_mid - foul_mid)
    pixels_per_foot = foul_to_dot_pixels / DOT_DISTANCE_FEET

    foul_width_pixels = np.linalg.norm(foul_far - foul_near)
    dot_width_pixels = np.linalg.norm(dot_far - dot_near)
    avg_lane_width_pixels = (foul_width_pixels + dot_width_pixels) / 2
    pixels_per_board = avg_lane_width_pixels / NUM_BOARDS

    cap = cv2.VideoCapture(video_path)
    fps = cap.get(cv2.CAP_PROP_FPS)
    cap.release()

    calibration = {
        "points": {k: list(v) for k, v in points.items()},
        "pixels_per_foot": pixels_per_foot,
        "pixels_per_board": pixels_per_board,
        "fps": fps,
        "foul_line_y": float(foul_mid[1]),
        "dot_line_y": float(dot_mid[1]),
        "pin_line_y": float(pin_mid[1]),
        "foul_line_near_x": float(foul_near[0]),
        "foul_line_far_x": float(foul_far[0]),
    }

    with open(save_path, "w") as f:
        json.dump(calibration, f, indent=2)

    print(f"\nCalibration complete!")
    print(f"  Pixels per foot: {pixels_per_foot:.2f}")
    print(f"  Pixels per board: {pixels_per_board:.2f}")
    print(f"  FPS: {fps}")
    print(f"  Saved to {save_path}\n")

    return calibration
