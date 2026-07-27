#!/usr/bin/env python3
"""Dependency-free pixel-art generator for the TITLE SCREEN + INTRO CUTSCENE.

Writes RGBA PNGs directly (no Pillow). Same dark-outline + bevel house style as
tools/make_ending.py / make_settings.py so the menu and intro match the rest of
the game. Theme: "CAREER REALMS - The Shifter's Path". A lone Shifter stands on a
hilltop beneath a great cosmic RIFT in the sky; a fantasy world glows below and
the five career realms (Engineering / Farming / Leadership / Medicine / Art) wait
to be reconnected.

Parallax panorama, drawn at 384x216 and shown 3x (1152x648) with NEAREST:
  * sky        - cosmic dusk gradient, green/orange nebula wisps, star field
  * hills      - hazy violet mountain silhouettes
  * clouds     - wide dusk-tinted strip that drifts
  * skyline    - a distant fantasy city of towers with warm lit windows
  * foreground - the hero's hilltop: path to the rift, 5 domain pennants, lamp
Animated props (placed + tweened/rotated in engine):
  * vortex     - the rift: a glowing five-armed spiral galaxy (rotates)
  * rays       - additive god-ray fan from the rift (counter-rotates)
  * hero       - the Shifter, back to camera, staff with a glowing orb
  * emblem_<d> - the five round domain medallions (x5)
  * crack      - jagged lightning fracture for the intro's "Fracture" beat
UI (pixel art):
  * title_banner - ornate ribbon plate the CAREER REALMS logo sits on
  * btn / btn_hi - menu button 9-slice (dark plate + green corner brackets;
                   hi = brighter gold-rimmed selected state).  margin=10
  * panel        - info/credits 9-slice window.                  margin=16
  * caption      - intro lower-third caption bar 9-slice.        margin=12
  * vignette     - edge darkening overlay
  * sparkle / bird / star_full - small accents/particles
  * _preview     - composite, for eyeballing only (not used by the game)

Run:  python3 tools/make_title.py assets/generated/title
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

    def add(self, x, y, c):
        """Additive plot (for glows) — accumulates light, clamped."""
        x = int(x); y = int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            bg = self.px[y * self.w + x]
            a = c[3] / 255.0
            self.px[y * self.w + x] = (
                min(255, int(bg[0] + c[0] * a)), min(255, int(bg[1] + c[1] * a)),
                min(255, int(bg[2] + c[2] * a)), min(255, bg[3] + c[3]))

    def get(self, x, y):
        return self.px[y * self.w + x]

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

    def tri(self, p0, p1, p2, c):
        xs = [p0[0], p1[0], p2[0]]; ys = [p0[1], p1[1], p2[1]]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            for x in range(int(min(xs)), int(max(xs)) + 1):
                if _in_tri(x + 0.5, y + 0.5, p0, p1, p2):
                    self.set(x, y, c)

    def blit(self, src, ox, oy):
        for y in range(src.h):
            for x in range(src.w):
                p = src.px[y * src.w + x]
                if p[3] != 0:
                    self.set(ox + x, oy + y, p)


def _in_tri(px, py, a, b, c):
    d1 = (px - b[0]) * (a[1] - b[1]) - (a[0] - b[0]) * (py - b[1])
    d2 = (px - c[0]) * (b[1] - c[1]) - (b[0] - c[0]) * (py - c[1])
    d3 = (px - a[0]) * (c[1] - a[1]) - (c[0] - a[0]) * (py - a[1])
    neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
    pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
    return not (neg and pos)


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


def grad(stops, f):
    """Sample a multi-stop gradient. stops = [(pos, color), ...] sorted by pos."""
    f = max(0.0, min(1.0, f))
    for i in range(len(stops) - 1):
        p0, c0 = stops[i]; p1, c1 = stops[i + 1]
        if p0 <= f <= p1:
            t = 0.0 if p1 == p0 else (f - p0) / (p1 - p0)
            return mix(c0, c1, t)
    return stops[-1][1]


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


OUTLINE = hx("#171029")          # deep cosmic outline (purpler than the ending)
PW, PH = 384, 216                # panorama art resolution (shown 3x -> 1152x648)
HORIZON = 150                    # lower horizon -> more sky for the rift

# domain accent colours (shared with StarManager / the ending)
DOMAIN_COL = {
    "Engineering": hx("#f4c12e"),  # gold
    "Farming":     hx("#5fc85a"),  # green
    "Leadership":  hx("#3f8cf0"),  # blue
    "Medicine":    hx("#a25bf0"),  # purple
    "Art":         hx("#e8554e"),  # red
}
DOMAIN_ORDER = ["Engineering", "Farming", "Leadership", "Medicine", "Art"]


# ================================================================== SKY ======
SKY_STOPS = [
    (0.00, hx("#160f30")),   # deep indigo zenith
    (0.34, hx("#2a1c4e")),   # violet
    (0.55, hx("#4a2a63")),   # plum
    (0.74, hx("#7d3c6a")),   # mauve
    (0.88, hx("#b85a5e")),   # rose
    (1.00, hx("#ec9b62")),   # warm gold horizon
]


def make_sky():
    c = C(PW, PH)
    for y in range(PH):
        col = grad(SKY_STOPS, min(1.0, y / float(HORIZON + 24)))
        for x in range(PW):
            c.px[y * PW + x] = col

    # nebula wisps in the cosmic green / orange of the old title art (subtle)
    rnd = random.Random(11)
    for (col, n) in [(hx("#3fae72"), 5), (hx("#e08a3a"), 4), (hx("#6a52c0"), 5)]:
        for _ in range(n):
            cx = rnd.randint(0, PW); cy = rnd.randint(0, int(HORIZON * 0.8))
            rx = rnd.randint(26, 70); ry = rnd.randint(10, 26)
            ang = rnd.uniform(-0.6, 0.6)
            for yy in range(-ry, ry):
                for xx in range(-rx, rx):
                    # rotated soft ellipse, very low alpha -> a faint glow band
                    rxr = xx * math.cos(ang) - yy * math.sin(ang)
                    ryr = xx * math.sin(ang) + yy * math.cos(ang)
                    d = (rxr / rx) ** 2 + (ryr / ry) ** 2
                    if d <= 1.0:
                        a = int(30 * (1 - d) ** 2)
                        if a > 0:
                            c.set(cx + xx, cy + yy, (col[0], col[1], col[2], a))

    # star field in the upper indigo band
    rnd = random.Random(7)
    for _ in range(150):
        x = rnd.randint(0, PW - 1); y = rnd.randint(0, int(HORIZON * 0.78))
        if rnd.random() < (1 - y / (HORIZON * 0.85)):
            b = rnd.choice([180, 215, 245, 255])
            c.set(x, y, (b, b, 255, rnd.randint(120, 235)))
            if rnd.random() < 0.12:                       # a few brighter 4px stars
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    c.set(x + dx, y + dy, (b, b, 255, 90))
    return PW, PH, c.px


# =============================================================== HILLS =========
def _ridge(c, base_y, amp, period, phase, col, seed):
    rnd = random.Random(seed)
    jit = [rnd.uniform(-2, 2) for _ in range(8)]
    for x in range(PW):
        h = base_y - (math.sin(x / period + phase) * amp
                      + math.sin(x / (period * 0.43) + phase * 2) * amp * 0.4
                      + jit[(x // 48) % 8])
        for y in range(int(h), PH):
            c.set(x, y, col)


def make_hills():
    c = C(PW, PH)
    _ridge(c, HORIZON + 6, 18, 74, 1.7, hx("#3a2c63"), 3)    # far range
    _ridge(c, HORIZON + 12, 13, 54, 4.2, hx("#322556"), 8)   # mid range
    _ridge(c, HORIZON + 18, 10, 40, 0.6, hx("#2a1f49"), 5)   # near range
    # atmospheric haze near the horizon line
    for y in range(HORIZON - 6, HORIZON + 22):
        a = max(0, 70 - (y - (HORIZON - 6)) * 3)
        for x in range(PW):
            if c.get(x, y)[3] != 0:
                c.set(x, y, (210, 130, 150, a))
    return PW, PH, c.px


# ============================================================== CLOUDS ========
def make_clouds():
    W, H = 512, 110
    c = C(W, H)
    rnd = random.Random(13)
    base = hx("#5a3f6e"); hi = hx("#9a6e8a"); lo = hx("#3a2750")
    for _ in range(10):
        cx = rnd.randint(20, W - 20); cy = rnd.randint(24, H - 24)
        scale = rnd.uniform(0.7, 1.5)
        puffs = [(0, 0, 16), (-13, 4, 11), (13, 3, 12), (-24, 7, 8), (24, 6, 8), (6, -6, 10), (-7, -4, 9)]
        for (dx, dy, r) in puffs:
            c.ellipse(cx + dx * scale, cy + dy * scale, r * scale, r * 0.6 * scale, base)
        for (dx, dy, r) in puffs:                # underside shadow
            c.ellipse(cx + dx * scale, cy + dy * scale + r * 0.42 * scale, r * scale, r * 0.30 * scale, lo)
        for (dx, dy, r) in puffs:                # rim light (rift glow from above)
            c.ellipse(cx + dx * scale, cy + dy * scale - r * 0.40 * scale, r * 0.78 * scale, r * 0.32 * scale, hi)
    return W, H, c.px


# ============================================================= SKYLINE ========
def _tower(c, x, y, w, h, wall, roof, seed=0):
    """Tall beveled tower with terracotta-ish cap + warm lit windows."""
    c.rect(x, y, w, h, wall)
    for i in range(h):                                   # vertical light->dark bevel
        f = 1.14 - 0.36 * (i / max(1, h))
        c.rect(x, y + i, 1, 1, shade(wall, min(1.25, f + 0.08)))
        c.rect(x + w - 1, y + i, 1, 1, shade(wall, f - 0.14))
    # cap roof
    rh = max(5, w // 2)
    c.tri((x - 1, y), (x + w + 1, y), (x + w / 2, y - rh), roof)
    c.line(x - 1, y, x + w + 1, y, shade(roof, 0.7), 0.6)
    # lit windows grid
    rnd = random.Random(seed + 1)
    for wy in range(y + 4, y + h - 3, 6):
        for wx in range(x + 2, x + w - 2, 5):
            if rnd.random() < 0.72:
                c.rect(wx, wy, 2, 3, hx("#ffd070"))
                c.set(wx, wy, hx("#fff0c0"))
            else:
                c.rect(wx, wy, 2, 3, hx("#2a1c30"))


def make_skyline():
    c = C(PW, PH)
    # the city sits on a dim ridge
    ridge = hx("#241a40")
    for x in range(PW):
        top = HORIZON + 4 + int(math.sin(x / 50.0 + 1) * 2)
        for y in range(top, HORIZON + 30):
            c.set(x, y, mix(ridge, hx("#181030"), (y - top) / 28.0))

    # cluster of towers, tallest near the centre (under the rift)
    rnd = random.Random(21)
    walls = [hx("#3a2c5e"), hx("#43326a"), hx("#4d3a72"), hx("#352a56")]
    roofs = [hx("#7d3c6a"), hx("#8a4660"), hx("#6a3360")]
    cx = PW // 2
    towers = []
    for x in range(8, PW - 8, 13):
        d = abs(x - cx) / float(cx)
        h = int(26 + (1 - d) * 30 + rnd.uniform(-6, 6))     # taller in the middle
        w = rnd.choice([8, 9, 10, 11])
        towers.append((x, HORIZON + 6 - h, w, h, rnd.choice(walls), rnd.choice(roofs), x))
    towers.sort(key=lambda t: t[3])                          # short first (drawn behind)
    for (x, y, w, h, wc, rc, s) in towers:
        _tower(c, x, y, w, h, wc, rc, seed=s)

    # a central cathedral, the tallest of the cluster — kept low enough to read
    # as part of the skyline (the steep parallax stretch means a taller spire
    # would poke up into the menu), capped by a small MUTED finial rather than a
    # bright pennant so it never competes with the title's domain emblems
    sx = cx - 5
    top = HORIZON - 38
    bh = HORIZON + 6 - top
    c.rect(sx, top, 10, bh, hx("#43326a"))
    for i in range(bh):
        f = 1.16 - 0.4 * (i / float(bh))
        c.set(sx, top + i, shade(hx("#43326a"), min(1.25, f + 0.08)))
        c.set(sx + 9, top + i, shade(hx("#43326a"), f - 0.16))
    c.tri((sx - 2, top), (sx + 12, top), (cx, top - 14), hx("#6a3360"))
    for wy in range(top + 6, HORIZON - 2, 7):              # tall lit windows
        c.rect(cx - 1, wy, 2, 3, hx("#ffd98a"))
    c.line(cx, top - 14, cx, top - 19, hx("#5a3360"), 1.0)  # short muted finial
    c.disc(cx, top - 20, 1.5, hx("#7a3f5e"))

    outline(c, OUTLINE)
    return PW, PH, c.px


# =========================================================== FOREGROUND =======
def make_foreground():
    c = C(PW, PH)
    grass = hx("#2f5340"); gdk = hx("#1d3a2c"); glt = hx("#3f6b4e")
    # rolling foreground hill, dips at the centre for the path up to the rift
    def crest(x):
        return HORIZON + 26 + int(-12 * math.cos((x / PW) * math.pi * 2) + math.sin(x / 38.0) * 3)
    for x in range(PW):
        top = crest(x)
        for y in range(top, PH):
            f = (y - top) / float(PH - top + 1)
            c.set(x, y, mix(glt, gdk, min(1.0, f * 1.3)))
        c.set(x, top, glt)
        c.set(x, top + 1, shade(glt, 1.12))

    # glowing path winding up toward the rift (cool moonlit stones)
    for y in range(crest(PW // 2), PH):
        f = (y - crest(PW // 2)) / float(PH - crest(PW // 2))
        cxp = PW / 2 + math.sin(f * 2.2) * 8
        wdt = 4 + f * 22
        for x in range(int(cxp - wdt), int(cxp + wdt)):
            if ((x * 3 + y * 5) % 23) < 11:
                c.set(x, y, hx("#6a6f9a"))
            else:
                c.set(x, y, hx("#54587e"))
        c.set(int(cxp - wdt), y, hx("#3e4060"))
        c.set(int(cxp + wdt) - 1, y, hx("#3e4060"))

    # five domain pennant poles planted along the ridge (the realms)
    spots = [44, 104, PW - 150, PW - 96, PW - 40]
    for i, px in enumerate(spots):
        dom = DOMAIN_ORDER[i]; col = DOMAIN_COL[dom]
        py = crest(px)
        c.rect(px, py - 30, 2, 30, hx("#2a2236"))               # pole
        c.set(px, py - 30, hx("#3a3048"))
        c.disc(px + 1, py - 31, 1.6, col)                        # finial
        # triangular pennant
        for k in range(11):
            ww = 12 - k
            for yy in range(2):
                c.set(px + 2 + k, py - 29 + yy + k * 0.0, shade(col, 1.05 - k * 0.02))
        c.tri((px + 2, py - 29), (px + 2, py - 21), (px + 14, py - 25), col)
        c.tri((px + 2, py - 29), (px + 14, py - 25), (px + 13, py - 25.5), shade(col, 1.3))

    # left lamp post with a warm flame
    lx = 30; ly = crest(lx)
    c.rect(lx, ly - 28, 2, 28, hx("#241f30"))
    c.rect(lx - 2, ly - 32, 6, 5, hx("#322b40"))
    c.disc(lx + 1, ly - 30, 2.4, hx("#ffd98a"))
    c.disc(lx + 1, ly - 30, 1.2, hx("#fff4d2"))

    # grass tufts + domain flowers on the slopes
    rnd = random.Random(33)
    petals = list(DOMAIN_COL.values())
    for _ in range(80):
        x = rnd.randint(0, PW - 1); y = crest(x) + rnd.randint(1, 6)
        c.line(x, y, x + rnd.choice([-1, 1]), y - 3, shade(grass, 1.2), 0.5)
    for _ in range(60):
        x = rnd.randint(6, PW - 6); y = rnd.randint(0, PH - 4)
        if y < crest(x) + 3:
            continue
        if abs(x - PW / 2) < 18 + (y - HORIZON) * 0.4:          # keep the path clear
            continue
        col = rnd.choice(petals)
        c.set(x, y, col)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            c.set(x + dx, y + dy, shade(col, 0.78))
        c.set(x, y, hx("#fff3b0"))
        c.set(x, y + 2, hx("#21402c"))

    outline(c, OUTLINE)
    return PW, PH, c.px


# ============================================================== VORTEX ========
def _soft_add(c, x, y, col, a, r=1.4):
    """Additive soft brush (round falloff) — gives the rift a glowing dusty look."""
    for dy in range(int(-r) - 1, int(r) + 2):
        for dx in range(int(-r) - 1, int(r) + 2):
            d = math.hypot(dx, dy)
            if d <= r:
                aa = int(a * (1 - d / (r + 0.4)))
                if aa > 0:
                    c.add(x + dx, y + dy, (col[0], col[1], col[2], aa))


def make_vortex():
    """The rift: a dense, glowing five-armed spiral galaxy on transparent bg.
    Shown additively in-engine and slowly rotated."""
    S = 230
    c = C(S, S); cx = cy = (S - 1) / 2.0
    arms = 5
    cols = [DOMAIN_COL[d] for d in DOMAIN_ORDER]
    R = S / 2.0 - 3
    # soft inner nebula haze first (so arms read on top of it)
    for y in range(S):
        for x in range(S):
            d = math.hypot(x - cx, y - cy)
            if d < R * 0.72:
                a = int(60 * (1 - d / (R * 0.72)) ** 2)
                if a > 0:
                    c.add(x, y, (120, 96, 200, a))
    # logarithmic spiral arms, each tinted a domain colour + a white leading edge
    steps = 5200
    for k in range(arms):
        base = k * (2 * math.pi / arms)
        col = cols[k]
        for i in range(steps):
            t = i / float(steps)
            r = 4 + t * R
            ang = base + t * 9.0                              # tighter winding
            x = cx + math.cos(ang) * r
            y = cy + math.sin(ang) * r
            a = int(150 * (1 - t) ** 1.15)
            if a <= 0:
                continue
            br = 1.0 + t * 1.8                                # arms widen outward
            _soft_add(c, x, y, col, a, br)
            # bright leading edge just inside the arm
            lx = cx + math.cos(ang - 0.16) * r
            ly = cy + math.sin(ang - 0.16) * r
            _soft_add(c, lx, ly, (235, 225, 255), int(a * 0.5), br * 0.7)
    # two faint orbital rings for structure
    c.ring(cx, cy, R * 0.52, 1.4, (210, 190, 255, 60))
    c.ring(cx, cy, R * 0.82, 1.1, (190, 160, 240, 40))
    # bright swirling core
    c.disc(cx, cy, 20, (170, 140, 235, 150))
    c.disc(cx, cy, 14, (210, 190, 255, 200))
    c.disc(cx, cy, 9, (240, 230, 255, 240))
    c.disc(cx, cy, 5, (255, 255, 255, 255))
    return S, S, c.px


# ============================================================ GOD RAYS =========
def make_rays():
    S = 256; c = C(S, S); cx = cy = S / 2
    n = 14
    for k in range(n):
        a0 = k / n * math.tau
        for rr in range(0, S // 2):
            spread = 0.05 + rr / S * 0.10
            da = -spread
            while da <= spread:
                a = a0 + da
                x = cx + math.cos(a) * rr; y = cy + math.sin(a) * rr
                edge = 1 - abs(da) / max(0.001, spread)
                al = int(40 * edge * (1 - rr / (S / 2)))
                if al > 0:
                    c.set(x, y, (220, 200, 255, al))
                da += 0.012
    return S, S, c.px


# ================================================================ HERO =========
def make_hero():
    """The Shifter, back to camera, holding a staff topped with a glowing orb."""
    W, H = 34, 52
    c = C(W, H); cx = W / 2
    skin = hx("#e8b186"); cloak = hx("#3b4f9e"); cl_d = shade(cloak, 0.66); cl_l = shade(cloak, 1.24)
    hair = hx("#2a2030"); boot = hx("#3a2a22")
    # cloak body with flared hem
    c.rect(cx - 6, 20, 12, 20, cloak)
    c.tri((cx - 6, 20), (cx - 10, 41), (cx - 6, 41), cl_d)
    c.tri((cx + 6, 20), (cx + 10, 41), (cx + 6, 41), cl_l)
    for i in range(20):
        c.set(cx - 6, 20 + i, cl_l)
        c.set(cx + 5, 20 + i, cl_d)
    c.rect(cx - 6, 33, 12, 2, hx("#caa23a"))                 # gold belt
    # hood
    c.disc(cx, 14, 6, cloak)
    c.tri((cx - 6, 14), (cx + 6, 14), (cx, 5), cloak)
    c.disc(cx, 15, 4, hair)
    # legs / boots
    c.rect(cx - 4, 40, 3, 8, hx("#28386a")); c.rect(cx + 1, 40, 3, 8, hx("#28386a"))
    c.rect(cx - 4, 47, 4, 3, boot); c.rect(cx, 47, 4, 3, boot)
    # staff in the right hand, glowing orb on top
    sx = cx + 8
    c.line(sx, 8, sx, 44, hx("#5a3f28"), 1.0)
    c.disc(sx, 7, 4, (180, 150, 240, 120))
    c.disc(sx, 7, 2.6, hx("#cfe0ff"))
    c.set(sx, 7, hx("#ffffff"))
    # near hand on the staff
    c.disc(cx + 6, 26, 1.8, skin)
    outline(c, OUTLINE)
    return W, H, c.px


# ============================================================= EMBLEMS =========
def _coin(col):
    S = 44; c = C(S, S); cx = cy = S / 2 - 0.5
    c.disc(cx, cy, 20, shade(col, 0.42))                     # dark rim
    c.disc(cx, cy, 18, col)
    c.disc(cx - 4, cy - 4, 12, shade(col, 1.2))             # sheen
    c.ring(cx, cy, 18, 1.4, shade(col, 1.45))
    c.disc(cx - 6, cy - 6, 3, shade(col, 1.55))
    return c, cx, cy


def _gear(c, cx, cy, r, col):
    teeth = 8
    for k in range(teeth):
        a = k / teeth * math.tau
        c.rect(cx + math.cos(a) * r - 1.5, cy + math.sin(a) * r - 1.5, 3, 3, col)
    c.disc(cx, cy, r - 1, col)
    c.disc(cx, cy, r * 0.4, shade(col, 0.5))


def emblem_engineering():
    col = DOMAIN_COL["Engineering"]; c, cx, cy = _coin(col)
    _gear(c, cx, cy, 8, hx("#fdf3cf"))
    c.disc(cx, cy, 3, hx("#3a2a08"))
    outline(c, OUTLINE)
    return c.w, c.h, c.px


def emblem_farming():
    col = DOMAIN_COL["Farming"]; c, cx, cy = _coin(col)
    grain = hx("#f6e7a0"); stem = hx("#2c5a26")
    c.line(cx, cy + 9, cx, cy - 9, stem, 1.2)
    for s in (-1, 1):
        for k in range(4):
            yy = cy - 8 + k * 5
            c.line(cx, yy, cx + s * 5, yy - 3, grain, 1.4)
            c.disc(cx + s * 5, yy - 3, 1.4, shade(grain, 1.15))
    c.disc(cx, cy - 9, 1.6, grain)
    outline(c, OUTLINE)
    return c.w, c.h, c.px


def emblem_leadership():
    col = DOMAIN_COL["Leadership"]; c, cx, cy = _coin(col)
    gold = hx("#ffe08a"); ink = hx("#243a66")
    base = cy + 6
    c.rect(cx - 9, base, 18, 4, gold)
    pts = [cx - 9, cx - 4.5, cx, cx + 4.5, cx + 9]
    for i, px in enumerate(pts):
        ph = 11 if i % 2 == 0 else 7
        c.tri((px - 2.4, base), (px + 2.4, base), (px, base - ph), gold)
        c.disc(px, base - ph, 1.5, hx("#fff6cf"))
    c.rect(cx - 9, base + 1, 18, 1, ink)
    for gx in (cx - 5, cx, cx + 5):
        c.disc(gx, base + 2, 1.2, hx("#e8554e"))
    outline(c, OUTLINE)
    return c.w, c.h, c.px


def emblem_medicine():
    col = DOMAIN_COL["Medicine"]; c, cx, cy = _coin(col)
    glass = hx("#dff0ff"); fluid = hx("#54e0b0"); cork = hx("#caa15a")
    c.tri((cx - 7, cy + 9), (cx + 7, cy + 9), (cx, cy - 2), glass)
    c.rect(cx - 2, cy - 9, 4, 7, glass)
    c.rect(cx - 3, cy - 11, 6, 2, cork)
    c.tri((cx - 4.5, cy + 8), (cx + 4.5, cy + 8), (cx, cy + 2), fluid)
    c.disc(cx, cy + 6, 1.2, hx("#d6fff0"))
    c.rect(cx - 1, cy + 2, 2, 6, hx("#ffffff")); c.rect(cx - 3, cy + 4, 6, 2, hx("#ffffff"))
    outline(c, OUTLINE)
    return c.w, c.h, c.px


def emblem_art():
    col = DOMAIN_COL["Art"]; c, cx, cy = _coin(col)
    wood = hx("#e8d2a6")
    c.ellipse(cx - 1, cy + 1, 11, 9, wood)
    for yy in range(int(cy + 1), int(cy + 7)):
        for xx in range(int(cx + 1), int(cx + 8)):
            if ((xx - (cx + 4)) / 3.2) ** 2 + ((yy - (cy + 4)) / 2.4) ** 2 <= 1:
                c.px[yy * c.w + xx] = shade(col, 0.7)
    blobs = [(-6, -3, hx("#e8554e")), (-2, -5, hx("#f4c12e")), (3, -4, hx("#3f8cf0")),
             (5, 0, hx("#5fc85a")), (-5, 2, hx("#a25bf0"))]
    for (dx, dy, bc) in blobs:
        c.disc(cx + dx, cy + dy, 2, bc); c.set(cx + dx - 1, cy + dy - 1, shade(bc, 1.4))
    c.line(cx - 9, cy + 9, cx + 6, cy - 8, hx("#9c6a3a"), 1.2)
    c.disc(cx + 6, cy - 8, 1.8, hx("#e8554e"))
    outline(c, OUTLINE)
    return c.w, c.h, c.px


# ============================================================== STARS ==========
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

    fill = hx("#ffd54a") if filled else hx("#33304a")
    hi = hx("#fff0a8") if filled else hx("#454060")
    for y in range(S):
        for x in range(S):
            if inside(x + 0.5, y + 0.5):
                c.set(x, y, hi if (x - cx) + (y - cy) < -1 else fill)
    outline(c, hx("#1c1630") if filled else hx("#241f38"))
    return S, S, c.px


def star_full():   return _star(True)
def star_empty():  return _star(False)


# ============================================================= SPARKLE =========
def make_sparkle():
    S = 14; c = C(S, S); cx = cy = S / 2 - 0.5
    core = hx("#fff7d4"); mid = hx("#ffe08a")
    c.disc(cx, cy, 4, (255, 210, 120, 70))
    for (dx, dy) in [(0, -6), (0, 6), (-6, 0), (6, 0)]:
        c.line(cx, cy, cx + dx, cy + dy, mid, 1.0)
    for (dx, dy) in [(-3, -3), (3, -3), (-3, 3), (3, 3)]:
        c.line(cx, cy, cx + dx, cy + dy, mid, 0.4)
    c.disc(cx, cy, 2, core)
    c.set(cx, cy, hx("#ffffff"))
    return S, S, c.px


# ================================================================ BIRD =========
def make_bird():
    W, H = 16, 9; c = C(W, H); col = hx("#1f1830")
    c.line(1, 5, 7, 1, col, 1.0)
    c.line(7, 1, 9, 3, col, 1.0)
    c.line(9, 3, 15, 0, col, 1.0)
    c.set(7, 2, shade(col, 2.2))
    return W, H, c.px


# =============================================================== CRACK =========
def make_crack():
    """Jagged lightning fracture for the intro 'Fracture' beat (transparent,
    shown additively).  A main bolt from the top with a few branches."""
    W, H = 200, 360
    c = C(W, H)
    glow = (150, 120, 230, 60); core = hx("#eaf0ff"); hot = hx("#ffffff")
    rnd = random.Random(5)

    def bolt(x0, y0, x1, y1, segs, jitter, t_core):
        pts = [(x0, y0)]
        for s in range(1, segs):
            f = s / float(segs)
            x = x0 + (x1 - x0) * f + rnd.uniform(-jitter, jitter)
            y = y0 + (y1 - y0) * f + rnd.uniform(-jitter * 0.4, jitter * 0.4)
            pts.append((x, y))
        pts.append((x1, y1))
        for i in range(len(pts) - 1):
            ax, ay = pts[i]; bx, by = pts[i + 1]
            c.line(ax, ay, bx, by, glow, 3.4)
            c.line(ax, ay, bx, by, core, 1.4)
            c.line(ax, ay, bx, by, hot, t_core)
        return pts

    main = bolt(W / 2, 0, W / 2 + rnd.uniform(-18, 18), H - 6, 16, 16, 0.7)
    for i in range(2, len(main) - 2, 3):                    # branches
        bx, by = main[i]
        bolt(bx, by, bx + rnd.uniform(-60, 60), by + rnd.uniform(40, 90), 6, 12, 0.4)
    return W, H, c.px


# =========================================================== UI: BANNER ========
def make_title_banner():
    """Wide ornate nameplate for the title lockup / menu headers.

    A tall, generous OPEN DARK CENTRE so the engine can place a title — and, on
    the main menu, a second subtitle line — fully inside it with clear margins.
    Framed by double gold rails, scrollwork ribbon ends and corner studs.  The
    inner-panel rect (used by titlescreen.gd to lay out the text) is
    (INSET+5, 14) .. (W-INSET-5, H-14); keep these in sync with BANNER_INNER.
    No loose gem row — the five realms read from the emblem coins instead."""
    W, H = 392, 96; c = C(W, H); cy = (H - 1) / 2.0
    body = hx("#241845"); panel = hx("#2e2150"); panel_lo = hx("#1b1236")
    band = hx("#e7c24a"); band_hi = hx("#fbe79a"); band_d = hx("#9c7820")
    inset = 36
    # ---- forked scrollwork ribbon tails on both ends ----
    for side, ex in ((-1, 20), (1, W - 20)):
        c.tri((ex, 14), (ex, H - 14), (ex - side * 30, cy), shade(body, 0.78))
        c.tri((ex, 20), (ex, H - 20), (ex - side * 17, cy), body)
        c.line(ex, 16, ex - side * 27, cy, band, 1.1)
        c.line(ex, H - 16, ex - side * 27, cy, band_d, 1.1)
        c.disc(ex - side * 5, cy, 4.4, shade(body, 0.7))     # end curl
        c.disc(ex - side * 5, cy, 2.5, band)
        c.set(ex - side * 6, cy - 1, band_hi)
    # ---- main plate ----
    c.rect(inset, 9, W - 2 * inset, H - 18, body)
    c.rect(inset + 5, 14, W - 2 * inset - 10, H - 28, panel)
    # soft vertical sheen across the inner panel
    for x in range(inset + 5, W - inset - 5):
        f = math.sin((x - inset - 5) / float(W - 2 * inset - 10) * math.pi)
        col = mix(panel, hx("#3a2c66"), 0.5 * f)
        for y in range(14, H - 14):
            c.set(x, y, col)
        c.set(x, 14, mix(col, panel_lo, 0.4)); c.set(x, H - 15, panel_lo)
    # ---- gold rails top & bottom (double rule for a richer frame) ----
    for x in range(inset, W - inset):
        c.set(x, 8, band_hi); c.set(x, 9, band); c.set(x, 10, band_d)
        c.set(x, H - 11, band_d); c.set(x, H - 10, band); c.set(x, H - 9, band_d)
    # ---- corner studs ----
    for (sx, sy) in [(inset + 4, 13), (W - inset - 4, 13), (inset + 4, H - 14), (W - inset - 4, H - 14)]:
        c.disc(sx, sy, 2.8, band_d); c.disc(sx, sy, 1.7, band); c.set(sx - 1, sy - 1, band_hi)
    outline(c, OUTLINE)
    return W, H, c.px


# =========================================================== UI: BUTTON ========
def _button(selected):
    """Menu button 9-slice (margin=14). A bevelled cosmic plate with a gold/green
    framed border, layered corner brackets, rivets and an engraved tab at each
    end; the selected frame warms to gold with an inner glow + brighter studs."""
    S, M = 44, 14; c = C(S, S)
    if selected:
        mid = hx("#4b3970"); hi = hx("#6f54a0"); lo = hx("#2e2150")
        brk = DOMAIN_COL["Engineering"]; rail = hx("#e7c24a"); glow = (255, 224, 150)
    else:
        mid = hx("#352a55"); hi = hx("#473a6c"); lo = hx("#211a3c")
        brk = DOMAIN_COL["Farming"]; rail = hx("#4a7d52"); glow = None
    brk_hi = shade(brk, 1.5); brk_lo = shade(brk, 0.55)
    c.rect(0, 0, S, S, mid)
    # bevelled top & bottom margin bands (these slices don't stretch vertically)
    for i in range(M):
        f = i / float(M)
        for x in range(S):
            c.set(x, i, mix(hi, mid, min(1.0, f * 1.3)))
            c.set(x, S - 1 - i, mix(lo, mid, min(1.0, f * 1.3)))
    # side bevels
    for y in range(S):
        c.set(1, y, shade(c.get(1, y), 1.18)); c.set(2, y, shade(c.get(2, y), 1.08))
        c.set(S - 2, y, shade(c.get(S - 2, y), 0.78)); c.set(S - 3, y, shade(c.get(S - 3, y), 0.9))
    # thin gold/green inner rail just inside the frame (reads as a metal trim)
    for x in range(5, S - 5):
        c.set(x, 4, rail); c.set(x, S - 5, shade(rail, 0.7))
    for y in range(5, S - 5):
        c.set(4, y, shade(rail, 0.86)); c.set(S - 5, y, shade(rail, 0.6))
    if selected:                                            # warm inner glow when picked
        for x in range(6, S - 6):
            c.set(x, 6, (glow[0], glow[1], glow[2], 64)); c.set(x, S - 7, (glow[0], glow[1], glow[2], 40))
        for y in range(7, S - 7):
            c.set(6, y, (glow[0], glow[1], glow[2], 46)); c.set(S - 7, y, (glow[0], glow[1], glow[2], 30))
    # dark outline frame
    for x in range(S):
        c.set(x, 0, OUTLINE); c.set(x, S - 1, OUTLINE)
    for y in range(S):
        c.set(0, y, OUTLINE); c.set(S - 1, y, OUTLINE)
    # layered L corner brackets + a rivet stud just inside each corner
    L = 10
    for (ox, oy, sx, sy) in [(2, 2, 1, 1), (S - 3, 2, -1, 1), (2, S - 3, 1, -1), (S - 3, S - 3, -1, -1)]:
        for k in range(L):
            c.set(ox + sx * k, oy, brk); c.set(ox, oy + sy * k, brk)
            c.set(ox + sx * k, oy + sy, brk_lo); c.set(ox + sx, oy + sy * k, brk_lo)
        c.set(ox, oy, brk_hi)
        c.disc(ox + sx * 5, oy + sy * 5, 1.6, shade(mid, 0.5))
        c.set(ox + sx * 5, oy + sy * 5, brk_hi)
    return S, S, c.px


def btn():     return _button(False)
def btn_hi():  return _button(True)


# =========================================================== UI: PANEL =========
def make_panel():
    """Info / credits window 9-slice. Dark navy-violet, gold inner rule, rivets.
    margin=16."""
    S = 56; c = C(S, S)
    navy = hx("#1c1438"); navy_hi = hx("#2a1f4e"); navy_lo = hx("#140e2a")
    band = hx("#5a3f86"); band_hi = hx("#7a5aae"); band_lo = hx("#3e2a60")
    gold = hx("#e0bf52"); gold_lo = hx("#9c7c28"); gold_hi = hx("#f6e29a")
    c.rect(0, 0, S, S, navy)
    for x in range(S):
        c.set(x, 0, OUTLINE); c.set(x, S - 1, OUTLINE)
    for y in range(S):
        c.set(0, y, OUTLINE); c.set(S - 1, y, OUTLINE)
    for x in range(1, S - 1):
        c.set(x, 1, band_hi); c.set(x, 2, band)
        c.set(x, S - 2, band_lo); c.set(x, S - 3, band)
    for y in range(1, S - 1):
        c.set(1, y, band); c.set(2, y, band)
        c.set(S - 2, y, band_lo); c.set(S - 3, y, band)
    for x in range(4, S - 4):
        c.set(x, 4, gold); c.set(x, S - 5, gold_lo)
    for y in range(4, S - 4):
        c.set(4, y, shade(gold, 0.92)); c.set(S - 5, y, gold_lo)
    for x in range(5, S - 5):
        c.set(x, 5, navy_hi); c.set(x, S - 6, navy_lo)
    for y in range(5, S - 5):
        c.set(5, y, shade(navy_hi, 0.92)); c.set(S - 6, y, navy_lo)
    for (rx, ry) in [(8, 8), (S - 9, 8), (8, S - 9), (S - 9, S - 9)]:
        c.disc(rx, ry, 2.6, gold_lo); c.disc(rx, ry, 1.7, gold)
        c.set(rx - 1, ry - 1, gold_hi)
    # gold corner flourishes (little L brackets just inside the rivets)
    for (ox, oy, sx, sy) in [(12, 12, 1, 1), (S - 13, 12, -1, 1), (12, S - 13, 1, -1), (S - 13, S - 13, -1, -1)]:
        for k in range(6):
            c.set(ox + sx * k, oy, gold); c.set(ox, oy + sy * k, gold)
        c.set(ox, oy, gold_hi)
    return S, S, c.px


def make_caption():
    """Intro lower-third caption bar 9-slice. Translucent dark plate framed by
    gold rules top AND bottom, with corner studs and domain gems. margin=14."""
    S = 32; c = C(S, S)
    body = (16, 11, 32, 220); top = hx("#e0bf52"); top_hi = hx("#f6e29a"); top_lo = hx("#9c7c28")
    c.rect(0, 0, S, S, body)
    # subtle inner gradient so it isn't a flat slab
    for y in range(2, S - 2):
        a = int(150 + 40 * math.sin(y / float(S) * math.pi))
        for x in range(2, S - 2):
            c.set(x, y, (20, 14, 38, a))
    for x in range(S):
        c.set(x, 0, OUTLINE); c.set(x, S - 1, OUTLINE)
    for y in range(S):
        c.set(0, y, OUTLINE); c.set(S - 1, y, OUTLINE)
    # gold rules, top and bottom
    for x in range(1, S - 1):
        c.set(x, 1, top_hi); c.set(x, 2, top); c.set(x, 3, top_lo)
        c.set(x, S - 2, top_lo); c.set(x, S - 3, top); c.set(x, S - 4, top_lo)
    # corner studs + a domain gem at each end of the top rule
    for (sx, sy) in [(6, 6), (S - 7, 6), (6, S - 7), (S - 7, S - 7)]:
        c.disc(sx, sy, 2.2, top_lo); c.disc(sx, sy, 1.3, top); c.set(sx - 1, sy - 1, top_hi)
    c.disc(11, 2, 1.6, DOMAIN_COL["Engineering"]); c.disc(S - 12, 2, 1.6, DOMAIN_COL["Art"])
    return S, S, c.px


# ============================================================== GLOW ==========
def make_glow():
    """Soft round radial glow (transparent, shown additively + tinted in engine)
    — used for the golden-age sun, the Shifter's staff light and the dawn."""
    S = 128; c = C(S, S); cx = cy = (S - 1) / 2.0; R = S / 2.0
    for y in range(S):
        for x in range(S):
            d = math.hypot(x - cx, y - cy) / R
            if d < 1.0:
                a = int(255 * (1 - d) ** 2.3)
                if a > 0:
                    c.set(x, y, (255, 246, 218, a))
    return S, S, c.px


