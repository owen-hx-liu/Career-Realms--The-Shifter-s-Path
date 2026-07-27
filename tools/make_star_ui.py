#!/usr/bin/env python3
"""Dependency-free pixel-art generator for the STAR CODEX UI + star-room polish.

Produces one cohesive "cosmic codex" art set used by two things:
  * the press-R star menu  (scripts/core/StarStatsUI.gd)
  * the star-pedestal placement effects (scripts/enviorment/StarPedastal.gd)

Everything shares ONE palette (deep-space navy, gold filigree, luminous star
white) so the room + menu read as a single hand.  The star icon is drawn
near-white so it tints cleanly to any domain colour via Sprite/Label modulate.

Files written (all 8-bit RGBA PNG):
  panel.png      112x112  9-slice cosmic codex frame (margin 34) - menu bg
  plate.png       64x64   9-slice sunken inner panel  (margin 16) - sub-blocks
  ribbon.png      96x32   9-slice title ribbon        (margin 14) - headers
  star_full.png   40x40   luminous 5-point star (tintable) - icons + pedestal
  star_empty.png  40x40   dim hollow star socket           - unfilled gauge
  glow.png        64x64   soft radial glow (additive)      - bursts + hint halo
  sparkle.png     16x16   4-point twinkle                  - burst particles
  ring.png        48x48   thin bright ring                 - placement shockwave

No Pillow / ImageMagick - just a tiny PNG writer.  Also drops a 4x nearest
preview of each into the temp dir for offline eyeballing.

Run:   python3 tools/make_star_ui.py assets/generated/star_ui
Then:  Godot --headless --path . --import   (so the engine imports the PNGs)
"""
import sys, os, zlib, struct, math, tempfile


# ----------------------------------------------------------------- PNG writer
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


# ----------------------------------------------------------------- colour utils
def hx(s):
    s = s.lstrip("#")
    if len(s) == 8:
        return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), int(s[6:8], 16))
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)

def shade(c, f):
    return (max(0, min(255, int(c[0] * f))), max(0, min(255, int(c[1] * f))),
            max(0, min(255, int(c[2] * f))), c[3] if len(c) > 3 else 255)

def lerp(a, b, t):
    return (int(a[0] + (b[0] - a[0]) * t), int(a[1] + (b[1] - a[1]) * t),
            int(a[2] + (b[2] - a[2]) * t),
            int((a[3] if len(a) > 3 else 255) + ((b[3] if len(b) > 3 else 255) - (a[3] if len(a) > 3 else 255)) * t))

def over(dst, src):
    sa = src[3] / 255.0
    if sa <= 0:
        return dst
    if sa >= 1 or dst[3] == 0:
        return (src[0], src[1], src[2], 255 if sa >= 1 else src[3])
    da = dst[3] / 255.0
    oa = sa + da * (1 - sa)
    r = (src[0] * sa + dst[0] * da * (1 - sa)) / oa
    g = (src[1] * sa + dst[1] * da * (1 - sa)) / oa
    b = (src[2] * sa + dst[2] * da * (1 - sa)) / oa
    return (int(r), int(g), int(b), int(oa * 255))

def nhash(x, y, s=0):
    h = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    return (h ^ (h >> 13)) & 0x7fffffff


# ----------------------------------------------------------------- palette
TRANS   = (0, 0, 0, 0)

# deep-space body
VOID_HI = hx("#1c2752")   # lit upper navy
VOID    = hx("#121a3c")
VOID_DK = hx("#0a0f28")
VOID_DP = hx("#05071a")   # near-black bottom

# gold filigree
GOLD_HI = hx("#ffe9a6")
GOLD    = hx("#f4c64e")
GOLD_MD = hx("#cf9a2e")
GOLD_DK = hx("#8a641c")
GOLD_DP = hx("#4d3710")

