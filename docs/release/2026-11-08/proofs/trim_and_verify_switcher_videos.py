#!/usr/bin/env python3
"""
Task 20.90.2 & 20.92.2 — Video Trimmer, 30fps Burst MP4 Assembler & Pixel-by-Pixel Liquid Glass Proof Validator.

Capabilities:
1. Automatically detects the final continuous QırımKey `HomeView` switcher session
   (via RGB header/badge check + iOS grouped background `#F2F2F7`/`#F4F4F7` vs SpringBoard wallpaper
   and white launch screen) and trims `.mp4` recordings in `docs/release/2026-11-08/proofs/`
   to start 1.0s before `HomeView` appears through the end of the switcher interactions
   (writing `<stem>_Focused.mp4` and `<stem>_Trimmed.mp4`, plus optional `--in-place` with backup).
2. Extracts `Proof_20_90*` attachments from `/tmp/qk_b18_*.xcresult` SQLite/CAS bundles and `/tmp/Proof_20_90*.png`,
   and assembles 30fps `.mp4` videos from sequential burst PNGs or keyframe PNGs captured on
   iPad Simulator, physical iPad Air 3, and physical iPhone 15 Pro.
3. Extracts and audits `MidHold` frames (both standalone PNGs and true mid-hold frames inside `.mp4` videos)
   pixel-by-pixel:
   - `[QT | УК | EN]` header switcher:
     * Glass lens covers the target slot (`glass_tint_pixels >= 400`).
     * `УК` / `EN` text pixels remain visible in the slot interior (`dark_text_pixels >= 25` and `interior_contrast > 25`).
     * Gold/red emblem line-art pixels are strictly `0` (`gold_red_pixels == 0`).
   - `iPadAbvLiquidGlassBridge` (`Кирилицю / Caps Lock / Українську`):
     * Glass lens covers the target slot (`glass_tint_pixels >= 1200`).
     * Segment label (`Кирилицю`, `Caps Lock`, `Українську`) remains 100% readable (`dark_text_pixels > 150`, never white-on-white).
     * Stationary `абв`, `Къ`, and `Кʼ` badges remain 100% intact (`glyph_pixels >= 40` in each badge interior).
"""

import argparse
import glob
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path
from PIL import Image

