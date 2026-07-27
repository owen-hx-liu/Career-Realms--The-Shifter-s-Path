#!/usr/bin/env python3
"""Dependency-free pixel-art generator for the Ancient Egypt canal autotile.
Writes a 16-tile connection sheet (4x4 grid of 16x16 tiles) as canal_tiles.png.

Each tile index is a 4-bit neighbour mask  N=1 E=2 S=4 W=8 .  A canal segment
extends a stone-lined water "arm" toward every connected neighbour, so adjacent
pieces line up into one seamless waterway.  Palette matches the desert houses
(warm sandstone, dark outline, bevel) and the Nile-blue terrain water.

Run:  python3 tools/make_canal.py assets/generated/canal
"""
import sys, os, zlib, struct, math

# ---------------- tiny PNG writer (same approach as tools/make_art.py) --------
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

def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)
def shade(c, f):
    return (max(0, min(255, int(c[0]*f))), max(0, min(255, int(c[1]*f))),
            max(0, min(255, int(c[2]*f))), c[3] if len(c) == 4 else 255)

# ---------------- palette (desert sandstone + Nile water) ---------------------
OUTLINE     = hx("#3a2616")
BANK_HI     = hx("#e9c489")
BANK        = hx("#d29c58")
BANK_DK     = hx("#a4703a")
BANK_WET    = hx("#855629")
WATER_DEEP  = hx("#155f84")
WATER       = hx("#2497c2")
WATER_MID   = hx("#39abd2")
WATER_HI    = hx("#62c8e4")
WATER_GLINT = hx("#c2eff8")

N, E, S, W = 1, 2, 4, 8
TILE = 16
PAD = 4
G = TILE + 2*PAD
CW = 3.0          # water channel half-width
BANK_T = 2.3      # bank thickness
CX = PAD + 7.5
CY = PAD + 7.5

def _hash(x, y):
    h = (x*73856093) ^ (y*19349663)
    return (h ^ (h >> 13)) & 0x7fffffff

def build_tile(mask):
    # 1) water region in the padded grid; connected arms run off the edge so
    #    the shared border has no cap/outline (seamless with the neighbour).
    water = [[False]*G for _ in range(G)]
    def box(x0, y0, x1, y1):
        for y in range(G):
            for x in range(G):
                if x0 <= x <= x1 and y0 <= y <= y1:
                    water[y][x] = True
    box(CX-CW, CY-CW, CX+CW, CY+CW)                 # centre hub
    if mask & N: box(CX-CW, 0,      CX+CW, CY)
    if mask & S: box(CX-CW, CY,     CX+CW, G-1)
    if mask & W: box(0,     CY-CW,  CX,    CY+CW)
    if mask & E: box(CX,    CY-CW,  G-1,   CY+CW)

    water_pts = [(x, y) for y in range(G) for x in range(G) if water[y][x]]
    nonwater_pts = [(x, y) for y in range(G) for x in range(G) if not water[y][x]]

    def dist_to(pts, x, y):
        best = 1e9
        for (px, py) in pts:
            d = (px-x)**2 + (py-y)**2
            if d < best:
                best = d
        return math.sqrt(best)

    px = [(0, 0, 0, 0)]*(TILE*TILE)
    for ty in range(TILE):
        for tx in range(TILE):
            x, y = tx+PAD, ty+PAD
            if water[y][x]:
                depth = dist_to(nonwater_pts, x, y)
                col = WATER
                if depth < 1.1:
                    col = WATER_DEEP
                elif depth < 2.0:
                    col = WATER
                else:
                    col = WATER_MID
                h = _hash(tx, ty)
                if depth >= 2.0 and h % 6 == 0:
                    col = WATER_HI
                if depth >= 3.2 and h % 11 == 0:
                    col = WATER_GLINT
                px[ty*TILE+tx] = col
                continue
            d = dist_to(water_pts, x, y)
            if d <= BANK_T:
                # bank: vertical bevel (sunlit top, shadowed base)
                f = 1.14 - 0.5*(ty/float(TILE))
                col = shade(BANK, f)
                inner = False    # touches the water (wet shadow rim)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if 0 <= x+dx < G and 0 <= y+dy < G and water[y+dy][x+dx]:
                        inner = True
                        break
                top_outer = (y-1 < 0) or (d <= BANK_T and not water[y-1][x]
                             and dist_to(water_pts, x, y-1) > BANK_T)
                if inner:
                    col = BANK_DK
                elif top_outer:
                    col = BANK_HI
                px[ty*TILE+tx] = col
            elif d <= BANK_T + 1.1:
                px[ty*TILE+tx] = OUTLINE
            # else transparent
    return px

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/generated/canal"
    os.makedirs(out, exist_ok=True)
    sheet_w = sheet_h = TILE*4
    sheet = [(0, 0, 0, 0)]*(sheet_w*sheet_h)
    for mask in range(16):
        tile = build_tile(mask)
        col = (mask % 4)*TILE
        row = (mask // 4)*TILE
        for ty in range(TILE):
            for tx in range(TILE):
                sheet[(row+ty)*sheet_w + (col+tx)] = tile[ty*TILE+tx]
    write_png(os.path.join(out, "canal_tiles.png"), sheet_w, sheet_h, sheet)
    print("Wrote canal autotile sheet (16 tiles) to", out)

if __name__ == "__main__":
    main()
