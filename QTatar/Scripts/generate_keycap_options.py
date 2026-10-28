#!/usr/bin/env python3
"""Icon options built from the real iOS 27 key look (owner request 2026-10-28): light bg #E0E1E8 / dark #202020, white / #454547 keys.
Writes AppStoreMetadata/Media_Designed/creative_assets/icon_options_keycap/*.png and a preview sheet (path printed)."""
import os, sys, importlib.util
from PIL import Image, ImageDraw, ImageFilter
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("fi", os.path.join(here, "generate_final_icon.py")); fi = importlib.util.module_from_spec(spec); spec.loader.exec_module(fi)
S, SS = fi.S, fi.SS
OUT = os.path.join(fi.CA, "icon_options_keycap"); os.makedirs(OUT, exist_ok=True)

def layer(box, r, rgba):
    l = Image.new("RGBA", (S, S), (0, 0, 0, 0)); l.paste(rgba, (0, 0), fi.mask_rr(box, r).point(lambda v: v * rgba[3] // 255)); return l

def shadow(box, r, dy, blur, alpha):
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sh.paste((0, 0, 0, 255), (0, dy), fi.mask_rr(box, r).point(lambda v: int(v * alpha / 255)))
    return sh.filter(ImageFilter.GaussianBlur(blur))

def ink(im, rgb):
    rgb_im = im.convert("RGB"); fi.tamga(rgb_im, 512, 512, 440, rgb); return rgb_im

def b1(dark):   # keyboard background tile + one 1:1 key
    bg = (32, 32, 32) if dark else (224, 225, 232)
    im = Image.new("RGBA", (S, S), bg + (255,)); box = (150, 190, 874, 850)
    im.alpha_composite(shadow(box, 150, 10, 4, 120 if dark else 70))
    im.alpha_composite(layer(box, 150, (69, 69, 71, 255) if dark else (255, 255, 255, 255)))
    return ink(im, (255, 255, 255) if dark else (10, 10, 12))

def b2(dark):   # translucent key over the brand backdrop (shows real transparency)
    tl, br = ((10, 40, 72), (14, 92, 150)) if dark else ((24, 150, 216), (11, 114, 181))
    im = fi.gradient(tl, br, br, tl).convert("RGBA"); box = (140, 180, 884, 860)
    im.alpha_composite(shadow(box, 160, 14, 14, 110))
    im.alpha_composite(layer(box, 160, (58, 58, 62, 190) if dark else (255, 255, 255, 205)))
    d = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d.paste((255, 255, 255, 90 if dark else 160), (0, 0), fi.mask_rr(box, 160, outline=4)); im.alpha_composite(d)
    return ink(im, (255, 255, 255) if dark else (10, 10, 12))

def b3(dark):   # keyboard tile: centre key + neighbouring keys cropped at the edges
    bg = (32, 32, 32) if dark else (224, 225, 232); key = (69, 69, 71) if dark else (255, 255, 255)
    im = Image.new("RGBA", (S, S), bg + (255,)); c = (230, 230, 794, 794)
    for box in [(-250, 230, 190, 794), (834, 230, 1274, 794), (230, -250, 794, 190), (230, 834, 794, 1274)]:
        im.alpha_composite(layer(box, 120, key + (150 if dark else 190,)))
    im.alpha_composite(shadow(c, 130, 10, 4, 120 if dark else 70)); im.alpha_composite(layer(c, 130, key + (255,)))
    return ink(im, (255, 255, 255) if dark else (10, 10, 12))

if __name__ == "__main__":
    names = [("A_keyboard_tile", b1), ("B_translucent_key", b2), ("C_key_with_neighbours", b3)]
    sheet = Image.new("RGB", (3 * 330 + 10, 2 * 330 + 10), (70, 70, 74))
    for col, (n, fn) in enumerate(names):
        for row, dark in enumerate((False, True)):
            im = fn(dark); im.save(os.path.join(OUT, f"{n}_{'dark' if dark else 'light'}.png"))
            m = Image.new("L", (1320, 1320), 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, 1319, 1319], radius=295, fill=255); m = m.resize((320, 320), Image.LANCZOS)
            sheet.paste(im.resize((320, 320), Image.LANCZOS), (10 + col * 330, 10 + row * 330), m)
    p = "/Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/icon_keycap_options.jpg"; sheet.save(p, quality=88); print("OK", p)