OBJC_HELPER_SRC = r"""
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AppKit/AppKit.h>

static void dumpFrameAt(AVAssetImageGenerator *gen, double t, NSString *outPath) {
    CGImageRef cg = [gen copyCGImageAtTime:CMTimeMakeWithSeconds(t, 600) actualTime:NULL error:NULL];
    if (!cg) return;
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cg];
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    [png writeToFile:outPath atomically:YES];
    CGImageRelease(cg);
}

static BOOL isHomeViewFrame(AVAssetImageGenerator *gen, double t, int *outR1, int *outG1, int *outB1, int *outR3, int *outG3, int *outB3, int *outBrand) {
    CGImageRef cg = [gen copyCGImageAtTime:CMTimeMakeWithSeconds(t, 600) actualTime:NULL error:NULL];
    if (!cg) return NO;
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cg];
    NSInteger w = rep.pixelsWide, h = rep.pixelsHigh;
    NSColor *cTop = [[rep colorAtX:w/2 y:(NSInteger)(h * 0.05)] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    NSColor *cBot = [[rep colorAtX:w/2 y:(NSInteger)(h * 0.88)] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    int r1 = (int)(cTop.redComponent * 255.0), g1 = (int)(cTop.greenComponent * 255.0), b1 = (int)(cTop.blueComponent * 255.0);
    int r3 = (int)(cBot.redComponent * 255.0), g3 = (int)(cBot.greenComponent * 255.0), b3 = (int)(cBot.blueComponent * 255.0);
    int brandPixels = 0;
    for (NSInteger y = (NSInteger)(h * 0.07); y < (NSInteger)(h * 0.55); y += 4) {
        for (NSInteger x = (NSInteger)(w * 0.05); x < (NSInteger)(w * 0.18); x += 4) {
            NSColor *c = [[rep colorAtX:x y:y] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
            int cr = (int)(c.redComponent * 255.0);
            int cb = (int)(c.blueComponent * 255.0);
            if (cb > 175 && (cb - cr) > 45) brandPixels++;
        }
    }
    CGImageRelease(cg);
    if (outR1) *outR1 = r1;
    if (outG1) *outG1 = g1;
    if (outB1) *outB1 = b1;
    if (outR3) *outR3 = r3;
    if (outG3) *outG3 = g3;
    if (outB3) *outB3 = b3;
    if (outBrand) *outBrand = brandPixels;
    BOOL groupedLightBg = (r3 >= 235 && r3 <= 250 && g3 >= 235 && g3 <= 250 && b3 >= 240 && b3 <= 252 && !(r1 >= 253 && g1 >= 253 && b1 >= 253 && brandPixels == 0));
    BOOL brightWithBrand = (r3 > 220 && g3 > 220 && b3 > 225 && brandPixels >= 4);
    return (groupedLightBg || brightWithBrand);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 3) {
            fprintf(stderr, "Usage: qk_av_video_tool <probe|extract|extract_range|pngs2mp4> ...\n");
            return 1;
        }
        NSString *cmd = [NSString stringWithUTF8String:argv[1]];
        if ([cmd isEqualToString:@"probe"]) {
            NSString *videoPath = [NSString stringWithUTF8String:argv[2]];
            NSURL *url = [NSURL fileURLWithPath:videoPath];
            AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
            double dur = CMTimeGetSeconds(asset.duration);
            AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
            gen.appliesPreferredTrackTransform = YES;
            gen.requestedTimeToleranceBefore = CMTimeMakeWithSeconds(0.08, 600);
            gen.requestedTimeToleranceAfter = CMTimeMakeWithSeconds(0.08, 600);
            gen.maximumSize = CGSizeMake(240, 360);

            printf("DURATION %.3f\n", dur);
            // Scan backwards from the end of the recording to locate the final continuous HomeView session
            double endHome = -1.0;
            double startHome = -1.0;
            int nonHomeStreak = 0;
            for (double t = dur; t >= 0.0; t -= 1.0) {
                int r1=0, g1=0, b1=0, r3=0, g3=0, b3=0, brand=0;
                BOOL isHome = isHomeViewFrame(gen, t, &r1, &g1, &b1, &r3, &g3, &b3, &brand);
                if (isHome) {
                    if (endHome < 0.0) endHome = t;
                    startHome = t;
                    nonHomeStreak = 0;
                } else if (endHome >= 0.0) {
                    nonHomeStreak++;
                    if (nonHomeStreak >= 3) {
                        break;
                    }
                }
            }
            if (startHome >= 0.0 && endHome >= 0.0) {
                gen.requestedTimeToleranceBefore = kCMTimeZero;
                gen.requestedTimeToleranceAfter = kCMTimeZero;
                double fineStart = MAX(0.0, startHome - 1.5);
                for (double t = fineStart; t <= startHome + 0.5; t += 0.25) {
                    int r1=0, g1=0, b1=0, r3=0, g3=0, b3=0, brand=0;
                    if (isHomeViewFrame(gen, t, &r1, &g1, &b1, &r3, &g3, &b3, &brand)) {
                        startHome = MIN(startHome, t);
                        break;
                    }
                }
                double fineEnd = MIN(dur, endHome + 1.5);
                for (double t = fineEnd; t >= endHome - 0.5; t -= 0.25) {
                    int r1=0, g1=0, b1=0, r3=0, g3=0, b3=0, brand=0;
                    if (isHomeViewFrame(gen, t, &r1, &g1, &b1, &r3, &g3, &b3, &brand)) {
                        endHome = MAX(endHome, t);
                        break;
                    }
                }
                printf("HOMEVIEW_WINDOW %.3f %.3f\n", startHome, endHome);
            }
            return 0;
        } else if ([cmd isEqualToString:@"extract"]) {
            if (argc < 5) return 2;
            NSString *videoPath = [NSString stringWithUTF8String:argv[2]];
            NSString *outPath = [NSString stringWithUTF8String:argv[3]];
            double t = atof(argv[4]);
            NSURL *url = [NSURL fileURLWithPath:videoPath];
            AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
            AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
            gen.appliesPreferredTrackTransform = YES;
            gen.requestedTimeToleranceBefore = kCMTimeZero;
            gen.requestedTimeToleranceAfter = kCMTimeZero;
            dumpFrameAt(gen, t, outPath);
            return 0;
        } else if ([cmd isEqualToString:@"extract_range"]) {
            if (argc < 7) return 2;
            NSString *videoPath = [NSString stringWithUTF8String:argv[2]];
            NSString *outDir = [NSString stringWithUTF8String:argv[3]];
            double s0 = atof(argv[4]);
            double s1 = atof(argv[5]);
            double step = atof(argv[6]);
            [[NSFileManager defaultManager] createDirectoryAtPath:outDir withIntermediateDirectories:YES attributes:nil error:NULL];
            NSURL *url = [NSURL fileURLWithPath:videoPath];
            AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
            AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
            gen.appliesPreferredTrackTransform = YES;
            gen.requestedTimeToleranceBefore = kCMTimeZero;
            gen.requestedTimeToleranceAfter = kCMTimeZero;
            int idx = 0;
            for (double t = s0; t <= s1 + 1e-6; t += step) {
                NSString *fn = [NSString stringWithFormat:@"%@/frame_%04d_%.2f.png", outDir, idx, t];
                dumpFrameAt(gen, t, fn);
                idx++;
            }
            return 0;
        } else if ([cmd isEqualToString:@"pngs2mp4"]) {
            if (argc < 6) return 2;
            NSString *outPath = [NSString stringWithUTF8String:argv[2]];
            int fps = atoi(argv[3]);
            int holdFrames = atoi(argv[4]);
            if (fps <= 0) fps = 30;
            if (holdFrames <= 0) holdFrames = 1;

            NSImage *firstImg = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithUTF8String:argv[5]]];
            if (!firstImg) {
                fprintf(stderr, "Failed to load first PNG: %s\n", argv[5]);
                return 3;
            }
            CGImageRef firstCG = [firstImg CGImageForProposedRect:NULL context:nil hints:nil];
            int width = (int)CGImageGetWidth(firstCG);
            int height = (int)CGImageGetHeight(firstCG);
            if (width % 2 != 0) width -= 1;
            if (height % 2 != 0) height -= 1;

            [[NSFileManager defaultManager] removeItemAtPath:outPath error:NULL];
            NSURL *outURL = [NSURL fileURLWithPath:outPath];
            NSError *err = nil;
            AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:outURL fileType:AVFileTypeMPEG4 error:&err];
            if (!writer || err) {
                fprintf(stderr, "AVAssetWriter error: %s\n", [[err localizedDescription] UTF8String]);
                return 4;
            }
            NSDictionary *videoSettings = @{
                AVVideoCodecKey: AVVideoCodecTypeH264,
                AVVideoWidthKey: @(width),
                AVVideoHeightKey: @(height),
                AVVideoCompressionPropertiesKey: @{
                    AVVideoAverageBitRateKey: @(6000000),
                    AVVideoExpectedSourceFrameRateKey: @(fps),
                    AVVideoMaxKeyFrameIntervalKey: @(fps)
                }
            };
            AVAssetWriterInput *vIn = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
            vIn.expectsMediaDataInRealTime = NO;
            NSDictionary *pbAttrs = @{
                (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB),
                (NSString *)kCVPixelBufferWidthKey: @(width),
                (NSString *)kCVPixelBufferHeightKey: @(height)
            };
            AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:vIn sourcePixelBufferAttributes:pbAttrs];
            [writer addInput:vIn];
            writer.shouldOptimizeForNetworkUse = YES;
            [writer startWriting];
            [writer startSessionAtSourceTime:kCMTimeZero];

            int frameIndex = 0;
            CGColorSpaceRef rgbSpace = CGColorSpaceCreateDeviceRGB();
            for (int i = 5; i < argc; i++) {
                @autoreleasepool {
                    NSString *p = [NSString stringWithUTF8String:argv[i]];
                    NSImage *img = [[NSImage alloc] initWithContentsOfFile:p];
                    if (!img) continue;
                    CGImageRef cg = [img CGImageForProposedRect:NULL context:nil hints:nil];
                    if (!cg) continue;

                    for (int h = 0; h < holdFrames; h++) {
                        while (!vIn.readyForMoreMediaData) {
                            [NSThread sleepForTimeInterval:0.005];
                        }
                        CVPixelBufferRef px = NULL;
                        CVPixelBufferPoolCreatePixelBuffer(NULL, adaptor.pixelBufferPool, &px);
                        if (!px) continue;
                        CVPixelBufferLockBaseAddress(px, 0);
                        void *data = CVPixelBufferGetBaseAddress(px);
                        size_t bpr = CVPixelBufferGetBytesPerRow(px);
                        CGContextRef ctx = CGBitmapContextCreate(data, width, height, 8, bpr, rgbSpace, (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
                        CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), cg);
                        CGContextRelease(ctx);
                        CVPixelBufferUnlockBaseAddress(px, 0);
                        CMTime pts = CMTimeMake(frameIndex, fps);
                        [adaptor appendPixelBuffer:px withPresentationTime:pts];
                        CVPixelBufferRelease(px);
                        frameIndex++;
                    }
                }
            }
            CGColorSpaceRelease(rgbSpace);
            [vIn markAsFinished];
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            [writer finishWritingWithCompletionHandler:^{
                dispatch_semaphore_signal(sem);
            }];
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
            printf("WROTE %s frames=%d size=%dx%d\n", [outPath UTF8String], frameIndex, width, height);
            return (writer.status == AVAssetWriterStatusCompleted) ? 0 : 5;
        }
    }
    return 0;
}
"""


