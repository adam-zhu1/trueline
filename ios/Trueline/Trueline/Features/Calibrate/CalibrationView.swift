import AVFoundation
import SwiftUI

/// The calibration step, v1.1 flow: six guided taps on recognizable landmarks
/// (foul line corners, three arrows, head pin) seed a least-squares homography,
/// then the lane's geometry is drawn over the frame and the user drags the
/// corners until the drawn pin spots sit on the real rack. The harness Monte
/// Carlo picked this design: 0.5-0.7 boards median entry error vs 3.0 for the
/// old tap-four-corners flow. A saved same-zoom calibration skips the taps and
/// opens directly on the refine overlay, which is also the phone-moved check.
struct CalibrationView: View {
    private enum Phase {
        case tapping, refining
    }

    private enum ProposalSource {
        case saved, fitted
    }

    let clipURL: URL
    /// Live sessions seed from the last human-confirmed calibration (same
    /// phone placement usually); imported clips always start from taps.
    var preferSavedCalibration = false
    /// The capture zoom the clip was recorded at — saved corners only apply
    /// when it matches the zoom they were confirmed at.
    var captureZoom: Double = 1.0
    var onBack: () -> Void
    var onConfirm: (LaneCorners) -> Void

    @State private var frame: UIImage?
    @State private var loadFailed = false
    @State private var phase: Phase = .tapping
    /// Placed taps in normalized image coords, parallel to LandmarkFit.targets.
    @State private var taps: [CGPoint] = []
    @State private var corners: LaneCorners = .defaultGuess
    /// What Reset restores: the fitted result of the taps, or the saved corners.
    @State private var proposal: LaneCorners?
    @State private var proposalSource: ProposalSource = .fitted
    @State private var fitFailed = false
    /// Active drag target: a tap index while tapping, a corner while refining.
    @State private var activeTap: Int?
    @State private var activeCorner: LaneCorners.Corner?
    @State private var dragStartPoint: CGPoint?

