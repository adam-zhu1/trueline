# Ball detector on tilted and off-axis placements: research and plan

> Update Nov 3: recommendation 1 (detect on the lane box) is built, commit "detect on the calibrated lane box". In the Mac harness, 5112/5113/5114 went from 14/7/0 tracked frames to 75/85/18, and the reference clips moved 0.1 to 0.5 board. Their accuracy is still unchecked against truth.

Nov 3, 2026. Research only. Nothing was trained, nothing in the repo was changed.
The experiment scripts were throwaway and are not committed.
(scan.py, fail.py, warp.py, batch2.py, roi1.py).

## The short version

The biggest problem is not mainly the training data. It is the input size the app feeds the model.

The app runs one 640 px letterboxed pass over a 1080x1920 portrait frame
(BallDetector.swift, `.scaleFit`, no `regionOfInterest` unless the focus crop
fires). That shrinks everything 3x. The Aug 19 sweep in notes/model-eval.md was run in Python
at imgsz 960, so it overstated what the app actually sees. On the batch 2 clips at
the app's 640 full-frame setting, the shipped model finds the ball in almost no
frames. Cropping to the calibrated lane before inference fixes most of it with the
same model and the same number of inferences.

Measured on the Aug 17 alley clips (ball.pt, PyTorch on CPU, frames sampled every 4th
frame inside the throw window; "hits" = frames with an in-lane box at conf 0.35 / 0.18):

| Clip | Full frame 640 (what the app does) | Full frame 960 (the Aug 19 sweep setting) | One lane-bbox crop at 640 | 2x2 native 640 tiles over the lane |
|---|---|---|---|---|
| IMG_5105 (batch 1) | 11/12 (warp set) | n/a | 20/21 | 12/12 (warp set) |
| IMG_5112 | 1/2 of 15 | 3/6 of 15 | 8/10 of 15 | 10/11 of 15 |
| IMG_5113 | 2/4 of 18 | 8/11 of 18 | 14/15 of 18 | 16/16 of 18 |
| IMG_5114 | 0/1 of 19 | 3/5 of 19 | 5/6 of 19 | 6/7 of 19 |

The first lock in ShotAnalyzer needs a candidate at mainConf 0.35, and the focus crop
only runs once `trackMeasured >= 3`. With 1 or 2 strong frames per throw, the track never
starts and the focus crop never gets a chance. That is exactly why 5112, 5113 and 5114
"never lock".

IMG_5114 is also an occlusion problem: from about frame 500 on, the bowler's body sits
between the phone and the ball (checked by eye). No model fixes that. Only placement can.

## Why batch 2 fails

