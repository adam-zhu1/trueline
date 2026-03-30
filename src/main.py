import json
import os
from pathlib import Path

from calibration import calibrate
from detect_ball import track_ball

# Repo root (parent of src/) so data/ and paths work when you `cd src && python main.py`
_REPO_ROOT = Path(__file__).resolve().parent.parent
_CALIB_PATH = _REPO_ROOT / "data" / "calibration.json"

def select_video():
    print("\n=== PinPoint ===")
    print("Enter the full path to your video file:")
    path = input("> ").strip()
    
    if not os.path.exists(path):
        print("Video file not found. Please check the path and try again.")
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
        print("\nExisting calibration found.")
        print("(R) Use existing   (C) Recalibrate")
        choice = input("> ").strip().upper()
        if choice == "C":
            calibration = calibrate(video_path, str(_CALIB_PATH))
        else:
            with open(_CALIB_PATH) as f:
                calibration = json.load(f)
            print("Calibration loaded.")
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