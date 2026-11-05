import AVFoundation
import CoreGraphics
import Vision
import simd

/// Notices a bumped phone between throws. The session's calibration was
/// tapped on one frame; every later throw reuses it. If the phone moved even a
/// few pixels, the stale corners skew the metrics (a 4 px bump moves entry
/// board by about 1.6 boards). So each throw's first frame is registered
/// against the calibration frame, and the corners are carried through the
/// estimated camera motion, or the user is asked to recalibrate when the
/// motion is too big to trust.
///
/// Only the top half of the portrait frame is compared: far lane, pin deck,
/// masking unit and ceiling. The bowler and the approach never enter it.
/// Prototype and measurements: experiments/drift_check/README.md.
enum DriftCheck {
    /// Fraction of the frame's height, from the top, that is compared.
    static let bandFraction = 0.5
    /// Width the band is downscaled to. 540 is half of a 1080p frame, the
    /// scale the prototype was measured at.
    static let bandWidth = 540
    /// Alignment score (normalized cross-correlation after warping) below
    /// which the registration is not trusted. Good alignments measured
    /// 0.983-0.998, wrong ones on re-propped phones 0.55-0.83.
    static let minScore = 0.95
    /// Corrections that move the pin deck more than this are untested, so
    /// they ask for a new calibration even when the score passes.
    static let maxDeckBoards = 8.0
    /// From this much deck motion up, the review step says the lane was
    /// re-aligned.
    static let noticeDeckBoards = 1.0

    /// The calibration frame's comparison band, kept for the session.
    struct Reference {
        /// Grayscale, `bandWidth` wide, top `bandFraction` of the frame.
        let band: GrayImage
        /// Full display-oriented frame size, for measuring motion in pixels.
        let frameSize: CGSize
    }

    enum Verdict: Equatable {
        /// Use the corrected corners. `noticeable` means the deck moved enough
        /// that the user should be told the lane was re-aligned.
        case corrected(noticeable: Bool)
        /// The phone moved too much to fix; recalibrate.
        case recalibrate
    }

    struct Result {
        let verdict: Verdict
        /// The session corners carried onto this throw. Equal to the input
        /// when the verdict is `.recalibrate`.
        let corners: LaneCorners
        /// Motion of the pin deck, in boards.
        let deckBoards: Double
        let score: Double
        /// This throw's band: after a correction it becomes the session's
        /// reference, so slow sag never accumulates past the gate.
        let reference: Reference
    }

    // MARK: - Gate

    static func verdict(score: Double, deckBoards: Double) -> Verdict {
        if score < minScore || deckBoards > maxDeckBoards || !deckBoards.isFinite {
            return .recalibrate
        }
        return .corrected(noticeable: deckBoards >= noticeDeckBoards)
    }

    /// How far the pin deck (the far corners) moved, in boards at the deck.
    /// `frameSize` turns normalized corners into pixels so the motion is
    /// measured the same in x and y.
    static func deckMotionBoards(from old: LaneCorners, to new: LaneCorners, frameSize: CGSize) -> Double {
        func px(_ p: CGPoint) -> SIMD2<Double> {
            SIMD2(Double(p.x * frameSize.width), Double(p.y * frameSize.height))
        }
        let deckWidth = simd_length(px(old.farRight) - px(old.farLeft))
        guard deckWidth > 1 else { return .infinity }
        let moved = max(
            simd_length(px(new.farLeft) - px(old.farLeft)),
            simd_length(px(new.farRight) - px(old.farRight))
        )
        return moved / (deckWidth / LaneModel.boardCount)
    }

    // MARK: - Corner transform

    /// Applies a homography in normalized image coordinates (top-left origin)
    /// to every corner.
    static func warp(_ corners: LaneCorners, by h: simd_double3x3) -> LaneCorners {
        var out = corners
        for c in LaneCorners.Corner.allCases {
            out[c] = apply(h, corners[c])
        }
        return out
    }

    static func apply(_ h: simd_double3x3, _ p: CGPoint) -> CGPoint {
        let v = h * SIMD3(Double(p.x), Double(p.y), 1)
        return CGPoint(x: v.x / v.z, y: v.y / v.z)
    }

    // MARK: - Pipeline