1. **Scale.** At 640 on a full portrait frame, a mid-lane ball is about 5 to 15 px, and
   the far-lane ball is smaller. Small objects lose most of their features after the
   stride 8/16/32 downsampling. This is the standard small-object failure that SAHI was
   built for ([SAHI paper](https://arxiv.org/abs/2202.06934)). Ultralytics' own advice is
   to train and infer "at native or higher resolution" when objects are small
   ([Ultralytics training tips](https://docs.ultralytics.com/yolov5/tutorials/tips_for_best_training_results/)).
2. **Lane angle prior.** The training set comes from about 12 source videos and 215
   frames in total. The synthetic test below shows the model cares about the
   angle of the lane on screen. Batch 1's lane leans about 38 degrees right of vertical, and
   batch 2's leans about 34 degrees left. Rotating 5105 so the lane leans further from
   vertical (rot-10) cuts full-frame hits from 11/12 to 6/12. rot-25 (lane nearly
   horizontal) drops to 0/12, and tiles only recover 3/12. Mirroring 5105 lowers mean
   confidence from 0.76 to 0.65 even though fliplr=0.5 is on.
3. **No geometric augmentation was ever used.** Every run in runs/detect/ (ball, ball2,
   ball3, ball4, allvids, far640, far960) used the Ultralytics defaults: degrees=0,
   shear=0, perspective=0 ([defaults](https://docs.ultralytics.com/usage/cfg/)). So the
   model never saw a rotated or keystoned lane.
4. **Blur augmentation never actually ran.** Ultralytics only applies its built-in
   Blur/MedianBlur (p=0.01 each) when `albumentations` is installed, and it is not
   installed in .venv. This matters more once we crop. A 9 px motion blur
   barely hurt the 640 full-frame path (10/12) but dropped native tiles to 7/12, because
   at native resolution the blur stays full size relative to the ball.
5. **Copy-paste is silently a no-op** for box-only labels. Ultralytics' CopyPaste returns
   early when there are no segment polygons (checked in the installed 8.4.84 source).

## Synthetic placement test (no new footage)

warp.py takes 12 frames of IMG_5105 that have a confident 960 detection as pseudo ground
truth. It applies a warp to each frame and to the ball position, then counts hits within 25 px
of the warped position.

| Warp | Full 640 @0.35 | Lane tiles @0.35 | Mean conf full / tiles |
|---|---|---|---|
| none | 11/12 | 12/12 | 0.76 / 0.89 |
| mirror | 10/12 | 12/12 | 0.65 / 0.81 |
| rotate +10 (lane toward vertical) | 12/12 | 12/12 | 0.75 / 0.89 |
| rotate -10 (lane away from vertical) | 6/12 | 12/12 | 0.41 / 0.81 |
| rotate +25 | 10/12 | 11/12 | 0.70 / 0.80 |
| rotate -25 | 0/12 | 3/12 | 0.02 / 0.26 |
| keystone 0.15 | 11/12 | 12/12 | 0.72 / 0.90 |
| keystone 0.30 | 8/12 | 12/12 | 0.49 / 0.88 |
| scale 0.7 (phone farther back) | 7/12 | 12/12 | 0.50 / 0.90 |
| horizontal motion blur 9 px | 10/12 | 7/12 | 0.66 / 0.43 |
| brightness x0.5 | 11/12 | 12/12 | 0.71 / 0.86 |

Also tried on 5112 (fail.py): rotating the frame so the lane points straight up
("deskew") took 960 full-frame hits from 4/20 to 11/20. Test-time augmentation
(`augment=True`) did nothing (4/20).

Recommendation: turn warp.py into a permanent `training/eval_robustness.py` that every
candidate model must pass. Use these warps on batch 1 clips plus the real batch 2 clips,
and report hits per warp at the app's real inference setting. Run it through the
mlpackage too, since FP16 confidences sag (see the July notes). It costs nothing and catches
regressions before an alley trip.

## Ranked plan

### 1. Lane-ROI inference (no retraining, do this first)

- Set `request.regionOfInterest` on the main pass to the calibrated lane polygon's
  bounding box, expanded by about 60 px plus a ball radius, and extended below the foul
  line to cover the release. Calibration already gives the quad (`LaneGeometry`), and
  the focus crop already proves that Vision ROI box mapping works.
- That single change is one inference per frame, the same as today. On batch 2 it
  shrinks the downscale from 3x to about 1.3x to 1.6x, which gave 8 to 14 strong hits per
  throw in place of 0 to 2.
- Optional second stage: if the ROI pass returns nothing and no track exists yet, run
  2x2 native 640 tiles over the lane bbox. That is a SAHI-style slice without the library.
  It costs 4 extra inferences, but only on empty frames.
- Keep the existing focus-crop fallback unchanged.
- Validate in the macOS harness that compiles the real Analysis sources, on all 8 alley
  clips, the 6 Aug 15 import clips and both IG clips. Check entry-board error on the
  reference clips, because the Nov 1 note says crop-first made reference entry error
  worse (0.79 vs 0.45 boards). Watch for that again here.
- Caveat: roi1.py did not apply the in-lane filter, so a few of its hits could be false
  positives. The Swift lane gate would filter those.

### 2. Retrain with geometric and blur augmentation, on crops that match inference

- Add `degrees=15, shear=3, perspective=0.0005` (try 0.001), and widen `scale` to 0.6.
  Keep fliplr=0.5.
- Install `albumentations` and add a stronger custom MotionBlur (p around 0.2). The default
  p=0.01 is too weak to matter.
- Train on lane-bbox crops and native 640 tiles cut from the full frames. This is
  slicing-aided fine-tuning, which the SAHI paper reports adds 12.7 to 14.5 AP on top of
  slicing inference. Training and inference then see the same ball sizes.
- Copy-paste: write the ball labels as circle polygons inscribed in each box. A ball is
  a circle, so this is exact enough. That turns on Ultralytics CopyPaste
  ([Ghiasi et al.](https://arxiv.org/abs/2012.07177)). Pasting small objects is a
  known fix for having too few small instances
  ([Kisantal et al.](https://arxiv.org/abs/1902.07296)). It is especially useful for
  ball colors we lack, such as gold or lane-colored balls.
- Add the batch 2 clips only after re-shot equivalents exist, or split by clip per the
  leakage rule in training/README.
- Warn Adam first: training runs hot on this laptop. Think about running it on a cloud GPU
  or Colab.

### 3. Collect placement-diverse data at the alley

See the recording list below. More placements beat more throws from the same spot.

### 4. Model architecture changes (only if 1 to 3 leave gaps)

- **YOLO11n in place of YOLOv8n.** 2.6M params and 6.5 GFLOPs versus 3.2M and 8.7, with
  higher COCO mAP (39.5 vs 37.3) ([YOLO11](https://docs.ultralytics.com/models/yolo11/),
  [YOLOv8](https://docs.ultralytics.com/models/yolov8/)). Ultralytics ships YOLO11 and
  newer models on the ANE through its iOS app, so the C2PSA attention block is not a
  blocker. Low cost, but change one variable at a time.
- **YOLOv8s / YOLO11s.** About 3.3x the FLOPs of n. Offline analysis can absorb it.
  Only worth it if the n model underfits after more data.
- **P2 head (`yolov8-p2.yaml`).** Adds a stride-4 output. It helps balls under about 10 px, but
  it makes the model slower and memory-heavier, and community reports call the gains
  "not guaranteed" ([Ultralytics discussion](https://github.com/orgs/ultralytics/discussions/8227)).
  Lane ROI cropping already makes the ball 2 to 3x larger, so this should rarely be
  needed.
- **Higher input (960 or 1280) on full frames.** In the experiment, 1280 full frame got 8/20
  on 5112, still worse than one 640 lane crop (15/20). Cropping is the cheaper way to get
  resolution.
- **Temporal model (TrackNet style).** Heatmap networks that take several frames are the
  research standard for tiny fast balls ([TrackNet](https://arxiv.org/abs/1907.03698)).
  It would be a big rewrite. Park it unless the detector plateaus.

### 5. Synthetic data (low priority)

Ball renders pasted onto real empty-lane frames, with random homographies (domain
randomization, [Tobin et al.](https://arxiv.org/abs/1703.06907)). Copy-paste of real
ball crops onto real lanes gets most of this benefit for far less work. Do it only for
colors you cannot record.

## On-device cost

How the code runs it today: ShotAnalyzer decodes the recorded clip after capture with
AVAssetReader. Each frame gets one `VNCoreMLRequest`, plus a second focus-crop request
on empty frames. The model loads with a default `MLModelConfiguration()` (compute units
`.all`), in ResultsView.swift:194. The model is a 5.9 MB fp16 mlpackage with NMS baked in.
Analysis is offline, so throughput matters, not real-time latency.

- Reference speed: Ultralytics lists YOLO26n detect at 640 at 3.7 ms per image on an
  iPhone 17 Pro with `.cpuAndNeuralEngine`, versus 8.8 ms CPU-only
  ([Ultralytics Core ML](https://docs.ultralytics.com/integrations/coreml/)).
  YOLOv8n/YOLO11n are the same class of model. Assume a few ms on an iPhone 14 to 16 Pro.
  Vision's scaling and conversion probably costs as much as the model.
- Lane ROI: same cost as today (one inference).
- 2x2 tiles on empty frames: up to 5 inferences on those frames. A 3 s throw at 60 fps
  is 180 frames, so even worst case that is about 900 inferences, a few seconds. Fine
  for post-recording analysis. 240 fps clips would be 4x that.
- P2 head: all ops are conv, upsample and concat, which the ANE supports. The cost is
  larger activations at stride 4, roughly 1.3 to 1.5x latency (estimate, not
  measured).
- YOLOv8s: about 3x latency, model about 22 MB fp16. Still fine offline. `quantize=8`
  (8-bit palettized weights, fp16 compute) roughly halves the size.
- Keep `imgsz=640`, `nms=True`, `dynamic=False` at export. Dynamic shapes cannot be
  combined with baked NMS, and fixed shapes are what the ANE likes best.
- Optional: set `computeUnits = .cpuAndNeuralEngine`, which is the Ultralytics SDK default.
  A compute-units override was tried and reverted in July, so measure before changing it.
  Use Xcode's Core ML performance report on the device.

## Data strategy

**How many frames.** Ultralytics' general guideline is 1,500+ images and 10,000+
instances per class
([training tips](https://docs.ultralytics.com/yolov5/tutorials/tips_for_best_training_results/)).
That guideline is for training from scratch. Here we fine-tune one class from a model that
already works. My estimate, not a measured number: about 50 to 100 labeled frames per new
placement, across 8 to 12 placements. That is roughly 600 to 1,000 new frames, bringing the set to
about 1,000 to 1,200. Include 5 to 10% background frames (empty lane, pin deck, bowler
holding the ball). Then measure with eval_robustness and the held-out clips, and add more
only where a warp or placement still fails.

**Labeling fast.**
- The repo's auto_label.py keeps only frames where the model is already confident at 0.50 or more,
  so by design it skips the frames we need. harvest_far_lane.py adds trajectory-gated
  pseudo-labels, but it needs a calibration that matches the video.
- New loop: run the lane-ROI and tile detector at a low threshold (0.10), fit the trajectory,
  and write pseudo-labels for every frame on the track, including the gated weak ones.
  Then import them into a labeling tool as pre-annotations, so a human only fixes or
  deletes boxes.
- Label Studio has a YOLO ML backend for pre-annotation
  ([Label Studio YOLO guide](https://labelstud.io/blog/use-yolo26-with-label-studio-for-fast-bounding-box-pre-annotations)).
  CVAT supports automatic annotation with self-hosted models via Nuclio
  ([CVAT auto-annotation](https://docs.cvat.ai/docs/annotation/auto-annotation/automatic-annotation/)).
  CVAT can also import YOLO-format labels directly, and that is the simpler path: upload
  frames plus pseudo-label .txt files, correct them, export YOLO 1.1.
- Expect 2 to 4 s per frame to correct. 800 frames is about an hour.

**Which frames to label (active learning).**
- First, frames where the tracker had to coast, or where the focus crop or tiles were
  needed. These are the model's blind spots by definition.
- Then frames with a gated detection at 0.10 to 0.50 confidence.
- Then frames where the 640 full-frame and lane-ROI passes disagree.
- Skip near-duplicates: take at most every 3rd frame in a run.
- Frame-wise selection beat sequence-wise selection in a video active-learning study
  ([Joshi et al.](https://library.oapen.org/handle/20.500.12657/89072)), and using temporal
  cues to avoid adjacent frames is the main idea in
  [Na and De-Silva](https://arxiv.org/abs/2303.12760).
- Add a few uniformly sampled frames so the set does not become all hard cases.

## Alley recording list (training data)

This adds to the ground-truth checklist in notes/alley-visit-checklist.md and does not
replace it. Record with field-footage mode so raw files are kept. About 6 throws per
placement is enough. Placement variety is what counts.

**Before each placement:** take a photo of the phone setup from the side, note height,
distance back and lateral offset, and calibrate once.

| # | Placement | Why |
|---|---|---|
| P1 | Nominal: centered behind the approach, tripod about 4 ft high, level | Baseline, matches batch 1 |
| P2 | Same spot, phone rolled about 5 to 10 degrees | Roll tilt like batch 2 |
| P3 | Offset 4 to 6 ft toward the ball return side | Lane leans the other way on screen |
| P4 | Offset 4 to 6 ft to the other side | Mirror of P3 |
| P5 | Low, about 2.5 to 3 ft (tripod short) | Strong keystone, compressed far lane |
| P6 | High, about 5.5 to 6 ft (arm raised or tall tripod) | Weak keystone, ball smaller near pins |
| P7 | 8 to 10 ft farther back | Smaller ball everywhere (like scale 0.7) |
| P8 | Directly behind the bowler's line | The occlusion case (5114). Teaches partial-visibility frames and documents the limit |
| P9 | Handheld, no tripod | Shake and drift, what many users will do |
| P10 | P1 at 2x zoom | The shipped zoom option |

Across placements:
- **Frame rate:** alternate 30 and 60 fps. Do at least one placement at 240 fps on the
  second phone, if it is free from truth duty.
- **Phones:** iPhone 16 Pro and 14 Pro, different lenses and processing. If a friend has a
  non-Pro iPhone, record 2 placements on it.
- **Lanes:** two lanes, one on each side of a lane pair, so the ball return sits on
  different sides.
- **Ball colors:** your ball plus 3 or 4 house balls: a gold, tan or orange one close to the
  lane color (the known blind spot), a bright one, a dark one and a clear or translucent
  one. House balls cost nothing. Three throws each from P1 and P3 is enough.
- **Negatives:** 20 s of the empty lane per placement; the pinsetter cycling; the bowler
  standing with the ball; a neighbor bowling on the next lane (a distractor ball in frame).
- **Lighting:** if the center does cosmic or glow bowling, record one placement under it.
- **Centers:** this session covers one. Plan a second center later, with different lane
  surface color and masking units, before claiming placement robustness.
- **Held-out test:** keep one full placement (say P4) and one ball color entirely out of
  training. Put them in data/test_videos/ so the leakage rule holds.

## Sources

- SAHI, slicing-aided inference and fine-tuning: https://arxiv.org/abs/2202.06934 , code https://github.com/obss/sahi
- Ultralytics augmentation defaults: https://docs.ultralytics.com/usage/cfg/
- Ultralytics training tips (dataset size, background share, native resolution): https://docs.ultralytics.com/yolov5/tutorials/tips_for_best_training_results/
- YOLO11 metrics: https://docs.ultralytics.com/models/yolo11/
- YOLOv8 metrics: https://docs.ultralytics.com/models/yolov8/
- Ultralytics Core ML export and iPhone latency: https://docs.ultralytics.com/integrations/coreml/
- P2 head discussion: https://github.com/orgs/ultralytics/discussions/8227 , https://community.ultralytics.com/t/how-to-add-p2-head-on-yolov8/444
- Simple Copy-Paste (Ghiasi et al., CVPR 2021): https://arxiv.org/abs/2012.07177
- Augmentation for small object detection (Kisantal et al.): https://arxiv.org/abs/1902.07296
- TrackNet: https://arxiv.org/abs/1907.03698
- Domain randomization (Tobin et al.): https://arxiv.org/abs/1703.06907
- Small object detection survey (2025): https://arxiv.org/abs/2503.20516
- Tiny object detection and domain adaptation survey: https://arxiv.org/abs/2107.07927
- Active learning for detectors on video (Na and De-Silva): https://arxiv.org/abs/2303.12760
- Video active learning, frame-wise selection (Joshi et al.): https://library.oapen.org/handle/20.500.12657/89072
- Label Studio YOLO pre-annotation: https://labelstud.io/blog/use-yolo26-with-label-studio-for-fast-bounding-box-pre-annotations
- CVAT automatic annotation: https://docs.cvat.ai/docs/annotation/auto-annotation/automatic-annotation/

Repo facts came from notes/model-eval.md, training/README.md,
training/train_ball_detector.py, runs/detect/*/args.yaml, BallDetector.swift,
ShotAnalyzer.swift, ResultsView.swift:194, experiments/calibration_v11/references/, and the
memory notes on ball tracking and the Nov 1 handoff.
