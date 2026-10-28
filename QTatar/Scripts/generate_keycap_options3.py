#!/usr/bin/env python3
"""Round 3 (owner: Liquid Glass look, no hard lines): heavily blurred soft backdrop, frosted keyboard layer, and a glass key
(blurred+lightened refraction of what is behind it, soft specular rim, no shadow). Same key proportions as round 2 (1.15:1, radius 0.155*h)."""
import os, math, importlib.util
from PIL import Image, ImageDraw, ImageFilter, ImageChops
here = os.path.dirname(os.path.abspath(__file__))
def load(n):
    s = importlib.util.spec_from_file_location(n, os.path.join(here, n + ".py")); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
g2 = load("generate_keycap_options2"); g1 = g2.g1; fi = g1.fi; S = fi.S
OUT = os.path.join(fi.CA, "icon_options_keycap3"); os.makedirs(OUT, exist_ok=True)

def soft_backdrop(dark, kind):
    if kind == "wallpaper":   # soft cream / grey-lilac swooshes like the iPad wallpaper
        a, b = ((46, 40, 52), (24, 24, 34)) if dark else ((236, 224, 208), (186, 176, 190))
        im = fi.gradient(a, b, b, a).convert("RGBA"); d = ImageDraw.Draw(im, "RGBA")
        d.ellipse([-300, 380, 760, 1250], fill=(255, 250, 240, 90 if dark else 190))
        d.ellipse([360, -260, 1300, 520], fill=(206, 168, 120, 90 if dark else 150))
        d.ellipse([500, 620, 1250, 1250], fill=(150, 150, 190, 90 if dark else 130))
    else:                     # brand blue with a warm gold glow
        a, b = ((9, 30, 56), (12, 78, 130)) if dark else ((24, 150, 216), (11, 114, 181))
        im = fi.gradient(a, b, b, a).convert("RGBA"); d = ImageDraw.Draw(im, "RGBA")
        d.ellipse([-200, -160, 620, 560], fill=(255, 215, 0, 110 if dark else 200))
        d.ellipse([520, 560, 1200, 1200], fill=(255, 255, 255, 50 if dark else 110))
    return im.filter(ImageFilter.GaussianBlur(70))

def glass_icon(dark, kind):
    im = soft_backdrop(dark, kind)
    im.alpha_composite(Image.new("RGBA", (S, S), (28, 28, 30, 150) if dark else (240, 241, 246, 120)))   # frosted keyboard layer
    mask = fi.mask_rr(g2.BOX, g2.KR)
    refr = im.filter(ImageFilter.GaussianBlur(18))
    lift = Image.new("RGBA", (S, S), (120, 120, 126, 70) if dark else (255, 255, 255, 120)); refr.alpha_composite(lift)   # glass body
    im.paste(refr, (0, 0), mask)
    rim = Image.new("RGBA", (S, S), (0, 0, 0, 0)); rd = ImageDraw.Draw(rim)
    rd.rounded_rectangle(g2.BOX, radius=g2.KR, outline=(255, 255, 255, 230 if not dark else 150), width=5)
    fade = Image.linear_gradient("L").resize((S, S)).rotate(45)                 # specular: strong top-left, faint bottom-right
    fade = ImageChops.invert(fade).point(lambda v: 40 + v * 215 // 255)
    rim.putalpha(ImageChops.multiply(rim.getchannel("A"), fade)); im.alpha_composite(rim.filter(ImageFilter.GaussianBlur(1.2)))
    return g1.ink(im, (255, 255, 255) if dark else (12, 12, 16))

if __name__ == "__main__":
    sheet = Image.new("RGB", (2 * 330 + 10, 2 * 330 + 10), (70, 70, 74))
    for col, kind in enumerate(("wallpaper", "brand")):
        for row, dark in enumerate((False, True)):
            im = glass_icon(dark, kind); im.save(os.path.join(OUT, f"{kind}_{'dark' if dark else 'light'}.png"))
            m = Image.new("L", (1320, 1320), 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, 1319, 1319], radius=295, fill=255); m = m.resize((320, 320), Image.LANCZOS)
            sheet.paste(im.resize((320, 320), Image.LANCZOS), (10 + col * 330, 10 + row * 330), m)
    p = "/Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/icon_keycap_options3.jpg"; sheet.save(p, quality=90); print("OK", p)
