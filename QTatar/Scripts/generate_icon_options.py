#!/usr/bin/env python3
"""Six QırımKey app-icon options (flat, minimal change from the current icon). Output: creative_assets/icon_options/option_<letter>.png (1024, opaque)
plus a preview sheet with the iOS rounded mask. Usage: python3 QTatar/Scripts/generate_icon_options.py"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CA = os.path.join(ROOT, "AppStoreMetadata", "Media_Designed", "creative_assets")
PREV = os.path.join(CA, "app_icon_previous_1024.png")
OUTD = os.path.join(CA, "icon_options")
S, SS = 1024, 3
TAMGA = [(1, 0), (8, 0), (8, 3), (9, 3), (9, 4), (7, 4), (7, 1), (5, 1), (5, 4), (6, 4), (6, 5), (3, 5), (3, 4), (4, 4),
         (4, 1), (2, 1), (2, 4), (0, 4), (0, 3), (1, 3)]
FONT = "/System/Library/Fonts/SFNS.ttf"


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(c_tl, c_br, c_tr=None, c_bl=None):
    c_tr = c_tr or lerp(c_tl, c_br, 0.5)
    c_bl = c_bl or lerp(c_tl, c_br, 0.5)
    im = Image.new("RGB", (S, S)); px = im.load()
    for y in range(S):
        for x in range(S):
            u, v = x / (S - 1), y / (S - 1)
            px[x, y] = lerp(lerp(c_tl, c_tr, u), lerp(c_bl, c_br, u), v)
    return im


def old_gradient():
    o = Image.open(PREV).convert("RGB")
    return gradient(o.getpixel((4, 4)), o.getpixel((S - 5, S - 5)), o.getpixel((S - 5, 4)), o.getpixel((4, S - 5)))


def poly(im, pts, fill):
    m = Image.new("L", (S * SS, S * SS), 0)
    ImageDraw.Draw(m).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    im.paste(fill, (0, 0), m.resize((S, S), Image.LANCZOS))


def rrect(im, box, r, fill, outline=None, width=0):
    m = Image.new("L", (S * SS, S * SS), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([v * SS for v in box], radius=r * SS, fill=255)
    im.paste(fill, (0, 0), m.resize((S, S), Image.LANCZOS))
    if outline:
        m2 = Image.new("L", (S * SS, S * SS), 0)
        ImageDraw.Draw(m2).rounded_rectangle([v * SS for v in box], radius=r * SS, outline=255, width=width * SS)
        im.paste(outline, (0, 0), m2.resize((S, S), Image.LANCZOS))


def tamga(im, cx, cy, width, fill):
    u = width / 9.0
    poly(im, [(cx - 4.5 * u + gx * u, cy - 2.5 * u + gy * u) for gx, gy in TAMGA], fill)


def shadow(im, box, r, dy, blur, alpha):
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    m = Image.new("L", (S * 2, S * 2), 0)
    ImageDraw.Draw(m).rounded_rectangle([v * 2 for v in box], radius=r * 2, fill=alpha)
    m = m.resize((S, S), Image.LANCZOS)
    sh.paste((30, 30, 70, 255), (0, dy), m)
    base = im.convert("RGBA"); base.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)))
    im.paste(base.convert("RGB"))


def opt_a():  # flat key
    im = old_gradient()
    box = (150, 150, 874, 874)
    shadow(im, box, 150, 16, 22, 70)
    rrect(im, box, 150, (255, 255, 255), outline=(206, 209, 228), width=6)
    tamga(im, 512, 512, 470, (10, 10, 12))
    return im


def opt_b():  # sky blue + gold
    im = gradient((24, 160, 226), (9, 106, 172))
    tamga(im, 512, 500, 640, (255, 215, 0))
    return im


def opt_c():  # dark + gold cursor bar
    im = gradient((15, 26, 38), (24, 44, 64))
    tamga(im, 512, 470, 610, (255, 255, 255))
    rrect(im, (400, 700, 624, 740), 20, (255, 215, 0))
    return im


def opt_d():  # tamga above a space bar
    im = old_gradient()
    tamga(im, 512, 450, 560, (10, 10, 12))
    rrect(im, (252, 700, 772, 790), 45, (255, 255, 255), outline=(206, 209, 228), width=5)
    return im


def opt_e():  # swipe trail
    im = old_gradient()
    tamga(im, 512, 440, 560, (10, 10, 12))
    pts = []
    import math
    for i in range(0, 101):
        t = i / 100
        x = 200 + 624 * t
        y = 760 - 70 * math.sin(t * math.pi * 2.2)
        pts.append((x, y))
    for i in range(len(pts) - 1):
        t = i / len(pts)
        col = lerp((255, 190, 0), (18, 149, 216), t)
        for k in range(8):
            a = (pts[i][0] + (pts[i + 1][0] - pts[i][0]) * k / 8, pts[i][1] + (pts[i + 1][1] - pts[i][1]) * k / 8)
            r = 24 * (0.45 + 0.55 * t)
            m = Image.new("L", (S, S), 0)
            ImageDraw.Draw(m).ellipse([a[0] - r, a[1] - r, a[0] + r, a[1] + r], fill=255)
            im.paste(col, (0, 0), m)
    return im


def opt_f():  # two key chips Q / Къ
    im = old_gradient()
    tamga(im, 512, 420, 520, (10, 10, 12))
    f = ImageFont.truetype(FONT, 118)
    try:
        f.set_variation_by_name("Bold")
    except Exception:
        pass
    for (x0, label) in ((262, "Q"), (532, "Къ")):
        rrect(im, (x0, 690, x0 + 230, 850), 38, (255, 255, 255), outline=(206, 209, 228), width=5)
        d = ImageDraw.Draw(im)
        w = d.textlength(label, font=f)
        d.text((x0 + 115 - w / 2, 722), label, font=f, fill=(20, 20, 24))
    return im


def squircle(im, size=330):
    m = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1], radius=int(size * 4 * 0.2237), fill=255)
    m = m.resize((size, size), Image.LANCZOS)
    out = Image.new("RGB", (size, size), (28, 28, 30))
    out.paste(im.resize((size, size), Image.LANCZOS), (0, 0), m)
    return out


if __name__ == "__main__":
    os.makedirs(OUTD, exist_ok=True)
    opts = {"A": opt_a, "B": opt_b, "C": opt_c, "D": opt_d, "E": opt_e, "F": opt_f}
    tiles = []
    for k, fn in opts.items():
        im = fn()
        im.save(os.path.join(OUTD, f"option_{k}.png"))
        t = squircle(im)
        ImageDraw.Draw(t).text((8, 6), k, fill=(255, 0, 0))
        tiles.append(t)
    cur = squircle(Image.open(PREV).convert("RGB")); ImageDraw.Draw(cur).text((8, 6), "old", fill=(255, 0, 0))
    key = squircle(Image.open(os.path.join(CA, "app_icon_keycap_1024.png")).convert("RGB")); ImageDraw.Draw(key).text((8, 6), "3D", fill=(255, 0, 0))
    tiles = [cur, key] + tiles
    cols = 4
    sheet = Image.new("RGB", (cols * 340 + 10, 2 * 340 + 10), (60, 60, 64))
    for i, t in enumerate(tiles):
        sheet.paste(t, (10 + (i % cols) * 340, 10 + (i // cols) * 340))
    sheet.save("/tmp/qk_icon_options.jpg", quality=82)
    print("OK", sheet.size)
