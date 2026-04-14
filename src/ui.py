"""
Shared drawing primitives and color palette for PinPoint overlays.

All colors are BGR tuples (OpenCV convention).
"""

import cv2
import numpy as np

# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------
ACCENT = (180, 160, 100)
TEXT_VALUE = (255, 255, 255)
TEXT_LABEL = (160, 160, 160)
TEXT_DIM = (100, 100, 100)
PANEL_BG = (0, 0, 0)
PANEL_ALPHA = 0.55
LANE_REF = (180, 170, 0)
TRAIL_COLOR = (255, 255, 255)
BP_MARKER = (200, 120, 255)

# Lane-view specific
LV_BG = (25, 20, 20)
LV_LANE = (120, 155, 180)
LV_LANE_BORDER = (90, 120, 140)
LV_GRID = (108, 140, 160)
LV_GUTTER = (55, 55, 55)

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


def draw_metric(img, x, y, value_str, label_str, col_width=None):
    """
    Big value on top, small label below.  Returns the width consumed so the
    caller can lay out multiple metrics in a row.
    """
    v_scale = 0.7
    l_scale = 0.35
    v_thick = 2
    l_thick = 1

    (vw, vh), _ = cv2.getTextSize(value_str, FONT_VALUE, v_scale, v_thick)
    (lw, lh), _ = cv2.getTextSize(label_str, FONT_LABEL, l_scale, l_thick)

    w = col_width if col_width else max(vw, lw) + 4
    vx = x + (w - vw) // 2
    lx = x + (w - lw) // 2

    draw_text(img, vx, y, value_str, v_scale, TEXT_VALUE, v_thick, FONT_VALUE)
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
    max_vh = 0
    max_lh = 0
    for val, lab in metrics:
        (vw, vh), _ = cv2.getTextSize(val, FONT_VALUE, v_scale, v_thick)
        (lw, lh), _ = cv2.getTextSize(lab, FONT_LABEL, l_scale, l_thick)
        col_widths.append(max(vw, lw) + 4)
        max_vh = max(max_vh, vh)
        max_lh = max(max_lh, lh)

    total_w = sum(col_widths) + gap * (len(metrics) - 1) + 2 * pad
    total_h = max_vh + max_lh + 6 + 2 * pad

    rounded_rect(img, (x, y), (x + total_w, y + total_h), PANEL_BG, radius, PANEL_ALPHA)

    cx = x + pad
    for i, (val, lab) in enumerate(metrics):
        draw_metric(img, cx, y + pad + max_vh, val, lab, col_widths[i])
        cx += col_widths[i] + gap
