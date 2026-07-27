#!/usr/bin/env python3
"""Dependency-free pixel-art generator for the NANOBOT SURGEON quest.

Writes RGBA PNGs directly (no Pillow), in the same beveled / dark-outline
house style as tools/make_immune.py and tools/make_art.py. Theme: a warm
crimson bloodstream interior with cool teal nano-tech accents and gold UI.

Generates:
  * background        : bg (1152x648)
  * 9-slice UI frames : frame_panel, frame_window, frame_banner, button,
                        bar_bg, bar_fill
  * gameplay sprites  : nanobot, breach, healed, pathogen, microbe, clot,
                        rbc, spark, glow
  * icons             : icon_integrity, icon_repair, icon_clock
  * stars             : star_full, star_empty

Run:  python3 tools/make_nanobot.py assets/generated/nanobot
Then: Godot --headless --path . --import   (so the engine can load them)
"""
import sys, os, zlib, struct, math, random


# ============================================================ PNG writer ====
def write_png(path, w, h, px):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for (r, g, b, a) in px[y * w:(y + 1) * w]:
            raw += bytes((r, g, b, a))

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n"
                + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
                + chunk(b"IEND", b""))


# ================================================================ canvas ====
class C:
    def __init__(self, w, h, bg=(0, 0, 0, 0)):
        self.w, self.h = w, h
        self.px = [bg] * (w * h)

    def set(self, x, y, c):
        x = int(x); y = int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            if len(c) == 3:
                c = (c[0], c[1], c[2], 255)
            self.px[y * self.w + x] = c if c[3] == 255 else blend(self.px[y * self.w + x], c)

    def disc(self, cx, cy, r, c):
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    self.set(x, y, c)

    def ring(self, cx, cy, r, t, c):
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                d2 = (x - cx) ** 2 + (y - cy) ** 2
                if (r - t) ** 2 <= d2 <= r * r:
                    self.set(x, y, c)

    def rect(self, x0, y0, w, h, c):
        for y in range(int(y0), int(y0 + h)):
            for x in range(int(x0), int(x0 + w)):
                self.set(x, y, c)

    def line(self, x0, y0, x1, y1, c, t=1.0):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            f = i / max(1, n)
            self.disc(x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, t, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.set(x, y, c)


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


def blend(bg, fg):
    a = fg[3] / 255.0
    return (int(fg[0] * a + bg[0] * (1 - a)), int(fg[1] * a + bg[1] * (1 - a)),
            int(fg[2] * a + bg[2] * (1 - a)), max(bg[3], fg[3]))


def shade(c, f):
    return (max(0, min(255, int(c[0] * f))), max(0, min(255, int(c[1] * f))),
            max(0, min(255, int(c[2] * f))), c[3] if len(c) == 4 else 255)


def mix(a, b, f):
    return (int(a[0] * (1 - f) + b[0] * f), int(a[1] * (1 - f) + b[1] * f),
            int(a[2] * (1 - f) + b[2] * f), 255)


def outline(c, col, thresh=60):
    w, h = c.w, c.h
    snap = list(c.px)
    for y in range(h):
        for x in range(w):
            if snap[y * w + x][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and snap[ny * w + nx][3] > thresh:
                    c.px[y * w + x] = col
                    break


OUTLINE = hx("#0b0608")          # universal near-black outline

# theme palette ---------------------------------------------------------------
TEAL = hx("#2fe0d2")
TEAL_HI = hx("#8ff6ec")
TEAL_DK = hx("#13796f")
STEEL = hx("#c6d2dd")
STEEL_MD = hx("#7f8 b9a".replace(" ", ""))  # guard against typo
STEEL_MD = hx("#7f8b9a")
STEEL_DK = hx("#414c5a")
CRIMSON = hx("#8f2233")
GOLD = hx("#d8b24a")
GOLD_HI = hx("#f4dc82")


# ============================================================ cell helpers ===
def membrane(c, cx, cy, R, body, seed=1, bumpy=0.0):
    """Beveled round cell: bright top-left, dark bottom-right, speckles."""
    bl = shade(body, 1.30)
    bd = shade(body, 0.66)
    rnd = random.Random(seed)
    for y in range(int(cy - R) - 2, int(cy + R) + 3):
        for x in range(int(cx - R) - 2, int(cx + R) + 3):
            ang = math.atan2(y - cy, x - cx)
            rr = R + (math.sin(ang * 5 + seed) * bumpy * R)
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if d2 <= rr * rr:
                d = (x - cx) + (y - cy)
                col = body
                if d > R * 0.45:
                    col = bd
                elif d < -R * 0.55:
                    col = bl
                c.set(x, y, col)
    for _ in range(int(R * 1.6)):
        a = rnd.random() * math.tau
        rr = rnd.random() * R * 0.8
        c.disc(cx + math.cos(a) * rr, cy + math.sin(a) * rr,
               rnd.choice([0.6, 1, 1]), shade(body, rnd.choice([0.82, 1.16])))


def nucleus(c, cx, cy, r, col):
    c.disc(cx, cy, r, col)
    c.disc(cx - r * 0.3, cy - r * 0.3, r * 0.45, shade(col, 1.3))
    c.disc(cx + r * 0.3, cy + r * 0.35, r * 0.32, shade(col, 0.72))


def spikes(c, cx, cy, R, n, length, col, knob=False, phase=0.0, thick=1.4):
    tip = shade(col, 1.2)
    for i in range(n):
        a = phase + i / n * math.tau
        ex, ey = cx + math.cos(a) * (R + length), cy + math.sin(a) * (R + length)
        c.line(cx + math.cos(a) * (R - 1), cy + math.sin(a) * (R - 1), ex, ey, col, thick)
        if knob:
            c.disc(ex, ey, thick + 1.1, tip)


# ============================================================ THE NANOBOT ====
def nanobot():
    """32x32 top-down nanobot, nose pointing UP (rotated in code).
    Chrome hull, glowing teal core, twin manipulator claws, rear thruster."""
    S = 32; c = C(S, S); cx = S / 2 - 0.5
    # rear thruster glow
    c.disc(cx, 27, 3.2, hx("#1c6f7a"))
    c.disc(cx, 28, 2.0, TEAL_HI)
    # hull: a rounded teardrop (wide tail, pointed nose)
    for y in range(6, 27):
        f = (y - 6) / 21.0
        half = 3.0 + 7.5 * math.sin(f * math.pi * 0.92)
        for x in range(int(cx - half), int(cx + half) + 1):
            d = (x - cx)
            # bevel: left highlight, right shadow
            if d < -half * 0.55:
                col = shade(STEEL, 1.12)
            elif d > half * 0.5:
                col = STEEL_DK
            else:
                col = STEEL_MD
            c.set(x, y, col)
    # crisp top-left rim shine
    for y in range(8, 24):
        f = (y - 6) / 21.0
        half = 3.0 + 7.5 * math.sin(f * math.pi * 0.92)
        c.set(cx - half + 1, y, hx("#eef4fa"))
    # plated seams
    for yy in (12, 18):
        c.line(cx - 6, yy, cx + 6, yy, STEEL_DK, 0.5)
    # twin manipulator claws at the nose
    for s in (-1, 1):
        c.line(cx + s * 3, 8, cx + s * 6, 3, STEEL_MD, 1.1)
        c.disc(cx + s * 6, 3, 1.4, STEEL)
        c.set(cx + s * 6, 2, TEAL_HI)
    # glowing core
    c.disc(cx, 16, 4.6, TEAL_DK)
    c.disc(cx, 16, 3.4, TEAL)
    c.disc(cx - 1, 15, 1.6, TEAL_HI)
    c.disc(cx, 16, 0.9, hx("#ffffff"))
    # little side antennae lights
    for s in (-1, 1):
        c.set(cx + s * 8, 14, hx("#ff5a6a"))
    outline(c, OUTLINE)
    return S, S, c.px


# ============================================================ REPAIR SITES ===
def breach():
    """40x40 damage site: a torn, dark wound ringed by raw crimson tissue."""
    S = 40; c = C(S, S); cx = cy = S / 2 - 0.5
    rnd = random.Random(7)
    # raw inflamed tissue halo (irregular)
    for y in range(S):
        for x in range(S):
            d = math.hypot(x - cx, y - cy)
            ang = math.atan2(y - cy, x - cx)
            edge = 15 + math.sin(ang * 6) * 2.0 + math.sin(ang * 3 + 1) * 1.5
            if d <= edge:
                if d > edge - 3:
                    c.set(x, y, shade(CRIMSON, 1.25))      # bright torn rim
                elif d > 8:
                    c.set(x, y, mix(CRIMSON, hx("#3a0c14"), (d - 8) / 7.0))
                else:
                    c.set(x, y, hx("#240609"))             # dark wound center
    # jagged cracks radiating out
    for i in range(7):
        a = i / 7 * math.tau + rnd.random() * 0.4
        L = 9 + rnd.random() * 5
        c.line(cx, cy, cx + math.cos(a) * L, cy + math.sin(a) * L, hx("#1a0508"), 0.8)
    # glistening highlights / exposed flesh specks
    for _ in range(14):
        a = rnd.random() * math.tau; rr = rnd.random() * 6
        c.disc(cx + math.cos(a) * rr, cy + math.sin(a) * rr, rnd.choice([0.6, 1]),
               shade(hx("#c4485a"), rnd.choice([0.8, 1.2])))
    # angry red alert pip at center
    c.disc(cx, cy, 2.0, hx("#ff3a4a"))
    c.disc(cx - 0.5, cy - 0.5, 0.9, hx("#ffb0b8"))
    outline(c, OUTLINE)
    return S, S, c.px


def healed():
    """40x40 repaired site: clean pink tissue sealed with a teal nano-suture."""
    S = 40; c = C(S, S); cx = cy = S / 2 - 0.5
    skin, skin_hi, skin_dk = hx("#e88fa0"), hx("#f6c2cd"), hx("#b85f72")
    for y in range(S):
        for x in range(S):
            d = math.hypot(x - cx, y - cy)
            if d <= 13:
                dd = (x - cx) + (y - cy)
                col = skin
                if dd > 6:
                    col = skin_dk
                elif dd < -7:
                    col = skin_hi
                c.set(x, y, col)
    # healthy speckle
    rnd = random.Random(3)
    for _ in range(16):
        a = rnd.random() * math.tau; rr = rnd.random() * 11
        c.disc(cx + math.cos(a) * rr, cy + math.sin(a) * rr, rnd.choice([0.6, 1]),
               shade(skin, rnd.choice([0.9, 1.12])))
    # teal nano-seal: a glowing plus / suture cross
    c.disc(cx, cy, 5.5, hx("#1c6f64"))
    c.disc(cx, cy, 4.2, TEAL)
    c.line(cx - 3, cy, cx + 3, cy, TEAL_HI, 0.9)
    c.line(cx, cy - 3, cx, cy + 3, TEAL_HI, 0.9)
    c.disc(cx, cy, 1.0, hx("#ffffff"))
    # suture ticks around rim
    for i in range(8):
        a = i / 8 * math.tau
        c.line(cx + math.cos(a) * 9, cy + math.sin(a) * 9,
               cx + math.cos(a) * 12, cy + math.sin(a) * 12, TEAL_HI, 0.7)
    outline(c, OUTLINE)
    return S, S, c.px


# ============================================================ HAZARDS ========
def pathogen():
    """28x28 spiky virus obstacle (violet)."""
    S = 28; c = C(S, S); cx = cy = S / 2 - 0.5
    body, spk, nuc = hx("#8a4bd0"), hx("#b98ef0"), hx("#3f2470")
    spikes(c, cx, cy, 9, 12, 4, spk, knob=True, thick=1.2)
    membrane(c, cx, cy, 9, body, seed=11)
    nucleus(c, cx, cy, 4.0, nuc)
    # menacing eye-glints
    c.disc(cx - 2.4, cy - 1, 1.0, hx("#ff5a6a"))
    c.disc(cx + 2.4, cy - 1, 1.0, hx("#ff5a6a"))
    outline(c, OUTLINE)
    return S, S, c.px


def microbe():
    """28x20 rod bacterium obstacle (sickly green-violet) with flagella."""
    S = 28; c = C(S, S); cx = cy = S / 2 - 0.5
    body, nuc = hx("#7a9b3a"), hx("#3c4a18")
    for s in (-1, 1):
        ox = cx + s * 9
        for i in range(8):
            f = i / 8.0
            c.set(ox + s * i * 1.3, cy + math.sin(f * 7 + s) * 4, hx("#a7c25a"))
    rx, ry = 10, 5
    bl, bd = shade(body, 1.28), shade(body, 0.66)
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                d = (x - cx) * 0.3 + (y - cy)
                col = body
                if d > ry * 0.5:
                    col = bd
                elif d < -ry * 0.6:
                    col = bl
                c.set(x, y, col)
    nucleus(c, cx - 3, cy, 2.4, nuc); nucleus(c, cx + 4, cy + 1, 2.0, nuc)
    outline(c, OUTLINE)
    return S, S, c.px


def clot():
    """32x32 dark fibrin clot — a clump of platelets and strands."""
    S = 32; c = C(S, S); cx = cy = S / 2 - 0.5
    rnd = random.Random(5)
    base = hx("#5a2230")
    blobs = [(cx, cy, 9)]
    for _ in range(6):
        a = rnd.random() * math.tau; rr = rnd.uniform(4, 8)
        blobs.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr, rnd.uniform(4, 6.5)))
    for (bx, by, br) in blobs:
        membrane(c, bx, by, br, base, seed=int(bx + by), bumpy=0.18)
    # fibrin strands
    for _ in range(10):
        a = rnd.random() * math.tau
        c.line(cx, cy, cx + math.cos(a) * 13, cy + math.sin(a) * 13, hx("#3a141c"), 0.6)
    # trapped platelet specks (mustard)
    for _ in range(8):
        a = rnd.random() * math.tau; rr = rnd.random() * 9
        c.disc(cx + math.cos(a) * rr, cy + math.sin(a) * rr, 1.1, hx("#b7892f"))
    outline(c, OUTLINE)
    return S, S, c.px


