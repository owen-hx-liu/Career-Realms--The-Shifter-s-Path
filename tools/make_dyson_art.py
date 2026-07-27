#!/usr/bin/env python3
"""Dependency-free pixel-art generator for the DYSON SWARM quest.
Writes RGBA PNGs directly (no Pillow). Deep-space palette: navy + gold, with
nebula and starfield. Run:  python3 tools/make_dyson_art.py [out_dir]
Mirrors tools/make_art.py so the quest's UI chrome is cohesive pixel art.
"""
import sys, os, zlib, struct, math, random

# ---------------- tiny PNG writer ----------------
def write_png(path, w, h, px):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for (r, g, b, a) in px[y*w:(y+1)*w]:
            raw += bytes((r, g, b, a))
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t+d) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n"
                + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
                + chunk(b"IEND", b""))

# ---------------- canvas ----------------
class C:
    def __init__(self, w, h, bg=(0, 0, 0, 0)):
        self.w, self.h = w, h
        self.px = [bg]*(w*h)
    def set(self, x, y, c):
        x = int(x); y = int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            if len(c) == 3: c = (c[0], c[1], c[2], 255)
            self.px[y*self.w+x] = c if c[3] == 255 else blend(self.px[y*self.w+x], c)
    def disc(self, cx, cy, r, c):
        for y in range(int(cy-r)-1, int(cy+r)+2):
            for x in range(int(cx-r)-1, int(cx+r)+2):
                if (x-cx)**2+(y-cy)**2 <= r*r:
                    self.set(x, y, c)
    def ring(self, cx, cy, r, t, c):
        for y in range(int(cy-r)-1, int(cy+r)+2):
            for x in range(int(cx-r)-1, int(cx+r)+2):
                d2 = (x-cx)**2+(y-cy)**2
                if (r-t)**2 <= d2 <= r*r:
                    self.set(x, y, c)
    def rect(self, x0, y0, w, h, c):
        for y in range(int(y0), int(y0+h)):
            for x in range(int(x0), int(x0+w)):
                self.set(x, y, c)

def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)
def blend(bg, fg):
    a = fg[3]/255.0
    return (int(fg[0]*a+bg[0]*(1-a)), int(fg[1]*a+bg[1]*(1-a)),
            int(fg[2]*a+bg[2]*(1-a)), max(bg[3], fg[3]))
def shade(c, f):
    return (max(0, min(255, int(c[0]*f))), max(0, min(255, int(c[1]*f))),
            max(0, min(255, int(c[2]*f))), c[3] if len(c) == 4 else 255)
def outline(c, col):
    w, h = c.w, c.h
    snap = list(c.px)
    for y in range(h):
        for x in range(w):
            if snap[y*w+x][3] != 0:
                continue
            for dx, dy in ((1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)):
                nx, ny = x+dx, y+dy
                if 0 <= nx < w and 0 <= ny < h and snap[ny*w+nx][3] > 60:
                    c.px[y*w+x] = col
                    break

# =============================================================================
#  Background: deep space (nebula + starfield + dying-star glow + vignette)
# =============================================================================
def soft_blob(c, cx, cy, r, col, peak_a):
    # Smooth per-pixel radial cloud (no visible banding).
    r2 = r*r
    for y in range(int(cy-r), int(cy+r)+1):
        for x in range(int(cx-r), int(cx+r)+1):
            d2 = (x-cx)**2 + (y-cy)**2
            if d2 > r2:
                continue
            f = 1.0 - math.sqrt(d2)/r
            a = int(peak_a * f*f)
            if a > 0:
                c.set(x, y, (col[0], col[1], col[2], a))