    /// The comparison band of a clip's first frame.
    static func reference(fromClip url: URL) async -> Reference? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        guard let (frame, _) = try? await generator.image(at: .zero) else { return nil }
        return reference(fromFrame: frame)
    }

    /// The comparison band of a display-oriented frame.
    static func reference(fromFrame frame: CGImage) -> Reference? {
        let bandHeight = Int((Double(frame.height) * bandFraction).rounded())
        guard frame.width > 0, bandHeight > 0,
              let crop = frame.cropping(to: CGRect(x: 0, y: 0, width: frame.width, height: bandHeight))
        else { return nil }
        let scale = Double(bandWidth) / Double(frame.width)
        let h = max(1, Int((Double(bandHeight) * scale).rounded()))
        guard let band = GrayImage(crop, width: bandWidth, height: h) else { return nil }
        return Reference(band: band, frameSize: CGSize(width: frame.width, height: frame.height))
    }

    /// Registers `throwClip`'s first frame against the session reference and
    /// carries the session corners onto it.
    static func check(throwClip url: URL, against ref: Reference, corners: LaneCorners) async -> Result? {
        guard let target = await reference(fromClip: url) else { return nil }
        return check(target: target, against: ref, corners: corners)
    }

    static func check(target: Reference, against ref: Reference, corners: LaneCorners) -> Result? {
        // Different frame shapes (another camera or orientation) can't be
        // compared band to band.
        guard target.band.width == ref.band.width, target.band.height == ref.band.height,
              let hBand = registerBands(ref: ref.band, target: target.band)
        else { return nil }
        let score = alignmentScore(ref: ref.band, target: target.band, h: hBand)
        let hNorm = bandToNormalized(hBand, band: ref.band)
        let moved = warp(corners, by: hNorm)
        let boards = deckMotionBoards(from: corners, to: moved, frameSize: ref.frameSize)
        let v = verdict(score: score, deckBoards: boards)
        return Result(
            verdict: v,
            corners: v == .recalibrate ? corners : moved,
            deckBoards: boards,
            score: score,
            reference: target
        )
    }

    /// Vision homographic registration. Returns the map from reference band
    /// pixels to target band pixels, top-left origin.
    static func registerBands(ref: GrayImage, target: GrayImage) -> simd_double3x3? {
        guard let refImage = ref.cgImage, let targetImage = target.cgImage else { return nil }
        let request = VNHomographicImageRegistrationRequest(targetedCGImage: targetImage, options: [:])
        let handler = VNImageRequestHandler(cgImage: refImage, options: [:])
        do { try handler.perform([request]) } catch { return nil }
        guard let obs = request.results?.first as? VNImageHomographicAlignmentObservation else { return nil }
        let w = obs.warpTransform
        let v = simd_double3x3(columns: (
            SIMD3<Double>(w.columns.0), SIMD3<Double>(w.columns.1), SIMD3<Double>(w.columns.2)
        ))
        // Vision works in bottom-left pixel coordinates and its warp maps the
        // target onto the reference; flip y on both sides, then invert so the
        // result carries reference points to the target (verified by the
        // synthetic-shift test).
        let flip = simd_double3x3(rows: [
            SIMD3(1, 0, 0), SIMD3(0, -1, Double(ref.height)), SIMD3(0, 0, 1),
        ])
        let topLeft = (flip * v * flip).inverse
        guard topLeft[2][2].isFinite, abs(topLeft[2][2]) > 1e-12 else { return nil }
        return topLeft * (1 / topLeft[2][2])
    }

    /// Band pixels to normalized full-frame coordinates: the band spans the
    /// frame's full width and the top `bandFraction` of its height.
    static func bandToNormalized(_ h: simd_double3x3, band: GrayImage) -> simd_double3x3 {
        let n = simd_double3x3(diagonal: SIMD3(
            Double(band.width), Double(band.height) / bandFraction, 1
        ))
        let out = n.inverse * h * n
        return out * (1 / out[2][2])
    }

    /// Normalized cross-correlation between the reference band and the target
    /// sampled through `h`. A wrong registration leaves the images misaligned
    /// and the score drops, which is what separates "fix it" from
    /// "recalibrate" (the size of a wrong estimate can't be trusted).
    static func alignmentScore(ref: GrayImage, target: GrayImage, h: simd_double3x3) -> Double {
        var sx = 0.0, sy = 0.0, sxx = 0.0, syy = 0.0, sxy = 0.0, n = 0.0
        for y in stride(from: 0, to: ref.height, by: 2) {
            for x in stride(from: 0, to: ref.width, by: 2) {
                let q = apply(h, CGPoint(x: x, y: y))
                let qx = Int(q.x.rounded()), qy = Int(q.y.rounded())
                guard qx >= 0, qy >= 0, qx < target.width, qy < target.height else { continue }
                let a = Double(ref.pixels[y * ref.width + x])
                let b = Double(target.pixels[qy * target.width + qx])
                sx += a; sy += b; sxx += a * a; syy += b * b; sxy += a * b; n += 1
            }
        }
        guard n > 100 else { return 0 }
        let cov = sxy - sx * sy / n
        let vx = sxx - sx * sx / n, vy = syy - sy * sy / n
        guard vx > 0, vy > 0 else { return 0 }
        return cov / (vx * vy).squareRoot()
    }
}

/// 8-bit grayscale bitmap, top row first.
struct GrayImage {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// Draws `image` into a grayscale bitmap of the given size.
    init?(_ image: CGImage, width: Int, height: Int) {
        var buf = [UInt8](repeating: 0, count: width * height)
        let ok = buf.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard ok else { return nil }
        self.init(width: width, height: height, pixels: buf)
    }

    var cgImage: CGImage? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }
}
