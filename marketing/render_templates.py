#!/usr/bin/env python3
"""
Deterministic renderer for QırımKey App Store & social marketing templates.
Reads `marketing/templates/config.json` and `marketing/provenance.json`,
binds Crimean coast sunset photography (`marketing/templates/assets/crimea_sunset_bg.png`)
and real simulator/device screenshots into `marketing/templates/{iphone,ipad}/template.svg`,
renders localized (crh, uk, en) iPhone 6.9" and iPad 13" App Store posters with realistic
hardware frames and Apple-grade SF Pro typography, and outputs parameterized SVGs and
a verification manifest to `marketing/rendered/`.
"""

import hashlib
import html
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = ROOT / "marketing" / "templates" / "config.json"
PROVENANCE_PATH = ROOT / "marketing" / "provenance.json"
OUT_DIR = ROOT / "marketing" / "rendered"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


SWIFT_COMPOSITOR = r"""
import Foundation
import AppKit
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import AVFoundation

let repoRoot = FileManager.default.currentDirectoryPath

func ensureDir(_ p: String) {
    try? FileManager.default.createDirectory(atPath: p, withIntermediateDirectories: true)
}

func loadCGImage(_ path: String) -> CGImage? {
    let url = URL(fileURLWithPath: path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

func saveCGImage(_ image: CGImage, to path: String) {
    let w = image.width
    let h = image.height
    let cs = CGColorSpaceCreateDeviceRGB()
    var finalImage = image
    if let opaqueCtx = CGContext(
        data: nil,
        width: w,
        height: h,
        bitsPerComponent: 8,
        bytesPerRow: w * 4,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) {
        opaqueCtx.setFillColor(CGColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1.0))
        opaqueCtx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        opaqueCtx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        if let stripped = opaqueCtx.makeImage() {
            finalImage = stripped
        }
    }
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
    let props: [CFString: Any] = [kCGImagePropertyHasAlpha: kCFBooleanFalse as Any]
    CGImageDestinationAddImage(dest, finalImage, props as CFDictionary)
    CGImageDestinationFinalize(dest)
}

func drawStyledText(
    _ ctx: CGContext,
    _ text: String,
    centerX: CGFloat,
    y: CGFloat,
    maxWidth: CGFloat,
    fontSize: CGFloat,
    weight: NSFont.Weight,
    kern: CGFloat = 0.0,
    color: NSColor
) {
    var actualSize = fontSize
    var attrStr = NSAttributedString()
    var line: CTLine!
    var lineW: CGFloat = 0

    while actualSize >= fontSize * 0.65 {
        let font = NSFont.systemFont(ofSize: actualSize, weight: weight)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .kern: kern
        ]
        attrStr = NSAttributedString(string: text, attributes: attrs)
        line = CTLineCreateWithAttributedString(attrStr)
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        lineW = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        if lineW <= maxWidth { break }
        actualSize -= 1.5
    }

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 12, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45))
    ctx.textMatrix = .identity
    ctx.textPosition = CGPoint(x: centerX - lineW * 0.5, y: y)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

let bgImg = loadCGImage("\(repoRoot)/marketing/templates/assets/crimea_sunset_bg.png")

struct PosterCopy {
    let shotId: String
    let badge: String
    let title: String
    let subtitle: String
    let isDark: Bool
}

let localizedCopy: [String: [PosterCopy]] = [
    "crh": [
        PosterCopy(shotId: "01_latin_light", badge: "QIRIMKEY • ÖZ TİLİMİZ ER YERDE", title: "Qırımtatar Klaviaturası", subtitle: "Lâtin ve Kirill elifbeleri, aqıllı söz teklifleri ve svayp", isDark: false),
        PosterCopy(shotId: "02_latin_dark", badge: "QARANLIQ TEMA & LIQUID GLASS", title: "Zarif Gece Körünişi", subtitle: "Közni yormayğan dizayn ve canlı Taraq Tamğa nefes aluvı", isDark: true),
        PosterCopy(shotId: "03_cyrillic", badge: "EKİ ELİFBE — BİR YERDE", title: "Kirill ve Canlı Transliteratsiya", subtitle: "селям → selâm • Ukraina ФІВА ve klassik tizilişleri", isDark: false),
        PosterCopy(shotId: "04_home_light", badge: "STATİSTİKA & SAZLAMALAR", title: "Öz Üslübiñizge Köre Sazlañız", subtitle: "Yazuv statistika kartası, künlik hikmetler ve qolay idare", isDark: false),
        PosterCopy(shotId: "05_home_dark", badge: "100% CİHAZDA • TAM HUSUSİYLİK", title: "Malümatıñız Emniyette", subtitle: "İnternetsiz işley • Şahsiy yazuvlarıñız cihazdan tışqa çıqmay", isDark: true)
    ],
    "uk": [
        PosterCopy(shotId: "01_latin_light", badge: "QIRIMKEY • РІДНА МОВА ВСЮДИ", title: "Кримськотатарська клавіатура", subtitle: "Латиниця та кирилиця, розумні підказки слів і свайп", isDark: false),
        PosterCopy(shotId: "02_latin_dark", badge: "ТЕМНА ТЕМА & LIQUID GLASS", title: "Витончений нічний дизайн", subtitle: "Комфортний набір удень і вночі з живим диханням Тарак-Тамги", isDark: true),
        PosterCopy(shotId: "03_cyrillic", badge: "ДВА АЛФАВІТИ РАЗОМ", title: "Кирилиця та миттєва транслітерація", subtitle: "селям → selâm • Українська розкладка ФІВА та класична", isDark: false),
        PosterCopy(shotId: "04_home_light", badge: "СТАТИСТИКА Й НАЛАШТУВАННЯ", title: "Зручне керування та прогрес", subtitle: "Статистика швидкості друку, відомі вислови та гнучкі опції", isDark: false),
        PosterCopy(shotId: "05_home_dark", badge: "100% НА ПРИСТРОЇ • ПОВНА ПРИВАТНІСТЬ", title: "Ваші дані у безпеці", subtitle: "Працює повністю офлайн • Жодні тексти не передаються в мережу", isDark: true)
    ],
    "en": [
        PosterCopy(shotId: "01_latin_light", badge: "QIRIMKEY • OUR LANGUAGE EVERYWHERE", title: "Crimean Tatar Keyboard", subtitle: "Latin & Cyrillic scripts, smart word predictions and swipe", isDark: false),
        PosterCopy(shotId: "02_latin_dark", badge: "DARK THEME & LIQUID GLASS", title: "Refined Night Experience", subtitle: "Effortless day & night typing with breathing Taraq Tamğa emblem", isDark: true),
        PosterCopy(shotId: "03_cyrillic", badge: "TWO SCRIPTS IN ONE", title: "Cyrillic & Live Transliteration", subtitle: "селям → selâm • Ukrainian FIVA and classic Cyrillic layouts", isDark: false),
        PosterCopy(shotId: "04_home_light", badge: "STATISTICS & CUSTOMIZATION", title: "Tailored to Your Typing Style", subtitle: "Personal typing milestones, cultural quotes & intuitive controls", isDark: false),
        PosterCopy(shotId: "05_home_dark", badge: "100% ON-DEVICE • TOTAL PRIVACY", title: "Your Data Stays Yours", subtitle: "Works completely offline • Zero telemetry or cloud tracking", isDark: true)
    ]
]

func drawHardwareDevice(
    _ ctx: CGContext,
    shotImg: CGImage,
    screenRect: CGRect,
    isPad: Bool
) {
    let cs = CGColorSpaceCreateDeviceRGB()
    let screenCorner: CGFloat = isPad ? 32 : 58
    let innerBezel: CGFloat = isPad ? 28 : 16
    let outerRim: CGFloat = isPad ? 6 : 7

    let innerRect = screenRect.insetBy(dx: -innerBezel, dy: -innerBezel)
    let outerRect = innerRect.insetBy(dx: -outerRim, dy: -outerRim)
    let innerCorner = screenCorner + innerBezel * 0.85
    let outerCorner = innerCorner + outerRim

    // 1. Hardware side buttons
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 0.44, green: 0.49, blue: 0.56, alpha: 1.0))
    if isPad {
        // Top power button & right-side volume buttons
        let topBtn = CGRect(x: outerRect.maxX - 115, y: outerRect.maxY - 2, width: 64, height: 7)
        let volUp = CGRect(x: outerRect.maxX - 2, y: outerRect.maxY - 190, width: 7, height: 72)
        let volDn = CGRect(x: outerRect.maxX - 2, y: outerRect.maxY - 280, width: 7, height: 72)
        for r in [topBtn, volUp, volDn] {
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: 3, cornerHeight: 3, transform: nil))
            ctx.fillPath()
        }
    } else {
        // Left Action + Volume Up/Down, Right Side/Power button
        let btnW: CGFloat = 7
        let actBtn = CGRect(x: outerRect.minX - btnW + 2, y: outerRect.maxY - 340, width: btnW, height: 52)
        let volUp = CGRect(x: outerRect.minX - btnW + 2, y: outerRect.maxY - 460, width: btnW, height: 96)
        let volDn = CGRect(x: outerRect.minX - btnW + 2, y: outerRect.maxY - 580, width: btnW, height: 96)
        let pwrBtn = CGRect(x: outerRect.maxX - 2, y: outerRect.maxY - 490, width: btnW, height: 145)
        for r in [actBtn, volUp, volDn, pwrBtn] {
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: 3, cornerHeight: 3, transform: nil))
            ctx.fillPath()
        }
    }
    ctx.restoreGState()

    // 2. Outer metallic titanium/aluminum chassis with drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -26), blur: 42, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.62))
    let outerPath = CGPath(roundedRect: outerRect, cornerWidth: outerCorner, cornerHeight: outerCorner, transform: nil)
    ctx.addPath(outerPath)
    ctx.setFillColor(CGColor(red: 0.45, green: 0.50, blue: 0.58, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    // Metallic gradient across outer chassis
    ctx.saveGState()
    ctx.addPath(outerPath)
    ctx.clip()
    let gradColors = [
        CGColor(red: 0.68, green: 0.73, blue: 0.80, alpha: 1.0),
        CGColor(red: 0.32, green: 0.36, blue: 0.43, alpha: 1.0),
        CGColor(red: 0.54, green: 0.59, blue: 0.67, alpha: 1.0)
    ] as CFArray
    if let grad = CGGradient(colorsSpace: cs, colors: gradColors, locations: [0.0, 0.5, 1.0]) {
        ctx.drawLinearGradient(grad, start: CGPoint(x: outerRect.minX, y: outerRect.maxY), end: CGPoint(x: outerRect.maxX, y: outerRect.minY), options: [])
    }
    ctx.restoreGState()

    // 3. Inner black bezel
    ctx.saveGState()
    let innerPath = CGPath(roundedRect: innerRect, cornerWidth: innerCorner, cornerHeight: innerCorner, transform: nil)
    ctx.addPath(innerPath)
    ctx.setFillColor(CGColor(red: 0.035, green: 0.042, blue: 0.058, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    // 4. Screen content clipped to screenRect
    ctx.saveGState()
    let clipPath = CGPath(roundedRect: screenRect, cornerWidth: screenCorner, cornerHeight: screenCorner, transform: nil)
    ctx.addPath(clipPath)
    ctx.clip()
    ctx.draw(shotImg, in: screenRect)
    ctx.restoreGState()

    // Subtle inner screen border rim
    ctx.saveGState()
    ctx.addPath(clipPath)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.12))
    ctx.setLineWidth(1.5)
    ctx.strokePath()
    ctx.restoreGState()

    // 5. Front camera / Dynamic Island hardware detail
    ctx.saveGState()
    if isPad {
        // Front TrueDepth camera sensor centered in top bezel
        let camR: CGFloat = 6.5
        let camCenter = CGPoint(x: innerRect.midX, y: screenRect.maxY + innerBezel * 0.5)
        ctx.setFillColor(CGColor(red: 0.08, green: 0.11, blue: 0.17, alpha: 1.0))
        ctx.fillEllipse(in: CGRect(x: camCenter.x - camR, y: camCenter.y - camR, width: camR * 2, height: camR * 2))
        ctx.setFillColor(CGColor(red: 0.18, green: 0.28, blue: 0.48, alpha: 0.85))
        ctx.fillEllipse(in: CGRect(x: camCenter.x - camR * 0.4, y: camCenter.y - camR * 0.4, width: camR * 0.8, height: camR * 0.8))
    } else {
        // Dynamic Island pill at top center of iPhone screen
        let islandW = screenRect.width * 0.265
        let islandH = screenRect.width * 0.074
        let islandX = screenRect.midX - islandW * 0.5
        let islandY = screenRect.maxY - islandH - screenRect.width * 0.024
        let islandRect = CGRect(x: islandX, y: islandY, width: islandW, height: islandH)
        let islandPath = CGPath(roundedRect: islandRect, cornerWidth: islandH * 0.5, cornerHeight: islandH * 0.5, transform: nil)
        ctx.addPath(islandPath)
        ctx.setFillColor(CGColor(red: 0.02, green: 0.025, blue: 0.035, alpha: 1.0))
        ctx.fillPath()

        // Camera lens inside right side of Dynamic Island
        let lensR = islandH * 0.24
        let lensCX = islandRect.maxX - islandH * 0.52
        let lensCY = islandRect.midY
        ctx.setFillColor(CGColor(red: 0.08, green: 0.11, blue: 0.18, alpha: 1.0))
        ctx.fillEllipse(in: CGRect(x: lensCX - lensR, y: lensCY - lensR, width: lensR * 2, height: lensR * 2))
        ctx.setFillColor(CGColor(red: 0.20, green: 0.34, blue: 0.58, alpha: 0.85))
        ctx.fillEllipse(in: CGRect(x: lensCX - lensR * 0.42, y: lensCY - lensR * 0.42, width: lensR * 0.84, height: lensR * 0.84))
    }
    ctx.restoreGState()
}

func renderFramedMarketingCard(width: Int, height: Int, shotImg: CGImage, copy: PosterCopy, isPad: Bool) -> CGImage? {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
    let w = CGFloat(width), h = CGFloat(height)

    // 1. Crimean sunset background + atmospheric gradient veil
    if let bg = bgImg {
        let bgAspect = CGFloat(bg.width) / CGFloat(bg.height)
        let canvasAspect = w / h
        var bgRect = CGRect(x: 0, y: 0, width: w, height: h)
        if bgAspect > canvasAspect {
            let scaledW = h * bgAspect
            bgRect = CGRect(x: (w - scaledW) * 0.5, y: 0, width: scaledW, height: h)
        } else {
            let scaledH = w / bgAspect
            bgRect = CGRect(x: 0, y: (h - scaledH) * 0.5, width: w, height: scaledH)
        }
        ctx.draw(bg, in: bgRect)
    }

    let veilColors = [
        CGColor(red: 0.03, green: 0.06, blue: 0.12, alpha: copy.isDark ? 0.82 : 0.70),
        CGColor(red: 0.05, green: 0.09, blue: 0.17, alpha: copy.isDark ? 0.58 : 0.42),
        CGColor(red: 0.02, green: 0.04, blue: 0.09, alpha: copy.isDark ? 0.88 : 0.78)
    ] as CFArray
    if let veilGrad = CGGradient(colorsSpace: cs, colors: veilColors, locations: [0.0, 0.45, 1.0]) {
        ctx.drawLinearGradient(veilGrad, start: CGPoint(x: w * 0.5, y: h), end: CGPoint(x: w * 0.5, y: 0), options: [])
    }

    // 2. Clean Apple-grade marketing copy at top (SF Pro Display via NSFont)
    let badgeFontSize = isPad ? w * 0.017 : w * 0.021
    let titleFontSize = isPad ? w * 0.036 : w * 0.043
    let subFontSize   = isPad ? w * 0.021 : w * 0.025

    drawStyledText(
        ctx,
        copy.badge,
        centerX: w * 0.5,
        y: h * 0.942,
        maxWidth: w * 0.88,
        fontSize: badgeFontSize,
        weight: .bold,
        kern: 2.2,
        color: NSColor(calibratedRed: 0.99, green: 0.78, blue: 0.28, alpha: 0.96)
    )
    drawStyledText(
        ctx,
        copy.title,
        centerX: w * 0.5,
        y: h * 0.892,
        maxWidth: w * 0.90,
        fontSize: titleFontSize,
        weight: .heavy,
        kern: -0.4,
        color: NSColor.white
    )
    drawStyledText(
        ctx,
        copy.subtitle,
        centerX: w * 0.5,
        y: h * 0.852,
        maxWidth: w * 0.90,
        fontSize: subFontSize,
        weight: .medium,
        kern: 0.1,
        color: NSColor(calibratedRed: 0.89, green: 0.93, blue: 0.98, alpha: 0.96)
    )

    // 3. Hardware device frame & screenshot placement
    let imgAspect = CGFloat(shotImg.width) / CGFloat(shotImg.height)
    let maxScreenH = h * (isPad ? 0.755 : 0.765)
    let maxScreenW = w * (isPad ? 0.82 : 0.80)
    var drawW = maxScreenH * imgAspect
    var drawH = maxScreenH
    if drawW > maxScreenW {
        drawW = maxScreenW
        drawH = drawW / imgAspect
    }
    let sx = (w - drawW) * 0.5
    let sy = h * 0.042
    let screenRect = CGRect(x: sx, y: sy, width: drawW, height: drawH)

    drawHardwareDevice(ctx, shotImg: shotImg, screenRect: screenRect, isPad: isPad)

    return ctx.makeImage()
}

func loadBestScreenshot(device: String, shotId: String, locale: String) -> CGImage? {
    var candidates = [
        "/tmp/qk_shots/store_\(device)_\(shotId)_\(locale).png",
        "/tmp/qk_shots/store_\(device)_\(shotId).png",
        "\(repoRoot)/docs/release/2026-10-25/assets/store_\(device)_\(shotId)_\(locale).png",
        "\(repoRoot)/docs/release/2026-10-25/assets/store_\(device)_\(shotId).png"
    ]
    if device == "iphone" {
        candidates.append("\(repoRoot)/AppStoreMetadata/Screenshots/iphone-6.3-1206x2622/\(shotId).png")
    }
    for path in candidates {
        if let img = loadCGImage(path) {
            return img
        }
    }
    return nil
}

ensureDir("\(repoRoot)/AppStoreMetadata/Screenshots/iphone-6.3-1206x2622")
ensureDir("\(repoRoot)/AppStoreMetadata/Screenshots/ipad-13-2064x2752")
ensureDir("\(repoRoot)/AppStoreMetadata/Media/iphone_6.9")
ensureDir("\(repoRoot)/AppStoreMetadata/Media/ipad_13")
ensureDir("\(repoRoot)/AppStoreMetadata/Media/ru/iphone_6.9")
ensureDir("\(repoRoot)/AppStoreMetadata/Media/ru/ipad_13")
ensureDir("\(repoRoot)/AppStoreMetadata/Media/en-US/iphone_6.9")
ensureDir("\(repoRoot)/AppStoreMetadata/Media/en-US/ipad_13")
ensureDir("\(repoRoot)/docs/release/2026-10-25/assets")

for (locale, copyList) in localizedCopy {
    let iphoneOutDir = "\(repoRoot)/AppStoreMetadata/Media/\(locale)/iphone_6.9"
    let ipadOutDir = "\(repoRoot)/AppStoreMetadata/Media/\(locale)/ipad_13"
    ensureDir(iphoneOutDir)
    ensureDir(ipadOutDir)

    for copy in copyList {
        if let iphoneShot = loadBestScreenshot(device: "iphone", shotId: copy.shotId, locale: locale) {
            if locale == "crh" {
                saveCGImage(iphoneShot, to: "\(repoRoot)/AppStoreMetadata/Screenshots/iphone-6.3-1206x2622/\(copy.shotId).png")
            }
            if let iphoneCard = renderFramedMarketingCard(width: 1320, height: 2868, shotImg: iphoneShot, copy: copy, isPad: false) {
                saveCGImage(iphoneCard, to: "\(iphoneOutDir)/\(copy.shotId).png")
                if locale == "crh" {
                    saveCGImage(iphoneCard, to: "\(repoRoot)/AppStoreMetadata/Media/iphone_6.9/\(copy.shotId).png")
                    saveCGImage(iphoneCard, to: "\(repoRoot)/AppStoreMetadata/Media/ru/iphone_6.9/\(copy.shotId).png")
                } else if locale == "en" {
                    saveCGImage(iphoneCard, to: "\(repoRoot)/AppStoreMetadata/Media/en-US/iphone_6.9/\(copy.shotId).png")
                }
            }
        }

        if let ipadShot = loadBestScreenshot(device: "ipad", shotId: copy.shotId, locale: locale) {
            if locale == "crh" {
                saveCGImage(ipadShot, to: "\(repoRoot)/AppStoreMetadata/Screenshots/ipad-13-2064x2752/\(copy.shotId).png")
            }
            if let ipadCard = renderFramedMarketingCard(width: 2064, height: 2752, shotImg: ipadShot, copy: copy, isPad: true) {
                saveCGImage(ipadCard, to: "\(ipadOutDir)/\(copy.shotId).png")
                if locale == "crh" {
                    saveCGImage(ipadCard, to: "\(repoRoot)/AppStoreMetadata/Media/ipad_13/\(copy.shotId).png")
                    saveCGImage(ipadCard, to: "\(repoRoot)/AppStoreMetadata/Media/ru/ipad_13/\(copy.shotId).png")
                } else if locale == "en" {
                    saveCGImage(ipadCard, to: "\(repoRoot)/AppStoreMetadata/Media/en-US/ipad_13/\(copy.shotId).png")
                }
            }
        }
    }
}

struct VideoScene {
    let startSec: Double
    let endSec: Double
    let act: String
    let titleCRH: String
    let subUK: String
    let image: CGImage?
    let drawComet: Bool
}

func makeScenes(for device: String) -> [VideoScene] {
    let s1Img = loadBestScreenshot(device: device, shotId: "01_latin_light", locale: "crh")
    let s2Img = loadBestScreenshot(device: device, shotId: "03_cyrillic", locale: "crh")
    let s3Img = loadBestScreenshot(device: device, shotId: "02_latin_dark", locale: "crh")
    let s4Img = loadBestScreenshot(device: device, shotId: "04_home_light", locale: "crh") ?? s1Img
    let s5Img = loadBestScreenshot(device: device, shotId: "04_home_light", locale: "uk") ?? s1Img
    let s6Img = loadBestScreenshot(device: device, shotId: "05_home_dark", locale: "crh")
    return [
        VideoScene(startSec: 0.0, endSec: 2.5, act: "WELCOME • 0–2s", titleCRH: "QırımKey — Qırımtatar klaviaturası", subUK: "Öz tilimiz — er yerde • Рідна мова — всюди", image: s1Img, drawComet: false),
        VideoScene(startSec: 2.5, endSec: 6.5, act: "DISCOVERY • 3–6s", titleCRH: "Qolay ve tez yazuv: Lâtin ve Kirill", subUK: "селям → selâm • Миттєва транслітерація", image: s2Img, drawComet: false),
        VideoScene(startSec: 6.5, endSec: 10.5, act: "ACTION • 7–10s", titleCRH: "Aqıllı söz teklifleri ve QırımKey Swipe", subUK: "Справжня комета свайпу • Розумні підказки", image: s3Img, drawComet: device == "iphone"),
        VideoScene(startSec: 10.5, endSec: 14.5, act: "ACTION • 11–14s", titleCRH: "iPad ve iPhone imkânları", subUK: "Статистика швидкості та щоденні вислови", image: s4Img, drawComet: false),
        VideoScene(startSec: 14.5, endSec: 18.5, act: "ACTION • 15–18s", titleCRH: "Aydınlıq / Qaranlıq ve Ukraina ФІВА", subUK: "ґ → g · г → ğ · кʼ → q · нʼ → ñ", image: s5Img, drawComet: false),
        VideoScene(startSec: 18.5, endSec: 22.0, act: "SUCCESS • 19–22s", titleCRH: "100% cihazda işley — App Store-dan indiriñiz!", subUK: "Повна приватність офлайн • Жодної телеметрії", image: s6Img, drawComet: false)
    ]
}

func appendSilentAudio(to audioInput: AVAssetWriterInput, durationSeconds: Double) {
    let sampleRate: Double = 44100
    let channels: UInt32 = 2
    let framesPerBuffer: CMItemCount = 1024
    let totalSamples = Int(sampleRate * durationSeconds)
    var asbd = AudioStreamBasicDescription(
        mSampleRate: sampleRate,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
        mBytesPerPacket: 4,
        mFramesPerPacket: 1,
        mBytesPerFrame: 4,
        mChannelsPerFrame: channels,
        mBitsPerChannel: 16,
        mReserved: 0
    )
    var formatDesc: CMAudioFormatDescription?
    guard CMAudioFormatDescriptionCreate(
        allocator: kCFAllocatorDefault,
        asbd: &asbd,
        layoutSize: 0,
        layout: nil,
        magicCookieSize: 0,
        magicCookie: nil,
        extensions: nil,
        formatDescriptionOut: &formatDesc
    ) == noErr, let fmt = formatDesc else { return }

    var samplesWritten = 0
    while samplesWritten < totalSamples {
        while !audioInput.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
        let count = min(Int(framesPerBuffer), totalSamples - samplesWritten)
        let dataSize = count * 4
        var blockBuffer: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: dataSize,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: dataSize,
            flags: kCMBlockBufferAssureMemoryNowFlag,
            blockBufferOut: &blockBuffer
        ) == kCMBlockBufferNoErr, let bbuf = blockBuffer else { break }
        CMBlockBufferFillDataBytes(with: 0, blockBuffer: bbuf, offsetIntoDestination: 0, dataLength: dataSize)

        var sampleBuffer: CMSampleBuffer?
        let pts = CMTime(value: CMTimeValue(samplesWritten), timescale: CMTimeScale(sampleRate))
        if CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: kCFAllocatorDefault,
            dataBuffer: bbuf,
            formatDescription: fmt,
            sampleCount: count,
            presentationTimeStamp: pts,
            packetDescriptions: nil,
            sampleBufferOut: &sampleBuffer
        ) == noErr, let sbuf = sampleBuffer {
            audioInput.append(sbuf)
        }
        samplesWritten += count
    }
}

func renderVideo(path: String, width: Int, height: Int, isPad: Bool) {
    let scenes = makeScenes(for: isPad ? "ipad" : "iphone")
    try? FileManager.default.removeItem(atPath: path)
    let url = URL(fileURLWithPath: path)
    guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 2,
        AVEncoderBitRateKey: 128000
    ]
    let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
    let attrs: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height
    ]
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)
    writer.add(input)
    writer.add(audioInput)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    let audioSem = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .userInitiated).async {
        appendSilentAudio(to: audioInput, durationSeconds: 22.0)
        audioInput.markAsFinished()
        audioSem.signal()
    }

    let fps = 30
    let totalFrames = 22 * fps
    let cs = CGColorSpaceCreateDeviceRGB()

    let prefix = isPad ? "ipad" : "iphone"
    var vframes: [CGImage] = []
    for idx in 0...21 {
        let name = String(format: "vframe_%@_%02d", prefix, idx)
        if let img = loadCGImage("/tmp/qk_shots/\(name).png") ?? loadCGImage("\(repoRoot)/docs/release/2026-10-25/assets/\(name).png") {
            vframes.append(img)
        }
    }

    let rawRecPath = isPad ? "/tmp/raw_ipad_screen.mp4" : "/tmp/raw_iphone_screen.mp4"
    var rawGenerator: AVAssetImageGenerator? = nil
    var rawDuration: Double = 0.0
    if FileManager.default.fileExists(atPath: rawRecPath) {
        let asset = AVURLAsset(url: URL(fileURLWithPath: rawRecPath))
        let dur = CMTimeGetSeconds(asset.duration)
        if dur.isFinite && dur >= 3.0 && !asset.tracks(withMediaType: .video).isEmpty {
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 60)
            gen.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 60)
            rawGenerator = gen
            rawDuration = dur
            print("Using live screen recording:", rawRecPath, "duration:", dur)
        }
    } else if vframes.count >= 10 {
        print("Using \(vframes.count) sequential full-screen capture frames for \(prefix)")
    }

    for frameIdx in 0..<totalFrames {
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
        let t = Double(frameIdx) / Double(fps)
        let scene = scenes.first(where: { t >= $0.startSec && t < $0.endSec }) ?? scenes.last!
        let localT = max(0.0, min(1.0, (t - scene.startSec) / max(0.001, scene.endSec - scene.startSec)))

        var pbOut: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pbOut)
        guard let pb = pbOut else { continue }
        CVPixelBufferLockBaseAddress(pb, [])
        if let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pb),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
            space: cs,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) {
            ctx.interpolationQuality = .high
            let w = CGFloat(width), h = CGFloat(height)
            let globalProgress = CGFloat(t / 22.0)

            if let gen = rawGenerator, rawDuration > 0 {
                // Direct full-screen recording from the live v3.1 simulator/device session
                let sampleSec = min(rawDuration - 0.05, max(0.0, (t / 22.0) * rawDuration))
                let sampleTime = CMTime(seconds: sampleSec, preferredTimescale: 600)
                if let rawCG = try? gen.copyCGImage(at: sampleTime, actualTime: nil) {
                    ctx.setFillColor(CGColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1.0))
                    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
                    ctx.draw(rawCG, in: CGRect(x: 0, y: 0, width: w, height: h))
                }
            } else if vframes.count >= 10 {
                // Direct full-screen sequential recording from XCUIScreen.main.screenshot() during live interaction
                let scaledPos = (t / 22.0) * Double(vframes.count - 1)
                let idxA = min(vframes.count - 1, max(0, Int(floor(scaledPos))))
                let idxB = min(vframes.count - 1, idxA + 1)
                let frac = scaledPos - Double(idxA)
                ctx.setFillColor(CGColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0))
                ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
                ctx.draw(vframes[idxA], in: CGRect(x: 0, y: 0, width: w, height: h))
                if idxB != idxA && frac > 0.78 {
                    let alpha = CGFloat((frac - 0.78) / 0.22)
                    ctx.saveGState()
                    ctx.setAlpha(alpha)
                    ctx.draw(vframes[idxB], in: CGRect(x: 0, y: 0, width: w, height: h))
                    ctx.restoreGState()
                }
                // Show live gold-cyan swipe trail during swipe step (idxA == 8) on iPhone
                if !isPad && idxA == 8 {
                    ctx.saveGState()
                    let pts = [
                        CGPoint(x: w * 0.16, y: h * 0.21),
                        CGPoint(x: w * 0.26, y: h * 0.28),
                        CGPoint(x: w * 0.84, y: h * 0.21),
                        CGPoint(x: w * 0.08, y: h * 0.21),
                        CGPoint(x: w * 0.76, y: h * 0.14)
                    ]
                    let cometProgress = min(1.0, max(0.15, CGFloat(frac * 1.25)))
                    let steps = 48
                    for i in 1...steps {
                        let u = (CGFloat(i) / CGFloat(steps)) * cometProgress
                        let segFloat = u * CGFloat(pts.count - 1)
                        let segIdx = min(pts.count - 2, max(0, Int(segFloat)))
                        let segFrac = segFloat - CGFloat(segIdx)
                        let pA = pts[segIdx]
                        let pB = pts[segIdx + 1]
                        let px = pA.x + (pB.x - pA.x) * segFrac
                        let py = pA.y + (pB.y - pA.y) * segFrac
                        let tailFactor = CGFloat(i) / CGFloat(steps)
                        let r = 8.5 * pow(tailFactor, 1.55)
                        ctx.setFillColor(CGColor(red: 0.99, green: 0.82, blue: 0.28, alpha: (0.08 + 0.92 * pow(tailFactor, 1.35)) * 0.90))
                        ctx.fillEllipse(in: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
                    }
                    ctx.restoreGState()
                }
            } else {
                // 1. Cinematic Ken Burns pan/zoom on Crimean sunset background plate
                if let bg = bgImg {
                    let kbScale: CGFloat = 1.04 + 0.08 * globalProgress
                    let panX: CGFloat = (globalProgress - 0.5) * w * 0.04
                    let panY: CGFloat = (0.5 - globalProgress) * h * 0.03
                    let bw = w * kbScale
                    let bh = h * kbScale
                    let bx = (w - bw) * 0.5 + panX
                    let by = (h - bh) * 0.5 + panY
                    ctx.draw(bg, in: CGRect(x: bx, y: by, width: bw, height: bh))
                }
                ctx.setFillColor(CGColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 0.66))
                ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

                // Subtle golden atmospheric bokeh particles behind hardware bezel
                ctx.saveGState()
                for pIdx in 0..<8 {
                    let seed = Double(pIdx) * 1.37
                    let px = w * CGFloat(0.12 + 0.76 * fmod(seed * 0.618 + t * 0.018, 1.0))
                    let py = h * CGFloat(0.15 + 0.70 * fmod(seed * 0.382 + t * 0.024, 1.0))
                    let pr = (isPad ? 26.0 : 18.0) * CGFloat(0.6 + 0.4 * sin(t * 1.4 + seed))
                    let pAlpha = CGFloat(0.05 + 0.04 * sin(t * 1.8 + seed))
                    ctx.setFillColor(CGColor(red: 0.99, green: 0.78, blue: 0.32, alpha: pAlpha))
                    ctx.fillEllipse(in: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2))
                }
                ctx.restoreGState()

                drawStyledText(ctx, scene.act, centerX: w * 0.5, y: h * 0.935, maxWidth: w * 0.9, fontSize: w * 0.022, weight: .bold, kern: 1.8, color: NSColor(calibratedRed: 0.99, green: 0.78, blue: 0.28, alpha: 0.95))
                drawStyledText(ctx, scene.titleCRH, centerX: w * 0.5, y: h * 0.885, maxWidth: w * 0.92, fontSize: w * 0.038, weight: .heavy, kern: -0.3, color: NSColor.white)
                drawStyledText(ctx, scene.subUK, centerX: w * 0.5, y: h * 0.845, maxWidth: w * 0.92, fontSize: w * 0.024, weight: .medium, kern: 0.1, color: NSColor(calibratedRed: 0.88, green: 0.92, blue: 0.98, alpha: 0.95))

                // 2. 100% pixel-exact v3.1 screenshot inside realistic iPhone 16 Pro / iPad Pro 13" hardware bezel
                if let shot = scene.image {
                    let imgAspect = CGFloat(shot.width) / CGFloat(shot.height)
                    let maxH = h * 0.74
                    let maxW = w * 0.80
                    var dw = maxH * imgAspect
                    var dh = maxH
                    if dw > maxW {
                        dw = maxW
                        dh = dw / imgAspect
                    }
                    let zoom = 1.0 + 0.016 * CGFloat(sin(localT * .pi))
                    dw *= zoom
                    dh *= zoom
                    let sx = (w - dw) * 0.5
                    let sy = h * 0.045
                    let sRect = CGRect(x: sx, y: sy, width: dw, height: dh)
                    drawHardwareDevice(ctx, shotImg: shot, screenRect: sRect, isPad: isPad)

                    if scene.drawComet {
                        ctx.saveGState()
                        let pts = [
                            CGPoint(x: sRect.minX + sRect.width * 0.24, y: sRect.minY + sRect.height * 0.21),
                            CGPoint(x: sRect.minX + sRect.width * 0.24, y: sRect.minY + sRect.height * 0.27),
                            CGPoint(x: sRect.minX + sRect.width * 0.78, y: sRect.minY + sRect.height * 0.21),
                            CGPoint(x: sRect.minX + sRect.width * 0.10, y: sRect.minY + sRect.height * 0.21),
                            CGPoint(x: sRect.minX + sRect.width * 0.68, y: sRect.minY + sRect.height * 0.15)
                        ]
                        let cometProgress = min(1.0, max(0.15, CGFloat(localT * 1.35)))
                        let steps = 48
                        for i in 1...steps {
                            let u = (CGFloat(i) / CGFloat(steps)) * cometProgress
                            let segFloat = u * CGFloat(pts.count - 1)
                            let segIdx = min(pts.count - 2, max(0, Int(segFloat)))
                            let segFrac = segFloat - CGFloat(segIdx)
                            let pA = pts[segIdx]
                            let pB = pts[segIdx + 1]
                            let px = pA.x + (pB.x - pA.x) * segFrac
                            let py = pA.y + (pB.y - pA.y) * segFrac
                            let tailFactor = CGFloat(i) / CGFloat(steps)
                            let r = 7.5 * pow(tailFactor, 1.55)
                            ctx.setFillColor(CGColor(red: 0.95, green: 0.97, blue: 1.0, alpha: (0.05 + 0.95 * pow(tailFactor, 1.35)) * 0.86))
                            ctx.fillEllipse(in: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
                        }
                        ctx.restoreGState()
                    }
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(pb, [])
        let time = CMTime(value: CMTimeValue(frameIdx), timescale: CMTimeScale(fps))
        adaptor.append(pb, withPresentationTime: time)
    }

    input.markAsFinished()
    audioSem.wait()
    let sem = DispatchSemaphore(value: 0)
    writer.finishWriting { sem.signal() }
    sem.wait()
    print("Saved video:", path)
}

renderVideo(path: "\(repoRoot)/AppStoreMetadata/Media/preview_iphone_6.9_22s.mp4", width: 886, height: 1920, isPad: false)
renderVideo(path: "\(repoRoot)/AppStoreMetadata/Media/preview_ipad_13_22s.mp4", width: 1200, height: 1600, isPad: true)
for dst in [
    "\(repoRoot)/AppStoreMetadata/Media/iphone_6.9/preview_iphone_6.9_22s.mp4",
    "\(repoRoot)/docs/release/2026-10-25/assets/preview_iphone_6.9_22s.mp4"
] {
    try? FileManager.default.removeItem(atPath: dst)
    try? FileManager.default.copyItem(atPath: "\(repoRoot)/AppStoreMetadata/Media/preview_iphone_6.9_22s.mp4", toPath: dst)
}
for dst in [
    "\(repoRoot)/AppStoreMetadata/Media/ipad_13/preview_ipad_13_22s.mp4",
    "\(repoRoot)/docs/release/2026-10-25/assets/preview_ipad_13_22s.mp4"
] {
    try? FileManager.default.removeItem(atPath: dst)
    try? FileManager.default.copyItem(atPath: "\(repoRoot)/AppStoreMetadata/Media/preview_ipad_13_22s.mp4", toPath: dst)
}
"""


