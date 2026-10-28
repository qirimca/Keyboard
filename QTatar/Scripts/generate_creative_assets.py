#!/usr/bin/env python3
"""App Store Connect "creative assets" (product page Header + Search Results) for QırımKey.
Sizes accepted by ASC (checked 2026-10-28): Header 5244x2950 and 3840x1646; Search Results 5244x2950, 3840x2560, 1920x1280.
Language-neutral: the real app icon + wordmark + two authentic captures (light/dark) in iPhone-like frames (Dynamic Island, side buttons).
Usage: python3 QTatar/Scripts/generate_creative_assets.py"""
import importlib.util
import os

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("gen", os.path.join(HERE, "generate_designed_store_media.py"))
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)

ROOT = gen.ROOT
OUT = os.path.join(ROOT, "AppStoreMetadata", "Media_Designed", "creative_assets")
SRC = os.path.join(gen.SRC, "crh", "iphone_6.9")
ICON = os.path.join(OUT, "final_icon", "qirimlogo.png")
SIZES = {
    "header_5244x2950": (5244, 2950),
    "header_3840x1646": (3840, 1646),
    "search_5244x2950": (5244, 2950),
    "search_3840x2560": (3840, 2560),
    "search_1920x1280": (1920, 1280),
}


def squircle_icon(size):
    """Standalone dark key (no outer icon tile): navy face, thin light outline, white Taraq Tamga."""
    ss = 4
    S4 = size * ss
    layer = Image.new("RGBA", (S4, S4), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    r = int(S4 * 0.226)
    d.rounded_rectangle([0, 0, S4 - 1, S4 - 1], radius=r, fill=(16, 32, 52, 238))
    w = max(3, int(S4 * 0.012))
    d.rounded_rectangle([w // 2, w // 2, S4 - 1 - w // 2, S4 - 1 - w // 2], radius=r - w // 2, outline=(120, 160, 200, 255), width=w)
    u = (S4 * 0.645) / 9.0
    cx, cy = S4 / 2, S4 / 2
    d.polygon([(cx - 4.5 * u + gx * u, cy - 2.5 * u + gy * u) for gx, gy in gen.TAMGA], fill=(255, 255, 255, 255))
    return layer.resize((size, size), Image.LANCZOS)


def iphone(shot, pw):
    """Authentic capture inside an iPhone-like body: dark frame, Dynamic Island, side buttons."""
    bz = max(6, int(pw * 0.016))
    body = gen.device(shot, pw, 0.075, 0.016)
    ss = 3
    isl_w, isl_h = int(pw * 0.30), int(pw * 0.085)
    ix, iy = bz + (pw - isl_w) // 2, bz + int(pw * 0.026)
    m = Image.new("L", (body.width * ss, body.height * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle([ix * ss, iy * ss, (ix + isl_w) * ss, (iy + isl_h) * ss], radius=isl_h * ss // 2, fill=255)
    body.paste((6, 6, 8, 255), (0, 0), m.resize(body.size, Image.LANCZOS))
    pad = int(pw * 0.012)
    out = Image.new("RGBA", (body.width + 2 * pad, body.height), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    h = body.height
    btn = (52, 54, 60, 255)
    for y0, y1 in ((0.155, 0.185), (0.225, 0.290), (0.305, 0.370)):          # action + volume (left)
        d.rounded_rectangle([0, int(h * y0), pad + 2, int(h * y1)], radius=pad // 2, fill=btn)
    d.rounded_rectangle([out.width - pad - 2, int(h * 0.255), out.width, int(h * 0.350)], radius=pad // 2, fill=btn)  # power (right)
    out.alpha_composite(body, (pad, 0))
    return out


def build(name, W, H):
    canvas = gen.background(W, H, 1)
    is_search = name.startswith("search")
    ph = int(H * (0.92 if not is_search else 0.88))
    shots = {k: Image.open(os.path.join(SRC, k)) for k in ("01_latin_light.png", "02_latin_dark.png")}
    aspect = shots["01_latin_light.png"].width / shots["01_latin_light.png"].height
    pw = int(ph * aspect * 0.965)
    phone_left = int(W * 0.68 - pw * 0.62)
    x0 = int(W * 0.07)
    icon_size = int(H * (0.25 if not is_search else 0.22))
    cy = int(H * 0.40)
    ic = squircle_icon(icon_size)
    sh = Image.new("RGBA", (icon_size + 120, icon_size + 120), (0, 0, 0, 0))
    sh.paste((0, 20, 50, 150), (60, 74), ic.split()[3])
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(int(icon_size * 0.04))), (x0 - 60, cy - icon_size // 2 - 60))
    canvas.alpha_composite(ic, (x0, cy - icon_size // 2))
    d = ImageDraw.Draw(canvas)
    tx = x0 + icon_size + int(H * 0.045)
    size = int(H * 0.12)
    f = gen.font(size, "Bold")
    while d.textlength("QırımKey", font=f) > phone_left - tx - int(W * 0.03) and size > 20:
        size = int(size * 0.94)
        f = gen.font(size, "Bold")
    ty = cy - int(size * 0.62)
    d.text((tx + 3, ty + 5), "QırımKey", font=f, fill=(0, 20, 45, 110))
    d.text((tx, ty), "QırımKey", font=f, fill=(255, 255, 255, 255))
    ry = cy + icon_size // 2 + int(H * 0.05)
    d.line([(x0, ry), (min(phone_left - int(W * 0.03), x0 + int(W * 0.30)), ry)], fill=gen.GOLD + (200,), width=max(3, int(H * 0.004)))
    for key, ang, cx_ratio, dy in (("02_latin_dark.png", -7, 0.80, 0.03), ("01_latin_light.png", 5, 0.66, 0.0)):
        body = iphone(shots[key], pw).rotate(ang, resample=Image.BICUBIC, expand=True)
        x = int(W * cx_ratio - body.width / 2)
        y = int(H * (0.5 + dy) - body.height / 2)
        gen.shadowed(canvas, body, x, y, blur=int(H * 0.025), dy=int(H * 0.012), alpha=150)
    img = canvas.convert("RGB")
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name + ".png"), optimize=True)
    img.resize((int(W * 0.18), int(H * 0.18)) if W > 3000 else (W // 3, H // 3)).save(os.path.join(OUT, "_preview_" + name + ".jpg"), quality=80)
    print("OK", name, img.size)


if __name__ == "__main__":
    for n, (w, h) in SIZES.items():
        build(n, w, h)
