#!/usr/bin/env python3
"""Designed App Store screenshots for QirimKey: a continuous panoramic canvas (5 frames) per device and locale.

Source images are the authentic captures in AppStoreMetadata/Media_PlanB (no generative imagery). The script only
composes them: continuous background, Taraq Tamga ornament and ribbon that cross frame seams, device bezel and
captions (SF Pro). The strip is then sliced into exact store sizes.

Usage: python3 QTatar/Scripts/generate_designed_store_media.py [--preview]
Output: AppStoreMetadata/Media_Designed/<locale>/<device>/0N_*.png  (+ _strip_preview_*.jpg with --preview)
"""
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "AppStoreMetadata", "Media_PlanB")
OUT = os.path.join(ROOT, "AppStoreMetadata", "Media_Designed")
FILES = ["01_latin_light.png", "02_latin_dark.png", "03_cyrillic.png", "04_home_light.png", "05_home_dark.png"]
DEVICES = {"iphone_6.9": (1320, 2868), "ipad_13": (2064, 2752), "iphone_duo": (1398, 2034)}  # Duo = foldable iPhone, outer display
FONT_PATH = "/System/Library/Fonts/SFNS.ttf"

BLUE_DEEP = (7, 58, 105)
BLUE_MID = (11, 114, 181)
BLUE_LIGHT = (18, 149, 216)
GOLD = (255, 215, 0)

# Crimean Tatar strings reuse words already present in the app UI; flagged for native review in the handoff.
CAPTIONS = {
    "en": [
        ("Type Crimean Tatar naturally", "Suggestions and every special letter"),
        ("Beautiful in Dark Mode", "Follows your system theme"),
        ("Latin and Cyrillic", "Both scripts in one keyboard"),
        ("Track your progress", "Speed, accuracy and achievements"),
        ("Your personal dictionary", "Learns the words you use"),
    ],
    "uk": [
        ("Пишіть кримськотатарською", "Підказки та всі спеціальні літери"),
        ("Чудово в темній темі", "Підлаштовується під систему"),
        ("Латиниця і кирилиця", "Обидва письма в одній клавіатурі"),
        ("Стежте за прогресом", "Швидкість, точність, досягнення"),
        ("Ваш особистий словник", "Запам’ятовує слова, які ви вживаєте"),
    ],
    "crh": [
        ("Qırımtatarca yazıñız", "Teklifler ve er bir mahsus arif"),
        ("Qaranlıq ve aydınlıq", "Sistemañızğa uyğun körünüş"),
        ("Latin ve Kirill", "Eki yazuv, bir klaviatura"),
        ("Yazuv tezligi", "Statistika ve yeñişler"),
        ("Şahsiy luğat", "Ögrenilgen sözler"),
    ],
    "tr": [
        ("Kırım Tatarcasını doğal yazın", "Öneriler ve tüm özel harfler"),
        ("Karanlık Modda harika", "Sistem temanıza uyum sağlar"),
        ("Latin ve Kiril", "Tek klavyede iki alfabe"),
        ("İlerlemenizi takip edin", "Hız, doğruluk ve başarılar"),
        ("Kişisel sözlüğünüz", "Kullandığınız kelimeleri öğrenir"),
    ],
    "de": [
        ("Krimtatarisch ganz natürlich tippen", "Vorschläge und alle Sonderbuchstaben"),
        ("Brillant im Dunkelmodus", "Folgt dem System-Design"),
        ("Lateinisch und Kyrillisch", "Beide Schriften in einer Tastatur"),
        ("Fortschritt im Blick", "Tempo, Genauigkeit und Erfolge"),
        ("Ihr persönliches Wörterbuch", "Lernt die Wörter, die Sie nutzen"),
    ],
    "pl": [
        ("Pisz po krymskotatarsku naturalnie", "Podpowiedzi i wszystkie specjalne litery"),
        ("Świetny w trybie ciemnym", "Dopasowuje się do motywu systemu"),
        ("Łacinka i cyrylica", "Oba alfabety w jednej klawiaturze"),
        ("Śledź swoje postępy", "Szybkość, dokładność i osiągnięcia"),
        ("Twój osobisty słownik", "Uczy się słów, których używasz"),
    ],
    "ro": [
        ("Scrie natural în tătară crimeeană", "Sugestii și toate literele speciale"),
        ("Superb în modul întunecat", "Se potrivește temei sistemului"),
        ("Alfabet latin și chirilic", "Ambele alfabete într-o singură tastatură"),
        ("Urmărește-ți progresul", "Viteză, acuratețe și realizări"),
        ("Dicționarul tău personal", "Învață cuvintele pe care le folosești"),
    ],
}
SRC_FOLDER = {"en": "en", "uk": "uk", "crh": "crh", "tr": "en", "de": "en", "pl": "en", "ro": "en"}
# Locales without an in-app UI language (the app UI exists only in crh/uk/en) reuse the English-UI captures with localized captions.
ALL_LOCALES = ["en", "uk", "crh", "tr", "de", "pl", "ro"]


