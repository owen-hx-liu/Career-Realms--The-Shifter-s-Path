#!/usr/bin/env python3
"""Dependency-free pixel-art generator for the XENO LAB quest.
Writes RGBA PNGs directly (no Pillow). Cohesive dark-teal sci-fi palette.
Run:  python3 tools/make_art.py <out_dir>
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

# ---------------- 5x7 pixel font ----------------
FONT = {
 "A": [".###.","#...#","#...#","#####","#...#","#...#","#...#"],
 "T": ["#####","..#..","..#..","..#..","..#..","..#..","..#.."],
 "C": [".###.","#...#","#....","#....","#....","#...#",".###."],
 "G": [".###.","#...#","#....","#.###","#...#","#...#",".####"],
 "U": ["#...#","#...#","#...#","#...#","#...#","#...#",".###."],
}
def stamp(c, letter, x0, y0, scale, col, shadow=None):
    g = FONT[letter]
    for ry, row in enumerate(g):
        for rx, ch in enumerate(row):
            if ch == "#":
                for sx in range(scale):
                    for sy in range(scale):
                        if shadow:
                            c.set(x0+rx*scale+sx+1, y0+ry*scale+sy+1, shadow)
    for ry, row in enumerate(g):
        for rx, ch in enumerate(row):
            if ch == "#":
                for sx in range(scale):
                    for sy in range(scale):
                        c.set(x0+rx*scale+sx, y0+ry*scale+sy, col)

# ---------------- base tiles ----------------
BASES = {"a":"#5fd36a", "t":"#ff6f61", "c":"#49a7ff", "g":"#ffc23d", "u":"#b27bff"}
def make_base(letter, base_hex):
    S = 24; c = C(S, S); col = hx(base_hex); rad = 5
    for y in range(S):
        for x in range(S):
            cx = min(x, S-1-x); cy = min(y, S-1-y)
            if cx < rad and cy < rad and (rad-cx)**2+(rad-cy)**2 > rad*rad+1:
                continue
            f = 1.22 - 0.55*(y/S)            # bevel: bright top, dark bottom
            c.set(x, y, shade(col, f))
    # inner top highlight line
    for x in range(rad, S-rad):
        c.set(x, 3, shade(col, 1.45))
    outline(c, hx("#0e1519"))
    stamp(c, letter.upper(), 7, 5, 2, hx("#f4fff8"), shadow=(10, 20, 16, 200))
    return S, S, c.px

# ---------------- creatures (cell / boss) ----------------
def make_cell(infected):
    S = 56; c = C(S, S); cx = cy = S/2-0.5
    if infected:
        body, bd, bl = hx("#7cc24f"), hx("#3f7a31"), hx("#a6e06a")
        spike, nuc, nucl = hx("#b27bff"), hx("#7b46c9"), hx("#a574e8")
    else:
        body, bd, bl = hx("#5fd3c2"), hx("#2f8d83"), hx("#9af0e3")
        spike, nuc, nucl = hx("#8defc0"), hx("#49a7ff"), hx("#8cc8ff")
    R = 19; n = 12 if infected else 8
    for i in range(n):
        ang = i/n*math.tau + (0.13 if infected else 0); L = R+(9 if infected else 4)
        for t in range(10):
            f = t/10.0
            c.disc(cx+math.cos(ang)*(R*0.7+f*L*0.4), cy+math.sin(ang)*(R*0.7+f*L*0.4), 1.4, spike)
        c.disc(cx+math.cos(ang)*L, cy+math.sin(ang)*L, 3 if infected else 3.2, spike)
    c.disc(cx, cy, R, body)
    for y in range(S):
        for x in range(S):
            if (x-cx)**2+(y-cy)**2 <= R*R:
                d = (x-cx)+(y-cy)
                if d > R*0.55: c.set(x, y, bd)
                elif d < -R*0.6: c.set(x, y, bl)
    rnd = random.Random(7 if infected else 3)
    for _ in range(18):
        a = rnd.random()*math.tau; rr = rnd.random()*R*0.8
        c.disc(cx+math.cos(a)*rr, cy+math.sin(a)*rr, rnd.choice([1,1,2]), shade(body, 0.8 if infected else 1.12))
    c.disc(cx+(3 if infected else 0), cy+2, 6, nuc); c.disc(cx+(3 if infected else 0)-1, cy+1, 2.4, nucl)
    white, dark = hx("#f4ffff"), hx("#15201c")
    for s in (-1, 1):
        c.disc(cx+s*6, cy-5, 3.1, white); c.disc(cx+s*6+(1 if infected else 0), cy-5, 1.5, dark)
    if infected:
        for k in range(6):
            c.set(cx-8+k, cy-9+k//2, dark); c.set(cx+8-k, cy-9+k//2, dark)
    else:
        for k in range(-3, 4):
            c.set(cx+k, cy+6+(0 if abs(k) < 3 else -1), dark)
    outline(c, hx("#0e1a16"))
    return S, S, c.px

def make_boss():
    S = 88; c = C(S, S); cx = cy = S/2-0.5
    body, bd, bl = hx("#6a8f3a"), hx("#33531f"), hx("#9ad055")
    spike, nuc = hx("#9b5de5"), hx("#5a2ea0")
    R = 30
    # tentacles
    for i in range(16):
        ang = i/16*math.tau + 0.1; L = R+14+ (4 if i % 2 else 0)
        for t in range(14):
            f = t/14.0
            wob = math.sin(f*6+i)*3
            c.disc(cx+math.cos(ang)*(R*0.7+f*L*0.45)+wob, cy+math.sin(ang)*(R*0.7+f*L*0.45), 2.0, spike)
        c.disc(cx+math.cos(ang)*L, cy+math.sin(ang)*L, 4, spike)
    c.disc(cx, cy, R, body)
    for y in range(S):
        for x in range(S):
            if (x-cx)**2+(y-cy)**2 <= R*R:
                d = (x-cx)+(y-cy)
                if d > R*0.5: c.set(x, y, bd)
                elif d < -R*0.7: c.set(x, y, bl)
    rnd = random.Random(11)
    for _ in range(40):
        a = rnd.random()*math.tau; rr = rnd.random()*R*0.85
        c.disc(cx+math.cos(a)*rr, cy+math.sin(a)*rr, rnd.choice([1,2,2,3]), shade(body, rnd.choice([0.7, 1.2])))
    # purple core
    c.disc(cx, cy+4, 9, nuc); c.disc(cx-2, cy+1, 4, hx("#b98ef0"))
    # three angry eyes
    white, dark = hx("#f4ffff"), hx("#15201c")
    for ex, ey in [(-11, -7), (11, -7), (0, -14)]:
        c.disc(cx+ex, cy+ey, 4.2, white); c.disc(cx+ex+1, cy+ey, 2.0, dark)
    for k in range(8):
        c.set(cx-15+k, cy-12+k//2, dark); c.set(cx+15-k, cy-12+k//2, dark)
    # jagged mouth
    for k in range(-9, 10):
        c.set(cx+k, cy+15+(k % 2)*2, dark)
        c.set(cx+k, cy+16+(k % 2)*2, dark)
    outline(c, hx("#0c150a"))
    return S, S, c.px

# ---------------- spores ----------------
def make_spore(toxic):
    S = 22; c = C(S, S); cx = cy = S/2-0.5
    if toxic:
        body, bd, bl, sp = hx("#e0476a"), hx("#8e2440"), hx("#ff90a8"), hx("#ff5d7a")
        for i in range(8):
            a = i/8*math.tau
            c.disc(cx+math.cos(a)*9, cy+math.sin(a)*9, 2.0, sp)
    else:
        body, bd, bl, sp = hx("#5fd36a"), hx("#2f8d3a"), hx("#a6f0a6"), hx("#8defc0")
        for i in range(3):
            a = -0.5 + i*0.5
            c.disc(cx+math.cos(a)*9, cy-7+i, 1.4, sp)
    R = 7
    c.disc(cx, cy, R, body)
    for y in range(S):
        for x in range(S):
            if (x-cx)**2+(y-cy)**2 <= R*R:
                d = (x-cx)+(y-cy)
                if d > R*0.4: c.set(x, y, bd)
                elif d < -R*0.6: c.set(x, y, bl)
    dark = hx("#1a1014")
    if toxic:
        c.set(cx-3, cy-1, dark); c.set(cx-2, cy, dark); c.set(cx-3, cy+1, dark); c.set(cx-1, cy, dark)
        c.set(cx+3, cy-1, dark); c.set(cx+2, cy, dark); c.set(cx+3, cy+1, dark); c.set(cx+1, cy, dark)
    else:
        c.disc(cx-2, cy-2, 1.4, hx("#eafff0"))
    outline(c, hx("#10171b"))
    return S, S, c.px

# ---------------- collector (catcher) ----------------
def make_collector():
    S = 40; c = C(S, S); cx = cy = S/2-0.5
    glow = hx("#6fe3c2")
    c.disc(cx, cy, 15, (60, 220, 190, 60))     # soft glow
    c.ring(cx, cy, 16, 4, hx("#8ff0d6"))        # outer hoop
    c.ring(cx, cy, 16, 2, hx("#d6fff2"))
    c.disc(cx, cy, 11, (90, 230, 200, 40))      # faint inner fill
    # crosshair
    for d in range(-6, 7):
        c.set(cx+d, cy, hx("#bff8e6")); c.set(cx, cy+d, hx("#bff8e6"))
    c.disc(cx, cy, 2.2, hx("#eafff7"))
    outline(c, hx("#103028"))
    return S, S, c.px

# ---------------- bioreactor vessel ----------------
def make_reactor():
    W, H = 70, 120; c = C(W, H)
    glass = hx("#9fe6ff"); cult = hx("#54c98a"); cultd = hx("#2f8d5c"); cultl = hx("#8defb0")
    # stand / base
    c.rect(12, H-12, W-24, 10, hx("#2a4250"))
    c.rect(8, H-4, W-16, 4, hx("#1d3340"))
    # vessel body
    bx0, by0, bw, bh = 14, 14, W-28, H-30
    # culture fill (lower 62%)
    fill_top = by0 + int(bh*0.38)
    for y in range(by0, by0+bh):
        for x in range(bx0, bx0+bw):
            if y >= fill_top:
                col = cult
                if x-bx0 < 3 or (bx0+bw)-x < 3: col = cultd
                c.set(x, y, col)
    # surface highlight
    for x in range(bx0, bx0+bw):
        c.set(x, fill_top, cultl)
    # bubbles
    rnd = random.Random(5)
    for _ in range(22):
        bxp = rnd.randint(bx0+3, bx0+bw-4); byp = rnd.randint(fill_top+2, by0+bh-3)
        c.disc(bxp, byp, rnd.choice([1, 1, 2]), cultl)
    # glass outline (vessel walls + neck)
    for y in range(by0, by0+bh):
        c.set(bx0, y, glass); c.set(bx0+bw-1, y, glass)
    for x in range(bx0, bx0+bw):
        c.set(x, by0, glass); c.set(x, by0+bh-1, glass)
    # neck + cap
    c.rect(W/2-7, 4, 14, 12, hx("#cdebf7"))
    c.rect(W/2-9, 2, 18, 4, hx("#7fb8cc"))
    # glass shine
    for y in range(by0+4, by0+bh-6):
        c.set(bx0+4, y, (255, 255, 255, 40))
    outline(c, hx("#12222b"))
    return W, H, c.px

# ---------------- pixel UI frames (9-slice) ----------------
def make_panel_frame():
    S = 24; c = C(S, S)
    fill, border, edge, hi = hx("#13212c"), hx("#356b86"), hx("#0b141b"), hx("#4d86a0")
    c.rect(0, 0, S, S, fill)
    for x in range(S):
        c.set(x, 0, edge); c.set(x, S-1, edge)
    for y in range(S):
        c.set(0, y, edge); c.set(S-1, y, edge)
    for x in range(1, S-1):
        c.set(x, 1, border); c.set(x, 2, border); c.set(x, S-2, border); c.set(x, S-3, border)
    for y in range(1, S-1):
        c.set(1, y, border); c.set(2, y, border); c.set(S-2, y, border); c.set(S-3, y, border)
    for x in range(3, S-3):
        c.set(x, 3, hi)
    return S, S, c.px

def make_card_frame():
    # lighter than panel_frame so dialog/result cards pop on the dark overlay
    S = 28; c = C(S, S)
    fill, border, edge, hi = hx("#1c3543"), hx("#5aa0bd"), hx("#0c1820"), hx("#84c8df")
    c.rect(0, 0, S, S, fill)
    for x in range(S):
        c.set(x, 0, edge); c.set(x, S-1, edge)
    for y in range(S):
        c.set(0, y, edge); c.set(S-1, y, edge)
    for x in range(1, S-1):
        for t in (1, 2):
            c.set(x, t, border); c.set(x, S-1-t, border)
    for y in range(1, S-1):
        for t in (1, 2):
            c.set(t, y, border); c.set(S-1-t, y, border)
    for x in range(3, S-3):
        c.set(x, 3, hi)
    return S, S, c.px

def make_button_frame():
    # near-white so it tints cleanly via modulate; dark outline stays dark.
    S = 24; c = C(S, S)
    c.rect(0, 0, S, S, (232, 238, 235, 255))
    for x in range(S):
        c.set(x, 1, (255, 255, 255, 255)); c.set(x, 2, (248, 250, 248, 255))
        c.set(x, S-2, (150, 156, 158, 255)); c.set(x, S-3, (186, 192, 190, 255))
    for y in range(S):
        c.set(1, y, (250, 252, 250, 255)); c.set(S-2, y, (168, 174, 172, 255))
    edge = (18, 24, 28, 255)
    for x in range(S):
        c.set(x, 0, edge); c.set(x, S-1, edge)
    for y in range(S):
        c.set(0, y, edge); c.set(S-1, y, edge)
    return S, S, c.px

def make_star(filled):
    S = 18; c = C(S, S); cx = cy = S/2-0.5
    R, r = 8.2, 3.5
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
    fill = hx("#ffd54a") if filled else hx("#2b3a45")
    hi = hx("#fff0a8") if filled else hx("#3b4d59")
    for y in range(S):
        for x in range(S):
            if inside(x+0.5, y+0.5):
                c.set(x, y, hi if (x-cx)+(y-cy) < -1 else fill)
    outline(c, hx("#15202a") if filled else hx("#22323c"))
    return S, S, c.px

# ---------------- background ----------------
def make_background():
    W, H = 1152, 648; c = C(W, H, hx("#0a1118"))
    top, bot = (10, 20, 28), (8, 14, 20)
    for y in range(H):
        f = y/H
        col = (int(top[0]*(1-f)+bot[0]*f), int(top[1]*(1-f)+bot[1]*f), int(top[2]*(1-f)+bot[2]*f), 255)
        for x in range(W):
            c.px[y*W+x] = col
    for x in range(0, W, 48):
        for y in range(H):
            c.set(x, y, (255, 255, 255, 10))
    for y in range(0, H, 48):
        for x in range(W):
            c.set(x, y, (255, 255, 255, 10))
    ccx = W*0.84
    for y in range(40, H-40):
        ph = y*0.05
        for t in range(-2, 3):
            c.set(ccx+math.sin(ph)*70+t, y, (110, 230, 200, 16))
            c.set(ccx+math.sin(ph+math.pi)*70+t, y, (90, 160, 255, 14))
        if y % 22 == 0:
            a, b = sorted([ccx+math.sin(ph)*70, ccx+math.sin(ph+math.pi)*70])
            for x in range(int(a), int(b)):
                c.set(x, y, (120, 200, 220, 12))
    for y in range(H):
        for x in range(W):
            dx = (x-W/2)/(W/2); dy = (y-H/2)/(H/2); d = dx*dx+dy*dy
            if d > 0.6:
                c.set(x, y, (0, 0, 0, int(min(120, (d-0.6)*180))))
    return W, H, c.px

# ---------------- main ----------------
def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/generated/splice_lab"
    os.makedirs(out, exist_ok=True)
    def w(name, tup): write_png(os.path.join(out, name+".png"), *tup)
    for k, hexcol in BASES.items():
        w("base_"+k, make_base(k, hexcol))
    w("alien_cell", make_cell(True))
    w("cured_cell", make_cell(False))
    w("boss", make_boss())
    w("spore_good", make_spore(False))
    w("spore_toxic", make_spore(True))
    w("collector", make_collector())
    w("reactor", make_reactor())
    w("panel_frame", make_panel_frame())
    w("card_frame", make_card_frame())
    w("button_frame", make_button_frame())
    w("star_full", make_star(True))
    w("star_empty", make_star(False))
    w("lab_background", make_background())
    print("Wrote all XENO LAB pixel art to", out)

if __name__ == "__main__":
    main()