# luminous star (kept light so modulate-tint reads true)
STAR_CORE = hx("#ffffff")
STAR_HI   = hx("#fffdf2")
STAR      = hx("#f3f1ff")
STAR_MD   = hx("#cdd2f0")
STAR_LO   = hx("#9aa6da")
STAR_OUT  = hx("#2a2350")   # cool dark outline

# accent sparks
SPARK   = hx("#bcd2ff")
OUTLINE = hx("#070912")


# ----------------------------------------------------------------- canvas
class C:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [TRANS] * (w * h)

    def put(self, x, y, col):
        x = int(x); y = int(y)
        if 0 <= x < self.w and 0 <= y < self.h and col[3] > 0:
            i = y * self.w + x
            self.px[i] = col if col[3] == 255 else over(self.px[i], col)

    def rect(self, x0, y0, x1, y1, col):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.put(x, y, col)

    def hline(self, x0, x1, y, col):
        for x in range(int(x0), int(x1) + 1):
            self.put(x, y, col)

    def vline(self, x, y0, y1, col):
        for y in range(int(y0), int(y1) + 1):
            self.put(x, y, col)

    def border(self, x0, y0, x1, y1, col):
        self.hline(x0, x1, y0, col); self.hline(x0, x1, y1, col)
        self.vline(x0, y0, y1, col); self.vline(x1, y0, y1, col)


# ----------------------------------------------------------------- building blocks
def starfield(cv, x0, y0, x1, y1):
    """Smooth top-lit navy gradient + sparse twinkles.  Gradient stretches
    cleanly under 9-slice; twinkles are tiny so any stretch stays unnoticed."""
    h = max(1, y1 - y0)
    for y in range(y0, y1 + 1):
        t = (y - y0) / float(h)
        base = lerp(VOID_HI, VOID_DP, min(1.0, t * 1.15))
        for x in range(x0, x1 + 1):
            col = base
            n = nhash(x, y, 7) % 140
            if n == 0:
                col = STAR_HI
            elif n == 1:
                col = STAR_MD
            elif n == 2:
                col = lerp(base, STAR_LO, 0.5)
            cv.put(x, y, col)


def gold_band(cv, x0, y0, x1, y1):
    """A beveled gold rectangle band: dark outer edge, bright top-left catch,
    deep bottom-right shadow.  Traces just the outline rectangle."""
    cv.border(x0, y0, x1, y1, GOLD_DP)
    cv.border(x0 + 1, y0 + 1, x1 - 1, y1 - 1, GOLD)
    cv.hline(x0 + 1, x1 - 1, y0 + 1, GOLD_HI)
    cv.vline(x0 + 1, y0 + 1, y1 - 1, GOLD_HI)
    cv.hline(x0 + 1, x1 - 1, y1 - 1, GOLD_DK)
    cv.vline(x1 - 1, y0 + 1, y1 - 1, GOLD_DK)
    cv.border(x0 + 2, y0 + 2, x1 - 2, y1 - 2, GOLD_MD)


def corner_stud(cv, cx, cy):
    """A small faceted gold gem stud for panel corners."""
    cv.rect(cx - 3, cy - 3, cx + 3, cy + 3, GOLD_DP)
    cv.rect(cx - 2, cy - 2, cx + 2, cy + 2, GOLD_MD)
    cv.rect(cx - 2, cy - 2, cx + 1, cy + 1, GOLD)
    cv.put(cx - 1, cy - 1, GOLD_HI)
    cv.put(cx, cy - 1, GOLD_HI)
    cv.put(cx - 1, cy, GOLD_HI)
    cv.put(cx + 2, cy + 2, GOLD_DK)


