"""Feature-based lane calibration proposal (experiment 1b).

Pipeline on one frame, all at half resolution except the final numbers:

1. Vanishing point. LSD segments below the masking unit, RANSAC for the point
   most long steep segments point at (every lane edge, gutter, capping and
   board seam in the house is parallel, so they share it).
2. Lane strip. Resample the image so lines through the vanishing point become
   columns (u = dx / dy around the VP). In that view every lane is a vertical
   bright strip with dark gutters either side. The subject lane is the widest
   bright strip, which is the lane the phone stands behind. Its edges are the
   strongest signed column gradients near the strip ends.
3. Foul line. A dark painted line running from one lane edge to the other:
   grid search over its two end heights for the line whose median black-hat
   response across the lane is largest.
4. Depth and cross-lane foreshortening. With both edges and the foul line
   fixed, two parameters remain (depth scale e and the cross-lane term g).
   Scored by the arrow V (seven dark marks at boards 5..35, centre at 15 ft,
   0.5 ft nearer per arrow outward) and, separately, by the pin deck (the
   head pin spot at 60 ft and the visible pins as bright blobs).
5. The lane model is fit to all features at once: the edges and foul line
   are kept, (g, e) is chosen by the arrow score, and the pin score is used
   only to break ties and to report whether it agrees.

Returns the four app corners in display pixels plus a feature report.
"""
import cv2
import numpy as np

ARROW_BOARDS = np.array([5, 10, 15, 20, 25, 30, 35], float)
# (board, feet) of the ten pin spots: 12 in apart in a row (11.28 boards),
# rows 10.39 in deep, each row offset half a spacing
PIN_SPOTS = []
for row, boards in enumerate([[20], [14.36, 25.64], [8.72, 20, 31.28], [3.08, 14.36, 25.64, 36.92]]):
    for b in boards:
        PIN_SPOTS.append((b, 60 + row * 10.392 / 12))
PIN_SPOTS = np.array(PIN_SPOTS)


def t_of_board(b):
    return (b - 0.5) / 39.0


def arrow_lane_points(apex=15.0, step=0.5):
    f = apex - np.abs(ARROW_BOARDS - 20) / 5 * step
    return np.c_[t_of_board(ARROW_BOARDS), f]


# ------------------------------------------------------------- primitives

def segments(gray):
    lsd = cv2.createLineSegmentDetector(cv2.LSD_REFINE_STD)
    lines = lsd.detect(gray)[0]
    return np.zeros((0, 4)) if lines is None else lines[:, 0, :].astype(float)


def vanishing_point(segs, h, w, iters=3000, tol_deg=1.0, seed=0):
    """RANSAC over pairs of steep segments; score = total length of segments
    whose direction points at the candidate within tol."""
    x1, y1, x2, y2 = segs.T
    dx, dy = x2 - x1, y2 - y1
    length = np.hypot(dx, dy)
    ang = np.degrees(np.arctan2(np.abs(dy), np.abs(dx)))
    mid_y = (y1 + y2) / 2
    keep = (length > 0.03 * h) & (ang > 12) & (ang < 88) & (mid_y > 0.35 * h)
    s = segs[keep]
    L = length[keep]
    if len(s) < 4:
        return None, keep
    # homogeneous lines
    p1 = np.c_[s[:, :2], np.ones(len(s))]
    p2 = np.c_[s[:, 2:], np.ones(len(s))]
    lines = np.cross(p1, p2)
    mids = (s[:, :2] + s[:, 2:]) / 2
    dirs = (s[:, 2:] - s[:, :2]) / np.linalg.norm(s[:, 2:] - s[:, :2], axis=1, keepdims=True)
    rng = np.random.default_rng(seed)
    prob = L / L.sum()
    best, best_score = None, -1
    cos_tol = np.cos(np.radians(tol_deg))
    for _ in range(iters):
        i, j = rng.choice(len(s), 2, replace=False, p=prob)
        v = np.cross(lines[i], lines[j])
        if abs(v[2]) < 1e-9:
            continue
        v = v[:2] / v[2]
        if not (-2 * w < v[0] < 3 * w and -h < v[1] < 0.6 * h):
            continue
        to = v - mids
        to /= np.linalg.norm(to, axis=1, keepdims=True) + 1e-9
        c = np.abs((to * dirs).sum(1))
        score = L[c > cos_tol].sum()
        if score > best_score:
            best, best_score = v, score
    if best is None:
        return None, keep
    # least-squares refine on inliers: minimise distance of VP to inlier lines
    for _ in range(3):
        to = best - mids
        to /= np.linalg.norm(to, axis=1, keepdims=True) + 1e-9
        inl = np.abs((to * dirs).sum(1)) > cos_tol
        ln = lines[inl] / np.linalg.norm(lines[inl][:, :2], axis=1, keepdims=True)
        wts = L[inl]
        A = ln[:, :2] * wts[:, None]
        b = -ln[:, 2] * wts
        best = np.linalg.lstsq(A, b, rcond=None)[0]
    return best, keep


