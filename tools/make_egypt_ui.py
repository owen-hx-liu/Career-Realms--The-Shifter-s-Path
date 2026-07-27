#!/usr/bin/env python3
"""Dependency-free pixel-art generator for the Ancient Egypt quest UI.

Replaces the old generic parchment scroll (narrator) and plain tan panel
(level-complete screen) with a cohesive set of carved-sandstone monuments:

  narrator_panel.png  256x128  - dialogue stela: winged sun-disk lintel,
                                  hieroglyph pilasters, recessed papyrus field.
  ending_panel.png    250x200  - victory temple stela: bigger winged disk,
                                  lotus columns, hieroglyph friezes, gold frame.

Both share ONE palette + motif set (winged sun disk, glyphs, gold trim, Nile
lapis/turquoise inlay) so the quest reads as a single hand.  Also writes
<name>_preview.png (4x nearest-scaled) for quick offline eyeballing.

No Pillow / ImageMagick (not installed) - just a tiny PNG writer.

Run:   python3 tools/make_egypt_ui.py assets/generated/egypt_ui
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
            int(a[2] + (b[2] - a[2]) * t), 255)

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
OUTLINE = hx("#2c1c0e")
OUTLN2  = hx("#46301a")
SHADOW  = hx("#0e070330")  # soft drop shadow (alpha)

SAND_HI = hx("#f1d8a2")
SAND    = hx("#d6a55c")
SAND_DK = hx("#a9763c")
SAND_SH = hx("#7c5128")
SAND_DP = hx("#583719")

PAP_HI  = hx("#f8ead0")
PAP     = hx("#ecd5a6")
PAP_SH  = hx("#cdaa72")

GOLD_HI = hx("#ffeaa8")
GOLD    = hx("#f3c64c")
GOLD_MD = hx("#d39a2c")
GOLD_DK = hx("#9a6c1d")

LAP_HI  = hx("#5bcaea")
LAP     = hx("#2b7fb6")
LAP_DK  = hx("#1c5180")

TURQ    = hx("#37b29a")
TURQ_DK = hx("#1f7d6c")

RED     = hx("#c0392b")
RED_HI  = hx("#e26a4f")
RED_DK  = hx("#8a2417")

BLACK   = hx("#241208")


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

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y * self.w + x]
        return TRANS

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
def drop_shadow(cv, x0, y0, x1, y1, dx=3, dy=4, r=3):
    """Soft rounded drop shadow behind a panel."""
    for layer in range(r, 0, -1):
        a = int(SHADOW[3] * (1.0 - (layer - 1) / float(r)))
        col = (SHADOW[0], SHADOW[1], SHADOW[2], a)
        cv.rect(x0 + dx - layer + r, y0 + dy - layer + r,
                x1 + dx + layer - r, y1 + dy + layer - r, col)


def stone_face(cv, x0, y0, x1, y1):
    """Sandstone fill with a top-lit vertical gradient + sparse carved speckle."""
    h = max(1, y1 - y0)
    for y in range(y0, y1 + 1):
        t = (y - y0) / float(h)
        base = lerp(SAND_HI, SAND_SH, min(1.0, t * 1.05))
        for x in range(x0, x1 + 1):
            col = base
            n = nhash(x, y, 3) % 31
            if n == 0:
                col = shade(col, 0.90)
            elif n == 1:
                col = shade(col, 1.05)
            cv.put(x, y, col)


def carved_block(cv, x0, y0, x1, y1, shadow=True):
    """Outlined sandstone block with a raised top-left bevel. Returns inner rect."""
    if shadow:
        drop_shadow(cv, x0, y0, x1, y1)
    cv.rect(x0, y0, x1, y1, OUTLINE)            # 1px hard outline
    stone_face(cv, x0 + 1, y0 + 1, x1 - 1, y1 - 1)
    # raised bevel: light top/left, shadow bottom/right
    cv.hline(x0 + 1, x1 - 1, y0 + 1, SAND_HI)
    cv.vline(x0 + 1, y0 + 1, y1 - 1, SAND_HI)
    cv.hline(x0 + 1, x1 - 1, y1 - 1, SAND_DP)
    cv.vline(x1 - 1, y0 + 1, y1 - 1, SAND_DP)
    cv.hline(x0 + 2, x1 - 2, y1 - 2, SAND_SH)
    cv.vline(x1 - 2, y0 + 2, y1 - 2, SAND_SH)
    return (x0 + 2, y0 + 2, x1 - 2, y1 - 2)


def gold_frame(cv, x0, y0, x1, y1):
    """A beveled gold band tracing a rectangle (outer dark, core bright)."""
    cv.border(x0, y0, x1, y1, GOLD_DK)
    cv.border(x0 + 1, y0 + 1, x1 - 1, y1 - 1, GOLD)
    # top/left catch the light
    cv.hline(x0 + 1, x1 - 1, y0 + 1, GOLD_HI)
    cv.vline(x0 + 1, y0 + 1, y1 - 1, GOLD_HI)
    cv.border(x0 + 2, y0 + 2, x1 - 2, y1 - 2, GOLD_MD)


def recessed_field(cv, x0, y0, x1, y1):
    """Sunken papyrus-coloured panel that reads as cut into the stone."""
    cv.rect(x0, y0, x1, y1, PAP)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if nhash(x, y, 11) % 47 == 0:
                cv.put(x, y, PAP_HI)
            elif nhash(x, y, 17) % 59 == 0:
                cv.put(x, y, PAP_SH)
    # incised walls: shadow on top/left, light on bottom/right
    cv.hline(x0, x1, y0, PAP_SH); cv.vline(x0, y0, y1, PAP_SH)
    cv.hline(x0, x1, y0 - 1, OUTLN2); cv.vline(x0 - 1, y0, y1, OUTLN2)
    cv.hline(x0, x1, y1, PAP_HI); cv.vline(x1, y0, y1, PAP_HI)


def sun_disk(cv, cx, cy, r):
    """Red solar disk (Ra) inside a gold rim with a top-left glint."""
    rr = r * r
    inner = (r - 2) * (r - 2)
    for y in range(-r - 1, r + 2):
        for x in range(-r - 1, r + 2):
            d = x * x + y * y
            if d <= rr:
                if d <= inner:
                    col = RED_HI if (x < -1 and y < -1) else RED
                else:
                    col = GOLD_HI if (x < 0 and y < 0) else GOLD
                cv.put(cx + x, cy + y, col)
            elif d <= (r + 1) * (r + 1):
                cv.put(cx + x, cy + y, OUTLINE)


def winged_disk(cv, cx, cy, span, r):
    """Iconic winged sun disk: a solar disk flanked by three tiers of tapering,
    scalloped feathers that sweep downward toward the wingtips."""
    tiers = [(GOLD_HI, 7), (GOLD, 6), (LAP, 5)]   # (colour, base feather length)
    for side in (-1, 1):
        for tier, (col, blen) in enumerate(tiers):
            x_start = r
            x_end = span - tier * 5               # upper tier = longest flight feathers
            seg = float(max(1, x_end - x_start))
            y_base = cy - 4 + tier * 3
            for k in range(x_start, x_end + 1):
                p = (k - x_start) / seg
                flen = max(2, int(round((blen - (k % 3)) * (1.0 - 0.45 * p))))  # scallop + taper
                yb = y_base + int(round(p * 5))   # wing droops toward the tip
                x = cx + side * k
                c = col if (k % 2 == 0) else shade(col, 0.80)
                cv.put(x, yb - 1, OUTLINE)
                cv.vline(x, yb, yb + flen, c)
                cv.put(x, yb + flen + 1, OUTLINE)
    sun_disk(cv, cx, cy, r)


# ----- hieroglyph stamps (# = inked).  Stamped with an auto dark outline. ------
GLYPHS = {
    "ankh": [".###.",
             "#...#",
             "#...#",
             ".###.",
             "#####",
             "..#..",
             "..#.."],
    "eye":  [".#####.",
             "##...##",
             "#..#..#",
             "##...##",
             "..###..",
             ".#...#."],
    "sun":  [".###.",
             "#####",
             "#####",
             "#####",
             ".###."],
    "wave": ["##..##",
             "..##..",
             "##..##"],
    "reed": ["..#..",
             ".###.",
             "..#..",
             "..#..",
             "..#..",
             "..#..",
             ".###."],
    "scarab": ["..#..",
               "#.#.#",
               ".###.",
               "#####",
               ".###.",
               "#.#.#"],
    "feather": ["..#..",
                ".##..",
                ".###.",
                ".###.",
                "..##.",
                "..#..",
                "..#.."],
}

def stamp(cv, gx, gy, key, col, outline=BLACK):
    bmp = GLYPHS[key]
    on = set()
    for j, row in enumerate(bmp):
        for i, ch in enumerate(row):
            if ch == '#':
                on.add((i, j))
    for (i, j) in on:                            # outline first (dilate)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if (i + dx, j + dy) not in on:
                    cv.put(gx + i + dx, gy + j + dy, outline)
    for (i, j) in on:                            # then inked fill on top
        cv.put(gx + i, gy + j, col)

def glyph_w(key):
    return len(GLYPHS[key][0])
def glyph_h(key):
    return len(GLYPHS[key])


def recessed_band(cv, x0, y0, x1, y1, vertical=False):
    """Sunken lapis-trimmed channel that holds inlaid glyphs."""
    cv.rect(x0, y0, x1, y1, SAND_DK)
    cv.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, SAND_SH)
    cv.hline(x0, x1, y0, OUTLN2); cv.vline(x0, y0, y1, OUTLN2)
    cv.hline(x0, x1, y1, SAND_HI); cv.vline(x1, y0, y1, SAND_HI)


def glyph_strip(cv, x0, y0, x1, y1, keys, vertical, cols=(LAP_HI, TURQ, GOLD, RED_HI)):
    """Lay a row/column of inlaid glyphs, gold-divided, inside a recessed band."""
    recessed_band(cv, x0, y0, x1, y1, vertical)
    ci = 0
    if vertical:
        cy = y0 + 3
        idx = 0
        while True:
            k = keys[idx % len(keys)]
            gh = glyph_h(k); gw = glyph_w(k)
            if cy + gh > y1 - 2:
                break
            gx = (x0 + x1) // 2 - gw // 2
            stamp(cv, gx, cy, k, cols[ci % len(cols)])
            ci += 1; idx += 1
            cy += gh + 3
            if cy < y1 - 4:
                cv.hline(x0 + 2, x1 - 2, cy - 2, GOLD_MD)
    else:
        cx = x0 + 3
        idx = 0
        while True:
            k = keys[idx % len(keys)]
            gw = glyph_w(k); gh = glyph_h(k)
            if cx + gw > x1 - 2:
                break
            gy = (y0 + y1) // 2 - gh // 2
            stamp(cv, cx, gy, k, cols[ci % len(cols)])
            ci += 1; idx += 1
            cx += gw + 4
            if cx < x1 - 5:
                cv.vline(cx - 2, y0 + 2, y1 - 2, GOLD_MD)


def lotus_column(cv, x0, x1, y0, y1):
    """Polychrome lotus column: flared capital, banded shaft, splayed base."""
    cw = x1 - x0
    cap_h = 9
    base_h = 7
    sx0, sx1 = x0 + 1, x1 - 1
    sy0, sy1 = y0 + cap_h, y1 - base_h
    # shaft
    cv.rect(sx0, sy0, sx1, sy1, SAND)
    cv.vline(sx0, sy0, sy1, SAND_HI)
    cv.vline(sx1, sy0, sy1, SAND_DP)
    cv.vline(x0, y0, y1, OUTLINE); cv.vline(x1, y0, y1, OUTLINE)
    for x in range(sx0 + 1, sx1, 2):             # vertical flutes
        cv.vline(x, sy0 + 1, sy1 - 1, shade(SAND, 0.92))
    # painted rings down the shaft (lapis / gold)
    ry = sy0 + 3
    band_cols = [LAP, GOLD, TURQ, GOLD, RED]
    bi = 0
    while ry < sy1 - 3:
        cv.hline(sx0, sx1, ry, band_cols[bi % len(band_cols)])
        cv.hline(sx0, sx1, ry + 1, shade(band_cols[bi % len(band_cols)], 0.7))
        cv.put(sx0, ry, OUTLN2); cv.put(sx1, ry + 1, OUTLN2)
        bi += 1; ry += 11
    # lotus/papyrus capital (bell that flares open toward the top)
    cxm = (x0 + x1) // 2
    for j in range(cap_h):
        t = j / float(cap_h - 1)
        half = int(cw / 2 * (0.55 + 0.45 * (1 - t)))
        col = LAP if j <= 1 else GOLD            # lapis crown, gold bell
        cv.hline(cxm - half, cxm + half, y0 + j, col)
        cv.put(cxm - half, y0 + j, OUTLINE); cv.put(cxm + half, y0 + j, OUTLINE)
    # vertical ribs on the bell
    for rx in (cxm - cw // 3, cxm, cxm + cw // 3):
        cv.vline(rx, y0 + 2, y0 + cap_h - 2, GOLD_DK)
    cv.hline(x0, x1, y0, OUTLINE)
    cv.hline(cxm - cw // 2, cxm + cw // 2, y0 + cap_h - 1, GOLD_HI)
    # base (mirror flare)
    for j in range(base_h):
        t = j / float(base_h - 1)
        half = int(cw / 2 * (0.55 + 0.45 * t))
        col = lerp(SAND_DK, SAND_SH, t)
        yy = y1 - base_h + 1 + j
        cv.hline(cxm - half, cxm + half, yy, col)
        cv.put(cxm - half, yy, OUTLINE); cv.put(cxm + half, yy, OUTLINE)
    cv.hline(x0, x1, y1, OUTLINE)


# ----------------------------------------------------------------- panels
def build_narrator():
    W, H = 256, 128
    cv = C(W, H)
    x0, y0, x1, y1 = 4, 3, 251, 121
    ix0, iy0, ix1, iy1 = carved_block(cv, x0, y0, x1, y1)

    # top lintel with the winged sun disk
    lint_b = iy0 + 30
    cv.hline(ix0, ix1, lint_b, GOLD_DK)
    cv.hline(ix0, ix1, lint_b + 1, GOLD)
    cv.hline(ix0, ix1, lint_b + 2, GOLD_HI)
    winged_disk(cv, (ix0 + ix1) // 2, iy0 + 14, 96, 8)

    # hieroglyph pilasters down each side
    pil_w = 16
    glyph_strip(cv, ix0, lint_b + 4, ix0 + pil_w, iy1, ["ankh", "eye", "wave", "sun"], True)
    glyph_strip(cv, ix1 - pil_w, lint_b + 4, ix1, iy1, ["sun", "wave", "eye", "ankh"], True)

    # recessed papyrus inscription field (where the dialogue text is drawn)
    fx0, fy0, fx1, fy1 = ix0 + pil_w + 4, lint_b + 5, ix1 - pil_w - 4, iy1 - 1
    gold_frame(cv, fx0, fy0, fx1, fy1)
    recessed_field(cv, fx0 + 4, fy0 + 4, fx1 - 4, fy1 - 4)
    return W, H, cv


def build_ending():
    W, H = 250, 200
    cv = C(W, H)
    x0, y0, x1, y1 = 3, 3, 246, 196
    ix0, iy0, ix1, iy1 = carved_block(cv, x0, y0, x1, y1)

    # lotus columns frame the sides
    col_w = 16
    lotus_column(cv, ix0 + 1, ix0 + 1 + col_w, iy0 + 2, iy1 - 1)
    lotus_column(cv, ix1 - 1 - col_w, ix1 - 1, iy0 + 2, iy1 - 1)

    inner_l = ix0 + col_w + 5
    inner_r = ix1 - col_w - 5

    # top lintel: big winged sun disk
    lint_b = iy0 + 30
    cv.hline(inner_l, inner_r, lint_b, GOLD_DK)
    cv.hline(inner_l, inner_r, lint_b + 1, GOLD_HI)
    winged_disk(cv, (inner_l + inner_r) // 2, iy0 + 14, 78, 9)

    # bottom hieroglyph frieze
    frieze_t = iy1 - 17
    cv.hline(inner_l, inner_r, frieze_t - 1, GOLD_HI)
    glyph_strip(cv, inner_l, frieze_t, inner_r, iy1 - 1,
                ["ankh", "sun", "feather", "eye", "scarab"], False)

    # central recessed field (QUEST COMPLETE / stars / message render over this)
    fx0, fy0, fx1, fy1 = inner_l, lint_b + 4, inner_r, frieze_t - 3
    gold_frame(cv, fx0, fy0, fx1, fy1)
    recessed_field(cv, fx0 + 3, fy0 + 3, fx1 - 3, fy1 - 3)
    return W, H, cv


# ----------------------------------------------------------------- output
def save(out, name, w, h, cv, scale=4):
    write_png(os.path.join(out, name + ".png"), w, h, cv.px)
    # nearest-neighbour preview written to a temp dir (NOT the game asset folder,
    # so it never gets imported) for quick offline eyeballing.
    pw, ph = w * scale, h * scale
    big = [TRANS] * (pw * ph)
    for y in range(ph):
        for x in range(pw):
            big[y * pw + x] = cv.px[(y // scale) * w + (x // scale)]
    prev = os.path.join(tempfile.gettempdir(), name + "_preview.png")
    write_png(prev, pw, ph, big)
    print("  preview:", prev)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/generated/egypt_ui"
    os.makedirs(out, exist_ok=True)
    w, h, cv = build_narrator()
    save(out, "narrator_panel", w, h, cv)
    w, h, cv = build_ending()
    save(out, "ending_panel", w, h, cv)
    print("Wrote Egypt UI panels (+previews) to", out)


if __name__ == "__main__":
    main()