# ============================================================= SHARD ==========
def make_shard():
    """A small chunk of debris that rains down during the Fracture beat."""
    W, H = 16, 16; c = C(W, H)
    rock = hx("#3f3358"); hi = hx("#6a5a8e"); edge = hx("#8a4660")
    pts = [(3, 8), (7, 2), (13, 6), (11, 13), (5, 12)]
    c.tri(pts[0], pts[1], pts[2], rock)
    c.tri(pts[0], pts[2], pts[3], rock)
    c.tri(pts[0], pts[3], pts[4], rock)
    c.line(pts[1][0], pts[1][1], pts[2][0], pts[2][1], hi, 0.7)     # lit edge
    c.line(pts[0][0], pts[0][1], pts[1][0], pts[1][1], shade(rock, 1.3), 0.6)
    c.set(int(pts[2][0]), int(pts[2][1]), edge)
    outline(c, OUTLINE)
    return W, H, c.px


# ============================================================ VIGNETTE =========
def make_vignette():
    W, H = 64, 36; c = C(W, H)
    cx, cy = (W - 1) / 2.0, (H - 1) / 2.0
    maxd = math.hypot(cx, cy)
    for y in range(H):
        for x in range(W):
            d = math.hypot(x - cx, y - cy) / maxd
            a = int(200 * max(0.0, (d - 0.52) / 0.48) ** 1.7)
            if a > 0:
                c.set(x, y, (6, 3, 14, min(220, a)))
    return W, H, c.px


