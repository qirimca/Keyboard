#!/usr/bin/env python3
"""Round 2 (owner: exact key copy, no shadows, visible translucency): key proportion 1.15:1 and corner radius 0.155*height measured on the iPad screenshot;
glass keyboard layer (alpha .80) and key (alpha .86) over a brand backdrop so the backdrop shows through."""
import os, math, importlib.util
from PIL import Image, ImageDraw, ImageFilter
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("g1", os.path.join(here, "generate_keycap_options.py")); g1 = importlib.util.module_from_spec(spec); spec.loader.exec_module(g1)
fi, S = g1.fi, g1.S
OUT = os.path.join(fi.CA, "icon_options_keycap2"); os.makedirs(OUT, exist_ok=True)
KW = 690; KH = int(KW / 1.15); KR = int(KH * 0.155); BOX = ((S - KW) // 2, (S - KH) // 2, (S + KW) // 2, (S + KH) // 2)

def backdrop(dark, kind):
    tl, br = ((9, 30, 56), (12, 78, 130)) if dark else ((24, 150, 216), (11, 114, 181))
    im = fi.gradient(tl, br, br, tl).convert("RGBA")
    d = ImageDraw.Draw(im, "RGBA"); col = (255, 215, 0, 150 if dark else 235)
    if kind == "ribbon":
        pts = [(x, S * 0.60 + 120 * math.sin(x / S * 2 * math.pi * 0.95 + 0.5)) for x in range(-20, S + 21, 8)]
        d.line(pts, fill=col, width=96, joint="curve")
        pts2 = [(x, S * 0.30 + 90 * math.sin(x / S * 2 * math.pi * 0.95 + 0.9)) for x in range(-20, S + 21, 8)]
        d.line(pts2, fill=(255, 255, 255, 70 if dark else 110), width=40, joint="curve")
    else:
        d.ellipse([-120, -120, 560, 560], fill=(255, 215, 0, 120 if dark else 190))
        d.ellipse([520, 520, 1150, 1150], fill=(255, 255, 255, 60 if dark else 100))
    return im.filter(ImageFilter.GaussianBlur(3))

def icon(dark, kind):
    im = backdrop(dark, kind)
    glass = (32, 32, 32, 214) if dark else (224, 225, 232, 205)
    im.alpha_composite(Image.new("RGBA", (S, S), glass))                  # keyboard background (translucent)
    im.alpha_composite(g1.layer(BOX, KR, (69, 69, 71, 232) if dark else (255, 255, 255, 222)))  # key, no shadow
    return g1.ink(im, (255, 255, 255) if dark else (10, 10, 12))

if __name__ == "__main__":
    sheet = Image.new("RGB", (2 * 330 + 10, 2 * 330 + 10), (70, 70, 74))
    for col, kind in enumerate(("ribbon", "glow")):
        for row, dark in enumerate((False, True)):
            im = icon(dark, kind); im.save(os.path.join(OUT, f"{kind}_{'dark' if dark else 'light'}.png"))
            m = Image.new("L", (1320, 1320), 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, 1319, 1319], radius=295, fill=255); m = m.resize((320, 320), Image.LANCZOS)
            sheet.paste(im.resize((320, 320), Image.LANCZOS), (10 + col * 330, 10 + row * 330), m)
    p = "/Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/icon_keycap_options2.jpg"; sheet.save(p, quality=88); print("OK", p, "key", KW, KH, KR)
