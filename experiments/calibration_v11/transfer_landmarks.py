"""Transfer IMG_5108's landmarks to a same-placement clip.

Applies the measured global shift, then re-centers each dot/arrow with
blackhat blob detection in a small window around the expected spot.
Headpin, pin columns, and corridors get the global shift only (sub-3 px).
Falls back to the shifted position when local detection finds nothing
(e.g. a mark occluded); reports which landmarks were re-detected.

Usage: python3 transfer_landmarks.py IMG_5105 <dx> <dy>
"""
import json
import sys

import cv2
import numpy as np


def redetect(gray, x, y, half=12, min_area=4, max_area=250):
    x0, y0 = int(x - half), int(y - half)
    crop = gray[y0:y0 + 2 * half, x0:x0 + 2 * half]
    if crop.size == 0:
        return None
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15))
    bh = cv2.morphologyEx(crop, cv2.MORPH_BLACKHAT, k)
    _, th = cv2.threshold(bh, 25, 255, cv2.THRESH_BINARY)
    n, lab, stats, cent = cv2.connectedComponentsWithStats(th)
    best = None
    for i in range(1, n):
        if not (min_area <= stats[i, cv2.CC_STAT_AREA] <= max_area):
            continue
        cx, cy = cent[i]
        d = np.hypot(cx - half, cy - half)
        if best is None or d < best[0]:
            best = (d, x0 + cx, y0 + cy)
    if best is None or best[0] > 9:
        return None
    return [float(best[1]), float(best[2])]


def main():
    clip, dx, dy = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
    src = json.load(open("landmarks/IMG_5108.json"))
    gray = cv2.imread(f"frames/{clip}_f0.png", cv2.IMREAD_GRAYSCALE)

    out = {"clip": src["clip"].replace("IMG_5108", clip), "frame": 0,
           "frame_path": f"frames/{clip}_f0.png", "corner_weight": src.get("corner_weight", 0.3)}
    for group in ["dots", "arrows"]:
        pts, redet = [], 0
        for x, y in src[group]:
            p = redetect(gray, x + dx, y + dy)
            if p is not None:
                redet += 1
            else:
                p = [x + dx, y + dy]
            pts.append(p)
        out[group] = pts
        print(f"{clip} {group}: {redet}/{len(pts)} re-detected locally")
    out["headpin"] = [src["headpin"][0] + dx, src["headpin"][1] + dy]
    out["pin_columns"] = [[x + dx, y + dy, b] for x, y, b in src["pin_columns"]]
    for key in ["foul_line_right", "foul_line_left", "pin_line_right", "pin_line_left"]:
        out[key] = [src[key][0] + dx, src[key][1] + dy]
    c = src["foul_corridor"]
    out["foul_corridor"] = {"from": [round(c["from"][0] + dx), round(c["from"][1] + dy)],
                            "to": [round(c["to"][0] + dx), round(c["to"][1] + dy)],
                            "mode": c.get("mode", "light2dark")}
    path = f"landmarks/{clip}.json"
    json.dump(out, open(path, "w"), indent=2)
    print("wrote", path)


if __name__ == "__main__":
    main()
