#!/usr/bin/env python3
"""Dependency-free pixel-art generator for the ENDING CUTSCENE.

Writes RGBA PNGs directly (no Pillow). Same dark-outline + bevel house style as
tools/make_art.py / tools/make_immune.py so the ending matches the rest of the
game. Theme: a renaissance village reborn at golden hour, celebrating the five
career domains (Engineering / Farming / Leadership / Medicine / Art).

Generates a parallax panorama (drawn at 384x216, shown 3x with NEAREST):
  * sky        - dusk gradient + glowing sun + faint stars
  * clouds     - wide transparent strip that drifts horizontally
  * hills      - hazy far mountain ranges
  * village    - the reborn village on its ridge + winding river
  * foreground - grassy hill, path, flowers (5 domain colours), lamp, fence
plus props:
  * hero                  - the Shifter, arm raised in triumph
  * rays                  - additive god-ray sprite (rotates behind the title)
  * banner                - ornate ribbon plate for the title
  * emblem_<domain> x5    - round domain medallions
  * star_full / star_empty
  * sparkle               - 4-point glint (twinkle / embers / fireworks)
  * bird                  - tiny silhouette
  * _preview              - composite, for eyeballing only (not used by game)

Run:  python3 tools/make_ending.py assets/generated/ending
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


OUTLINE = hx("#211a2b")          # warm dark outline (sunset friendly)
PW, PH = 384, 216                # panorama art resolution (shown 3x -> 1152x648)
HORIZON = 132

# domain accent colours (art-directed versions of StarManager.DOMAIN_COLORS)
DOMAIN_COL = {
    "Engineering": hx("#f4c12e"),  # gold
    "Farming":     hx("#5fc85a"),  # green
    "Leadership":  hx("#3f8cf0"),  # blue
    "Medicine":    hx("#a25bf0"),  # purple
    "Art":         hx("#e8554e"),  # red
}


# ================================================================== SKY ======
SKY_STOPS = [
    (0.00, hx("#241b3e")),   # deep indigo zenith
    (0.30, hx("#4a3a6e")),   # violet
    (0.52, hx("#8a4e7e")),   # plum
    (0.70, hx("#d2685f")),   # rose
    (0.84, hx("#f0925a")),   # warm orange
    (1.00, hx("#ffd486")),   # pale gold horizon
]
SUN = (PW * 0.40, HORIZON - 16)


def make_sky():
    c = C(PW, PH)
    for y in range(PH):
        f = y / float(HORIZON if HORIZON else PH)
        col = grad(SKY_STOPS, min(1.0, y / float(HORIZON)))
        for x in range(PW):
            c.px[y * PW + x] = col
    sx, sy = SUN
    # halo
    for r in range(60, 0, -1):
        a = int(46 * (1 - r / 60.0))
        if a > 0:
            c.disc(sx, sy, r, (255, 210, 130, a))
    # sun body (banded glow)
    c.disc(sx, sy, 22, hx("#ffb858"))
    c.disc(sx, sy, 18, hx("#ffd07a"))
    c.disc(sx, sy, 13, hx("#ffe9ad"))
    c.disc(sx - 4, sy - 4, 6, hx("#fff6da"))
    # stars in the upper indigo band
    rnd = random.Random(7)
    for _ in range(70):
        x = rnd.randint(0, PW - 1); y = rnd.randint(0, int(HORIZON * 0.55))
        if rnd.random() < (1 - y / (HORIZON * 0.6)):
            b = rnd.choice([170, 210, 245])
            c.set(x, y, (b, b, 255, rnd.randint(120, 220)))
    return PW, PH, c.px


# ============================================================== CLOUDS ========
def make_clouds():
    W, H = 512, 116
    c = C(W, H)
    rnd = random.Random(13)
    base = hx("#f4c489"); hi = hx("#ffe6bf"); lo = hx("#c87f6e")
    for _ in range(11):
        cx = rnd.randint(20, W - 20); cy = rnd.randint(24, H - 24)
        scale = rnd.uniform(0.7, 1.5)
        puffs = [(0, 0, 16), (-13, 4, 11), (13, 3, 12), (-24, 7, 8), (24, 6, 8), (6, -6, 10), (-7, -4, 9)]
        for (dx, dy, r) in puffs:
            c.ellipse(cx + dx * scale, cy + dy * scale, r * scale, r * 0.62 * scale, base)
        for (dx, dy, r) in puffs:                # underside shadow
            c.ellipse(cx + dx * scale, cy + dy * scale + r * 0.42 * scale, r * scale, r * 0.30 * scale, lo)
        for (dx, dy, r) in puffs:                # sunlit tops
            c.ellipse(cx + dx * scale, cy + dy * scale - r * 0.40 * scale, r * 0.80 * scale, r * 0.34 * scale, hi)
    return W, H, c.px


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
    _ridge(c, HORIZON + 8, 16, 70, 1.7, hx("#7b6ba0"), 3)    # far range
    _ridge(c, HORIZON + 14, 12, 52, 4.2, hx("#6a5a92"), 8)   # mid range
    _ridge(c, HORIZON + 20, 9, 38, 0.6, hx("#5a4d83"), 5)    # near range
    # atmospheric haze near the horizon line
    for y in range(HORIZON - 4, HORIZON + 26):
        a = max(0, 80 - (y - (HORIZON - 4)) * 4)
        for x in range(PW):
            if c.get(x, y)[3] != 0:
                c.set(x, y, (255, 200, 150, a))
    return PW, PH, c.px


# ============================================================= VILLAGE ========
def _house(c, x, y, w, h, wall, roof, seed=0):
    """Beveled house with terracotta roof + warm lit windows."""
    wl, wd = shade(wall, 1.16), shade(wall, 0.74)
    c.rect(x, y, w, h, wall)
    for i in range(h):                                   # vertical light->dark bevel
        f = 1.12 - 0.34 * (i / max(1, h))
        c.rect(x, y + i, 2, 1, shade(wall, min(1.2, f + 0.06)))
        c.rect(x + w - 2, y + i, 2, 1, shade(wall, f - 0.12))
    # roof: trapezoid, overhanging both sides
    rh = max(6, h // 2)
    over = 3
    for i in range(rh):
        f = i / float(rh)
        half = (w / 2 + over) * f
        rc = shade(roof, 1.12 - 0.4 * f)
        for xx in range(int(x + w / 2 - half), int(x + w / 2 + half) + 1):
            c.set(xx, y - rh + i, rc)
    c.rect(x - over, y - 1, w + 2 * over, 2, shade(roof, 0.7))   # eave line
    # lit windows
    rnd = random.Random(seed + 1)
    gw = 3; gh = 4
    cols = max(1, (w - 4) // 6)
    for ci in range(cols):
        wx = x + 3 + ci * 6
        wy = y + h - 9
        if wx + gw < x + w - 1:
            c.rect(wx, wy, gw, gh, hx("#3a2c1c"))
            c.rect(wx, wy, gw, gh - 1, hx("#ffd070") if rnd.random() < 0.8 else hx("#caa24a"))
            c.set(wx, wy, hx("#fff0c0"))
    # door
    dx = x + w // 2 - 2
    c.rect(dx, y + h - 7, 4, 7, hx("#5a3a24"))
    c.rect(dx + 1, y + h - 6, 2, 6, hx("#724a2e"))


def _tree(c, x, y, r):
    trunk = hx("#4a3322")
    c.rect(x - 1, y, 3, r, trunk)
    canopy = hx("#3a6b40"); ch = shade(canopy, 1.25); cd = shade(canopy, 0.7)
    for (dx, dy, rr) in [(0, -r, r), (-r * 0.7, -r * 0.5, r * 0.8), (r * 0.7, -r * 0.5, r * 0.8),
                         (0, -r * 1.7, r * 0.8)]:
        c.disc(x + dx, y + dy, rr, canopy)
    c.disc(x - r * 0.4, y - r * 1.5, r * 0.5, ch)        # sunlit top-left
    c.disc(x + r * 0.5, y - r * 0.4, r * 0.45, cd)       # shadow lower-right


def make_village():
    c = C(PW, PH)
    # ground ridge the village sits on
    ground = hx("#5b7a44"); gdk = hx("#3f5c31")
    for x in range(PW):
        top = HORIZON + 6 + int(math.sin(x / 60.0 + 2) * 3)
        for y in range(top, HORIZON + 40):
            c.set(x, y, mix(ground, gdk, (y - top) / 36.0))

    # winding river catching the sun
    river = hx("#86c0e0"); rsky = hx("#b6e0f2")
    for y in range(HORIZON + 8, HORIZON + 42):
        f = (y - (HORIZON + 8)) / 34.0
        cxr = PW * 0.40 + math.sin(f * 3.1) * 26
        wdt = 3 + f * 9
        for x in range(int(cxr - wdt), int(cxr + wdt)):
            col = river if ((x + y) % 7) else rsky
            c.set(x, y, mix(col, hx("#ffe6a8"), max(0, 0.5 - f) * 0.7))  # sun glint upstream

    # tree line behind the houses
    for tx in range(8, PW, 33):
        _tree(c, tx + (tx % 5), HORIZON + 9, 5)

    # central town hall / cathedral tower with banner
    tx, ty, tw, th = PW // 2 - 9, HORIZON - 30, 18, 34
    _house(c, tx, ty, tw, th, hx("#dcc6a2"), hx("#54688f"), seed=99)
    c.rect(tx + tw // 2 - 3, ty - 16, 6, 16, hx("#c9b48f"))     # spire base
    c.tri((tx + tw // 2 - 4, ty - 16), (tx + tw // 2 + 4, ty - 16),
          (tx + tw // 2, ty - 26), hx("#46587c"))               # spire roof
    c.line(tx + tw // 2, ty - 26, tx + tw // 2, ty - 33, OUTLINE, 0.6)
    c.rect(tx + tw // 2, ty - 33, 9, 6, hx("#f0c33a"))          # gold banner
    c.tri((tx + tw // 2 + 9, ty - 33), (tx + tw // 2 + 9, ty - 27),
          (tx + tw // 2 + 12, ty - 30), hx("#f0c33a"))
    c.rect(tx + 3, ty + 6, 4, 7, hx("#ffe39a"))                 # big lit window
    c.rect(tx + tw - 7, ty + 6, 4, 7, hx("#ffe39a"))

    # cluster of houses around it
    houses = [
        (PW // 2 - 40, HORIZON - 4, 22, 16, hx("#e6c79a"), hx("#c5532f"), 1),
        (PW // 2 - 64, HORIZON + 2, 20, 14, hx("#d8b486"), hx("#b0472a"), 2),
        (PW // 2 + 16, HORIZON - 6, 24, 18, hx("#ecd0a4"), hx("#bb4d2c"), 3),
        (PW // 2 + 44, HORIZON + 1, 20, 15, hx("#d2ab7e"), hx("#a8412a"), 4),
        (PW // 2 - 88, HORIZON + 6, 18, 12, hx("#e0bf90"), hx("#b85436"), 5),
        (PW // 2 + 70, HORIZON + 5, 18, 13, hx("#dcbb8a"), hx("#a8412a"), 6),
    ]
    for (hxp, hyp, hw, hh, wc, rc, s) in houses:
        _house(c, hxp, hyp, hw, hh, wc, rc, seed=s)

    # windmill on the right rise (engineering/farming nod)
    mx = PW - 46
    body = hx("#cdb286"); base_y = HORIZON + 21; bh = 24
    bot_half, top_half = 8, 4
    for i in range(bh):                                      # tapered stone tower
        f = i / float(bh - 1)
        half = bot_half + (top_half - bot_half) * f
        yy = base_y - i
        for xx in range(int(mx - half), int(mx + half) + 1):
            d = (xx - mx) / half
            c.set(xx, yy, shade(body, 1.14 if d < -0.3 else (0.76 if d > 0.35 else 1.0)))
    c.tri((mx - top_half - 2, base_y - bh + 1), (mx + top_half + 2, base_y - bh + 1),
          (mx, base_y - bh - 8), hx("#7a4a30"))             # conical cap
    c.rect(mx - 2, base_y - 11, 4, 4, hx("#3a2c1c"))        # door
    c.rect(mx - 1, base_y - 18, 2, 3, hx("#ffd070"))        # lit window
    hub = (mx, base_y - bh + 4)
    for k in range(4):                                       # 4 X-sails with cloth slats
        a = k / 4.0 * math.tau + math.pi / 4
        ex, ey = hub[0] + math.cos(a) * 13, hub[1] + math.sin(a) * 13
        c.line(hub[0], hub[1], ex, ey, hx("#5a3f28"), 0.8)  # wooden arm
        px2, py2 = -math.sin(a), math.cos(a)
        for t in (5, 8, 11):                                # sail-cloth lattice
            sx, sy = hub[0] + math.cos(a) * t, hub[1] + math.sin(a) * t
            c.line(sx, sy, sx + px2 * 3.2, sy + py2 * 3.2, hx("#efe2c4"), 0.7)
    c.disc(hub[0], hub[1], 2, hx("#4a3322"))

    # flag-tipped watch tower on the left
    lx, ly = 30, HORIZON - 14
    c.rect(lx, ly, 9, 24, hx("#c3a880"))
    c.rect(lx - 1, ly - 3, 11, 3, hx("#9c8460"))
    c.rect(lx + 4, ly - 12, 1, 9, hx("#6a5238"))
    c.tri((lx + 5, ly - 12), (lx + 5, ly - 6), (lx + 12, ly - 9), DOMAIN_COL["Leadership"])

    outline(c, OUTLINE)
    return PW, PH, c.px


# =========================================================== FOREGROUND =======
def make_foreground():
    c = C(PW, PH)
    grass = hx("#5a9b4a"); gdk = hx("#3c7234"); glt = hx("#74b85a")
    # rolling foreground hill, higher at the edges, dips center for the path
    def crest(x):
        return HORIZON + 30 + int(-14 * math.cos((x / PW) * math.pi * 2) + math.sin(x / 40.0) * 3)
    for x in range(PW):
        top = crest(x)
        for y in range(top, PH):
            f = (y - top) / float(PH - top + 1)
            col = mix(glt, gdk, min(1.0, f * 1.3))
            c.set(x, y, col)
        c.set(x, top, glt)                                  # bright crest line
        c.set(x, top + 1, shade(glt, 1.1))

    # stone path winding up the dip to the village
    for y in range(crest(PW // 2), PH):
        f = (y - crest(PW // 2)) / float(PH - crest(PW // 2))
        cxp = PW / 2 + math.sin(f * 2.4) * 10
        wdt = 4 + f * 26
        for x in range(int(cxp - wdt), int(cxp + wdt)):
            if ((x * 3 + y * 5) % 23) < 11:
                c.set(x, y, hx("#c2b290"))
            else:
                c.set(x, y, hx("#a89578"))
        c.set(int(cxp - wdt), y, hx("#8c7a5e"))
        c.set(int(cxp + wdt) - 1, y, hx("#8c7a5e"))

    # flowers in the five domain colours, scattered on the slopes
    rnd = random.Random(21)
    petals = list(DOMAIN_COL.values())
    for _ in range(120):
        x = rnd.randint(6, PW - 6); y = rnd.randint(crest(x) + 4, PH - 4)
        if abs(x - PW / 2) < 20 + (y - HORIZON) * 0.5:       # keep path clear-ish
            continue
        col = rnd.choice(petals)
        c.set(x, y, shade(col, 1.05))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            c.set(x + dx, y + dy, shade(col, 0.8))
        c.set(x, y, hx("#fff3b0"))                           # bright center
        c.set(x, y + 2, hx("#2f5d2e"))                       # tiny stem

    # grass tufts along the crest
    for _ in range(90):
        x = rnd.randint(0, PW - 1); y = crest(x) + rnd.randint(0, 5)
        c.line(x, y, x + rnd.choice([-1, 1]), y - 3, shade(grass, 1.15), 0.5)

    # left lamp post
    lx = 40
    ly = crest(lx)
    c.rect(lx, ly - 26, 2, 26, hx("#33303c"))
    c.rect(lx - 2, ly - 30, 6, 5, hx("#46414f"))
    c.disc(lx + 1, ly - 28, 2.4, hx("#ffe39a"))
    c.disc(lx + 1, ly - 28, 1.2, hx("#fff7d8"))
    # right wooden fence
    fx = PW - 70
    fy = crest(fx)
    c.rect(fx, fy - 2, 56, 2, hx("#6a4a30"))
    c.rect(fx, fy + 3, 56, 2, hx("#5a3e28"))
    for k in range(0, 56, 9):
        c.rect(fx + k, fy - 8, 2, 14, hx("#6f4e34"))
        c.set(fx + k, fy - 8, hx("#8a6643"))

    outline(c, OUTLINE)
    return PW, PH, c.px


# ================================================================ HERO =========
def make_hero():
    """The Shifter, back to camera, one arm raised in triumph."""
    W, H = 30, 46
    c = C(W, H); cx = W / 2
    skin = hx("#e8b186"); cloak = hx("#3f6cae"); cl_d = shade(cloak, 0.7); cl_l = shade(cloak, 1.2)
    hair = hx("#3a2a1e"); boot = hx("#4a3326")
    # cloak/body
    c.rect(cx - 6, 18, 12, 18, cloak)
    c.tri((cx - 6, 18), (cx - 9, 36), (cx - 6, 36), cl_d)     # flare left
    c.tri((cx + 6, 18), (cx + 9, 36), (cx + 6, 36), cl_l)     # flare right (sunlit)
    for i in range(18):
        c.set(cx - 6, 18 + i, shade(cloak, 1.25))
        c.set(cx + 5, 18 + i, cl_d)
    c.rect(cx - 5, 30, 10, 2, hx("#caa23a"))                  # gold belt
    # legs
    c.rect(cx - 4, 36, 3, 7, hx("#2f4a72")); c.rect(cx + 1, 36, 3, 7, hx("#2f4a72"))
    c.rect(cx - 4, 42, 4, 3, boot); c.rect(cx, 42, 4, 3, boot)
    # head
    c.disc(cx, 13, 5, skin)
    c.disc(cx, 10, 5, hair); c.rect(cx - 5, 8, 10, 4, hair)
    c.set(cx - 2, 14, shade(skin, 0.8)); c.set(cx + 2, 14, shade(skin, 0.8))
    # raised right arm holding a glint
    c.line(cx + 5, 22, cx + 11, 6, cloak, 1.6)
    c.disc(cx + 11, 5, 2, skin)
    c.disc(cx + 11, 4, 3, hx("#fff2b0"))                      # spark in hand
    c.set(cx + 11, 4, hx("#ffffff"))
    # resting left arm
    c.line(cx - 5, 22, cx - 8, 31, cloak, 1.5)
    c.disc(cx - 8, 31, 1.6, skin)
    outline(c, OUTLINE)
    return W, H, c.px


# ============================================================ GOD RAYS =========
def make_rays():
    S = 256; c = C(S, S); cx = cy = S / 2
    n = 12
    for k in range(n):
        a0 = k / n * math.tau
        for rr in range(0, S // 2):
            spread = 0.06 + rr / S * 0.12
            for da in [x * 0.012 for x in range(int(-spread / 0.012), int(spread / 0.012) + 1)]:
                a = a0 + da
                x = cx + math.cos(a) * rr; y = cy + math.sin(a) * rr
                edge = 1 - abs(da) / max(0.001, spread)
                al = int(46 * edge * (1 - rr / (S / 2)))
                if al > 0:
                    c.set(x, y, (255, 232, 170, al))
    return S, S, c.px


# ============================================================== BANNER =========
def make_banner():
    """Ornate ribbon title plate (placed, not stretched)."""
    W, H = 288, 60; c = C(W, H); cy = H / 2
    body = hx("#2a1f3a"); band = hx("#e7c24a"); band_d = hx("#a07c22")
    # main plate
    c.rect(20, 12, W - 40, H - 24, body)
    for x in range(20, W - 20):                              # top/bottom gold rails
        c.set(x, 14, band); c.set(x, H - 15, band_d)
    for x in range(22, W - 22):
        c.set(x, 17, hx("#473a5e"))
    # forked ribbon tails
    for side, sx in ((-1, 18), (1, W - 18)):
        c.tri((sx, 6), (sx, H - 6), (sx - side * 18, cy), shade(body, 0.8))
        c.tri((sx, 10), (sx, H - 10), (sx - side * 11, cy), body)
        c.line(sx, 12, sx - side * 16, cy, band, 1.0)
        c.line(sx, H - 12, sx - side * 16, cy, band_d, 1.0)
    # corner studs
    for (sx, sy) in [(28, 20), (W - 28, 20), (28, H - 20), (W - 28, H - 20)]:
        c.disc(sx, sy, 2, band); c.set(sx, sy - 1, hx("#fff0a8"))
    outline(c, OUTLINE)
    return W, H, c.px


# ============================================================= EMBLEMS =========
def _coin(col):
    S = 44; c = C(S, S); cx = cy = S / 2 - 0.5
    c.disc(cx, cy, 20, shade(col, 0.45))                     # dark rim
    c.disc(cx, cy, 18, col)
    c.disc(cx - 4, cy - 4, 12, shade(col, 1.18))            # sheen
    c.ring(cx, cy, 18, 1.4, shade(col, 1.4))
    c.disc(cx - 6, cy - 6, 3, shade(col, 1.5))
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
    ink = hx("#3a2a08"); steel = hx("#fdf3cf")
    _gear(c, cx, cy, 8, steel)
    c.disc(cx, cy, 3, ink)
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
    # five-point crown
    base = cy + 6
    c.rect(cx - 9, base, 18, 4, gold)
    pts = [cx - 9, cx - 4.5, cx, cx + 4.5, cx + 9]
    for i, px in enumerate(pts):
        ph = 11 if i % 2 == 0 else 7
        c.tri((px - 2.4, base), (px + 2.4, base), (px, base - ph), gold)
        c.disc(px, base - ph, 1.5, hx("#fff6cf"))
    c.rect(cx - 9, base + 1, 18, 1, ink)
    for gx in (cx - 5, cx, cx + 5):
        c.disc(gx, base + 2, 1.2, hx("#e8554e"))            # jewels
    outline(c, OUTLINE)
    return c.w, c.h, c.px


def emblem_medicine():
    col = DOMAIN_COL["Medicine"]; c, cx, cy = _coin(col)
    glass = hx("#dff0ff"); fluid = hx("#54e0b0"); cork = hx("#caa15a")
    # flask
    c.tri((cx - 7, cy + 9), (cx + 7, cy + 9), (cx, cy - 2), glass)
    c.rect(cx - 2, cy - 9, 4, 7, glass)
    c.rect(cx - 3, cy - 11, 6, 2, cork)
    c.tri((cx - 4.5, cy + 8), (cx + 4.5, cy + 8), (cx, cy + 2), fluid)   # liquid
    c.disc(cx, cy + 6, 1.2, hx("#d6fff0"))
    # plus badge
    c.rect(cx - 1, cy + 2, 2, 6, hx("#ffffff")); c.rect(cx - 3, cy + 4, 6, 2, hx("#ffffff"))
    outline(c, OUTLINE)
    return c.w, c.h, c.px


def emblem_art():
    col = DOMAIN_COL["Art"]; c, cx, cy = _coin(col)
    wood = hx("#e8d2a6")
    c.ellipse(cx - 1, cy + 1, 11, 9, wood)                  # palette
    c.ellipse(cx + 4, cy + 4, 3.2, 2.4, (0, 0, 0, 0))       # thumb hole (carve)
    for yy in range(int(cy + 1), int(cy + 7)):              # re-carve cleanly
        for xx in range(int(cx + 1), int(cx + 8)):
            if ((xx - (cx + 4)) / 3.2) ** 2 + ((yy - (cy + 4)) / 2.4) ** 2 <= 1:
                c.px[yy * c.w + xx] = shade(col, 0.7)
    blobs = [(-6, -3, hx("#e8554e")), (-2, -5, hx("#f4c12e")), (3, -4, hx("#3f8cf0")),
             (5, 0, hx("#5fc85a")), (-5, 2, hx("#a25bf0"))]
    for (dx, dy, bc) in blobs:
        c.disc(cx + dx, cy + dy, 2, bc); c.set(cx + dx - 1, cy + dy - 1, shade(bc, 1.4))
    # brush
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

    fill = hx("#ffd54a") if filled else hx("#3a3050")
    hi = hx("#fff0a8") if filled else hx("#4a4060")
    for y in range(S):
        for x in range(S):
            if inside(x + 0.5, y + 0.5):
                c.set(x, y, hi if (x - cx) + (y - cy) < -1 else fill)
    outline(c, hx("#1c1630") if filled else hx("#2a2440"))
    return S, S, c.px


def star_full():   return _star(True)
def star_empty():  return _star(False)


# ============================================================= SPARKLE =========
def make_sparkle():
    S = 14; c = C(S, S); cx = cy = S / 2 - 0.5
    core = hx("#fff7d4"); mid = hx("#ffe08a"); glow = (255, 210, 120, 70)
    c.disc(cx, cy, 4, glow)
    for (dx, dy) in [(0, -6), (0, 6), (-6, 0), (6, 0)]:
        c.line(cx, cy, cx + dx, cy + dy, mid, 1.0)
    for (dx, dy) in [(-3, -3), (3, -3), (-3, 3), (3, 3)]:
        c.line(cx, cy, cx + dx, cy + dy, mid, 0.4)
    c.disc(cx, cy, 2, core)
    c.set(cx, cy, hx("#ffffff"))
    return S, S, c.px


# ================================================================ BIRD =========
def make_bird():
    W, H = 16, 9; c = C(W, H); col = hx("#2b2336")
    c.line(1, 5, 7, 1, col, 1.0)
    c.line(7, 1, 9, 3, col, 1.0)
    c.line(9, 3, 15, 0, col, 1.0)
    c.set(7, 2, shade(col, 1.6))
    return W, H, c.px


# ============================================================== PREVIEW ========
def make_preview(layers, props):
    c = C(PW, PH)
    for (w, h, px) in layers:
        src = C(w, h); src.px = list(px); c.blit(src, 0, 0)
    # drop the hero on the path
    hw, hh, hpx = props["hero"]
    src = C(hw, hh); src.px = list(hpx); c.blit(src, PW // 2 - hw // 2, PH - hh - 6)
    # emblems in a row up top
    x = 10
    for name in ["emblem_engineering", "emblem_farming", "emblem_leadership",
                 "emblem_medicine", "emblem_art"]:
        w, h, px = props[name]; src = C(w, h); src.px = list(px)
        c.blit(src, x, 6); x += w + 4
    # banner + small props bottom-right
    return PW, PH, c.px


# ================================================================ MAIN =========
def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/generated/ending"
    os.makedirs(out, exist_ok=True)

    def w(name, tup):
        write_png(os.path.join(out, name + ".png"), *tup)
        return tup

    sky = w("sky", make_sky())
    clouds = w("clouds", make_clouds())
    hills = w("hills", make_hills())
    village = w("village", make_village())
    foreground = w("foreground", make_foreground())
    props = {
        "hero": w("hero", make_hero()),
        "rays": w("rays", make_rays()),
        "banner": w("banner", make_banner()),
        "emblem_engineering": w("emblem_engineering", emblem_engineering()),
        "emblem_farming": w("emblem_farming", emblem_farming()),
        "emblem_leadership": w("emblem_leadership", emblem_leadership()),
        "emblem_medicine": w("emblem_medicine", emblem_medicine()),
        "emblem_art": w("emblem_art", emblem_art()),
        "star_full": w("star_full", star_full()),
        "star_empty": w("star_empty", star_empty()),
        "sparkle": w("sparkle", make_sparkle()),
        "bird": w("bird", make_bird()),
    }
    # dev-only composite preview (pass --preview); kept out of the asset folder
    # by default so the game never imports an unused texture.
    if "--preview" in sys.argv:
        write_png("/tmp/ending_preview.png",
                  *make_preview([sky, hills, clouds, village, foreground], props))
        print("Wrote /tmp/ending_preview.png")

    print("Wrote ending assets to %s" % out)


if __name__ == "__main__":
    main()
