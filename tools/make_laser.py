#!/usr/bin/env python3
"""Dependency-free pixel-art generator for the PRISM ARRAY laser quest.

Writes RGBA PNGs directly (no Pillow), in the same beveled / dark-outline
house style as tools/make_nanobot.py and tools/make_immune.py. Theme: a cool
deep-space photonics lab — indigo board, chrome optics, neon beams and gold UI.

Generates:
  * background        : bg (1152x648)
  * 9-slice UI frames : frame_panel, frame_window, frame_banner, button,
                        slot_off, slot_on
  * board tiles       : cell, wall
  * optics sprites    : emitter, mirror, prism, socket, gem, glow, spark
  * icons             : icon_mirror, icon_prism, icon_target
  * stars             : star_full, star_empty

Run:  python3 tools/make_laser.py assets/generated/laser
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

    def poly(self, pts, c):
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            xs = []
            n = len(pts)
            j = n - 1
            for i in range(n):
                yi, yj = pts[i][1], pts[j][1]
                if (yi > y) != (yj > y):
                    xs.append(pts[i][0] + (y - yi) / (yj - yi) * (pts[j][0] - pts[i][0]))
                j = i
            xs.sort()
            for k in range(0, len(xs) - 1, 2):
                for x in range(int(math.ceil(xs[k])), int(xs[k + 1]) + 1):
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


OUTLINE = hx("#070612")          # universal near-black indigo outline

# theme palette ---------------------------------------------------------------
CYAN = hx("#34e0ff")
CYAN_HI = hx("#aef4ff")
CYAN_DK = hx("#1d7d99")
STEEL = hx("#c6d2dd")
STEEL_MD = hx("#7f8b9a")
STEEL_DK = hx("#414c5a")
NAVY = hx("#141027")
NAVY_HI = hx("#251d44")
GOLD = hx("#e8c24a")
GOLD_HI = hx("#f6e08a")
GLASS = hx("#e9f4ff")


# ============================================================ THE EMITTER ====
def emitter():
    """36x36 laser cannon, muzzle pointing RIGHT (rotated in code).
    Chrome housing, dark vents, a white-hot aperture that code haloes."""
    S = 36; c = C(S, S); cy = S / 2 - 0.5
    # rear mounting block
    for x in range(4, 14):
        half = 11 - (x - 4) * 0.2
        for y in range(int(cy - half), int(cy + half) + 1):
            d = (y - cy)
            col = shade(STEEL, 1.12) if d < -half * 0.5 else (STEEL_DK if d > half * 0.45 else STEEL_MD)
            c.set(x, y, col)
    # barrel (tapers toward the muzzle on the right)
    for x in range(12, 31):
        f = (x - 12) / 19.0
        half = 9.0 - 4.5 * f
        for y in range(int(cy - half), int(cy + half) + 1):
            d = (y - cy)
            col = shade(STEEL, 1.16) if d < -half * 0.5 else (STEEL_DK if d > half * 0.4 else STEEL_MD)
            c.set(x, y, col)
    # crisp top rim shine
    for x in range(6, 30):
        f = max(0.0, (x - 12) / 19.0)
        half = 9.0 - 4.5 * f if x >= 12 else 10.0
        c.set(x, cy - half, hx("#eef6ff"))
    # plated seams + cooling vents
    for vx in (10, 16, 21):
        c.line(vx, cy - 6, vx, cy + 6, STEEL_DK, 0.5)
    # cyan energy cell on the body
    c.disc(9, cy, 3.0, CYAN_DK)
    c.disc(9, cy, 2.0, CYAN)
    c.disc(8.4, cy - 0.6, 0.9, CYAN_HI)
    # muzzle aperture (white-hot) at the right
    c.disc(30, cy, 4.4, hx("#0a1830"))
    c.disc(31, cy, 3.2, CYAN_DK)
    c.disc(31, cy, 2.2, CYAN_HI)
    c.disc(31.5, cy, 1.2, hx("#ffffff"))
    outline(c, OUTLINE)
    return S, S, c.px


# ============================================================ THE MIRROR =====
def mirror():
    """32x32 angled mirror in the '/' orientation (code rotates 90 for '\\').
    A polished glass face with a chrome bevel and dark mounting caps."""
    S = 32; c = C(S, S)
    # the '/' band is the anti-diagonal  x + y == S-1
    for y in range(S):
        for x in range(S):
            d = (x + y) - (S - 1)        # signed distance across the band
            if abs(d) <= 4.2:
                if d < -2.2:
                    col = hx("#f2fbff")          # bright reflective face (upper-left)
                elif d < -0.4:
                    col = CYAN_HI
                elif d <= 1.4:
                    col = hx("#bcd6e6")           # mirror body
                elif d <= 3.0:
                    col = STEEL_MD
                else:
                    col = STEEL_DK               # shadow backing (lower-right)
                c.set(x, y, col)
    # a thin bright specular streak down the face
    for t in range(S):
        x = t * 0.5 + 1.5
        y = (S - 1) - (x) - 1.6
        c.set(x, y, hx("#ffffff"))
    # dark chrome mounting caps at the two ends of the diagonal
    c.disc(2.5, S - 3.5, 3.0, STEEL_DK)
    c.disc(2.5, S - 3.5, 1.6, STEEL_MD)
    c.disc(S - 3.5, 2.5, 3.0, STEEL_DK)
    c.disc(S - 3.5, 2.5, 1.6, STEEL_MD)
    outline(c, OUTLINE)
    return S, S, c.px


# ============================================================ THE PRISM ======
def prism():
    """30x30 faceted glass diamond, near-white so it tints cleanly via modulate.
    Strong internal facets + a hot core so a coloured prism really glows."""
    S = 30; c = C(S, S); cx = cy = S / 2 - 0.5
    top = (cx, 2.5); right = (S - 3.0, cy); bot = (cx, S - 2.5); left = (3.0, cy)
    # body
    c.poly([top, right, bot, left], GLASS)
    # facet shading: 4 triangles from centre, each a different tone
    c.poly([top, right, (cx, cy)], hx("#cfe6f5"))
    c.poly([right, bot, (cx, cy)], hx("#9fc0d8"))
    c.poly([bot, left, (cx, cy)], hx("#bcd8ec"))
    c.poly([left, top, (cx, cy)], hx("#eef7ff"))
    # bright edges
    c.line(*top, *right, hx("#ffffff"), 0.6)
    c.line(*left, *top, hx("#ffffff"), 0.7)
    c.line(*right, *bot, hx("#7fa6c0"), 0.6)
    c.line(*bot, *left, hx("#9bbed6"), 0.6)
    # hot core + sparkle
    c.disc(cx, cy, 2.6, hx("#ffffff"))
    c.disc(cx - 0.6, cy - 0.6, 1.2, hx("#ffffff"))
    c.set(cx + 3, cy - 4, hx("#ffffff"))
    c.set(cx - 4, cy + 3, hx("#ffffff"))
    outline(c, OUTLINE)
    return S, S, c.px


# ============================================================ TARGET =========
def socket():
    """40x40 chrome receiver housing (neutral) that cradles the gem."""
    S = 40; c = C(S, S); cx = cy = S / 2 - 0.5
    # outer ring with bevel
    c.disc(cx, cy, 18, STEEL_DK)
    c.disc(cx, cy, 16.5, STEEL_MD)
    c.disc(cx, cy, 14.5, shade(STEEL, 1.05))
    c.ring(cx, cy, 16.5, 2.0, shade(STEEL, 1.18))   # top sheen
    # recessed dark seat
    c.disc(cx, cy, 12.5, hx("#0c1424"))
    c.disc(cx, cy, 11.0, hx("#13203a"))
    # four mounting bolts
    for a in (45, 135, 225, 315):
        ar = math.radians(a)
        bx, by = cx + math.cos(ar) * 15.5, cy + math.sin(ar) * 15.5
        c.disc(bx, by, 2.2, STEEL_DK)
        c.disc(bx, by, 1.2, shade(STEEL, 1.1))
    outline(c, OUTLINE)
    return S, S, c.px


def gem():
    """26x26 faceted crystal, near-white so code tints it per target colour
    (dark when unlit, full colour + glow when lit)."""
    S = 26; c = C(S, S); cx = cy = S / 2 - 0.5
    top = (cx, 1.5); ur = (S - 2.5, cy - 4); lr = (S - 5, S - 2.5)
    ll = (4, S - 2.5); ul = (1.5, cy - 4)
    c.poly([top, ur, lr, ll, ul], GLASS)
    # facets
    c.poly([top, ur, (cx, cy)], hx("#ffffff"))
    c.poly([ur, lr, (cx, cy)], hx("#c4d8e8"))
    c.poly([lr, ll, (cx, cy)], hx("#9fb8cc"))
    c.poly([ll, ul, (cx, cy)], hx("#b8d0e2"))
    c.poly([ul, top, (cx, cy)], hx("#eaf4ff"))
    # edge glints
    c.line(*ul, *top, hx("#ffffff"), 0.6)
    c.line(*top, *ur, hx("#ffffff"), 0.6)
    c.disc(cx, cy, 1.8, hx("#ffffff"))
    outline(c, OUTLINE)
    return S, S, c.px


# ============================================================ TILES ==========
def cell():
    """32x32 board cell — a faint recessed slot the player can build on.
    Semi-transparent so the lab board shows through; subtle corner rivets."""
    S = 32; c = C(S, S)
    c.rect(2, 2, S - 4, S - 4, (40, 52, 92, 70))
    # inner recessed border
    for x in range(3, S - 3):
        c.set(x, 3, (16, 22, 44, 150)); c.set(x, S - 4, (70, 88, 140, 90))
    for y in range(3, S - 3):
        c.set(3, y, (16, 22, 44, 150)); c.set(S - 4, y, (70, 88, 140, 90))
    # corner rivets
    for (rx, ry) in ((5, 5), (S - 6, 5), (5, S - 6), (S - 6, S - 6)):
        c.set(rx, ry, (120, 150, 210, 150))
    # faint centre dot grid mark
    c.set(S / 2 - 0.5, S / 2 - 0.5, (90, 120, 180, 60))
    return S, S, c.px


def wall():
    """32x32 solid tech block that stops the beam."""
    S = 32; c = C(S, S)
    base, hi, dk = hx("#2b3358"), hx("#454f80"), hx("#161a34")
    c.rect(1, 1, S - 2, S - 2, base)
    # bevel
    for x in range(1, S - 1):
        c.set(x, 1, hi); c.set(x, 2, shade(hi, 0.9))
        c.set(x, S - 2, dk); c.set(x, S - 3, shade(dk, 1.2))
    for y in range(1, S - 1):
        c.set(1, y, shade(hi, 0.95)); c.set(S - 2, y, dk)
    # rivets + circuit etch
    for (rx, ry) in ((6, 6), (S - 7, 6), (6, S - 7), (S - 7, S - 7)):
        c.disc(rx, ry, 1.6, hx("#101428"))
        c.disc(rx, ry, 0.9, hx("#5a6699"))
    c.line(11, 16, 21, 16, hx("#1b2244"), 0.7)
    c.line(16, 11, 16, 21, hx("#1b2244"), 0.7)
    c.disc(16, 16, 2.2, hx("#5a6699"))
    c.disc(16, 16, 1.1, CYAN_DK)
    for x in range(1, S - 1):
        c.set(x, 0, OUTLINE); c.set(x, S - 1, OUTLINE)
    for y in range(1, S - 1):
        c.set(0, y, OUTLINE); c.set(S - 1, y, OUTLINE)
    return S, S, c.px


# ============================================================ FX =============
def spark():
    """9x9 bright 4-point spark (white core, tinted via modulate)."""
    S = 9; c = C(S, S); cx = cy = S / 2
    c.line(cx, 0, cx, S - 1, hx("#ffffff"), 0.6)
    c.line(0, cy, S - 1, cy, hx("#ffffff"), 0.6)
    c.disc(cx, cy, 1.8, hx("#ffffff"))
    return S, S, c.px


def glow():
    """64x64 soft radial glow (white, tinted via modulate)."""
    S = 64; c = C(S, S); cx = cy = S / 2 - 0.5
    for y in range(S):
        for x in range(S):
            d = math.hypot(x - cx, y - cy) / (S / 2)
            if d < 1.0:
                a = int(170 * (1 - d) ** 2.1)
                c.set(x, y, (255, 255, 255, a))
    return S, S, c.px


# ============================================================ ICONS =========
def icon_mirror():
    S = 16; c = C(S, S)
    for y in range(S):
        for x in range(S):
            d = (x + y) - (S - 1)
            if abs(d) <= 2.2:
                c.set(x, y, hx("#eaf6ff") if d < 0 else STEEL_MD)
    c.disc(2, S - 3, 1.6, STEEL_DK)
    c.disc(S - 3, 2, 1.6, STEEL_DK)
    outline(c, OUTLINE)
    return S, S, c.px


def icon_prism():
    S = 16; c = C(S, S); cx = cy = S / 2 - 0.5
    c.poly([(cx, 1.5), (S - 2.5, cy), (cx, S - 1.5), (1.5, cy)], CYAN_HI)
    c.poly([(cx, 1.5), (S - 2.5, cy), (cx, cy)], CYAN)
    c.poly([(cx, cy), (S - 2.5, cy), (cx, S - 1.5)], CYAN_DK)
    c.disc(cx, cy, 1.4, hx("#ffffff"))
    outline(c, OUTLINE)
    return S, S, c.px


def icon_target():
    S = 16; c = C(S, S); cx = cy = S / 2 - 0.5
    c.disc(cx, cy, 7, STEEL_DK)
    c.disc(cx, cy, 5.5, hx("#13203a"))
    c.poly([(cx, 3), (cx + 3.5, cy), (cx, S - 3), (cx - 3.5, cy)], CYAN_HI)
    c.disc(cx, cy, 1.2, hx("#ffffff"))
    outline(c, OUTLINE)
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

    fill = hx("#ffd54a") if filled else hx("#2b3450")
    hi = hx("#fff0a8") if filled else hx("#3b4868")
    for y in range(S):
        for x in range(S):
            if inside(x + 0.5, y + 0.5):
                c.set(x, y, hi if (x - cx) + (y - cy) < -1 else fill)
    outline(c, hx("#151d2c") if filled else hx("#222d40"))
    return S, S, c.px


def star_full():   return _star(True)
def star_empty():  return _star(False)


# ============================================================ UI FRAMES =====
def _frame(S, fill, border, edge, hi, bevel=2):
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


def frame_panel():   return _frame(24, hx("#141027"), hx("#2f7d99"), hx("#070612"), hx("#46c6e6"))
def frame_window():  return _frame(28, hx("#0e0a1c"), hx("#e8c24a"), hx("#070510"), hx("#f6e08a"), bevel=3)


def frame_banner():
    S = 24; c = C(S, S)
    c.rect(0, 0, S, S, hx("#100b22"))
    for x in range(S):
        c.set(x, 0, OUTLINE); c.set(x, S - 1, OUTLINE)
    for y in range(S):
        c.set(0, y, OUTLINE); c.set(S - 1, y, OUTLINE)
    for x in range(1, S - 1):
        c.set(x, 1, hx("#e8c24a")); c.set(x, S - 2, hx("#9c7e26"))
        c.set(x, 3, hx("#1d6f8a"))
    for y in range(1, S - 1):
        c.set(1, y, hx("#d4af36")); c.set(S - 2, y, hx("#80661c"))
    return S, S, c.px


def button():
    # near-white so it tints cleanly via modulate_color
    S = 22; c = C(S, S)
    c.rect(0, 0, S, S, (228, 236, 233, 255))
    for x in range(S):
        c.set(x, 1, (255, 255, 255, 255)); c.set(x, 2, (246, 250, 248, 255))
        c.set(x, S - 2, (146, 154, 156, 255)); c.set(x, S - 3, (184, 192, 190, 255))
    for y in range(S):
        c.set(1, y, (250, 252, 250, 255)); c.set(S - 2, y, (164, 172, 170, 255))
    edge = (12, 16, 26, 255)
    for x in range(S):
        c.set(x, 0, edge); c.set(x, S - 1, edge)
    for y in range(S):
        c.set(0, y, edge); c.set(S - 1, y, edge)
    return S, S, c.px


def slot_off():
    """24x24 toolbar slot (unselected) — recessed navy."""
    return _frame(24, hx("#100c20"), hx("#26305a"), hx("#070612"), hx("#39477f"))


def slot_on():
    """24x24 toolbar slot (selected) — cyan-lit."""
    return _frame(24, hx("#10283a"), hx("#34e0ff"), hx("#06141e"), hx("#aef4ff"), bevel=2)


# ============================================================ BACKGROUND ====
def make_bg():
    W, H = 1152, 648; c = C(W, H)
    top, bot = hx("#16123a"), hx("#05030f")
    for y in range(H):
        f = y / H
        c.px[y * W:(y + 1) * W] = [mix(top, bot, f ** 1.1)] * W
    rnd = random.Random(7)
    # soft nebula bokeh (cool magenta + cyan)
    for _ in range(26):
        x = rnd.randint(0, W); y = rnd.randint(0, H); r = rnd.randint(40, 120)
        base = rnd.choice([(90, 60, 180), (40, 150, 200), (150, 60, 170)])
        for ring_r in range(r, r - 5, -1):
            for a in range(0, 360, 5):
                ar = math.radians(a)
                c.set(x + math.cos(ar) * ring_r, y + math.sin(ar) * ring_r, (base[0], base[1], base[2], 10))
        c.disc(x, y, r - 6, (base[0], base[1], base[2], 5))
    # blueprint grid
    for gx in range(0, W, 48):
        for y in range(H):
            c.set(gx, y, (120, 170, 220, 9))
    for gy in range(0, H, 48):
        for x in range(W):
            c.set(x, gy, (120, 170, 220, 9))
    # glowing circuit traces
    for _ in range(20):
        x = rnd.randint(40, W - 40); y = rnd.randint(40, H - 40)
        col = (52, 224, 255, 26)
        steps = rnd.randint(3, 6)
        for _s in range(steps):
            horiz = rnd.random() < 0.5
            ln = rnd.choice([48, 96, 96, 144])
            nx = x + (rnd.choice([-1, 1]) * ln if horiz else 0)
            ny = y + (0 if horiz else rnd.choice([-1, 1]) * ln)
            c.line(x, y, nx, ny, col, 0.7)
            c.disc(nx, ny, 1.4, (52, 224, 255, 40))
            x, y = max(8, min(W - 8, nx)), max(8, min(H - 8, ny))
    # starfield specks
    for _ in range(220):
        x = rnd.randint(0, W); y = rnd.randint(0, H)
        b = rnd.randint(40, 150)
        c.disc(x, y, rnd.choice([0.6, 1, 1]), (200, 220, 255, b))
    # heavy vignette
    for y in range(H):
        for x in range(W):
            dx = (x - W / 2) / (W / 2); dy = (y - H / 2) / (H / 2); d = dx * dx + dy * dy
            if d > 0.5:
                c.set(x, y, (4, 2, 12, int(min(190, (d - 0.5) * 240))))
    return W, H, c.px


# ============================================================ MAIN ==========
def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/generated/laser"
    os.makedirs(out, exist_ok=True)

    def w(name, tup):
        write_png(os.path.join(out, name + ".png"), *tup)

    # frames + ui
    w("frame_panel", frame_panel())
    w("frame_window", frame_window())
    w("frame_banner", frame_banner())
    w("button", button())
    w("slot_off", slot_off())
    w("slot_on", slot_on())
    # tiles
    w("cell", cell())
    w("wall", wall())
    # optics sprites
    w("emitter", emitter())
    w("mirror", mirror())
    w("prism", prism())
    w("socket", socket())
    w("gem", gem())
    w("glow", glow())
    w("spark", spark())
    # icons
    w("icon_mirror", icon_mirror())
    w("icon_prism", icon_prism())
    w("icon_target", icon_target())
    # stars
    w("star_full", star_full())
    w("star_empty", star_empty())
    # background
    w("bg", make_bg())

    print("Wrote laser quest assets to %s" % out)


if __name__ == "__main__":
    main()