# ============================================================== PREVIEW ========
def make_preview(layers, props):
    c = C(PW, PH)
    for (w, h, px) in layers:
        src = C(w, h); src.px = list(px); c.blit(src, 0, 0)
    # rift glow centre
    vw, vh, vpx = props["vortex"]; src = C(vw, vh); src.px = list(vpx)
    c.blit(src, PW // 2 - vw // 2, 38 - 0)
    # hero on the path
    hw, hh, hpx = props["hero"]; src = C(hw, hh); src.px = list(hpx)
    c.blit(src, PW // 2 - hw // 2, PH - hh - 8)
    # emblems in an arc under the title
    for i, dom in enumerate(DOMAIN_ORDER):
        w, h, px = props["emblem_" + dom.lower()]; src = C(w, h); src.px = list(px)
        x = int(70 + i * 50); y = int(150 - 8 * math.sin(math.pi * i / 4))
        c.blit(src, x, y)
    return PW, PH, c.px


# ================================================================ MAIN =========
def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/generated/title"
    os.makedirs(out, exist_ok=True)

    def w(name, tup):
        write_png(os.path.join(out, name + ".png"), *tup)
        return tup

    sky = w("sky", make_sky())
    hills = w("hills", make_hills())
    clouds = w("clouds", make_clouds())
    skyline = w("skyline", make_skyline())
    foreground = w("foreground", make_foreground())
    props = {
        "vortex": w("vortex", make_vortex()),
        "rays": w("rays", make_rays()),
        "hero": w("hero", make_hero()),
        "crack": w("crack", make_crack()),
        "glow": w("glow", make_glow()),
        "shard": w("shard", make_shard()),
        "emblem_engineering": w("emblem_engineering", emblem_engineering()),
        "emblem_farming": w("emblem_farming", emblem_farming()),
        "emblem_leadership": w("emblem_leadership", emblem_leadership()),
        "emblem_medicine": w("emblem_medicine", emblem_medicine()),
        "emblem_art": w("emblem_art", emblem_art()),
        "star_full": w("star_full", star_full()),
        "star_empty": w("star_empty", star_empty()),
        "sparkle": w("sparkle", make_sparkle()),
        "bird": w("bird", make_bird()),
        "title_banner": w("title_banner", make_title_banner()),
        "btn": w("btn", btn()),
        "btn_hi": w("btn_hi", btn_hi()),
        "panel": w("panel", make_panel()),
        "caption": w("caption", make_caption()),
        "vignette": w("vignette", make_vignette()),
    }
    if "--preview" in sys.argv:
        write_png("/tmp/title_preview.png",
                  *make_preview([sky, hills, clouds, skyline, foreground], props))
        print("Wrote /tmp/title_preview.png")

    print("Wrote title assets to %s" % out)


if __name__ == "__main__":
    main()