def rbc():
    """22x22 red blood cell — harmless biconcave drifting decor."""
    S = 22; c = C(S, S); cx = cy = S / 2 - 0.5
    body = hx("#c34b56")
    membrane(c, cx, cy, 9, body, seed=21)
    c.disc(cx, cy, 4.2, shade(body, 0.72))    # central pallor
    c.disc(cx - 0.5, cy - 0.5, 3.0, shade(body, 0.82))
    c.disc(cx - 2.5, cy - 2.5, 1.4, hx("#e89aa2"))  # shine
    outline(c, OUTLINE)
    return S, S, c.px


# ============================================================ FX =============
def spark():
    """9x9 bright 4-point nano-spark (teal-white)."""
    S = 9; c = C(S, S); cx = cy = S / 2
    c.line(cx, 0, cx, S - 1, TEAL_HI, 0.6)
    c.line(0, cy, S - 1, cy, TEAL_HI, 0.6)
    c.disc(cx, cy, 1.8, hx("#ffffff"))
    c.disc(cx, cy, 1.0, hx("#ffffff"))
    return S, S, c.px


def glow():
    """64x64 soft radial glow (teal), additive halo for cores & sites."""
    S = 64; c = C(S, S); cx = cy = S / 2 - 0.5
    for y in range(S):
        for x in range(S):
            d = math.hypot(x - cx, y - cy) / (S / 2)
            if d < 1.0:
                a = int(150 * (1 - d) ** 2.2)
                c.set(x, y, (TEAL[0], TEAL[1], TEAL[2], a))
    return S, S, c.px


