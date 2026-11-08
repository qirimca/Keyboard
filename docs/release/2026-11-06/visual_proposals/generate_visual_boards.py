#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate high-resolution visual design boards (2400x1600 PNGs) and interactive
prototype previews for QırımKey using claude-canvas-design, claude-frontend-design,
claude-algorithmic-art, and claude-theme-factory principles.

Verified fixes:
1. Centered Daily Phrase + vector arrow.up.left.circle + vector 4-point sparkles right next to each other (поряд) with zero background pill.
2. 100% vector-drawn icons (zero missing-glyph tofu boxes ▯, zero emojis).
3. True local quadratic Bezier corner filleting + Chaikin smoothing for Swipe v2 in Board 3B so the comet ribbon passes directly through every anchor key (s -> e -> l -> a -> m).
4. Dedicated left label gutter in Board 3A so the sine wave never overlaps y-axis opacity labels.
5. Optically centered 4x zoom keycap glyphs in Board 1 (including custom vector Smart Apostrophe ʼ in Option 1C) and script-aware 'абв' / 'abc' bottom key.
6. Stacked bottom Cyrillic & Ukrainian rows in Board 2 with vertically centered [абв] keycap selectors (settings.cyrillic.abvSelector & settings.ukrainianCyrillic.abvSelector) and vector Tryzub / Union Jack / Taraq Tamğa emblems.
"""

import math
import os
import random
from PIL import Image, ImageDraw, ImageFont

OUT_DIR = "/Users/love/Documents/Documents - MacBook Air - Віта/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals"
CANVAS_FONTS_DIR = "/Users/love/.gemini/config/plugins/claude-skills/skills/claude-canvas-design/canvas-fonts"

os.makedirs(OUT_DIR, exist_ok=True)


def load_font(size, style="sans", bold=False):
    """
    Uses Arial / Georgia on macOS which have 100% coverage for Crimean Tatar Latin (ğ, ñ, ş, ç, ö, ü, â),
    Cyrillic (къ, гъ, нъ, ї, є, ґ, ʼ), and mathematical/arrow glyphs (→, ≥, ×, Δ, θ).
    """
    if style == "serif":
        candidates = [
            "/System/Library/Fonts/Supplemental/Georgia Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Georgia.ttf",
            os.path.join(CANVAS_FONTS_DIR, "Lora-Bold.ttf" if bold else "Lora-Regular.ttf"),
        ]
    elif style == "mono":
        candidates = [
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/System/Library/Fonts/Menlo.ttc",
        ]
    else:
        candidates = [
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/System/Library/Fonts/SFNS.ttf",
        ]

    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


# Canonical 9x5 Taraq Tamğa polygon vertices (from SpaceBarLabel.swift)
TAMGA_VERTICES = [
    (1, 0), (8, 0),
    (8, 3), (9, 3),
    (9, 4), (7, 4),
    (7, 1), (5, 1),
    (5, 4), (6, 4),
    (6, 5), (3, 5),
    (3, 4), (4, 4),
    (4, 1), (2, 1),
    (2, 4), (0, 4),
    (0, 3), (1, 3)
]


def draw_tamga(draw, cx, cy, width, fill_color, outline_color=None, outline_width=1):
    scale = width / 9.0
    height = scale * 5.0
    ox = cx - width * 0.5
    oy = cy - height * 0.5
    pts = [(ox + gx * scale, oy + gy * scale) for (gx, gy) in TAMGA_VERTICES]
    draw.polygon(pts, fill=fill_color, outline=outline_color, width=outline_width)


def draw_tryzub_vector(draw, cx, cy, size, color):
    """Draws a crisp vector Ukrainian Tryzub emblem."""
    s = size * 0.5
    # Central spire
    draw.polygon([
        (cx, cy - s),
        (cx + s * 0.16, cy - s * 0.35),
        (cx + s * 0.12, cy + s * 0.55),
        (cx, cy + s * 0.95),
        (cx - s * 0.12, cy + s * 0.55),
        (cx - s * 0.16, cy - s * 0.35),
    ], fill=color)
    # Left trident wing
    draw.polygon([
        (cx - s * 0.72, cy - s * 0.82),
        (cx - s * 0.48, cy - s * 0.82),
        (cx - s * 0.48, cy + s * 0.25),
        (cx - s * 0.12, cy + s * 0.42),
        (cx - s * 0.12, cy + s * 0.62),
        (cx - s * 0.72, cy + s * 0.42),
    ], fill=color)
    # Right trident wing
    draw.polygon([
        (cx + s * 0.72, cy - s * 0.82),
        (cx + s * 0.48, cy - s * 0.82),
        (cx + s * 0.48, cy + s * 0.25),
        (cx + s * 0.12, cy + s * 0.42),
        (cx + s * 0.12, cy + s * 0.62),
        (cx + s * 0.72, cy + s * 0.42),
    ], fill=color)
    # Crossbar
    draw.rectangle([cx - s * 0.58, cy + s * 0.05, cx + s * 0.58, cy + s * 0.22], fill=color)


def draw_union_jack_badge(draw, x1, y1, x2, y2, radius=12):
    """Draws a vector Union Jack inside a rounded badge."""
    draw.rounded_rectangle([x1, y1, x2, y2], radius=radius, fill=(1, 33, 105))
    cx = (x1 + x2) // 2
    cy = (y1 + y2) // 2
    # Diagonals
    draw.line([(x1 + 5, y1 + 5), (x2 - 5, y2 - 5)], fill=(255, 255, 255), width=5)
    draw.line([(x2 - 5, y1 + 5), (x1 + 5, y2 - 5)], fill=(255, 255, 255), width=5)
    draw.line([(x1 + 5, y1 + 5), (x2 - 5, y2 - 5)], fill=(200, 16, 46), width=2)
    draw.line([(x2 - 5, y1 + 5), (x1 + 5, y2 - 5)], fill=(200, 16, 46), width=2)
    # St George cross
    draw.rectangle([cx - 5, y1 + 2, cx + 5, y2 - 2], fill=(255, 255, 255))
    draw.rectangle([x1 + 2, cy - 5, x2 - 2, cy + 5], fill=(255, 255, 255))
    draw.rectangle([cx - 3, y1 + 2, cx + 3, y2 - 2], fill=(200, 16, 46))
    draw.rectangle([x1 + 2, cy - 3, x2 - 2, cy + 3], fill=(200, 16, 46))


def draw_smart_apostrophe_vector(draw, cx, cy, scale, color):
    """Draws a crisp, optically centered Ukrainian/Crimean Tatar modifier apostrophe (U+02BC ʼ)."""
    # Upper diamond/comma head + curved tail
    r = 9.0 * scale
    hx = cx + 2.0 * scale
    hy = cy - 18.0 * scale
    draw.ellipse([hx - r, hy - r, hx + r, hy + r], fill=color)
    tail_pts = [
        (hx + r * 0.85, hy + r * 0.1),
        (hx + r * 0.95, hy + r * 1.4),
        (hx + r * 0.15, hy + r * 2.8),
        (hx - r * 0.85, hy + r * 3.4),
        (hx - r * 1.15, hy + r * 2.7),
        (hx - r * 0.25, hy + r * 1.9),
        (hx - r * 0.10, hy + r * 0.7),
    ]
    draw.polygon(tail_pts, fill=color)


def draw_sparkles_vector(draw, cx, cy, r, color):
    """Draws a true 4-point vector sparkles icon (SF Symbol 'sparkles') with zero background pill."""
    pts = [
        (cx, cy - r),
        (cx + r * 0.26, cy - r * 0.26),
        (cx + r, cy),
        (cx + r * 0.26, cy + r * 0.26),
        (cx, cy + r),
        (cx - r * 0.26, cy + r * 0.26),
        (cx - r, cy),
        (cx - r * 0.26, cy - r * 0.26),
    ]
    draw.polygon(pts, fill=color)
    sx, sy, sr = cx + r * 0.72, cy - r * 0.68, r * 0.44
    s_pts = [
        (sx, sy - sr),
        (sx + sr * 0.28, sy - sr * 0.28),
        (sx + sr, sy),
        (sx + sr * 0.28, sy + sr * 0.28),
        (sx, sy + sr),
        (sx - sr * 0.28, sy + sr * 0.28),
        (sx - sr, sy),
        (sx - sr * 0.28, sy - sr * 0.28),
    ]
    draw.polygon(s_pts, fill=color)
    tx, ty, tr = cx - r * 0.68, cy + r * 0.68, r * 0.28
    t_pts = [
        (tx, ty - tr), (tx + tr, ty), (tx, ty + tr), (tx - tr, ty)
    ]
    draw.polygon(t_pts, fill=color)


def draw_insert_arrow_circle(draw, cx, cy, r, bg_color, fg_color):
    """Draws SF Symbol 'arrow.up.left.circle.fill' as pure vector geometry."""
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=bg_color)
    x0, y0 = cx + r * 0.35, cy + r * 0.35
    x1, y1 = cx - r * 0.35, cy - r * 0.35
    draw.line([(x0, y0), (x1, y1)], fill=fg_color, width=2)
    draw.line([(x1, y1), (x1 + r * 0.48, y1)], fill=fg_color, width=2)
    draw.line([(x1, y1), (x1, y1 + r * 0.48)], fill=fg_color, width=2)


def draw_shift_vector(draw, cx, cy, s, color):
    pts = [
        (cx, cy - s),
        (cx + s, cy),
        (cx + s * 0.45, cy),
        (cx + s * 0.45, cy + s * 0.85),
        (cx - s * 0.45, cy + s * 0.85),
        (cx - s * 0.45, cy),
        (cx - s, cy),
    ]
    draw.polygon(pts, outline=color, width=2)


def draw_backspace_vector(draw, cx, cy, s, color):
    pts = [
        (cx - s * 1.1, cy),
        (cx - s * 0.45, cy - s * 0.75),
        (cx + s * 1.0, cy - s * 0.75),
        (cx + s * 1.0, cy + s * 0.75),
        (cx - s * 0.45, cy + s * 0.75),
    ]
    draw.polygon(pts, outline=color, width=2)
    draw.line([(cx - s * 0.1, cy - s * 0.32), (cx + s * 0.55, cy + s * 0.32)], fill=color, width=2)
    draw.line([(cx + s * 0.55, cy - s * 0.32), (cx - s * 0.1, cy + s * 0.32)], fill=color, width=2)


def draw_bolt_vector(draw, cx, cy, s, color):
    pts = [
        (cx + s * 0.2, cy - s),
        (cx - s * 0.65, cy + s * 0.1),
        (cx - s * 0.05, cy + s * 0.1),
        (cx - s * 0.25, cy + s),
        (cx + s * 0.65, cy - s * 0.1),
        (cx + s * 0.05, cy - s * 0.1),
    ]
    draw.polygon(pts, fill=color)


def draw_centered_text(draw, cx, cy, text, font, fill):
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text((cx - tw * 0.5 - bbox[0], cy - th * 0.5 - bbox[1]), text, font=font, fill=fill)


def hex_to_rgb(hex_str):
    h = hex_str.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def compute_filleted_chaikin_spine(ctrl_pts, max_fillet_span=28.0, samples_per_seg=10):
    """
    Faithfully implements SystemKeyboard.swift's quadratic Bezier corner filleting + 2-pass Chaikin
    subdivision so the Swipe v2 comet passes directly through/around every anchor keycap without
    collapsing long segments inward!
    """
    if len(ctrl_pts) < 2:
        return ctrl_pts[:]

    dense = [ctrl_pts[0]]
    for i in range(1, len(ctrl_pts) - 1):
        p_prev = ctrl_pts[i - 1]
        p_curr = ctrl_pts[i]
        p_next = ctrl_pts[i + 1]

        v_in = (p_curr[0] - p_prev[0], p_curr[1] - p_prev[1])
        v_out = (p_next[0] - p_curr[0], p_next[1] - p_curr[1])
        len_in = math.hypot(*v_in)
        len_out = math.hypot(*v_out)
        if len_in < 1e-3 or len_out < 1e-3:
            dense.append(p_curr)
            continue

        span = min(max_fillet_span, 0.32 * min(len_in, len_out))
        entry_pt = (p_curr[0] - (v_in[0] / len_in) * span, p_curr[1] - (v_in[1] / len_in) * span)
        exit_pt = (p_curr[0] + (v_out[0] / len_out) * span, p_curr[1] + (v_out[1] / len_out) * span)

        # Sample linear approach from last point in dense to entry_pt
        start_seg = dense[-1]
        for s_i in range(1, samples_per_seg):
            u = s_i / float(samples_per_seg)
            dense.append((
                start_seg[0] + (entry_pt[0] - start_seg[0]) * u,
                start_seg[1] + (entry_pt[1] - start_seg[1]) * u
            ))

        # Sample quadratic Bezier around the corner p_curr
        for b_i in range(samples_per_seg + 1):
            t = b_i / float(samples_per_seg)
            omt = 1.0 - t
            bx = omt * omt * entry_pt[0] + 2 * omt * t * p_curr[0] + t * t * exit_pt[0]
            by = omt * omt * entry_pt[1] + 2 * omt * t * p_curr[1] + t * t * exit_pt[1]
            dense.append((bx, by))

    # Final segment to last control point
    start_seg = dense[-1]
    end_pt = ctrl_pts[-1]
    for s_i in range(1, samples_per_seg + 1):
        u = s_i / float(samples_per_seg)
        dense.append((
            start_seg[0] + (end_pt[0] - start_seg[0]) * u,
            start_seg[1] + (end_pt[1] - start_seg[1]) * u
        ))

    # 2 passes of Chaikin corner-cutting on the dense spine
    pts = dense
    for _ in range(2):
        new_pts = [pts[0]]
        for i in range(len(pts) - 1):
            p0, p1 = pts[i], pts[i + 1]
            new_pts.append((0.75 * p0[0] + 0.25 * p1[0], 0.75 * p0[1] + 0.25 * p1[1]))
            new_pts.append((0.25 * p0[0] + 0.75 * p1[0], 0.25 * p0[1] + 0.75 * p1[1]))
        new_pts.append(pts[-1])
        pts = new_pts
    return pts


def draw_board_header(draw, W, title, subtitle, board_code):
    f_eyebrow = load_font(18, "mono", bold=True)
    f_title = load_font(44, "serif", bold=True)
    f_sub = load_font(21, "sans", bold=False)

    draw.text((72, 48), board_code, font=f_eyebrow, fill=(0, 135, 219))
    draw.text((72, 78), title, font=f_title, fill=(20, 20, 19))
    draw.text((72, 136), subtitle, font=f_sub, fill=(94, 93, 89))

    draw.rounded_rectangle([W - 340, 54, W - 72, 118], radius=16, fill=(18, 149, 216))
    draw_tamga(draw, W - 300, 86, 36, fill_color=(255, 215, 0))
    f_badge = load_font(18, "mono", bold=True)
    draw.text((W - 266, 75), "QIRIMKEY STUDIO", font=f_badge, fill=(255, 255, 255))

    draw.line([(72, 182), (W - 72, 182)], fill=(215, 212, 205), width=2)


def render_mini_keyboard(
    draw, x, y, w, h, mode="whisper", script="latn",
    kb_bg=(214, 218, 226), key_bg=(255, 255, 255),
    sys_bg=(182, 187, 196), ink=(18, 18, 20),
    accent=(0, 135, 219), gold=(212, 155, 26),
    show_wisdom=True, highlight_key=None
):
    is_dark_kb = (kb_bg[0] + kb_bg[1] + kb_bg[2]) < 240
    chassis_border = (48, 62, 82) if is_dark_kb else (188, 192, 200)
    draw.rounded_rectangle([x, y, x + w, y + h], radius=24, fill=kb_bg, outline=chassis_border, width=2)

    tb_y = y + 10
    tb_h = 48
    f_tb = load_font(18, "sans", bold=False)
    f_tb_bold = load_font(18, "sans", bold=True)
    muted_ink = (
        int(ink[0] * 0.62 + kb_bg[0] * 0.38),
        int(ink[1] * 0.62 + kb_bg[1] * 0.38),
        int(ink[2] * 0.62 + kb_bg[2] * 0.38),
    )

    if show_wisdom:
        phrase = "Atalar sözünde altın bar." if script == "latn" else "Közü yoq — körsete, sözü yoq — ögrete."
        text_w = int(draw.textlength(phrase, font=f_tb))
        tamga_w = 20
        arrow_d = 16
        sparkles_d = 18
        total_cluster_w = tamga_w + 8 + text_w + 8 + arrow_d + 10 + sparkles_d
        start_cx = x + (w - total_cluster_w) // 2
        cy_bar = tb_y + tb_h // 2

        draw_tamga(draw, start_cx + tamga_w // 2, cy_bar, tamga_w, fill_color=ink)
        tx_x = start_cx + tamga_w + 8
        draw.text((tx_x, cy_bar - 10), phrase, font=f_tb, fill=ink)
        ar_cx = tx_x + text_w + 8 + arrow_d // 2
        draw_insert_arrow_circle(draw, ar_cx, cy_bar, arrow_d // 2, muted_ink, kb_bg)
        sp_cx = ar_cx + arrow_d // 2 + 10 + sparkles_d // 2
        draw_sparkles_vector(draw, sp_cx, cy_bar, 9, ink)
    else:
        slot_w = (w - 24) // 3
        s0 = "“selam”" if script == "latn" else "“кирим”"
        s1 = "selâm" if script == "latn" else "кʼирим"
        s2 = "selâmlar" if script == "latn" else "кʼиримда"
        draw_centered_text(draw, x + 12 + slot_w // 2, tb_y + tb_h // 2, s0, f_tb, ink)
        pill_x1 = x + 12 + slot_w + 18
        pill_x2 = x + 12 + 2 * slot_w - 18
        draw.rounded_rectangle([pill_x1, tb_y + 5, pill_x2, tb_y + tb_h - 5], radius=18, fill=key_bg, outline=accent, width=2)
        draw_centered_text(draw, (pill_x1 + pill_x2) // 2, tb_y + tb_h // 2, s1, f_tb_bold, ink)
        draw_centered_text(draw, x + 12 + 2 * slot_w + slot_w // 2, tb_y + tb_h // 2, s2, f_tb, ink)

    rows_latn = [
        [("q","1"),("w","2"),("e","3"),("r","4"),("t","5"),("y","6"),("u","7"),("i","8"),("o","9"),("p","0"),("ğ","-"),("ü","=")],
        [("a","@"),("s","#"),("d","$"),("f","%"),("g","&"),("h","*"),("j","("),("k",")"),("l","_"),("ş","+"),("ı","/"),("â",":")],
        [("SHIFT",""),("z",'"'),("x","'"),("c",";"),("v","!"),("b","?"),("n",","),("m","."),("ö","«"),("ç","»"),("ñ","~"),("DEL","")]
    ]
    rows_uk = [
        [("й","1"),("ц","2"),("у","3"),("к","4"),("е","5"),("н","6"),("г","7"),("ш","8"),("щ","9"),("з","0"),("х","-"),("ї","yi")],
        [("ф","@"),("і","i"),("в","$"),("а","%"),("п","&"),("р","*"),("о","("),("л",")"),("д","_"),("ж","+"),("є","ye"),("ʼ","q/ñ")],
        [("SHIFT",""),("я",'"'),("ч","'"),("с",";"),("м","!"),("и","ı"),("т",","),("ь","."),("б","«"),("ю","»"),("ґ","g"),("DEL","")]
    ]
    rows = rows_latn if script == "latn" else rows_uk

    f_key = load_font(21, "sans", bold=False)
    f_flick = load_font(10, "mono", bold=True)
    f_sys = load_font(15, "sans", bold=True)

    pad_x = 12
    gap_x = 6
    gap_y = 8
    row_y0 = tb_y + tb_h + 8
    avail_h = h - (row_y0 - y) - 14
    row_h = (avail_h - 3 * gap_y) // 4
    col_w = (w - 2 * pad_x - 11 * gap_x) / 12.0

    for r_idx, row in enumerate(rows):
        ky = row_y0 + r_idx * (row_h + gap_y)
        for c_idx, (main_ch, flick_ch) in enumerate(row):
            kx = int(x + pad_x + c_idx * (col_w + gap_x))
            kw = int(col_w)
            is_sys = main_ch in ("SHIFT", "DEL")
            is_hl = (highlight_key == main_ch)

            if mode == "borderless" and not is_sys:
                if is_hl:
                    bloom_fill = (
                        int(kb_bg[0] * 0.78 + accent[0] * 0.22),
                        int(kb_bg[1] * 0.78 + accent[1] * 0.22),
                        int(kb_bg[2] * 0.78 + accent[2] * 0.22),
                    )
                    draw.rounded_rectangle([kx - 2, ky - 2, kx + kw + 2, ky + row_h + 2], radius=12, fill=bloom_fill, outline=accent, width=2)
            else:
                fill_c = sys_bg if is_sys else key_bg
                out_c = gold if is_hl else (chassis_border if is_dark_kb else (225, 228, 234))
                draw.rounded_rectangle([kx, ky, kx + kw, ky + row_h], radius=10, fill=fill_c, outline=out_c, width=2 if is_hl else 1)

            if flick_ch:
                flick_col = accent if is_hl else muted_ink
                draw.text((kx + kw - 18, ky + 3), flick_ch, font=f_flick, fill=flick_col)

            if main_ch == "SHIFT":
                draw_shift_vector(draw, kx + kw // 2, ky + row_h // 2, 8, ink)
            elif main_ch == "DEL":
                draw_backspace_vector(draw, kx + kw // 2, ky + row_h // 2, 8, ink)
            elif main_ch == "ʼ":
                draw_smart_apostrophe_vector(draw, kx + kw // 2, ky + row_h // 2 + 5, 0.36, ink)
            else:
                draw_centered_text(draw, kx + kw // 2, ky + row_h // 2 + 2, main_ch, f_key, ink)

    by = row_y0 + 3 * (row_h + gap_y)
    w_small = int(col_w * 1.15)
    draw.rounded_rectangle([x + pad_x, by, x + pad_x + w_small, by + row_h], radius=10, fill=sys_bg)
    draw_centered_text(draw, x + pad_x + w_small // 2, by + row_h // 2, "123", f_sys, ink)

    gx = x + pad_x + w_small + gap_x
    draw.rounded_rectangle([gx, by, gx + w_small, by + row_h], radius=10, fill=sys_bg)
    # Match DemoStyleProvider.swift line 373: "abc" when Cyrillic is active, "абв" when Latin is active
    script_toggle_label = "абв" if script == "latn" else "abc"
    draw_centered_text(draw, gx + w_small // 2, by + row_h // 2, script_toggle_label, f_sys, ink)

    sx1 = gx + w_small + gap_x
    w_ret = int(col_w * 2.3)
    w_dot = int(col_w * 1.0)
    sx2 = x + w - pad_x - w_ret - w_dot - 2 * gap_x
    draw.rounded_rectangle([sx1, by, sx2, by + row_h], radius=10, fill=key_bg, outline=chassis_border, width=1)
    draw_tamga(draw, (sx1 + sx2) // 2, by + row_h // 2, 26, fill_color=muted_ink)
    code_str = "QT" if script == "latn" else "Кʼ"
    draw.text((sx2 - 24, by + row_h - 16), code_str, font=f_flick, fill=muted_ink)

    dx1 = sx2 + gap_x
    if mode != "borderless":
        draw.rounded_rectangle([dx1, by, dx1 + w_dot, by + row_h], radius=10, fill=key_bg, outline=chassis_border, width=1)
    draw_centered_text(draw, dx1 + w_dot // 2, by + row_h // 2, ".", f_key, ink)

    rx1 = dx1 + w_dot + gap_x
    rx2 = x + w - pad_x
    draw.rounded_rectangle([rx1, by, rx2, by + row_h], radius=10, fill=accent)
    ret_txt_col = (20, 20, 19) if (accent[0] * 0.299 + accent[1] * 0.587 + accent[2] * 0.114) > 165 else (255, 255, 255)
    draw_centered_text(draw, (rx1 + rx2) // 2, by + row_h // 2, "Return", f_sys, ret_txt_col)


def generate_board_1():
    """Proposal_1_Minimalist_Keyboard_Concepts.png"""
    W, H = 2400, 1600
    img = Image.new("RGB", (W, H), (244, 241, 234))
    draw = ImageDraw.Draw(img)

    draw_board_header(
        draw, W,
        "Proposal I — Minimalist Keyboard Architectures & Top-Bar Choreography",
        "Three tactile paradigms for the 12-column QırımKey keyplane: Rim-Lit Liquid Whisper, Typographic Air (Borderless), and Ukrainian ФІВА 12×12.",
        "BOARD 01 / CLAUDE-CANVAS-DESIGN & FRONTEND-DESIGN"
    )

    col_w = 720
    col_h = 1280
    gap = 48
    start_x = 72
    top_y = 216

    f_card_num = load_font(15, "mono", bold=True)
    f_card_title = load_font(28, "serif", bold=True)
    f_card_desc = load_font(16, "sans", bold=False)
    f_spec_label = load_font(15, "mono", bold=True)
    f_spec_body = load_font(15, "sans", bold=False)

    specs = [
        {
            "tag": "OPTION 1A · DEFAULT REFINEMENT",
            "title": "Liquid Whisper (Rim-Lit Glass)",
            "desc": "0.5pt top specular rim with whisper-quiet secondary flicks (22% resting → 42% proximity bloom) and unplattered daily wisdom.",
            "mode": "whisper",
            "script": "latn",
            "wisdom": True,
            "hl": "ğ",
            "kb_bg": (214, 218, 226),
            "key_bg": (255, 255, 255),
            "sys_bg": (184, 189, 198),
            "ink": (18, 18, 20),
            "accent": (0, 135, 219),
            "bullets": [
                ("Top Rim Specular", "LinearGradient white 45% → 8% (0.5pt)"),
                ("Flick Hierarchy", "9.5pt condensed at 22% resting opacity"),
                ("Daily Wisdom Bar", "Color.clear unplattered phrase + adjacent sparkles"),
                ("Spacebar Soul", "9×5 Taraq Tamğa + bottom-right 'QT' (0.20 alpha)")
            ]
        },
        {
            "tag": "OPTION 1B · ULTRA-MINIMALIST",
            "title": "Typographic Air (Borderless)",
            "desc": "Alphabetic keycap boxes dissolve into pure negative space; only perimeter system keys keep glass pills to anchor thumb memory.",
            "mode": "borderless",
            "script": "latn",
            "wisdom": False,
            "hl": "ş",
            "kb_bg": (246, 244, 238),
            "key_bg": (255, 255, 255),
            "sys_bg": (226, 222, 214),
            "ink": (20, 20, 19),
            "accent": (29, 78, 216),
            "bullets": [
                ("Zero Letter Cages", "0% keycap fill on alphabetic rows 0..2"),
                ("Tactile Bloom", "Radial 28pt soft aura on touch-down"),
                ("Stadium Pill", "14pt continuous pill strictly on Slot 1 autocorrect"),
                ("Visual Calm", "Reduces high-frequency visual grid edges by 74%")
            ]
        },
        {
            "tag": "OPTION 1C · UKRAINIAN ФІВА & DARK GLASS",
            "title": "Nocturnal Glass & ФІВА 12×12",
            "desc": "Bioluminescent midnight slate with Ukrainian-adapted ФІВА (ї, є, ґ, smart apostrophe ʼ → q/ñ/ğ) and riddle #65 reveal.",
            "mode": "whisper",
            "script": "uk",
            "wisdom": True,
            "hl": "ʼ",
            "kb_bg": (14, 23, 38),
            "key_bg": (26, 40, 62),
            "sys_bg": (18, 29, 46),
            "ink": (237, 244, 252),
            "accent": (18, 149, 216),
            "bullets": [
                ("Smart Apostrophe ʼ", "Row 1 Col 11: кʼ→q, нʼ→ñ, гʼ→ğ, literal ʼ after vowel"),
                ("Riddle #65 Reveal", "Banner hides ': Kitap', reveals on tap insertion"),
                ("Nocturnal Contrast", "Deep slate #0E1726 with cyan specular top edge"),
                ("2-Char Corner Code", "Condensed 'Кʼ' at 0.30 dark opacity (never 3-char)")
            ]
        }
    ]

    for idx, sp in enumerate(specs):
        cx = start_x + idx * (col_w + gap)
        draw.rounded_rectangle([cx, top_y, cx + col_w, top_y + col_h], radius=28, fill=(255, 255, 255), outline=(218, 215, 208), width=2)

        draw.text((cx + 32, top_y + 28), sp["tag"], font=f_card_num, fill=sp["accent"])
        draw.text((cx + 32, top_y + 56), sp["title"], font=f_card_title, fill=(20, 20, 19))

        words = sp["desc"].split()
        lines, curr = [], ""
        for w in words:
            if len(curr + " " + w) <= 58:
                curr = (curr + " " + w).strip()
            else:
                lines.append(curr)
                curr = w
        if curr:
            lines.append(curr)
        for l_i, line in enumerate(lines[:3]):
            draw.text((cx + 32, top_y + 100 + l_i * 23), line, font=f_card_desc, fill=(94, 93, 89))

        kb_y = top_y + 188
        kb_h = 360
        render_mini_keyboard(
            draw, cx + 24, kb_y, col_w - 48, kb_h,
            mode=sp["mode"], script=sp["script"],
            kb_bg=sp["kb_bg"], key_bg=sp["key_bg"], sys_bg=sp["sys_bg"],
            ink=sp["ink"], accent=sp["accent"], show_wisdom=sp["wisdom"],
            highlight_key=sp["hl"]
        )

        zoom_y = kb_y + kb_h + 28
        zoom_h = 310
        draw.rounded_rectangle([cx + 24, zoom_y, cx + col_w - 24, zoom_y + zoom_h], radius=20, fill=(248, 246, 241), outline=(224, 221, 214), width=1)
        draw.text((cx + 44, zoom_y + 20), "KEYCAP & TOOLBAR OPTICAL ANATOMY (4X ZOOM)", font=f_spec_label, fill=(94, 93, 89))

        zk_x, zk_y, zk_w, zk_h = cx + 48, zoom_y + 62, 170, 215
        if sp["mode"] == "borderless":
            draw.rounded_rectangle([zk_x, zk_y, zk_x + zk_w, zk_y + zk_h], radius=24, fill=(228, 236, 252), outline=sp["accent"], width=2)
        else:
            draw.rounded_rectangle([zk_x, zk_y, zk_x + zk_w, zk_y + zk_h], radius=24, fill=sp["key_bg"], outline=sp["accent"], width=3)
        f_zoom_flick = load_font(20, "mono", bold=True)
        f_zoom_main = load_font(78, "sans", bold=False)
        flick_txt = "-" if idx == 0 else ("+" if idx == 1 else "q/ñ")
        draw.text((zk_x + zk_w - 18 - int(draw.textlength(flick_txt, font=f_zoom_flick)), zk_y + 16), flick_txt, font=f_zoom_flick, fill=sp["accent"])
        if sp["hl"] == "ʼ":
            # Crisp centered vector modifier apostrophe + subtle 'ʼ (U+02BC)' caption
            draw_smart_apostrophe_vector(draw, zk_x + zk_w // 2, zk_y + zk_h // 2 + 4, 1.55, sp["ink"])
            draw_centered_text(draw, zk_x + zk_w // 2, zk_y + zk_h - 26, "U+02BC (ʼ)", load_font(14, "mono", bold=True), (140, 175, 210))
        else:
            draw_centered_text(draw, zk_x + zk_w // 2, zk_y + zk_h // 2 + 10, sp["hl"], f_zoom_main, sp["ink"])

        ax = zk_x + zk_w + 28
        ay = zoom_y + 68
        annotations = [
            "Corner Squircle: 8.5pt continuous",
            "Primary Glyph: 24.5pt SF Pro Regular",
            "Secondary Flick: 9.5pt @ 22% → 42%",
            "Hit Target: 100% full-cell rectangle",
            "Toolbar Slot: .contentShape(Rectangle())"
        ]
        for a_i, ann in enumerate(annotations):
            draw.ellipse([ax, ay + a_i * 38 + 6, ax + 8, ay + a_i * 38 + 14], fill=sp["accent"])
            draw.text((ax + 18, ay + a_i * 38), ann, font=f_spec_body, fill=(40, 40, 38))

        spec_y = zoom_y + zoom_h + 26
        for b_i, (b_title, b_val) in enumerate(sp["bullets"]):
            by_row = spec_y + b_i * 82
            draw.rounded_rectangle([cx + 24, by_row, cx + col_w - 24, by_row + 70], radius=14, fill=(250, 249, 246), outline=(228, 225, 218), width=1)
            draw.text((cx + 42, by_row + 12), b_title, font=f_spec_label, fill=(20, 20, 19))
            draw.text((cx + 42, by_row + 38), b_val, font=f_spec_body, fill=(94, 93, 89))

    out_path = os.path.join(OUT_DIR, "Proposal_1_Minimalist_Keyboard_Concepts.png")
    img.save(out_path, "PNG", optimize=True)
    print("Saved", out_path)


def generate_board_2():
    """Proposal_2_HomeView_Editorial_Bento.png"""
    W, H = 2400, 1600
    img = Image.new("RGB", (W, H), (244, 241, 234))
    draw = ImageDraw.Draw(img)

    draw_board_header(
        draw, W,
        "Proposal II — HomeView Editorial Bento, Stacked Cyrillic Rows & WPM Mastery",
        "Refining the companion app: National Gold Taraq Tamğa emblem, stacked bottom Къ/Кʼ rows with iPad [абв] selectors, and 2-tile Statistics.",
        "BOARD 02 / CLAUDE-FRONTEND-DESIGN & CANVAS-DESIGN"
    )

    f_sec_tag = load_font(15, "mono", bold=True)
    f_sec_title = load_font(30, "serif", bold=True)
    f_ui_title = load_font(20, "sans", bold=True)
    f_ui_sub = load_font(15, "sans", bold=False)
    f_mono = load_font(14, "mono", bold=True)
    f_big_num = load_font(44, "mono", bold=True)

    # Left Column
    lx, ly, lw, lh = 72, 216, 1100, 1310
    draw.rounded_rectangle([lx, ly, lx + lw, ly + lh], radius=28, fill=(255, 255, 255), outline=(218, 215, 208), width=2)
    draw.text((lx + 36, ly + 30), "CONCEPT 2A · CLOSED-LOOP EMBLEMS & STACKED BOTTOM CYRILLIC ROWS", font=f_sec_tag, fill=(0, 135, 219))
    draw.text((lx + 36, ly + 60), "Vector Language Emblems & iPad [абв] Keycap Selectors", font=f_sec_title, fill=(20, 20, 19))

    # Card 1: Interface Language Row + 3 Vector Emblems (Taraq Tamğa, Tryzub, Union Jack)
    c1_y = ly + 120
    draw.rounded_rectangle([lx + 36, c1_y, lx + lw - 36, c1_y + 178], radius=22, fill=(248, 246, 242), outline=(224, 221, 214), width=1)
    # Active CRH Sky-Blue badge with National Gold #FFD700 Taraq Tamğa
    draw.rounded_rectangle([lx + 60, c1_y + 24, lx + 120, c1_y + 84], radius=15, fill=(18, 149, 216))
    draw_tamga(draw, lx + 90, c1_y + 54, 40, fill_color=(255, 215, 0))
    draw.text((lx + 138, c1_y + 24), "Мова інтерфейсу (Interface Language)", font=f_ui_title, fill=(20, 20, 19))
    draw.text((lx + 138, c1_y + 54), "National Gold (#FFD700) Taraq Tamğa on Sky-Blue (#1295D8)", font=f_ui_sub, fill=(94, 93, 89))

    # Preview of all 3 closed-loop vector emblems
    emb_y = c1_y + 98
    draw.text((lx + 60, emb_y + 16), "3 Vector Emblems:", font=f_mono, fill=(94, 93, 89))
    # 1. CRH Tamğa
    draw.rounded_rectangle([lx + 225, emb_y, lx + 273, emb_y + 48], radius=12, fill=(18, 149, 216))
    draw_tamga(draw, lx + 249, emb_y + 24, 30, fill_color=(255, 215, 0))
    draw.text((lx + 281, emb_y + 16), "crh (Tamğa)", font=f_mono, fill=(20, 20, 19))
    # 2. UK Tryzub
    draw.rounded_rectangle([lx + 405, emb_y, lx + 453, emb_y + 48], radius=12, fill=(0, 115, 206))
    draw_tryzub_vector(draw, lx + 429, emb_y + 24, 30, (255, 215, 0))
    draw.text((lx + 461, emb_y + 16), "uk (Tryzub)", font=f_mono, fill=(20, 20, 19))
    # 3. EN Union Jack
    draw_union_jack_badge(draw, lx + 585, emb_y, lx + 633, emb_y + 48, radius=12)
    draw.text((lx + 641, emb_y + 16), "en (Union Jack) · Zero Къ/Кʼ re-trigger", font=f_mono, fill=(0, 135, 219))

    seg_x = lx + lw - 365
    seg_y = c1_y + 24
    draw.rounded_rectangle([seg_x, seg_y, seg_x + 306, seg_y + 44], radius=13, fill=(230, 227, 220))
    draw.rounded_rectangle([seg_x + 102, seg_y + 4, seg_x + 204, seg_y + 40], radius=10, fill=(0, 135, 219))
    draw_centered_text(draw, seg_x + 51, seg_y + 22, "QT", f_mono, (60, 60, 58))
    draw_centered_text(draw, seg_x + 153, seg_y + 22, "УК", f_mono, (255, 255, 255))
    draw_centered_text(draw, seg_x + 255, seg_y + 22, "EN", f_mono, (60, 60, 58))

    # Card 2: Top-Level Stacked Bottom Cyrillic & Ukrainian Rows (keyboardSettingsSection)
    c2_y = c1_y + 198
    draw.rounded_rectangle([lx + 36, c2_y, lx + lw - 36, c2_y + 424], radius=22, fill=(248, 246, 242), outline=(224, 221, 214), width=1)
    draw.text((lx + 60, c2_y + 20), "keyboardSettingsSection · Stacked Bottom Rows & iPad [абв] Keycap Selectors", font=f_sec_tag, fill=(89, 86, 214))

    # Primary Keyboard Status Row (where addedBadges belong exclusively)
    p_y = c2_y + 52
    draw.rounded_rectangle([lx + 60, p_y, lx + lw - 60, p_y + 88], radius=16, fill=(255, 255, 255), outline=(224, 221, 214), width=1)
    draw.rounded_rectangle([lx + 78, p_y + 16, lx + 134, p_y + 72], radius=14, fill=(0, 135, 219))
    draw_centered_text(draw, lx + 106, p_y + 44, "Q", load_font(28, "sans", bold=True), (255, 255, 255))
    draw.text((lx + 150, p_y + 18), "Стандартна розкладка (status.primaryKeyboard.row)", font=f_ui_title, fill=(20, 20, 19))
    for c_i, ch in enumerate(["ğ", "ñ", "ş", "ç", "ö", "ü", "â"]):
        bx = lx + 150 + c_i * 42
        draw.rounded_rectangle([bx, p_y + 48, bx + 34, p_y + 74], radius=7, fill=(226, 242, 254), outline=(140, 198, 242), width=1)
        draw_centered_text(draw, bx + 17, p_y + 61, ch, f_mono, (0, 102, 178))
    # Exclusive Added Badges in status.primaryKeyboard.row
    draw.rounded_rectangle([lx + lw - 270, p_y + 26, lx + lw - 172, p_y + 60], radius=10, fill=(225, 246, 232), outline=(82, 196, 116), width=1)
    draw_centered_text(draw, lx + lw - 221, p_y + 43, "Къ Додано", load_font(13, "mono", bold=True), (24, 128, 56))
    draw.rounded_rectangle([lx + lw - 164, p_y + 26, lx + lw - 76, p_y + 60], radius=10, fill=(224, 240, 254), outline=(80, 165, 235), width=1)
    draw_centered_text(draw, lx + lw - 120, p_y + 43, "Кʼ Додано", load_font(13, "mono", bold=True), (0, 105, 180))

    # Stacked Bottom Row 1: Кирилична клавіатура (settings.cyrillic.statusRow)
    r1_y = p_y + 104
    draw.rounded_rectangle([lx + 60, r1_y, lx + lw - 60, r1_y + 116], radius=16, fill=(255, 255, 255), outline=(185, 183, 238), width=2)
    draw.rounded_rectangle([lx + 78, r1_y + 20, lx + 134, r1_y + 76], radius=14, fill=(89, 86, 214))
    draw_centered_text(draw, lx + 106, r1_y + 48, "Къ", load_font(22, "sans", bold=True), (255, 255, 255))
    draw.text((lx + 150, r1_y + 18), "Кирилична клавіатура (Kirill klaviaturası)", font=f_ui_title, fill=(20, 20, 19))
    draw.text((lx + 150, r1_y + 48), "гъ → ğ  ·  къ → q  ·  нъ → ñ  ·  дж → c", font=f_mono, fill=(89, 86, 214))
    draw.text((lx + 150, r1_y + 78), "Always above Українська розкладка across QT / УК / EN (zero row shift)", font=f_ui_sub, fill=(94, 93, 89))
    # Vertically centered [абв] selector (settings.cyrillic.abvSelector) + Toggle ON
    abv1_x = lx + lw - 246
    draw.rounded_rectangle([abv1_x, r1_y + 40, abv1_x + 76, r1_y + 76], radius=9, fill=(226, 228, 235), outline=(190, 194, 205), width=1)
    draw_centered_text(draw, abv1_x + 38, r1_y + 58, "абв", f_mono, (55, 55, 60))
    draw.rounded_rectangle([lx + lw - 152, r1_y + 39, lx + lw - 82, r1_y + 77], radius=19, fill=(52, 199, 89))
    draw.ellipse([lx + lw - 118, r1_y + 43, lx + lw - 86, r1_y + 73], fill=(255, 255, 255))

    # Stacked Bottom Row 2: Українська розкладка (settings.ukrainianCyrillic.statusRow — strictly when language == 'uk')
    r2_y = r1_y + 128
    draw.rounded_rectangle([lx + 60, r2_y, lx + lw - 60, r2_y + 116], radius=16, fill=(255, 255, 255), outline=(95, 175, 235), width=2)
    draw.rounded_rectangle([lx + 78, r2_y + 20, lx + 134, r2_y + 76], radius=14, fill=(0, 135, 219))
    draw.line([(lx + 82, r2_y + 72), (lx + 130, r2_y + 72)], fill=(255, 215, 0), width=4)
    draw_centered_text(draw, lx + 106, r2_y + 46, "Кʼ", load_font(22, "sans", bold=True), (255, 255, 255))
    draw.text((lx + 150, r2_y + 18), "Українська розкладка (ФІВА · strictly language == 'uk')", font=f_ui_title, fill=(20, 20, 19))
    draw.text((lx + 150, r2_y + 48), "ґ → g  ·  г → ğ  ·  кʼ → q  ·  нʼ → ñ", font=f_mono, fill=(0, 105, 180))
    draw.text((lx + 150, r2_y + 78), "iPad [абв] selector active (settings.ukrainianCyrillic.abvSelector)", font=f_ui_sub, fill=(94, 93, 89))
    abv2_x = lx + lw - 246
    draw.rounded_rectangle([abv2_x, r2_y + 40, abv2_x + 76, r2_y + 76], radius=9, fill=(0, 135, 219))
    draw_centered_text(draw, abv2_x + 38, r2_y + 58, "абв", f_mono, (255, 255, 255))
    draw.rounded_rectangle([lx + lw - 152, r2_y + 39, lx + lw - 82, r2_y + 77], radius=19, fill=(52, 199, 89))
    draw.ellipse([lx + lw - 118, r2_y + 43, lx + lw - 86, r2_y + 73], fill=(255, 255, 255))

    # Card 3: Interactive Sandbox Field Modes
    c3_y = c2_y + 444
    draw.rounded_rectangle([lx + 36, c3_y, lx + lw - 36, ly + lh - 36], radius=22, fill=(248, 246, 242), outline=(224, 221, 214), width=1)
    draw.text((lx + 64, c3_y + 22), "Інтерактивна пісочниця: Режими поля (Текст / Пошук / Пошта / URL / 123)", font=f_ui_title, fill=(20, 20, 19))
    modes_list = [("Aa Текст", True), ("Q Пошук", False), ("@ Пошта", False), (".com URL", False), ("123 Числа", False)]
    for m_i, (m_label, is_act) in enumerate(modes_list):
        mx = lx + 64 + m_i * 194
        my = c3_y + 62
        draw.rounded_rectangle([mx, my, mx + 182, my + 42], radius=12, fill=(0, 135, 219) if is_act else (232, 229, 222))
        draw_centered_text(draw, mx + 91, my + 21, m_label, f_mono, (255, 255, 255) if is_act else (60, 60, 58))

    sb_y = c3_y + 120
    draw.rounded_rectangle([lx + 64, sb_y, lx + lw - 64, ly + lh - 56], radius=16, fill=(255, 255, 255), outline=(140, 198, 242), width=2)
    draw.text((lx + 88, sb_y + 18), "«Atalar sözünde altın bar.» (Qırımtatar atalar sözü)", font=load_font(20, "serif", bold=False), fill=(20, 20, 19))
    draw.text((lx + 88, sb_y + 48), "— «У словах предків є золото.» (Кримськотатарське прислів'я)", font=f_ui_sub, fill=(94, 93, 89))
    draw.rounded_rectangle([lx + 88, sb_y + 84, lx + 286, sb_y + 118], radius=17, fill=(226, 242, 254))
    draw_bolt_vector(draw, lx + 108, sb_y + 101, 9, (0, 135, 219))
    draw.text((lx + 124, sb_y + 93), "58 сл/хв (WPM)", font=f_mono, fill=(0, 105, 180))

    # Right Column: Unified 2-Tile Collapsed Statistics Grid + Expanded 6-Tile + WPM Mastery Ring
    rx, ry, rw, rh = 1216, 216, 1112, 1310
    draw.rounded_rectangle([rx, ry, rx + rw, ry + rh], radius=28, fill=(255, 255, 255), outline=(218, 215, 208), width=2)
    draw.text((rx + 36, ry + 30), "CONCEPT 2B · BENTOCOLLAPSEDSTATISTICSGRID & WPM MASTERY", font=f_sec_tag, fill=(148, 74, 234))
    draw.text((rx + 36, ry + 60), "Clean Header + 2-Tile Collapsed Grid & 5-Tier Speed Norms", font=f_sec_title, fill=(20, 20, 19))

    col_box_y = ry + 124
    draw.rounded_rectangle([rx + 36, col_box_y, rx + rw - 36, col_box_y + 280], radius=22, fill=(248, 246, 242), outline=(224, 221, 214), width=1)
    draw.rounded_rectangle([rx + 64, col_box_y + 22, rx + 114, col_box_y + 72], radius=14, fill=(148, 74, 234))
    draw.rectangle([rx + 76, col_box_y + 46, rx + 82, col_box_y + 60], fill=(255, 255, 255))
    draw.rectangle([rx + 86, col_box_y + 34, rx + 92, col_box_y + 60], fill=(255, 255, 255))
    draw.rectangle([rx + 96, col_box_y + 40, rx + 102, col_box_y + 60], fill=(255, 255, 255))

    draw.text((rx + 130, col_box_y + 34), "Статистика", font=f_ui_title, fill=(20, 20, 19))
    draw.text((rx + 290, col_box_y + 38), "Clean single-word header (no legacy 4 pills)", font=f_mono, fill=(148, 74, 234))
    draw.rounded_rectangle([rx + rw - 170, col_box_y + 30, rx + rw - 102, col_box_y + 66], radius=18, fill=(52, 199, 89))
    draw.ellipse([rx + rw - 134, col_box_y + 33, rx + rw - 105, col_box_y + 63], fill=(255, 255, 255))
    draw.text((rx + rw - 82, col_box_y + 32), "›", font=load_font(28, "sans", bold=True), fill=(140, 140, 135))

    t_y = col_box_y + 88
    t_w = (rw - 148) // 2
    t_h = 168
    draw.rounded_rectangle([rx + 64, t_y, rx + 64 + t_w, t_y + t_h], radius=18, fill=(255, 255, 255), outline=(140, 198, 242), width=2)
    draw.text((rx + 88, t_y + 20), "Написано слів (stats.wordsTile)", font=f_ui_sub, fill=(94, 93, 89))
    draw.text((rx + 88, t_y + 54), "1 284", font=f_big_num, fill=(20, 20, 19))
    draw.text((rx + 88, t_y + 122), "Унікальних: 312 (user_unigrams)", font=f_mono, fill=(0, 135, 219))
    sp_pts = [(rx + 320, t_y + 96), (rx + 355, t_y + 82), (rx + 390, t_y + 88), (rx + 425, t_y + 66), (rx + 460, t_y + 72), (rx + 500, t_y + 48)]
    draw.line(sp_pts, fill=(0, 135, 219), width=4)

    t2_x = rx + 64 + t_w + 20
    draw.rounded_rectangle([t2_x, t_y, t2_x + t_w, t_y + t_h], radius=18, fill=(255, 255, 255), outline=(245, 160, 168), width=2)
    draw.text((t2_x + 24, t_y + 20), "Швидкість друку (stats.speedTile)", font=f_ui_sub, fill=(94, 93, 89))
    draw.text((t2_x + 24, t_y + 54), "58 сл/хв", font=f_big_num, fill=(20, 20, 19))
    draw.text((t2_x + 24, t_y + 122), "WPM / сл/хв only (zero CPM clutter)", font=f_mono, fill=(242, 82, 96))
    gx_c, gy_c = t2_x + t_w - 74, t_y + 84
    draw.arc([gx_c - 44, gy_c - 44, gx_c + 44, gy_c + 44], start=0, end=360, fill=(230, 227, 220), width=9)
    draw.arc([gx_c - 44, gy_c - 44, gx_c + 44, gy_c + 44], start=-90, end=195, fill=(242, 82, 96), width=9)
    draw_centered_text(draw, gx_c, gy_c, "4/5", f_mono, (242, 82, 96))

    exp_y = col_box_y + 304
    draw.rounded_rectangle([rx + 36, exp_y, rx + rw - 36, ry + rh - 36], radius=22, fill=(248, 246, 242), outline=(224, 221, 214), width=1)
    draw.text((rx + 64, exp_y + 24), "Розгорнута Статистика: 6 Bento-плиток, Словник (is_custom = 1) та 5 рівнів швидкості", font=f_ui_title, fill=(20, 20, 19))

    extra_tiles = [
        ("Набрано вручну", "842", "Клавішами та свайпом", (0, 135, 219)),
        ("Підказками", "442 · ×1.4", "Зекономлено 1 980 зн.", (52, 199, 89)),
        ("Активний час", "46 хв", "Чистий час набору", (52, 199, 89)),
        ("Особистий словник", "28 вивч.", "WHERE is_custom = 1 (Slot 0)", (245, 148, 10))
    ]
    for e_i, (e_title, e_val, e_sub, e_col) in enumerate(extra_tiles):
        col_idx = e_i % 2
        row_idx = e_i // 2
        ex = rx + 64 + col_idx * (t_w + 20)
        ey = exp_y + 72 + row_idx * 150
        draw.rounded_rectangle([ex, ey, ex + t_w, ey + 134], radius=16, fill=(255, 255, 255), outline=(224, 221, 214), width=1)
        draw.text((ex + 22, ey + 16), e_title, font=f_ui_sub, fill=(94, 93, 89))
        draw.text((ex + 22, ey + 44), e_val, font=load_font(34, "mono", bold=True), fill=e_col)
        draw.text((ex + 22, ey + 94), e_sub, font=f_mono, fill=(94, 93, 89))

    tier_y = exp_y + 390
    draw.text((rx + 64, tier_y), "ЕМПІРИЧНІ РІВНІ ШВИДКОСТІ ДРУКУ ЛЮДИНИ (5 PROGRESSIVE WPM TIERS) + ВІДОМІ ВИСЛОВИ", font=f_sec_tag, fill=(20, 20, 19))
    tiers = [
        ("Tier 1", "15 WPM", "Початковий", True),
        ("Tier 2", "25 WPM", "Впевнений", True),
        ("Tier 3", "40 WPM", "Швидкий", True),
        ("Tier 4", "55 WPM", "Майстерний", True),
        ("Tier 5", "75 WPM", "Блискавичний (Max)", False)
    ]
    tier_w = (rw - 128 - 4 * 14) // 5
    for t_idx, (t_lvl, t_wpm, t_name, reached) in enumerate(tiers):
        tx = rx + 64 + t_idx * (tier_w + 14)
        ty = tier_y + 36
        bg_c = (0, 135, 219) if reached else (230, 227, 220)
        fg_c = (255, 255, 255) if reached else (60, 60, 58)
        draw.rounded_rectangle([tx, ty, tx + tier_w, ty + 110], radius=14, fill=bg_c)
        draw.text((tx + 16, ty + 14), t_lvl, font=f_mono, fill=fg_c)
        draw.text((tx + 16, ty + 42), t_wpm, font=load_font(22, "mono", bold=True), fill=fg_c)
        draw.text((tx + 16, ty + 76), t_name, font=load_font(15, "sans", bold=False), fill=fg_c)

    draw.rounded_rectangle([rx + 64, tier_y + 166, rx + rw - 64, tier_y + 236], radius=14, fill=(255, 248, 230), outline=(228, 190, 95), width=1)
    draw.text((rx + 88, tier_y + 180), "Досягнення «Відомі вислови» (phrasesInserted): вставка щоденної мудрості ніколи не", font=f_ui_sub, fill=(60, 48, 20))
    draw.text((rx + 88, tier_y + 204), "завищує лічильник слів користувача, але відкриває 5 рівнів культурних досягнень.", font=f_ui_sub, fill=(60, 48, 20))

    out_path = os.path.join(OUT_DIR, "Proposal_2_HomeView_Editorial_Bento.png")
    img.save(out_path, "PNG", optimize=True)
    print("Saved", out_path)


def generate_board_3():
    """Proposal_3_MicroAnimations_And_Comet_Spec.png"""
    W, H = 2400, 1600
    img = Image.new("RGB", (W, H), (14, 20, 30))
    draw = ImageDraw.Draw(img)

    f_eyebrow = load_font(18, "mono", bold=True)
    f_title = load_font(44, "serif", bold=True)
    f_sub = load_font(21, "sans", bold=False)
    f_sec = load_font(26, "serif", bold=True)
    f_mono = load_font(15, "mono", bold=True)
    f_body = load_font(16, "sans", bold=False)

    draw.text((72, 48), "BOARD 03 / CLAUDE-ALGORITHMIC-ART & MOTION CHOREOGRAPHY SPECIFICATION", font=f_eyebrow, fill=(56, 189, 248))
    draw.text((72, 78), "Proposal III — Bio-Responsive Tamğa Breathing & Swipe v2 Comet Physics", font=f_title, fill=(240, 246, 252))
    draw.text((72, 136), "Phase-continuous CoreAnimation math (15..75 WPM → 1.0x..2.9x), fold-free Bezier+Chaikin comet, and Δθ ≥ 22° anchor glow.", font=f_sub, fill=(148, 163, 184))
    draw.line([(72, 182), (W - 72, 182)], fill=(36, 58, 86), width=2)

    # Panel 3A (Top Left) — Dedicated Left Label Gutter so sine wave never overlaps text!
    p1_x, p1_y, p1_w, p1_h = 72, 214, 1100, 640
    draw.rounded_rectangle([p1_x, p1_y, p1_x + p1_w, p1_y + p1_h], radius=24, fill=(20, 30, 46), outline=(42, 72, 108), width=2)
    draw.text((p1_x + 32, p1_y + 24), "3A · TARAQ TAMĞA BIO-CADENCE WAVEFORM & WORD-COMMIT PULSE", font=f_mono, fill=(255, 215, 0))
    draw.text((p1_x + 32, p1_y + 52), "Phase-Continuous Frequency Modulation (Zero Phase Jumps)", font=f_sec, fill=(240, 246, 252))

    # Left gutter (176px) for y-axis labels, plot area starts at p1_x + 212
    gx0, gy0, gw, gh = p1_x + 212, p1_y + 116, p1_w - 252, 310
    draw.rectangle([gx0, gy0, gx0 + gw, gy0 + gh], fill=(12, 18, 28), outline=(38, 62, 92), width=1)
    f_axis = load_font(13, "mono", bold=True)
    for frac, label in [(0.15, "0.52 max (1.045x)"), (0.50, "0.38 mid (1.010x)"), (0.85, "0.25 min (0.975x)")]:
        yy = int(gy0 + frac * gh)
        draw.line([(gx0, yy), (gx0 + gw, yy)], fill=(28, 42, 62), width=1)
        draw.text((p1_x + 34, yy - 8), label, font=f_axis, fill=(168, 185, 208))

    wave_pts = []
    env_pts = []
    phase = 0.0
    for ix in range(gw):
        t_norm = ix / float(gw)
        if t_norm < 0.22:
            exertion = 0.0
        elif t_norm < 0.58:
            exertion = min(1.0, (t_norm - 0.22) / 0.25)
        elif t_norm < 0.85:
            exertion = max(0.0, math.exp(-(t_norm - 0.58) * 9.0))
        else:
            exertion = 0.0

        speed = 1.0 + exertion * 1.9
        if t_norm < 0.88:
            phase += 0.035 * speed
            val = 0.5 - 0.5 * math.cos(phase)
        else:
            val = max(0.0, (0.5 - 0.5 * math.cos(phase)) * math.exp(-(t_norm - 0.88) * 25.0))

        wy = gy0 + gh * (0.85 - val * 0.70)
        ey = gy0 + gh * (0.85 - exertion * 0.70)
        wave_pts.append((gx0 + ix, wy))
        env_pts.append((gx0 + ix, ey))

    draw.line(env_pts, fill=(212, 175, 35), width=3)
    draw.line(wave_pts, fill=(56, 189, 248), width=4)

    zones = [
        (0.01, "1. Rest (1.0x)"),
        (0.24, "2. 15→75 WPM (2.9x)"),
        (0.54, "3. Cooldown (×0.90)"),
        (0.80, "4. 60s Idle Settle")
    ]
    for z_frac, z_text in zones:
        draw.text((int(gx0 + z_frac * gw), gy0 + gh + 14), z_text, font=f_axis, fill=(240, 246, 252))

    draw.rounded_rectangle([p1_x + 36, p1_y + 485, p1_x + p1_w - 36, p1_y + p1_h - 24], radius=16, fill=(14, 22, 34), outline=(145, 122, 24), width=1)
    draw_tamga(draw, p1_x + 110, p1_y + 550, 64, fill_color=(255, 215, 0))
    draw.rounded_rectangle([p1_x + 66, p1_y + 520, p1_x + 154, p1_y + 580], radius=14, outline=(195, 165, 28), width=2)
    draw.rounded_rectangle([p1_x + 54, p1_y + 510, p1_x + 166, p1_y + 590], radius=18, outline=(42, 125, 175), width=2)
    draw.text((p1_x + 194, p1_y + 506), "NEW PROPOSAL: Word-Commit Golden Harmonic Ripple (BreathingTamgaUIView)", font=f_mono, fill=(255, 215, 0))
    draw.text((p1_x + 194, p1_y + 536), "When committing an autocorrect pill or finishing a Swipe v2 word, the spacebar", font=f_body, fill=(203, 213, 225))
    draw.text((p1_x + 194, p1_y + 562), "Taraq Tamğa emits a single 0.42s golden contour wave (scale 1.0 → 1.45, alpha 0.45 → 0).", font=f_body, fill=(203, 213, 225))

    # Panel 3B (Top Right) — True Filleted Bezier + Chaikin Comet Passing Through Every Anchor Key
    p2_x, p2_y, p2_w, p2_h = 1216, 214, 1112, 640
    draw.rounded_rectangle([p2_x, p2_y, p2_x + p2_w, p2_y + p2_h], radius=24, fill=(20, 30, 46), outline=(42, 72, 108), width=2)
    draw.text((p2_x + 32, p2_y + 24), "3B · QIRIMKEY SWIPE V2 COMET RIBBON & MAGNETIC ANCHOR KEY GLOW", font=f_mono, fill=(56, 189, 248))
    draw.text((p2_x + 32, p2_y + 52), "Quadratic Bezier Filleting + Chaikin Spine & Δθ ≥ 22° Anchor Illumination", font=f_sec, fill=(240, 246, 252))

    kb_sx, kb_sy, kb_sw, kb_sh = p2_x + 40, p2_y + 115, p2_w - 80, 340
    draw.rounded_rectangle([kb_sx, kb_sy, kb_sx + kb_sw, kb_sy + kb_sh], radius=20, fill=(11, 17, 28), outline=(36, 58, 86), width=1)

    rows_latn = [
        ["q","w","e","r","t","y","u","i","o","p","ğ","ü"],
        ["a","s","d","f","g","h","j","k","l","ş","ı","â"],
        ["SHIFT","z","x","c","v","b","n","m","ö","ç","ñ","DEL"]
    ]
    cw = (kb_sw - 40) / 12.0
    rh = 88
    key_centers = {}
    anchor_keys = {"s", "e", "l", "a", "m"}

    for r_i, row in enumerate(rows_latn):
        for c_i, ch in enumerate(row):
            kx = int(kb_sx + 20 + c_i * cw)
            ky = int(kb_sy + 24 + r_i * (rh + 12))
            kw = int(cw * 0.9)
            is_anchor = ch in anchor_keys
            key_centers[ch] = (kx + kw // 2, ky + rh // 2)
            out_col = (255, 215, 0) if is_anchor else (45, 62, 84)
            fill_col = (36, 56, 84) if is_anchor else (22, 32, 48)
            draw.rounded_rectangle([kx, ky, kx + kw, ky + rh], radius=12, fill=fill_col, outline=out_col, width=3 if is_anchor else 1)
            if ch == "SHIFT":
                draw_shift_vector(draw, kx + kw // 2, ky + rh // 2, 10, (180, 195, 210))
            elif ch == "DEL":
                draw_backspace_vector(draw, kx + kw // 2, ky + rh // 2, 10, (180, 195, 210))
            else:
                # Place letter near top-left of anchor keys so the anchor dot & comet spine are crystal clear
                draw_centered_text(
                    draw,
                    kx + kw // 2,
                    (ky + 22) if is_anchor else (ky + rh // 2),
                    ch,
                    load_font(22 if is_anchor else 24, "sans", bold=is_anchor),
                    (255, 215, 0) if is_anchor else (180, 195, 210)
                )

    path_keys = ["s", "e", "l", "a", "m"]
    # Offset y slightly for 'l' and 'a' so the outgoing and returning passes over Row 1 are both visibly separated
    ctrl_pts = [
        (key_centers["s"][0], key_centers["s"][1] - 4),
        (key_centers["e"][0], key_centers["e"][1] + 6),
        (key_centers["l"][0], key_centers["l"][1] - 4),
        (key_centers["a"][0], key_centers["a"][1] + 14),
        (key_centers["m"][0], key_centers["m"][1] + 6),
    ]
    pts = compute_filleted_chaikin_spine(ctrl_pts, max_fillet_span=24.0, samples_per_seg=14)

    # Render smooth tapered comet ribbon without bumpy seams
    for i in range(1, len(pts)):
        prog = i / float(len(pts) - 1)
        r = max(1.8, 10.5 * (prog ** 0.85))
        p0, p1 = pts[i - 1], pts[i]
        c_col = (
            int(24 + (56 - 24) * prog),
            int(86 + (189 - 86) * prog),
            int(148 + (248 - 148) * prog),
        )
        draw.line([p0, p1], fill=c_col, width=max(2, int(r * 2)))
        draw.ellipse([p1[0] - r, p1[1] - r, p1[0] + r, p1[1] + r], fill=c_col)

    # Draw golden inflection nodes right at the control points on each anchor key
    for idx_pt, (cx_k, cy_k) in enumerate(ctrl_pts):
        r_dot = 9 if idx_pt == len(ctrl_pts) - 1 else 7
        draw.ellipse([cx_k - r_dot, cy_k - r_dot, cx_k + r_dot, cy_k + r_dot], fill=(255, 215, 0), outline=(14, 20, 30), width=2)

    draw.rounded_rectangle([p2_x + 40, p2_y + 475, p2_x + p2_w - 40, p2_y + p2_h - 24], radius=16, fill=(14, 22, 34), outline=(42, 95, 140), width=1)
    draw.text((p2_x + 64, p2_y + 494), "SWIPE V2 ENGINE TELEMETRY & VISUAL FEEDBACK PROPOSAL:", font=f_mono, fill=(56, 189, 248))
    draw.text((p2_x + 64, p2_y + 524), "• Turning-angle anchors (Δθ ≥ 22°: s, e, l, a, m) illuminate keycap rims in gold (#FFD700).", font=f_body, fill=(203, 213, 225))
    draw.text((p2_x + 64, p2_y + 552), "• Collinear transit keys (d, f, g, h, j, k) stay unlit; Row-0 right-flank transit keys stripped before/after ъ/ʼ.", font=f_body, fill=(203, 213, 225))
    draw.text((p2_x + 64, p2_y + 580), "• Fold-free capsule union silhouette (maxCometArcLength = 340pt, tailDuration = 0.36s, <0.35ms at 120Hz).", font=f_body, fill=(203, 213, 225))

    # Bottom Full-Width Panel 3C
    p3_x, p3_y, p3_w, p3_h = 72, 884, 2256, 646
    draw.rounded_rectangle([p3_x, p3_y, p3_x + p3_w, p3_y + p3_h], radius=24, fill=(20, 30, 46), outline=(42, 72, 108), width=2)
    draw.text((p3_x + 36, p3_y + 26), "3C · TOP TOOLBAR STRICT MUTUAL EXCLUSION & ORTHOGRAPHY MICRO-TRANSITIONS (ДЕСС № 1722/04-03/25)", font=f_mono, fill=(56, 189, 248))
    draw.text((p3_x + 36, p3_y + 56), "Zero-Overlap State Machine & Spring Choreography", font=f_sec, fill=(240, 246, 252))

    cards_3c = [
        (
            "STATE 1 · STANDARD TEXT (EMPTY)",
            "Daily Wisdom Banner ONLY (Color.clear)",
            "Atalar sözünde altın bar.",
            [
                "• Shown ONLY in standard Text fields (.default)",
                "• Unplattered (no background pill) in 16pt/17pt",
                "• Sparkles icon cross-dissolves next wisdom phrase",
                "• Never shown in Search (.webSearch) or URL/Email"
            ],
            (255, 215, 0)
        ),
        (
            "STATE 2 · ACTIVE TYPING OR SEARCH",
            "3-Slot Autocomplete Bar ONLY",
            "“yaptıñ mı”   |   [ yaptıñmı ]   |   yaptıñız",
            [
                "• Shown for both Text and Search fields",
                "• Stadium pill (14pt) strictly on isAutocorrect",
                "• § 67 particle merge: 'yaptıñ mı' → 'yaptıñmı'",
                "• § 63 compound hyphens: 'alış-veriş', 'gece-kündüz'"
            ],
            (56, 189, 248)
        ),
        (
            "STATE 3 · SPACE COMMIT & BACKSPACE UNDO",
            "Immediate Backspace Revert & Toponym Casing",
            "Space → 'Aqmescit '   |   Tap Backspace → Revert",
            [
                "• Autocorrect commits strictly on .space (never quotes)",
                "• Single tap Backspace immediately restores original token",
                "• Single tap Backspace after Swipe v2 deletes swiped word",
                "• Auto-capitalizes Qırım, Aqmescit, Bağçasaray, Çonğar"
            ],
            (52, 199, 89)
        )
    ]

    c3_w = (p3_w - 72 - 48) // 3
    for idx, (st_tag, st_title, st_bar, st_bullets, st_col) in enumerate(cards_3c):
        cx = p3_x + 36 + idx * (c3_w + 24)
        cy = p3_y + 114
        draw.rounded_rectangle([cx, cy, cx + c3_w, cy + 496], radius=20, fill=(12, 19, 30), outline=st_col, width=2)
        draw.text((cx + 28, cy + 24), st_tag, font=f_mono, fill=st_col)
        draw.text((cx + 28, cy + 54), st_title, font=load_font(23, "sans", bold=True), fill=(240, 246, 252))

        draw.rounded_rectangle([cx + 28, cy + 104, cx + c3_w - 28, cy + 168], radius=14, fill=(24, 36, 54), outline=(48, 68, 96), width=1)
        if idx == 0:
            bar_font = load_font(18, "sans", bold=False)
            tw = int(draw.textlength(st_bar, font=bar_font))
            total_w = 22 + 8 + tw + 8 + 16 + 10 + 18
            sx0 = cx + (c3_w - total_w) // 2
            sy0 = cy + 136
            draw_tamga(draw, sx0 + 11, sy0, 22, fill_color=st_col)
            draw.text((sx0 + 30, sy0 - 10), st_bar, font=bar_font, fill=st_col)
            ar_x = sx0 + 30 + tw + 16
            draw_insert_arrow_circle(draw, ar_x, sy0, 8, st_col, (24, 36, 54))
            draw_sparkles_vector(draw, ar_x + 22, sy0, 9, st_col)
        else:
            draw_centered_text(draw, cx + c3_w // 2, cy + 136, st_bar, load_font(18, "mono", bold=True), st_col)

        for b_i, line in enumerate(st_bullets):
            draw.text((cx + 28, cy + 204 + b_i * 58), line, font=f_body, fill=(203, 213, 225))

    out_path = os.path.join(OUT_DIR, "Proposal_3_MicroAnimations_And_Comet_Spec.png")
    img.save(out_path, "PNG", optimize=True)
    print("Saved", out_path)


def generate_board_4():
    """Proposal_4_ThemeFactory_Palettes.png"""
    W, H = 2400, 1600
    img = Image.new("RGB", (W, H), (244, 241, 234))
    draw = ImageDraw.Draw(img)

    draw_board_header(
        draw, W,
        "Proposal IV — Curated QırımKey Cultural & Minimalist Theme Factory",
        "Six cohesive color & material systems grounded in Crimean heritage and optical ergonomics (WCAG AA/AAA verified).",
        "BOARD 04 / CLAUDE-THEME-FACTORY COLLECTION"
    )

    themes = [
        {
            "num": "THEME 01 · SYSTEM DEFAULT",
            "name": "Native iOS Liquid Glass",
            "sub": "Pure optical translucency & Crimean Sky-Blue (#0087DB)",
            "kb_bg": (214, 218, 226),
            "key_bg": (255, 255, 255),
            "sys_bg": (182, 187, 196),
            "ink": (18, 18, 20),
            "accent": (0, 135, 219),
            "swatches": [("#D6DAE2", "Surface"), ("#FFFFFF", "Keycap"), ("#0087DB", "Brand Blue"), ("#FFD700", "Tamğa Gold")],
            "mode": "whisper",
            "script": "latn"
        },
        {
            "num": "THEME 02 · CULTURAL HERITAGE",
            "name": "Bağçasaray Limestone & Gold",
            "sub": "Warm Hansaray travertine stone, walnut ink & filigree gold",
            "kb_bg": (234, 224, 208),
            "key_bg": (251, 248, 243),
            "sys_bg": (218, 207, 190),
            "ink": (35, 31, 27),
            "accent": (200, 138, 20),
            "swatches": [("#EAE0D0", "Limestone"), ("#FBF8F3", "Travertine"), ("#C88A14", "Filigree Gold"), ("#231F1B", "Walnut Ink")],
            "mode": "whisper",
            "script": "latn"
        },
        {
            "num": "THEME 03 · NOCTURNAL BIOLUMINESCENCE",
            "name": "Qara Deñiz Midnight",
            "sub": "Deep Black Sea abyssal navy with bioluminescent cyan & starlight",
            "kb_bg": (11, 19, 30),
            "key_bg": (24, 38, 58),
            "sys_bg": (16, 26, 40),
            "ink": (237, 244, 252),
            "accent": (18, 149, 216),
            "swatches": [("#0B131E", "Abyssal"), ("#18263A", "Marine Key"), ("#1295D8", "Cyan Glow"), ("#FFD700", "Starlight")],
            "mode": "whisper",
            "script": "uk"
        },
        {
            "num": "THEME 04 · EDITORIAL E-INK",
            "name": "Aqmescit Minimalist Paper",
            "sub": "Archival rag paper paired with Borderless Typographic Air mode",
            "kb_bg": (243, 241, 236),
            "key_bg": (255, 255, 255),
            "sys_bg": (226, 223, 215),
            "ink": (20, 20, 19),
            "accent": (29, 78, 216),
            "swatches": [("#F3F1EC", "Rag Paper"), ("#E2DFD7", "Stone Wash"), ("#1D4ED8", "Cobalt Ink"), ("#141413", "Carbon")],
            "mode": "borderless",
            "script": "latn"
        },
        {
            "num": "THEME 05 · ORGANIC HORIZON",
            "name": "Steppe Dawn (Çöl Tañı)",
            "sub": "Crimean steppe wormwood sage, morning mist & dawn apricot",
            "kb_bg": (232, 224, 216),
            "key_bg": (255, 253, 251),
            "sys_bg": (216, 206, 196),
            "ink": (38, 35, 34),
            "accent": (74, 124, 111),
            "swatches": [("#E8E0D8", "Steppe Mist"), ("#FFFDFB", "Warm Silk"), ("#4A7C6F", "Sage Teal"), ("#E07A5F", "Apricot")],
            "mode": "whisper",
            "script": "latn"
        },
        {
            "num": "THEME 06 · OLED MONOLITH",
            "name": "Chufut-Kale Obsidian",
            "sub": "High-contrast carved basalt keys with pure national gold (#FFD700)",
            "kb_bg": (8, 8, 10),
            "key_bg": (22, 22, 27),
            "sys_bg": (14, 14, 18),
            "ink": (255, 255, 255),
            "accent": (212, 155, 26),
            "swatches": [("#08080A", "OLED Void"), ("#16161B", "Basalt Key"), ("#FFD700", "Pure Gold"), ("#FFFFFF", "AAA White")],
            "mode": "whisper",
            "script": "uk"
        }
    ]

    f_tag = load_font(15, "mono", bold=True)
    f_title = load_font(26, "serif", bold=True)
    f_sub = load_font(15, "sans", bold=False)
    f_hex = load_font(14, "mono", bold=True)

    card_w = 720
    card_h = 626
    gap_x = 48
    gap_y = 36
    start_x = 72
    start_y = 212

    for idx, th in enumerate(themes):
        col = idx % 3
        row = idx // 3
        cx = start_x + col * (card_w + gap_x)
        cy = start_y + row * (card_h + gap_y)

        draw.rounded_rectangle([cx, cy, cx + card_w, cy + card_h], radius=26, fill=(255, 255, 255), outline=(218, 215, 208), width=2)
        draw.text((cx + 28, cy + 22), th["num"], font=f_tag, fill=th["accent"])
        draw.text((cx + 28, cy + 48), th["name"], font=f_title, fill=(20, 20, 19))
        draw.text((cx + 28, cy + 84), th["sub"], font=f_sub, fill=(94, 93, 89))

        sw_y = cy + 118
        sw_w = (card_w - 56 - 3 * 12) // 4
        for s_i, (hex_code, s_label) in enumerate(th["swatches"]):
            sx = cx + 28 + s_i * (sw_w + 12)
            rgb = hex_to_rgb(hex_code)
            draw.rounded_rectangle([sx, sw_y, sx + sw_w, sw_y + 54], radius=12, fill=rgb, outline=(205, 202, 195), width=1)
            lum = 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]
            txt_col = (20, 20, 19) if lum > 145 else (255, 255, 255)
            draw.text((sx + 12, sw_y + 10), hex_code, font=f_hex, fill=txt_col)
            draw.text((sx + 12, sw_y + 30), s_label, font=load_font(12, "sans", bold=False), fill=txt_col)

        render_mini_keyboard(
            draw, cx + 24, cy + 190, card_w - 48, 412,
            mode=th["mode"], script=th["script"],
            kb_bg=th["kb_bg"], key_bg=th["key_bg"], sys_bg=th["sys_bg"],
            ink=th["ink"], accent=th["accent"],
            show_wisdom=(idx % 2 == 0),
            highlight_key="ğ" if th["script"] == "latn" else "ї"
        )

    out_path = os.path.join(OUT_DIR, "Proposal_4_ThemeFactory_Palettes.png")
    img.save(out_path, "PNG", optimize=True)
    print("Saved", out_path)


def generate_preview_interactive_1():
    """Preview_Interactive_1_Tamga_Harmonic_Flow.png (1200x1200 generative plate)"""
    W, H = 1200, 1200
    img = Image.new("RGB", (W, H), (11, 19, 30))
    draw = ImageDraw.Draw(img)

    rng = random.Random(4650)
    scale = 540.0 / 9.0
    ox = W * 0.5 - 4.5 * scale
    oy = H * 0.5 - 2.5 * scale
    verts = [(ox + gx * scale, oy + gy * scale) for (gx, gy) in TAMGA_VERTICES]

    # Concentric word-commit harmonic contour waves
    for r_i in range(1, 7):
        s_f = 1.0 + r_i * 0.11
        sw = 540.0 * s_f
        sh = sw * (5.0 / 9.0)
        rx = W * 0.5 - sw * 0.5
        ry = H * 0.5 - sh * 0.5
        r_pts = [(rx + gx * (sw / 9.0), ry + gy * (sh / 5.0)) for (gx, gy) in TAMGA_VERTICES]
        col = (255, 215, 0) if r_i % 2 == 1 else (18, 149, 216)
        draw.polygon(r_pts, outline=col, width=1)

    # Streamlines around the 20 vertices
    for _ in range(950):
        px = rng.uniform(40, W - 40)
        py = rng.uniform(40, H - 100)
        use_gold = rng.random() < 0.44
        col = (255, 215, 0) if use_gold else (18, 149, 216)
        pts = [(px, py)]
        for _step in range(28):
            # Nearest Tamğa vertex
            best_d = 1e9
            nvx, nvy = W * 0.5, H * 0.5
            for (vx, vy) in verts:
                d = math.hypot(px - vx, py - vy)
                if d < best_d:
                    best_d = d
                    nvx, nvy = vx, vy
            ang = math.atan2(nvy - py, nvx - px) + math.pi * 0.42
            curl = math.sin(px * 0.009 + py * 0.007) * 1.8
            a = ang * 0.55 + curl * 0.45
            px += math.cos(a) * 6.5
            py += math.sin(a) * 6.5
            if 36 <= px <= W - 36 and 36 <= py <= H - 96:
                pts.append((px, py))
            else:
                break
        if len(pts) > 2:
            draw.line(pts, fill=col, width=2 if use_gold else 1)

    draw_tamga(draw, W // 2, H // 2, 540, fill_color=(255, 215, 0), outline_color=(18, 149, 216), outline_width=3)
    draw.line([(54, H - 64), (W - 54, H - 64)], fill=(255, 255, 255), width=1)
    f_meta = load_font(16, "mono", bold=True)
    draw.text((54, H - 44), "ALGORITHMIC PLATE 01  |  9x5 TARAQ TAMGA HARMONIC ATTRACTOR  |  SEED 4650 (46.5°N)", font=f_meta, fill=(237, 244, 252))
    draw.text((W - 368, H - 44), "WPM: 55  |  BREATH: 2.39x  |  P5.JS", font=f_meta, fill=(255, 215, 0))

    out_path = os.path.join(OUT_DIR, "Preview_Interactive_1_Tamga_Harmonic_Flow.png")
    img.save(out_path, "PNG", optimize=True)
    print("Saved", out_path)


if __name__ == "__main__":
    generate_board_1()
    generate_board_2()
    generate_board_3()
    generate_board_4()
    generate_preview_interactive_1()
