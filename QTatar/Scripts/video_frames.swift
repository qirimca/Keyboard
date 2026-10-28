#!/usr/bin/env swift
// Usage: swift video_frames.swift <input.mp4> <out_dir> <step_seconds> [max_width]
// Writes frame_XXX.png (one every step seconds). Used to verify videos when a viewer cannot play .mp4 directly.
import AVFoundation
import AppKit

let a = CommandLine.arguments
guard a.count >= 4 else { fputs("usage: video_frames.swift in out step [maxw]\n", stderr); exit(1) }
let url = URL(fileURLWithPath: a[1])
let outDir = a[2]
let step = Double(a[3]) ?? 1.0
let maxW = a.count > 4 ? CGFloat(Double(a[4]) ?? 300) : 300
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let asset = AVURLAsset(url: url)
let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
gen.maximumSize = CGSize(width: maxW, height: maxW * 4)
let dur = CMTimeGetSeconds(asset.duration)
var t = 0.0
var i = 0
while t < dur {
    if let cg = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) {
        let rep = NSBitmapImageRep(cgImage: cg)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: String(format: "%@/frame_%03d.png", outDir, i)))
        }
    }
    i += 1
    t += step
}
print("frames:", i, "duration:", dur)
