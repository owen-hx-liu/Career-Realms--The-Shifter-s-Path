#!/usr/bin/env python3
"""Dependency-free pixel-art generator for the hub tutorial guide "Astra".

Astra is an original star-spirit mentor who introduces the player to the hub.
Writes RGBA PNGs directly (no Pillow), matching the look of tools/make_art.py.

Produces (into <out_dir>, default assets/generated/tutorial):
  astra_idle.png   - eyes open, gentle smile  (default frame)
  astra_talk.png   - eyes open, mouth open    (swapped while text types)
  astra_blink.png  - eyes closed, gentle smile (occasional idle blink)
  star_badge.png   - small glowing star (UI accent for headers/bullets)

Run:  python3 tools/make_guide.py [out_dir]
After running, import before the game can load them:
  ~/Downloads/Godot_mono.app/Contents/MacOS/Godot --headless --path . --import
"""
import sys, os, zlib, struct, math

# ---------------- tiny PNG writer (same format as make_art.py) ----------------
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

# ---------------- helpers ----------------
def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)

def blend(bg, fg):
    a = fg[3] / 255.0
    return (int(fg[0] * a + bg[0] * (1 - a)), int(fg[1] * a + bg[1] * (1 - a)),
            int(fg[2] * a + bg[2] * (1 - a)), max(bg[3], fg[3]))

class C:
    def __init__(self, w, h, bg=(0, 0, 0, 0)):
        self.w, self.h = w, h
        self.px = [bg] * (w * h)
    def get(self, x, y):
        return self.px[y * self.w + x]
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
    def rect(self, x0, y0, w, h, c):
        for y in range(int(y0), int(y0 + h)):
            for x in range(int(x0), int(x0 + w)):
                self.set(x, y, c)
    def hline(self, x0, x1, y, c):
        for x in range(int(x0), int(x1) + 1):
            self.set(x, y, c)

def poly_fill(c, pts, col):
    ys = [p[1] for p in pts]
    for y in range(int(min(ys)), int(max(ys)) + 1):
        xs = []
        n = len(pts)
        for i in range(n):
            x1, y1 = pts[i]
            x2, y2 = pts[(i + 1) % n]
            if (y1 <= y < y2) or (y2 <= y < y1):
                xs.append(x1 + (y - y1) * (x2 - x1) / (y2 - y1))
        xs.sort()
        for i in range(0, len(xs) - 1, 2):
            for x in range(int(math.ceil(xs[i])), int(math.floor(xs[i + 1])) + 1):
                c.set(x, y, col)

def star_pts(cx, cy, r_out, r_in, n=5, rot=-math.pi / 2):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rot + i * math.pi / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts

def draw_star(c, cx, cy, r_out, col, edge=None, glow=None):
    r_in = r_out * 0.42
    if glow:
        c.disc(cx, cy, r_out * 1.5, glow)
    if edge:
        poly_fill(c, star_pts(cx, cy, r_out + 1, r_in + 1), edge)
    poly_fill(c, star_pts(cx, cy, r_out, r_in), col)
    # tiny inner sparkle
    if r_out >= 5:
        c.set(cx, cy - r_out * 0.25, (255, 255, 255, 230))