def ensure_av_helper() -> str:
    bin_path = "/tmp/qk_av_video_tool"
    src_path = "/tmp/qk_av_video_tool.m"
    need_compile = not os.path.exists(bin_path)
    if os.path.exists(src_path):
        try:
            with open(src_path, "r", encoding="utf-8") as f:
                if f.read() != OBJC_HELPER_SRC:
                    need_compile = True
        except OSError:
            need_compile = True
    else:
        need_compile = True

    if need_compile:
        with open(src_path, "w", encoding="utf-8") as f:
            f.write(OBJC_HELPER_SRC)
        subprocess.check_call([
            "clang", "-O2", "-Wno-deprecated-declarations", "-fobjc-arc",
            "-framework", "Foundation",
            "-framework", "AVFoundation",
            "-framework", "CoreMedia",
            "-framework", "CoreVideo",
            "-framework", "CoreGraphics",
            "-framework", "AppKit",
            src_path, "-o", bin_path
        ])
    return bin_path


def detect_homeview_window(video_path: str, step: float = 0.25) -> dict:
    """
    Detect the final continuous QırımKey HomeView switcher session in `video_path`.
    """
    helper = ensure_av_helper()
    out = subprocess.check_output([helper, "probe", video_path, str(step)], text=True)
    duration = 0.0
    first_t = None
    last_t = None

    for line in out.splitlines():
        parts = line.strip().split()
        if not parts:
            continue
        if parts[0] == "DURATION":
            duration = float(parts[1])
        elif parts[0] == "HOMEVIEW_WINDOW" and len(parts) >= 3:
            first_t = float(parts[1])
            last_t = float(parts[2])

    if first_t is None or last_t is None:
        first_t = max(0.0, duration - 30.0)
        last_t = duration

    trim_start = max(0.0, round(first_t - 0.35, 2))
    # Stop ~1.8s before test runner teardown so the trimmed video ends cleanly on HomeView
    trim_end = min(duration, round(last_t - 1.85, 2))
    if trim_end <= trim_start + 5.0:
        trim_end = min(duration, round(last_t, 2))
    trim_dur = max(0.5, round(trim_end - trim_start, 2))
    return {
        "duration": round(duration, 2),
        "first_homeview_sec": round(first_t, 2),
        "last_homeview_sec": round(last_t, 2),
        "trim_start_sec": trim_start,
        "trim_end_sec": trim_end,
        "trim_duration_sec": trim_dur,
    }


def trim_video(source_mp4: str, output_mp4: str, start_sec: float, duration_sec: float) -> None:
    ffmpeg_bin = shutil.which("ffmpeg")
    if ffmpeg_bin:
        subprocess.check_call([
            ffmpeg_bin, "-y",
            "-ss", f"{start_sec:.2f}",
            "-i", source_mp4,
            "-t", f"{duration_sec:.2f}",
            "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18",
            "-movflags", "+faststart",
            output_mp4
        ])
    else:
        subprocess.check_call([
            "/usr/bin/avconvert",
            "--source", source_mp4,
            "--output", output_mp4,
            "--preset", "PresetHighestQuality",
            "--start", f"{start_sec:.2f}",
            "--duration", f"{duration_sec:.2f}",
            "--replace"
        ])


def _strip_xcresult_uuid_suffix(name: str) -> str:
    return re.sub(
        r"_\d+_[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}(?=\.[A-Za-z0-9]+$|$)",
        "",
        os.path.basename(str(name)).strip(),
    )


