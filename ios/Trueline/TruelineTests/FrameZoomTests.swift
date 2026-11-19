import CoreGraphics
import Testing
@testable import Trueline

@Suite("Calibration frame zoom mapping")
struct FrameZoomTests {
    /// A portrait 1080x1920 frame aspect-fit into a 393x600 viewport: height
    /// limited, so the frame has empty bars left and right at 1x.
    static let bounds = CGRect(x: 0, y: 0, width: 393, height: 600)
    static let fitted = CGRect(x: (393 - 337.5) / 2, y: 0, width: 337.5, height: 600)

    static func close(_ a: CGPoint, _ b: CGPoint, _ tolerance: CGFloat = 1e-9) -> Bool {
        abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance
    }

    @Test("at 1x the display rect is the aspect-fit rect")
    func identityIsFitted() {
        #expect(FrameZoom().displayRect(fitted: Self.fitted, bounds: Self.bounds) == Self.fitted)
    }

    @Test("view and normalized coordinates round-trip at any zoom", arguments: [1.0, 2.5, 6.0] as [CGFloat])
    func roundTrip(scale: CGFloat) {
        let zoom = FrameZoom(scale: scale, center: CGPoint(x: 0.42, y: 0.2)).clamped(fitted: Self.fitted, bounds: Self.bounds)
        let rect = zoom.displayRect(fitted: Self.fitted, bounds: Self.bounds)
        for point in [CGPoint(x: 0.5, y: 0.13), CGPoint(x: 0.1, y: 0.9), CGPoint(x: 0.42, y: 0.2)] {
            let view = FrameZoom.viewPoint(point, in: rect)
            #expect(Self.close(FrameZoom.normalizedPoint(view, in: rect), point))
        }
    }

    @Test("a point placed while zoomed lands on the same frame spot at 1x")
    func placementWhileZoomed() {
        // Zoom 3x on the arrows and touch the middle of the viewport.
        let zoom = FrameZoom(scale: 3, center: CGPoint(x: 0.5, y: 0.3)).clamped(fitted: Self.fitted, bounds: Self.bounds)
        let rect = zoom.displayRect(fitted: Self.fitted, bounds: Self.bounds)
        let placed = FrameZoom.normalizedPoint(CGPoint(x: Self.bounds.midX, y: Self.bounds.midY), in: rect)
        #expect(Self.close(placed, CGPoint(x: 0.5, y: 0.3)))
        // The same normalized point drawn at 1x sits where the fitted frame
        // has that spot, so overlay and points stay locked to the picture.
        let atFit = FrameZoom.viewPoint(placed, in: Self.fitted)
        #expect(Self.close(atFit, CGPoint(x: Self.fitted.minX + 0.5 * 337.5, y: 0.3 * 600)))
    }

    @Test("finger travel moves a point less the further you zoom")
    func dragDeltaScales() {
        let rect1 = FrameZoom().displayRect(fitted: Self.fitted, bounds: Self.bounds)
        let rect3 = FrameZoom(scale: 3).displayRect(fitted: Self.fitted, bounds: Self.bounds)
        let d1 = FrameZoom.normalizedDelta(CGSize(width: 30, height: 30), in: rect1)
        let d3 = FrameZoom.normalizedDelta(CGSize(width: 30, height: 30), in: rect3)
        #expect(abs(d1.width / d3.width - 3) < 1e-9)
        #expect(abs(d1.height / d3.height - 3) < 1e-9)
    }

    @Test("panning stops at the frame's edges")
    func clampsToEdges() {
        let zoom = FrameZoom(scale: 2, center: CGPoint(x: -1, y: 5)).clamped(fitted: Self.fitted, bounds: Self.bounds)
        let rect = zoom.displayRect(fitted: Self.fitted, bounds: Self.bounds)
        // Zoomed 2x the frame (675 wide) is wider than the viewport, so it
        // must cover it with no empty edge: left edge pinned, bottom pinned.
        #expect(rect.minX == Self.bounds.minX)
        #expect(rect.maxY == Self.bounds.maxY)
        #expect(rect.maxX >= Self.bounds.maxX)
        #expect(rect.minY <= Self.bounds.minY)
        // Stored center matches what's drawn, so the next pan starts there.
        #expect(Self.close(zoom.center, FrameZoom.normalizedPoint(CGPoint(x: Self.bounds.midX, y: Self.bounds.midY), in: rect)))
    }

