#!/usr/bin/env python3
"""Measure key geometry on a keyboard screenshot (pure PIL, no numpy).

Usage: measure_keys.py IMAGE.png [--scale S] [--y Y1,Y2,Y3,...] [--thr 245]

Scans each given y (pixel row) for runs of near-white pixels (letter keys) and prints their x ranges,
widths, gaps and centres in points (pixels / --scale). It also measures the key height and the corner
radius of the first run at each y. Use it to compare a screenshot of a native keyboard with QirimKey.
"""
import argparse
from PIL import Image


def runs(line, thr, min_len):
    out, start = [], None
    for x, v in enumerate(line):
        white = v >= thr
        if white and start is None:
            start = x
        elif not white and start is not None:
            if x - start >= min_len:
                out.append((start, x - 1))
            start = None
    if start is not None and len(line) - start >= min_len:
        out.append((start, len(line) - 1))
    return out


def vertical_extent(img, x, y, thr):
    w, h = img.size
    px = img.load()
    top = y
    while top > 0 and px[x, top - 1] >= thr:
        top -= 1
    bottom = y
    while bottom < h - 1 and px[x, bottom + 1] >= thr:
        bottom += 1
    return top, bottom


def corner_radius(img, x0, top, thr):
    """Radius = how many pixels the white boundary is inset on the key's first row, measured on the left edge."""
    px = img.load()
    # walk down from the top edge until the left edge reaches its final x position
    inset_rows = 0
    for dy in range(0, 60):
        y = top + dy
        x = x0
        # find first white pixel at or before x0 + 40
        first = None
        for xx in range(max(0, x0 - 4), x0 + 40):
            if px[xx, y] >= thr:
                first = xx
                break
        if first is None:
            inset_rows += 1
            continue
        if first <= x0 + 0:
            break
        inset_rows += 1
    return inset_rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--scale", type=float, default=1.0, help="pixels per point")
    ap.add_argument("--y", default="", help="comma separated pixel rows to scan")
    ap.add_argument("--thr", type=int, default=245)
    ap.add_argument("--min", type=int, default=20, help="minimum key width in px")
    args = ap.parse_args()
    img = Image.open(args.image).convert("L")
    w, h = img.size
    print(f"image {w}x{h}px scale {args.scale} -> {w / args.scale:.1f}x{h / args.scale:.1f}pt")
    ys = [int(v) for v in args.y.split(",") if v] or [int(h * f) for f in (0.66, 0.75, 0.84)]
    px = img.load()
    for y in ys:
        line = [px[x, y] for x in range(w)]
        found = runs(line, args.thr, args.min)
        print(f"\ny={y}px ({y / args.scale:.1f}pt): {len(found)} runs")
        prev_end = None
        for i, (a, b) in enumerate(found):
            width = (b - a + 1) / args.scale
            gap = (a - prev_end - 1) / args.scale if prev_end is not None else float("nan")
            centre = (a + b) / 2 / args.scale
            print(f"  [{i:2d}] x={a / args.scale:7.1f}..{b / args.scale:7.1f}pt  w={width:5.1f}  gap={gap:5.1f}  centre={centre:7.1f}")
            prev_end = b
        if found:
            a, b = found[0]
            cx = (a + b) // 2
            top, bottom = vertical_extent(img, cx, y, args.thr)
            print(f"  first key height {(bottom - top + 1) / args.scale:.1f}pt  corner-inset-rows {corner_radius(img, a, top, args.thr) / args.scale:.1f}pt")


if __name__ == "__main__":
    main()
