"""Estimate ball rev rate from a brightness signal (see extract_signal.py).

Pipeline: normalize ball brightness by the background annulus (kills the
down-lane lighting gradient), interpolate detection gaps onto a uniform
frame grid, subtract a moving average (window longer than the slowest
plausible rev), Hann window, zero-padded rFFT. Candidate frequencies in
the physical band (90-540 RPM) are scored by harmonic-weighted magnitude
— mag(f) + 0.5 mag(2f) — because a tape flash is a pulse train with
harmonics while a noise peak stands alone; this also resolves the
fundamental-vs-2nd-harmonic ambiguity. The winner is refined by parabolic
interpolation.

Confidence is two-of-three evidence, with a hard SNR floor of 2.8:
- SNR: harmonic score of the peak over the band's median score >= 3.5.
- Split-half consistency: the two halves of the window, estimated
  independently, agree with the full-window peak (within 8%, floored at
  the half-window frequency resolution). A real rev signal repeats in
  both halves; a lucky noise peak does not.
- Autocorrelation cross-check: the first strong in-band autocorrelation
  peak (the fundamental lag — the global max can sit on a multiple)
  agrees within 15%.

Thresholds are set by synth_test.py: recover taped-ball signals across
150-450 RPM at 30/60 fps, never pass a no-tape null (0 of 200 synthetic
nulls pass). An unconfident answer means "no tape signal found" — the
correct output for an untaped ball.

Usage: python3 estimate_rpm.py signals/<clip>_signal.json [--window 1.6] [--band 90 540]
"""
import json
import sys

import numpy as np

BAND_RPM = (90.0, 540.0)
WINDOW_S = 2.2        # early lane; real tracks run ~2.4-2.9 s
SNR_CONFIDENT = 3.5
SNR_FLOOR = 2.8       # below this, no amount of agreement is confident
SPLIT_TOL = 0.08      # halves agree within 8%, floored at the half-window
                      # frequency resolution (matters below ~200 RPM)
PAD = 8               # zero-padding factor for the FFT


MIN_COVERAGE = 0.6    # real detections per grid frame; below this the
                      # interpolated signal is fantasy (batch-2 sparse tracks)


def uniform_series(samples, fps, window_s):
    """Normalized, gap-interpolated signal over the first window_s seconds.

    Returns (grid, values, coverage) where coverage is the fraction of grid
    frames backed by a real detection."""
    t = np.array([s["t"] for s in samples])
    v = np.array([s["ball"] for s in samples]) / np.maximum(
        np.array([s["bg"] for s in samples]), 1e-6)
    keep = t - t[0] <= window_s
    t, v = t[keep], v[keep]
    grid = np.arange(t[0], t[-1] + 0.5 / fps, 1.0 / fps)
    return grid, np.interp(grid, t, v), len(t) / max(len(grid), 1)


def detrend(v, fps, slowest_hz):
    win = max(3, int(round(fps / slowest_hz * 1.2)) | 1)  # odd, > slowest period
    pad = win // 2
    padded = np.pad(v, pad, mode="edge")
    trend = np.convolve(padded, np.ones(win) / win, mode="valid")
    return v - trend


def spectral_peak(v, fps, band_hz):
    w = v * np.hanning(len(v))
    n = PAD * len(w)
    mag = np.abs(np.fft.rfft(w, n=n))
    freqs = np.fft.rfftfreq(n, 1.0 / fps)
    in_band = (freqs >= band_hz[0]) & (freqs <= band_hz[1])
    if in_band.sum() < 3:
        return None
    idx = np.flatnonzero(in_band)
    # harmonic-weighted score: a pulse train has energy at 2f, noise doesn't
    idx2 = np.minimum(idx * 2, len(mag) - 1)
    score = mag[idx] + 0.5 * mag[idx2]
    best = int(np.argmax(score))
    k = idx[best]
    # parabolic interpolation on log magnitude around the winning bin
    if 0 < k < len(mag) - 1 and mag[k - 1] > 0 and mag[k + 1] > 0:
        denom = np.log(mag[k - 1]) - 2 * np.log(mag[k]) + np.log(mag[k + 1])
        if denom < 0:
            shift = 0.5 * (np.log(mag[k - 1]) - np.log(mag[k + 1])) / denom
            k = k + float(np.clip(shift, -0.5, 0.5))  # flat curvature explodes
    f = k * fps / n
    # SNR on the harmonic score, excluding the peak's own neighborhood and
    # its half/double (signal leakage would inflate the noise floor)
    fq = freqs[idx]
    near = np.zeros(len(idx), bool)
    for c in (f, f / 2, 2 * f):
        near |= np.abs(fq - c) < 0.35
    floor = score[~near]
    snr = score[best] / max(np.median(floor), 1e-12) if floor.size >= 5 \
        else score[best] / max(np.median(score), 1e-12)
    return f, snr


