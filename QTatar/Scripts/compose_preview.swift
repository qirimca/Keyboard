#!/usr/bin/env swift
// Compose an App Store preview: burn timed captions into an authentic screen recording and mux an original soundtrack.
// Output is constant 30 fps H.264 + AAC stereo (mp4), same pixel size as the source.
// Usage: swift compose_preview.swift <in.mp4> <audio.wav> <out.mp4> <timeline.json> <top|middle> [max_seconds]
// timeline.json: [{"start":0.4,"end":4.4,"text":"..."}]
import AVFoundation
import AppKit
import CoreText
import CoreImage

struct Cap: Decodable { let start: Double; let end: Double; let text: String }

let a = CommandLine.arguments
guard a.count >= 6 else { fputs("usage: compose_preview.swift in wav out timeline top|middle [maxSec]\n", stderr); exit(1) }
let inURL = URL(fileURLWithPath: a[1]), wavURL = URL(fileURLWithPath: a[2]), outURL = URL(fileURLWithPath: a[3])
let caps = try JSONDecoder().decode([Cap].self, from: Data(contentsOf: URL(fileURLWithPath: a[4])))
let anchorTop = a[5] == "top"
let maxSec = a.count > 6 ? Double(a[6]) ?? 24.1 : 24.1
try? FileManager.default.removeItem(at: outURL)

let asset = AVURLAsset(url: inURL)
let wavAsset = AVURLAsset(url: wavURL)
guard let vTrack = asset.tracks(withMediaType: .video).first, let aTrack = wavAsset.tracks(withMediaType: .audio).first else {
    fputs("missing tracks\n", stderr); exit(2)
}
let size = vTrack.naturalSize
// Optional 8th arg "WxH" rescales the source (e.g. a 2064x2752 simulator recording -> 1200x1600).
var W = Int(size.width), H = Int(size.height)
if a.count > 8 { let p = a[8].split(separator: "x").compactMap { Int($0) }; if p.count == 2 { W = p[0]; H = p[1] } }
let needScale = W != Int(size.width) || H != Int(size.height)
let ciContext = CIContext(options: nil)
let fps = 30
// Optional 7th arg "a-b,c-d" keeps only those source ranges (real time, 1x) and concatenates them.
var segments: [(Double, Double)] = []
if a.count > 7 { for part in a[7].split(separator: ",") { let ab = part.split(separator: "-").compactMap { Double($0) }; if ab.count == 2 { segments.append((ab[0], ab[1])) } } }
let outSeconds = segments.isEmpty ? min(CMTimeGetSeconds(asset.duration), maxSec) : segments.reduce(0) { $0 + ($1.1 - $1.0) }
let total = Int(outSeconds * Double(fps))
func sourceTime(_ t: Double) -> Double {
    if segments.isEmpty { return t }
    var rem = t
    for (s0, s1) in segments { let d = s1 - s0; if rem <= d { return s0 + rem }; rem -= d }
    return segments.last!.1
}

let reader = try AVAssetReader(asset: asset)
let vOut = AVAssetReaderTrackOutput(track: vTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
reader.add(vOut)
let aReader = try AVAssetReader(asset: wavAsset)
let aOut = AVAssetReaderTrackOutput(track: aTrack, outputSettings: [
    AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
    AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 2])
aReader.add(aOut)

let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                      AVVideoMaxKeyFrameIntervalKey: fps, AVVideoExpectedSourceFrameRateKey: fps]])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vIn, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA), kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H])
let aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: [
    AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 128_000])
writer.add(vIn); writer.add(aIn)
writer.shouldOptimizeForNetworkUse = true
guard reader.startReading(), aReader.startReading(), writer.startWriting() else {
    fputs("start failed: \(String(describing: reader.error)) \(String(describing: writer.error))\n", stderr); exit(3)
}
writer.startSession(atSourceTime: .zero)

