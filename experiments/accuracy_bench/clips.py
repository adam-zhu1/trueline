"""The benchmark corpus: every clip we have footage AND a trusted calibration for.

Videos are git-ignored. Alley clips live in <repo>/data/test_videos/alley-2026-08-17
(the main checkout's data/ when run from a worktree); the portfolio throw lives in
the portfolio repo's docs/handoff/trueline tree. Override either root with
TRUELINE_DATA / TRUELINE_PORTFOLIO_CLIP.
"""
import json
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
REFS = REPO / "experiments" / "calibration_v11" / "references"


def _data_root() -> Path:
    env = os.environ.get("TRUELINE_DATA")
    if env:
        return Path(env)
    for cand in (REPO / "data", Path.home() / "Projects" / "trueline" / "data"):
        if (cand / "test_videos").exists():
            return cand
    return REPO / "data"


def _portfolio_root() -> Path:
    env = os.environ.get("TRUELINE_PORTFOLIO_CLIP")
    if env:
        return Path(env)
    return (Path.home() / "Portfolio" / "website-code" / ("adam-zhu1." + "github.io")
            / "docs" / "handoff" / "trueline")


ALLEY = ["IMG_5105", "IMG_5106", "IMG_5107", "IMG_5108",
         "IMG_5112", "IMG_5113", "IMG_5114", "IMG_5115"]

# What the footage itself says happened, from Adam's notes at the session and
# frame-by-frame review (see notes/accuracy-benchmark-2026-11.md for the
# evidence behind each line). `entry_range` is the board band the pin action
# allows at 59.5 ft; None where the clip doesn't show it.
OUTCOMES = {
    "IMG_5105": {"note": "miss, light/right (Adam)", "entry_range": None},
    "IMG_5106": {"note": "gutter ball (Adam)", "entry_range": None, "gutter": True},
    "IMG_5107": {"note": "miss, light/right (Adam)", "entry_range": None},
    "IMG_5108": {"note": "strike (Adam)", "entry_range": [16.0, 19.0]},
    "IMG_5112": {"note": "batch 2, tilted", "entry_range": None},
    "IMG_5113": {"note": "batch 2", "entry_range": None},
    "IMG_5114": {"note": "batch 2, rolled; bowler occludes far lane", "entry_range": None},
    "IMG_5115": {"note": "batch 2", "entry_range": None},
    "portfolio_30": {"note": "screen recording, 30 fps conversion", "entry_range": None},
    "portfolio_60": {"note": "same throw, original 60 fps", "entry_range": None},
}


def manifest() -> list[dict]:
    data = _data_root() / "test_videos" / "alley-2026-08-17"
    clips = []
    for cid in ALLEY:
        ref = json.loads((REFS / f"{cid}_ref.json").read_text())
        c = ref["corners"]
        video = next((p for p in data.glob(cid + ".*")), None)
        if video is None:
            continue
        clips.append({
            "id": cid, "video": str(video), "hand": "R",
            "farLeft": c["pin_line_left"], "farRight": c["pin_line_right"],
            "nearRight": c["foul_line_right"], "nearLeft": c["foul_line_left"],
            "H_ref": ref["H_undistorted_to_lane"],
        })
    port = _portfolio_root()
    cal_path = port / "clip" / "calibration.json"
    if cal_path.exists():
        cal = json.loads(cal_path.read_text())
        c = cal["corners_px"]
        for cid, video in (("portfolio_30", port / "clip" / "source-30fps.mp4"),
                           ("portfolio_60", port / "assets" / "ScreenRecording_09-09-2026 05-22-17_1.mov")):
            if video.exists():
                clips.append({
                    "id": cid, "video": str(video), "hand": "R",
                    "farLeft": c["farLeft"], "farRight": c["farRight"],
                    "nearRight": c["nearRight"], "nearLeft": c["nearLeft"],
                })
    return clips
