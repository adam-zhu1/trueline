"""Detect the ball through a clip and compute its entry board at 60 ft
under (a) a landmark reference calibration and (b) an optional legacy
4-corner calibration, for comparison.

Usage: python3 entry_board.py <video> references/<clip>_ref.json [legacy_cal.json]
"""
import json
import sys

import cv2
import numpy as np
from ultralytics import YOLO


def lane_mapper_from_H(H):
    def f(pt):
        q = cv2.perspectiveTransform(np.array([[pt]], np.float64), H)[0, 0]
        return q[0] * 39.0, q[1]  # boards from right gutter (edge=0), feet
    return f


def lane_mapper_from_corners(points):
    src = np.array([points["foul_line_right"], points["foul_line_left"],
                    points["pin_line_left"], points["pin_line_right"]], np.float32)
    dst = np.array([[0, 0], [1, 0], [1, 60], [0, 60]], np.float32)
    H = cv2.getPerspectiveTransform(src, dst).astype(np.float64)
    return lane_mapper_from_H(H)


def main():
    video, ref_path = sys.argv[1], sys.argv[2]
    ref = json.load(open(ref_path))
    mappers = {"reference": lane_mapper_from_H(np.array(ref["H_undistorted_to_lane"]))}
    if len(sys.argv) > 3:
        legacy = json.load(open(sys.argv[3]))
        mappers["legacy"] = lane_mapper_from_corners(legacy["points"])

    import os
    cache = "detections/" + os.path.splitext(os.path.basename(video))[0] + "_track.json"
    if os.path.exists(cache):
        track = [tuple(t) for t in json.load(open(cache))]
        print(f"{len(track)} ball detections (cached: {cache})")
    else:
        model = YOLO("../../models/ball.pt")
        cap = cv2.VideoCapture(video)
        n = 0
        track = []  # (frame, cx, contact_y, conf)
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            r = model.predict(frame, imgsz=960, conf=0.30, verbose=False)[0]
            if len(r.boxes):
                i = int(np.argmax(r.boxes.conf.cpu().numpy()))
                x1, y1, x2, y2 = r.boxes.xyxy.cpu().numpy()[i]
                track.append((n, float((x1 + x2) / 2), float(y2), float(r.boxes.conf.cpu().numpy()[i])))
            n += 1
        cap.release()
        os.makedirs("detections", exist_ok=True)
        json.dump(track, open(cache, "w"))
        print(f"{len(track)} ball detections over {n} frames (cached to {cache})")

    for name, mapper in mappers.items():
        lane = [(f, *mapper((cx, cy)), conf) for f, cx, cy, conf in track]
        # keep the monotone down-lane run (the throw)
        lane.sort()
        best = None
        for i in range(len(lane)):
            run = [lane[i]]
            for j in range(i + 1, len(lane)):
                if lane[j][2] > run[-1][2] - 0.5 and lane[j][0] - run[-1][0] <= 12:
                    run.append(lane[j])
            if best is None or len(run) > len(best):
                best = run
        run = best
        print(f"\n[{name}] throw run: {len(run)} detections, "
              f"{run[0][2]:.1f} -> {run[-1][2]:.1f} ft (frames {run[0][0]}-{run[-1][0]})")
        for f, b, ft, conf in run[-6:]:
            print(f"  f{f}: board {b:5.2f}  {ft:5.2f} ft  conf {conf:.2f}")
        # entry board: interpolate board at the 60 ft crossing
        for (f1, b1, t1, _), (f2, b2, t2, _) in zip(run, run[1:]):
            if t1 <= 60.0 <= t2 and t2 > t1:
                entry = b1 + (b2 - b1) * (60.0 - t1) / (t2 - t1)
                print(f"  entry board @60ft: {entry:.2f} "
                      f"(between f{f1} {b1:.2f}bd/{t1:.1f}ft and f{f2} {b2:.2f}bd/{t2:.1f}ft)")
                break
        deepest = max(run, key=lambda r: r[2])
        print(f"  deepest detection: board {deepest[1]:.2f} at {deepest[2]:.2f} ft")


if __name__ == "__main__":
    main()