def font(size, weight="Bold"):
    f = ImageFont.truetype(FONT_PATH, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background(w, h, n):
    """Horizontal gradient that breathes deep -> light -> deep across the whole strip, plus soft glows on seams."""
    total = w * n
    strip = Image.new("RGB", (total, h))
    px = ImageDraw.Draw(strip)
    for x in range(total):
        t = x / (total - 1)
        k = 0.5 - 0.5 * math.cos(t * math.pi * 2 * 1.0)  # 0 -> 1 -> 0
        px.line([(x, 0), (x, h)], fill=lerp(BLUE_DEEP, BLUE_LIGHT, 0.10 + k * 0.90))
    # vertical falloff: darker at the bottom for depth
    shade = Image.new("L", (1, h))
    for y in range(h):
        shade.putpixel((0, y), int(70 * (y / h) ** 1.6))
    shade = shade.resize((total, h))
    strip = Image.composite(Image.new("RGB", (total, h), (3, 28, 52)), strip, shade)
    # soft glows crossing seams 1/2 and 3/4
    glow = Image.new("RGBA", (total, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for sx, sy, r in [(w * 1.0, h * 0.30, w * 0.55), (w * 3.0, h * 0.62, w * 0.60), (w * 4.9, h * 0.20, w * 0.45)]:
        gd.ellipse([sx - r, sy - r, sx + r, sy + r], fill=(255, 255, 255, 38))
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.12))
    return Image.alpha_composite(strip.convert("RGBA"), glow)


TAMGA = [(1, 0), (8, 0), (8, 3), (9, 3), (9, 4), (7, 4), (7, 1), (5, 1), (5, 4), (6, 4), (6, 5), (3, 5), (3, 4), (4, 4),
         (4, 1), (2, 1), (2, 4), (0, 4), (0, 3), (1, 3)]


def draw_tamga(canvas, cx, cy, width, line, alpha, fill=False):
    """Taraq Tamga (same 9x5 polygon as TaraqTamgaShape) drawn antialiased on a 3x supersampled layer."""
    ss = 3
    scale = width / 9.0
    pad = int(line * 3)
    lw, lh = int(width + pad * 2), int(scale * 5 + pad * 2)
    layer = Image.new("RGBA", (lw * ss, lh * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    pts = [((pad + gx * scale) * ss, (pad + gy * scale) * ss) for gx, gy in TAMGA]
    col = GOLD + (alpha,)
    if fill:
        d.polygon(pts, fill=col)
    else:
        d.line(pts + [pts[0], pts[1]], fill=col, width=int(line * ss), joint="curve")
    layer = layer.resize((lw, lh), Image.LANCZOS)
    canvas.alpha_composite(layer, (int(cx - lw / 2), int(cy - lh / 2)))


def ribbon(canvas, w, h, n):
    """Flowing gold ribbon that crosses every seam."""
    total = w * n
    ss = 2
    layer = Image.new("RGBA", (total // ss, h // ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for off, a, lw in [(0, 120, 6), (26, 70, 4), (-26, 50, 3)]:
        pts = []
        for x in range(0, total, 12):
            t = x / total
            y = h * (0.80 + 0.07 * math.sin(t * math.pi * 2 * 2.0 + 0.6)) + off
            pts.append((x / ss, y / ss))
        d.line(pts, fill=GOLD + (a,), width=lw * 2, joint="curve")
    layer = layer.resize((total, h), Image.LANCZOS)
    canvas.alpha_composite(layer)


def rounded_mask(size, radius, ss=4):
    m = Image.new("L", (size[0] * ss, size[1] * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] * ss - 1, size[1] * ss - 1], radius=radius * ss, fill=255)
    return m.resize(size, Image.LANCZOS)


def device(shot, width, radius_ratio, bezel_ratio):
    sw = width
    sh = int(shot.height * sw / shot.width)
    shot = shot.convert("RGB").resize((sw, sh), Image.LANCZOS)
    bz = max(6, int(sw * bezel_ratio))
    r_out = int(sw * radius_ratio)
    r_in = max(4, r_out - bz)
    total = (sw + bz * 2, sh + bz * 2)
    body = Image.new("RGBA", total, (0, 0, 0, 0))
    frame = Image.new("RGBA", total, (14, 16, 20, 255))
    body.paste(frame, (0, 0), rounded_mask(total, r_out))
    inner = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    inner.paste(shot, (0, 0), rounded_mask((sw, sh), r_in))
    body.alpha_composite(inner, (bz, bz))
    # subtle outer highlight
    hl = Image.new("RGBA", total, (0, 0, 0, 0))
    ImageDraw.Draw(hl).rounded_rectangle([0, 0, total[0] - 1, total[1] - 1], radius=r_out, outline=(255, 255, 255, 60), width=2)
    body.alpha_composite(hl)
    return body


def shadowed(canvas, body, x, y, blur, dy, alpha):
    sh = Image.new("RGBA", (body.width + blur * 4, body.height + blur * 4), (0, 0, 0, 0))
    a = body.split()[3].point(lambda v: int(v * alpha / 255))
    sh.paste((0, 0, 0, 255), (blur * 2, blur * 2), a)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(sh, (x - blur * 2, y - blur * 2 + dy))
    canvas.alpha_composite(body, (x, y))


def wrap(draw, text, fnt, max_w):
    words, lines, cur = text.split(), [], ""
    for wd in words:
        t = (cur + " " + wd).strip()
        if draw.textlength(t, font=fnt) <= max_w:
            cur = t
        else:
            lines.append(cur)
            cur = wd
    lines.append(cur)
    return lines


def caption(canvas, fx, w, h, head, sub, ipad):
    d = ImageDraw.Draw(canvas)
    hs = int(w * (0.060 if ipad else 0.082))
    ss_ = int(w * (0.027 if ipad else 0.037))
    max_w = w * 0.86
    hf = font(hs, "Bold")
    while True:
        lines = wrap(d, head, hf, max_w)
        if len(lines) <= 2:
            break
        hs = int(hs * 0.92)
        hf = font(hs, "Bold")
    dev_top = int(h * (0.215 if ipad else 0.235))
    block = len(lines) * int(hs * 1.12) + int(hs * 0.12) + int(ss_ * 1.3)
    y = max(int(h * 0.03), dev_top - int(h * 0.028) - block)
    for ln in lines:
        tw = d.textlength(ln, font=hf)
        d.text((fx + (w - tw) / 2 + 2, y + 3), ln, font=hf, fill=(0, 20, 45, 90))  # soft shadow
        d.text((fx + (w - tw) / 2, y), ln, font=hf, fill=(255, 255, 255, 255))
        y += int(hs * 1.12)
    sf = font(ss_, "Medium")
    tw = d.textlength(sub, font=sf)
    d.text((fx + (w - tw) / 2, y + int(hs * 0.12)), sub, font=sf, fill=(255, 255, 255, 215))


def build(locale, dev, w, h, preview):
    ipad = dev.startswith("ipad")
    n = len(FILES)
    canvas = background(w, h, n)
    # ornament crossing seams (behind devices)
    ribbon(canvas, w, h, n)
    shots = [Image.open(os.path.join(SRC, SRC_FOLDER[locale], "iphone_6.9" if dev == "iphone_duo" else dev, f)) for f in FILES]
    # Media_PlanB/*/ipad_13/03_cyrillic.png shows the LATIN layout (pre-existing defect). Use the authentic iPad Cyrillic
    # capture (status bar normalised to 09:41 from the reference shot) so frame 3 really shows Cyrillic.
    fixed = os.path.join(OUT, "_sources", "ipad_13_03_cyrillic.png")
    if ipad and os.path.exists(fixed):
        shots[2] = Image.open(fixed)
    dev_w = int(w * (0.70 if ipad else 0.80))
    if dev.startswith("iphone"):
        # Fit the phone mockup into the space under the caption (it may bleed ~3.5% off the bottom), keeping its aspect ratio.
        top = h * 0.235
        aspect = shots[0].width / shots[0].height
        dev_w = int(min(dev_w, (h - top + h * 0.035) * aspect))
    for i, shot in enumerate(shots):
        body = device(shot, dev_w, 0.075 if not ipad else 0.045, 0.016 if not ipad else 0.014)
        x = i * w + (w - body.width) // 2
        y = int(h * (0.215 if ipad else 0.235))
        shadowed(canvas, body, x, y, blur=int(w * 0.03), dy=int(w * 0.02), alpha=150)
    # gallery rail: thin gold line across the whole strip with a Taraq Tamga seal on every seam
    rail_y = int(h * 0.045)
    ImageDraw.Draw(canvas).line([(w * 0.04, rail_y), (w * n - w * 0.04, rail_y)], fill=GOLD + (70,), width=max(2, int(w * 0.0025)))
    for k in range(1, n):
        cx = k * w
        ImageDraw.Draw(canvas).ellipse([cx - w * 0.095, rail_y - w * 0.095, cx + w * 0.095, rail_y + w * 0.095], fill=(8, 66, 118, 255), outline=GOLD + (200,), width=max(2, int(w * 0.003)))
        draw_tamga(canvas, cx, rail_y, w * 0.115, w * 0.006, 255, fill=True)
    for i, (head, sub) in enumerate(CAPTIONS[locale]):
        caption(canvas, i * w, w, h, head, sub, ipad)
    out_dir = os.path.join(OUT, locale, dev)
    os.makedirs(out_dir, exist_ok=True)
    for i, name in enumerate(FILES):
        frame = canvas.crop((i * w, 0, (i + 1) * w, h)).convert("RGB")
        assert frame.size == (w, h)
        frame.save(os.path.join(out_dir, name), optimize=True)
    if preview:
        sc = 0.18 if not ipad else 0.14
        small = canvas.convert("RGB").resize((int(w * n * sc), int(h * sc)), Image.LANCZOS)
        small.save(os.path.join(OUT, f"_strip_preview_{locale}_{dev}.jpg"), quality=82)
    print("OK", locale, dev, len(FILES), "frames")


if __name__ == "__main__":
    preview = "--preview" in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    devs = [a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--dev=")]
    for loc in (only or ALL_LOCALES):
        for dev, (w, h) in DEVICES.items():
            if devs and dev not in devs:
                continue
            build(loc, dev, w, h, preview)
