import AVFoundation
import SwiftUI

/// The calibration step: a frame from the clip with the four proposed lane corners
/// overlaid. The user drags each corner onto the lane's actual corners (foul line
/// near, pin deck far); a loupe magnifies the area under the active handle.
/// The static default seed is replaced by lane auto-detect in task #4.
struct CalibrationView: View {
    private enum ProposalSource {
        case saved, detected, none
    }

    let clipURL: URL
    /// Live sessions seed from the last human-confirmed calibration (same
    /// phone placement usually); imported clips always auto-detect.
    var preferSavedCalibration = false
    var onBack: () -> Void
    var onConfirm: (LaneCorners) -> Void

    @State private var frame: UIImage?
    @State private var loadFailed = false
    @State private var corners: LaneCorners = .defaultGuess
    @State private var proposal: LaneCorners?
    @State private var proposalSource: ProposalSource = .none
    @State private var isDetecting = true
    /// Once the user drags a corner, a late-arriving auto-detect proposal must
    /// not overwrite their adjustment.
    @State private var userAdjusted = false
    @State private var activeCorner: LaneCorners.Corner?
    @State private var dragStartCorner: CGPoint?

    var body: some View {
        // Hint, image, and buttons stack vertically so the controls never cover
        // the corner handles (near corners sit at the bottom of the frame).
        VStack(spacing: 0) {
            Group {
                if isDetecting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text("Finding the lane…")
                    }
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(.top, 8)
                } else {
                    Text(hintText)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(.top, 8)
                }
            }
            .frame(minHeight: 44)

            Group {
                if let frame {
                    GeometryReader { geo in
                        let rect = fittedRect(imageSize: frame.size, in: geo.size)
                        ZStack {
                            Image(uiImage: frame)
                                .resizable()
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)

                            let outline = LaneCorners.Corner.allCases.map { viewPoint(corners[$0], in: rect) }
                            QuadShape(points: outline)
                                .fill(Color.accentColor.opacity(0.12))
                            QuadShape(points: outline)
                                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8, 5]))

                            ForEach(LaneCorners.Corner.allCases, id: \.self) { corner in
                                handle(for: corner, in: rect)
                            }

