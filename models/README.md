# Trained ball weights (optional)

After training, copy Ultralytics `best.pt` to **`ball.pt`** in this directory (see **`training/README.md`**). When `ball.pt` is present and dependencies load, the application uses YOLO instead of classical motion detection.

Large binaries are gitignored (`*.pt`, `*.onnx`).
