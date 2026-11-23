import Foundation
import Testing
@testable import Trueline

/// The metric fits ShotAnalyzer runs on the measured series: launch speed
/// (least squares over the first 16 ft) and entry board / angle (one fit
/// through the back end, cut at pin deflection). Numbers that moved on the
/// accuracy benchmark (experiments/accuracy_bench) are locked in here on
/// synthetic tracks with known answers.
@Suite("Shot metric fits")
struct ShotMetricFitTests {
    // MARK: Launch speed

    /// 22 ft/s is 15.0 mph.
    static func track(feetPerSecond v: Double, from start: Double, fps: Double, count: Int,
                      noise: (Int) -> Double = { _ in 0 }) -> (feet: [Double], frames: [Double]) {
        let frames = (0..<count).map { Double(100 + $0) }
        let feet = frames.indices.map { start + v * Double($0) / fps + noise($0) }
        return (feet, frames)
    }

    @Test("constant speed reads exactly", arguments: [30.0, 60.0])
    func constantSpeed(fps: Double) throws {
        let t = Self.track(feetPerSecond: 22, from: 2, fps: fps, count: Int(fps))
        let mph = try #require(ShotAnalyzer.launchSpeedMph(feet: t.feet, frames: t.frames, fps: fps))
        #expect(isClose(mph, 22 * 0.681818, 1e-6))
    }

    @Test("frame-to-frame jitter averages out instead of landing on two crossings")
    func jitterAveragesOut() throws {
        // ±0.4 ft alternating error, what a lagging/noisy contact point does.
        let t = Self.track(feetPerSecond: 22, from: 2, fps: 30, count: 30) { $0 % 2 == 0 ? 0.4 : -0.4 }
        let mph = try #require(ShotAnalyzer.launchSpeedMph(feet: t.feet, frames: t.frames, fps: 30))
        #expect(abs(mph - 15.0) < 0.3)
    }

    @Test("only the first 16 ft count: a slower back end doesn't drag launch speed down")
    func windowIsTheFront() throws {
        var t = Self.track(feetPerSecond: 22, from: 2, fps: 30, count: 60)
        // Past 18 ft the ball slows to 18 ft/s.
        var last = 0.0
        for i in t.feet.indices {
            if t.feet[i] > 18 {
                last += 18.0 / 30.0
                t.feet[i] = 18 + last
            }
        }
        let mph = try #require(ShotAnalyzer.launchSpeedMph(feet: t.feet, frames: t.frames, fps: 30))
        #expect(abs(mph - 15.0) < 0.05)
    }

    @Test("a mid-lane lock is not a launch speed")
    func midLaneLockRefused() {
        let t = Self.track(feetPerSecond: 22, from: 16, fps: 30, count: 30)
        #expect(ShotAnalyzer.launchSpeedMph(feet: t.feet, frames: t.frames, fps: 30) == nil)
    }

    @Test("too short a span is refused")
    func shortSpanRefused() {
        let t = Self.track(feetPerSecond: 22, from: 2, fps: 30, count: 6)  // ~3.7 ft
        #expect(ShotAnalyzer.launchSpeedMph(feet: t.feet, frames: t.frames, fps: 30) == nil)
    }

    // MARK: Entry board and angle

    /// A hooking back end: board = a + b(f - 59.5) + c(f - 59.5)², sampled
    /// every 0.9 ft from 38 ft to `end`.
    static func hook(a: Double, b: Double, c: Double, end: Double = 59.0) -> (boards: [Double], feet: [Double]) {
        let feet = stride(from: 38.0, through: end, by: 0.9).map { $0 }
        let boards = feet.map { a + b * ($0 - 59.5) + c * ($0 - 59.5) * ($0 - 59.5) }
        return (boards, feet)
    }

    @Test("a curving back end reads its board and angle at 59.5 ft")
    func curvingBackEnd() throws {
        // 17.5 at the pins, 1.0 board/ft (5.0 degrees), still bending.
        let h = Self.hook(a: 17.5, b: 1.0, c: 0.02)
        let e = try #require(ShotAnalyzer.entryFit(boards: h.boards, feet: h.feet))
        #expect(isClose(e.board, 17.5, 1e-6))
        let expected = atan(1.0 * LaneModel.inchesPerBoard / 12) * 180 / .pi
        #expect(isClose(e.angleDegrees, expected, 1e-6))
    }

    @Test("a track that ends at 55 ft still projects to the pins")
    func shortTrackProjects() throws {
        let h = Self.hook(a: 18.0, b: 0.9, c: 0.0, end: 55)
        let e = try #require(ShotAnalyzer.entryFit(boards: h.boards, feet: h.feet))
        #expect(isClose(e.board, 18.0, 1e-6))
    }

    @Test("pin deflection after impact is cut off, not fitted")
    func deflectionIsCut() throws {
        // Hook into the pocket, then the ball kicks back 4 boards over the
        // last frames (IMG_5113 read entry 11.2 this way).
        var h = Self.hook(a: 17.5, b: 1.0, c: 0.02, end: 55.5)
        let impactBoard = h.boards.last!
        for k in 1...5 {
            h.feet.append(55.5 + 0.8 * Double(k))
            h.boards.append(impactBoard - 0.9 * Double(k))
        }
        let e = try #require(ShotAnalyzer.entryFit(boards: h.boards, feet: h.feet))
        #expect(abs(e.board - 17.5) < 0.05)
        #expect(e.angleDegrees > 4)
    }

    @Test("deflection cut keeps a steady hook whole and ignores half-board noise")
    func cutLeavesNoiseAlone() {
        let steady: [Double] = (0..<20).map { i in
            let jitter: Double = i % 2 == 0 ? 0.25 : -0.25
            return 10.0 + 0.3 * Double(i) + jitter
        }
        #expect(ShotAnalyzer.deflectionCut(steady) == steady.count)
        let deflected: [Double] = [10, 11, 12, 13, 12.2, 11.5, 11.0]
        #expect(ShotAnalyzer.deflectionCut(deflected) == 4)
    }

    @Test("gutter-side hand: boards falling toward the pins fit the same way")
    func fallingBoards() throws {
        let h = Self.hook(a: 5.0, b: -0.6, c: 0.0)
        let e = try #require(ShotAnalyzer.entryFit(boards: h.boards, feet: h.feet))
        #expect(isClose(e.board, 5.0, 1e-6))
        #expect(e.angleDegrees < 0)
    }

    @Test("no entry from a track that never reaches 50 ft")
    func shallowTrackRefused() {
        let h = Self.hook(a: 17.5, b: 1.0, c: 0.0, end: 48)
        #expect(ShotAnalyzer.entryFit(boards: h.boards, feet: h.feet) == nil)
    }

    @Test("polyfit recovers a quadratic, lowest order first")
    func polyfitQuadratic() throws {
        let x = (0..<10).map { Double($0) - 4.5 }
        let y = x.map { 2 - 3 * $0 + 0.5 * $0 * $0 }
        let c = try #require(ShotAnalyzer.polyfit(x: x, y: y, degree: 2))
        #expect(isClose(c[0], 2, 1e-9) && isClose(c[1], -3, 1e-9) && isClose(c[2], 0.5, 1e-9))
    }
}