    @Test("a frame narrower than the viewport stays centered on that axis")
    func narrowAxisCenters() {
        // 1.1x: 371 wide, still narrower than 393, so it can't pan sideways.
        let zoom = FrameZoom(scale: 1.1, center: CGPoint(x: 0.1, y: 0.5))
        let rect = zoom.displayRect(fitted: Self.fitted, bounds: Self.bounds)
        #expect(abs(rect.midX - Self.bounds.midX) < 1e-9)
    }

    @Test("scale stays between fit and the maximum")
    func scaleLimits() {
        #expect(FrameZoom(scale: 0.4).clamped(fitted: Self.fitted, bounds: Self.bounds).scale == 1)
        #expect(FrameZoom(scale: 40).clamped(fitted: Self.fitted, bounds: Self.bounds).scale == FrameZoom.maxScale)
    }

    @Test("pinching keeps the frame spot under the fingers")
    func pinchKeepsAnchor() {
        let anchor = CGPoint(x: 0.5, y: 0.3)
        let fingers = CGPoint(x: 200, y: 260)
        let zoom = FrameZoom().pinched(anchor: anchor, to: fingers, scale: 3, fitted: Self.fitted, bounds: Self.bounds)
        let rect = zoom.displayRect(fitted: Self.fitted, bounds: Self.bounds)
        #expect(zoom.scale == 3)
        #expect(Self.close(FrameZoom.viewPoint(anchor, in: rect), fingers, 1e-6))
    }

    @Test("two-finger pan at a fixed scale moves the frame with the fingers")
    func twoFingerPan() {
        let start = FrameZoom(scale: 3, center: CGPoint(x: 0.5, y: 0.5))
        let startRect = start.displayRect(fitted: Self.fitted, bounds: Self.bounds)
        let midpoint = CGPoint(x: 200, y: 300)
        let anchor = FrameZoom.normalizedPoint(midpoint, in: startRect)
        let moved = CGPoint(x: 240, y: 340)
        let panned = start.pinched(anchor: anchor, to: moved, scale: 3, fitted: Self.fitted, bounds: Self.bounds)
        let rect = panned.displayRect(fitted: Self.fitted, bounds: Self.bounds)
        #expect(abs(rect.minX - startRect.minX - 40) < 1e-6)
        #expect(abs(rect.minY - startRect.minY - 40) < 1e-6)
    }

    @Test("double tap zooms onto the tapped spot, and back to fit")
    func doubleTapToggles() {
        let tap = CGPoint(x: 196.5, y: 120)
        let fit = FrameZoom()
        let tappedSpot = FrameZoom.normalizedPoint(tap, in: Self.fitted)
        let zoomed = fit.toggled(at: tap, fitted: Self.fitted, bounds: Self.bounds)
        #expect(zoomed.scale == FrameZoom.doubleTapScale)
        // Away from the edges, the tapped spot moves to the viewport center.
        let rect = zoomed.displayRect(fitted: Self.fitted, bounds: Self.bounds)
        #expect(Self.close(FrameZoom.viewPoint(tappedSpot, in: rect), CGPoint(x: Self.bounds.midX, y: Self.bounds.midY), 1e-6))
        #expect(zoomed.toggled(at: tap, fitted: Self.fitted, bounds: Self.bounds) == FrameZoom())
    }

    @Test("double tap near an edge zooms as far as the edge allows")
    func doubleTapAtEdge() {
        let zoomed = FrameZoom().toggled(at: CGPoint(x: 40, y: 5), fitted: Self.fitted, bounds: Self.bounds)
        let rect = zoomed.displayRect(fitted: Self.fitted, bounds: Self.bounds)
        #expect(rect.minX == Self.bounds.minX)
        #expect(rect.minY == Self.bounds.minY)
    }
}