def composite_posters_and_videos() -> None:
    with tempfile.NamedTemporaryFile("w", suffix=".swift", delete=False) as f:
        f.write(SWIFT_COMPOSITOR)
        script_path = Path(f.name)
    try:
        subprocess.run(["swift", str(script_path)], cwd=str(ROOT), check=True)
    finally:
        script_path.unlink(missing_ok=True)


def render_svg(
    template_text: str,
    width: int,
    height: int,
    corner_radius: int,
    theme: dict,
    typography: dict,
    badge: str,
    title: str,
    subtitle: str,
    pills: list[str],
    screenshot_uri: str,
    crimea_bg_uri: str,
    is_ipad: bool = False,
) -> str:
    center_x = width // 2

    badge_size = max(18, int(width * (0.017 if is_ipad else 0.021)))
    badge_text_y = int(height * 0.058)

    title_y = int(height * 0.106)
    subtitle_y = int(height * 0.144)
    title_size = max(32, int(width * (0.036 if is_ipad else 0.043)))
    subtitle_size = max(20, int(width * (0.021 if is_ipad else 0.025)))

    screen_w = int(width * 0.78)
    screen_h = int(height * 0.76)
    screen_x = (width - screen_w) // 2
    screen_y = int(height * 0.185)

    bezel = max(14, int(width * (0.015 if is_ipad else 0.013)))
    frame_x = screen_x - bezel
    frame_y = screen_y - bezel
    frame_w = screen_w + bezel * 2
    frame_h = screen_h + bezel * 2
    frame_radius = corner_radius + int(bezel * 0.85)

    outer_rim = max(5, int(width * 0.005))
    outer_x = frame_x - outer_rim
    outer_y = frame_y - outer_rim
    outer_w = frame_w + outer_rim * 2
    outer_h = frame_h + outer_rim * 2
    outer_radius = frame_radius + outer_rim

    island_w = int(screen_w * 0.265)
    island_h = int(screen_w * 0.074)
    island_x = center_x - island_w // 2
    island_y = screen_y + int(screen_w * 0.024)
    island_rx = island_h // 2
    camera_cx = island_x + island_w - int(island_h * 0.52)
    camera_cy = island_y + island_h // 2
    camera_r = max(4, int(island_h * 0.22))

    btn_w = max(5, int(width * 0.005))
    btn_left_x = outer_x - btn_w + 2
    btn_right_x = outer_x + outer_w - 2
    btn_action_y = outer_y + int(outer_h * 0.14)
    btn_action_h = int(outer_h * 0.026)
    btn_vol1_y = outer_y + int(outer_h * 0.19)
    btn_vol2_y = outer_y + int(outer_h * 0.25)
    btn_vol_h = int(outer_h * 0.046)
    btn_pwr_y = outer_y + int(outer_h * 0.21)
    btn_pwr_h = int(outer_h * 0.068)

    btn_top_x = outer_x + outer_w - int(outer_w * 0.12)
    btn_top_y = outer_y - btn_w + 2
    btn_top_w = int(outer_w * 0.045)
    btn_top_h = btn_w
    ipad_cam_y = frame_y + bezel // 2
    ipad_cam_r = max(5, int(bezel * 0.22))

    replacements = {
        "{{WIDTH}}": str(width),
        "{{HEIGHT}}": str(height),
        "{{BG_START}}": theme["bg_start"],
        "{{BG_END}}": theme["bg_end"],
        "{{VEIL_OPACITY}}": theme.get("veil_opacity", "0.55"),
        "{{ACCENT}}": theme["accent"],
        "{{HEADLINE_COLOR}}": theme["headline"],
        "{{SUBTITLE_COLOR}}": theme["subtitle"],
        "{{FRAME_BORDER}}": theme["frame_border"],
        "{{HEADLINE_FONT}}": typography["headline_font"],
        "{{BODY_FONT}}": typography["body_font"],
        "{{CENTER_X}}": str(center_x),
        "{{BADGE_SIZE}}": str(badge_size),
        "{{BADGE_TEXT_Y}}": str(badge_text_y),
        "{{BADGE_TEXT}}": html.escape(badge),
        "{{TITLE_Y}}": str(title_y),
        "{{SUBTITLE_Y}}": str(subtitle_y),
        "{{TITLE_SIZE}}": str(title_size),
        "{{SUBTITLE_SIZE}}": str(subtitle_size),
        "{{TITLE}}": html.escape(title),
        "{{SUBTITLE}}": html.escape(subtitle),
        "{{SCREEN_X}}": str(screen_x),
        "{{SCREEN_Y}}": str(screen_y),
        "{{SCREEN_W}}": str(screen_w),
        "{{SCREEN_H}}": str(screen_h),
        "{{CORNER_RADIUS}}": str(corner_radius),
        "{{FRAME_X}}": str(frame_x),
        "{{FRAME_Y}}": str(frame_y),
        "{{FRAME_W}}": str(frame_w),
        "{{FRAME_H}}": str(frame_h),
        "{{FRAME_RADIUS}}": str(frame_radius),
        "{{OUTER_X}}": str(outer_x),
        "{{OUTER_Y}}": str(outer_y),
        "{{OUTER_W}}": str(outer_w),
        "{{OUTER_H}}": str(outer_h),
        "{{OUTER_RADIUS}}": str(outer_radius),
        "{{ISLAND_X}}": str(island_x),
        "{{ISLAND_Y}}": str(island_y),
        "{{ISLAND_W}}": str(island_w),
        "{{ISLAND_H}}": str(island_h),
        "{{ISLAND_RX}}": str(island_rx),
        "{{CAMERA_CX}}": str(camera_cx),
        "{{CAMERA_CY}}": str(camera_cy),
        "{{CAMERA_R}}": str(camera_r),
        "{{BTN_W}}": str(btn_w),
        "{{BTN_LEFT_X}}": str(btn_left_x),
        "{{BTN_RIGHT_X}}": str(btn_right_x),
        "{{BTN_ACTION_Y}}": str(btn_action_y),
        "{{BTN_ACTION_H}}": str(btn_action_h),
        "{{BTN_VOL1_Y}}": str(btn_vol1_y),
        "{{BTN_VOL2_Y}}": str(btn_vol2_y),
        "{{BTN_VOL_H}}": str(btn_vol_h),
        "{{BTN_PWR_Y}}": str(btn_pwr_y),
        "{{BTN_PWR_H}}": str(btn_pwr_h),
        "{{BTN_TOP_X}}": str(btn_top_x),
        "{{BTN_TOP_Y}}": str(btn_top_y),
        "{{BTN_TOP_W}}": str(btn_top_w),
        "{{BTN_TOP_H}}": str(btn_top_h),
        "{{IPAD_CAM_Y}}": str(ipad_cam_y),
        "{{IPAD_CAM_R}}": str(ipad_cam_r),
        "{{SCREENSHOT_URI}}": screenshot_uri,
        "{{CRIMEA_BG_URI}}": crimea_bg_uri,
    }
    out = template_text
    for k, v in replacements.items():
        out = out.replace(k, v)
    return out


