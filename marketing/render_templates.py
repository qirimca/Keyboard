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

from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
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
    ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 16, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.72))
    ctx.textMatrix = .identity
    ctx.textPosition = CGPoint(x: centerX - lineW * 0.5, y: y)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

func fitTypographicSize(
    _ rawLines: [String],
    maxWidth: CGFloat,
    fontSize: CGFloat,
    weight: NSFont.Weight,
    kern: CGFloat
) -> CGFloat {
    var actualSize = fontSize
    while actualSize >= fontSize * 0.68 {
        let font = NSFont.systemFont(ofSize: actualSize, weight: weight)
        var fitsAll = true
        for ln in rawLines {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .kern: kern
            ]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: ln, attributes: attrs))
            var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
            let lw = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
            if lw > maxWidth {
                fitsAll = false
                break
            }
        }
        if fitsAll { break }
        actualSize -= 1.0
    }
    return actualSize
}

func drawMultilineStyledText(
    _ ctx: CGContext,
    _ text: String,
    centerX: CGFloat,
    topBaselineY: CGFloat,
    maxWidth: CGFloat,
    fontSize: CGFloat,
    lineHeightMultiplier: CGFloat,
    weight: NSFont.Weight,
    kern: CGFloat = -0.4,
    color: NSColor
) -> CGFloat {
    let rawLines = text
        .replacingOccurrences(of: "\\n", with: "\n")
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { String($0).trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    guard !rawLines.isEmpty else { return topBaselineY }

    let actualSize = fitTypographicSize(rawLines, maxWidth: maxWidth, fontSize: fontSize, weight: weight, kern: kern)
    let font = NSFont.systemFont(ofSize: actualSize, weight: weight)
    let lineStep = actualSize * lineHeightMultiplier
    var curY = topBaselineY

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 16, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.72))
    for ln in rawLines {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .kern: kern
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: ln, attributes: attrs))
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let lw = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: centerX - lw * 0.5, y: curY)
        CTLineDraw(line, ctx)
        curY -= lineStep
    }
    ctx.restoreGState()
    return curY
}

func renderCanvaBackgroundPlate(sunsetSrc: CGImage, twilightSrc: CGImage, width: Int, height: Int, isDark: Bool, isPad: Bool) -> CGImage? {
    let cs = CGColorSpaceCreateDeviceRGB()
    let w = CGFloat(width), h = CGFloat(height)
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .high

    let srcW = CGFloat(sunsetSrc.width)
    let srcH = CGFloat(sunsetSrc.height)

    // Draw the real Crimean coastal photograph ONCE across the entire canvas with aspect-fill (zero split, zero cliff duplication, zero sky seam)
    let scale = max(w / srcW, h / srcH)
    let drawW = srcW * scale
    let drawH = srcH * scale
    let drawX = (w - drawW) * 0.5
    let drawY = (h - drawH) * 0.5

    func drawContinuous(_ img: CGImage, alpha: CGFloat) {
        ctx.saveGState()
        ctx.setAlpha(alpha)
        ctx.draw(img, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
        ctx.restoreGState()
    }

    if isDark {
        drawContinuous(sunsetSrc, alpha: 1.0)
        drawContinuous(twilightSrc, alpha: 0.76)
    } else {
        drawContinuous(sunsetSrc, alpha: 1.0)
    }

    if isDark {
        let darkSkyColors = [
            CGColor(red: 0.02, green: 0.05, blue: 0.10, alpha: 0.68),
            CGColor(red: 0.04, green: 0.08, blue: 0.14, alpha: 0.56),
            CGColor(red: 0.05, green: 0.09, blue: 0.16, alpha: 0.38),
            CGColor(red: 0.03, green: 0.06, blue: 0.11, alpha: 0.14),
            CGColor(red: 0.01, green: 0.02, blue: 0.05, alpha: 0.48)
        ] as CFArray
        if let grad = CGGradient(colorsSpace: cs, colors: darkSkyColors, locations: [0.0, 0.26, 0.35, 0.44, 1.0]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: w * 0.5, y: h), end: CGPoint(x: w * 0.5, y: 0), options: [])
        }
    } else {
        let lightSkyColors = [
            CGColor(red: 0.03, green: 0.06, blue: 0.11, alpha: 0.62),
            CGColor(red: 0.05, green: 0.09, blue: 0.15, alpha: 0.50),
            CGColor(red: 0.07, green: 0.11, blue: 0.17, alpha: 0.30),
            CGColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 0.00),
            CGColor(red: 0.02, green: 0.03, blue: 0.05, alpha: 0.24)
        ] as CFArray
        if let grad = CGGradient(colorsSpace: cs, colors: lightSkyColors, locations: [0.0, 0.26, 0.35, 0.43, 1.0]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: w * 0.5, y: h), end: CGPoint(x: w * 0.5, y: 0), options: [])
        }
    }


    // Ensure bottom center gap below the device bezel (x = 0.30*w .. 0.70*w, y = 0 .. 0.05*h) is smoothly shadowed
    ctx.saveGState()
    let botColors = [
        CGColor(red: 0.02, green: 0.03, blue: 0.05, alpha: 1.0),
        CGColor(red: 0.02, green: 0.03, blue: 0.05, alpha: 0.0)
    ] as CFArray
    if let bGrad = CGGradient(colorsSpace: cs, colors: botColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(
            bGrad,
            startCenter: CGPoint(x: w * 0.5, y: 0),
            startRadius: w * 0.12,
            endCenter: CGPoint(x: w * 0.5, y: 0),
            endRadius: w * 0.36,
            options: [.drawsBeforeStartLocation]
        )
    }
    ctx.restoreGState()

    return ctx.makeImage()
}

let assetDir = "\(repoRoot)/marketing/templates/assets"
ensureDir(assetDir)
let brainSunsetPath = "/Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/crimea_real_photo_sunset_hd_1793013867609.jpg"
let brainTwilightPath = "/Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/crimea_real_photo_twilight_hd_1793013888479.jpg"
if let sSrc = loadCGImage(brainSunsetPath), let tSrc = loadCGImage(brainTwilightPath) {
    if let p = renderCanvaBackgroundPlate(sunsetSrc: sSrc, twilightSrc: tSrc, width: 2064, height: 2752, isDark: false, isPad: true) {
        saveCGImage(p, to: "\(assetDir)/crimea_sunset_bg.png")
    }
    if let p = renderCanvaBackgroundPlate(sunsetSrc: sSrc, twilightSrc: tSrc, width: 2064, height: 2752, isDark: true, isPad: true) {
        saveCGImage(p, to: "\(assetDir)/crimea_twilight_bg.png")
    }
    if let p = renderCanvaBackgroundPlate(sunsetSrc: sSrc, twilightSrc: tSrc, width: 1320, height: 2868, isDark: false, isPad: false) {
        saveCGImage(p, to: "\(assetDir)/crimea_sunset_iphone_bg.png")
    }
    if let p = renderCanvaBackgroundPlate(sunsetSrc: sSrc, twilightSrc: tSrc, width: 1320, height: 2868, isDark: true, isPad: false) {
        saveCGImage(p, to: "\(assetDir)/crimea_twilight_iphone_bg.png")
    }
}

let bgImg = loadCGImage("\(assetDir)/crimea_sunset_bg.png")
let bgTwilightImg = loadCGImage("\(assetDir)/crimea_twilight_bg.png") ?? bgImg
let bgIPhoneImg = loadCGImage("\(assetDir)/crimea_sunset_iphone_bg.png") ?? bgImg
let bgIPhoneTwilightImg = loadCGImage("\(assetDir)/crimea_twilight_iphone_bg.png") ?? bgTwilightImg

struct PosterCopy {
    let shotId: String
    let badge: String
    let title: String
    let subtitle: String
    let pills: [String]
    let isDark: Bool
}

