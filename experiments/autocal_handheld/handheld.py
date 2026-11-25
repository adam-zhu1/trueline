"""Simulated handheld motion and per-frame registration (experiment 2).

Motion model (per frame t, frame 0 = identity, because the user calibrates on
the first frame):
  rotation  = slow drift (three sinusoids, 0.05-0.4 Hz, random phase, peak
              about `drift_deg` per axis) + tremor (two sinusoids at 4-10 Hz,
              `tremor_deg` each) about yaw, pitch and roll;
  translation = slow image-space sway of up to `shift_px` (full-res px),
              the plane-induced part of a small camera translation;
  W_t = T_t K R_t K^-1, mapping frame-0 display px to frame-t display px.
Motion blur: the rendered frame is the mean of `blur_samples` warps spread
over the exposure (camera-motion blur only; the ball's own blur is already in
the footage).

Registration estimates G_t (frame-0 px -> frame-t px). Calibration at frame t
is G_t applied to the frame-0 corners.
"""
import cv2
import numpy as np

LEVELS = {
    "mild": {"drift_deg": 0.5, "tremor_deg": 0.05, "shift_px": 3},
    "moderate": {"drift_deg": 1.5, "tremor_deg": 0.15, "shift_px": 6},
    "strong": {"drift_deg": 3.0, "tremor_deg": 0.3, "shift_px": 12},
    # tremor only: the lane barely moves, so the detector test isn't mixed
    # up with the fixed calibration's lane box and lane gate
    "tremor_moderate": {"drift_deg": 0.0, "tremor_deg": 0.15, "shift_px": 0},
    "tremor_strong": {"drift_deg": 0.0, "tremor_deg": 0.3, "shift_px": 0},
    "still": {"drift_deg": 0.0, "tremor_deg": 0.0, "shift_px": 0},
}


def intrinsics(w, h):
    f = 0.72 * max(w, h)          # iPhone 1x camera, 16:9 video, ~69 deg on the long side
    return np.array([[f, 0, w / 2], [0, f, h / 2], [0, 0, 1.0]])


def rot(yaw, pitch, roll):
    y, p, r = np.radians([yaw, pitch, roll])
    Ry = np.array([[np.cos(y), 0, np.sin(y)], [0, 1, 0], [-np.sin(y), 0, np.cos(y)]])
    Rx = np.array([[1, 0, 0], [0, np.cos(p), -np.sin(p)], [0, np.sin(p), np.cos(p)]])
    Rz = np.array([[np.cos(r), -np.sin(r), 0], [np.sin(r), np.cos(r), 0], [0, 0, 1]])
    return Rz @ Rx @ Ry


class Motion:
    def __init__(self, level, fps, w, h, seed=0):
        p = LEVELS[level]
        rng = np.random.default_rng(seed)
        self.K = intrinsics(w, h)
        self.Ki = np.linalg.inv(self.K)
        self.fps = fps
        # 3 rotation axes + 2 translation axes
        self.drift = []
        for axis in range(5):
            fr = rng.uniform(0.05, 0.4, 3)
            ph = rng.uniform(0, 2 * np.pi, 3)
            amp = rng.uniform(0.5, 1.0, 3)
            amp = amp / amp.sum() * (p["drift_deg"] if axis < 3 else p["shift_px"])
            self.drift.append((fr, ph, amp))
        self.tremor = []
        for axis in range(3):
            fr = rng.uniform(4, 10, 2)
            ph = rng.uniform(0, 2 * np.pi, 2)
            self.tremor.append((fr, ph, np.full(2, p["tremor_deg"] / 2)))

    def _signal(self, comps, t):
        fr, ph, amp = comps
        return float(np.sum(amp * (np.sin(2 * np.pi * fr * t + ph) - np.sin(ph))))

    def params(self, t):
        ang = [self._signal(self.drift[a], t) + self._signal(self.tremor[a], t) for a in range(3)]
        sh = [self._signal(self.drift[3 + a], t) for a in range(2)]
        return ang, sh

    def W(self, t, scale=1.0):
        """frame-0 px -> frame-t px at `scale` x full resolution."""
        (yaw, pitch, roll), (tx, ty) = self.params(t)
        H = self.K @ rot(yaw, pitch, roll) @ self.Ki
        H = np.array([[1, 0, tx], [0, 1, ty], [0, 0, 1.0]]) @ H
        S = np.diag([scale, scale, 1.0])
        return S @ H @ np.linalg.inv(S)


