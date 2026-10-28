#!/usr/bin/env python3
"""Keycap-style QırımKey app icon (1024x1024, opaque RGB): the Taraq Tamga sits on a raised key face over the original
peach-to-lavender gradient. Corner colours are sampled from the previous icon so the brand colours stay the same.
Usage: python3 QTatar/Scripts/generate_app_icon.py [--apply]   (--apply overwrites AppIcon.appiconset/qirimlogo.png, backup kept)
"""
import os
import shutil
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ICON = os.path.join(ROOT, "QTatar", "Demo", "Demo", "Assets.xcassets", "AppIcon.appiconset", "qirimlogo.png")
OUT = os.path.join(ROOT, "AppStoreMetadata", "Media_Designed", "creative_assets", "app_icon_keycap_1024.png")
PREV = os.path.join(ROOT, "AppStoreMetadata", "Media_Designed", "creative_assets", "app_icon_previous_1024.png")
S = 1024
TAMGA = [(1, 0), (8, 0), (8, 3), (9, 3), (9, 4), (7, 4), (7, 1), (5, 1), (5, 4), (6, 4), (6, 5), (3, 5), (3, 4), (4, 4),
         (4, 1), (2, 1), (2, 4), (0, 4), (0, 3), (1, 3)]


def rr_mask(box, radius, ss=4):
    x0, y0, x1, y1 = box
    m = Image.new("L", (S * ss, S * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle([x0 * ss, y0 * ss, x1 * ss, y1 * ss], radius=radius * ss, fill=255)
    return m.resize((S, S), Image.LANCZOS)


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def build():
    old = Image.open(PREV if os.path.exists(PREV) else ICON).convert("RGB")
    tl, tr, bl, br = (old.getpixel(p) for p in ((4, 4), (S - 5, 4), (4, S - 5), (S - 5, S - 5)))
    bg = Image.new("RGB", (S, S))
    px = bg.load()
    for y in range(S):
        for x in range(S):
            u, v = x / (S - 1), y / (S - 1)
            px[x, y] = tuple(int(c) for c in lerp(lerp(tl, tr, u), lerp(bl, br, u), v))
    # key geometry
    inset, top, bottom, lip = 128, 112, 880, 40
    radius = 150
    face = (inset, top, S - inset, bottom - lip)
    base = (inset, top + lip, S - inset, bottom)
    canvas = bg.convert("RGBA")
    # soft cast shadow under the key
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sh.paste((40, 40, 80, 120), (0, 26), rr_mask(base, radius))
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(26)))
    # key side (lip) = darker band
    canvas.paste((196, 199, 222, 255), (0, 0), rr_mask(base, radius))
    # key face with vertical gradient
    fg = Image.new("RGBA", (S, S))
    fpx = fg.load()
    for y in range(S):
        t = min(1.0, max(0.0, (y - face[1]) / (face[3] - face[1])))
        c = tuple(int(v) for v in lerp((255, 255, 255), (238, 240, 247), t))
        for x in range(S):
            fpx[x, y] = c + (255,)
    canvas.paste(fg, (0, 0), rr_mask(face, radius))
    # inner highlight stroke along the top edge of the face
    hl = ImageChops.subtract(rr_mask(face, radius), rr_mask((face[0] + 6, face[1] + 6, face[2] - 6, face[3] - 2), radius - 6))
    canvas.paste((255, 255, 255, 255), (0, 0), hl.point(lambda v: int(v * 0.9)))
    # tamga, black, optically centred on the face
    unit = 540 / 9.0
    cx, cy = (face[0] + face[2]) / 2, (face[1] + face[3]) / 2 + 6
    ss = 4
    layer = Image.new("L", (S * ss, S * ss), 0)
    pts = [((cx - 4.5 * unit + gx * unit) * ss, (cy - 2.5 * unit + gy * unit) * ss) for gx, gy in TAMGA]
    ImageDraw.Draw(layer).polygon(pts, fill=255)
    layer = layer.resize((S, S), Image.LANCZOS)
    canvas.paste((8, 8, 10, 255), (0, 0), layer)
    return canvas.convert("RGB")


if __name__ == "__main__":
    os.makedirs(os.path.dirname(PREV), exist_ok=True)
    if not os.path.exists(PREV):
        shutil.copyfile(ICON, PREV)  # keep the previous icon outside the asset catalog
    img = build()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    if "--apply" in sys.argv:
        img.save(ICON)
    img.resize((512, 512), Image.LANCZOS).save("/tmp/qk_icon_new.png")
    print("OK", img.size, "applied" if "--apply" in sys.argv else "preview only")
