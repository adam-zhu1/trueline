"""
Trueline lane auto-detect — prototype v2 (gutter-line based).

Idea: the two gutter channels are the strongest, longest, near-linear edges that
converge toward the pins. Find them, keep the pair that brackets the frame's
horizontal center at the bottom (in the real app the subject lane is centered),
and intersect those two lines with a near row (foul end) and a far row (pin end)
to get the four corners.
"""
import glob
import os

import cv2
import numpy as np


def _candidate_lines(frame):
    h, w = frame.shape[:2]
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (5, 5), 0)
    edges = cv2.Canny(gray, 40, 120)
    segs = cv2.HoughLinesP(
        edges, 1, np.pi / 180, threshold=80,
        minLineLength=int(0.18 * h), maxLineGap=int(0.04 * h),
    )
    if segs is None:
        return []
    lines = []
    for x1, y1, x2, y2 in segs[:, 0]:
        dy = y2 - y1
        if abs(dy) < 1:
            continue
        a = (x2 - x1) / dy          # x = a*y + b
        b = x1 - a * y1
        ang = np.degrees(np.arctan2(abs(dy), abs(x2 - x1)))  # 90 = vertical
        if ang < 35:                # too horizontal to be a gutter
            continue
        length = np.hypot(x2 - x1, y2 - y1)
        lines.append({"a": a, "b": b, "len": length,
                      "x_bot": a * h + b, "ang": ang})
    return lines


def detect_corners(frame):
    h, w = frame.shape[:2]
    cx = w / 2.0
    lines = _candidate_lines(frame)
    if not lines:
        return None, []

    # Left gutter: crosses bottom left of center and leans right going up (a < 0,
    # since x decreases as y decreases toward the vanishing point above center).
    # Right gutter: crosses bottom right of center and leans left going up (a > 0).
    lefts = [l for l in lines if l["x_bot"] < cx and l["a"] <= 0.15]
    rights = [l for l in lines if l["x_bot"] > cx and l["a"] >= -0.15]
    if not lefts or not rights:
        return None, lines

    # Prefer long lines whose bottom is near center (the subject lane brackets center).
    def score(l, side):
        prox = 1.0 - min(1.0, abs(l["x_bot"] - cx) / (0.5 * w))
        return l["len"] * (0.5 + prox)

    left = max(lefts, key=lambda l: score(l, "L"))
    right = max(rights, key=lambda l: score(l, "R"))

    def x_at(l, y):
        return l["a"] * y + l["b"]

    # Near row (foul end): near the bottom of the frame.
    y_near = 0.92 * h
    # Far row (pin end): where the two gutters have converged to ~18% of their
    # near separation (approx the pin deck; avoids running to the vanishing point).
    sep_near = abs(x_at(right, y_near) - x_at(left, y_near))
    y_far = y_near
    for y in np.linspace(y_near, 0, 200):
        if abs(x_at(right, y) - x_at(left, y)) <= 0.18 * sep_near:
            y_far = y
            break

    corners = {
        "foul_line_left": (x_at(left, y_near), y_near),
        "foul_line_right": (x_at(right, y_near), y_near),
        "pin_line_left": (x_at(left, y_far), y_far),
        "pin_line_right": (x_at(right, y_far), y_far),
    }
    return corners, [left, right]


def draw(frame, corners, lines):
    vis = frame.copy()
    for l in lines:  # chosen gutter lines in cyan
        p1 = (int(l["a"] * 0 + l["b"]), 0)
        p2 = (int(l["a"] * frame.shape[0] + l["b"]), frame.shape[0])
        cv2.line(vis, p1, p2, (255, 200, 0), 2)
    if corners:
        quad = np.array([
            corners["foul_line_right"], corners["foul_line_left"],
            corners["pin_line_left"], corners["pin_line_right"],
        ], np.int32)
        cv2.polylines(vis, [quad], True, (0, 255, 255), 4)
        for name, (x, y) in corners.items():
            cv2.circle(vis, (int(x), int(y)), 12, (0, 0, 255), -1)
            cv2.putText(vis, name.replace("_line_", " "), (int(x) + 14, int(y)),
                        cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 0, 255), 3)
    else:
        cv2.putText(vis, "NO DETECTION", (40, 80),
                    cv2.FONT_HERSHEY_SIMPLEX, 2.0, (0, 0, 255), 4)
    return vis


if __name__ == "__main__":
    out = os.path.dirname(os.path.abspath(__file__))
    frames = sorted(glob.glob(os.path.join(out, "frame_*.jpg")))
    for fp in frames:
        frame = cv2.imread(fp)
        corners, lines = detect_corners(frame)
        vis = draw(frame, corners, lines)
        name = os.path.basename(fp).replace("frame_", "detect2_")
        cv2.imwrite(os.path.join(out, name), vis)
        print(("OK  " if corners else "MISS") + f"  {os.path.basename(fp)}")