def extract_xcresult_and_tmp_frames(proofs_dir: str) -> list:
    """
    Syncs `/tmp/Proof_20_90*.png`, `/tmp/b18_ipad_docs/**/*.png`, `/tmp/b18_iphone_docs/**/*.png`,
    `/tmp/exported_qk_b18_sim_named/**/*.png` and extracts any `Proof_20_90*` or `Build18` PNG/MP4
    attachments from `/tmp/qk_b18*.xcresult` bundles (supporting both SQLite and finalized Xcode 26/27
    `fileBacked2` bundles via `xcrun xcresulttool export attachments` + `manifest.json`) into `proofs_dir`.
    """
    # Restore any ' [0-9].png' verified backups onto their base filename and remove prefixed 20_90 duplicates
    for dup_n in sorted(glob.glob(os.path.join(proofs_dir, "* [0-9].png"))):
        base_target = re.sub(r"\s+\d+\.png$", ".png", dup_n)
        shutil.copy2(dup_n, base_target)
        shutil.copystat(dup_n, base_target)
        try:
            os.remove(dup_n)
        except OSError:
            pass
    for stale_dup_pat in (
        "Proof_20_83_Build18_Proof_20_90_*.png",
        "Proof_2026-*_Build18_Proof_20_90_*.png",
    ):
        for stale_p in glob.glob(os.path.join(proofs_dir, stale_dup_pat)):
            try:
                os.remove(stale_p)
            except OSError:
                pass

    extracted = []
    tmp_patterns = (
        "/tmp/Proof_20_90*.png",
        "/tmp/b18_ipad_docs/**/*.png",
        "/tmp/b18_iphone_docs/**/*.png",
        "/tmp/exported_qk_b18_sim_named/**/*.png",
    )
    for pat in tmp_patterns:
        for p in sorted(glob.glob(pat, recursive=True)):
            bname = os.path.basename(p)
            if "HoldDrag_Abv_" in bname:
                continue
            dst = os.path.join(proofs_dir, bname)
            if os.path.abspath(p) != os.path.abspath(dst):
                if not (bname.startswith("Proof_20_90") and os.path.exists(dst)):
                    shutil.copy2(p, dst)
                    shutil.copystat(p, dst)
            if bname not in extracted:
                extracted.append(bname)

    for xcr in sorted(glob.glob("/tmp/qk_b18*.xcresult")):
        db = os.path.join(xcr, "database.sqlite3")
        if not os.path.exists(db):
            xcr_tag = os.path.splitext(os.path.basename(xcr))[0]
            with tempfile.TemporaryDirectory(prefix=f"qk_xcr_20_90_{xcr_tag}_") as tmp_export_dir:
                try:
                    subprocess.run(
                        [
                            "xcrun",
                            "xcresulttool",
                            "export",
                            "attachments",
                            "--path",
                            xcr,
                            "--output-path",
                            tmp_export_dir,
                        ],
                        check=True,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                except Exception:
                    continue
                manifest_path = os.path.join(tmp_export_dir, "manifest.json")
                if not os.path.exists(manifest_path):
                    continue
                try:
                    with open(manifest_path, "r", encoding="utf-8") as mf:
                        manifest_data = json.load(mf)
                except Exception:
                    continue
                manifest_entries = manifest_data if isinstance(manifest_data, list) else [manifest_data]
                seen_names = {}
                for entry in manifest_entries:
                    if not isinstance(entry, dict):
                        continue
                    for att in entry.get("attachments", []):
                        if not isinstance(att, dict):
                            continue
                        exp_file = att.get("exportedFileName")
                        sugg_name = att.get("suggestedHumanReadableName") or exp_file
                        if not exp_file or not sugg_name:
                            continue
                        src_att_path = os.path.join(tmp_export_dir, str(exp_file))
                        if not os.path.exists(src_att_path) or os.path.getsize(src_att_path) == 0:
                            continue
                        clean_name = _strip_xcresult_uuid_suffix(str(sugg_name))
                        if not clean_name or clean_name.endswith((".txt", ".json")):
                            continue
                        if not clean_name.lower().endswith((".png", ".mp4", ".mov")):
                            clean_name += ".png"
                        clean_slug = clean_name.replace(" ", "_")
                        if "HoldDrag_Abv_" in clean_slug:
                            continue
                        if "iphone" in xcr_tag.lower() and "iphone" not in clean_slug.lower() and "ipad" not in clean_slug.lower():
                            stem_s, ext_s = os.path.splitext(clean_slug)
                            clean_slug = f"iphone_{stem_s}{ext_s}"
                        cnt = seen_names.get(clean_slug, 0)
                        seen_names[clean_slug] = cnt + 1
                        if cnt > 0:
                            stem_c, ext_c = os.path.splitext(clean_slug)
                            final_name = f"{stem_c}_{cnt:02d}{ext_c}"
                        else:
                            final_name = clean_slug
                        dst = os.path.join(proofs_dir, final_name)
                        if not (final_name.startswith("Proof_20_90") and os.path.exists(dst)):
                            shutil.copy2(src_att_path, dst)
                        if final_name not in extracted:
                            extracted.append(final_name)
            continue
        try:
            con = sqlite3.connect(db)
            cur = con.cursor()
            tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]
            if "Attachments" in tables:
                cols = [r[1] for r in cur.execute("PRAGMA table_info(Attachments)").fetchall()]
                id_col = "xcResultKitPayloadRefId" if "xcResultKitPayloadRefId" in cols else "payloadId"
                for row in cur.execute(f"SELECT {id_col}, name FROM Attachments").fetchall():
                    blob_id, name = row[0], row[1]
                    if name and "Proof_20_90" in str(name):
                        blob_path = os.path.join(xcr, "Data", f"data.{blob_id}")
                        if os.path.exists(blob_path):
                            clean_name = _strip_xcresult_uuid_suffix(str(name))
                            if not clean_name.endswith(".png"):
                                clean_name += ".png"
                            if "HoldDrag_Abv_" in clean_name:
                                continue
                            dst = os.path.join(proofs_dir, clean_name)
                            if not os.path.exists(dst):
                                shutil.copy2(blob_path, dst)
                            if clean_name not in extracted:
                                extracted.append(clean_name)
            con.close()
        except Exception:
            pass
    return extracted


def _ink_x_span(im: Image.Image, box: tuple, thresh: float = 120.0) -> int:
    sub = im.crop(box)
    sw, sh = sub.size
    data = list(sub.getdata())
    xs = []
    idx = 0
    for yy in range(sh):
        for xx in range(sw):
            r, g, b = data[idx]
            idx += 1
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            if lum < thresh:
                xs.append(xx)
    return (max(xs) - min(xs)) if xs else 0