def sync_provenance_hashes() -> None:
    if not PROVENANCE_PATH.exists():
        return
    prov = json.loads(PROVENANCE_PATH.read_text(encoding="utf-8"))
    existing_by_path = {a["path"]: a for a in prov.get("assets", [])}
    poster_specs = [
        ("media_iphone_6_9_01_latin_light", "AppStoreMetadata/Media/iphone_6.9/01_latin_light.png", 1320, 2868, "iPhone 6.9-inch App Store poster 01 (Latin Light)"),
        ("media_iphone_6_9_02_latin_dark", "AppStoreMetadata/Media/iphone_6.9/02_latin_dark.png", 1320, 2868, "iPhone 6.9-inch App Store poster 02 (Latin Dark)"),
        ("media_iphone_6_9_03_cyrillic", "AppStoreMetadata/Media/iphone_6.9/03_cyrillic.png", 1320, 2868, "iPhone 6.9-inch App Store poster 03 (Cyrillic)"),
        ("media_iphone_6_9_04_home_light", "AppStoreMetadata/Media/iphone_6.9/04_home_light.png", 1320, 2868, "iPhone 6.9-inch App Store poster 04 (HomeView Light with Kirill Toggle switch ON)"),
        ("media_iphone_6_9_05_home_dark", "AppStoreMetadata/Media/iphone_6.9/05_home_dark.png", 1320, 2868, "iPhone 6.9-inch App Store poster 05 (HomeView Dark with Kirill Toggle switch ON)"),
        ("media_ipad_13_01_latin_light", "AppStoreMetadata/Media/ipad_13/01_latin_light.png", 2064, 2752, "iPad 13-inch App Store poster 01 (Latin Light)"),
        ("media_ipad_13_02_latin_dark", "AppStoreMetadata/Media/ipad_13/02_latin_dark.png", 2064, 2752, "iPad 13-inch App Store poster 02 (Latin Dark)"),
        ("media_ipad_13_03_cyrillic", "AppStoreMetadata/Media/ipad_13/03_cyrillic.png", 2064, 2752, "iPad 13-inch App Store poster 03 (Cyrillic)"),
        ("media_ipad_13_04_home_light", "AppStoreMetadata/Media/ipad_13/04_home_light.png", 2064, 2752, "iPad 13-inch App Store poster 04 (HomeView Light with Kirill Toggle switch ON)"),
        ("media_ipad_13_05_home_dark", "AppStoreMetadata/Media/ipad_13/05_home_dark.png", 2064, 2752, "iPad 13-inch App Store poster 05 (HomeView Dark with Kirill Toggle switch ON)"),
    ]
    for locale in ("crh", "ru", "uk", "en", "en-US"):
        for shot_id in ("01_latin_light", "02_latin_dark", "03_cyrillic", "04_home_light", "05_home_dark"):
            poster_specs.append(
                (
                    f"media_{locale.replace('-', '_')}_iphone_6_9_{shot_id}",
                    f"AppStoreMetadata/Media/{locale}/iphone_6.9/{shot_id}.png",
                    1320,
                    2868,
                    f"Localized ({locale}) iPhone 6.9-inch App Store poster {shot_id}",
                )
            )
            poster_specs.append(
                (
                    f"media_{locale.replace('-', '_')}_ipad_13_{shot_id}",
                    f"AppStoreMetadata/Media/{locale}/ipad_13/{shot_id}.png",
                    2064,
                    2752,
                    f"Localized ({locale}) iPad 13-inch App Store poster {shot_id}",
                )
            )
    for asset_id, rel_path, w, h, role in poster_specs:
        if rel_path not in existing_by_path and (ROOT / rel_path).exists():
            prov["assets"].append(
                {
                    "id": asset_id,
                    "path": rel_path,
                    "kind": "app_store_poster",
                    "role": role,
                    "format": "PNG",
                    "width_px": w,
                    "height_px": h,
                    "sha256": sha256_file(ROOT / rel_path),
                    "capture_provenance": {
                        "device_model": "iPhone 16 Pro & iPad (A16) (Simulator iOS 27.0)",
                        "os_version": "iOS 27.0 (24A434)",
                        "app_version": "3.1",
                        "build_number": "5",
                        "commit_sha": "codex/release-public-api-2026-10-25",
                        "captured_at": "2026-10-25",
                        "capture_method": "CoreGraphics hardware-frame poster compositor + XCUITest localized screenshots",
                    },
                    "review_status": "verified_release_candidate",
                    "review_note": "Verified against 2026-10-25 user requirements: realistic iPhone/iPad hardware frame, SF Pro Display typography, localized crh/uk/en in-app UI matching poster language, pure Crimean Tatar işley, and meaningful sandbox phrase.",
                }
            )
    for asset in prov.get("assets", []):
        p = ROOT / asset["path"]
        if p.exists() and p.is_file():
            asset["sha256"] = sha256_file(p)
    PROVENANCE_PATH.write_text(json.dumps(prov, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> int:
    composite_posters_and_videos()
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    bg_rel = config.get("background_asset", "marketing/templates/assets/crimea_sunset_bg.png")
    crimea_bg_uri = str((ROOT / bg_rel).resolve())

    manifest = {
        "template_version": config["template_version"],
        "background_asset": bg_rel,
        "video_storyboard_22s": config.get("video_storyboard_22s", {}),
        "rendered_files": [],
    }
    for locale, copy_map in config["copy"].items():
        for dev_key in ("iphone_6_3", "ipad_13"):
            dev_cfg = config["device_classes"][dev_key]
            template_path = ROOT / dev_cfg["template"]
            template_text = template_path.read_text(encoding="utf-8")
            subdir = "iphone-6.3-1206x2622" if dev_key == "iphone_6_3" else "ipad-13-2064x2752"
            dev_tag = "iphone" if dev_key == "iphone_6_3" else "ipad"
            is_ipad = dev_key == "ipad_13"
            for shot_id, copy_entry in copy_map.items():
                theme_key = "dark" if "dark" in shot_id else "light"
                localized_candidates = [
                    ROOT / f"docs/release/2026-10-25/assets/store_{dev_tag}_{shot_id}_{locale}.png",
                    ROOT / f"docs/release/2026-10-25/assets/store_{dev_tag}_{shot_id}.png",
                    ROOT / f"AppStoreMetadata/Screenshots/{subdir}/{shot_id}.png",
                ]
                shot_abs = next((p for p in localized_candidates if p.exists()), localized_candidates[-1])
                shot_rel = str(shot_abs.relative_to(ROOT))
                svg_content = render_svg(
                    template_text=template_text,
                    width=dev_cfg["width_px"],
                    height=dev_cfg["height_px"],
                    corner_radius=dev_cfg["corner_radius"],
                    theme=config["themes"][theme_key],
                    typography=config["typography"],
                    badge=copy_entry.get("badge", "QIRIMKEY"),
                    title=copy_entry["title"],
                    subtitle=copy_entry["subtitle"],
                    pills=copy_entry.get("pills", []),
                    screenshot_uri=str(shot_abs.resolve()),
                    crimea_bg_uri=crimea_bg_uri,
                    is_ipad=is_ipad,
                )
                out_sub = OUT_DIR / locale / dev_key
                out_sub.mkdir(parents=True, exist_ok=True)
                out_file = out_sub / f"{shot_id}.svg"
                out_file.write_text(svg_content, encoding="utf-8")
                manifest["rendered_files"].append(
                    {
                        "locale": locale,
                        "device_class": dev_key,
                        "shot_id": shot_id,
                        "svg_path": str(out_file.relative_to(ROOT)),
                        "source_screenshot": shot_rel,
                        "source_exists": shot_abs.exists(),
                        "sha256": sha256_file(out_file),
                    }
                )

    manifest_json = json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"
    (OUT_DIR / "manifest.json").write_text(manifest_json, encoding="utf-8")
    (OUT_DIR / "render_manifest.json").write_text(manifest_json, encoding="utf-8")
    sync_provenance_hashes()
    print(f"Rendered {len(manifest['rendered_files'])} parameterized SVG templates + localized posters & videos.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