    var body: some View {
        // Hint, image, and buttons stack vertically so the controls never cover
        // the handles (near corners sit at the bottom of the frame).
        VStack(spacing: 0) {
            // The longest hint, hidden, fixes this slot's height up front so
            // hint changes between steps never reflow the frame below.
            ZStack {
                hintCapsule(Self.tallestHint)
                    .hidden()
                hintCapsule(hintText)
            }
            .padding(.top, 8)
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

                            if phase == .refining {
                                LaneOverlayView(corners: corners, imageSize: frame.size, fittedRect: rect)
                                ForEach(LaneCorners.Corner.allCases, id: \.self) { corner in
                                    handle(at: corners[corner], active: activeCorner == corner, in: rect)
                                }
                            } else {
                                ForEach(taps.indices, id: \.self) { index in
                                    handle(at: taps[index], active: activeTap == index, in: rect)
                                }
                            }

                            if let point = activePoint {
                                LoupeView(image: frame, normalizedPoint: point, fittedRect: rect)
                                    .position(loupeCenter(for: point, in: rect))
                                    .allowsHitTesting(false)
                            }
                        }
                        .coordinateSpace(name: "calibration")
                        .contentShape(Rectangle())
                        .gesture(phase == .tapping ? tapPhaseGesture(in: rect) : nil)
                        .gesture(phase == .refining ? refineDragGesture(in: rect) : nil)
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

            // Back and Undo/Reset as icon squares so the confirm — the action
            // this screen exists for — gets the width.
            HStack(spacing: 12) {
                Button {
                    if phase == .refining {
                        phase = .tapping
                        fitFailed = false
                    } else {
                        onBack()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.iconAction)
                .accessibilityLabel(phase == .refining ? "Back to taps" : "Back")

                if phase == .tapping {
                    Button {
                        if !taps.isEmpty {
                            taps.removeLast()
                        }
                        fitFailed = false
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.iconAction)
                    .disabled(taps.isEmpty)
                    .accessibilityLabel("Undo last tap")
                } else {
                    Button {
                        if let proposal {
                            corners = proposal
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.iconAction)
                    .disabled(proposal == nil)
                    .accessibilityLabel("Reset corners")
                }

                Button {
                    onConfirm(corners)
                } label: {
                    Label("Looks Good", systemImage: "checkmark")
                }
                .buttonStyle(.primaryAction)
                .disabled(phase != .refining)
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .task { await loadFrame() }
    }

    // MARK: - Hints

    private var hintText: String {
        switch phase {
        case .tapping:
            if fitFailed {
                return "Those taps don't line up with a lane. Undo and adjust them."
            }
            if taps.count < LandmarkFit.targets.count {
                return LandmarkFit.targets[taps.count].hint
            }
            return "Adjust any point, or lift your finger to continue."
        case .refining:
            var hint = switch proposalSource {
            case .saved: "From your last session. Check the drawn pins still sit on the real pins."
            case .fitted: "Drag the corners until the drawn pins sit on the real pins."
            }
            if farEndTooSmall {
                hint += " Far end looks tiny. Record at 2x next time."
            }
            return hint
        }
    }

    /// The hint that wraps to the most lines; it sizes the hint slot so hint
    /// swaps can't move the layout.
    private static let tallestHint =
        "From your last session. Check the drawn pins still sit on the real pins. Far end looks tiny. Record at 2x next time."

    /// Below ~3 px per board at the deck, sub-board reads are physically out of
    /// reach; nudge toward 2x capture (which roughly doubles it).
    private var farEndTooSmall: Bool {
        guard let frame, captureZoom < 2 else { return false }
        let l = CGPoint(x: corners.farLeft.x * frame.size.width, y: corners.farLeft.y * frame.size.height)
        let r = CGPoint(x: corners.farRight.x * frame.size.width, y: corners.farRight.y * frame.size.height)
        return hypot(l.x - r.x, l.y - r.y) / 39 < 3
    }

    private func hintCapsule(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.55), in: Capsule())
    }

    // MARK: - Frame loading

    private func loadFrame() async {
        do {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: clipURL))
            generator.appliesPreferredTrackTransform = true
            let (cgImage, _) = try await generator.image(at: .zero)
            frame = UIImage(cgImage: cgImage)
            // A human-confirmed calibration from the last session beats
            // re-tapping — same placement means one confirming look at the
            // overlay, and any phone bump is immediately visible against it.
            if preferSavedCalibration, let saved = LaneCorners.loadLastConfirmed(forZoom: captureZoom) {
                corners = saved
                proposal = saved
                proposalSource = .saved
                phase = .refining
            }
        } catch {
            loadFailed = true
        }
    }

    // MARK: - Gestures

    private var activePoint: CGPoint? {
        if phase == .refining, let activeCorner {
            return corners[activeCorner]
        }
        if phase == .tapping, let activeTap, taps.indices.contains(activeTap) {
            return taps[activeTap]
        }
        return nil
    }

    /// Tap phase: a touch near an existing point grabs and adjusts it (moving
    /// by the drag delta, document-scanner style); a touch elsewhere places the
    /// next target under the finger, adjustable until lift. When the sixth
    /// point lands, the fit runs and the refine overlay appears.
    private func tapPhaseGesture(in rect: CGRect) -> some Gesture {
        let grabRadius: CGFloat = 40
        return DragGesture(minimumDistance: 0, coordinateSpace: .named("calibration"))
            .onChanged { value in
                if activeTap == nil {
                    let nearest = taps.indices.min { a, b in
                        distance(viewPoint(taps[a], in: rect), value.startLocation)
                            < distance(viewPoint(taps[b], in: rect), value.startLocation)
                    }
                    if let nearest,
                       distance(viewPoint(taps[nearest], in: rect), value.startLocation) <= grabRadius {
                        activeTap = nearest
                        dragStartPoint = taps[nearest]
                    } else if taps.count < LandmarkFit.targets.count {
                        let placed = normalizedPoint(value.startLocation, in: rect)
                        taps.append(placed)
                        activeTap = taps.count - 1
                        dragStartPoint = placed
                    } else {
                        return
                    }
                    fitFailed = false
                }
                guard let index = activeTap, let start = dragStartPoint else { return }
                let dx = (value.location.x - value.startLocation.x) / rect.width
                let dy = (value.location.y - value.startLocation.y) / rect.height
                taps[index] = CGPoint(
                    x: min(max(start.x + dx, 0), 1),
                    y: min(max(start.y + dy, 0), 1)
                )
            }
            .onEnded { _ in
                activeTap = nil
                dragStartPoint = nil
                if taps.count == LandmarkFit.targets.count {
                    fitFromTaps()
                }
            }
    }

    private func fitFromTaps() {
        guard let frame,
              let fitted = LandmarkFit.corners(fromTaps: taps, imageSize: frame.size)
        else {
            fitFailed = true
            return
        }
        corners = fitted
        proposal = fitted
        proposalSource = .fitted
        phase = .refining
    }

    /// Refine phase: same document-scanner drag as the old flow, but against
    /// the live overlay — touch anywhere near a corner to grab it, then it
    /// moves by the drag delta so precise placement doesn't need a precise grab.
    private func refineDragGesture(in rect: CGRect) -> some Gesture {
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
                    dragStartPoint = corners[nearest]
                }
                guard let corner = activeCorner, let start = dragStartPoint else { return }
                let dx = (value.location.x - value.startLocation.x) / rect.width
                let dy = (value.location.y - value.startLocation.y) / rect.height
                corners[corner] = CGPoint(
                    x: min(max(start.x + dx, 0), 1),
                    y: min(max(start.y + dy, 0), 1)
                )
            }
            .onEnded { _ in
                activeCorner = nil
                dragStartPoint = nil
            }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    // MARK: - Layout helpers

    private func handle(at normalized: CGPoint, active: Bool, in rect: CGRect) -> some View {
        Circle()
            .fill(.white)
            .frame(width: 20, height: 20)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 3))
            .scaleEffect(active ? 1.35 : 1.0)
            .animation(.easeOut(duration: 0.12), value: active)
            .position(viewPoint(normalized, in: rect))
            .allowsHitTesting(false)
    }

    /// Keeps the loupe near the active handle but off the finger — above it when
    /// there's room, below when the handle is near the top edge.
    private func loupeCenter(for normalized: CGPoint, in rect: CGRect) -> CGPoint {
        let handle = viewPoint(normalized, in: rect)
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

/// Magnified view of the frame around the point being dragged, with a crosshair
/// marking the exact position.
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