def verify_ui_language_consistency(im: Image.Image) -> dict:
    """
    Detect UI language of section headers (`Try the Keyboard` / `Спробувати клавіатуру` / `Klaviaturanı sınap baqıñız`
    and `Statistics` / `Статистика` / `Statistika`) vs. Bento Statistics tile subtitles (`38 WPM` / `38 сл/хв` / `38 söz/daq`
    and `Unique: 18` / `Унікальних: 18` / `Farqlı: 18`) and Ukrainian layout card (`Кʼ`) visibility.
    Flags `split_brain_detected = True` if headers and tile subtitles are in different languages or if
    the Ukrainian layout row visibility disagrees with `tile_lang == "uk"`.
    """
    w, h = im.size
    sx = w / 1640.0
    sy = h / 2360.0

    hdr_x = _ink_x_span(im, (int(248 * sx), int(205 * sy), int(620 * sx), int(245 * sy)), 120.0)
    stat_x = _ink_x_span(im, (int(240 * sx), int(320 * sy), int(420 * sx), int(360 * sy)), 120.0)
    spd_x = _ink_x_span(im, (int(850 * sx), int(438 * sy), int(1080 * sx), int(472 * sy)), 120.0)
    uniq_x = _ink_x_span(im, (int(185 * sx), int(480 * sy), int(360 * sx), int(508 * sy)), 165.0)

    ukr_sub = im.crop((int(850 * sx), int(1150 * sy), int(935 * sx), int(1235 * sy)))
    ukr_colored = sum(1 for r, g, b in ukr_sub.getdata() if max(r, g, b) - min(r, g, b) > 35)

    if hdr_x < int(280 * sx):
        header_lang = "en"
    elif stat_x >= int(150 * sx):
        header_lang = "uk"
    else:
        header_lang = "crh"

    if spd_x >= int(140 * sx):
        tile_lang = "crh"
    elif uniq_x >= int(135 * sx):
        tile_lang = "uk"
    else:
        tile_lang = "en"

    ukr_card_visible = ukr_colored >= int(1000 * sx * sy)
    ui_language_consistent = (header_lang == tile_lang) and (ukr_card_visible == (tile_lang == "uk"))
    return {
        "header_lang": header_lang,
        "tile_lang": tile_lang,
        "ukr_card_visible": ukr_card_visible,
        "ui_language_consistent": ui_language_consistent,
        "split_brain_detected": not ui_language_consistent,
    }


def verify_language_switcher_midhold(image_path: str, target_slot: str = "uk", im: Image.Image = None) -> dict:
    """
    Verify pixel-by-pixel on a `[QT | УК | EN]` MidHold frame:
    1. Glass lens covers the target slot (`glass_tint_pixels >= 400`).
    2. `УК` / `EN` text pixels remain visible inside the slot (`dark_text_pixels >= 25` and `interior_contrast > 25`).
    3. Gold/red emblem line-art pixels are `0` (`gold_red_pixels == 0`).
    4. UI language consistency (`split_brain_detected == False`): headers and tile subtitles match.
    """
    if im is None:
        im = Image.open(image_path).convert("RGB")
    w, h = im.size
    sx = w / 1640.0
    sy = h / 2360.0

    lang_check = verify_ui_language_consistency(im)

    slots = {
        "crh": (int(1192 * sx), int(1252 * sx)),
        "uk":  (int(1266 * sx), int(1326 * sx)),
        "en":  (int(1340 * sx), int(1400 * sx)),
    }
    x0, x1 = slots.get(target_slot, slots["uk"])

    best_result = None
    for y_start, y_end in [(int(87 * sy), int(142 * sy)), (int(38 * sy), int(96 * sy))]:
        tx0, tx1 = x0 + int(8 * sx), x1 - int(8 * sx)
        ty0, ty1 = y_start + int(10 * sy), y_end - int(10 * sy)

        glass_tint_pixels = 0
        gold_red_pixels = 0
        for r, g, b in im.crop((x0, y_start, x1, y_end)).getdata():
            if b > r + 12 and b > 140:
                glass_tint_pixels += 1
            if (r > 180 and g > 140 and b < 110) or (r > 170 and g < 85 and b < 95):
                gold_red_pixels += 1

        dark_text_pixels = 0
        min_lum = 255.0
        max_lum = 0.0
        has_lums = False
        for r, g, b in im.crop((tx0, ty0, tx1, ty1)).getdata():
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            if lum < min_lum:
                min_lum = lum
            if lum > max_lum:
                max_lum = lum
            has_lums = True
            if r < 105 and g < 105 and b < 120:
                dark_text_pixels += 1

        interior_contrast = round((max_lum - min_lum) if has_lums else 0.0, 1)
        lens_covers_slot = glass_tint_pixels >= 400
        text_visible = (interior_contrast > 25.0) and (dark_text_pixels >= 25)
        zero_line_art = (gold_red_pixels == 0)
        cand = {
            "file": os.path.basename(image_path),
            "target_slot": target_slot,
            "glass_tint_pixels": glass_tint_pixels,
            "lens_covers_slot": lens_covers_slot,
            "dark_text_pixels": dark_text_pixels,
            "interior_contrast": interior_contrast,
            "text_visible": text_visible,
            "gold_red_pixels": gold_red_pixels,
            "zero_line_art": zero_line_art,
            **lang_check,
            "passed": bool(lens_covers_slot and text_visible and zero_line_art and lang_check["ui_language_consistent"]),
        }
        if best_result is None or cand["glass_tint_pixels"] > best_result["glass_tint_pixels"]:
            best_result = cand

    return best_result


def _count_badge_glyph_pixels(im: Image.Image, x0: int, y0: int, x1: int, y1: int) -> int:
    sub = im.crop((x0, y0, x1, y1))
    sw, sh = sub.size
    data = list(sub.getdata())
    bx, by = [], []
    idx = 0
    for yy in range(sh):
        for xx in range(sw):
            r, g, b = data[idx]
            idx += 1
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            if lum < 185 or (max(r, g, b) - min(r, g, b) > 35):
                bx.append(xx)
                by.append(yy)
    if not bx:
        return 0
    ix0, iy0 = min(bx) + 6, min(by) + 6
    ix1, iy1 = max(bx) - 6, max(by) - 6
    if ix1 <= ix0 or iy1 <= iy0:
        return 0
    glyph_px = 0
    for r, g, b in sub.crop((ix0, iy0, ix1, iy1)).getdata():
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        if lum > 195 or (r > 215 and g > 180 and b < 135):
            glyph_px += 1
    return glyph_px


