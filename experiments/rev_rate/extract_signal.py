"""Extract the ball-patch brightness signal from a clip + cached ball track.

The rev-rate hypothesis: a strip of white tape on the ball sweeps in and
out of the camera-facing hemisphere once per revolution, so the mean
brightness of the ball patch is a periodic signal whose fundamental
frequency IS the rev rate. This script only produces the signal; the
estimator lives in estimate_rpm.py.

Per tracked frame it records the mean grayscale over a disc inside the
ball and the mean over a surrounding annulus (background), so the
estimator can normalize away the lighting gradient down-lane.

Track format matches calibration_v11/detections: [frame, cx, contact_y,
conf], where contact_y is the ball's bottom edge — the disc is centered
one radius above it. Ball radius is modeled as rk * cy (apparent size
shrinks with distance), clamped to [5, 40] px.

Usage: python3 extract_signal.py <video> <track.json> [--rk 0.02] [--out signals/<clip>_signal.json]
"""
import json
import os
import sys

import cv2
import numpy as np

RK_DEFAULT = 0.02
R_MIN, R_MAX = 5.0, 40.0
DISC_FRAC = 0.75      # sample inside the ball, away from the edge
ANNULUS_IN, ANNULUS_OUT = 1.3, 2.0  # background ring, in ball radii


def radius_at(cy, rk):
    return float(np.clip(rk * cy, R_MIN, R_MAX))


def patch_means(gray, cx, contact_y, r):
    """Mean over the ball disc and over the background annulus."""
    cy = contact_y - r  # track y is the contact point; center is one radius up
    h, w = gray.shape
    lim = int(np.ceil(r * ANNULUS_OUT)) + 1
    x0, x1 = max(0, int(cx) - lim), min(w, int(cx) + lim + 1)
    y0, y1 = max(0, int(cy) - lim), min(h, int(cy) + lim + 1)
    if x1 - x0 < 3 or y1 - y0 < 3:
        return None
    yy, xx = np.mgrid[y0:y1, x0:x1]
    d = np.hypot(xx - cx, yy - cy)
    disc = d <= r * DISC_FRAC
    ring = (d >= r * ANNULUS_IN) & (d <= r * ANNULUS_OUT)
    if disc.sum() < 4 or ring.sum() < 8:
        return None
    win = gray[y0:y1, x0:x1].astype(np.float64)
    return float(win[disc].mean()), float(win[ring].mean())


def main():
    args = sys.argv[1:]
    rk, out_path = RK_DEFAULT, None
    if "--rk" in args:
        i = args.index("--rk"); rk = float(args[i + 1]); del args[i:i + 2]
    if "--out" in args:
        i = args.index("--out"); out_path = args[i + 1]; del args[i:i + 2]
    video, track_path = args[0], args[1]

    track = [tuple(t) for t in json.load(open(track_path))]
    by_frame = {int(t[0]): t for t in track}
    first, last = min(by_frame), max(by_frame)

    cap = cv2.VideoCapture(video)
    fps = cap.get(cv2.CAP_PROP_FPS)
    cap.set(cv2.CAP_PROP_POS_FRAMES, first)
    samples = []
    for f in range(first, last + 1):
        ok, frame = cap.read()
        if not ok:
            break
        if f not in by_frame:
            continue
        _, cx, contact_y, conf = by_frame[f]
        r = radius_at(contact_y, rk)
        m = patch_means(cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY), cx, contact_y, r)
        if m is None:
            continue
        ball, bg = m
        samples.append({"frame": f, "t": f / fps, "ball": ball, "bg": bg,
                        "r": r, "conf": conf})
    cap.release()

    clip = os.path.splitext(os.path.basename(video))[0]
    if out_path is None:
        os.makedirs("signals", exist_ok=True)
        out_path = f"signals/{clip}_signal.json"
    json.dump({"clip": clip, "fps": fps, "rk": rk, "samples": samples},
              open(out_path, "w"))
    print(f"{clip}: {len(samples)} samples over {samples[-1]['t'] - samples[0]['t']:.2f} s "
          f"(fps {fps:g}, radius {samples[0]['r']:.0f} -> {samples[-1]['r']:.0f} px) -> {out_path}")


if __name__ == "__main__":
    main()