class VPView:
    """Resampling where every line through the vanishing point is a column:
    column = u (dx/dy around the VP), row = image y."""

    def __init__(self, vp, h, w, n_cols=1400, y0_frac=0.12, u_frac=0.3):
        self.vp = vp
        self.h, self.w = h, w
        y0 = vp[1] + y0_frac * (h - vp[1])
        yu = vp[1] + u_frac * (h - vp[1])
        us = [(0 - vp[0]) / (yu - vp[1]), (w - vp[0]) / (yu - vp[1]),
              (0 - vp[0]) / (h - vp[1]), (w - vp[0]) / (h - vp[1])]
        self.umin, self.umax = min(us), max(us)
        self.us = np.linspace(self.umin, self.umax, n_cols)
        self.ys = np.arange(int(np.ceil(y0)), h)

    def sample(self, img):
        U, Y = np.meshgrid(self.us, self.ys)
        X = self.vp[0] + U * (Y - self.vp[1])
        return cv2.remap(img, X.astype(np.float32), Y.astype(np.float32), cv2.INTER_LINEAR,
                         borderMode=cv2.BORDER_CONSTANT, borderValue=-1 if img.dtype == np.float32 else 0)

    def col_to_u(self, c):
        return self.umin + c * (self.umax - self.umin) / (len(self.us) - 1)


def edge_line(vp, u):
    """Image line x = vp.x + u (y - vp.y) through the VP, as (point, direction)."""
    return vp, np.array([u, 1.0])


def x_on(vp, u, y):
    return vp[0] + u * (y - vp[1])


# ------------------------------------------------------------- lane strip

def find_lane_strip(gray, vp, report):
    h, w = gray.shape
    view = VPView(vp, h, w)
    g = gray.astype(np.float32)
    valid = view.sample(np.ones_like(g, np.float32) * 1.0)
    P = view.sample(g)
    # band of rows where the lanes are seen at mid distance: 12% to 45% of the
    # way from the VP down to the bottom of the frame
    Ys = view.ys - vp[1]
    band = (Ys > 0.10 * (h - vp[1])) & (Ys < 0.45 * (h - vp[1]))
    Pb = np.where(valid[band] > 0.99, P[band], np.nan)
    cover = np.mean(~np.isnan(Pb), axis=0)
    prof = np.nanmedian(np.where(cover[None, :] > 0.3, Pb, np.nan), axis=0)
    prof = np.where(cover > 0.3, prof, np.nan)
    # bright runs = lanes; threshold between the dark gutters and the wood
    v = prof[~np.isnan(prof)]
    if len(v) < 50:
        return None
    thr = 0.5 * (np.percentile(v, 15) + np.percentile(v, 85))
    bright = np.nan_to_num(prof, nan=0) > thr
    runs, start = [], None
    for i, b in enumerate(np.r_[bright, False]):
        if b and start is None:
            start = i
        elif not b and start is not None:
            runs.append((start, i - 1))
            start = None
    if not runs:
        return None
    # In u every lane has the same width (u is lateral ground position over
    # camera height), so width can't pick the lane. The subject lane is the
    # one the phone stands behind: the bright strip covering the most image
    # area below the VP (nearer lanes reach the bottom of the frame).
    du = (view.umax - view.umin) / (len(view.us) - 1)
    wmax = max(r[1] - r[0] for r in runs)
    cand = [r for r in runs if r[1] - r[0] >= 0.5 * wmax]
    area_map = (valid > 0.99) * (view.ys - vp[1])[:, None]
    lo, hi = max(cand, key=lambda r: float(area_map[:, r[0]:r[1] + 1].sum()))
    report["strip_candidates"] = len(cand)
    # signed column gradient summed over the band (lane edge = strongest
    # dark->bright on the left side, bright->dark on the right)
    Pg = np.where(valid > 0.99, P, np.nan)
    gx = np.diff(Pg[band], axis=1)
    colg = np.nanmean(gx, axis=0)
    win = max(4, int(0.15 * (hi - lo)))
    l0, l1 = max(0, lo - win), min(len(colg) - 1, lo + win)
    r0, r1 = max(0, hi - win), min(len(colg) - 1, hi + win)
    li = l0 + int(np.nanargmax(colg[l0:l1 + 1]))
    ri = r0 + int(np.nanargmin(colg[r0:r1 + 1]))
    u_left = view.umin + (li + 0.5) * du
    u_right = view.umin + (ri + 0.5) * du
    report["strip_runs"] = len(runs)
    report["strip_width_cols"] = int(hi - lo)
    return u_left, u_right, view, P, prof