def autocorr_peak(v, fps, band_hz):
    v = v - v.mean()
    ac = np.correlate(v, v, mode="full")[len(v) - 1:]
    if ac[0] <= 0:
        return None
    ac = ac / ac[0]
    lag_min = max(2, int(np.floor(fps / band_hz[1])))
    lag_max = min(len(ac) - 2, int(np.ceil(fps / band_hz[0])))
    if lag_max <= lag_min:
        return None
    seg = ac[lag_min: lag_max + 1]
    top = seg.max()
    if top < 0.15:  # no real periodicity
        return None
    # first strong local peak = the fundamental period; the global max can
    # land on a multiple of the true lag (pulse trains repeat at 2T, 3T...)
    k = None
    for j in range(lag_min, lag_max + 1):
        if ac[j] >= 0.7 * top and ac[j] >= ac[j - 1] and ac[j] >= ac[j + 1]:
            k = j
            break
    if k is None:
        k = lag_min + int(np.argmax(seg))
    a, b, c = ac[k - 1], ac[k], ac[k + 1]
    denom = a - 2 * b + c
    lag = k + (0.5 * (a - c) / denom if denom < 0 else 0.0)
    return fps / lag


def estimate(samples, fps, window_s=WINDOW_S, band_rpm=BAND_RPM):
    """Returns dict with rpm, snr, confident, and the cross-check detail."""
    band_hz = (band_rpm[0] / 60.0, band_rpm[1] / 60.0)
    grid, v, coverage = uniform_series(samples, fps, window_s)
    if len(v) < int(fps / band_hz[0]) + 4:
        return {"rpm": None, "snr": 0.0, "confident": False,
                "note": f"window too short ({len(v)} samples)"}
    if coverage < MIN_COVERAGE:
        return {"rpm": None, "snr": 0.0, "confident": False,
                "note": f"detection coverage {coverage:.0%} < {MIN_COVERAGE:.0%}"}
    d = detrend(v, fps, band_hz[0])
    sp = spectral_peak(d, fps, band_hz)
    if sp is None:
        return {"rpm": None, "snr": 0.0, "confident": False, "note": "band empty"}
    f, snr = sp

    # split-half consistency: a real rev signal repeats in both halves
    half = len(d) // 2
    sp1 = spectral_peak(d[:half], fps, band_hz)
    sp2 = spectral_peak(d[half:], fps, band_hz)
    tol_hz = max(SPLIT_TOL * f, 0.5 * fps / half)  # >= half-window resolution
    split_ok = (sp1 is not None and sp2 is not None
                and abs(sp1[0] - f) < tol_hz and abs(sp2[0] - f) < tol_hz)

    f_ac = autocorr_peak(d, fps, band_hz)
    ac_ok = f_ac is not None and abs(f_ac - f) / f < 0.15
    # split-half is mandatory: FFT and autocorrelation see the same data, so
    # they agree on noise too — repeating in both halves is the only
    # independent evidence. On top of it, either a strong peak or the
    # autocorrelation cross-check.
    confident = snr >= SNR_FLOOR and split_ok and (ac_ok or snr >= SNR_CONFIDENT)
    return {"rpm": f * 60.0, "snr": snr,
            "rpm_autocorr": None if f_ac is None else f_ac * 60.0,
            "split_halves": None if sp1 is None or sp2 is None
                            else [sp1[0] * 60.0, sp2[0] * 60.0],
            "confident": confident,
            "n_samples": len(v), "window_s": float(grid[-1] - grid[0])}


def main():
    args = sys.argv[1:]
    window_s, band = WINDOW_S, BAND_RPM
    if "--window" in args:
        i = args.index("--window"); window_s = float(args[i + 1]); del args[i:i + 2]
    if "--band" in args:
        i = args.index("--band"); band = (float(args[i + 1]), float(args[i + 2])); del args[i:i + 3]
    sig = json.load(open(args[0]))
    r = estimate(sig["samples"], sig["fps"], window_s, band)
    if r["rpm"] is None:
        print(f"{sig['clip']}: no estimate ({r['note']})")
        return
    ac = "n/a" if r["rpm_autocorr"] is None else f"{r['rpm_autocorr']:.0f}"
    verdict = "CONFIDENT" if r["confident"] else "no tape signal (unconfident)"
    print(f"{sig['clip']}: {r['rpm']:.0f} RPM  snr {r['snr']:.1f}  autocorr {ac} RPM  "
          f"[{r['n_samples']} samples / {r['window_s']:.2f} s]  -> {verdict}")


if __name__ == "__main__":
    main()