def render(frame, motion, t, exposure, scale=1.0, samples=5):
    """frame (at `scale`) as the moving camera would record it at time t."""
    h, w = frame.shape[:2]
    if samples <= 1 or exposure <= 0:
        return cv2.warpPerspective(frame, motion.W(t, scale), (w, h))
    acc = np.zeros(frame.shape, np.float32)
    for s in np.linspace(-0.5, 0.5, samples):
        acc += cv2.warpPerspective(frame, motion.W(t + s * exposure, scale), (w, h)).astype(np.float32)
    return (acc / samples).astype(frame.dtype)


# ------------------------------------------------------------- masks

def lane_mask(shape, lane_to_img, scale, near_ft=-3.0):
    """The lane and its surroundings: one lane width either side, from just
    behind the foul line (or from near_ft) to the pins, plus the band above
    the deck (masking unit, pins, neighbouring decks). lane_to_img in
    full-res px."""
    h, w = shape
    L = []
    for t in (-1.0, 2.0):
        for f in (near_ft, 62.0):
            L.append((t, f))
    p = np.c_[np.array(L), np.ones(4)] @ lane_to_img.T
    p = p[:, :2] / p[:, 2:3] * scale
    far = p[[1, 3]]
    up = far - np.array([0, 0.15 * h])
    poly = np.vstack([p, up]).astype(np.float32)
    hull = cv2.convexHull(poly).astype(np.int32)
    m = np.zeros(shape, np.uint8)
    cv2.fillConvexPoly(m, hull, 255)
    return m


def valid_mask(gray, erode=6):
    """Pixels that came from inside the source frame (warping leaves black)."""
    m = (gray > 2).astype(np.uint8) * 255
    return cv2.erode(m, np.ones((erode * 2 + 1, erode * 2 + 1), np.uint8))


def motion_mask(cur_aligned, ref, thr=20, grow=10):
    """Pixels that changed between the reference and the current frame after
    alignment: bowler, ball, falling pins, people on other lanes. Compared on
    heavily blurred copies so residual misalignment and blur at sharp edges
    don't count as motion; only blob-sized changes do."""
    a = cv2.GaussianBlur(cur_aligned, (0, 0), 4)
    b = cv2.GaussianBlur(ref, (0, 0), 4)
    valid = (cur_aligned > 2) & (ref > 2)
    m = ((cv2.absdiff(a, b) > thr) & valid).astype(np.uint8)
    m = cv2.dilate(m, np.ones((grow * 2 + 1, grow * 2 + 1), np.uint8))
    return (1 - m) * 255


def _and_motion(static, motion):
    """Apply the motion mask unless it would leave almost nothing."""
    both = cv2.bitwise_and(static, motion)
    return both if np.count_nonzero(both) > 0.3 * np.count_nonzero(static) else static


# ------------------------------------------------------------- registration

def _ransac(p0, p1, thr=1.5):
    if len(p0) < 8:
        return None, 0
    H, inl = cv2.findHomography(p0, p1, cv2.RANSAC, thr, maxIters=2000, confidence=0.995)
    if H is None:
        return None, 0
    return H, int(inl.sum())


def _plausible(R, shape, max_frac=0.08):
    """A per-frame correction moves the frame corners by a few percent at
    most; anything bigger is a bad RANSAC or a diverged ECC."""
    h, w = shape
    c = np.array([[0, 0], [w, 0], [w, h], [0, h]], float)
    p = np.c_[c, np.ones(4)] @ R.T
    p = p[:, :2] / p[:, 2:3]
    return np.all(np.isfinite(p)) and np.abs(p - c).max() < max_frac * max(h, w)