def refine_edge(gray_f, vp, u, sign, y_lo, y_hi, half_px=10):
    """Fit the lane edge as an unconstrained image line: on every row between
    y_lo and y_hi find the strongest signed horizontal gradient within
    half_px of the VP line, then a robust line fit x = a y + b."""
    gx = cv2.Sobel(gray_f, cv2.CV_32F, 1, 0, ksize=3)
    pts = []
    for y in range(int(y_lo), int(y_hi), 2):
        xc = x_on(vp, u, y)
        x0, x1 = int(xc - half_px), int(xc + half_px)
        if x0 < 1 or x1 >= gray_f.shape[1] - 1:
            continue
        seg = sign * gx[y, x0:x1 + 1]
        k = int(np.argmax(seg))
        if seg[k] <= 0:
            continue
        pts.append((x0 + k, y, seg[k]))
    if len(pts) < 10:
        return None
    pts = np.array(pts)
    a, b = np.polyfit(pts[:, 1], pts[:, 0], 1)
    for _ in range(3):
        r = pts[:, 0] - (a * pts[:, 1] + b)
        mad = np.median(np.abs(r)) + 0.5
        k = np.abs(r) < 2.5 * mad
        a, b = np.polyfit(pts[k, 1], pts[k, 0], 1, w=np.sqrt(pts[k, 2]))
    return a, b


# ------------------------------------------------------------- foul line

def find_foul_line(gray_f, left, right, vp, report):
    """left/right: (a, b) with x = a y + b. Search the two end heights."""
    h, w = gray_f.shape
    k = max(5, int(round(0.012 * h)) | 1)
    bh = cv2.morphologyEx(gray_f, cv2.MORPH_BLACKHAT, cv2.getStructuringElement(cv2.MORPH_RECT, (1, k)))
    bh = cv2.GaussianBlur(bh, (3, 3), 0)
    y_lo = vp[1] + 0.25 * (h - vp[1])
    ys = np.arange(int(y_lo), h - 2, 2)
    n = 48
    s = np.linspace(0.06, 0.94, n)
    best = (-1, None)
    # coarse grid on both ends
    xl = left[0] * ys + left[1]
    xr = right[0] * ys + right[1]
    for i, yl in enumerate(ys):
        if not (0 <= xl[i] < w):
            pass
        yr = ys
        X = xl[i] + (xr - xl[i])[:, None] * s[None, :]
        Y = yl + (yr - yl)[:, None] * s[None, :]
        ok = (X >= 0) & (X < w - 1) & (Y >= 0) & (Y < h - 1)
        vals = cv2.remap(bh, X.astype(np.float32), Y.astype(np.float32), cv2.INTER_LINEAR)
        vals = np.where(ok, vals, np.nan)
        frac = ok.mean(1)
        med = np.nanpercentile(vals, 30, axis=1)
        med = np.where(frac > 0.6, med, -1)
        # a foul line is nearly perpendicular to the lane: reject end
        # heights that differ by more than the lane's own width
        width = np.abs(xr - xl[i])
        med = np.where(np.abs(yr - yl) < 0.5 * width, med, -1)
        j = int(np.argmax(med))
        if med[j] > best[0]:
            best = (med[j], (yl, ys[j]))
    if best[1] is None:
        return None
    yl, yr = best[1]
    # fine search +-4 px
    fine = (-1, None)
    for dl in np.arange(-4, 4.5, 0.5):
        for dr in np.arange(-4, 4.5, 0.5):
            a, b = yl + dl, yr + dr
            xa, xb = left[0] * a + left[1], right[0] * b + right[1]
            X = xa + (xb - xa) * s
            Y = a + (b - a) * s
            v = cv2.remap(bh, X.astype(np.float32)[None], Y.astype(np.float32)[None], cv2.INTER_LINEAR)[0]
            m = np.percentile(v, 30)
            if m > fine[0]:
                fine = (m, (a, b))
    report["foul_score"] = float(fine[0])
    report["foul_contrast"] = float(fine[0] / (np.median(bh) + 1e-3))
    return fine[1]