def make_background(W=1280, H=720):
    c = C(W, H, hx("#05070f"))
    # 1) vertical base gradient (deep navy -> near black)
    top, bot = hx("#0b1124"), hx("#04060d")
    for y in range(H):
        f = y/float(H)
        col = (int(top[0]*(1-f)+bot[0]*f), int(top[1]*(1-f)+bot[1]*f),
               int(top[2]*(1-f)+bot[2]*f), 255)
        row = y*W
        for x in range(W):
            c.px[row+x] = col

    # 2) nebula clouds (seeded, painterly soft blobs)
    rnd = random.Random(20260611)
    palette = [hx("#3a2b63"), hx("#243a78"), hx("#1d5566"), hx("#5a2f63"), hx("#27406e")]
    for _ in range(22):
        bx = rnd.randint(0, W); by = rnd.randint(0, H)
        br = rnd.randint(90, 230); col = rnd.choice(palette)
        soft_blob(c, bx, by, br, col, rnd.randint(10, 24))
    # a faint diagonal "galactic band" of denser dust
    for _ in range(40):
        t = rnd.random()
        bx = int(W*0.1 + t*W*0.85 + rnd.randint(-40, 40))
        by = int(H*0.85 - t*H*0.7 + rnd.randint(-30, 30))
        soft_blob(c, bx, by, rnd.randint(40, 90), rnd.choice(palette), rnd.randint(8, 16))

    # 3) dying-star glow near the centre (where the sun sprite sits) -- smooth
    gx, gy = W//2, H//2
    GR = 280
    for y in range(gy-GR, gy+GR+1):
        for x in range(gx-GR, gx+GR+1):
            d = math.sqrt((x-gx)**2 + (y-gy)**2)
            if d > GR:
                continue
            f = 1.0 - d/GR
            # warm outer halo + hotter inner core, both smooth
            halo = int(34 * f*f)
            core = int(70 * max(0.0, (1.0 - d/110.0))**2) if d < 110 else 0
            if halo > 0:
                c.set(x, y, (255, 205, 120, halo))
            if core > 0:
                c.set(x, y, (255, 236, 184, core))

    # 4) starfield: many faint stars, fewer bright ones, a few coloured + sparkle
    star_cols = [(255,255,255), (210,224,255), (255,236,200), (200,255,240), (255,210,220)]
    for _ in range(900):
        x = rnd.randint(0, W-1); y = rnd.randint(0, H-1)
        b = rnd.choice([40, 55, 70, 90, 120])
        col = rnd.choice(star_cols)
        c.set(x, y, (col[0], col[1], col[2], b))
    for _ in range(120):                      # medium stars w/ tiny glow
        x = rnd.randint(1, W-2); y = rnd.randint(1, H-2)
        col = rnd.choice(star_cols)
        c.set(x, y, (col[0], col[1], col[2], 230))
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            c.set(x+dx, y+dy, (col[0], col[1], col[2], 70))
    for _ in range(16):                       # bright sparkle stars (+ shape)
        x = rnd.randint(6, W-7); y = rnd.randint(6, H-7)
        col = rnd.choice(star_cols)
        c.disc(x, y, 1.6, (col[0], col[1], col[2], 255))
        for d in range(1, 6):
            a = int(150*(1-d/6.0))
            c.set(x+d, y, (col[0], col[1], col[2], a)); c.set(x-d, y, (col[0], col[1], col[2], a))
            c.set(x, y+d, (col[0], col[1], col[2], a)); c.set(x, y-d, (col[0], col[1], col[2], a))

    # 5) vignette to focus the play area
    for y in range(H):
        for x in range(W):
            dx = (x-W/2)/(W/2); dy = (y-H/2)/(H/2); d = dx*dx+dy*dy
            if d > 0.55:
                c.set(x, y, (0, 0, 0, int(min(150, (d-0.55)*210))))
    return W, H, c.px