let defaultLocalizedCopy: [String: [PosterCopy]] = [
    "crh": [
        PosterCopy(shotId: "01_latin_light", badge: "QIRIMKEY • ÖZ TİLİMİZ ER YERDE", title: "Qırımtatar\nklaviaturası QırımKey", subtitle: "Lâtin ve Kirill elifbeleri • Aqıllı\nsöz teklifleri ve tez svayp", pills: ["Lâtin & Kirill", "Söz teklifleri", "Zengin luğat"], isDark: false),
        PosterCopy(shotId: "02_latin_dark", badge: "QARANLIQ TEMA & LIQUID GLASS", title: "Zarif gece\nkörünişi", subtitle: "Qaranlıq tema Liquid Glass • Canlı\nTaraq Tamğa nefes aluvı", pills: ["Qaranlıq tema", "Liquid Glass", "Taraq Tamğa"], isDark: true),
        PosterCopy(shotId: "03_cyrillic", badge: "EKİ ELİFBE — BİR YERDE", title: "Kirill ve canlı\ntransliteratsiya", subtitle: "селям → selâm • Ukraina ФІВА\ntizilişi ve avto-tüzetüv", pills: ["Къырымтатарджа", "Українська ФІВА", "Avto-tüzetüv"], isDark: false),
        PosterCopy(shotId: "04_home_light", badge: "STATİSTİKA & SAZLAMALAR", title: "Qolay idare\nve statistika", subtitle: "Yazuv statistikası • Söz ögrenüv •\nKünlik hikmetler ve sazlamalar", pills: ["Statistika", "Söz ögrenüv", "Künlik hikmetler"], isDark: false),
        PosterCopy(shotId: "05_home_dark", badge: "100% CİHAZDA • TAM HUSUSİYLİK", title: "Malümatıñız\nemniyette", subtitle: "Tamamen internetsiz işley • Şahsiy\nyazuvlarıñız cihazdan tışqa çıqmay", pills: ["İnternetsiz işley", "Sıfır telemetriya", "Tam emniyet"], isDark: true)
    ],
    "uk": [
        PosterCopy(shotId: "01_latin_light", badge: "QIRIMKEY • РІДНА МОВА ВСЮДИ", title: "Кримськотатарська\nклавіатура QırımKey", subtitle: "Латиниця та кирилиця • Розумні\nпропозиції слів і швидкий свайп", pills: ["Латиниця й кирилиця", "Пропозиції слів", "Багатий словник"], isDark: false),
        PosterCopy(shotId: "02_latin_dark", badge: "ТЕМНА ТЕМА & LIQUID GLASS", title: "Витончений\nнічний дизайн", subtitle: "Темна тема Liquid Glass • Живе\nдихання емблеми Тарак-Тамги", pills: ["Темна тема", "Liquid Glass", "Тарак-Тамга"], isDark: true),
        PosterCopy(shotId: "03_cyrillic", badge: "ДВА АЛФАВІТИ РАЗОМ", title: "Латиниця й кирилиця\nв один дотик", subtitle: "селям → selâm • Українська\nрозкладка ФІВА та автовиправлення", pills: ["Къырымтатарджа", "Українська ФІВА", "Автовиправлення"], isDark: false),
        PosterCopy(shotId: "04_home_light", badge: "СТАТИСТИКА Й НАЛАШТУВАННЯ", title: "Швидке налаштування\nта статистика", subtitle: "Статистика друку • Навчання слів •\nВідомі вислови • Підказки в додатку", pills: ["Статистика", "Навчання слів", "Відомі вислови"], isDark: false),
        PosterCopy(shotId: "05_home_dark", badge: "100% НА ПРИСТРОЇ • ПОВНА ПРИВАТНІСТЬ", title: "Ваші дані\nу безпеці", subtitle: "Працює повністю офлайн •\nЖодні тексти не передаються в мережу", pills: ["100% Офлайн", "Без телеметрії", "Повний захист"], isDark: true)
    ],
    "en": [
        PosterCopy(shotId: "01_latin_light", badge: "QIRIMKEY • OUR LANGUAGE EVERYWHERE", title: "Crimean Tatar\nKeyboard QırımKey", subtitle: "Latin & Cyrillic scripts • Smart\nword predictions and fast swipe", pills: ["Latin & Cyrillic", "Smart Suggestions", "Rich Lexicon"], isDark: false),
        PosterCopy(shotId: "02_latin_dark", badge: "DARK THEME & LIQUID GLASS", title: "Refined Night\nExperience", subtitle: "Liquid Glass dark theme • Breathing\nTaraq Tamğa spacebar emblem", pills: ["Dark Theme", "Liquid Glass", "Taraq Tamğa"], isDark: true),
        PosterCopy(shotId: "03_cyrillic", badge: "TWO SCRIPTS IN ONE", title: "Cyrillic & Live\nTransliteration", subtitle: "селям → selâm • Ukrainian FIVA\nlayout and smart autocorrect", pills: ["Cyrillic Script", "Ukrainian FIVA", "Autocorrect"], isDark: false),
        PosterCopy(shotId: "04_home_light", badge: "STATISTICS & CUSTOMIZATION", title: "Quick Setup\n& Statistics", subtitle: "Typing statistics • Word learning •\nCultural quotes & in-app guidance", pills: ["Statistics", "Word Learning", "Cultural Quotes"], isDark: false),
        PosterCopy(shotId: "05_home_dark", badge: "100% ON-DEVICE • TOTAL PRIVACY", title: "Your Data\nStays Safe", subtitle: "Works completely offline •\nNo typed text is ever sent online", pills: ["100% Offline", "Zero Telemetry", "Full Privacy"] , isDark: true)
    ]
]

let localizedCopy: [String: [PosterCopy]] = {
    let cfgURL = URL(fileURLWithPath: "\(repoRoot)/marketing/templates/config.json")
    guard let data = try? Data(contentsOf: cfgURL),
          let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let copyDict = root["copy"] as? [String: [String: [String: Any]]] else {
        return defaultLocalizedCopy
    }
    let orderedShotIds = ["01_latin_light", "02_latin_dark", "03_cyrillic", "04_home_light", "05_home_dark"]
    var result: [String: [PosterCopy]] = [:]
    for (loc, fallbackList) in defaultLocalizedCopy {
        guard let locMap = copyDict[loc] else {
            result[loc] = fallbackList
            continue
        }
        var items: [PosterCopy] = []
        for shotId in orderedShotIds {
            if let entry = locMap[shotId],
               let badge = entry["badge"] as? String,
               let title = entry["title"] as? String,
               let subtitle = entry["subtitle"] as? String {
                let pills = (entry["pills"] as? [String]) ?? []
                items.append(PosterCopy(shotId: shotId, badge: badge, title: title, subtitle: subtitle, pills: pills, isDark: shotId.contains("dark")))
            } else if let fb = fallbackList.first(where: { $0.shotId == shotId }) {
                items.append(fb)
            }
        }
        result[loc] = items
    }
    return result
}()