# ------------------------------------------------------------- lane model

def base_homography(left, right, foul):
    """Lane->image homography with t=0 on the right edge, t=1 on the left,
    feet 0 on the foul line, and the lane direction at the VP. The far points
    are placed on the edges at an arbitrary row, so depth scale (e) and the
    cross-lane term (g) are left free: H = H0 @ L(g, e)."""
    yl, yr = foul
    nl = np.array([left[0] * yl + left[1], yl])
    nr = np.array([right[0] * yr + right[1], yr])
    # far points: where the edges reach 40% of the way to their intersection
    a1, b1 = left
    a2, b2 = right
    yv = (b2 - b1) / (a1 - a2)
    yfl = yl + 0.6 * (yv - yl)
    yfr = yr + 0.6 * (yv - yr)
    fl = np.array([a1 * yfl + b1, yfl])
    fr = np.array([a2 * yfr + b2, yfr])
    src = np.float32([(0, 0), (1, 0), (1, 1), (0, 1)])
    dst = np.float32([nr, nl, fl, fr])
    return cv2.getPerspectiveTransform(src, dst).astype(float)


def L_of(g, e):
    """Lane-space map fixing t=0, t=1, feet=0 and the lane direction:
    (t, f) -> ((1+g) t / (g t + 1), e f / (g t + 1))."""
    return np.array([[1 + g, 0, 0], [0, e, 0], [g, 0, 1]], float)


def proj(H, pts):
    p = np.c_[pts, np.ones(len(pts))] @ H.T
    return p[:, :2] / p[:, 2:3]


def _maps(gray_f, scale_px):
    """Black-hat (dark marks: arrows) and top-hat (bright pins) images at
    full resolution; scale_px ~ image height / 1000."""
    ka = max(5, int(round(7 * scale_px)) | 1)
    bh = cv2.morphologyEx(gray_f, cv2.MORPH_BLACKHAT,
                          cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (ka, ka)))
    bh = cv2.GaussianBlur(bh, (3, 3), 0)
    kp = max(9, int(round(25 * scale_px)) | 1)
    th = cv2.morphologyEx(gray_f, cv2.MORPH_TOPHAT,
                          cv2.getStructuringElement(cv2.MORPH_RECT, (kp, 1)))
    th = cv2.GaussianBlur(th, (3, 3), 0)
    return bh, th


def _sample_many(img, pts):
    """pts (..., 2) -> values (...), zero outside the image."""
    h, w = img.shape
    flat = np.nan_to_num(pts.reshape(-1, 2), nan=-10.0, posinf=-10.0, neginf=-10.0)
    ok = (flat[:, 0] >= 0) & (flat[:, 0] < w - 1) & (flat[:, 1] >= 0) & (flat[:, 1] < h - 1)
    x = np.clip(flat[:, 0], 0, w - 1.001)
    y = np.clip(flat[:, 1], 0, h - 1.001)
    x0, y0 = x.astype(int), y.astype(int)
    fx, fy = x - x0, y - y0
    v = (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x0 + 1] * fx * (1 - fy)
         + img[y0 + 1, x0] * (1 - fx) * fy + img[y0 + 1, x0 + 1] * fx * fy)
    return np.where(ok, v, 0.0).reshape(pts.shape[:-1])


def _proj_many(Hs, lane):
    p = np.einsum("...ij,nj->...ni", Hs, np.c_[lane, np.ones(len(lane))])
    return p[..., :2] / p[..., 2:3]