# ----------------------------------------------------------------- 5-point star
def _star_inside(dx, dy, R, r):
    """True if point is within the 5-point star (point-up).  Returns the
    normalised inner depth 0..1 (1 = centre) for shading, or None if outside."""
    d = math.hypot(dx, dy)
    if d < 1e-4:
        return 1.0
    ang = math.atan2(dx, -dy)            # 0 at top, +cw
    seg = math.pi / 5.0                  # 36 deg
    a = ang % (2 * seg)
    if a > seg:
        a = 2 * seg - a                  # fold into 0..seg ramp
    f = a / seg                          # 0 at a point, 1 at a valley
    edge = R + (r - R) * f               # radius of the star edge at this angle
    if d <= edge:
        return 1.0 - d / edge
    return None


def build_star(full=True):
    W = H = 40
    cv = C(W, H)
    cx, cy = 19.5, 20.5
    R, r = 18.0, 7.6
    inside = {}
    for y in range(H):
        for x in range(W):
            depth = _star_inside(x - cx, y - cy, R, r)
            if depth is not None:
                inside[(x, y)] = depth
    # outline = 1px dilation of the shape
    out = set()
    for (x, y) in inside:
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                if (x + ox, y + oy) not in inside:
                    out.add((x + ox, y + oy))
    for (x, y) in out:
        cv.put(x, y, STAR_OUT)
    if full:
        for (x, y), depth in inside.items():
            t = (y - 2) / float(H)                       # vertical sheen
            base = lerp(STAR, STAR_LO, min(1.0, t * 1.1))
            # bright crystalline core
            if depth > 0.62:
                base = STAR_CORE
            elif depth > 0.42:
                base = lerp(STAR_HI, base, 0.35)
            # upper-left specular catch
            if (x - cx) < -1 and (y - cy) < -1 and depth > 0.2:
                base = lerp(base, STAR_CORE, 0.5)
            cv.put(x, y, base)
        # tiny inner shadow rim lower-right for a faceted gem read
        for (x, y), depth in inside.items():
            if 0.05 < depth < 0.2 and (x - cx) > 1 and (y - cy) > 1:
                cv.put(x, y, lerp(cv.px[y * W + x], STAR_OUT, 0.25))
    else:
        # hollow socket: faint navy fill, inner ring of dim star-grey
        for (x, y), depth in inside.items():
            cv.put(x, y, lerp(VOID_DK, VOID, depth))
        ring = [p for p, d in inside.items() if 0.10 < d < 0.26]
        for (x, y) in ring:
            cv.put(x, y, STAR_LO)
    return W, H, cv


# ----------------------------------------------------------------- glow / spark
def build_glow():
    W = H = 64
    cv = C(W, H)
    cx, cy = (W - 1) / 2.0, (H - 1) / 2.0
    Rmax = W / 2.0
    for y in range(H):
        for x in range(W):
            d = math.hypot(x - cx, y - cy) / Rmax
            if d < 1.0:
                a = (1.0 - d) ** 2.2
                cv.put(x, y, (255, 248, 222, int(a * 255)))
    return W, H, cv


def build_sparkle():
    W = H = 16
    cv = C(W, H)
    cx, cy = 7.5, 7.5
    for y in range(H):
        for x in range(W):
            dx, dy = abs(x - cx), abs(y - cy)
            d = math.hypot(dx, dy)
            spike = max(0.0, 1.0 - (dx + dy) / 8.0)      # 4-point diamond falloff
            core = max(0.0, 1.0 - d / 2.4)
            a = max(spike * 0.85, core)
            if a > 0.02:
                col = lerp(SPARK, STAR_CORE, min(1.0, core * 1.4))
                cv.put(x, y, (col[0], col[1], col[2], int(min(1.0, a) * 255)))
    return W, H, cv


def build_ring():
    W = H = 48
    cv = C(W, H)
    cx, cy = (W - 1) / 2.0, (H - 1) / 2.0
    R = 20.0
    for y in range(H):
        for x in range(W):
            d = math.hypot(x - cx, y - cy)
            e = abs(d - R)
            if e < 3.0:
                a = (1.0 - e / 3.0) ** 1.5
                col = lerp(GOLD, STAR_CORE, max(0.0, 1.0 - e / 3.0))
                cv.put(x, y, (col[0], col[1], col[2], int(a * 235)))
    return W, H, cv