func drawCaption(_ ctx: CGContext, text: String, alpha: CGFloat) {
    var fs = CGFloat(W) * (anchorTop ? 0.056 : 0.050)
    var line: CTLine!, tw: CGFloat = 0, asc: CGFloat = 0, desc: CGFloat = 0, lead: CGFloat = 0
    for _ in 0..<8 {
        let font = NSFont.systemFont(ofSize: fs, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white.withAlphaComponent(alpha)]
        line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        tw = CGFloat(CTLineGetTypographicBounds(line, &asc, &desc, &lead))
        if tw + fs * 1.6 <= CGFloat(W) * 0.94 { break }
        fs *= 0.92
    }
    let padX = fs * 0.8, padY = fs * 0.46
    let ph = asc + desc + padY * 2, pw = tw + padX * 2
    let cyTop = CGFloat(H) * (anchorTop ? 0.083 : 0.50) + (1 - alpha) * fs * 0.5
    let rect = CGRect(x: (CGFloat(W) - pw) / 2, y: CGFloat(H) - cyTop - ph / 2, width: pw, height: ph)
    let path = CGPath(roundedRect: rect, cornerWidth: ph / 2, cornerHeight: ph / 2, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -fs * 0.15), blur: fs * 0.5, color: NSColor.black.withAlphaComponent(0.35 * alpha).cgColor)
    ctx.setFillColor(NSColor(calibratedRed: 7 / 255, green: 58 / 255, blue: 105 / 255, alpha: 0.86 * alpha).cgColor)
    ctx.addPath(path); ctx.fillPath()
    ctx.restoreGState()
    ctx.setStrokeColor(NSColor(calibratedRed: 1, green: 0.84, blue: 0, alpha: 0.55 * alpha).cgColor)
    ctx.setLineWidth(max(1.5, fs * 0.04)); ctx.addPath(path); ctx.strokePath()
    ctx.textPosition = CGPoint(x: rect.minX + padX, y: rect.minY + padY + desc)
    CTLineDraw(line, ctx)
}

func alpha(at t: Double) -> (Cap, CGFloat)? {
    for c in caps where t >= c.start && t <= c.end {
        let a = min(1.0, (t - c.start) / 0.25, (c.end - t) / 0.25)
        return (c, CGFloat(max(0, a)))
    }
    return nil
}

let group = DispatchGroup()
var pending: CMSampleBuffer? = vOut.copyNextSampleBuffer()
var cur: CVImageBuffer? = nil
var k = 0
group.enter()
vIn.requestMediaDataWhenReady(on: DispatchQueue(label: "video")) {
    while vIn.isReadyForMoreMediaData && k < total {
        let t = Double(k) / Double(fps)
        let ts = sourceTime(t)
        while let sb = pending, CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sb)) <= ts + 1e-6 || cur == nil {
            cur = CMSampleBufferGetImageBuffer(sb)
            pending = vOut.copyNextSampleBuffer()
            if pending == nil { break }
        }
        guard let src = cur, let pool = adaptor.pixelBufferPool else { k += 1; continue }
        var dstOpt: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &dstOpt)
        guard let dst = dstOpt else { k += 1; continue }
        CVPixelBufferLockBaseAddress(src, .readOnly); CVPixelBufferLockBaseAddress(dst, [])
        let sBytes = CVPixelBufferGetBytesPerRow(src), dBytes = CVPixelBufferGetBytesPerRow(dst)
        let sp = CVPixelBufferGetBaseAddress(src)!, dp = CVPixelBufferGetBaseAddress(dst)!
        if needScale {
            let img = CIImage(cvPixelBuffer: src).transformed(by: CGAffineTransform(scaleX: CGFloat(W) / size.width, y: CGFloat(H) / size.height))
            ciContext.render(img, to: dst)
        } else {
            for row in 0..<H { memcpy(dp + row * dBytes, sp + row * sBytes, min(sBytes, dBytes)) }
        }
        if let (c, al) = alpha(at: t),
           let ctx = CGContext(data: dp, width: W, height: H, bitsPerComponent: 8, bytesPerRow: dBytes, space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
            drawCaption(ctx, text: c.text, alpha: al)
        }
        CVPixelBufferUnlockBaseAddress(dst, []); CVPixelBufferUnlockBaseAddress(src, .readOnly)
        adaptor.append(dst, withPresentationTime: CMTime(value: CMTimeValue(k), timescale: CMTimeScale(fps)))
        k += 1
    }
    if k >= total { vIn.markAsFinished(); group.leave() }
}
group.enter()
let audioEnd = CMTime(seconds: Double(total) / Double(fps), preferredTimescale: 44100)
aIn.requestMediaDataWhenReady(on: DispatchQueue(label: "audio")) {
    while aIn.isReadyForMoreMediaData {
        if let sb = aOut.copyNextSampleBuffer(), CMTimeCompare(CMSampleBufferGetPresentationTimeStamp(sb), audioEnd) < 0 {
            aIn.append(sb)
        } else { aIn.markAsFinished(); group.leave(); break }
    }
}
group.wait()
let sem = DispatchSemaphore(value: 0)
writer.finishWriting { sem.signal() }
sem.wait()
print(writer.status == .completed ? "OK \(a[3]) frames=\(k) \(W)x\(H)" : "FAILED \(String(describing: writer.error))")