def outline(c, col):
    """Add a 1px outline around every opaque (alpha>60) cluster, into transparent pixels."""
    w, h = c.w, c.h
    snap = list(c.px)
    for y in range(h):
        for x in range(w):
            if snap[y * w + x][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and snap[ny * w + nx][3] > 60:
                    c.px[y * w + x] = col
                    break

def blit(dst, src):
    """Blend src canvas over dst (same size)."""
    for i in range(len(src.px)):
        p = src.px[i]
        if p[3] == 0:
            continue
        x = i % src.w; y = i // src.w
        dst.set(x, y, p)

# ---------------- palette ----------------
OUTLINE = hx("#241c40")
ROBE    = hx("#3c3578"); ROBE_HI = hx("#5b54a8"); ROBE_SH = hx("#2a2356")
HOOD    = hx("#4a78c8"); HOOD_HI = hx("#82a8ec"); HOOD_SH = hx("#2f5198")
SKIN    = hx("#ffe2c2"); SKIN_SH = hx("#f0be94"); BLUSH   = (255, 150, 140, 170)
GOLD    = hx("#ffd24a"); GOLD_HI = hx("#fff0a8"); GOLD_SH = hx("#e0992a")
EYE     = hx("#2a2440")
AURA    = (255, 224, 150, 46)   # low alpha so it reads as a soft glow behind

# ---------------- the guide ----------------
W, H = 72, 96
CX = 36

def base_figure():
    """Everything except the eyes + mouth (those are per-expression)."""
    c = C(W, H)

    # --- robe / body: a soft bell shape ---
    # built from stacked horizontal spans for clean pixel edges
    body_top, body_bot = 54, 90
    for y in range(body_top, body_bot):
        t = (y - body_top) / float(body_bot - body_top)
        half = 9 + t * 17          # widens toward the hem
        c.hline(CX - half, CX + half, y, ROBE)
    # hem shadow + scalloped bottom
    for y in range(body_bot - 5, body_bot):
        t = (y - body_top) / float(body_bot - body_top)
        half = 9 + t * 17
        c.hline(CX - half, CX + half, y, ROBE_SH)
    # left-side lighting + right-side shade
    for y in range(body_top, body_bot):
        t = (y - body_top) / float(body_bot - body_top)
        half = 9 + t * 17
        c.hline(CX - half, CX - half + 4, y, ROBE_HI)
        c.hline(CX + half - 3, CX + half, y, ROBE_SH)
    # center robe seam
    for y in range(body_top + 3, body_bot - 2):
        c.set(CX, y, ROBE_SH)

    # --- gold trim: collar at the neckline + hem along the bottom ---
    for x in range(CX - 7, CX + 8):
        c.set(x, 53, GOLD); c.set(x, 54, GOLD_SH)
    c.set(CX - 7, 52, GOLD); c.set(CX + 7, 52, GOLD)
    for y in range(body_bot - 3, body_bot - 1):
        t = (y - body_top) / float(body_bot - body_top)
        half = 9 + t * 17
        c.hline(CX - half + 1, CX + half - 1, y, GOLD_SH)

    # --- arms: robe sleeves with little skin hands; right hand raised in a wave ---
    for (sx, sy, sr) in [(CX + 12, 58, 4), (CX + 16, 53, 4), (CX + 19, 49, 4)]:
        c.disc(sx, sy, sr, ROBE)
    c.disc(CX + 19, 49, 3, ROBE_HI)
    c.disc(CX + 19, 50, 2.2, GOLD)                 # cuff
    c.disc(CX + 21, 46, 3.4, SKIN)                 # waving hand
    c.set(CX + 21, 45, hx("#fff0dc"))
    for (sx, sy, sr) in [(CX - 12, 60, 4), (CX - 15, 64, 4), (CX - 18, 68, 4)]:
        c.disc(sx, sy, sr, ROBE)
    c.disc(CX - 18, 68, 3, ROBE_SH)
    c.disc(CX - 18, 69, 2.2, GOLD_SH)              # cuff
    c.disc(CX - 19, 72, 3.2, SKIN)                 # resting hand
    c.set(CX - 20, 71, hx("#fff0dc"))

    # --- chest star emblem ---
    draw_star(c, CX, 68, 5.5, GOLD, edge=GOLD_SH)
    c.set(CX, 66, GOLD_HI)

    # --- head ---
    c.disc(CX, 34, 16, SKIN)
    # cheek shading on the right
    for y in range(26, 46):
        c.set(CX + 13, y, SKIN_SH)
        c.set(CX + 12, y, SKIN_SH)
    c.disc(CX - 7, 30, 5, hx("#fff0dc"))   # soft brow highlight

    # --- hood: a starlit-blue cowl framing the face ---
    # outer hood arc
    for y in range(14, 40):
        dy = y - 30
        span = int(math.sqrt(max(0, 19 * 19 - dy * dy)))
        # only the upper crown + sides, leaving the face open
        if y < 26:
            c.hline(CX - span, CX + span, y, HOOD)
        else:
            c.hline(CX - span, CX - span + 6, y, HOOD)
            c.hline(CX + span - 6, CX + span, y, HOOD)
    # hood rim highlight + shade
    for y in range(15, 27):
        dy = y - 30
        span = int(math.sqrt(max(0, 19 * 19 - dy * dy)))
        c.hline(CX - span, CX - span + 3, y, HOOD_HI)
        c.hline(CX + span - 3, CX + span, y, HOOD_SH)
    # a little peak at the top of the hood
    poly_fill(c, [(CX - 6, 16), (CX + 6, 16), (CX, 6)], HOOD)
    poly_fill(c, [(CX - 6, 16), (CX - 1, 16), (CX, 8)], HOOD_HI)
    # sparkle stars on the hood
    draw_star(c, CX - 13, 20, 2.4, GOLD_HI)
    draw_star(c, CX + 11, 17, 2.0, GOLD_HI)

    # --- floating guiding star above the head ---
    draw_star(c, CX, 6, 6.5, GOLD, edge=GOLD_SH, glow=(255, 226, 150, 70))
    c.set(CX - 2, 4, GOLD_HI)

    outline(c, OUTLINE)

    # blush goes on AFTER outline so it stays soft (interior)
    c.disc(CX - 9, 38, 2.4, BLUSH)
    c.disc(CX + 9, 38, 2.4, BLUSH)
    return c

def with_face(eyes, mouth):
    fig = base_figure()
    ex_l, ex_r, ey = CX - 6, CX + 6, 34
    if eyes == "open":
        for ex in (ex_l, ex_r):
            fig.rect(ex - 1, ey - 2, 3, 5, EYE)
            fig.set(ex - 1, ey - 2, EYE); fig.set(ex + 1, ey - 2, EYE)
            fig.set(ex, ey - 1, (255, 255, 255, 255))   # glint
            fig.set(ex - 1, ey + 1, (120, 150, 230, 255))
    else:  # blink
        for ex in (ex_l, ex_r):
            fig.hline(ex - 2, ex + 1, ey + 1, EYE)
            fig.set(ex - 2, ey, EYE); fig.set(ex + 1, ey, EYE)

    my = 43
    if mouth == "smile":
        fig.set(CX - 2, my, EYE); fig.set(CX - 1, my + 1, EYE)
        fig.set(CX, my + 1, EYE); fig.set(CX + 1, my + 1, EYE); fig.set(CX + 2, my, EYE)
    else:  # open (talking)
        fig.rect(CX - 2, my, 5, 4, hx("#7a2c3a"))
        fig.rect(CX - 1, my + 2, 3, 2, hx("#d8607a"))   # tongue
        fig.set(CX - 2, my, EYE); fig.set(CX + 2, my, EYE)

    # composite the soft aura behind the finished figure
    out = C(W, H)
    out.disc(CX, 40, 30, AURA)
    out.disc(CX, 40, 22, AURA)
    out.disc(CX, 6, 12, (255, 226, 150, 40))
    blit(out, fig)
    return out

def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "assets/generated/tutorial"
    os.makedirs(out_dir, exist_ok=True)

    frames = {
        "astra_idle":  with_face("open",  "smile"),
        "astra_talk":  with_face("open",  "open"),
        "astra_blink": with_face("blink", "smile"),
    }
    for name, canv in frames.items():
        p = os.path.join(out_dir, name + ".png")
        write_png(p, canv.w, canv.h, canv.px)
        print("wrote", p)

    # small standalone glowing star badge for UI headers / bullets
    sb = C(24, 24)
    sb.disc(12, 12, 11, (255, 226, 150, 60))
    draw_star(sb, 12, 12, 9, GOLD, edge=GOLD_SH)
    sb.set(10, 9, GOLD_HI); sb.set(11, 8, (255, 255, 255, 240))
    outline(sb, OUTLINE)
    p = os.path.join(out_dir, "star_badge.png")
    write_png(p, sb.w, sb.h, sb.px)
    print("wrote", p)

if __name__ == "__main__":
    main()