def fit_depth(gray_full, H0_full, report):
    """Grid search of the two free parameters (g, e) against the arrow marks
    and the pin deck, separately and jointly. H0_full maps lane -> full-res px."""
    h, w = gray_full.shape
    bh, th = _maps(gray_full, h / 1000.0)
    gs = np.linspace(-0.6, 1.5, 106)
    es = np.exp(np.linspace(np.log(0.002), np.log(0.08), 300))
    G, E = np.meshgrid(gs, es, indexing="ij")
    Ls = np.zeros(G.shape + (3, 3))
    Ls[..., 0, 0] = 1 + G
    Ls[..., 1, 1] = E
    Ls[..., 2, 0] = G
    Ls[..., 2, 2] = 1
    Hs = np.einsum("ij,abjk->abik", H0_full, Ls)

    # arrows: all seven dark, the gaps between them not (drop the weakest
    # arrow so one worn or occluded mark doesn't sink the score)
    arrows = arrow_lane_points()
    ctrl = np.c_[t_of_board(ARROW_BOARDS[:-1] + 2.5), arrows[:-1, 1]]
    va = _sample_many(bh, _proj_many(Hs, arrows))
    vc = _sample_many(bh, _proj_many(Hs, ctrl))
    A = np.sort(va, axis=-1)[..., 1:].mean(-1) - vc.mean(-1)

    # pins: bright bodies standing on the ten spots; sample 3 to 12 boards'
    # worth of pixels up the image from each spot
    pins = np.c_[t_of_board(PIN_SPOTS[:, 0]), PIN_SPOTS[:, 1]]
    pp = _proj_many(Hs, pins)
    bpx = np.linalg.norm(_proj_many(Hs, pins + np.array([1 / 39.0, 0])) - pp, axis=-1, keepdims=True)
    vals = [_sample_many(th, pp - np.concatenate([np.zeros_like(bpx), k * bpx], -1)) for k in (3, 6, 9, 12)]
    Pn = np.mean(vals, axis=0).mean(-1)

    def z(S):
        med = np.median(S)
        mad = np.median(np.abs(S - med)) + 1e-6
        return (S - med) / mad

    J = z(A) + z(Pn)
    out = {}
    for name, S in (("arrows", A), ("pins", Pn), ("joint", J)):
        i, j = np.unravel_index(np.argmax(S), S.shape)
        out[name] = (float(gs[i]), float(es[j]), float(S[i, j]))
    report["arrow_z"] = float(z(A).max())
    report["pin_z"] = float(z(Pn).max())
    scales = (np.median(np.abs(A - np.median(A))) + 1e-6, np.median(np.abs(Pn - np.median(Pn))) + 1e-6)
    return out, (bh, th, scales)


def _quads_to_H(quads):
    """Batch lane->image homographies from (N, 4, 2) corner quads in the
    app order (nearRight, nearLeft, farLeft, farRight)."""
    src = np.array([(0, 0), (1, 0), (1, 60), (0, 60)], float)
    n = len(quads)
    A = np.zeros((n, 8, 8))
    b = np.zeros((n, 8))
    for k, (x, y) in enumerate(src):
        u, v = quads[:, k, 0], quads[:, k, 1]
        A[:, 2 * k, 0:3] = [x, y, 1]
        A[:, 2 * k, 6] = -x * u
        A[:, 2 * k, 7] = -y * u
        A[:, 2 * k + 1, 3:6] = [x, y, 1]
        A[:, 2 * k + 1, 6] = -x * v
        A[:, 2 * k + 1, 7] = -y * v
        b[:, 2 * k], b[:, 2 * k + 1] = u, v
    h = np.linalg.solve(A, b[..., None])[..., 0]
    return np.concatenate([h, np.ones((n, 1))], 1).reshape(n, 3, 3)


