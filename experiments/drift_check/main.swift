// Drift check prototype: register a throw's frame against the calibration
// reference frame with Apple Vision, restricted to the upper part of the
// portrait image (far lane, pin deck, masking unit, ceiling) so the bowler
// on the approach never enters the estimate.
//
// usage:
//   drift reg  <ref.png> <tgt.png> <topFrac> [cal.json]   register real pair
//   drift synth <ref.png> <topFrac> dx dy rotDeg scale       warp ref, register
//
// Output transform H maps REFERENCE pixel coords to TARGET pixel coords
// (top-left origin, full-image pixels), so a calibration tapped on the
// reference frame is carried to the throw by applying H to its points.

import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Vision
import simd

func loadCG(_ path: String) -> CGImage {
    let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(src, 0, nil)!
}

/// Top band of the image, rows [0, frac*H) in top-left coords.
func topBand(_ img: CGImage, _ frac: Double) -> CGImage {
    let h = Int(Double(img.height) * frac)
    return img.cropping(to: CGRect(x: 0, y: 0, width: img.width, height: h))!
}

/// Downscale for speed; registration does not need full res.
let ctx = CIContext()
func scaled(_ img: CGImage, _ s: Double) -> CGImage {
    let ci = CIImage(cgImage: img).transformed(by: CGAffineTransform(scaleX: s, y: s))
    return ctx.createCGImage(ci, from: ci.extent.integral)!
}

typealias M3 = simd_double3x3
func m3(_ f: simd_float3x3) -> M3 {
    M3(columns: (SIMD3<Double>(f.columns.0), SIMD3<Double>(f.columns.1), SIMD3<Double>(f.columns.2)))
}
func apply(_ m: M3, _ p: SIMD2<Double>) -> SIMD2<Double> {
    let v = m * SIMD3(p.x, p.y, 1)
    return SIMD2(v.x / v.z, v.y / v.z)
}

struct Reg { var H: M3; var ms: Double }

/// Vision homographic registration of `tgt` onto `ref` (both same-size band
/// crops at scale s). Returns H in full-res top-left pixel coords mapping
/// ref -> tgt. Vision's matrix is in the scaled band's bottom-left pixel
/// coords; the direction is resolved by the synthetic test (see README).
func register(ref: CGImage, tgt: CGImage, frac: Double, s: Double, homographic: Bool, invert: Bool) -> Reg? {
    let r = scaled(topBand(ref, frac), s)
    let t = scaled(topBand(tgt, frac), s)
    let h = Double(r.height)
    let t0 = Date()
    let handler = VNImageRequestHandler(cgImage: r, options: [:])
    var V: M3
    if homographic {
        let req = VNHomographicImageRegistrationRequest(targetedCGImage: t, options: [:])
        do { try handler.perform([req]) } catch { print("err \(error)"); return nil }
        guard let obs = req.results?.first as? VNImageHomographicAlignmentObservation else { return nil }
        V = m3(obs.warpTransform)
    } else {
        let req = VNTranslationalImageRegistrationRequest(targetedCGImage: t, options: [:])
        do { try handler.perform([req]) } catch { print("err \(error)"); return nil }
        guard let obs = req.results?.first as? VNImageTranslationAlignmentObservation else { return nil }
        let a = obs.alignmentTransform
        V = M3(rows: [SIMD3(Double(a.a), Double(a.c), Double(a.tx)),
                      SIMD3(Double(a.b), Double(a.d), Double(a.ty)),
                      SIMD3(0, 0, 1)])
    }
    let ms = Date().timeIntervalSince(t0) * 1000
    // bottom-left (scaled) -> top-left full res: flip y, then unscale.
    let F = M3(rows: [SIMD3(1, 0, 0), SIMD3(0, -1, h), SIMD3(0, 0, 1)])
    let S = M3(diagonal: SIMD3(1 / s, 1 / s, 1))
    let Si = M3(diagonal: SIMD3(s, s, 1))
    var Htl = S * F * V * F * Si
    if invert { Htl = Htl.inverse }
    Htl = Htl * (1 / Htl[2][2])
    return Reg(H: Htl, ms: ms)
}

