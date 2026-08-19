# Ball detector evaluation

## Aug 19, 2026 — raw detection sweep, 8 alley clips (Perfect Games lane 15)

`models/ball.pt` run on every frame, conf ≥ 0.30, imgsz 960. Coverage =
detected frames within the ball's first-to-last-detection window. The clips
split into two camera placements: Adam moved the phone mid-session.

| Clip | Placement | Coverage | Conf mean / min |
|------|-----------|----------|-----------------|
| IMG_5105 | batch 1 | 100% (89 fr) | 0.86 / 0.46 |
| IMG_5106 | batch 1 | 74% (77 fr) | 0.78 / 0.31 |
| IMG_5107 | batch 1 | 100% (81 fr) | 0.88 / 0.63 |
| IMG_5108 (strike) | batch 1 | 100% (87 fr) | 0.88 / 0.45 |
| IMG_5112 | batch 2 (tilted) | 27% (71 fr) | 0.70 / 0.34 |
| IMG_5113 | batch 2 | 49% (78 fr) | 0.65 / 0.30 |
| IMG_5114 | batch 2 | 22% (72 fr) | 0.59 / 0.34 |
| IMG_5115 | batch 2 | 63% (76 fr) | 0.62 / 0.31 |

**Finding: the detector is placement-sensitive.** Batch 1 (the framing the
model has effectively been developed against) is near-perfect. Batch 2's
tilted, repositioned view drops coverage to 22–63% with weak confidence —
at that rate the tracker's gate can fail, which most plausibly explains the
one live throw at the alley that ended in "Couldn't track the ball."

**Action (v1.1):** fold the alley clips into training via the auto-label
workflow (`training/auto_label.py`), batch 2 especially — it's exactly the
off-nominal placement real users will produce. Batch 2 clips are held OUT
of training until re-shot equivalents exist, or split train/test carefully
per training/README's leakage rule.

**Accuracy error budget (state of knowledge tonight):**
1. Board numbers are dominated by far-end calibration precision: the pin
   deck spans ~90 px at 1x ≈ 2.3 px/board; 10 px of corner slop = 4+
   boards of entry error. Mitigations: 2x capture zoom (shipped on v1.1
   branch), corner guidance + drift check (planned).
2. Detection coverage (this sweep): placement-dependent, retrainable.
3. Ball-height systematic: already compensated — ShotAnalyzer projects the
   ball's contact point (y + radius), not its center, onto the lane plane.
4. Speed is anchored to file fps and full-lane crossing times; least
   fragile of the metrics.
5. No ground-truth validation session yet: nobody has measured app-vs-tape
   truth. A dedicated session (marked target board, known speeds) is the
   v1.1 acceptance test before making any accuracy claims in marketing.