class Registrar:
    """method: 'klt_chain' | 'klt_key' | 'orb_key' | 'ecc_key'
    mask:   'none' | 'lane' | 'lane_motion'
    All work on grayscale frames at the given scale; G maps frame-0 -> frame-t
    in that scale's pixels."""

    def __init__(self, method, mask, key_gray, lane_to_img, scale):
        self.method, self.mask_kind, self.scale = method, mask, scale
        self.key = key_gray
        self.shape = key_gray.shape
        self.G = np.eye(3)
        self.A_last = np.eye(3)
        self.prev = key_gray
        self.lane_to_img = lane_to_img
        self.lost = 0
        self.inliers = []
        km = self._static_mask(key_gray, np.eye(3))
        if method == "klt_key":
            self.key_pts = cv2.goodFeaturesToTrack(key_gray, 600, 0.01, 7, mask=km, blockSize=7)
        if method == "orb_key":
            self.orb = cv2.ORB_create(2000, fastThreshold=10)
            self.key_kp, self.key_des = self.orb.detectAndCompute(key_gray, km)
            self.bf = cv2.BFMatcher(cv2.NORM_HAMMING)

    def _static_mask(self, gray, G):
        """Mask in the coordinates of `gray`, whose frame relates to frame 0 by G."""
        m = valid_mask(gray)
        S = np.diag([self.scale, self.scale, 1.0])
        L = np.linalg.inv(S) @ G @ S @ self.lane_to_img
        if self.mask_kind in ("lane", "lane_motion"):
            m = cv2.bitwise_and(m, lane_mask(self.shape, L, self.scale))
        elif self.mask_kind in ("far", "far_motion"):
            # the far two thirds of the lane and what is around and above
            # it: where the entry board is read, and never the bowler
            m = cv2.bitwise_and(m, lane_mask(self.shape, L, self.scale, near_ft=20.0))
        elif self.mask_kind == "top":
            # DriftCheck's band: the top half of the portrait frame
            m[int(0.5 * self.shape[0]):] = 0
        return m

    def step(self, gray):
        G_prev = self.G
        h, w = self.shape
        if self.method == "klt_chain":
            # features on the previous frame, tracked into this one
            m = self._static_mask(self.prev, G_prev)
            if self.mask_kind in ("lane_motion", "far_motion"):
                # align with the last frame-to-frame step before differencing
                cur = cv2.warpPerspective(gray, np.linalg.inv(self.A_last), (w, h))
                m = _and_motion(m, motion_mask(cur, self.prev))
            p0 = cv2.goodFeaturesToTrack(self.prev, 500, 0.01, 7, mask=m, blockSize=7)
            A = None
            if p0 is not None:
                p1, st, _ = cv2.calcOpticalFlowPyrLK(self.prev, gray, p0, None, winSize=(21, 21), maxLevel=3)
                ok = st[:, 0] == 1
                A, n = _ransac(p0[ok], p1[ok])
                self.inliers.append(n)
            if A is None or not _plausible(A, self.shape):
                self.lost += 1
                A = np.eye(3)
            self.A_last = A
            self.G = A @ G_prev
        else:
            # register to the keyframe, starting from the previous estimate:
            # bring this frame back to frame-0 coordinates, then solve the
            # small residual
            back = cv2.warpPerspective(gray, np.linalg.inv(G_prev), (w, h))
            m = self._static_mask(self.key, np.eye(3))
            m = cv2.bitwise_and(m, valid_mask(back))
            if self.mask_kind in ("lane_motion", "far_motion"):
                m = _and_motion(m, motion_mask(back, self.key))
            R = None
            if self.method == "klt_key":
                pts = self.key_pts
                if pts is not None:
                    keep = m[np.clip(pts[:, 0, 1].astype(int), 0, h - 1), np.clip(pts[:, 0, 0].astype(int), 0, w - 1)] > 0
                    pts = pts[keep]
                if pts is not None and len(pts) >= 8:
                    p1, st, _ = cv2.calcOpticalFlowPyrLK(self.key, back, pts, None, winSize=(21, 21), maxLevel=3)
                    ok = st[:, 0] == 1
                    R, n = _ransac(pts[ok], p1[ok])
                    self.inliers.append(n)
            elif self.method == "orb_key":
                kp, des = self.orb.detectAndCompute(back, m)
                if des is not None and self.key_des is not None and len(kp) >= 8:
                    mt = self.bf.knnMatch(self.key_des, des, k=2)
                    good = [a for a, b in (x for x in mt if len(x) == 2) if a.distance < 0.8 * b.distance]
                    p0 = np.float32([self.key_kp[g.queryIdx].pt for g in good])
                    p1 = np.float32([kp[g.trainIdx].pt for g in good])
                    R, n = _ransac(p0, p1, 2.0)
                    self.inliers.append(n)
            elif self.method == "ecc_key":
                try:
                    warp = np.eye(3, dtype=np.float32)
                    _, warp = cv2.findTransformECC(self.key, back, warp, cv2.MOTION_HOMOGRAPHY,
                                                   (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 60, 1e-5),
                                                   m, 5)
                    # ECC's warp maps template (key) coords to input (back) coords
                    R = warp.astype(float)
                    self.inliers.append(-1)
                except cv2.error:
                    R = None
            if R is None or not _plausible(R, self.shape):
                self.lost += 1
                R = np.eye(3)
            self.G = G_prev @ R
        self.prev = gray
        return self.G
