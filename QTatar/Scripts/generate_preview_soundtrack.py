#!/usr/bin/env python3
"""Original synthesized App Preview soundtrack (no third-party music, no samples): calm modal pad + sparse pentatonic plucks.
Usage: python3 generate_preview_soundtrack.py <out.wav> [duration_seconds=24.1]
"""
import array
import math
import random
import sys
import wave

SR = 44100
out = sys.argv[1]
dur = float(sys.argv[2]) if len(sys.argv) > 2 else 24.1
n = int(SR * dur)
random.seed(27)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


# four chords x ~6 s: Dm9, Bbmaj7, Gm6/9 (dorian colour), A sus - all D dorian / minor-pentatonic friendly
chords = [[50, 57, 60, 64, 69], [46, 58, 62, 65, 69], [43, 55, 62, 65, 69], [45, 57, 62, 64, 67]]
pent = [62, 65, 67, 69, 72, 74, 77, 79]  # D minor pentatonic-ish, octave 4-5
L = array.array("f", [0.0]) * n
R = array.array("f", [0.0]) * n

# pad
seg = dur / len(chords)
for ci, ch in enumerate(chords):
    t0, t1 = ci * seg, (ci + 1) * seg + 1.4  # overlap into next chord
    for ni, m in enumerate(ch):
        f = hz(m)
        pan = 0.35 + 0.3 * ((ni % 3) / 2.0)
        for d, det in ((0, -0.0035), (1, 0.0035)):
            ff = f * (1 + det)
            a = int(t0 * SR)
            b = min(n, int(t1 * SR))
            for i in range(a, b):
                t = (i - a) / SR
                env = min(1.0, t / 1.6) * min(1.0, max(0.0, (t1 - t0 - t) / 1.4))
                v = (math.sin(2 * math.pi * ff * t) + 0.35 * math.sin(4 * math.pi * ff * t)) * env * 0.030
                L[i] += v * (1 - pan)
                R[i] += v * pan

# plucks (eighth notes at 92 bpm, probabilistic, gentle)
step = 60.0 / 92.0 / 2.0
t = 0.45
last = 3
while t < dur - 1.2:
    if random.random() < 0.62:
        last = max(0, min(len(pent) - 1, last + random.choice([-2, -1, 1, 2, 3])))
        f = hz(pent[last])
        a = int(t * SR)
        pan = random.uniform(0.3, 0.7)
        for i in range(a, min(n, a + int(1.6 * SR))):
            tt = (i - a) / SR
            env = math.exp(-3.8 * tt) * min(1.0, tt / 0.004)
            v = (math.sin(2 * math.pi * f * tt) + 0.4 * math.sin(4 * math.pi * f * tt) + 0.15 * math.sin(6 * math.pi * f * tt)) * env * 0.085
            L[i] += v * (1 - pan)
            R[i] += v * pan
    t += step

# cheap stereo reverb: three feedback delays
for buf, delays in ((L, (0.037, 0.061, 0.089)), (R, (0.043, 0.067, 0.097))):
    for dl in delays:
        d = int(dl * SR)
        for i in range(d, n):
            buf[i] += buf[i - d] * 0.28

peak = max(max(abs(x) for x in L), max(abs(x) for x in R)) or 1.0
gain = 0.50 / peak  # about -6 dBFS peak, leaves headroom
fade_in, fade_out = int(0.8 * SR), int(1.6 * SR)
pcm = array.array("h")
for i in range(n):
    g = gain * min(1.0, i / fade_in) * min(1.0, (n - i) / fade_out)
    pcm.append(int(max(-1, min(1, L[i] * g)) * 32767))
    pcm.append(int(max(-1, min(1, R[i] * g)) * 32767))
with wave.open(out, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("wrote", out, round(dur, 2), "s")