                            if let activeCorner {
                                LoupeView(image: frame, normalizedPoint: corners[activeCorner], fittedRect: rect)
                                    .position(loupeCenter(for: activeCorner, in: rect))
                                    .allowsHitTesting(false)
                            }
                        }
                        .coordinateSpace(name: "calibration")
                        .contentShape(Rectangle())
                        .gesture(cornerDragGesture(in: rect))
                    }
                    // Breathing room so edge handles stay under the finger, not
                    // clipped against the hint or button rows.
                    .padding(.vertical, 24)
                } else if loadFailed {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 44))
                        Text("Couldn't load a frame from the clip.")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(.white)
                } else {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            HStack(spacing: 12) {
                    Button {
                        onBack()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.secondaryAction)

                    Button {
                        corners = proposal ?? .defaultGuess
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.secondaryAction)

                    Button {
                        onConfirm(corners)
                    } label: {
                        Label("Looks Good", systemImage: "checkmark")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .buttonStyle(.primaryAction)
                    .disabled(frame == nil)
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .task { await loadFrame() }
    }

    private var hintText: String {
        switch proposalSource {
        case .saved:
            "Corners from your last session — adjust if the phone moved."
        case .detected:
            "We found the lane — drag the corners to fine-tune if needed."
        case .none:
            "Drag the corners onto the lane — foul line at the bottom, pin deck at the top."
        }
    }

    private func loadFrame() async {
        do {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: clipURL))
            generator.appliesPreferredTrackTransform = true
            let (cgImage, _) = try await generator.image(at: .zero)
            frame = UIImage(cgImage: cgImage)
            // A human-confirmed calibration from the last session beats any
            // detector proposal — same placement means one confirming tap.
            if preferSavedCalibration, let saved = LaneCorners.loadLastConfirmed() {
                proposal = saved
                proposalSource = .saved
                if !userAdjusted {
                    corners = saved
                }
                isDetecting = false
                return
            }
            // Otherwise propose via lane auto-detect; the user adjusts from there.
            let detected = await Task.detached(priority: .userInitiated) {
                LaneAutoDetector.detectLaneCorners(in: cgImage)
            }.value
            if let detected {
                proposal = detected
                proposalSource = .detected
                if !userAdjusted {
                    corners = detected
                }
            }
            isDetecting = false
        } catch {
            loadFailed = true
            isDetecting = false
        }
    }

    /// Visual dot only — dragging is handled by the shared gesture below, so the
    /// user never has to hit the dot exactly.
    private func handle(for corner: LaneCorners.Corner, in rect: CGRect) -> some View {
        Circle()
            .fill(.white)
            .frame(width: 20, height: 20)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 3))
            .scaleEffect(activeCorner == corner ? 1.35 : 1.0)
            .animation(.easeOut(duration: 0.12), value: activeCorner == corner)
            .position(viewPoint(corners[corner], in: rect))
            .allowsHitTesting(false)
    }

    /// Document-scanner style adjustment: touch anywhere near a corner to grab
    /// it, then the corner moves by the drag *delta* (not to the finger), so the
    /// point stays visible and precise placement doesn't need a precise grab.
    private func cornerDragGesture(in rect: CGRect) -> some Gesture {
        let grabRadius: CGFloat = 70
        return DragGesture(minimumDistance: 0, coordinateSpace: .named("calibration"))
            .onChanged { value in
                if activeCorner == nil {
                    let nearest = LaneCorners.Corner.allCases.min { a, b in
                        distance(viewPoint(corners[a], in: rect), value.startLocation)
                            < distance(viewPoint(corners[b], in: rect), value.startLocation)
                    }
                    guard let nearest,
                          distance(viewPoint(corners[nearest], in: rect), value.startLocation) <= grabRadius
                    else { return }
                    activeCorner = nearest
                    dragStartCorner = corners[nearest]
                }
                guard let corner = activeCorner, let start = dragStartCorner else { return }
                userAdjusted = true
                let dx = (value.location.x - value.startLocation.x) / rect.width
                let dy = (value.location.y - value.startLocation.y) / rect.height
                corners[corner] = CGPoint(
                    x: min(max(start.x + dx, 0), 1),
                    y: min(max(start.y + dy, 0), 1)
                )
            }
            .onEnded { _ in
                activeCorner = nil
                dragStartCorner = nil
            }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    /// Keeps the loupe near the active handle but off the finger — above it when
    /// there's room, below when the handle is near the top edge.
    private func loupeCenter(for corner: LaneCorners.Corner, in rect: CGRect) -> CGPoint {
        let handle = viewPoint(corners[corner], in: rect)
        let offset: CGFloat = handle.y - rect.minY > 160 ? -110 : 110
        return CGPoint(
            x: min(max(handle.x, rect.minX + 70), rect.maxX - 70),
            y: handle.y + offset
        )
    }

    private func fittedRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func viewPoint(_ normalized: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + normalized.x * rect.width,
            y: rect.minY + normalized.y * rect.height
        )
    }

    private func normalizedPoint(_ location: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max((location.x - rect.minX) / rect.width, 0), 1),
            y: min(max((location.y - rect.minY) / rect.height, 0), 1)
        )
    }
}

private struct QuadShape: Shape {
    var points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

/// Magnified view of the frame around the point being dragged, with a crosshair
/// marking the exact corner position.
private struct LoupeView: View {
    let image: UIImage
    let normalizedPoint: CGPoint
    let fittedRect: CGRect

    private let diameter: CGFloat = 130
    private let zoom: CGFloat = 3

    var body: some View {
        Canvas { context, size in
            context.clip(to: Path(ellipseIn: CGRect(origin: .zero, size: size)))
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            let drawSize = CGSize(width: fittedRect.width * zoom, height: fittedRect.height * zoom)
            let origin = CGPoint(
                x: size.width / 2 - normalizedPoint.x * drawSize.width,
                y: size.height / 2 - normalizedPoint.y * drawSize.height
            )
            context.draw(Image(uiImage: image), in: CGRect(origin: origin, size: drawSize))

            var crosshair = Path()
            crosshair.move(to: CGPoint(x: size.width / 2 - 12, y: size.height / 2))
            crosshair.addLine(to: CGPoint(x: size.width / 2 + 12, y: size.height / 2))
            crosshair.move(to: CGPoint(x: size.width / 2, y: size.height / 2 - 12))
            crosshair.addLine(to: CGPoint(x: size.width / 2, y: size.height / 2 + 12))
            context.stroke(crosshair, with: .color(.yellow), lineWidth: 1.5)
        }
        .frame(width: diameter, height: diameter)
        .overlay(Circle().stroke(.white, lineWidth: 2))
        .shadow(radius: 4)
    }
}
