import cv2
import os
import json
from calibration import calibrate
from detect_ball import track_ball

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

    # Step 2: check if calibration exists
    calibration_path = "data/calibration.json"
    
    if os.path.exists(calibration_path):
        print("\nExisting calibration found.")
        print("(R) Use existing   (C) Recalibrate")
        choice = input("> ").strip().upper()
        if choice == "C":
            calibration = calibrate(video_path, calibration_path)
        else:
            with open(calibration_path) as f:
                calibration = json.load(f)
            print("Calibration loaded.")
    else:
        print("\nNo calibration found. Starting calibration...")
        calibration = calibrate(video_path, calibration_path)

    if calibration is None:
        print("Calibration failed. Exiting.")
        return

    # Step 3: track the ball
    track_ball(video_path, calibration)

if __name__ == "__main__":
    main()