# ----------------------------------------------------------------- panels
def build_panel():
    """Cosmic codex frame, 9-slice margin 34."""
    W = H = 112
    cv = C(W, H)
    x0, y0, x1, y1 = 0, 0, W - 1, H - 1
    starfield(cv, x0, y0, x1, y1)
    # layered gold frame
    cv.border(x0, y0, x1, y1, OUTLINE)
    gold_band(cv, x0 + 1, y0 + 1, x1 - 1, y1 - 1)
    # inner sunken lip around the field
    li = 9
    cv.border(x0 + li, y0 + li, x1 - li, y1 - li, GOLD_DK)
    cv.border(x0 + li + 1, y0 + li + 1, x1 - li - 1, y1 - li - 1, VOID_DP)
    cv.hline(x0 + li + 1, x1 - li - 1, y0 + li + 1, VOID_DK)
    # corner studs
    for (sx, sy) in ((x0 + 6, y0 + 6), (x1 - 6, y0 + 6), (x0 + 6, y1 - 6), (x1 - 6, y1 - 6)):
        corner_stud(cv, sx, sy)
    return W, H, cv


def build_plate():
    """Sunken inner sub-panel, 9-slice margin 16 (groups hero/domain blocks)."""
    W = H = 64
    cv = C(W, H)
    x0, y0, x1, y1 = 0, 0, W - 1, H - 1
    # translucent dark glass body
    for y in range(H):
        t = y / float(H)
        col = lerp(VOID, VOID_DP, t)
        for x in range(W):
            cv.put(x, y, (col[0], col[1], col[2], 235))
    cv.border(x0, y0, x1, y1, OUTLINE)
    cv.border(x0 + 1, y0 + 1, x1 - 1, y1 - 1, GOLD_DK)
    cv.hline(x0 + 2, x1 - 2, y0 + 2, lerp(VOID_HI, GOLD_DK, 0.4))   # top inner catch
    cv.hline(x0 + 1, x1 - 1, y1 - 1, VOID_DP)
    return W, H, cv


def build_ribbon():
    """Title ribbon plate, 9-slice margin 14 (header bar)."""
    W, H = 96, 32
    cv = C(W, H)
    x0, y0, x1, y1 = 0, 0, W - 1, H - 1
    for y in range(H):
        t = y / float(H)
        col = lerp(hx("#22305f"), hx("#0e1430"), t)
        for x in range(W):
            cv.put(x, y, col)
    cv.border(x0, y0, x1, y1, OUTLINE)
    gold_band(cv, x0 + 1, y0 + 1, x1 - 1, y1 - 1)
    cv.border(x0 + 4, y0 + 4, x1 - 4, y1 - 4, GOLD_DK)
    return W, H, cv


# ----------------------------------------------------------------- output
def save(out, name, w, h, cv, scale=6):
    write_png(os.path.join(out, name + ".png"), w, h, cv.px)
    pw, ph = w * scale, h * scale
    big = [TRANS] * (pw * ph)
    for y in range(ph):
        for x in range(pw):
            big[y * pw + x] = cv.px[(y // scale) * w + (x // scale)]
    prev = os.path.join(tempfile.gettempdir(), "star_ui_" + name + "_preview.png")
    write_png(prev, pw, ph, big)
    print("  %-12s -> %s" % (name, prev))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/generated/star_ui"
    os.makedirs(out, exist_ok=True)
    save(out, "panel", *build_panel())
    save(out, "plate", *build_plate())
    save(out, "ribbon", *build_ribbon())
    save(out, "star_full", *build_star(True))
    save(out, "star_empty", *build_star(False))
    save(out, "glow", *build_glow())
    save(out, "sparkle", *build_sparkle())
    save(out, "ring", *build_ring())
    print("Wrote STAR CODEX art (+previews) to", out)


if __name__ == "__main__":
    main()