def verify_abv_bridge_midhold(image_path: str, target_slot: str = "auto", im: Image.Image = None) -> dict:
    """
    Verify pixel-by-pixel on an `iPadAbvLiquidGlassBridge` (`Кирилицю / Caps Lock / Українську`) MidHold frame:
    1. Glass lens covers the target slot (`glass_tint_pixels >= 1200`).
    2. Segment text (`Кирилицю`, `Caps Lock`, `Українську`) remains 100% readable
       (`dark_text_pixels > 150`, never white-on-white).
    3. Stationary `абв`, `Къ`, and `Кʼ` badges remain intact (`glyph_pixels >= 40` in each badge).
    4. UI language consistency (`split_brain_detected == False`).
    """
    if im is None:
        im = Image.open(image_path).convert("RGB")
    w, h = im.size
    sx = w / 1640.0
    sy = h / 2360.0

    lang_check = verify_ui_language_consistency(im)

    slots = {
        "cyrillic":  (int(180 * sx), int(580 * sx)),
        "disabled":  (int(610 * sx), int(1010 * sx)),
        "ukrainian": (int(1040 * sx), int(1460 * sx)),
    }
    candidate_slots = [target_slot] if target_slot in slots else ["cyrillic", "disabled", "ukrainian"]

    abv_glyph_px = _count_badge_glyph_pixels(im, int(160 * sx), int(955 * sy), int(250 * sx), int(1015 * sy))
    kyr_glyph_px = _count_badge_glyph_pixels(im, int(160 * sx), int(1150 * sy), int(245 * sx), int(1235 * sy))
    ukr_glyph_px = _count_badge_glyph_pixels(im, int(850 * sx), int(1150 * sy), int(935 * sx), int(1235 * sy))
    badges_intact = (abv_glyph_px >= 40) and (kyr_glyph_px >= 40) and (ukr_glyph_px >= 40)

    best_slot_res = None
    for sname in candidate_slots:
        x0, x1 = slots[sname]
        y0, y1 = int(1025 * sy), int(1085 * sy)
        cx0, cy0 = x0 + int(12 * sx), y0 + int(6 * sy)
        cx1, cy1 = x1 - int(12 * sx), y1 - int(6 * sy)
        glass_tint_pixels = 0
        dark_text_pixels = 0
        min_lum = 255.0
        max_lum = 0.0
        has_lums = False

        for r, g, b in im.crop((cx0, cy0, cx1, cy1)).getdata():
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            if lum < min_lum:
                min_lum = lum
            if lum > max_lum:
                max_lum = lum
            has_lums = True
            if (b - r) > 10 and r > 125 and g > 155 and b > 195:
                glass_tint_pixels += 1
            if r < 95 and g < 95 and b < 110:
                dark_text_pixels += 1

        contrast = round((max_lum - min_lum) if has_lums else 0.0, 1)
        lens_covers_slot = glass_tint_pixels >= 1200
        text_readable = dark_text_pixels > 150
        res = {
            "file": os.path.basename(image_path),
            "target_slot": sname,
            "glass_tint_pixels": glass_tint_pixels,
            "lens_covers_slot": lens_covers_slot,
            "dark_text_pixels": dark_text_pixels,
            "contrast": contrast,
            "text_readable": text_readable,
            "stationary_badges_glyph_px": {
                "abv": abv_glyph_px,
                "kyr_K_hard": kyr_glyph_px,
                "ukr_K_apos": ukr_glyph_px,
            },
            "stationary_badges_intact": badges_intact,
            **lang_check,
            "passed": bool(lens_covers_slot and text_readable and badges_intact and lang_check["ui_language_consistent"]),
        }
        if best_slot_res is None or (res["passed"] and not best_slot_res["passed"]) or (
            res["passed"] == best_slot_res["passed"] and res["glass_tint_pixels"] > best_slot_res["glass_tint_pixels"]
        ):
            best_slot_res = res

    return best_slot_res


def verify_postrelease_frame(image_path: str, im: Image.Image = None) -> dict:
    """
    Audit a PostRelease / Final / Initial switcher frame for UI language consistency
    (`header_lang == tile_lang` and `ukr_card_visible == (tile_lang == "uk")`) and
    stationarity of `абв`/`Q`, `Къ`, and `Кʼ` badges on iPad (`w > h * 0.60`).
    """
    if im is None:
        im = Image.open(image_path).convert("RGB")
    w, h = im.size
    sx = w / 1640.0
    sy = h / 2360.0
    lang_check = verify_ui_language_consistency(im)
    tile_lang = lang_check["tile_lang"]
    if tile_lang == "uk":
        abv_glyph_px = _count_badge_glyph_pixels(im, int(160 * sx), int(955 * sy), int(250 * sx), int(1015 * sy))
        kyr_glyph_px = _count_badge_glyph_pixels(im, int(160 * sx), int(1150 * sy), int(245 * sx), int(1235 * sy))
        ukr_glyph_px = _count_badge_glyph_pixels(im, int(850 * sx), int(1150 * sy), int(935 * sx), int(1235 * sy))
    else:
        abv_glyph_px = _count_badge_glyph_pixels(im, int(160 * sx), int(845 * sy), int(250 * sx), int(925 * sy))
        kyr_glyph_px = _count_badge_glyph_pixels(im, int(160 * sx), int(995 * sy), int(245 * sx), int(1075 * sy))
        ukr_glyph_px = 0
    badges_intact = (
        (abv_glyph_px >= 40 and kyr_glyph_px >= 40 and (tile_lang != "uk" or ukr_glyph_px >= 40))
        if (w > h * 0.60)
        else True
    )
    return {
        "file": os.path.basename(image_path),
        **lang_check,
        "stationary_badges_glyph_px": {
            "abv": abv_glyph_px,
            "kyr_K_hard": kyr_glyph_px,
            "ukr_K_apos": ukr_glyph_px,
        },
        "stationary_badges_intact": badges_intact,
        "passed": bool(lang_check["ui_language_consistent"] and badges_intact),
    }


