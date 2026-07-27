#!/usr/bin/env python3
"""Dependency-free pixel-art asteroid generator for the Dyson Swarm quest.
Writes RGBA PNGs directly (no Pillow), matching the make_art.py house style:
an irregular rocky body, top-left lighting, shaded craters, and a dark outline.

Run:  python3 tools/make_asteroid.py assets/generated/dyson
Produces asteroid_1.png .. asteroid_3.png (a few shape/crater variants).
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

# ---------------- canvas + helpers ----------------
def blend(bg, fg):
    a = fg[3]/255.0
    return (int(fg[0]*a+bg[0]*(1-a)), int(fg[1]*a+bg[1]*(1-a)),
            int(fg[2]*a+bg[2]*(1-a)), max(bg[3], fg[3]))

class C:
    def __init__(self, w, h, bg=(0, 0, 0, 0)):
        self.w, self.h = w, h
        self.px = [bg]*(w*h)
    def set(self, x, y, c):
        x = int(x); y = int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            if len(c) == 3: c = (c[0], c[1], c[2], 255)
            self.px[y*self.w+x] = c if c[3] == 255 else blend(self.px[y*self.w+x], c)

def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)
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

# ---------------- palette (warm space-rock) ----------------
P = {
    "base": "#7d6d5c", "light": "#a8957f", "hi": "#cdbaa1",
    "dark": "#4e4338", "deep": "#322a22", "line": "#191309",
}
LX, LY = -0.62, -0.60   # light comes from the top-left

def make_asteroid(seed, S=96):
    rnd = random.Random(seed)
    c = C(S, S)
    cx = cy = S/2.0 - 0.5
    base_R = S*0.40
    # one dominant low-frequency lobe (elongation) + small high-frequency bumps
    # -> lumpy "potato" rocks rather than symmetric spiky stars
    harm = [(rnd.uniform(0.12, 0.20), 2, rnd.uniform(0, math.tau))]
    harm += [(rnd.uniform(0.025, 0.065), rnd.randint(3, 6), rnd.uniform(0, math.tau)) for _ in range(3)]
    def radius_at(ang):
        r = base_R
        for amp, freq, ph in harm:
            r *= (1.0 + amp*math.sin(freq*ang + ph))
        return r
    def inside(px, py):
        dx, dy = px-cx, py-cy
        return math.hypot(dx, dy) <= radius_at(math.atan2(dy, dx)) - 1

    base, light, hi = hx(P["base"]), hx(P["light"]), hx(P["hi"])
    dark, deep = hx(P["dark"]), hx(P["deep"])

    # --- body with directional lighting + a soft top-left highlight ---
    hlx, hly = cx - base_R*0.42, cy - base_R*0.42   # highlight centre (toward light)
    for y in range(S):
        for x in range(S):
            dx, dy = x-cx, y-cy
            d = math.hypot(dx, dy)
            R = radius_at(math.atan2(dy, dx))
            if d <= R:
                nx, ny = dx/base_R, dy/base_R
                lam = nx*LX + ny*LY              # >0 toward the light
                f = 0.92 + 0.5*lam
                edge = d/R
                if edge > 0.84:
                    f *= 0.72                     # darken the silhouette rim
                # broad soft highlight blob on the lit shoulder
                hd = math.hypot(x-hlx, y-hly)
                if hd < base_R*0.5:
                    f += 0.16*(1.0 - hd/(base_R*0.5))
                f += rnd.uniform(-0.045, 0.045)
                c.set(x, y, shade(base, max(0.4, min(1.55, f))))

    # --- subtle rocky mottling ---
    for _ in range(rnd.randint(8, 12)):
        a = rnd.uniform(0, math.tau); rr = rnd.uniform(0, 0.7)*base_R
        mx, my = cx + math.cos(a)*rr, cy + math.sin(a)*rr
        mrad = rnd.uniform(2, 5)
        tone = rnd.choice([0.86, 0.9, 1.1, 1.14])
        for y in range(int(my-mrad), int(my+mrad)+1):
            for x in range(int(mx-mrad), int(mx+mrad)+1):
                if math.hypot(x-mx, y-my) <= mrad and inside(x, y):
                    cur = c.px[y*S+x]
                    c.set(x, y, shade(cur, tone))

    # --- craters: smaller, spaced out, with 3-D bowl shading ---
    placed = []
    tries = 0
    target = rnd.randint(3, 4)
    while len(placed) < target and tries < 60:
        tries += 1
        a = rnd.uniform(0, math.tau)
        rr = rnd.uniform(0.0, 0.5)*base_R
        ccx, ccy = cx + math.cos(a)*rr, cy + math.sin(a)*rr
        crad = rnd.uniform(0.07, 0.12)*S
        if not inside(ccx + crad*0.6, ccy) or not inside(ccx - crad*0.6, ccy):
            continue
        ok = True
        for (px, py, pr) in placed:
            if math.hypot(ccx-px, ccy-py) < (crad + pr)*1.15:
                ok = False; break
        if not ok:
            continue
        placed.append((ccx, ccy, crad))

        # bowl floor: dark, a touch lighter on the far (lit) wall
        for y in range(int(ccy-crad)-1, int(ccy+crad)+2):
            for x in range(int(ccx-crad)-1, int(ccx+crad)+2):
                dx, dy = x-ccx, y-ccy
                if math.hypot(dx, dy) <= crad and inside(x, y):
                    wall = -((dx/crad)*LX + (dy/crad)*LY)   # >0 on far/lit wall
                    c.set(x, y, shade(deep, 0.95 + 0.45*max(0.0, wall)))
        # inner walls: bright crescent on far side, deep shadow on near side
        for i in range(80):
            ang = i/80.0*math.tau
            wl = -(math.cos(ang)*LX + math.sin(ang)*LY)     # >0 far/lit wall
            for k in (0.74, 0.9):
                rx, ry = ccx + math.cos(ang)*crad*k, ccy + math.sin(ang)*crad*k
                if not inside(rx, ry):
                    continue
                if wl > 0.2:
                    c.set(rx, ry, hi)
                elif wl < -0.2:
                    c.set(rx, ry, shade(deep, 0.7))
        # raised outer rim: lit on the top-left edge
        for i in range(80):
            ang = i/80.0*math.tau
            ol = math.cos(ang)*LX + math.sin(ang)*LY        # >0 lit outer edge
            rx, ry = ccx + math.cos(ang)*(crad+1), ccy + math.sin(ang)*(crad+1)
            if inside(rx, ry) and ol > 0.3:
                c.set(rx, ry, light)

    outline(c, hx(P["line"]))
    return S, S, c.px

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/generated/dyson"
    os.makedirs(out, exist_ok=True)
    for i in range(1, 4):
        w, h, px = make_asteroid(seed=100+i)
        p = os.path.join(out, "asteroid_%d.png" % i)
        write_png(p, w, h, px)
        print("wrote", p)

if __name__ == "__main__":
    main()