/// Tile mode: translational registration on a grid of tiles inside the band,
/// then a robust least-squares similarity fit (rotation, scale, shift) to the
/// tile displacements. Textureless or occluded tiles fall out as outliers.
func translate(_ r: CGImage, _ t: CGImage) -> SIMD2<Double>? {
    let handler = VNImageRequestHandler(cgImage: r, options: [:])
    let req = VNTranslationalImageRegistrationRequest(targetedCGImage: t, options: [:])
    guard (try? handler.perform([req])) != nil,
          let obs = req.results?.first as? VNImageTranslationAlignmentObservation else { return nil }
    // bottom-left -> top-left: flip ty; invert direction (ref -> tgt).
    return SIMD2(-Double(obs.alignmentTransform.tx), Double(obs.alignmentTransform.ty))
}

var lastTiles: [(SIMD2<Double>, SIMD2<Double>, Bool)] = []
func registerTiles(ref: CGImage, tgt: CGImage, frac: Double, s: Double, nx: Int, ny: Int) -> Reg? {
    let r = scaled(topBand(ref, frac), s), t = scaled(topBand(tgt, frac), s)
    let t0 = Date()
    let W = Double(r.width), H = Double(r.height)
    let tw = W / Double(nx), th = H / Double(ny)
    var pts: [(SIMD2<Double>, SIMD2<Double>)] = []
    for j in 0..<ny { for i in 0..<nx {
        // Overlapping tiles: 1.5x the grid cell, clamped to the band.
        let w = min(tw * 1.5, W), h = min(th * 1.5, H)
        let cx = (Double(i) + 0.5) * tw, cy = (Double(j) + 0.5) * th
        let rect = CGRect(x: min(max(cx - w / 2, 0), W - w), y: min(max(cy - h / 2, 0), H - h), width: w, height: h).integral
        guard let rc = r.cropping(to: rect), let tc = t.cropping(to: rect), let d = translate(rc, tc) else { continue }
        pts.append((SIMD2(Double(rect.midX), Double(rect.midY)) / s, d / s))
    } }
    let ms = Date().timeIntervalSince(t0) * 1000
    guard pts.count >= 3 else { return nil }
    // Similarity: d = [a -b; b a] p + [tx ty] - p, solve for (a-1, b, tx, ty).
    func fit(_ use: [Bool]) -> SIMD4<Double> {
        var AtA = simd_double4x4(0), Atb = SIMD4<Double>(0, 0, 0, 0)
        for (k, (p, d)) in pts.enumerated() where use[k] {
            let r1 = SIMD4(p.x, -p.y, 1, 0), r2 = SIMD4(p.y, p.x, 0, 1)
            for (row, y) in [(r1, d.x), (r2, d.y)] {
                AtA += simd_double4x4(columns: (row * row.x, row * row.y, row * row.z, row * row.w))
                Atb += row * y
            }
        }
        return AtA.inverse * Atb
    }
    var use = [Bool](repeating: true, count: pts.count)
    var x = fit(use)
    for _ in 0..<3 {
        let res = pts.map { (p, d) -> Double in
            let pred = SIMD2(x.x * p.x - x.y * p.y + x.z, x.y * p.x + x.x * p.y + x.w)
            return simd_length(pred - d)
        }
        let sorted = res.sorted(); let med = sorted[sorted.count / 2]
        let thr = max(3 * med, 2.0)
        let nu = res.map { $0 <= thr }
        if nu.filter({ $0 }).count < 3 { break }
        use = nu; x = fit(use)
    }
    lastTiles = pts.enumerated().map { ($0.element.0, $0.element.1, use[$0.offset]) }
    let Hm = M3(rows: [SIMD3(1 + x.x, -x.y, x.z), SIMD3(x.y, 1 + x.x, x.w), SIMD3(0, 0, 1)])
    return Reg(H: Hm, ms: ms)
}

/// Grayscale bitmap at scale s (top-left origin rows).
func gray(_ img: CGImage, _ s: Double) -> (buf: [UInt8], w: Int, h: Int) {
    let w = Int(Double(img.width) * s), h = Int(Double(img.height) * s)
    var buf = [UInt8](repeating: 0, count: w * h)
    let c = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    c.interpolationQuality = .medium
    c.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    return (buf, w, h)
}

