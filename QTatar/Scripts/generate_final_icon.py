#!/usr/bin/env python3
"""Final QırımKey app icon (option A: flat key silhouette around the Taraq Tamga) in the three iOS appearances:
light (default), dark and tinted (grayscale). Staged in creative_assets/final_icon; --apply copies into AppIcon.appiconset and writes Contents.json.
Usage: python3 QTatar/Scripts/generate_final_icon.py [--apply]"""
import json
import math
import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CA = os.path.join(ROOT, "AppStoreMetadata", "Media_Designed", "creative_assets")
PREV = os.path.join(CA, "app_icon_previous_1024.png")
STAGE = os.path.join(CA, "final_icon")
SET = os.path.join(ROOT, "QTatar", "Demo", "Demo", "Assets.xcassets", "AppIcon.appiconset")
S, SS = 1024, 3
TAMGA = [(1, 0), (8, 0), (8, 3), (9, 3), (9, 4), (7, 4), (7, 1), (5, 1), (5, 4), (6, 4), (6, 5), (3, 5), (3, 4), (4, 4),
         (4, 1), (2, 1), (2, 4), (0, 4), (0, 3), (1, 3)]


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(tl, tr, bl, br):
    im = Image.new("RGB", (S, S)); px = im.load()
    for y in range(S):
        for x in range(S):
            u, v = x / (S - 1), y / (S - 1)
            px[x, y] = lerp(lerp(tl, tr, u), lerp(bl, br, u), v)
    return im


def mask_rr(box, r, outline=0):
    m = Image.new("L", (S * SS, S * SS), 0)
    d = ImageDraw.Draw(m)
    if outline:
        d.rounded_rectangle([v * SS for v in box], radius=r * SS, outline=255, width=outline * SS)
    else:
        d.rounded_rectangle([v * SS for v in box], radius=r * SS, fill=255)
    return m.resize((S, S), Image.LANCZOS)


def tamga(im, cx, cy, width, fill):
    u = width / 9.0
    m = Image.new("L", (S * SS, S * SS), 0)
    ImageDraw.Draw(m).polygon([((cx - 4.5 * u + gx * u) * SS, (cy - 2.5 * u + gy * u) * SS) for gx, gy in TAMGA], fill=255)
    im.paste(fill, (0, 0), m.resize((S, S), Image.LANCZOS))


def key_icon(bg, face, line, ink, shadow_rgb, shadow_alpha):
    box = (140, 140, 884, 884)
    im = bg.convert("RGBA")
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sh.paste(shadow_rgb + (255,), (0, 16), mask_rr(box, 168).point(lambda v: int(v * shadow_alpha / 255)))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(22)))
    rgb = im.convert("RGB")
    rgb.paste(face, (0, 0), mask_rr(box, 168))
    rgb.paste(line, (0, 0), mask_rr(box, 168, outline=5))
    tamga(rgb, 512, 512, 480, ink)
    return rgb


def build():
    o = Image.open(PREV).convert("RGB")
    light_bg = gradient(o.getpixel((4, 4)), o.getpixel((S - 5, 4)), o.getpixel((4, S - 5)), o.getpixel((S - 5, S - 5)))
    light = key_icon(light_bg, (255, 255, 255), (206, 209, 228), (10, 10, 12), (40, 40, 90), 70)
    dark_bg = gradient((15, 26, 38), (18, 32, 46), (18, 32, 46), (26, 46, 66))
    dark = key_icon(dark_bg, (33, 50, 70), (84, 108, 138), (255, 255, 255), (0, 0, 0), 110)
    tint_bg = gradient((22, 22, 22), (26, 26, 26), (26, 26, 26), (34, 34, 34))
    tinted = key_icon(tint_bg, (44, 44, 44), (178, 178, 178), (245, 245, 245), (0, 0, 0), 90)
    return light, dark, tinted


if __name__ == "__main__":
    light, dark, tinted = build()
    os.makedirs(STAGE, exist_ok=True)
    names = {"qirimlogo.png": light, "qirimlogo_dark.png": dark, "qirimlogo_tinted.png": tinted}
    for n, im in names.items():
        im.save(os.path.join(STAGE, n))
    if "--apply" in sys.argv:
        for n in names:
            shutil.copyfile(os.path.join(STAGE, n), os.path.join(SET, n))
        contents = {"images": [
            {"filename": "qirimlogo.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "dark"}], "filename": "qirimlogo_dark.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "tinted"}], "filename": "qirimlogo_tinted.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
            "info": {"author": "xcode", "version": 1}}
        json.dump(contents, open(os.path.join(SET, "Contents.json"), "w"), indent=2)
    # preview strip with iOS mask
    sheet = Image.new("RGB", (3 * 340 + 10, 350), (60, 60, 64))
    for i, im in enumerate(names.values()):
        m = Image.new("L", (1320, 1320), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, 1319, 1319], radius=int(1320 * 0.2237), fill=255)
        m = m.resize((330, 330), Image.LANCZOS)
        sheet.paste(im.resize((330, 330), Image.LANCZOS), (10 + i * 340, 10), m)
    sheet.save("/tmp/qk_final_icon_sheet.jpg", quality=85)
    print("OK", "applied" if "--apply" in sys.argv else "staged")
