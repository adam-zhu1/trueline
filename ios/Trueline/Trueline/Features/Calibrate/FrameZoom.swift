import CoreGraphics

/// Zoom and pan state for the calibration frame. Every calibration point is
/// stored in normalized frame coordinates (0...1 on both axes), so zooming
/// only changes where the frame is drawn: `displayRect` is the rect the whole
/// frame occupies in view space, and the two mapping functions convert
/// through it. Points and the lane overlay stay locked to the picture at any
/// zoom because they all go through the same rect.
struct FrameZoom: Equatable {
    static let maxScale: CGFloat = 6
    /// Double-tap target: enough to make an arrow a comfortable target
    /// without losing the lane around it.
    static let doubleTapScale: CGFloat = 2.5

    /// 1 = the aspect-fit frame.
    var scale: CGFloat = 1
    /// The normalized frame point drawn at the middle of the viewport.
    var center = CGPoint(x: 0.5, y: 0.5)

    var isZoomed: Bool { scale > 1.01 }

    /// Where the whole frame is drawn. Along each axis the frame either fills
    /// the viewport with no empty edge showing, or (when it's narrower than
    /// the viewport) sits centered, so panning can never lose the picture.
    func displayRect(fitted: CGRect, bounds: CGRect) -> CGRect {
        let width = fitted.width * scale
        let height = fitted.height * scale
        let x = Self.clampedOrigin(bounds.midX - center.x * width, length: width, from: bounds.minX, to: bounds.maxX)
        let y = Self.clampedOrigin(bounds.midY - center.y * height, length: height, from: bounds.minY, to: bounds.maxY)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// The same zoom with `center` pulled back to what `displayRect` draws,
    /// so stored state never drifts past the frame's edges.
    func clamped(fitted: CGRect, bounds: CGRect) -> FrameZoom {
        var zoom = self
        zoom.scale = min(max(scale, 1), Self.maxScale)
        let rect = zoom.displayRect(fitted: fitted, bounds: bounds)
        zoom.center = CGPoint(
            x: (bounds.midX - rect.minX) / rect.width,
            y: (bounds.midY - rect.minY) / rect.height
        )
        return zoom
    }

    /// Pinch and two-finger pan in one step: the frame point that was under
    /// the fingers when the pinch began (`anchor`, normalized) stays under
    /// their current midpoint at the new scale, as in Photos.
    func pinched(anchor: CGPoint, to location: CGPoint, scale newScale: CGFloat, fitted: CGRect, bounds: CGRect) -> FrameZoom {
        let scale = min(max(newScale, 1), Self.maxScale)
        let width = fitted.width * scale
        let height = fitted.height * scale
        let origin = CGPoint(x: location.x - anchor.x * width, y: location.y - anchor.y * height)
        return FrameZoom(
            scale: scale,
            center: CGPoint(x: (bounds.midX - origin.x) / width, y: (bounds.midY - origin.y) / height)
        ).clamped(fitted: fitted, bounds: bounds)
    }

    /// Double tap toggles between the fitted frame and `doubleTapScale`
    /// centered on the tapped spot (as far as the frame's edges allow).
    func toggled(at location: CGPoint, fitted: CGRect, bounds: CGRect) -> FrameZoom {
        if isZoomed {
            return FrameZoom()
        }
        let tapped = Self.normalizedPoint(location, in: displayRect(fitted: fitted, bounds: bounds))
        return FrameZoom(scale: Self.doubleTapScale, center: tapped).clamped(fitted: fitted, bounds: bounds)
    }

    /// Normalized frame point → view point, through the current display rect.
    static func viewPoint(_ normalized: CGPoint, in displayRect: CGRect) -> CGPoint {
        CGPoint(
            x: displayRect.minX + normalized.x * displayRect.width,
            y: displayRect.minY + normalized.y * displayRect.height
        )
    }

    /// View point → normalized frame point, clamped onto the frame.
    static func normalizedPoint(_ location: CGPoint, in displayRect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max((location.x - displayRect.minX) / displayRect.width, 0), 1),
            y: min(max((location.y - displayRect.minY) / displayRect.height, 0), 1)
        )
    }

    /// A finger drag of `translation` view points moves a point by this much
    /// in normalized coordinates. Zoomed in, the same finger travel moves the
    /// point less, which is where the extra precision comes from.
    static func normalizedDelta(_ translation: CGSize, in displayRect: CGRect) -> CGSize {
        CGSize(width: translation.width / displayRect.width, height: translation.height / displayRect.height)
    }

    private static func clampedOrigin(_ origin: CGFloat, length: CGFloat, from low: CGFloat, to high: CGFloat) -> CGFloat {
        if length <= high - low {
            return (low + high - length) / 2
        }
        return min(max(origin, high - length), low)
    }
}
