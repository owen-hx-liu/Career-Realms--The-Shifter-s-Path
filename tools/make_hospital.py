#!/usr/bin/env python3
"""Dependency-free pixel-art generator for the HOSPITAL WARD (world_3.tscn).

Writes RGBA PNGs directly (no Pillow), in the same beveled / dark-outline
house style as tools/make_nanobot.py and tools/make_immune.py. Theme: a clean
clinical surface -- cool teal/cyan medical tech with warm gold trim and crisp
white, on a near-black outline. This art dresses the *presentation* layer of
the ward (dialogue panel, name plate, interaction prompt, location banner) so
it matches the remastered NANOBOT SURGEON minigame it leads into.

Generates  -> assets/generated/hospital/
  9-slice frames : frame_panel, nameplate, prompt_box, banner_frame
  ui sprites     : key_e, arrow, cross, portrait_doc

Run:  python3 tools/make_hospital.py assets/generated/hospital
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


# ===================================================== theme palette ========
OUTLINE = hx("#0a1316")          # universal near-black outline (cool)
PANEL   = hx("#10242b")          # deep slate-teal panel body
PANEL_DK= hx("#0a181d")
PANEL_HI= hx("#1b3a44")
TEAL    = hx("#37b8c4")          # primary cyan rim
TEAL_HI = hx("#8ff0f6")
TEAL_DK = hx("#1d6b75")
GOLD    = hx("#e7c356")          # warm trim accent
GOLD_HI = hx("#ffe79a")
GOLD_DK = hx("#9c7c2c")
CREAM   = hx("#eef6f5")
STEEL   = hx("#c4d2d8")
STEEL_DK= hx("#7d8e96")
SKIN    = hx("#e7b48c")
SKIN_DK = hx("#c98c63")
SCRUB   = hx("#2f9aa6")
SCRUB_DK= hx("#1d6f79")
SCRUB_HI= hx("#5fc3cd")
MED_RED = hx("#e23b4d")


# ============================================================ 9-SLICE FRAMES =
def _bevel_frame(S, fill, band, edge, hi, bevel=3, corner=0):
    """Beveled 9-slice: dark outer edge, colored border band, inner fill, a
    bright top/left highlight. Optional rounded corners (clip to a radius)."""
    c = C(S, S)
    c.rect(0, 0, S, S, fill)
    # bright inner highlight (top + left), drawn first so the band sits over it
    for x in range(1 + bevel, S - 1 - bevel):
        c.set(x, 1 + bevel, hi)
    for y in range(1 + bevel, S - 1 - bevel):
        c.set(1 + bevel, y, shade(hi, 0.78))
    # colored border band
    for t in range(1, 1 + bevel):
        for x in range(t, S - t):
            c.set(x, t, band); c.set(x, S - 1 - t, shade(band, 0.7))
        for y in range(t, S - t):
            c.set(t, y, band); c.set(S - 1 - t, y, shade(band, 0.7))
    # outer edge
    for x in range(S):
        c.set(x, 0, edge); c.set(x, S - 1, edge)
    for y in range(S):
        c.set(0, y, edge); c.set(S - 1, y, edge)
    if corner > 0:
        _round_corners(c, corner, edge)
    return S, S, c.px


def _round_corners(c, r, edge):
    """Carve transparent rounded corners and re-edge them, in-place."""
    S = c.w
    for (cx, cy, sx, sy) in ((r, r, -1, -1), (S - 1 - r, r, 1, -1),
                             (r, S - 1 - r, -1, 1), (S - 1 - r, S - 1 - r, 1, 1)):
        for y in range(r + 1):
            for x in range(r + 1):
                px, py = cx + sx * x, cy + sy * y
                d = math.hypot(x, y)
                if d > r + 0.3:
                    c.px[py * S + px] = (0, 0, 0, 0)
                elif d > r - 0.9:
                    c.px[py * S + px] = edge


def frame_panel():
    # main dialogue panel: slate body, cyan rim, gold inner highlight line
    S = 34; c = C(S, S)
    c.rect(0, 0, S, S, PANEL)
    # subtle vertical body gradient
    for y in range(1, S - 1):
        f = y / S
        for x in range(1, S - 1):
            c.set(x, y, mix(PANEL_HI, PANEL_DK, f))
    # gold hairline just inside the rim (the "premium" read)
    for x in range(4, S - 4):
        c.set(x, 4, GOLD); c.set(x, S - 5, GOLD_DK)
    for y in range(4, S - 4):
        c.set(4, y, GOLD); c.set(S - 5, y, GOLD_DK)
    # cyan border band
    for t in (1, 2, 3):
        col = TEAL if t == 2 else (TEAL_HI if t == 1 else TEAL_DK)
        for x in range(t, S - t):
            c.set(x, t, col); c.set(x, S - 1 - t, shade(col, 0.78))
        for y in range(t, S - t):
            c.set(t, y, col); c.set(S - 1 - t, y, shade(col, 0.78))
    for x in range(S):
        c.set(x, 0, OUTLINE); c.set(x, S - 1, OUTLINE)
    for y in range(S):
        c.set(0, y, OUTLINE); c.set(S - 1, y, OUTLINE)
    return S, S, c.px


def nameplate():
    # gold-trimmed dark plate for the speaker name
    return _bevel_frame(20, hx("#160f06"), GOLD, OUTLINE, GOLD_HI, bevel=2)


def prompt_box():
    # rounded dark pill for the floating prompt + the continue chip
    S = 22
    out = _bevel_frame(S, hx("#0c1c22"), TEAL, OUTLINE, TEAL_HI, bevel=2, corner=7)
    return out


def banner_frame():
    # wide title-card frame: dark with double gold rule
    S = 28; c = C(S, S)
    c.rect(0, 0, S, S, hx("#0c1a20"))
    for x in range(S):
        c.set(x, 0, OUTLINE); c.set(x, S - 1, OUTLINE)
    for y in range(S):
        c.set(0, y, OUTLINE); c.set(S - 1, y, OUTLINE)
    for x in range(1, S - 1):
        c.set(x, 1, GOLD); c.set(x, 2, GOLD_DK)
        c.set(x, S - 2, GOLD_DK); c.set(x, S - 3, shade(GOLD_DK, 0.8))
        c.set(x, 4, TEAL_DK)
    for y in range(1, S - 1):
        c.set(1, y, GOLD); c.set(2, y, GOLD_DK)
        c.set(S - 2, y, GOLD_DK)
    return S, S, c.px


# ============================================================ UI SPRITES =====
def key_e():
    """18x18 keycap engraved with 'E'."""
    S = 18; c = C(S, S)
    body = hx("#dfe7ea"); top = hx("#f6fafb"); bot = hx("#a3b0b6"); edge = hx("#11181c")
    # keycap plate (slightly rounded)
    c.rect(2, 2, S - 4, S - 4, body)
    for x in range(3, S - 3):
        c.set(x, 2, top); c.set(x, 3, hx("#ecf2f4"))
        c.set(x, S - 3, bot)
    for y in range(3, S - 3):
        c.set(2, y, hx("#eef4f5")); c.set(S - 3, y, hx("#b6c2c7"))
    # rounded corners
    for (cx, cy) in ((2, 2), (S - 3, 2), (2, S - 3), (S - 3, S - 3)):
        c.set(cx, cy, (0, 0, 0, 0))
    outline(c, edge)
    # engraved 'E'
    ink = hx("#27323a")
    c.rect(6, 5, 2, 9, ink)       # stem
    c.rect(6, 5, 6, 2, ink)       # top bar
    c.rect(6, 8, 5, 2, ink)       # mid bar
    c.rect(6, 12, 6, 2, ink)      # bottom bar
    # tiny highlight on the engraving top-left for depth
    c.set(6, 5, hx("#3c4a54"))
    return S, S, c.px


def arrow():
    """10x10 gold 'continue' triangle pointing right."""
    S = 10; c = C(S, S)
    for x in range(2, 8):
        half = (8 - x)
        for y in range(5 - half, 5 + half + 1):
            c.set(x, y, GOLD if x < 6 else GOLD_HI)
    outline(c, OUTLINE)
    return S, S, c.px


def cross():
    """14x14 medical emblem: white rounded tile, red cross, gold ring."""
    S = 14; c = C(S, S)
    c.disc(S / 2 - 0.5, S / 2 - 0.5, 6.4, GOLD_DK)
    c.disc(S / 2 - 0.5, S / 2 - 0.5, 5.7, CREAM)
    # red plus
    c.rect(6, 3, 2, 8, MED_RED)
    c.rect(3, 6, 8, 2, MED_RED)
    c.set(6, 3, hx("#f26072"))
    c.set(3, 6, hx("#f26072"))
    outline(c, OUTLINE)
    return S, S, c.px


def portrait_doc():
    """48x48 framed bust of a friendly surgeon (cap + mask + stethoscope)."""
    S = 48; c = C(S, S)
    cx = S / 2 - 0.5
    # soft teal studio backdrop
    for y in range(S):
        for x in range(S):
            d = math.hypot(x - cx, y - 20) / 30.0
            c.set(x, y, mix(hx("#16323a"), hx("#0c1f25"), min(1.0, d)))
    # shoulders / scrubs
    for y in range(34, S):
        f = (y - 34) / float(S - 34)
        half = 12 + 11 * f
        for x in range(int(cx - half), int(cx + half) + 1):
            d = (x - cx)
            col = SCRUB
            if d < -half * 0.5: col = SCRUB_HI
            elif d > half * 0.45: col = SCRUB_DK
            c.set(x, y, col)
    # collar V + a stethoscope tube around the neck
    c.line(cx - 5, 35, cx, 40, SCRUB_DK, 1.1)
    c.line(cx + 5, 35, cx, 40, SCRUB_DK, 1.1)
    for s in (-1, 1):
        c.line(cx + s * 6, 33, cx + s * 9, 44, hx("#2b3a42"), 1.2)
    c.disc(cx + 9, 45, 2.2, STEEL); c.disc(cx + 9, 45, 1.1, STEEL_DK)
    # neck
    c.rect(cx - 3, 30, 7, 6, SKIN_DK)
    c.rect(cx - 3, 30, 7, 3, SKIN)
    # head
    c.ellipse(cx, 22, 9.5, 10.5, SKIN)
    # shading on right of face
    for y in range(12, 33):
        for x in range(int(cx), int(cx + 10)):
            if ((x - cx) / 9.5) ** 2 + ((y - 22) / 10.5) ** 2 <= 1.0 and (x - cx) > 4:
                c.set(x, y, SKIN_DK)
    # surgical cap (teal) over the crown
    for y in range(11, 23):
        for x in range(int(cx - 11), int(cx + 11)):
            dx = (x - cx) / 10.5; dy = (y - 20) / 11.0
            if dx * dx + dy * dy <= 1.0 and y < 21:
                col = SCRUB
                if y < 14: col = SCRUB_HI
                c.set(x, y, col)
    c.rect(cx - 11, 20, 22, 2, SCRUB_DK)   # cap band
    # tiny gold cross on the cap
    c.set(cx, 15, GOLD_HI); c.set(cx, 16, GOLD); c.set(cx - 1, 16, GOLD); c.set(cx + 1, 16, GOLD)
    # eyes (above the mask)
    for s in (-1, 1):
        c.disc(cx + s * 3.4, 22, 1.5, hx("#23303a"))
        c.set(cx + s * 3.4 - 0.5, 21.5, TEAL_HI)
        # brow
        c.line(cx + s * 1.8, 19.5, cx + s * 5, 19.5, SKIN_DK, 0.6)
    # surgical mask over nose + mouth
    for y in range(25, 33):
        half = 7.5 - abs(y - 28) * 0.35
        for x in range(int(cx - half), int(cx + half) + 1):
            col = CREAM if (x - cx) < 2 else hx("#cdd9d8")
            c.set(x, y, col)
    c.line(cx - 7, 25, cx - 11, 23, hx("#d7e2e1"), 0.8)   # ear straps
    c.line(cx + 7, 25, cx + 11, 23, hx("#d7e2e1"), 0.8)
    for yy in (27, 29, 31):                                 # mask pleats
        c.line(cx - 6, yy, cx + 6, yy, hx("#b7c5c4"), 0.5)
    outline(c, OUTLINE)
    return S, S, c.px


# ================================================================== MAIN =====
def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/generated/hospital"
    os.makedirs(out, exist_ok=True)

    def w(name, tup):
        write_png(os.path.join(out, name + ".png"), *tup)

    w("frame_panel",  frame_panel())
    w("nameplate",    nameplate())
    w("prompt_box",   prompt_box())
    w("banner_frame", banner_frame())
    w("key_e",        key_e())
    w("arrow",        arrow())
    w("cross",        cross())
    w("portrait_doc", portrait_doc())
    print("wrote hospital art ->", out)


if __name__ == "__main__":
    main()