# =============================================================================
#  9-slice UI frames (navy + gold, to match the quest overlays)
# =============================================================================
def _frame(S, fill, border, edge, hi, bw=2):
    c = C(S, S)
    c.rect(0, 0, S, S, fill)
    for x in range(S):
        c.set(x, 0, edge); c.set(x, S-1, edge)
    for y in range(S):
        c.set(0, y, edge); c.set(S-1, y, edge)
    for x in range(1, S-1):
        for t in range(1, 1+bw):
            c.set(x, t, border); c.set(x, S-1-t, border)
    for y in range(1, S-1):
        for t in range(1, 1+bw):
            c.set(t, y, border); c.set(S-1-t, y, border)
    # inner top highlight
    for x in range(1+bw, S-1-bw):
        c.set(x, 1+bw, hi)
    return S, S, c.px

def make_panel_frame():    # HUD panel: deep navy, gold edge
    return _frame(24, hx("#0f1830"), hx("#caa23a"), hx("#05070f"), hx("#21305a"), bw=2)

def make_card_frame():     # overlay cards: lighter navy so they pop, bright gold edge
    return _frame(28, hx("#162243"), hx("#ffd152"), hx("#070b16"), hx("#26365f"), bw=2)

def make_button_frame():   # near-white so it tints cleanly via modulate
    S = 24; c = C(S, S)
    c.rect(0, 0, S, S, (232, 238, 235, 255))
    for x in range(S):
        c.set(x, 1, (255, 255, 255, 255)); c.set(x, 2, (248, 250, 248, 255))
        c.set(x, S-2, (150, 156, 158, 255)); c.set(x, S-3, (186, 192, 190, 255))
    for y in range(S):
        c.set(1, y, (250, 252, 250, 255)); c.set(S-2, y, (168, 174, 172, 255))
    edge = (12, 16, 28, 255)
    for x in range(S):
        c.set(x, 0, edge); c.set(x, S-1, edge)
    for y in range(S):
        c.set(0, y, edge); c.set(S-1, y, edge)
    return S, S, c.px

def make_bar_frame():      # thin framed channel for the energy meter
    W, H = 20, 16; c = C(W, H)
    fill, border, edge = hx("#070b16"), hx("#caa23a"), hx("#05070f")
    c.rect(0, 0, W, H, fill)
    for x in range(W):
        c.set(x, 0, edge); c.set(x, H-1, edge)
    for y in range(H):
        c.set(0, y, edge); c.set(W-1, y, edge)
    for x in range(1, W-1):
        c.set(x, 1, border); c.set(x, H-2, border)
    for y in range(1, H-1):
        c.set(1, y, border); c.set(W-2, y, border)
    return W, H, c.px

def make_star(filled):
    S = 20; c = C(S, S); cx = cy = S/2-0.5
    R, r = 9.0, 3.8
    pts = []
    for i in range(10):
        ang = -math.pi/2 + i*math.pi/5
        rad = R if i % 2 == 0 else r
        pts.append((cx+math.cos(ang)*rad, cy+math.sin(ang)*rad))
    def inside(px, py):
        n = len(pts); ins = False; j = n-1
        for i in range(n):
            xi, yi = pts[i]; xj, yj = pts[j]
            if ((yi > py) != (yj > py)) and (px < (xj-xi)*(py-yi)/(yj-yi)+xi):
                ins = not ins
            j = i
        return ins
    fill = hx("#ffd54a") if filled else hx("#26323f")
    hi = hx("#fff0a8") if filled else hx("#34424f")
    for y in range(S):
        for x in range(S):
            if inside(x+0.5, y+0.5):
                c.set(x, y, hi if (x-cx)+(y-cy) < -1 else fill)
    outline(c, hx("#13202a") if filled else hx("#1d2a34"))
    return S, S, c.px

# =============================================================================
def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/generated/dyson"
    os.makedirs(out, exist_ok=True)
    def w(name, tup): write_png(os.path.join(out, name+".png"), *tup)
    w("space_background", make_background())
    w("panel_frame", make_panel_frame())
    w("card_frame", make_card_frame())
    w("button_frame", make_button_frame())
    w("bar_frame", make_bar_frame())
    w("star_full", make_star(True))
    w("star_empty", make_star(False))
    print("Wrote DYSON SWARM pixel art to", out)

if __name__ == "__main__":
    main()