def refine_far(corners, maps, report):
    """Last step, the least-squares-like fit of the whole lane model: keep the
    foul corners, free the two far corners (4 parameters) and maximise the
    arrow + pin evidence. The gutter edges are fit on the near lane, where
    they are long and sharp; at the deck the lane is a few dozen pixels wide
    and a sub-degree error in the edge direction is several boards, so the
    pin columns (bright, at known boards) are the better lateral reference."""
    bh, th, (sa, sp) = maps
    arrows = arrow_lane_points()
    ctrl = np.c_[t_of_board(ARROW_BOARDS[:-1] + 2.5), arrows[:-1, 1]]
    pins = np.c_[t_of_board(PIN_SPOTS[:, 0]), PIN_SPOTS[:, 1]]

    def score(quads):
        Hs = _quads_to_H(quads)
        va = _sample_many(bh, _proj_many(Hs, arrows))
        vc = _sample_many(bh, _proj_many(Hs, ctrl))
        A = np.sort(va, axis=-1)[..., 1:].mean(-1) - vc.mean(-1)
        pp = _proj_many(Hs, pins)
        bpx = np.linalg.norm(_proj_many(Hs, pins + np.array([1 / 39.0, 0])) - pp, axis=-1, keepdims=True)
        vals = [_sample_many(th, pp - np.concatenate([np.zeros_like(bpx), k * bpx], -1)) for k in (3, 6, 9, 12)]
        P = np.mean(vals, axis=0).mean(-1)
        return A / sa + P / sp

    best = np.asarray(corners, float)
    for span, step in ((24, 4), (4, 1)):
        d = np.arange(-span, span + step, step, dtype=float)
        D = np.stack(np.meshgrid(d, d, d, d, indexing="ij"), -1).reshape(-1, 4)
        quads = np.repeat(best[None], len(D), 0)
        quads[:, 2] += D[:, 0:2]
        quads[:, 3] += D[:, 2:4]
        s = np.concatenate([score(quads[i:i + 8192]) for i in range(0, len(quads), 8192)])
        best = quads[int(np.argmax(s))]
    report["far_shift_px"] = (best - np.asarray(corners))[2:].tolist()
    return best


# ------------------------------------------------------------- driver

def detect(frame_bgr, scale=0.5, mode="joint"):
    """Propose the four app corners for one display frame. mode picks what
    fixes depth and cross-lane skew: 'arrows', 'pins', 'joint', or 'all'
    (a dict of all three)."""
    report = {}
    small = cv2.resize(frame_bgr, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
    gray = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape
    vp, _ = vanishing_point(segments(gray), h, w)
    if vp is None:
        return None, {"fail": "vp"}
    report["vp"] = (vp / scale).tolist()
    strip = find_lane_strip(gray, vp, report)
    if strip is None:
        return None, {**report, "fail": "strip"}
    u_left, u_right = strip[:2]
    gf = gray.astype(np.float32)
    y_lo = vp[1] + 0.12 * (h - vp[1])
    left = refine_edge(gf, vp, u_left, +1, y_lo, h - 1) or (u_left, vp[0] - u_left * vp[1])
    right = refine_edge(gf, vp, u_right, -1, y_lo, h - 1) or (u_right, vp[0] - u_right * vp[1])
    report["edge_left"], report["edge_right"] = list(left), list(right)
    foul = find_foul_line(gf, left, right, vp, report)
    if foul is None:
        return None, {**report, "fail": "foul"}
    H0f = np.diag([1 / scale, 1 / scale, 1]) @ base_homography(left, right, foul)
    gray_full = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2GRAY).astype(np.float32)
    res, maps = fit_depth(gray_full, H0f, report)
    lane = np.array([(0, 0), (1, 0), (1, 60), (0, 60)], float)
    g, e, _ = res["joint"]
    refined = refine_far(proj(H0f @ L_of(g, e), lane), maps, report)
    out = {}
    for name, (g, e, _) in list(res.items()) + [("refined", (None, None, None))]:
        Hf = (cv2.getPerspectiveTransform(lane.astype(np.float32), refined.astype(np.float32)).astype(float)
              if name == "refined" else H0f @ L_of(g, e))
        out[name] = (proj(Hf, lane), {
            "g": g, "e": e,
            "arrows_px": proj(Hf, arrow_lane_points()).tolist(),
            "headpin_px": proj(Hf, np.array([[0.5, 60.0]]))[0].tolist(),
            "foul_px": proj(Hf, np.array([[0, 0], [1, 0]], float)).tolist()})
    if mode == "all":
        return out, report
    corners, extra = out[mode]
    report.update(extra)
    return corners, report