# ============================================================ ICONS =========
def icon_integrity():
    """16x16 shield — patient integrity."""
    S = 16; c = C(S, S); cx = S / 2 - 0.5
    body, hi, dk = hx("#49c0ff"), hx("#9fe0ff"), hx("#2a6fa8")
    for y in range(2, 14):
        f = (y - 2) / 12.0
        if y < 9:
            half = 6.0
        else:
            half = 6.0 * (1 - (y - 9) / 5.0)
        for x in range(int(cx - half), int(cx + half) + 1):
            col = hi if (x - cx) < -half * 0.4 and y < 9 else (dk if (x - cx) > half * 0.3 else body)
            c.set(x, y, col)
    # cross
    c.rect(cx - 0.5, 5, 2, 6, hx("#ffffff"))
    c.rect(cx - 2, 7, 6, 2, hx("#ffffff"))
    outline(c, hx("#0c2030"))
    return S, S, c.px


def icon_repair():
    """16x16 wrench — repairs."""
    S = 16; c = C(S, S)
    steel, edge = hx("#cdd6df"), hx("#8a96a4")
    c.line(4, 12, 11, 5, steel, 1.6)
    c.line(4, 12, 11, 5, edge, 0.5)
    # head ring (open jaw)
    c.disc(12, 4, 3.0, steel)
    c.disc(12, 4, 1.5, (0, 0, 0, 0))
    c.rect(13, 1, 3, 3, (0, 0, 0, 0))
    # handle knob
    c.disc(4, 12, 2.0, steel)
    c.disc(4, 12, 1.0, edge)
    outline(c, hx("#1a2028"))
    return S, S, c.px