/// Verification: normalized cross-correlation between the reference band and
/// the target sampled through H (ref -> tgt). A wrong H (big re-prop the
/// registration could not follow) leaves the images misaligned and the score
/// drops; this is what separates "auto-correct" from "recalibrate".
func alignScore(ref: CGImage, tgt: CGImage, H: M3, frac: Double) -> Double {
    let s = 0.25
    let r = gray(ref, s), t = gray(tgt, s)
    var xs: [Double] = [], ys: [Double] = []
    let rows = Int(Double(r.h) * frac)
    for y in stride(from: 0, to: rows, by: 2) { for x in stride(from: 0, to: r.w, by: 2) {
        let q = apply(H, SIMD2(Double(x) / s, Double(y) / s)) * s
        let qx = Int(q.x.rounded()), qy = Int(q.y.rounded())
        guard qx >= 0, qy >= 0, qx < t.w, qy < t.h else { continue }
        xs.append(Double(r.buf[y * r.w + x])); ys.append(Double(t.buf[qy * t.w + qx]))
    } }
    guard xs.count > 100 else { return 0 }
    let n = Double(xs.count)
    let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
    var sxy = 0.0, sxx = 0.0, syy = 0.0
    for i in 0..<xs.count { let a = xs[i] - mx, b = ys[i] - my; sxy += a * b; sxx += a * a; syy += b * b }
    return sxy / (sxx * syy).squareRoot()
}

func loadCal(_ path: String) -> [String: SIMD2<Double>] {
    let d = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as! [String: Any]
    let pts = d["points"] as! [String: [Double]]
    return pts.mapValues { SIMD2($0[0], $0[1]) }
}

func writeCal(_ cal: [String: SIMD2<Double>], hand: String, to path: String) {
    let pts = cal.mapValues { [$0.x, $0.y] }
    let d: [String: Any] = ["points": pts, "bowler_hand": hand]
    try! JSONSerialization.data(withJSONObject: d).write(to: URL(fileURLWithPath: path))
}

/// Synthetic target: ref rotated about the image center, scaled, shifted
/// (top-left pixel coords). Returns the image and the true ref->tgt map.
func synth(_ img: CGImage, dx: Double, dy: Double, rotDeg: Double, scale: Double) -> (CGImage, M3) {
    let W = Double(img.width), H = Double(img.height)
    let c = cos(rotDeg * .pi / 180), sn = sin(rotDeg * .pi / 180)
    // top-left coords map: p' = C + scale*R*(p - C) + d
    let C = SIMD2(W / 2, H / 2)
    let A = M3(rows: [SIMD3(scale * c, -scale * sn, 0), SIMD3(scale * sn, scale * c, 0), SIMD3(0, 0, 1)])
    let T1 = M3(rows: [SIMD3(1, 0, -C.x), SIMD3(0, 1, -C.y), SIMD3(0, 0, 1)])
    let T2 = M3(rows: [SIMD3(1, 0, C.x + dx), SIMD3(0, 1, C.y + dy), SIMD3(0, 0, 1)])
    let Mtl = T2 * A * T1
    // CoreImage is bottom-left: conjugate by the flip.
    let F = M3(rows: [SIMD3(1, 0, 0), SIMD3(0, -1, H), SIMD3(0, 0, 1)])
    let Mbl = F * Mtl * F
    let at = CGAffineTransform(a: Mbl[0][0], b: Mbl[0][1], c: Mbl[1][0], d: Mbl[1][1], tx: Mbl[2][0], ty: Mbl[2][1])
    let ci = CIImage(cgImage: img).transformed(by: at)
        .composited(over: CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: W, height: H)))
        .cropped(to: CGRect(x: 0, y: 0, width: W, height: H))
    return (ctx.createCGImage(ci, from: CGRect(x: 0, y: 0, width: W, height: H))!, Mtl)
}

let a = CommandLine.arguments
let env = ProcessInfo.processInfo.environment
let s = Double(env["DRIFT_SCALE"] ?? "0.5")!
let mode = env["DRIFT_MODE"] ?? "tiles"
let homog = mode == "homog"
let nx = Int(env["DRIFT_NX"] ?? "4")!, ny = Int(env["DRIFT_NY"] ?? "3")!
func reg(_ ref: CGImage, _ tgt: CGImage, _ frac: Double) -> Reg? {
    mode == "tiles" ? registerTiles(ref: ref, tgt: tgt, frac: frac, s: s, nx: nx, ny: ny)
        : register(ref: ref, tgt: tgt, frac: frac, s: s, homographic: homog, invert: true)
}

