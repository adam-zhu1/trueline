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
    /// The point the current touch is placing or nudging, if any.
    @State private var edit: PointEdit?
    /// Bumped each time a finger lifts off a point it placed or moved; drives
    /// the selection haptic.
    @State private var placements = 0
    @State private var zoom = FrameZoom()
    @State private var pinchStart: (zoom: FrameZoom, anchor: CGPoint, span: CGFloat)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One touch's edit of a calibration point. Kept until the edit commits so
    /// a pinch or double tap that starts with one finger can take it back.
    private struct PointEdit {
        enum Target: Equatable {
            case tap(Int)
            case corner(LaneCorners.Corner)
        }

        let target: Target
        /// Where the point was before this touch; nil if this touch placed it.
        let original: CGPoint?
        /// The point's normalized position and the finger's view position at
        /// touch down. The point moves by the finger's travel from there.
        let startPoint: CGPoint
        let touchStart: CGPoint
        var fingerDown = true
    }

    var body: some View {
        // Guide header, image, and buttons stack vertically so the controls
        // never cover the handles (near corners sit at the bottom of the frame).
        VStack(spacing: 0) {
            // Fixed-height header: a mini lane showing where the current
            // target sits, a step counter, and the instruction. The diagram
            // fixes the slot height so step changes never reflow the frame.
            HStack(spacing: 16) {
                CalibrationGuideDiagram(stage: guideStage)
                VStack(alignment: .leading, spacing: 6) {
                    Text(stepLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brandMint)
                    Text(hintText)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subHintText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // Step, instruction and sub-hint read as one announcement.
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .frame(minHeight: CalibrationGuideDiagram.size.height + 16)

            Group {
                if let frame {
                    GeometryReader { geo in
                        let bounds = CGRect(origin: .zero, size: geo.size)
                        let fitted = fittedRect(imageSize: frame.size, in: geo.size)
                        let rect = zoom.displayRect(fitted: fitted, bounds: bounds)
                        ZStack {
                            // Zoomed in, the frame is larger than the viewport;
                            // the picture and overlay clip to it, while handles
                            // keep a little slack so edge points stay grabbable.
                            Image(uiImage: frame)
                                .resizable()
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()

                            if phase == .refining {
                                LaneOverlayView(corners: corners, imageSize: frame.size, fittedRect: rect)
                                    .clipped()
                                ForEach(LaneCorners.Corner.allCases, id: \.self) { corner in
                                    handle(at: corners[corner], active: activeTarget == .corner(corner), in: rect, bounds: bounds)
                                }
                            } else {
                                ForEach(taps.indices, id: \.self) { index in
                                    handle(at: taps[index], active: activeTarget == .tap(index), in: rect, bounds: bounds)
                                }
                            }

                            CalibrationTouchSurface { event in
                                handleTouch(event, display: rect, fitted: fitted, bounds: bounds)
                            }

                            if let point = activePoint {
                                LoupeView(image: frame, normalizedPoint: point, displayRect: rect, zoom: loupeZoom)
                                    .position(loupeCenter(for: FrameZoom.viewPoint(point, in: rect), in: bounds))
                                    .allowsHitTesting(false)
                            }
                        }
                        // Calibration is touching exact spots on the frame, which
                        // VoiceOver's focus model can't do. Direct interaction
                        // passes touches straight through so a VoiceOver user
                        // (or a sighted helper) can still place the points, and
                        // the label says plainly what the area needs.
                        .accessibilityElement(children: .ignore)
                        .accessibilityAddTraits(.allowsDirectInteraction)
                        .accessibilityLabel("Lane frame for calibration")
                        .accessibilityValue(calibrationAccessibilityValue)
                        .accessibilityHint("Placing the points needs a precise touch on the lane picture. The instruction above names each spot. Pinch or double-tap to zoom.")
                    }
                    // Breathing room so edge handles stay under the finger, not
                    // clipped against the hint or button rows.
                    .padding(.vertical, 24)
                } else if loadFailed {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 44))
                            .accessibilityHidden(true)
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
                        edit = nil
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
        .sensoryFeedback(.selection, trigger: placements)
        .sensoryFeedback(.success, trigger: phase) { _, newPhase in
            newPhase == .refining
        }
        .task { await loadFrame() }
    }

    private var calibrationAccessibilityValue: String {
        let status = switch phase {
        case .tapping:
            "\(min(taps.count, LandmarkFit.targets.count)) of \(LandmarkFit.targets.count) points placed."
        case .refining:
            "Lane overlay placed. Drag a corner to adjust, or choose Looks Good."
        }
        return zoom.isZoomed ? status + " Zoomed in." : status
    }

    // MARK: - Guide header

    private var guideStage: CalibrationGuideDiagram.Stage {
        phase == .refining
            ? .refining
            : .tapping(
                active: taps.count < LandmarkFit.targets.count ? taps.count : nil,
                placed: taps.count
            )
    }

    private var stepLabel: String {
        switch phase {
        case .tapping:
            if fitFailed {
                return "Try again"
            }
            if taps.count >= LandmarkFit.targets.count {
                return "All 6 placed"
            }
            return "Point \(taps.count + 1) of 6"
        case .refining:
            return proposalSource == .saved ? "Checking saved calibration" : "Last step: match the lane"
        }
    }

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
            case .saved: "From your last session. Check that every drawn ring still circles its pin."
            case .fitted: "The far end starts as a rough guess. Drag the corners until every drawn ring circles its pin, front row and back."
            }
            if farEndTooSmall {
                hint += " Far end looks tiny. Record at 2x next time."
            }
            return hint
        }
    }

    /// Second line under the hint: the touch mechanics that are otherwise
    /// invisible (the loupe, the generous grab radius).
    private var subHintText: String {
        switch phase {
        case .tapping:
            return "Touch and slide, then lift. Pinch or double-tap to zoom."
        case .refining:
            return "Hold near a corner and drag. Pinch or double-tap to zoom."
        }
    }

    /// Below ~3 px per board at the deck, sub-board reads are physically out of
    /// reach; nudge toward 2x capture (which roughly doubles it).
    private var farEndTooSmall: Bool {
        guard let frame, captureZoom < 2 else { return false }
        let l = CGPoint(x: corners.farLeft.x * frame.size.width, y: corners.farLeft.y * frame.size.height)
        let r = CGPoint(x: corners.farRight.x * frame.size.width, y: corners.farRight.y * frame.size.height)
        return hypot(l.x - r.x, l.y - r.y) / LaneModel.boardCount < 3
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

    /// The point under the finger right now (the loupe follows it).
    private var activeTarget: PointEdit.Target? {
        guard let edit, edit.fingerDown else { return nil }
        return edit.target
    }

    private var activePoint: CGPoint? {
        switch activeTarget {
        case .tap(let index)?:
            taps.indices.contains(index) ? taps[index] : nil
        case .corner(let corner)?:
            corners[corner]
        case nil:
            nil
        }
    }

    /// 4x at the fitted frame (far arrows and the head pin are a few pixels
    /// there), easing off as the pinch zoom grows: past about 6x combined the
    /// video has no more detail to show, only blur.
    private var loupeZoom: CGFloat {
        min(max(6 / zoom.scale, 1.5), 4)
    }

    private var zoomAnimation: Animation? {
        reduceMotion ? nil : .spring(duration: 0.35, bounce: 0)
    }

    /// One finger places or grabs a point and slides it (touch, slide, lift,
    /// like the text magnifier); two fingers pinch and pan; a double tap
    /// toggles zoom. `display` is where the frame is drawn for this render.
    private func handleTouch(_ event: CalibrationTouchSurface.Event, display: CGRect, fitted: CGRect, bounds: CGRect) {
        switch event {
        case .began(let location):
            beginEdit(at: location, in: display)
        case .moved(let location):
            guard let edit, edit.fingerDown else { return }
            let delta = FrameZoom.normalizedDelta(
                CGSize(width: location.x - edit.touchStart.x, height: location.y - edit.touchStart.y),
                in: display
            )
            setPoint(
                CGPoint(
                    x: min(max(edit.startPoint.x + delta.width, 0), 1),
                    y: min(max(edit.startPoint.y + delta.height, 0), 1)
                ),
                for: edit.target
            )
        case .lifted:
            guard let current = edit else { return }
            let moved = activePoint.map { $0 != current.original } ?? false
            edit?.fingerDown = false
            // Tick when a point lands or moves, not for a grab-and-release.
            if current.original == nil || moved {
                placements += 1
            }
        case .committed:
            guard edit != nil else { return }
            edit = nil
            if phase == .tapping, taps.count == LandmarkFit.targets.count {
                fitFromTaps()
            }
        case .cancelled:
            revertEdit()
        case .pinchBegan(let midpoint, let span):
            pinchStart = (zoom, FrameZoom.normalizedPoint(midpoint, in: display), span)
        case .pinchChanged(let midpoint, let span):
            guard let start = pinchStart else { return }
            zoom = start.zoom.pinched(
                anchor: start.anchor,
                to: midpoint,
                scale: start.zoom.scale * span / start.span,
                fitted: fitted,
                bounds: bounds
            )
        case .pinchEnded:
            pinchStart = nil
            if zoom.scale < 1.05 {
                withAnimation(zoomAnimation) { zoom = FrameZoom() }
            }
        case .doubleTap(let location):
            withAnimation(zoomAnimation) {
                zoom = zoom.toggled(at: location, fitted: fitted, bounds: bounds)
            }
        }
    }

    /// A touch near an existing point grabs it (it then moves by the finger's
    /// travel, document-scanner style, so the grab needn't be exact); a touch
    /// elsewhere places the next target under the finger.
    private func beginEdit(at location: CGPoint, in display: CGRect) {
        func nearest<T>(_ items: [T], point: (T) -> CGPoint, within radius: CGFloat) -> T? {
            let closest = items.min {
                distance(FrameZoom.viewPoint(point($0), in: display), location)
                    < distance(FrameZoom.viewPoint(point($1), in: display), location)
            }
            guard let closest,
                  distance(FrameZoom.viewPoint(point(closest), in: display), location) <= radius
            else { return nil }
            return closest
        }

        switch phase {
        case .tapping:
            // Tighter while targets remain, so placing an arrow right next to
            // the one before it doesn't grab the neighbor instead.
            let grabRadius: CGFloat = taps.count < LandmarkFit.targets.count ? 28 : 44
            if let index = nearest(Array(taps.indices), point: { taps[$0] }, within: grabRadius) {
                edit = PointEdit(target: .tap(index), original: taps[index], startPoint: taps[index], touchStart: location)
            } else if taps.count < LandmarkFit.targets.count {
                let placed = FrameZoom.normalizedPoint(location, in: display)
                taps.append(placed)
                edit = PointEdit(target: .tap(taps.count - 1), original: nil, startPoint: placed, touchStart: location)
            } else {
                return
            }
            fitFailed = false
        case .refining:
            guard let corner = nearest(LaneCorners.Corner.allCases, point: { corners[$0] }, within: 70) else { return }
            edit = PointEdit(target: .corner(corner), original: corners[corner], startPoint: corners[corner], touchStart: location)
        }
    }

    private func setPoint(_ point: CGPoint, for target: PointEdit.Target) {
        switch target {
        case .tap(let index):
            if taps.indices.contains(index) {
                taps[index] = point
            }
        case .corner(let corner):
            corners[corner] = point
        }
    }

    /// A pinch or double tap that began with one finger takes back whatever
    /// that finger did.
    private func revertEdit() {
        guard let edit else { return }
        self.edit = nil
        if let original = edit.original {
            setPoint(original, for: edit.target)
        } else if case .tap(let index) = edit.target, index == taps.count - 1 {
            taps.removeLast()
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
        // The overlay is judged against the whole rack, so show the whole lane.
        withAnimation(zoomAnimation) { zoom = FrameZoom() }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    // MARK: - Layout helpers

    @ViewBuilder
    private func handle(at normalized: CGPoint, active: Bool, in rect: CGRect, bounds: CGRect) -> some View {
        let point = FrameZoom.viewPoint(normalized, in: rect)
        // Zoomed in, points off the visible part of the frame aren't drawn.
        if bounds.insetBy(dx: -14, dy: -14).contains(point) {
            Circle()
                .fill(.white)
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(Color.accentColor, lineWidth: 3))
                .scaleEffect(active ? 1.35 : 1.0)
                .animation(.easeOut(duration: 0.12), value: active)
                .position(point)
                .allowsHitTesting(false)
        }
    }

    /// Keeps the loupe off the finger: above the point when there's room, and
    /// beside it (on the roomier side) near the top of the frame, where the
    /// head pin and arrows sit. Never below, where the hand is.
    private func loupeCenter(for point: CGPoint, in bounds: CGRect) -> CGPoint {
        let radius = LoupeView.diameter / 2
        let gap: CGFloat = 50
        func clampX(_ x: CGFloat) -> CGFloat { min(max(x, bounds.minX + radius), bounds.maxX - radius) }
        if point.y - bounds.minY >= gap + 2 * radius {
            return CGPoint(x: clampX(point.x), y: point.y - gap - radius)
        }
        let x = point.x > bounds.midX ? point.x - gap - radius : point.x + gap + radius
        return CGPoint(x: clampX(x), y: min(max(point.y, bounds.minY + radius), bounds.maxY - radius))
    }

    private func fittedRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        LaneOverlayView.fittedRect(imageSize: imageSize, in: container)
    }
}

/// Magnified view of the frame around the point being placed, with a
/// crosshair marking the exact position. Same idea as the iOS text magnifier.
private struct LoupeView: View {
    let image: UIImage
    let normalizedPoint: CGPoint
    /// Where the whole frame is drawn on screen right now; the loupe
    /// magnifies relative to that, so it adds to any pinch zoom.
    let displayRect: CGRect
    let zoom: CGFloat

    static let diameter: CGFloat = 130

    var body: some View {
        Canvas { context, size in
            context.clip(to: Path(ellipseIn: CGRect(origin: .zero, size: size)))
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            let drawSize = CGSize(width: displayRect.width * zoom, height: displayRect.height * zoom)
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
        .frame(width: Self.diameter, height: Self.diameter)
        .overlay(Circle().stroke(.white, lineWidth: 2))
        .shadow(radius: 4)
    }
}
