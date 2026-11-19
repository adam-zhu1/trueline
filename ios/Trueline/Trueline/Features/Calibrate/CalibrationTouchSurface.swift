import SwiftUI
import UIKit

/// Raw touch handling for the calibration frame. One finger places or nudges
/// a point (touch, slide, lift), two fingers pinch and pan the frame, and a
/// double tap toggles zoom. SwiftUI on iOS 17 can't read a pinch's moving
/// midpoint, and its one-finger drag would already have dropped a point by
/// the time a second finger lands, so this view sorts the touches out first
/// and reports what the user meant.
struct CalibrationTouchSurface: UIViewRepresentable {
    enum Event {
        /// One finger is down (reported after a short beat, so a pinch that
        /// lands one finger first never flashes a point).
        case began(CGPoint)
        case moved(CGPoint)
        /// The finger lifted. The edit is final unless `cancelled` follows
        /// (a quick tap waits briefly in case it's the first of a double tap).
        case lifted
        case committed
        /// Undo whatever the current one-finger touch did.
        case cancelled
        case pinchBegan(midpoint: CGPoint, span: CGFloat)
        case pinchChanged(midpoint: CGPoint, span: CGFloat)
        case pinchEnded
        case doubleTap(CGPoint)
    }

    var onEvent: (Event) -> Void

    func makeUIView(context: Context) -> CalibrationTouchView {
        let view = CalibrationTouchView()
        view.onEvent = onEvent
        return view
    }

    func updateUIView(_ view: CalibrationTouchView, context: Context) {
        view.onEvent = onEvent
    }
}

final class CalibrationTouchView: UIView {
    var onEvent: (CalibrationTouchSurface.Event) -> Void = { _ in }

    private enum Mode {
        case idle
        /// One finger down, not yet reported: waiting to see if a second joins.
        case pendingSingle
        case single
        case pinch
        /// Second tap of a possible double tap.
        case secondTap
        /// A pinch ended with a finger still down; ignore it until it lifts.
        case ignoring
    }

    /// How long a lone finger waits for a partner before it counts as a
    /// one-finger touch. Short enough to be invisible.
    private static let singleDelay: TimeInterval = 0.06
    private static let doubleTapWindow: TimeInterval = 0.25
    private static let tapSlop: CGFloat = 10
    private static let doubleTapDistance: CGFloat = 44

    private var mode = Mode.idle
    private var touches: [UITouch] = []
    private var start: (point: CGPoint, time: TimeInterval) = (.zero, 0)
    private var travel: CGFloat = 0
    private var singleTimer: Timer?
    /// A quick tap's commit, held for the double-tap window.
    private var pendingCommit: (point: CGPoint, work: DispatchWorkItem)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func touchesBegan(_ newTouches: Set<UITouch>, with event: UIEvent?) {
        touches.append(contentsOf: newTouches)
        let location = newTouches.first?.location(in: self) ?? .zero

        if let pending = pendingCommit {
            pendingCommit = nil
            pending.work.cancel()
            if mode == .idle, touches.count == 1,
               hypot(location.x - pending.point.x, location.y - pending.point.y) <= Self.doubleTapDistance {
                // Second tap: the first tap's point goes away and the frame zooms.
                onEvent(.cancelled)
                mode = .secondTap
                beginTracking(at: location)
                return
            }
            onEvent(.committed)
        }

        switch mode {
        case .idle:
            beginTracking(at: location)
            if touches.count >= 2 {
                beginPinch()
            } else {
                mode = .pendingSingle
                singleTimer = Timer.scheduledTimer(withTimeInterval: Self.singleDelay, repeats: false) { [weak self] _ in
                    self?.startSingle()
                }
            }
        case .pendingSingle, .secondTap:
            if touches.count >= 2 {
                beginPinch()
            }
        case .single:
            if touches.count >= 2 {
                onEvent(.cancelled)
                beginPinch()
            }
        case .pinch, .ignoring:
            break
        }
    }

    override func touchesMoved(_ movedTouches: Set<UITouch>, with event: UIEvent?) {
        switch mode {
        case .pendingSingle:
            updateTravel()
            if travel > 6 {
                startSingle()
                onEvent(.moved(primaryLocation))
            }
        case .single:
            updateTravel()
            onEvent(.moved(primaryLocation))
        case .secondTap:
            updateTravel()
        case .pinch:
            if let pinch = pinchGeometry {
                onEvent(.pinchChanged(midpoint: pinch.midpoint, span: pinch.span))
            }
        case .idle, .ignoring:
            break
        }
    }

    override func touchesEnded(_ endedTouches: Set<UITouch>, with event: UIEvent?) {
        finish(endedTouches, cancelled: false)
    }

    override func touchesCancelled(_ cancelledTouches: Set<UITouch>, with event: UIEvent?) {
        finish(cancelledTouches, cancelled: true)
    }

    // MARK: - State machine

    private var primaryLocation: CGPoint {
        touches.first?.location(in: self) ?? start.point
    }

    private var pinchGeometry: (midpoint: CGPoint, span: CGFloat)? {
        guard touches.count >= 2 else { return nil }
        let a = touches[0].location(in: self)
        let b = touches[1].location(in: self)
        return (CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2), max(hypot(a.x - b.x, a.y - b.y), 1))
    }

    private func beginTracking(at location: CGPoint) {
        start = (location, CACurrentMediaTime())
        travel = 0
    }

    private func updateTravel() {
        let p = primaryLocation
        travel = max(travel, hypot(p.x - start.point.x, p.y - start.point.y))
    }

    private func startSingle() {
        singleTimer?.invalidate()
        singleTimer = nil
        guard mode == .pendingSingle else { return }
        mode = .single
        onEvent(.began(start.point))
    }

    private func beginPinch() {
        singleTimer?.invalidate()
        singleTimer = nil
        mode = .pinch
        if let pinch = pinchGeometry {
            onEvent(.pinchBegan(midpoint: pinch.midpoint, span: pinch.span))
        }
    }

    private func finish(_ ended: Set<UITouch>, cancelled: Bool) {
        touches.removeAll { ended.contains($0) }

        switch mode {
        case .pendingSingle:
            // Lifted before the beat ran out: a quick tap still places a point.
            startSingle()
            finishSingle(cancelled: cancelled)
        case .single:
            finishSingle(cancelled: cancelled)
        case .secondTap:
            guard touches.isEmpty else { return }
            mode = .idle
            if !cancelled, travel <= Self.doubleTapDistance {
                onEvent(.doubleTap(start.point))
            }
        case .pinch:
            guard touches.count < 2 else { return }
            onEvent(.pinchEnded)
            mode = touches.isEmpty ? .idle : .ignoring
        case .ignoring:
            if touches.isEmpty {
                mode = .idle
            }
        case .idle:
            break
        }
    }

    private func finishSingle(cancelled: Bool) {
        guard touches.isEmpty else { return }
        mode = .idle
        if cancelled {
            onEvent(.cancelled)
            return
        }
        onEvent(.lifted)
        let quick = CACurrentMediaTime() - start.time < 0.3 && travel < Self.tapSlop
        guard quick else {
            onEvent(.committed)
            return
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.pendingCommit != nil else { return }
            self.pendingCommit = nil
            self.onEvent(.committed)
        }
        pendingCommit = (start.point, work)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.doubleTapWindow, execute: work)
    }
}
