"""Zoomed crop with an original-coordinate grid, for hand-placing calibration
points from image inspection. Usage:

    python3 zoomgrid.py <frame.png> <cx> <cy> <half> <scale> <out.png> [px,py ...]

Crops a (2*half x 2*half) window centered on (cx, cy), scales it up, and draws
gridlines every 10 original pixels (heavy every 50) labeled with original
coordinates. Optional trailing px,py pairs are drawn as red crosshairs so a
candidate point can be checked against the imagery.
"""
import sys

import cv2
import numpy as np


def main():
    frame_path, cx, cy, half, scale, out = sys.argv[1:7]
    cx, cy, half, scale = int(cx), int(cy), int(half), int(scale)
    marks = []
    for arg in sys.argv[7:]:
        px, py = arg.split(",")
        marks.append((float(px), float(py)))

    img = cv2.imread(frame_path)
    h, w = img.shape[:2]
    x0, y0 = max(0, cx - half), max(0, cy - half)
    x1, y1 = min(w, cx + half), min(h, cy + half)
    crop = img[y0:y1, x0:x1]
    big = cv2.resize(crop, None, fx=scale, fy=scale, interpolation=cv2.INTER_NEAREST)

    def to_big(x, y):
        return int(round((x - x0) * scale)), int(round((y - y0) * scale))

    for gx in range(x0 - x0 % 10, x1 + 1, 10):
        heavy = gx % 50 == 0
        bx, _ = to_big(gx, y0)
        cv2.line(big, (bx, 0), (bx, big.shape[0]), (0, 255, 0), 2 if heavy else 1)
        if heavy:
            cv2.putText(big, str(gx), (bx + 3, 25), cv2.FONT_HERSHEY_SIMPLEX,
                        0.7, (0, 255, 0), 2, cv2.LINE_AA)
    for gy in range(y0 - y0 % 10, y1 + 1, 10):
        heavy = gy % 50 == 0
        _, by = to_big(x0, gy)
        cv2.line(big, (0, by), (big.shape[1], by), (0, 255, 0), 2 if heavy else 1)
        if heavy:
            cv2.putText(big, str(gy), (3, by - 5), cv2.FONT_HERSHEY_SIMPLEX,
                        0.7, (0, 255, 0), 2, cv2.LINE_AA)

    for mx, my in marks:
        bx, by = to_big(mx, my)
        cv2.drawMarker(big, (bx, by), (0, 0, 255), cv2.MARKER_CROSS, 40, 3)

    cv2.imwrite(out, big)
    print(f"crop origin ({x0},{y0}) size {x1 - x0}x{y1 - y0} scale {scale} -> {out}")


if __name__ == "__main__":
    main()
