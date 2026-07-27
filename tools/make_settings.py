#!/usr/bin/env python3
"""Dependency-free pixel-art generator for the global SETTINGS / accessibility menu.

Writes RGBA PNGs directly (no Pillow). One cohesive dark-navy / teal / gold
"arcane control panel" palette that matches the rest of the game (same bevel +
dark-outline house style as tools/make_immune.py and tools/make_ending.py).

Generates 9-slice UI frames, a custom themed slider (track / fill / grabber),
animated icons (gear, sun, music note), sparkle + glow particles, a button and
a soft backdrop vignette.

Run:  python3 tools/make_settings.py assets/generated/settings
Then: Godot --headless --path . --import   (so the engine imports the PNGs)
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
    f = max(0.0, min(1.0, f))
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


def rr_dist(x, y, x0, y0, x1, y1):
    """Distance from (x,y) to the axis-aligned box [x0,x1]x[y0,y1] (0 inside)."""
    px = min(max(x, x0), x1)
    py = min(max(y, y0), y1)
    return math.hypot(x - px, y - py)


# ---- shared palette ----
OUTLINE = hx("#0c141b")          # universal dark outline
INK = hx("#06101a")
NAVY = hx("#13212d")
NAVY_HI = hx("#1d3340")
NAVY_LO = hx("#0c1a25")
TEAL = hx("#356b86")
TEAL_HI = hx("#5aa6c4")
TEAL_LO = hx("#23485c")
GOLD = hx("#e0bf52")
GOLD_HI = hx("#f6e29a")
GOLD_LO = hx("#9c7c28")
CYAN = hx("#46c9e6")
CYAN_HI = hx("#9ef0ff")
CYAN_LO = hx("#2a8aa6")


# ============================================================ UI FRAMES =====
def panel():
    """Main window: flat dark-navy fill, dark outline, teal border band, gold
    inner rule, top/left highlight, and gold corner rivets. 9-slice margin=16."""
    S = 56
    c = C(S, S)
    c.rect(0, 0, S, S, NAVY)
    # outer outline
    for x in range(S):
        c.set(x, 0, OUTLINE); c.set(x, S - 1, OUTLINE)
    for y in range(S):
        c.set(0, y, OUTLINE); c.set(S - 1, y, OUTLINE)
    # teal border band (rows 1-2)
    for x in range(1, S - 1):
        c.set(x, 1, TEAL_HI); c.set(x, 2, TEAL)
        c.set(x, S - 2, TEAL_LO); c.set(x, S - 3, TEAL)
    for y in range(1, S - 1):
        c.set(1, y, TEAL); c.set(2, y, TEAL)
        c.set(S - 2, y, TEAL_LO); c.set(S - 3, y, TEAL)
    # gold inner rule (row/col 4)
    for x in range(4, S - 4):
        c.set(x, 4, GOLD); c.set(x, S - 5, GOLD_LO)
    for y in range(4, S - 4):
        c.set(4, y, shade(GOLD, 0.92)); c.set(S - 5, y, GOLD_LO)
    # inner fill bevel
    for x in range(5, S - 5):
        c.set(x, 5, NAVY_HI); c.set(x, S - 6, NAVY_LO)
    for y in range(5, S - 5):
        c.set(5, y, shade(NAVY_HI, 0.92)); c.set(S - 6, y, NAVY_LO)
    # gold corner rivets (live inside the fixed 16px 9-slice corners)
    for (rx, ry) in [(8, 8), (S - 9, 8), (8, S - 9), (S - 9, S - 9)]:
        c.disc(rx, ry, 2.6, GOLD_LO)
        c.disc(rx, ry, 1.7, GOLD)
        c.set(rx - 1, ry - 1, GOLD_HI)
    return S, S, c.px


def banner():
    """Title plate: dark teal fill with a double gold rule. 9-slice margin=10."""
    S = 30
    c = C(S, S)
    c.rect(0, 0, S, S, hx("#102a3a"))
    for x in range(S):
        c.set(x, 0, OUTLINE); c.set(x, S - 1, OUTLINE)
    for y in range(S):
        c.set(0, y, OUTLINE); c.set(S - 1, y, OUTLINE)
    for x in range(1, S - 1):
        c.set(x, 1, GOLD); c.set(x, 2, GOLD_LO)
        c.set(x, S - 2, GOLD_LO); c.set(x, S - 3, shade(GOLD, 0.82))
    for y in range(1, S - 1):
        c.set(1, y, GOLD); c.set(2, y, GOLD_LO)
        c.set(S - 2, y, GOLD_LO); c.set(S - 3, y, shade(GOLD, 0.82))
    for x in range(3, S - 3):
        c.set(x, 4, hx("#1c4860"))      # teal sheen line
    return S, S, c.px


def row():
    """Recessed control strip behind each slider row. 9-slice margin=8."""
    S = 20
    c = C(S, S)
    c.rect(0, 0, S, S, hx("#0c1a26"))
    for x in range(S):
        c.set(x, 0, INK); c.set(x, S - 1, hx("#21404f"))
    for y in range(S):
        c.set(0, y, INK); c.set(S - 1, y, hx("#21404f"))
    for x in range(1, S - 1):
        c.set(x, 1, hx("#091420"))
    for y in range(1, S - 1):
        c.set(1, y, hx("#091420"))
    return S, S, c.px


def button():
    """Near-white 9-slice so it tints cleanly via modulate_color. margin=6."""
    S = 22
    c = C(S, S)
    c.rect(0, 0, S, S, (226, 234, 232, 255))
    for x in range(S):
        c.set(x, 1, (255, 255, 255, 255)); c.set(x, 2, (244, 248, 246, 255))
        c.set(x, S - 2, (140, 150, 152, 255)); c.set(x, S - 3, (180, 190, 188, 255))
    for y in range(S):
        c.set(1, y, (250, 252, 250, 255)); c.set(S - 2, y, (158, 168, 166, 255))
    for x in range(S):
        c.set(x, 0, OUTLINE); c.set(x, S - 1, OUTLINE)
    for y in range(S):
        c.set(0, y, OUTLINE); c.set(S - 1, y, OUTLINE)
    return S, S, c.px


# ============================================================ SLIDER ========
def slider_track():
    """Visible recessed rail — a clear rounded line that shows the slider's FULL
    travel (its scope) even where it isn't filled. Steel-teal groove that reads
    plainly against the dark row, with a recessed top shadow, a bottom catch-light
    and a thin upper sheen, all wrapped in the universal dark outline. The 9-slice
    (margin=7) keeps the rounded end-caps crisp while the centre stretches."""
    W = H = 16
    c = C(W, H)
    cy = (H - 1) / 2.0
    cr = 5
    x0, x1 = cr, W - 1 - cr
    y0, y1 = cr, H - 1 - cr
    base = hx("#274a5d")                 # steel-teal rail body (clearly > row #0c1a26)
    topsh = hx("#15303f")                # recessed inner top shadow
    botlt = hx("#3a6c84")                # inner bottom catch-light
    sheen = hx("#52899f")                # thin sheen just under the top rim
    for y in range(H):
        for x in range(W):
            if rr_dist(x, y, x0, y0, x1, y1) <= cr:
                d = y - cy
                if d < -cr * 0.55:
                    col = topsh
                elif d < -cr * 0.18:
                    col = sheen
                elif d > cr * 0.45:
                    col = botlt
                else:
                    col = base
                c.set(x, y, col)
    outline(c, OUTLINE)
    return W, H, c.px


def slider_fill():
    """Bright cyan liquid fill, inset 1px so the dark groove frames it.
    9-slice margin=7."""
    W = H = 16
    c = C(W, H)
    cr = 4
    x0, x1 = 1 + cr, W - 2 - cr
    y0, y1 = 1 + cr, H - 2 - cr
    for y in range(H):
        for x in range(W):
            if rr_dist(x, y, x0, y0, x1, y1) <= cr:
                f = (y - 1) / float(H - 3)
                c.set(x, y, mix(CYAN_HI, CYAN_LO, f))
    # top highlight + bottom shade
    for x in range(W):
        for yy in range(H):
            if c.px[yy * W + x][3] > 0:
                c.set(x, yy, hx("#d4f7ff"))
                break
    outline(c, hx("#0a2a36"))
    return W, H, c.px


def grabber(highlight=False):
    """Round beveled control knob: gold ring, cyan gem, specular shine."""
    S = 22
    c = C(S, S)
    cx = cy = (S - 1) / 2.0
    body = CYAN if not highlight else hx("#6fe0f6")
    ring = GOLD if not highlight else GOLD_HI
    # gold ring
    c.disc(cx, cy, 10, shade(ring, 0.7))
    c.disc(cx, cy, 9, ring)
    c.disc(cx, cy, 8, shade(ring, 0.55))
    # cyan gem
    R = 7.4
    for y in range(S):
        for x in range(S):
            if (x - cx) ** 2 + (y - cy) ** 2 <= R * R:
                d = (x - cx) + (y - cy)
                col = body
                if d > R * 0.5:
                    col = shade(body, 0.66)
                elif d < -R * 0.55:
                    col = shade(body, 1.35)
                c.set(x, y, col)
    # specular shine
    c.disc(cx - 2.4, cy - 2.7, 2.1, hx("#e6fbff"))
    c.disc(cx - 3.0, cy - 3.2, 1.0, (255, 255, 255, 255))
    # gold ring top sparkle
    for a in range(190, 300, 10):
        ar = math.radians(a)
        c.set(cx + math.cos(ar) * 9.4, cy + math.sin(ar) * 9.4, GOLD_HI)
    outline(c, OUTLINE)
    return S, S, c.px


def grabber_glow():
    """Soft radial cyan glow that pulses behind the grabber (linear-filtered)."""
    S = 46
    c = C(S, S)
    cx = cy = (S - 1) / 2.0
    R = (S - 1) / 2.0
    for y in range(S):
        for x in range(S):
            d = math.hypot(x - cx, y - cy)
            if d <= R:
                a = int(170 * (1.0 - d / R) ** 2.2)
                if a > 0:
                    c.set(x, y, (120, 232, 255, a))
    return S, S, c.px


# ============================================================ ICONS =========
def icon_gear():
    """Cog with 8 teeth + center hole — rotates slowly in the title."""
    S = 28
    c = C(S, S)
    cx = cy = (S - 1) / 2.0
    R = 8.5
    teeth_out = R + 3.0
    for y in range(S):
        for x in range(S):
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy)
            ang = math.atan2(dy, dx) % (2 * math.pi)
            seg = int(ang / (2 * math.pi / 16))     # 16 sectors -> 8 teeth
            outer = teeth_out if seg % 2 == 0 else R
            if d <= outer:
                col = GOLD
                bev = dx + dy
                if bev > 3:
                    col = GOLD_LO
                elif bev < -4:
                    col = GOLD_HI
                c.set(x, y, col)
    # rim ring + center hole
    c.ring(cx, cy, R - 1.0, 1.0, shade(GOLD, 0.7))
    c.disc(cx, cy, 3.2, NAVY)
    c.disc(cx, cy, 2.2, INK)
    c.set(cx - 1, cy - 1, shade(NAVY, 1.4))
    outline(c, OUTLINE)
    return S, S, c.px


def icon_brightness():
    """Sun with 8 rays — gently pulses/rotates on the brightness row."""
    S = 30
    c = C(S, S)
    cx = cy = (S - 1) / 2.0
    core = hx("#ffe08a"); body = hx("#f4b942"); dark = hx("#c8821f")
    for i in range(8):
        a = i / 8.0 * 2 * math.pi
        c.line(cx + math.cos(a) * 8.5, cy + math.sin(a) * 8.5,
               cx + math.cos(a) * 13.0, cy + math.sin(a) * 13.0, body, 1.5)
    R = 7.0
    for y in range(S):
        for x in range(S):
            if (x - cx) ** 2 + (y - cy) ** 2 <= R * R:
                d = (x - cx) + (y - cy)
                col = body
                if d > 3:
                    col = dark
                elif d < -4:
                    col = core
                c.set(x, y, col)
    c.disc(cx - 2, cy - 2.4, 1.7, hx("#fff3cf"))
    outline(c, OUTLINE)
    return S, S, c.px


def icon_music():
    """Eighth note — bobs on the volume row."""
    S = 30
    c = C(S, S)
    body = hx("#5fd3ec"); dark = hx("#2a8aa6"); hi = hx("#bff0ff")
    # stem
    c.rect(16, 5, 2, 17, body)
    c.set(16, 5, hi)
    for y in range(5, 22):
        c.set(16, y, hi)
    # flag
    c.line(18, 5, 23, 9, body, 1.8)
    c.line(18, 9, 22, 12, body, 1.4)
    # note head (ellipse, bottom-left)
    hxp, hyp = 11.5, 21.5
    c.ellipse(hxp, hyp, 5.2, 4.0, body)
    c.ellipse(hxp + 1.3, hyp + 1.1, 3.0, 2.1, dark)
    c.ellipse(hxp - 1.5, hyp - 1.4, 1.8, 1.2, hi)
    outline(c, OUTLINE)
    return S, S, c.px


def sparkle():
    """4-point twinkle for burst + ambient drift (additive feel via alpha)."""
    S = 16
    c = C(S, S)
    cx = cy = (S - 1) / 2.0
    tip = hx("#bff0ff")
    L = 7
    for d in range(-L, L + 1):
        a = int(235 * (1 - abs(d) / float(L)) ** 1.3)
        if a > 0:
            c.set(cx + d, cy, (tip[0], tip[1], tip[2], a))
            c.set(cx, cy + d, (tip[0], tip[1], tip[2], a))
    # faint diagonals
    for d in range(-3, 4):
        a = int(120 * (1 - abs(d) / 3.0))
        if a > 0:
            c.set(cx + d, cy + d, (tip[0], tip[1], tip[2], a))
            c.set(cx + d, cy - d, (tip[0], tip[1], tip[2], a))
    c.disc(cx, cy, 2.0, (235, 250, 255, 255))
    c.disc(cx, cy, 1.0, (255, 255, 255, 255))
    return S, S, c.px


def vignette():
    """Soft dark radial vignette for the backdrop (linear-filtered, stretched)."""
    W, H = 256, 144
    c = C(W, H)
    cx, cy = (W - 1) / 2.0, (H - 1) / 2.0
    maxd = math.hypot(cx, cy)
    for y in range(H):
        for x in range(W):
            d = math.hypot(x - cx, y - cy) / maxd
            a = int(max(0.0, (d - 0.32) / 0.68) ** 1.4 * 200)
            if a > 0:
                c.set(x, y, (3, 7, 12, min(200, a)))
    return W, H, c.px


# ============================================================ MAIN ==========
ASSETS = {
    "panel": panel,
    "banner": banner,
    "row": row,
    "button": button,
    "slider_track": slider_track,
    "slider_fill": slider_fill,
    "grabber": lambda: grabber(False),
    "grabber_hi": lambda: grabber(True),
    "grabber_glow": grabber_glow,
    "icon_gear": icon_gear,
    "icon_brightness": icon_brightness,
    "icon_music": icon_music,
    "sparkle": sparkle,
    "vignette": vignette,
}


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/generated/settings"
    os.makedirs(out, exist_ok=True)
    for name, fn in ASSETS.items():
        write_png(os.path.join(out, name + ".png"), *fn())
    print("Wrote %d settings-menu assets to %s" % (len(ASSETS), out))


if __name__ == "__main__":
    main()
