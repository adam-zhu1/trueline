"""
Shared drawing primitives and color palette for PinPoint overlays.

All colors are BGR tuples (OpenCV convention).
"""

import cv2
import numpy as np

# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------
ACCENT = (0, 140, 255)
ACCENT_DIM = (0, 100, 200)
TEXT_VALUE = (255, 255, 255)
TEXT_LABEL = (160, 160, 160)
TEXT_DIM = (100, 100, 100)
PANEL_BG = (0, 0, 0)
PANEL_ALPHA = 0.55
LANE_REF = (0, 100, 180)
TRAIL_COLOR = (0, 140, 255)
BP_MARKER = (0, 140, 255)

# Lane-view specific
LV_BG = (22, 20, 20)
LV_LANE = (60, 55, 55)
LV_LANE_BORDER = (80, 75, 70)
LV_GRID = (75, 70, 65)
LV_GUTTER = (40, 38, 38)
LV_SIDEBAR = (30, 28, 28)

# Fonts
FONT_VALUE = cv2.FONT_HERSHEY_DUPLEX
FONT_LABEL = cv2.FONT_HERSHEY_SIMPLEX


# ---------------------------------------------------------------------------
# Primitives
# ---------------------------------------------------------------------------

def draw_text(img, x, y, text, scale, color, thickness=1, font=None):
    """putText wrapper that always uses LINE_AA."""
    if font is None:
        font = FONT_LABEL
    cv2.putText(img, text, (int(x), int(y)), font, scale, color, thickness, cv2.LINE_AA)


def draw_degrees(img, x, y, value_str, scale, color, thickness=1, font=None):
    """
    Draw an angle value followed by a degree sign. OpenCV's Hershey fonts have no
    `°` glyph (it renders as garbage), so the symbol is a small drawn ring sitting
    superscript to the number. (x, y) is the text baseline origin, as in draw_text.
    """
    if font is None:
        font = FONT_LABEL
    draw_text(img, x, y, value_str, scale, color, thickness, font)
    (tw, th), _ = cv2.getTextSize(value_str, font, scale, thickness)
    r = max(2, int(round(th * 0.18)))
    cv2.circle(img, (int(x + tw + r + 3), int(y - th + r)), r, color,
               max(1, thickness), cv2.LINE_AA)


