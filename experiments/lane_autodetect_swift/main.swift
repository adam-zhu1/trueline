// Parity harness: runs the iOS LaneAutoDetector on still frames so its output
// can be compared with the Python prototype on identical input.
//
// Build & run:
//   swiftc -O -o lanedetect experiments/lane_autodetect_swift/main.swift \
//     ios/Trueline/Trueline/Analysis/LaneAutoDetector.swift \
//     ios/Trueline/Trueline/Models/LaneCorners.swift
//   ./lanedetect frame1.png frame2.png ...

import CoreGraphics
import Foundation
import ImageIO

for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        print("ERROR could not read \(path)")
        continue
    }
    let start = Date()
    let corners = LaneAutoDetector.detectPixelCorners(in: image)
    let ms = Int(Date().timeIntervalSince(start) * 1000)
    let name = url.deletingPathExtension().lastPathComponent

    if ProcessInfo.processInfo.environment["VERBOSE"] != nil {
        let segments = LaneAutoDetector.detectSegments(in: image)
        let h = Double(image.height)
        let w = Double(image.width)
        let cx = w / 2
        var cands: [(score: Double, a: Double, b: Double, len: Double, xBot: Double)] = []
        for (x1, y1, x2, y2) in segments {
            let dy = Double(y2 - y1)
            guard abs(dy) >= 1 else { continue }
            let a = Double(x2 - x1) / dy
            let b = Double(x1) - a * Double(y1)
            let ang = atan2(abs(dy), abs(Double(x2 - x1))) * 180 / .pi
            guard ang >= 35 else { continue }
            let len = (Double(x2 - x1) * Double(x2 - x1) + dy * dy).squareRoot()
            let xBot = a * h + b
            let prox = 1.0 - min(1.0, abs(xBot - cx) / (0.5 * w))
            cands.append((len * (0.5 + prox), a, b, len, xBot))
        }
        cands.sort { $0.score > $1.score }
        print("  segments: \(segments.count), steep candidates: \(cands.count)")
        for c in cands.prefix(8) {
            print(String(format: "  %.0f  a=%.3f b=%.0f len=%.0f xbot=%.0f", c.score, c.a, c.b, c.len, c.xBot))
        }
    }
    if let c = corners {
        func fmt(_ p: CGPoint) -> String { String(format: "(%.1f, %.1f)", p.x, p.y) }
        print("OK   \(name)  foulL=\(fmt(c.foulLeft)) foulR=\(fmt(c.foulRight)) pinL=\(fmt(c.pinLeft)) pinR=\(fmt(c.pinRight))  [\(ms)ms]")
    } else {
        print("MISS \(name)  [\(ms)ms]")
    }
}