func corners(_ cal: [String: SIMD2<Double>]) -> [(String, SIMD2<Double>)] {
    cal.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
}

if a[1] == "synth" {
    let ref = loadCG(a[2]); let frac = Double(a[3])!
    let (tgt, truth) = synth(ref, dx: Double(a[4])!, dy: Double(a[5])!, rotDeg: Double(a[6])!, scale: Double(a[7])!)
    guard let r = reg(ref, tgt, frac) else { print("FAIL"); exit(1) }
    // Error at probe points spread over the lane (deck to foul line band).
    var worst = 0.0, deckErr = 0.0
    for p in [SIMD2(540.0, 840), SIMD2(900, 840), SIMD2(200, 1450), SIMD2(800, 1500), SIMD2(540, 1100)] {
        let e = simd_length(apply(r.H, p) - apply(truth, p))
        worst = max(worst, e); if p.y == 840 { deckErr = max(deckErr, e) }
    }
    let deck = apply(truth, SIMD2(900, 840)) - SIMD2(900, 840)
    print(String(format: "synth dx=%@ dy=%@ rot=%@ sc=%@  true deck shift %.1f px  err deck %.2f / anywhere %.2f px  (%.0f ms)",
                 a[4], a[5], a[6], a[7], simd_length(deck), deckErr, worst, r.ms))
} else if a[1] == "reg" {
    let ref = loadCG(a[2]), tgt = loadCG(a[3]); let frac = Double(a[4])!
    guard let r = reg(ref, tgt, frac) else { print("FAIL"); exit(1) }
    // Motion summary: displacement of the deck center and the foul-line center.
    let deck = apply(r.H, SIMD2(540, 840)) - SIMD2(540, 840)
    let foul = apply(r.H, SIMD2(540, 1480)) - SIMD2(540, 1480)
    let score = alignScore(ref: ref, tgt: tgt, H: r.H, frac: frac)
    let raw = alignScore(ref: ref, tgt: tgt, H: M3(diagonal: SIMD3(1, 1, 1)), frac: frac)
    var line = String(format: "deck %.1f px  foul %.1f px  ncc %.3f (raw %.3f)  (%.0f ms)", simd_length(deck), simd_length(foul), score, raw, r.ms)
    if a.count > 6 {
        // a[5] = ref cal, a[6] = tgt cal (truth); optional a[7] = out cal path
        let rc = loadCal(a[5]), tc = loadCal(a[6])
        var errs: [String] = []
        var moved = 0.0
        var out: [String: SIMD2<Double>] = [:]
        for (k, p) in corners(rc) {
            let q = apply(r.H, p); out[k] = q
            errs.append(String(format: "%@ %.1f", String(k.prefix(9)), simd_length(q - tc[k]!)))
            moved = max(moved, simd_length(tc[k]! - p))
        }
        line += String(format: "  | true max corner move %.1f px | corrected err: ", moved) + errs.joined(separator: ", ")
        if a.count > 7 { writeCal(out, hand: "R", to: a[7]) }
    }
    print(line)
}

// synthcal <frame.png> <frac> dx dy rot sc <cal.json> <stale.json> <corrected.json>
// The throw's true calibration is cal. Pretend the calibration frame was taken
// before a bump: ref = frame warped by M, so the stale calibration is M(cal).
// Register ref -> frame, carry the stale calibration through the estimate.
if a[1] == "synthcal" {
    let frame = loadCG(a[2]); let frac = Double(a[3])!
    let (ref, M) = synth(frame, dx: Double(a[4])!, dy: Double(a[5])!, rotDeg: Double(a[6])!, scale: Double(a[7])!)
    let cal = loadCal(a[8])
    let stale = cal.mapValues { apply(M, $0) }
    guard let r = reg(ref, frame, frac) else { print("FAIL"); exit(1) }
    let corr = stale.mapValues { apply(r.H, $0) }
    writeCal(stale, hand: "R", to: a[9]); writeCal(corr, hand: "R", to: a[10])
    let score = alignScore(ref: ref, tgt: frame, H: r.H, frac: frac)
    let staleErr = cal.keys.map { simd_length(stale[$0]! - cal[$0]!) }.max()!
    let corrErr = cal.keys.map { simd_length(corr[$0]! - cal[$0]!) }.max()!
    print(String(format: "stale corner err %.1f px -> corrected %.2f px  ncc %.3f", staleErr, corrErr, score))
}