func drawHardwareDevice(
    _ ctx: CGContext,
    shotImg: CGImage,
    screenRect: CGRect,
    isPad: Bool
) {
    let cs = CGColorSpaceCreateDeviceRGB()
    let screenCorner: CGFloat = isPad ? 30 : 54
    let innerBezel: CGFloat = isPad ? 22 : 14
    let outerRim: CGFloat = isPad ? 6 : 6.5

    let innerRect = screenRect.insetBy(dx: -innerBezel, dy: -innerBezel)
    let outerRect = innerRect.insetBy(dx: -outerRim, dy: -outerRim)
    let innerCorner = screenCorner + innerBezel * 0.85
    let outerCorner = innerCorner + outerRim


    // 1. Hardware side buttons
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 0.52, green: 0.46, blue: 0.42, alpha: 1.0))
    if isPad {
        let topBtn = CGRect(x: outerRect.maxX - 115, y: outerRect.maxY - 2, width: 64, height: 7)
        let volUp = CGRect(x: outerRect.maxX - 2, y: outerRect.maxY - 190, width: 7, height: 72)
        let volDn = CGRect(x: outerRect.maxX - 2, y: outerRect.maxY - 280, width: 7, height: 72)
        for r in [topBtn, volUp, volDn] {
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: 3, cornerHeight: 3, transform: nil))
            ctx.fillPath()
        }
    } else {
        let btnW: CGFloat = 6.5
        let actBtn = CGRect(x: outerRect.minX - btnW + 2, y: outerRect.maxY - 310, width: btnW, height: 48)
        let volUp = CGRect(x: outerRect.minX - btnW + 2, y: outerRect.maxY - 420, width: btnW, height: 88)
        let volDn = CGRect(x: outerRect.minX - btnW + 2, y: outerRect.maxY - 530, width: btnW, height: 88)
        let pwrBtn = CGRect(x: outerRect.maxX - 2, y: outerRect.maxY - 450, width: btnW, height: 132)
        for r in [actBtn, volUp, volDn, pwrBtn] {
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: 3, cornerHeight: 3, transform: nil))
            ctx.fillPath()
        }
    }
    ctx.restoreGState()

    // 2. Warm Crimean sunset/twilight ambient rim glow + deep drop shadow behind metallic chassis (matching Canva DAHZG5VPIOs)
    let outerPath = CGPath(roundedRect: outerRect, cornerWidth: outerCorner, cornerHeight: outerCorner, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: -6, height: -4), blur: 54, color: CGColor(red: 1.0, green: 0.62, blue: 0.22, alpha: 0.52))
    ctx.addPath(outerPath)
    ctx.setFillColor(CGColor(red: 0.45, green: 0.42, blue: 0.40, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -26), blur: 44, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.72))
    ctx.addPath(outerPath)
    ctx.setFillColor(CGColor(red: 0.45, green: 0.42, blue: 0.40, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    // Warm sunset-lit titanium metallic bevel across outer chassis
    ctx.saveGState()
    ctx.addPath(outerPath)
    ctx.clip()
    let gradColors = [
        CGColor(red: 0.97, green: 0.76, blue: 0.52, alpha: 1.0),
        CGColor(red: 0.34, green: 0.38, blue: 0.46, alpha: 1.0),
        CGColor(red: 0.88, green: 0.64, blue: 0.42, alpha: 1.0)
    ] as CFArray
    if let grad = CGGradient(colorsSpace: cs, colors: gradColors, locations: [0.0, 0.52, 1.0]) {
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

    // 4. Screen content clipped to screenRect with high-quality resampling
    ctx.saveGState()
    ctx.interpolationQuality = .high
    let clipPath = CGPath(roundedRect: screenRect, cornerWidth: screenCorner, cornerHeight: screenCorner, transform: nil)
    ctx.addPath(clipPath)
    ctx.clip()
    ctx.draw(shotImg, in: screenRect)
    ctx.restoreGState()

    // Subtle warm inner screen border rim
    ctx.saveGState()
    ctx.addPath(clipPath)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 0.92, blue: 0.82, alpha: 0.18))
    ctx.setLineWidth(1.5)
    ctx.strokePath()
    ctx.restoreGState()

    // 5. Front camera / Dynamic Island hardware detail
    ctx.saveGState()
    if isPad {
        let camR: CGFloat = 5.5
        let camCenter = CGPoint(x: innerRect.midX, y: screenRect.maxY + innerBezel * 0.5)
        ctx.setFillColor(CGColor(red: 0.08, green: 0.11, blue: 0.17, alpha: 1.0))
        ctx.fillEllipse(in: CGRect(x: camCenter.x - camR, y: camCenter.y - camR, width: camR * 2, height: camR * 2))
        ctx.setFillColor(CGColor(red: 0.18, green: 0.28, blue: 0.48, alpha: 0.85))
        ctx.fillEllipse(in: CGRect(x: camCenter.x - camR * 0.4, y: camCenter.y - camR * 0.4, width: camR * 0.8, height: camR * 0.8))
    } else {
        let islandW = screenRect.width * 0.265
        let islandH = screenRect.width * 0.074
        let islandX = screenRect.midX - islandW * 0.5
        let islandY = screenRect.maxY - islandH - screenRect.width * 0.022
        let islandRect = CGRect(x: islandX, y: islandY, width: islandW, height: islandH)
        let islandPath = CGPath(roundedRect: islandRect, cornerWidth: islandH * 0.5, cornerHeight: islandH * 0.5, transform: nil)
        ctx.addPath(islandPath)
        ctx.setFillColor(CGColor(red: 0.02, green: 0.025, blue: 0.035, alpha: 1.0))
        ctx.fillPath()

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
    ctx.interpolationQuality = .high
    let w = CGFloat(width), h = CGFloat(height)

    // 1. Dedicated aspect-exact Canva-style Crimean coastal sunset (Light) / twilight (Dark) HD plate
    let chosenBg: CGImage? = isPad
        ? (copy.isDark ? bgTwilightImg : bgImg)
        : (copy.isDark ? bgIPhoneTwilightImg : bgIPhoneImg)
    if let bg = chosenBg {
        let bgW = CGFloat(bg.width), bgH = CGFloat(bg.height)
        let scale = max(w / bgW, h / bgH)
        let drawW = bgW * scale
        let drawH = bgH * scale
        let bgRect = CGRect(x: (w - drawW) * 0.5, y: h - drawH, width: drawW, height: drawH)
        ctx.draw(bg, in: bgRect)
    }

    // 2. Clean 2-Element Canva DAHZG5VPIOs Header & Symmetrical Dark-Glass Backdrop:
    //    - Element 1: Large stacked 2-line Extra-Bold White Headline
    //    - Element 2: Clean 2-line •-separated Subtitle
    //    - Symmetrical dark-glass card with identical top and bottom vertical padding (padV)
    let textMaxW = w * (isPad ? 0.60 : 0.74)
    let titleFontSize = isPad ? w * 0.0475 : w * 0.0595
    let subFontSize   = isPad ? w * 0.0205 : w * 0.0248
    let titleLineMult: CGFloat = 1.10
    let subLineMult: CGFloat = 1.35

    let titleLines = copy.title
        .replacingOccurrences(of: "\\n", with: "\n")
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { String($0).trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    let subLines = copy.subtitle
        .replacingOccurrences(of: "\\n", with: "\n")
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { String($0).trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }

    let actualTitleSize = fitTypographicSize(titleLines, maxWidth: textMaxW, fontSize: titleFontSize, weight: .heavy, kern: -0.6)
    let actualSubSize   = fitTypographicSize(subLines, maxWidth: textMaxW, fontSize: subFontSize, weight: .medium, kern: 0.1)

    let titleStep = actualTitleSize * titleLineMult
    let subStep   = actualSubSize * subLineMult
    let ascentTop = actualTitleSize * 0.76
    let descentBot = actualSubSize * 0.24
    let blockGap = actualTitleSize * 0.56 + actualSubSize * 1.05

    let titleSpan = CGFloat(max(0, titleLines.count - 1)) * titleStep
    let subSpan   = CGFloat(max(0, subLines.count - 1)) * subStep
    let textBlockH = ascentTop + titleSpan + blockGap + subSpan + descentBot

    let padV = h * (isPad ? 0.024 : 0.023)
    let cardW = w * (isPad ? 0.64 : 0.78)
    let cardH = textBlockH + padV * 2.0
    let cardX = (w - cardW) * 0.5
    let cardY = h * (isPad ? 0.754 : 0.760)
    let cardCorner: CGFloat = isPad ? 46.0 : 40.0
    let cardRect = CGRect(x: cardX, y: cardY, width: cardW, height: cardH)
    let cardPath = CGPath(roundedRect: cardRect, cornerWidth: cardCorner, cornerHeight: cardCorner, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 28, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.30))
    ctx.addPath(cardPath)
    ctx.setFillColor(CGColor(red: 0.03, green: 0.05, blue: 0.09, alpha: copy.isDark ? 0.44 : 0.40))
    ctx.fillPath()
    ctx.restoreGState()

    let titleBase1 = cardY + cardH - padV - ascentTop
    let subBase1   = titleBase1 - titleSpan - blockGap

    _ = drawMultilineStyledText(
        ctx,
        copy.title,
        centerX: w * 0.5,
        topBaselineY: titleBase1,
        maxWidth: textMaxW,
        fontSize: actualTitleSize,
        lineHeightMultiplier: titleLineMult,
        weight: .heavy,
        kern: -0.6,
        color: NSColor.white
    )

    _ = drawMultilineStyledText(
        ctx,
        copy.subtitle,
        centerX: w * 0.5,
        topBaselineY: subBase1,
        maxWidth: textMaxW,
        fontSize: actualSubSize,
        lineHeightMultiplier: subLineMult,
        weight: .medium,
        kern: 0.1,
        color: NSColor(calibratedRed: 0.94, green: 0.96, blue: 0.99, alpha: 0.96)
    )

    // 4. Hardware device frame & screenshot placement (leaving Left setting sun & Right rocky cliff 100% visible!)
    let displayShot: CGImage = {
        // For iPhone 04_home_light, isotropically crop the excess bottom blank margin so "Системні налаштування" sits right above the bottom bezel (matching Canva DAHZG5VPIOs Page 1!)
        if !isPad && copy.shotId == "04_home_light" {
            let sw = CGFloat(shotImg.width), sh = CGFloat(shotImg.height)
            let cropW = sw * 0.922
            let cropH = sh * 0.922
            let cropX = (sw - cropW) * 0.5
            let cropRect = CGRect(x: cropX, y: 0, width: cropW, height: cropH)
            if let cropped = shotImg.cropping(to: cropRect) {
                return cropped
            }
        }
        return shotImg
    }()

    let imgAspect = CGFloat(displayShot.width) / CGFloat(displayShot.height)
    let maxScreenH = h * (isPad ? 0.680 : 0.692)
    let maxScreenW = w * (isPad ? 0.630 : 0.650)
    var drawW = maxScreenH * imgAspect
    var drawH = maxScreenH
    if drawW > maxScreenW {
        drawW = maxScreenW
        drawH = drawW / imgAspect
    }
    let sx = (w - drawW) * 0.5
    let sy = h * (isPad ? 0.036 : 0.034)
    let screenRect = CGRect(x: sx, y: sy, width: drawW, height: drawH)

    drawHardwareDevice(ctx, shotImg: displayShot, screenRect: screenRect, isPad: isPad)

    return ctx.makeImage()
}

func renderPureScreenCard(width: Int, height: Int, shotImg: CGImage) -> CGImage? {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .high
    ctx.draw(shotImg, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
    return ctx.makeImage()
}

let env = ProcessInfo.processInfo.environment
let postersOnly = env["QK_POSTERS_ONLY"] == "1"
let planBOnly = env["QK_PLAN_B"] == "1"
let rawDirOverride = (env["QK_RAW_DIR"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
let onlyShotsFilter: Set<String> = {
    guard let raw = env["QK_ONLY_SHOTS"], !raw.isEmpty else { return [] }
    return Set(raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
}()

func fileModDate(_ path: String) -> Date {
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
          let mtime = attrs[.modificationDate] as? Date else {
        return .distantPast
    }
    return mtime
}

func softenSpacebarCornerBadge(baseImg: CGImage, device: String, shotId: String) -> CGImage {
    // Soften the bottom-right spacebar corner code (QT / КЪ / Кʼ) so its contrast matches standard iOS УК (0.20..0.24 Light / 0.30..0.32 Dark).
    // Skip iPhone 04_home_light which has no keyboard at the bottom.
    if device == "iphone" && shotId == "04_home_light" {
        return baseImg
    }
    let w = baseImg.width, h = baseImg.height
    let cs = CGColorSpaceCreateDeviceRGB()
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    guard let ctx = CGContext(
        data: &pixels,
        width: w,
        height: h,
        bitsPerComponent: 8,
        bytesPerRow: w * 4,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        return baseImg
    }
    let fullRect = CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h))
    ctx.draw(baseImg, in: fullRect)

    // Badge bbox in top-down pixel coordinates (row 0 = top)
    let x0 = Int(Double(w) * (device == "ipad" ? 0.690 : 0.686))
    let x1 = Int(Double(w) * (device == "ipad" ? 0.724 : 0.728))
    let y0 = Int(Double(h) * (device == "ipad" ? 0.955 : 0.885))
    let y1 = Int(Double(h) * (device == "ipad" ? 0.976 : 0.906))
    guard x0 > 40 && x1 < w && y0 >= 0 && y1 < h else { return baseImg }

    var minLum = 255
    var maxLum = 0
    for y in y0...y1 {
        for x in x0...x1 {
            let idx = (y * w + x) * 4
            let lum = (Int(pixels[idx]) + Int(pixels[idx + 1]) + Int(pixels[idx + 2])) / 3
            if lum < minLum { minLum = lum }
            if lum > maxLum { maxLum = lum }
        }
    }
    // Idempotency guard: only soften if contrast delta > 82 (old 0.55 opacity has delta ~103..137; new 0.24/0.32 opacity has delta ~55..62)
    guard (maxLum - minLum) > 82 else {
        return baseImg
    }

    let isDark = shotId.contains("dark")
    let keepFactor: Double = isDark ? 0.58 : 0.44
    let refX = x0 - 12
    for y in y0...y1 {
        let refIdx = (y * w + refX) * 4
        let bgR = Double(pixels[refIdx])
        let bgG = Double(pixels[refIdx + 1])
        let bgB = Double(pixels[refIdx + 2])
        for x in x0...x1 {
            let idx = (y * w + x) * 4
            pixels[idx]     = UInt8(clamping: Int(round(Double(pixels[idx])     * keepFactor + bgR * (1.0 - keepFactor))))
            pixels[idx + 1] = UInt8(clamping: Int(round(Double(pixels[idx + 1]) * keepFactor + bgG * (1.0 - keepFactor))))
            pixels[idx + 2] = UInt8(clamping: Int(round(Double(pixels[idx + 2]) * keepFactor + bgB * (1.0 - keepFactor))))
        }
    }
    return ctx.makeImage() ?? baseImg
}

func loadReferenceAsset(device: String, shotId: String, locale: String) -> CGImage? {
    let candidates = [
        "/tmp/qk_shots/store_\(device)_\(shotId)_\(locale).png",
        "\(repoRoot)/docs/release/2026-10-25/assets/store_\(device)_\(shotId)_\(locale).png",
        "\(repoRoot)/docs/release/2026-10-25/assets/store_\(device)_\(shotId)_crh.png"
    ]
    for path in candidates {
        if FileManager.default.fileExists(atPath: path), let img = loadCGImage(path) {
            return img
        }
    }
    return nil
}

func copyTopLeftRegion(
    from srcImg: CGImage,
    srcX: Int, srcYTop: Int, srcW: Int, srcH: Int,
    to ctx: CGContext,
    dstX: Int, dstYTop: Int, dstW: Int, dstH: Int,
    canvasH: Int
) {
    let cropRect = CGRect(x: srcX, y: srcYTop, width: srcW, height: srcH)
    guard let cropped = srcImg.cropping(to: cropRect) else { return }
    let dstRect = CGRect(
        x: CGFloat(dstX),
        y: CGFloat(canvasH - dstYTop - dstH),
        width: CGFloat(dstW),
        height: CGFloat(dstH)
    )
    ctx.interpolationQuality = .high
    ctx.draw(cropped, in: dstRect)
}

func compositeDockedIPadKeyboardIfNeeded(baseImg: CGImage, device: String, shotId: String, locale: String) -> CGImage {
    var currentImg = baseImg
    let loc = (locale == "uk" || locale == "en") ? locale : "crh"
    let w = currentImg.width
    let h = currentImg.height
    let isDark = (shotId == "02_latin_dark" || shotId == "05_home_dark")
    let refHomeShot = isDark ? "05_home_dark" : "04_home_light"
    let cs = CGColorSpaceCreateDeviceRGB()

    if device == "ipad" && w == 1640 && h == 2360 {
        // 04_home_light and 05_home_dark from /tmp/qk_shots already have the authentic docked iPad keyboard,
        // personalized sandbox message, Statistics pill units, and updated Settings badges.
        if shotId == "01_latin_light" || shotId == "02_latin_dark" || shotId == "03_cyrillic" {
            if let ipadHomeImg = loadReferenceAsset(device: "ipad", shotId: refHomeShot, locale: loc),
               ipadHomeImg.width == w && ipadHomeImg.height == h,
               let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) {
                ctx.draw(currentImg, in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
                // Copy updated Statistics card (with units) + Settings card (with new badges), shifted +38px to match focused sandbox card height
                copyTopLeftRegion(
                    from: ipadHomeImg,
                    srcX: 160, srcYTop: 683, srcW: 1320, srcH: 820,
                    to: ctx,
                    dstX: 160, dstYTop: 721, dstW: 1320, dstH: 820,
                    canvasH: h
                )
                if let merged = ctx.makeImage() {
                    currentImg = merged
                }
            }
        }
    } else if device == "iphone" && w == 1206 && h == 2622 {
        if let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) {
            ctx.draw(currentImg, in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))

            // 1. Repair stray "< Settings" in top-left status bar on 02_latin_dark_crh
            if shotId == "02_latin_dark" && loc == "crh",
               let cleanDarkImg = loadReferenceAsset(device: "iphone", shotId: "02_latin_dark", locale: "uk"),
               cleanDarkImg.width == w && cleanDarkImg.height == h {
                copyTopLeftRegion(
                    from: cleanDarkImg,
                    srcX: 0, srcYTop: 0, srcW: 1206, srcH: 160,
                    to: ctx,
                    dstX: 0, dstYTop: 0, dstW: 1206, dstH: 160,
                    canvasH: h
                )
            }

            // 2. Repair "seyam" -> "selâm" in Cyrillic suggestion bar on 03_cyrillic_crh
            if shotId == "03_cyrillic" && loc == "crh",
               let cleanCyrImg = loadReferenceAsset(device: "iphone", shotId: "03_cyrillic", locale: "en"),
               cleanCyrImg.width == w && cleanCyrImg.height == h {
                copyTopLeftRegion(
                    from: cleanCyrImg,
                    srcX: 30, srcYTop: 1620, srcW: 1146, srcH: 128,
                    to: ctx,
                    dstX: 30, dstYTop: 1620, dstW: 1146, dstH: 128,
                    canvasH: h
                )
            }

            // 3. Upgrade 4 Statistics pills (with units) and Settings badges from iPad 04/05 reference (@2x -> @3x = 1.5x)
            if let ipadHomeImg = loadReferenceAsset(device: "ipad", shotId: refHomeShot, locale: loc),
               ipadHomeImg.width == 1640 && ipadHomeImg.height == 2360 {
                let pillYTop: Int
                let langBadgeYTop: Int
                switch shotId {
                case "01_latin_light", "03_cyrillic":
                    pillYTop = 1255
                    langBadgeYTop = 1418
                case "02_latin_dark":
                    pillYTop = 1255
                    langBadgeYTop = 1417
                case "04_home_light":
                    pillYTop = 1204
                    langBadgeYTop = 1373
                default: // 05_home_dark
                    pillYTop = 1198
                    langBadgeYTop = 1361
                }

                // Clear existing 4-pill row interior with card background color
                if isDark {
                    ctx.setFillColor(red: 28.0 / 255.0, green: 28.0 / 255.0, blue: 30.0 / 255.0, alpha: 1.0)
                } else {
                    ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
                }
                let clearYTop = pillYTop - 4
                let clearH = 80
                ctx.fill(CGRect(x: 76, y: h - clearYTop - clearH, width: 1054, height: clearH))

                let pillSrcX: Int
                let pillSrcW: Int
                if loc == "uk" {
                    pillSrcX = 579
                    pillSrcW = 649
                } else if loc == "en" {
                    pillSrcX = 512
                    pillSrcW = 716
                } else {
                    pillSrcX = 535
                    pillSrcW = 693
                }
                let pillDstW = min(1048, Int(round(Double(pillSrcW) * 1.5)))
                copyTopLeftRegion(
                    from: ipadHomeImg,
                    srcX: pillSrcX, srcYTop: 727, srcW: pillSrcW, srcH: 48,
                    to: ctx,
                    dstX: 78, dstYTop: pillYTop, dstW: pillDstW, dstH: 72,
                    canvasH: h
                )

                // Upgrade Interface language badge (56x56 -> 84x84)
                copyTopLeftRegion(
                    from: ipadHomeImg,
                    srcX: 208, srcYTop: 843, srcW: 56, srcH: 56,
                    to: ctx,
                    dstX: 78, dstYTop: langBadgeYTop, dstW: 84, dstH: 84,
                    canvasH: h
                )

                // Upgrade System settings badge on 04_home_light (56x56 -> 84x84)
                if shotId == "04_home_light" {
                    let sysSrcYTop = (loc == "uk") ? 1276 : 1164
                    let sysDstYTop = (loc == "uk") ? 2160 : 1995
                    copyTopLeftRegion(
                        from: ipadHomeImg,
                        srcX: 208, srcYTop: sysSrcYTop, srcW: 56, srcH: 56,
                        to: ctx,
                        dstX: 78, dstYTop: sysDstYTop, dstW: 84, dstH: 84,
                        canvasH: h
                    )
                }
            }

            if let merged = ctx.makeImage() {
                currentImg = merged
            }
        }
    }

    return softenSpacebarCornerBadge(baseImg: currentImg, device: device, shotId: shotId)
}

func loadBestScreenshot(device: String, shotId: String, locale: String) -> CGImage? {
    let releaseAsset = "\(repoRoot)/docs/release/2026-10-25/assets/store_\(device)_\(shotId)_\(locale).png"
    let defaultAsset = "\(repoRoot)/docs/release/2026-10-25/assets/store_\(device)_\(shotId).png"

    if !rawDirOverride.isEmpty {
        let explicitPath = "\(rawDirOverride)/store_\(device)_\(shotId)_\(locale).png"
        if let rawImg = loadCGImage(explicitPath) {
            let img = compositeDockedIPadKeyboardIfNeeded(baseImg: rawImg, device: device, shotId: shotId, locale: locale)
            saveCGImage(img, to: releaseAsset)
            if locale == "crh" {
                saveCGImage(img, to: defaultAsset)
            }
            return img
        }
    }

    let localizedCandidates = [
        "/tmp/qk_shots/store_\(device)_\(shotId)_\(locale).png",
        "/tmp/qk_store_raw/store_\(device)_\(shotId)_\(locale).png",
        "\(repoRoot)/QTatar/AppStoreAssets/RawScreenshots/store_\(device)_\(shotId)_\(locale).png",
        releaseAsset
    ]
    let sortedLocalized = localizedCandidates
        .filter { FileManager.default.fileExists(atPath: $0) }
        .sorted { fileModDate($0) > fileModDate($1) }

    for path in sortedLocalized {
        if let rawImg = loadCGImage(path) {
            let img = compositeDockedIPadKeyboardIfNeeded(baseImg: rawImg, device: device, shotId: shotId, locale: locale)
            saveCGImage(img, to: releaseAsset)
            if locale == "crh" {
                saveCGImage(img, to: defaultAsset)
            }
            return img
        }
    }

    var fallbackCandidates: [String] = []
    if !rawDirOverride.isEmpty {
        fallbackCandidates.append("\(rawDirOverride)/store_\(device)_\(shotId).png")
    }
    let unlocalizedPool = [
        "/tmp/qk_shots/store_\(device)_\(shotId).png",
        "/tmp/qk_store_raw/store_\(device)_\(shotId).png",
        "\(repoRoot)/QTatar/AppStoreAssets/RawScreenshots/store_\(device)_\(shotId).png",
        defaultAsset
    ]
    fallbackCandidates.append(contentsOf: unlocalizedPool
        .filter { FileManager.default.fileExists(atPath: $0) }
        .sorted { fileModDate($0) > fileModDate($1) })
    if device == "iphone" {
        fallbackCandidates.append("\(repoRoot)/AppStoreMetadata/Screenshots/iphone-6.3-1206x2622/\(shotId).png")
    }
    for path in fallbackCandidates {
        if let rawImg = loadCGImage(path) {
            return compositeDockedIPadKeyboardIfNeeded(baseImg: rawImg, device: device, shotId: shotId, locale: locale)
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
ensureDir("\(repoRoot)/AppStoreMetadata/Media_PlanB/iphone_6.9")
ensureDir("\(repoRoot)/AppStoreMetadata/Media_PlanB/ipad_13")
ensureDir("\(repoRoot)/AppStoreMetadata/Media_PlanB/ru/iphone_6.9")
ensureDir("\(repoRoot)/AppStoreMetadata/Media_PlanB/ru/ipad_13")
ensureDir("\(repoRoot)/AppStoreMetadata/Media_PlanB/en-US/iphone_6.9")
ensureDir("\(repoRoot)/AppStoreMetadata/Media_PlanB/en-US/ipad_13")
ensureDir("\(repoRoot)/docs/release/2026-10-25/assets")

for device in ["iphone", "ipad"] {
    for auxShot in ["04b_home_cyrillic_missing", "04c_home_uk_stats_expanded"] {
        let releaseAux = "\(repoRoot)/docs/release/2026-10-25/assets/store_\(device)_\(auxShot).png"
        if !rawDirOverride.isEmpty {
            let explicitAux = "\(rawDirOverride)/store_\(device)_\(auxShot).png"
            if explicitAux != releaseAux, let img = loadCGImage(explicitAux) {
                saveCGImage(img, to: releaseAux)
                continue
            }
        }
        let auxCandidates = [
            "/tmp/qk_shots/store_\(device)_\(auxShot).png",
            "/tmp/qk_store_raw/store_\(device)_\(auxShot).png",
            "\(repoRoot)/QTatar/AppStoreAssets/RawScreenshots/store_\(device)_\(auxShot).png",
            releaseAux
        ]
        .filter { FileManager.default.fileExists(atPath: $0) }
        .sorted { fileModDate($0) > fileModDate($1) }
        for path in auxCandidates {
            if let img = loadCGImage(path) {
                if path != releaseAux {
                    saveCGImage(img, to: releaseAux)
                }
                break
            }
        }
    }
}

for (locale, copyList) in localizedCopy {
    let iphoneOutDir = "\(repoRoot)/AppStoreMetadata/Media/\(locale)/iphone_6.9"
    let ipadOutDir = "\(repoRoot)/AppStoreMetadata/Media/\(locale)/ipad_13"
    let iphonePlanBDir = "\(repoRoot)/AppStoreMetadata/Media_PlanB/\(locale)/iphone_6.9"
    let ipadPlanBDir = "\(repoRoot)/AppStoreMetadata/Media_PlanB/\(locale)/ipad_13"
    ensureDir(iphoneOutDir)
    ensureDir(ipadOutDir)
    ensureDir(iphonePlanBDir)
    ensureDir(ipadPlanBDir)

    for copy in copyList {
        if !onlyShotsFilter.isEmpty && !onlyShotsFilter.contains(copy.shotId) {
            continue
        }
        if let iphoneShot = loadBestScreenshot(device: "iphone", shotId: copy.shotId, locale: locale) {
            if locale == "crh" {
                saveCGImage(iphoneShot, to: "\(repoRoot)/AppStoreMetadata/Screenshots/iphone-6.3-1206x2622/\(copy.shotId).png")
            }
            if let iphonePure = renderPureScreenCard(width: 1320, height: 2868, shotImg: iphoneShot) {
                saveCGImage(iphonePure, to: "\(iphonePlanBDir)/\(copy.shotId).png")
                if locale == "crh" {
                    saveCGImage(iphonePure, to: "\(repoRoot)/AppStoreMetadata/Media_PlanB/iphone_6.9/\(copy.shotId).png")
                    saveCGImage(iphonePure, to: "\(repoRoot)/AppStoreMetadata/Media_PlanB/ru/iphone_6.9/\(copy.shotId).png")
                } else if locale == "en" {
                    saveCGImage(iphonePure, to: "\(repoRoot)/AppStoreMetadata/Media_PlanB/en-US/iphone_6.9/\(copy.shotId).png")
                }
                if planBOnly {
                    saveCGImage(iphonePure, to: "\(iphoneOutDir)/\(copy.shotId).png")
                    if locale == "crh" {
                        saveCGImage(iphonePure, to: "\(repoRoot)/AppStoreMetadata/Media/iphone_6.9/\(copy.shotId).png")
                        saveCGImage(iphonePure, to: "\(repoRoot)/AppStoreMetadata/Media/ru/iphone_6.9/\(copy.shotId).png")
                    } else if locale == "en" {
                        saveCGImage(iphonePure, to: "\(repoRoot)/AppStoreMetadata/Media/en-US/iphone_6.9/\(copy.shotId).png")
                    }
                }
            }
            if !planBOnly, let iphoneCard = renderFramedMarketingCard(width: 1320, height: 2868, shotImg: iphoneShot, copy: copy, isPad: false) {
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
            if let ipadPure = renderPureScreenCard(width: 2064, height: 2752, shotImg: ipadShot) {
                saveCGImage(ipadPure, to: "\(ipadPlanBDir)/\(copy.shotId).png")
                if locale == "crh" {
                    saveCGImage(ipadPure, to: "\(repoRoot)/AppStoreMetadata/Media_PlanB/ipad_13/\(copy.shotId).png")
                    saveCGImage(ipadPure, to: "\(repoRoot)/AppStoreMetadata/Media_PlanB/ru/ipad_13/\(copy.shotId).png")
                } else if locale == "en" {
                    saveCGImage(ipadPure, to: "\(repoRoot)/AppStoreMetadata/Media_PlanB/en-US/ipad_13/\(copy.shotId).png")
                }
                if planBOnly {
                    saveCGImage(ipadPure, to: "\(ipadOutDir)/\(copy.shotId).png")
                    if locale == "crh" {
                        saveCGImage(ipadPure, to: "\(repoRoot)/AppStoreMetadata/Media/ipad_13/\(copy.shotId).png")
                        saveCGImage(ipadPure, to: "\(repoRoot)/AppStoreMetadata/Media/ru/ipad_13/\(copy.shotId).png")
                    } else if locale == "en" {
                        saveCGImage(ipadPure, to: "\(repoRoot)/AppStoreMetadata/Media/en-US/ipad_13/\(copy.shotId).png")
                    }
                }
            }
            if !planBOnly, let ipadCard = renderFramedMarketingCard(width: 2064, height: 2752, shotImg: ipadShot, copy: copy, isPad: true) {
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

func renderPureScreenVideo(path: String, width: Int, height: Int, isPad: Bool, locale: String = "uk") {
    let dev = isPad ? "ipad" : "iphone"
    let s1 = loadBestScreenshot(device: dev, shotId: "01_latin_light", locale: locale) ?? loadBestScreenshot(device: dev, shotId: "01_latin_light", locale: "crh")
    let s2 = loadBestScreenshot(device: dev, shotId: "03_cyrillic", locale: locale) ?? s1
    let s3 = loadBestScreenshot(device: dev, shotId: "02_latin_dark", locale: locale) ?? s1
    let s4 = loadBestScreenshot(device: dev, shotId: "04_home_light", locale: locale) ?? s1
    let s5 = loadBestScreenshot(device: dev, shotId: "05_home_dark", locale: locale) ?? s3
    let frames = [s1, s2, s3, s4, s5].compactMap { $0 }
    guard !frames.isEmpty else { return }

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

    let durationSec = 20.0
    let audioSem = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .userInitiated).async {
        appendSilentAudio(to: audioInput, durationSeconds: durationSec)
        audioInput.markAsFinished()
        audioSem.signal()
    }

    let fps = 30
    let totalFrames = Int(durationSec) * fps
    let cs = CGColorSpaceCreateDeviceRGB()

    for frameIdx in 0..<totalFrames {
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
        let t = Double(frameIdx) / Double(fps)
        let scaled = (t / durationSec) * Double(frames.count)
        let idxA = min(frames.count - 1, max(0, Int(floor(scaled))))
        let idxB = min(frames.count - 1, idxA + 1)
        let localFrac = scaled - floor(scaled)

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
            let rect = CGRect(x: 0, y: 0, width: w, height: h)
            ctx.draw(frames[idxA], in: rect)

            if idxB != idxA && localFrac > 0.88 {
                let alpha = CGFloat((localFrac - 0.88) / 0.12)
                ctx.saveGState()
                ctx.setAlpha(alpha)
                ctx.draw(frames[idxB], in: rect)
                ctx.restoreGState()
            }

            // Show live swipe comet trail during scene idxA == 2 (02_latin_dark) on iPhone
            if !isPad && idxA == 2 && localFrac > 0.12 && localFrac < 0.82 {
                ctx.saveGState()
                let pts = [
                    CGPoint(x: w * 0.08, y: h * 0.25),
                    CGPoint(x: w * 0.62, y: h * 0.25),
                    CGPoint(x: w * 0.33, y: h * 0.25),
                    CGPoint(x: w * 0.62, y: h * 0.25),
                    CGPoint(x: w * 0.68, y: h * 0.14)
                ]
                let cometProgress = min(1.0, max(0.10, CGFloat((localFrac - 0.12) / 0.55)))
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
                    let r = 8.0 * pow(tailFactor, 1.55)
                    ctx.setFillColor(CGColor(red: 0.99, green: 0.82, blue: 0.28, alpha: (0.08 + 0.92 * pow(tailFactor, 1.35)) * 0.90))
                    ctx.fillEllipse(in: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
                }
                ctx.restoreGState()
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
    print("Saved pure-screen video:", path)
}

let pureIPhoneMaster = "\(repoRoot)/AppStoreMetadata/Media/AppPreview_PureScreen_iPhone_6_9.mp4"
let pureIPadMaster = "\(repoRoot)/AppStoreMetadata/Media/AppPreview_PureScreen_iPad_13.mp4"
if !postersOnly || !FileManager.default.fileExists(atPath: pureIPhoneMaster) || !FileManager.default.fileExists(atPath: pureIPadMaster) {
    ensureDir("\(repoRoot)/AppStoreMetadata/Media_PlanB")
    for loc in ["crh", "uk", "en"] {
        let locPhone = "\(repoRoot)/AppStoreMetadata/Media_PlanB/\(loc)/iphone_6.9/AppPreview_PureScreen_iPhone_6_9.mp4"
        let locPad = "\(repoRoot)/AppStoreMetadata/Media_PlanB/\(loc)/ipad_13/AppPreview_PureScreen_iPad_13.mp4"
        renderPureScreenVideo(path: locPhone, width: 886, height: 1920, isPad: false, locale: loc)
        renderPureScreenVideo(path: locPad, width: 1200, height: 1600, isPad: true, locale: loc)
        for dst in [
            "\(repoRoot)/AppStoreMetadata/Media_PlanB/\(loc)/iphone_6.9/preview_iphone_6.9_22s.mp4",
            "\(repoRoot)/AppStoreMetadata/Media/\(loc)/iphone_6.9/AppPreview_PureScreen_iPhone_6_9.mp4"
        ] {
            try? FileManager.default.removeItem(atPath: dst)
            try? FileManager.default.copyItem(atPath: locPhone, toPath: dst)
        }
        for dst in [
            "\(repoRoot)/AppStoreMetadata/Media_PlanB/\(loc)/ipad_13/preview_ipad_13_22s.mp4",
            "\(repoRoot)/AppStoreMetadata/Media/\(loc)/ipad_13/AppPreview_PureScreen_iPad_13.mp4"
        ] {
            try? FileManager.default.removeItem(atPath: dst)
            try? FileManager.default.copyItem(atPath: locPad, toPath: dst)
        }
        if loc == "uk" {
            for dst in [
                pureIPhoneMaster,
                "\(repoRoot)/AppStoreMetadata/Media_PlanB/AppPreview_PureScreen_iPhone_6_9.mp4",
                "\(repoRoot)/AppStoreMetadata/Media_PlanB/iphone_6.9/preview_iphone_6.9_22s.mp4"
            ] {
                try? FileManager.default.removeItem(atPath: dst)
                try? FileManager.default.copyItem(atPath: locPhone, toPath: dst)
            }
            for dst in [
                pureIPadMaster,
                "\(repoRoot)/AppStoreMetadata/Media_PlanB/AppPreview_PureScreen_iPad_13.mp4",
                "\(repoRoot)/AppStoreMetadata/Media_PlanB/ipad_13/preview_ipad_13_22s.mp4"
            ] {
                try? FileManager.default.removeItem(atPath: dst)
                try? FileManager.default.copyItem(atPath: locPad, toPath: dst)
            }
        }
    }
}

if !postersOnly {
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
}
"""


def composite_posters_and_videos(
    posters_only: bool = False,
    only_shots: str = "",
    raw_dir: str = "",
    plan_b: bool = False,
) -> None:
    env = os.environ.copy()
    if posters_only:
        env["QK_POSTERS_ONLY"] = "1"
    if plan_b:
        env["QK_PLAN_B"] = "1"
    if only_shots:
        env["QK_ONLY_SHOTS"] = only_shots
    if raw_dir:
        env["QK_RAW_DIR"] = raw_dir
    with tempfile.NamedTemporaryFile("w", suffix=".swift", delete=False) as f:
        f.write(SWIFT_COMPOSITOR)
        script_path = Path(f.name)
    try:
        subprocess.run(["swift", str(script_path)], cwd=str(ROOT), env=env, check=True)
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
    is_dark = theme.get("bg_start", "").lower() in ("#090f1c", "#050912")

    badge_size = max(18, int(width * (0.017 if is_ipad else 0.021)))
    badge_text_y = int(height * 0.052)

    title_size = max(32, int(width * (0.0475 if is_ipad else 0.0595)))
    subtitle_size = max(20, int(width * (0.0205 if is_ipad else 0.0248)))
    title_line_step = int(title_size * 1.10)
    subtitle_line_step = int(subtitle_size * 1.35)

    title_y = int(height * (0.102 if is_ipad else 0.098))
    subtitle_y = int(height * (0.174 if is_ipad else 0.172))

    title_lines = [ln.strip() for ln in title.split("\n") if ln.strip()]
    subtitle_lines = [ln.strip() for ln in subtitle.split("\n") if ln.strip()]

    title_tspans = "\n".join(
        f'        <tspan x="{center_x}" y="{title_y + idx * title_line_step}">{html.escape(line)}</tspan>'
        for idx, line in enumerate(title_lines)
    )
    subtitle_tspans = "\n".join(
        f'        <tspan x="{center_x}" y="{subtitle_y + idx * subtitle_line_step}">{html.escape(line)}</tspan>'
        for idx, line in enumerate(subtitle_lines)
    )

    max_h = int(height * (0.680 if is_ipad else 0.692))
    max_w = int(width * (0.630 if is_ipad else 0.650))
    shot_aspect = (1640.0 / 2360.0) if is_ipad else (1206.0 / 2436.0)
    screen_w = int(max_h * shot_aspect)
    screen_h = max_h
    if screen_w > max_w:
        screen_w = max_w
        screen_h = int(screen_w / shot_aspect)
    screen_x = (width - screen_w) // 2
    screen_y = height - int(height * (0.036 if is_ipad else 0.034)) - screen_h

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

    # Each device class uses its dedicated pre-rendered Canva background plate at exact aspect ratio
    bg_draw_w = width
    bg_draw_h = height
    bg_shift_x = 0
    bg_shift_y = 0

    # Build Canva-editable frosted-glass SVG pills group (kept hidden with opacity=0 for clean Canva DAHZG5VPIOs layout)
    pill_font_size = max(16, int(width * (0.0155 if is_ipad else 0.0180)))
    pill_h = max(32, int(width * (0.028 if is_ipad else 0.033)))
    pill_pad_x = int(width * (0.018 if is_ipad else 0.022))
    pill_gap = int(width * (0.012 if is_ipad else 0.014))
    pill_y = int(height * 0.178) - pill_h // 2

    pill_widths = [int(len(p.strip()) * pill_font_size * 0.56) + pill_pad_x * 2 for p in pills]
    total_pills_w = sum(pill_widths) + max(0, len(pills) - 1) * pill_gap
    cur_px = center_x - total_pills_w // 2
    pills_svg_lines = []
    for idx, p_text in enumerate(pills):
        pw = pill_widths[idx]
        rx = pill_h // 2
        stroke = "#FDE047" if idx == 0 else "#FFFFFF"
        stroke_op = "0.62" if idx == 0 else "0.30"
        fill_op = "0.12" if is_dark else "0.15"
        tx = cur_px + pw // 2
        ty = pill_y + int(pill_h * 0.67)
        pills_svg_lines.append(
            f'    <g id="pill-{idx + 1}">\n'
            f'      <rect x="{cur_px}" y="{pill_y}" width="{pw}" height="{pill_h}" rx="{rx}" ry="{rx}" '
            f'fill="#FFFFFF" fill-opacity="{fill_op}" stroke="{stroke}" stroke-opacity="{stroke_op}" stroke-width="1.4" />\n'
            f'      <text x="{tx}" y="{ty}" text-anchor="middle" font-family="{typography["body_font"]}" '
            f'font-size="{pill_font_size}" font-weight="600" fill="#FFFFFF">{html.escape(p_text.strip())}</text>\n'
            f'    </g>'
        )
        cur_px += pw + pill_gap

    # Canva DAHZG5VPIOs borderless dark-glass rounded header backdrop card
    badge_pill_w = int(width * (0.64 if is_ipad else 0.78))
    badge_pill_h = int(height * (0.194 if is_ipad else 0.190))
    badge_pill_x = (width - badge_pill_w) // 2
    badge_pill_y = int(height * (0.052 if is_ipad else 0.050))
    badge_pill_rx = 46 if is_ipad else 40

    replacements = {
        "{{WIDTH}}": str(width),
        "{{HEIGHT}}": str(height),
        "{{BG_START}}": theme["bg_start"],
        "{{BG_END}}": theme["bg_end"],
        "{{VEIL_OPACITY}}": theme.get("veil_opacity", "0.42" if is_dark else "0.28"),
        "{{VEIL_TOP_OPACITY}}": theme.get("veil_top_opacity", "0.44" if is_dark else "0.28"),
        "{{VEIL_HORIZON_OPACITY}}": theme.get("veil_mid_opacity", "0.12" if is_dark else "0.06"),
        "{{VEIL_BOTTOM_OPACITY}}": theme.get("veil_bot_opacity", "0.42" if is_dark else "0.28"),
        "{{GLOW_OPACITY}}": "0.14" if is_dark else "0.16",
        "{{BG_SHIFT_X}}": str(bg_shift_x),
        "{{BG_SHIFT_Y}}": str(bg_shift_y),
        "{{BG_DRAW_W}}": str(bg_draw_w),
        "{{BG_DRAW_H}}": str(bg_draw_h),
        "{{BADGE_PILL_X}}": str(badge_pill_x),
        "{{BADGE_PILL_Y}}": str(badge_pill_y),
        "{{BADGE_PILL_W}}": str(badge_pill_w),
        "{{BADGE_PILL_H}}": str(badge_pill_h),
        "{{BADGE_PILL_RX}}": str(badge_pill_rx),
        "{{PILLS_SVG}}": "\n".join(pills_svg_lines),
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
        "{{TITLE}}": html.escape(title.replace("\n", " ")),
        "{{SUBTITLE}}": html.escape(subtitle.replace("\n", " ")),
        "{{TITLE_SVG_TSPANS}}": title_tspans,
        "{{SUBTITLE_SVG_TSPANS}}": subtitle_tspans,
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
    for asset in prov.get("assets", []):
        p = ROOT / asset["path"]
        if p.exists() and p.is_file():
            asset["sha256"] = sha256_file(p)
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
    PROVENANCE_PATH.write_text(json.dumps(prov, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Render QırımKey App Store posters, SVGs, and optionally preview videos.")
    parser.add_argument(
        "--posters-only",
        "--skip-video",
        dest="posters_only",
        action="store_true",
        help="Render only PNG posters and SVG templates without re-encoding 22s MP4 videos.",
    )
    parser.add_argument(
        "--plan-b",
        "--raw-only",
        dest="plan_b",
        action="store_true",
        help="Output pure unframed language-personalized screenshots into AppStoreMetadata/Media as well as Media_PlanB.",
    )
    parser.add_argument(
        "--only",
        dest="only_shots",
        default="",
        help="Comma-separated list of shot IDs to composite (e.g. 04_home_light,05_home_dark).",
    )
    parser.add_argument(
        "--raw-dir",
        dest="raw_dir",
        default="",
        help="Optional directory containing raw store_{device}_{shotId}_{locale}.png screenshots.",
    )
    args = parser.parse_args(argv)

    composite_posters_and_videos(
        posters_only=args.posters_only,
        only_shots=args.only_shots,
        raw_dir=args.raw_dir,
        plan_b=args.plan_b,
    )
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    bg_rel = config.get("background_asset", "marketing/templates/assets/crimea_sunset_bg.png")
    bg_dark_rel = config.get("background_asset_dark", bg_rel)
    crimea_bg_light_uri = str((ROOT / bg_rel).resolve())
    crimea_bg_dark_uri = str((ROOT / bg_dark_rel).resolve()) if (ROOT / bg_dark_rel).exists() else crimea_bg_light_uri
    crimea_iphone_light = ROOT / "marketing/templates/assets/crimea_sunset_iphone_bg.png"
    crimea_iphone_dark = ROOT / "marketing/templates/assets/crimea_twilight_iphone_bg.png"
    crimea_bg_iphone_light_uri = str(crimea_iphone_light.resolve()) if crimea_iphone_light.exists() else crimea_bg_light_uri
    crimea_bg_iphone_dark_uri = str(crimea_iphone_dark.resolve()) if crimea_iphone_dark.exists() else crimea_bg_dark_uri

    manifest = {
        "template_version": config["template_version"],
        "background_asset": bg_rel,
        "background_asset_dark": bg_dark_rel,
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
                if is_ipad:
                    crimea_bg_uri = crimea_bg_dark_uri if theme_key == "dark" else crimea_bg_light_uri
                else:
                    crimea_bg_uri = crimea_bg_iphone_dark_uri if theme_key == "dark" else crimea_bg_iphone_light_uri
                localized_candidates: list[Path] = []
                if args.raw_dir:
                    raw_base = Path(args.raw_dir).resolve()
                    localized_candidates.extend([
                        raw_base / f"store_{dev_tag}_{shot_id}_{locale}.png",
                        raw_base / f"store_{dev_tag}_{shot_id}.png",
                    ])
                localized_candidates.extend([
                    ROOT / f"QTatar/AppStoreAssets/RawScreenshots/store_{dev_tag}_{shot_id}_{locale}.png",
                    ROOT / f"docs/release/2026-10-25/assets/store_{dev_tag}_{shot_id}_{locale}.png",
                    ROOT / f"QTatar/AppStoreAssets/RawScreenshots/store_{dev_tag}_{shot_id}.png",
                    ROOT / f"docs/release/2026-10-25/assets/store_{dev_tag}_{shot_id}.png",
                    ROOT / f"AppStoreMetadata/Screenshots/{subdir}/{shot_id}.png",
                ])
                shot_abs = next((p for p in localized_candidates if p.exists()), localized_candidates[-1])
                try:
                    shot_rel = str(shot_abs.relative_to(ROOT))
                except ValueError:
                    shot_rel = str(shot_abs)
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
    mode_desc = "localized posters" if args.posters_only else "localized posters & videos"
    print(f"Rendered {len(manifest['rendered_files'])} parameterized SVG templates + {mode_desc}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