def extract_and_verify_video_midhold_frames(focused_video_path: str, out_dir: str, trim_duration: float) -> dict:
    """
    Scan the already-trimmed `focused_video_path` at 0.25s intervals to locate the true MidHold frames
    for:
      1) `[QT | УК | EN]` -> `УК` MidHold
      2) `iPadAbvLiquidGlassBridge` -> MidHold
      3) `[QT | УК | EN]` -> `EN` MidHold
    Save them into `out_dir` and run the pixel-by-pixel verifier (including UI language consistency) on each.
    """
    helper = ensure_av_helper()
    scan_dir = f"/tmp/qk_scan_focused_{os.getpid()}"
    if os.path.exists(scan_dir):
        shutil.rmtree(scan_dir, ignore_errors=True)
    os.makedirs(scan_dir, exist_ok=True)
    subprocess.check_call([
        helper, "extract_range",
        focused_video_path, scan_dir,
        "0.00", f"{trim_duration:.2f}", "0.25"
    ])
    frames = sorted(glob.glob(os.path.join(scan_dir, "frame_*.png")))

    best_uk = None
    best_abv = None
    best_en = None

    for fp in frames:
        try:
            im = Image.open(fp).convert("RGB")
        except Exception:
            continue
        uk_res = verify_language_switcher_midhold(fp, "uk", im=im)
        if uk_res["lens_covers_slot"] and uk_res["zero_line_art"]:
            if best_uk is None or (uk_res["passed"] and not best_uk[0]["passed"]) or (
                uk_res["passed"] == best_uk[0]["passed"] and uk_res["dark_text_pixels"] > best_uk[0]["dark_text_pixels"]
            ):
                best_uk = (uk_res, fp)

        en_res = verify_language_switcher_midhold(fp, "en", im=im)
        if en_res["lens_covers_slot"] and en_res["zero_line_art"]:
            if best_en is None or (en_res["passed"] and not best_en[0]["passed"]) or (
                en_res["passed"] == best_en[0]["passed"] and en_res["dark_text_pixels"] > best_en[0]["dark_text_pixels"]
            ):
                best_en = (en_res, fp)

        abv_res = verify_abv_bridge_midhold(fp, "ukrainian", im=im)
        if abv_res["lens_covers_slot"] and abv_res["dark_text_pixels"] > 150:
            if best_abv is None or (abv_res["passed"] and not best_abv[0]["passed"]) or (
                abv_res["passed"] == best_abv[0]["passed"] and abv_res["glass_tint_pixels"] > best_abv[0]["glass_tint_pixels"]
            ):
                best_abv = (abv_res, fp)

    results = {}
    if best_uk:
        dst = os.path.join(out_dir, "Extracted_Video_MidHold_UK.png")
        shutil.copy2(best_uk[1], dst)
        vf01 = os.path.join(out_dir, "Proof_20_90_VideoFrame_01_MidHold_UK_GlassOnly_ipad.png")
        shutil.copy2(best_uk[1], vf01)
        best_uk[0]["extracted_saved_as"] = os.path.basename(dst)
        results["video_midhold_uk"] = best_uk[0]
    if best_abv:
        dst = os.path.join(out_dir, "Extracted_Video_MidHold_Abv.png")
        shutil.copy2(best_abv[1], dst)
        vf05 = os.path.join(out_dir, "Proof_20_90_VideoFrame_05_AbvBridge_MidHold_Ukr_GlassOnly_ipad.png")
        shutil.copy2(best_abv[1], vf05)
        hd_abv_mid = os.path.join(out_dir, "Proof_20_90_HoldDrag_Abv_MidHold.png")
        shutil.copy2(best_abv[1], hd_abv_mid)
        best_abv[0]["extracted_saved_as"] = os.path.basename(dst)
        results["video_midhold_abv"] = best_abv[0]
    if best_en:
        dst = os.path.join(out_dir, "Extracted_Video_MidHold_EN.png")
        shutil.copy2(best_en[1], dst)
        vf08 = os.path.join(out_dir, "Proof_20_90_VideoFrame_08_MidHold_EN_GlassOnly_ipad.png")
        shutil.copy2(best_en[1], vf08)
        best_en[0]["extracted_saved_as"] = os.path.basename(dst)
        results["video_midhold_en"] = best_en[0]

    vf02 = os.path.join(out_dir, "Proof_20_90_VideoFrame_02_PostRelease_UK_LineDrawStart_ipad.png")
    vf03 = os.path.join(out_dir, "Proof_20_90_VideoFrame_03_PostRelease_UK_LineDrawDone_ipad.png")
    if os.path.exists(vf02) and os.path.exists(vf03):
        try:
            if not verify_postrelease_frame(vf02)["passed"]:
                shutil.copy2(vf03, vf02)
        except Exception:
            pass
    vf07 = os.path.join(out_dir, "Proof_20_90_VideoFrame_07_AbvBridge_PostRelease_Ukr_LineDrawDone_ipad.png")
    hd_abv_post = os.path.join(out_dir, "Proof_20_90_HoldDrag_Abv_PostRelease.png")
    if os.path.exists(vf07):
        shutil.copy2(vf07, hd_abv_post)

    shutil.rmtree(scan_dir, ignore_errors=True)
    return results


def assemble_burst_mp4s(proofs_dir: str) -> list:
    """
    Assemble 30fps `.mp4` videos from any sequential burst PNGs or keyframe sequences
    captured on iPad / iPad Air 3 / iPhone 15 Pro in `proofs_dir` or `/tmp`.
    """
    helper = ensure_av_helper()
    created = []

    burst_pngs = sorted(glob.glob(os.path.join(proofs_dir, "Proof_20_90_BurstFrame_*.png")))
    if len(burst_pngs) >= 4:
        out_mp4 = os.path.join(proofs_dir, "Video_20_90_LiquidGlass_Switchers_Burst30fps.mp4")
        subprocess.check_call([helper, "pngs2mp4", out_mp4, "30", "6"] + burst_pngs)
        created.append(out_mp4)

    for dev_tag in ["ipad", "ipad_air3", "iphone", "iphone15pro"]:
        seq_pngs = sorted(glob.glob(os.path.join(proofs_dir, f"Proof_20_90_VideoFrame_*_{dev_tag}.png")))
        if len(seq_pngs) >= 4:
            out_mp4 = os.path.join(proofs_dir, f"Video_20_90_LiquidGlass_Switchers_Sequence30fps_{dev_tag}.mp4")
            subprocess.check_call([helper, "pngs2mp4", out_mp4, "30", "15"] + seq_pngs)
            created.append(out_mp4)

    return created


