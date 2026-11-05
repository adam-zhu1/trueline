import CoreGraphics
import Testing
import simd
@testable import Trueline

@Suite("Calibration drift check")
struct DriftCheckTests {
    static let corners = LaneCorners(
        farLeft: CGPoint(x: 0.44, y: 0.14),
        farRight: CGPoint(x: 0.59, y: 0.14),
        nearRight: CGPoint(x: 0.84, y: 0.95),
        nearLeft: CGPoint(x: 0.15, y: 0.95)
    )
    static let frameSize = CGSize(width: 1080, height: 1920)

    // MARK: corner transform

    @Test("warping corners applies the homography to every corner")
    func warpAppliesHomography() {
        // Shift right by 0.01 and down by 0.02, then scale about the origin.
        let h = simd_double3x3(rows: [
            SIMD3(1.02, 0, 0.01), SIMD3(0, 1.02, 0.02), SIMD3(0, 0, 1),
        ])
        let out = DriftCheck.warp(Self.corners, by: h)
        for c in LaneCorners.Corner.allCases {
            let p = Self.corners[c]
            let want = CGPoint(x: 1.02 * p.x + 0.01, y: 1.02 * p.y + 0.02)
            #expect(isClose(out[c], want, 1e-12))
        }
    }

    @Test("identity homography leaves corners and deck motion at zero")
    func identityIsNoMotion() {
        let out = DriftCheck.warp(Self.corners, by: matrix_identity_double3x3)
        #expect(out == Self.corners)
        #expect(DriftCheck.deckMotionBoards(from: Self.corners, to: out, frameSize: Self.frameSize) == 0)
    }

    @Test("deck motion is measured in boards at the pin deck")
    func deckMotionInBoards() {
        let deckPx = Double((Self.corners.farRight.x - Self.corners.farLeft.x) * Self.frameSize.width)
        let boardPx = deckPx / LaneModel.boardCount
        var moved = Self.corners
        // Two boards sideways at the deck; the near corners don't count.
        moved.farLeft.x += 2 * boardPx / Self.frameSize.width
        moved.farRight.x += 2 * boardPx / Self.frameSize.width
        moved.nearLeft.x += 0.2
        let boards = DriftCheck.deckMotionBoards(from: Self.corners, to: moved, frameSize: Self.frameSize)
        #expect(isClose(boards, 2, 1e-9))
    }

    // MARK: gate

    @Test("gate: low score or a big move asks to recalibrate, otherwise corrects")
    func gate() {
        #expect(DriftCheck.verdict(score: 0.94, deckBoards: 0.2) == .recalibrate)
        #expect(DriftCheck.verdict(score: 0.83, deckBoards: 0.1) == .recalibrate)
        #expect(DriftCheck.verdict(score: 0.99, deckBoards: 8.5) == .recalibrate)
        #expect(DriftCheck.verdict(score: 0.99, deckBoards: .infinity) == .recalibrate)
        #expect(DriftCheck.verdict(score: 0.99, deckBoards: 0.4) == .corrected(noticeable: false))
        #expect(DriftCheck.verdict(score: 0.96, deckBoards: 1.0) == .corrected(noticeable: true))
        #expect(DriftCheck.verdict(score: 0.99, deckBoards: 7.9) == .corrected(noticeable: true))
    }

    // MARK: registration on generated images

    /// A textured band: smooth gradients plus scattered bright and dark
    /// blocks, so registration has structure to lock onto. Pixel (x, y)
    /// samples the pattern at (x - dx, y - dy), so content moves by (dx, dy).
    static func pattern(width: Int, height: Int, dx: Double = 0, dy: Double = 0, seed: UInt64 = 1) -> GrayImage {
        var rng = SplitMix(seed: seed)
        let blocks = (0..<60).map { _ in
            (x: rng.next() * Double(width), y: rng.next() * Double(height),
             w: 8 + rng.next() * 40, h: 8 + rng.next() * 40, v: rng.next() > 0.5 ? 230.0 : 25.0)
        }
        var px = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let sx = Double(x) - dx, sy = Double(y) - dy
                var v = 120 + 40 * sin(sx / 23) * cos(sy / 31) + 0.08 * sx
                for b in blocks where sx >= b.x && sx < b.x + b.w && sy >= b.y && sy < b.y + b.h {
                    v = b.v
                }
                px[y * width + x] = UInt8(max(0, min(255, v)))
            }
        }
        return GrayImage(width: width, height: height, pixels: px)
    }

    @Test("a known shift is recovered and scores as a good alignment")
    func syntheticShift() throws {
        let w = DriftCheck.bandWidth, h = 480
        let ref = Self.pattern(width: w, height: h)
        let target = Self.pattern(width: w, height: h, dx: 6, dy: -4)
        let hBand = try #require(DriftCheck.registerBands(ref: ref, target: target))
        for p in [CGPoint(x: 100, y: 100), CGPoint(x: 400, y: 300), CGPoint(x: 270, y: 240)] {
            let q = DriftCheck.apply(hBand, p)
            #expect(isClose(q, CGPoint(x: p.x + 6, y: p.y - 4), 0.75))
        }
        #expect(DriftCheck.alignmentScore(ref: ref, target: target, h: hBand) > DriftCheck.minScore)
    }

    @Test("full check carries the corners by the shift; an unrelated view asks to recalibrate")
    func fullCheck() throws {
        let w = DriftCheck.bandWidth, h = 480
        let size = CGSize(width: 1080, height: 1920)  // band = top half at 0.5 scale
        let ref = DriftCheck.Reference(band: Self.pattern(width: w, height: h), frameSize: size)
        let bumped = DriftCheck.Reference(band: Self.pattern(width: w, height: h, dx: 5, dy: 3), frameSize: size)
        let result = try #require(DriftCheck.check(target: bumped, against: ref, corners: Self.corners))
        // 5 band px = 10 frame px across, 3 band px = 6 frame px down.
        #expect(isClose(result.corners.farLeft,
                        CGPoint(x: Self.corners.farLeft.x + 10 / 1080, y: Self.corners.farLeft.y + 6 / 1920),
                        0.0015))
        if case .corrected = result.verdict {} else { Issue.record("expected a correction, got \(result.verdict)") }

        let other = DriftCheck.Reference(band: Self.pattern(width: w, height: h, seed: 99), frameSize: size)
        if let moved = DriftCheck.check(target: other, against: ref, corners: Self.corners) {
            #expect(moved.verdict == .recalibrate)
            #expect(moved.corners == Self.corners)
        }
    }
}

/// Small deterministic generator so the test pattern is the same every run.
struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }
}