def rounded_rect(img, pt1, pt2, color, radius, alpha=None):
    """
    Filled rounded rectangle.  If *alpha* is given (0-1), the shape is blended
    onto *img* at that opacity; otherwise it is drawn opaque.
    """
    x1, y1 = int(pt1[0]), int(pt1[1])
    x2, y2 = int(pt2[0]), int(pt2[1])
    if x2 < x1:
        x1, x2 = x2, x1
    if y2 < y1:
        y1, y2 = y2, y1
    r = min(radius, (x2 - x1) // 2, (y2 - y1) // 2)
    r = max(r, 0)

    h, w = img.shape[:2]
    rx1 = max(x1, 0)
    ry1 = max(y1, 0)
    rx2 = min(x2, w)
    ry2 = min(y2, h)
    if rx2 <= rx1 or ry2 <= ry1:
        return

    if alpha is not None and 0.0 < alpha < 1.0:
        roi = img[ry1:ry2, rx1:rx2].copy()

    target = img
    _fill_rounded(target, x1, y1, x2, y2, r, color)

    if alpha is not None and 0.0 < alpha < 1.0:
        blended = cv2.addWeighted(
            img[ry1:ry2, rx1:rx2], alpha,
            roi, 1.0 - alpha, 0,
        )
        img[ry1:ry2, rx1:rx2] = blended


def _fill_rounded(img, x1, y1, x2, y2, r, color):
    """Draw the filled body + corner arcs of a rounded rect."""
    cv2.rectangle(img, (x1 + r, y1), (x2 - r, y2), color, -1, cv2.LINE_AA)
    cv2.rectangle(img, (x1, y1 + r), (x2, y2 - r), color, -1, cv2.LINE_AA)
    cv2.ellipse(img, (x1 + r, y1 + r), (r, r), 180, 0, 90, color, -1, cv2.LINE_AA)
    cv2.ellipse(img, (x2 - r, y1 + r), (r, r), 270, 0, 90, color, -1, cv2.LINE_AA)
    cv2.ellipse(img, (x2 - r, y2 - r), (r, r), 0, 0, 90, color, -1, cv2.LINE_AA)
    cv2.ellipse(img, (x1 + r, y2 - r), (r, r), 90, 0, 90, color, -1, cv2.LINE_AA)


def draw_metric(img, x, y, value_str, label_str, col_width=None, degree=False):
    """
    Big value on top, small label below.  Returns the width consumed so the
    caller can lay out multiple metrics in a row. *degree* appends a `°` ring.
    """
    v_scale = 0.7
    l_scale = 0.35
    v_thick = 2
    l_thick = 1

    (vw, vh), _ = cv2.getTextSize(value_str, FONT_VALUE, v_scale, v_thick)
    (lw, lh), _ = cv2.getTextSize(label_str, FONT_LABEL, l_scale, l_thick)

    deg_r = max(2, int(round(vh * 0.18))) if degree else 0
    deg_w = (deg_r * 2 + 3) if degree else 0

    w = col_width if col_width else max(vw + deg_w, lw) + 4
    vx = x + (w - (vw + deg_w)) // 2
    lx = x + (w - lw) // 2

    draw_text(img, vx, y, value_str, v_scale, TEXT_VALUE, v_thick, FONT_VALUE)
    if degree:
        cv2.circle(img, (int(vx + vw + deg_r + 3), int(y - vh + deg_r)),
                   deg_r, TEXT_VALUE, v_thick, cv2.LINE_AA)
    draw_text(img, lx, y + vh + 6, label_str, l_scale, TEXT_LABEL, l_thick, FONT_LABEL)

    return w


def metrics_panel(img, x, y, metrics, pad=14, gap=18, radius=10):
    """
    Draw a row of metrics inside a semi-transparent rounded panel.

    *metrics* is a list of (value_str, label_str) pairs.
    The panel is anchored at (x, y) = top-left.
    """
    if not metrics:
        return

    v_scale = 0.7
    l_scale = 0.35
    v_thick = 2
    l_thick = 1

    col_widths = []
    degrees = []
    max_vh = 0
    max_lh = 0
    for item in metrics:
        val, lab = item[0], item[1]
        deg = bool(item[2]) if len(item) > 2 else False
        degrees.append(deg)
        (vw, vh), _ = cv2.getTextSize(val, FONT_VALUE, v_scale, v_thick)
        (lw, lh), _ = cv2.getTextSize(lab, FONT_LABEL, l_scale, l_thick)
        deg_w = (max(2, int(round(vh * 0.18))) * 2 + 3) if deg else 0
        col_widths.append(max(vw + deg_w, lw) + 4)
        max_vh = max(max_vh, vh)
        max_lh = max(max_lh, lh)

    total_w = sum(col_widths) + gap * (len(metrics) - 1) + 2 * pad
    total_h = max_vh + max_lh + 6 + 2 * pad

    rounded_rect(img, (x, y), (x + total_w, y + total_h), PANEL_BG, radius, PANEL_ALPHA)

    cx = x + pad
    for i, item in enumerate(metrics):
        draw_metric(img, cx, y + pad + max_vh, item[0], item[1], col_widths[i],
                    degree=degrees[i])
        cx += col_widths[i] + gap


def draw_pill_label(img, x, y, value_str, icon="circle", color=None, scale=1.0):
    """
    Draw a small icon (circle or triangle) + rounded pill with a value label.
    (x, y) is the center of the icon. The pill extends to the right.
    ``scale`` multiplies every dimension so the marker matches a scaled canvas.
    """
    if color is None:
        color = ACCENT

    def S(v):
        return int(round(v * scale))

    t_scale = 0.42 * scale
    t_thick = max(1, int(round(scale)))
    (tw, th), _ = cv2.getTextSize(value_str, FONT_LABEL, t_scale, t_thick)

    pill_x = x + S(10)
    pill_y = y - th // 2 - S(4)
    pill_w = tw + S(14)
    pill_h = th + S(8)

    rounded_rect(img, (pill_x, pill_y), (pill_x + pill_w, pill_y + pill_h),
                 PANEL_BG, S(8), 0.6)

    if icon == "circle":
        cv2.circle(img, (int(x), int(y)), S(5), color, -1, cv2.LINE_AA)
    elif icon == "triangle":
        tri = np.array([
            [int(x), int(y) - S(5)],
            [int(x) - S(5), int(y) + S(4)],
            [int(x) + S(5), int(y) + S(4)],
        ], dtype=np.int32)
        cv2.fillPoly(img, [tri], color)

    draw_text(img, pill_x + S(7), pill_y + th + S(3), value_str,
              t_scale, TEXT_VALUE, t_thick)