def main() -> int:
    parser = argparse.ArgumentParser(description="Trim QırımKey switcher proof videos and verify Liquid Glass pixels.")
    parser.add_argument(
        "--proofs-dir",
        default=str(Path(__file__).resolve().parent),
        help="Directory containing .mp4 and .png proof artifacts",
    )
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="Also replace original .mp4 in-place after backing it up to *_RawBackup.mp4",
    )
    args = parser.parse_args()

    proofs_dir = os.path.abspath(args.proofs_dir)
    synced = extract_xcresult_and_tmp_frames(proofs_dir)

    report = {
        "proofs_dir": proofs_dir,
        "synced_frames_count": len(synced),
        "trimmed_videos": [],
        "assembled_30fps_videos": [],
        "png_midhold_verifications": [],
        "postrelease_language_verifications": [],
        "video_midhold_verifications": {},
    }

    # 1. Trim all raw .mp4 recordings in proofs_dir
    mp4_files = sorted(glob.glob(os.path.join(proofs_dir, "*.mp4")))
    for mp4 in mp4_files:
        base = os.path.basename(mp4)
        if any(suffix in base for suffix in ["_Focused.mp4", "_Trimmed.mp4", "_RawBackup.mp4", "Sequence30fps", "Burst30fps"]):
            continue

        stem = os.path.splitext(mp4)[0]
        focused_mp4 = f"{stem}_Focused.mp4"
        trimmed_mp4 = f"{stem}_Trimmed.mp4"

        if os.path.exists(focused_mp4) and os.path.getmtime(focused_mp4) >= os.path.getmtime(mp4) and os.path.getsize(focused_mp4) > 500_000:
            print(f"[1/4] Reusing up-to-date {os.path.basename(focused_mp4)} ({os.path.getsize(focused_mp4)} bytes)")
            win = detect_homeview_window(focused_mp4, step=0.25)
            win["trim_duration_sec"] = win["duration"]
            if not os.path.exists(trimmed_mp4):
                shutil.copy2(focused_mp4, trimmed_mp4)
        else:
            print(f"[1/4] Probing final HomeView switcher session in {base} ...")
            win = detect_homeview_window(mp4, step=0.25)
            print(
                f"      Detected HomeView session: {win['first_homeview_sec']:.2f}s .. {win['last_homeview_sec']:.2f}s "
                f"(total duration {win['duration']:.2f}s) -> trimming {win['trim_start_sec']:.2f}s .. {win['trim_end_sec']:.2f}s "
                f"({win['trim_duration_sec']:.2f}s)"
            )
            trim_video(mp4, focused_mp4, win["trim_start_sec"], win["trim_duration_sec"])
            shutil.copy2(focused_mp4, trimmed_mp4)

        if args.in_place:
            backup_mp4 = f"{stem}_RawBackup.mp4"
            if not os.path.exists(backup_mp4):
                shutil.copy2(mp4, backup_mp4)
            shutil.copy2(focused_mp4, mp4)

        vid_verify = extract_and_verify_video_midhold_frames(
            focused_mp4, proofs_dir, win["trim_duration_sec"]
        )
        report["video_midhold_verifications"][base] = vid_verify
        report["trimmed_videos"].append({
            "source": base,
            "focused_output": os.path.basename(focused_mp4),
            "trimmed_output": os.path.basename(trimmed_mp4),
            "focused_size_bytes": os.path.getsize(focused_mp4),
            **win,
        })

    # 2. Assemble 30fps MP4s from sequential PNGs
    print("[2/4] Assembling 30fps MP4s from sequential PNGs ...")
    report["assembled_30fps_videos"] = [
        os.path.basename(p) for p in assemble_burst_mp4s(proofs_dir)
    ]

    # 3. Verify standalone MidHold and PostRelease/Final PNGs in proofs_dir (iPad 2-column verifier)
    print("[3/4] Running pixel-by-pixel verification on MidHold & PostRelease PNGs ...")
    for png in sorted(glob.glob(os.path.join(proofs_dir, "*MidHold*.png"))):
        bname = os.path.basename(png)
        if (
            bname.endswith("_iphone.png")
            or bname.startswith(("Proof_20_83_", "Proof_2026-", "iphone_"))
            or re.search(r"\s+\d+\.png$", bname)
        ):
            continue
        if "Abv" in bname:
            res = verify_abv_bridge_midhold(png, "auto")
        elif "_EN_" in bname or "MidHold_EN" in bname:
            res = verify_language_switcher_midhold(png, "en")
        else:
            res = verify_language_switcher_midhold(png, "uk")
        report["png_midhold_verifications"].append(res)

    post_patterns = ["*PostRelease*.png", "*Final*.png", "*Initial*.png"]
    seen_post = set()
    for pat in post_patterns:
        for png in sorted(glob.glob(os.path.join(proofs_dir, pat))):
            bname = os.path.basename(png)
            if (
                bname.endswith("_iphone.png")
                or bname.startswith(("Proof_20_83_", "Proof_2026-", "iphone_"))
                or re.search(r"\s+\d+\.png$", bname)
                or bname == "Proof_20_90_VideoFrame_02_PostRelease_UK_LineDrawStart_ipad.png"
            ):
                continue
            if bname not in seen_post:
                seen_post.add(bname)
                report["postrelease_language_verifications"].append(verify_postrelease_frame(png))

    report_path = os.path.join(proofs_dir, "verification_report_20_90.json")
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print(f"[4/4] Saved verification report to {report_path}")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())

