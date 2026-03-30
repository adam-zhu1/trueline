import json
import os
from pathlib import Path

from calibration import calibrate
from ball_tracking import track_ball

# Repo root (parent of src/) so data/ resolves when running `python3 main.py` from `src/`
_REPO_ROOT = Path(__file__).resolve().parent.parent
_CALIB_PATH = _REPO_ROOT / "data" / "calibration.json"


def _normalize_user_path(raw: str) -> str:
    """Strip whitespace and a single pair of wrapping quotes (common when pasting paths)."""
    p = raw.strip()
    if len(p) >= 2 and p[0] in "'\"" and p[-1] == p[0]:
        p = p[1:-1].strip()
    return os.path.expanduser(p)


def select_video():
    print("\n=== PinPoint ===")
    print("Enter the full path to the video file (paste is fine; do not wrap in quotes):")
    path = _normalize_user_path(input("> "))
    if not path:
        print("Empty path.")
        return None
    if not os.path.isfile(path):
        print("Video file not found. Check the path and try again.")
        return None
    return path

def main():
    # Step 1: select video
    video_path = select_video()
    if not video_path:
        return

    # Step 2: check if calibration exists (always under repo data/, not cwd)
    _CALIB_PATH.parent.mkdir(parents=True, exist_ok=True)

    if _CALIB_PATH.is_file():
        rel = _CALIB_PATH.relative_to(_REPO_ROOT)
        print(
            f"\nSaved calibration: {rel} — lane corner clicks, one file for the whole project "
            "(not tied to this video file)."
        )
        print(
            "Use (R) if this clip matches the same camera + lane view as before; "
            "use (C) after moving the camera, changing lanes, or if zoom/crop looks different."
        )
        print("(R) Use saved   (C) Recalibrate from this video's first frame")
        choice = input("> ").strip().upper()
        if choice == "C":
            calibration = calibrate(video_path, str(_CALIB_PATH))
        else:
            with open(_CALIB_PATH) as f:
                calibration = json.load(f)
            print("Using saved calibration.")
    else:
        print("\nNo calibration found. Starting calibration...")
        calibration = calibrate(video_path, str(_CALIB_PATH))

    if calibration is None:
        print("Calibration failed. Exiting.")
        return

    # Step 3: track the ball
    track_ball(video_path, calibration)

if __name__ == "__main__":
    main()