def icon_clock():
    """16x16 timer."""
    S = 16; c = C(S, S); cx = cy = S / 2 - 0.5
    c.disc(cx, cy, 6.5, hx("#e0c24a"))
    c.disc(cx, cy, 5.2, hx("#3a2f10"))
    c.disc(cx, cy, 4.4, hx("#f4dc82"))
    c.line(cx, cy, cx, cy - 3, hx("#3a2f10"), 0.7)
    c.line(cx, cy, cx + 2.4, cy, hx("#3a2f10"), 0.7)
    c.rect(cx - 1, 1, 2, 1.5, hx("#e0c24a"))  # top button
    outline(c, hx("#1a1408"))
    return S, S, c.px


# ============================================================ STARS =========
def _star(filled):
    S = 18; c = C(S, S); cx = cy = S / 2 - 0.5
    R, r = 8.4, 3.5
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rad = R if i % 2 == 0 else r
        pts.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad))

    def inside(px, py):
        n = len(pts); ins = False; j = n - 1
        for i in range(n):
            xi, yi = pts[i]; xj, yj = pts[j]
            if ((yi > py) != (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi):
                ins = not ins
            j = i
        return ins

    fill = hx("#ffd54a") if filled else hx("#2b3a45")
    hi = hx("#fff0a8") if filled else hx("#3b4d59")
    for y in range(S):
        for x in range(S):
            if inside(x + 0.5, y + 0.5):
                c.set(x, y, hi if (x - cx) + (y - cy) < -1 else fill)
    outline(c, hx("#15202a") if filled else hx("#22323c"))
    return S, S, c.px


def star_full():   return _star(True)
def star_empty():  return _star(False)


# ============================================================ UI FRAMES =====
def _frame(S, fill, border, edge, hi, bevel=2):
    """Generic beveled 9-slice frame: dark edge, colored border band,
    inner fill, single bright top highlight line."""
    c = C(S, S)
    c.rect(0, 0, S, S, fill)
    for x in range(S):
        c.set(x, 0, edge); c.set(x, S - 1, edge)
    for y in range(S):
        c.set(0, y, edge); c.set(S - 1, y, edge)
    for t in range(1, 1 + bevel):
        for x in range(t, S - t):
            c.set(x, t, border); c.set(x, S - 1 - t, border)
        for y in range(t, S - t):
            c.set(t, y, border); c.set(S - 1 - t, y, border)
    for x in range(1 + bevel, S - 1 - bevel):
        c.set(x, 1 + bevel, hi)
    for y in range(1 + bevel, S - 1 - bevel):
        c.set(1 + bevel, y, shade(hi, 0.8))
    return S, S, c.px


def frame_panel():   return _frame(24, hx("#1a0d12"), hx("#a83a4e"), hx("#0a0507"), hx("#d8627a"))
def frame_window():  return _frame(28, hx("#140a10"), hx("#d8b24a"), hx("#0a0608"), hx("#f4dc82"), bevel=3)


def frame_banner():
    S = 24; c = C(S, S)
    c.rect(0, 0, S, S, hx("#160a10"))
    for x in range(S):
        c.set(x, 0, OUTLINE); c.set(x, S - 1, OUTLINE)
    for y in range(S):
        c.set(0, y, OUTLINE); c.set(S - 1, y, OUTLINE)
    for x in range(1, S - 1):
        c.set(x, 1, hx("#d8b24a")); c.set(x, S - 2, hx("#a07c22"))
        c.set(x, 3, hx("#7a2330"))
    for y in range(1, S - 1):
        c.set(1, y, hx("#c79e36")); c.set(S - 2, y, hx("#8a6a1c"))
    return S, S, c.px


def button():
    # near-white so it tints cleanly via modulate_color; dark outline stays dark
    S = 22; c = C(S, S)
    c.rect(0, 0, S, S, (228, 236, 233, 255))
    for x in range(S):
        c.set(x, 1, (255, 255, 255, 255)); c.set(x, 2, (246, 250, 248, 255))
        c.set(x, S - 2, (146, 154, 156, 255)); c.set(x, S - 3, (184, 192, 190, 255))
    for y in range(S):
        c.set(1, y, (250, 252, 250, 255)); c.set(S - 2, y, (164, 172, 170, 255))
    edge = (14, 20, 26, 255)
    for x in range(S):
        c.set(x, 0, edge); c.set(x, S - 1, edge)
    for y in range(S):
        c.set(0, y, edge); c.set(S - 1, y, edge)
    return S, S, c.px


def bar_bg():
    """16x16 recessed meter track."""
    S = 16; c = C(S, S)
    c.rect(0, 0, S, S, hx("#0b0608"))
    for x in range(S):
        c.set(x, 0, hx("#05090d")); c.set(x, S - 1, hx("#2a1620"))
    for y in range(S):
        c.set(0, y, hx("#05090d")); c.set(S - 1, y, hx("#2a1620"))
    for x in range(2, S - 2):
        c.set(x, 1, hx("#1a2a32"))
    return S, S, c.px


def bar_fill():
    """near-white fill for meters (tinted via modulate)."""
    S = 12; c = C(S, S)
    c.rect(0, 0, S, S, (236, 244, 240, 255))
    for x in range(S):
        c.set(x, 0, (255, 255, 255, 255))
        c.set(x, S - 1, (170, 178, 182, 255))
    return S, S, c.px


# ============================================================ BACKGROUND ====
def make_bg():
    W, H = 1152, 648; c = C(W, H)
    top, bot = hx("#3a0e18"), hx("#120308")
    for y in range(H):
        f = y / H
        c.px[y * W:(y + 1) * W] = [mix(top, bot, f)] * W
    rnd = random.Random(20)
    # flowing plasma streaks (soft diagonal bands)
    for _ in range(26):
        y0 = rnd.randint(-40, H)
        x0 = rnd.randint(-60, W)
        L = rnd.randint(160, 420)
        ang = rnd.uniform(-0.35, 0.15)
        col = (210, 90, 110, 10)
        for i in range(L):
            x = x0 + i
            y = y0 + math.sin(i * 0.012) * 26 + i * ang
            c.disc(x, y, rnd.choice([3, 4, 5]), col)
    # soft out-of-focus blood cells (bokeh)
    for _ in range(30):
        x = rnd.randint(0, W); y = rnd.randint(0, H); r = rnd.randint(28, 74)
        base = (200, 70, 90)
        for ring_r in range(r, r - 4, -1):
            for a in range(0, 360, 5):
                ar = math.radians(a)
                c.set(x + math.cos(ar) * ring_r, y + math.sin(ar) * ring_r, (base[0], base[1], base[2], 14))
        c.disc(x, y, r - 5, (base[0], base[1], base[2], 7))
    # a couple of teal nano bokeh (cool accents)
    for _ in range(6):
        x = rnd.randint(0, W); y = rnd.randint(0, H); r = rnd.randint(26, 56)
        for ring_r in range(r, r - 3, -1):
            for a in range(0, 360, 6):
                ar = math.radians(a)
                c.set(x + math.cos(ar) * ring_r, y + math.sin(ar) * ring_r, (60, 200, 200, 12))
    # faint lab grid overlay
    for gx in range(0, W, 64):
        for y in range(H):
            c.set(gx, y, (255, 255, 255, 6))
    for gy in range(0, H, 64):
        for x in range(W):
            c.set(x, gy, (255, 255, 255, 6))
    # drifting platelet specks
    for _ in range(140):
        x = rnd.randint(0, W); y = rnd.randint(0, H)
        c.disc(x, y, rnd.choice([1, 1, 2]), (220, 150, 160, rnd.randint(12, 32)))
    # vessel-wall vignette (warm, heavy)
    for y in range(H):
        for x in range(W):
            dx = (x - W / 2) / (W / 2); dy = (y - H / 2) / (H / 2); d = dx * dx + dy * dy
            if d > 0.5:
                c.set(x, y, (20, 2, 8, int(min(175, (d - 0.5) * 230))))
    return W, H, c.px


# ============================================================ MAIN ==========
def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/generated/nanobot"
    os.makedirs(out, exist_ok=True)

    def w(name, tup):
        write_png(os.path.join(out, name + ".png"), *tup)

    # frames + ui
    w("frame_panel", frame_panel())
    w("frame_window", frame_window())
    w("frame_banner", frame_banner())
    w("button", button())
    w("bar_bg", bar_bg())
    w("bar_fill", bar_fill())
    # sprites
    w("nanobot", nanobot())
    w("breach", breach())
    w("healed", healed())
    w("pathogen", pathogen())
    w("microbe", microbe())
    w("clot", clot())
    w("rbc", rbc())
    w("spark", spark())
    w("glow", glow())
    # icons
    w("icon_integrity", icon_integrity())
    w("icon_repair", icon_repair())
    w("icon_clock", icon_clock())
    # stars
    w("star_full", star_full())
    w("star_empty", star_empty())
    # background
    w("bg", make_bg())

    print("Wrote nanobot quest assets to %s" % out)


if __name__ == "__main__":
    main()
