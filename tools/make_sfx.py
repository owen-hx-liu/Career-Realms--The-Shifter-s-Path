#!/usr/bin/env python3
"""Dependency-free SFX generator for the Ancient Egypt flood quest.
Writes tiny 16-bit PCM mono WAVs (no external libs). Quiet, subtle cues.

Run:  python3 tools/make_sfx.py assets/generated/sfx
"""
import sys, os, struct, math, random

SR = 22050

def write_wav(path, samples):
    data = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s)) * 32767)
        data += struct.pack("<h", v)
    n = len(samples)
    byte_rate = SR * 2
    with open(path, "wb") as f:
        f.write(b"RIFF")
        f.write(struct.pack("<I", 36 + len(data)))
        f.write(b"WAVE")
        f.write(b"fmt ")
        f.write(struct.pack("<IHHIIHH", 16, 1, 1, SR, byte_rate, 2, 16))
        f.write(b"data")
        f.write(struct.pack("<I", len(data)))
        f.write(bytes(data))

def place_canal():
    # soft water "plop": pitch drops, quick decay, tiny splash noise
    dur = 0.16; n = int(SR*dur); out = []; phase = 0.0; rnd = random.Random(1)
    for i in range(n):
        t = i/SR
        f = 300 + 250*math.exp(-t*28)
        phase += 2*math.pi*f/SR
        env = math.exp(-t*20)
        noise = (rnd.random()*2-1)*math.exp(-t*70)*0.25
        out.append((math.sin(phase)*0.55 + noise)*env*0.5)
    return out

def pickup():
    # bright two-note rise (gather/collect)
    out = []; rnd = random.Random(2)
    for (f0, d) in [(659, 0.07), (988, 0.12)]:
        n = int(SR*d); phase = 0.0
        for i in range(n):
            t = i/SR
            phase += 2*math.pi*f0/SR
            env = math.exp(-t*14)
            out.append((math.sin(phase)*0.5 + math.sin(phase*2)*0.12)*env*0.45)
    return out

def flood():
    # gentle rising water whoosh: filtered noise swell
    dur = 0.7; n = int(SR*dur); out = []; rnd = random.Random(3); lp = 0.0
    for i in range(n):
        t = i/SR
        white = rnd.random()*2-1
        cutoff = 0.04 + 0.22*(t/dur)          # open up over time
        lp += (white - lp)*cutoff
        swell = math.sin(math.pi*min(1.0, t/dur))   # 0->1->0
        # a low watery tone underneath
        tone = math.sin(2*math.pi*(120+60*t)*t)*0.15
        out.append((lp*0.9 + tone)*swell*0.4)
    return out

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/generated/sfx"
    os.makedirs(out, exist_ok=True)
    write_wav(os.path.join(out, "place_canal.wav"), place_canal())
    write_wav(os.path.join(out, "pickup.wav"), pickup())
    write_wav(os.path.join(out, "flood.wav"), flood())
    print("Wrote canal SFX to", out)

if __name__ == "__main__":
    main()
