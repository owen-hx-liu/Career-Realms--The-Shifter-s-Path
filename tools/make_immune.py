#!/usr/bin/env python3
"""Dependency-free pixel-art generator for the IMMUNE DEFENSE card quest.

Writes RGBA PNGs directly (no Pillow). One cohesive dark-navy / teal medical
sci-fi palette that matches the rest of the game (same bevel + dark-outline
house style as tools/make_art.py).

Generates:
  * 9-slice UI frames  : frame_panel, frame_pathogen, frame_immune,
                         frame_slot, frame_window, frame_banner, button
  * icons              : icon_hp, icon_atk, star_full, star_empty,
                         badge_perfect, badge_good, badge_bad, badge_neutral
  * 48x48 portraits    : p_01..p_12 (pathogens), i_01..i_10 (immune cells)
  * background         : bg (1152x648)

Run:  python3 tools/make_immune.py assets/generated/immune
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


OUTLINE = hx("#0c141b")          # universal dark outline


# ============================================================ cell body =====
def membrane(c, cx, cy, R, body, seed=1, bumpy=0.0):
    """Beveled round cell membrane: bright top-left, dark bottom-right, speckles."""
    bl = shade(body, 1.30)
    bd = shade(body, 0.66)
    rnd = random.Random(seed)
    for y in range(int(cy - R) - 2, int(cy + R) + 3):
        for x in range(int(cx - R) - 2, int(cx + R) + 3):
            ang = math.atan2(y - cy, x - cx)
            rr = R + (math.sin(ang * 5 + seed) * bumpy * R)
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if d2 <= rr * rr:
                d = (x - cx) + (y - cy)
                col = body
                if d > R * 0.45:
                    col = bd
                elif d < -R * 0.55:
                    col = bl
                c.set(x, y, col)
    # cytoplasm speckles
    for _ in range(int(R * 1.6)):
        a = rnd.random() * math.tau
        rr = rnd.random() * R * 0.8
        c.disc(cx + math.cos(a) * rr, cy + math.sin(a) * rr,
               rnd.choice([0.6, 1, 1]), shade(body, rnd.choice([0.82, 1.16])))
    # crisp rim shine (top-left)
    for a in range(180, 280, 6):
        ar = math.radians(a)
        c.set(cx + math.cos(ar) * (R - 1), cy + math.sin(ar) * (R - 1), shade(body, 1.45))


def nucleus(c, cx, cy, r, col):
    c.disc(cx, cy, r, col)
    c.disc(cx - r * 0.3, cy - r * 0.3, r * 0.45, shade(col, 1.3))
    c.disc(cx + r * 0.3, cy + r * 0.35, r * 0.32, shade(col, 0.72))


def spikes(c, cx, cy, R, n, length, col, knob=False, phase=0.0, thick=1.4):
    tip = shade(col, 1.2)
    for i in range(n):
        a = phase + i / n * math.tau
        ex, ey = cx + math.cos(a) * (R + length), cy + math.sin(a) * (R + length)
        c.line(cx + math.cos(a) * (R - 1), cy + math.sin(a) * (R - 1), ex, ey, col, thick)
        if knob:
            c.disc(ex, ey, thick + 1.1, tip)


# ============================================================ PORTRAITS =====
PSZ = 48  # portrait canvas

def _virus(capsid, spike, nuc, n=11, length=6, knob=False, seed=3, R=12):
    c = C(PSZ, PSZ); cx = cy = PSZ / 2 - 0.5
    spikes(c, cx, cy, R, n, length, spike, knob=knob, phase=0.0, thick=1.2)
    membrane(c, cx, cy, R, capsid, seed=seed)
    nucleus(c, cx, cy, R * 0.42, nuc)
    # faceted capsid hint
    for a in range(0, 360, 60):
        ar = math.radians(a + 15)
        c.line(cx, cy, cx + math.cos(ar) * R * 0.9, cy + math.sin(ar) * R * 0.9, shade(capsid, 0.8), 0.6)
    outline(c, OUTLINE)
    return PSZ, PSZ, c.px


def p_influenza():   return _virus(hx("#e2683f"), hx("#f09a4a"), hx("#7a2f18"), n=13, length=5, knob=True, seed=11, R=12)
def p_hiv():         return _virus(hx("#8a5bd0"), hx("#b98ef0"), hx("#3f2470"), n=10, length=7, knob=True, seed=5, R=11)
def p_rhino():       return _virus(hx("#b7c24a"), hx("#dbe87a"), hx("#5b6320"), n=14, length=3, knob=False, seed=7, R=11)
def p_sars():        return _virus(hx("#c75b54"), hx("#e89a86"), hx("#5e2420"), n=11, length=7, knob=True, seed=9, R=12)


def _cocci_cluster(positions, body, nuc, seed):
    c = C(PSZ, PSZ)
    for (px, py, r) in positions:
        membrane(c, px, py, r, body, seed=seed + int(px))
        nucleus(c, px, py, r * 0.4, nuc)
    outline(c, OUTLINE)
    return PSZ, PSZ, c.px


def p_ecoli():       # rod / bacillus with flagella
    c = C(PSZ, PSZ); cx = cy = PSZ / 2 - 0.5
    body, nuc = hx("#5aa86a"), hx("#2c6a3a")
    # flagella
    for s in (-1, 1):
        ox = cx + s * 13
        for i in range(10):
            f = i / 10.0
            c.set(ox + s * i * 1.4, cy + math.sin(f * 7 + s) * 5, hx("#7fce8c"))
    # capsule (rounded rect): two discs + bar
    rx, ry = 14, 7
    c.ellipse(cx, cy, rx, ry, body)
    bl, bd = shade(body, 1.28), shade(body, 0.66)
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                d = (x - cx) * 0.4 + (y - cy)
                if d > ry * 0.5:
                    c.set(x, y, bd)
                elif d < -ry * 0.6:
                    c.set(x, y, bl)
    rnd = random.Random(4)
    for _ in range(16):
        c.disc(cx + rnd.uniform(-rx * 0.7, rx * 0.7), cy + rnd.uniform(-ry * 0.6, ry * 0.6),
               rnd.choice([0.7, 1]), shade(body, rnd.choice([0.8, 1.2])))
    nucleus(c, cx - 4, cy, 3, nuc); nucleus(c, cx + 5, cy + 1, 2.4, nuc)
    outline(c, OUTLINE)
    return PSZ, PSZ, c.px


def p_strep():       # chain of cocci
    cx = cy = PSZ / 2 - 0.5
    pos = [(cx - 11, cy - 7, 5), (cx - 2, cy - 2, 5.5), (cx + 7, cy + 3, 5), (cx + 13, cy + 11, 4.2),
           (cx - 9, cy + 9, 4.4)]
    return _cocci_cluster(pos, hx("#9b6ad6"), hx("#4a2a86"), 6)


def p_staph():       # grape-like cluster
    cx = cy = PSZ / 2 - 0.5
    pos = [(cx - 6, cy - 6, 6), (cx + 5, cy - 5, 5.5), (cx - 7, cy + 5, 5.5),
           (cx + 6, cy + 6, 6), (cx, cy, 5)]
    return _cocci_cluster(pos, hx("#d6a93f"), hx("#7a5c18"), 8)


def p_candida():     # budding fungus + hypha
    c = C(PSZ, PSZ); cx = cy = PSZ / 2 - 0.5
    body, nuc = hx("#4fc2a8"), hx("#236a5a")
    # hypha tube
    c.line(cx - 13, cy + 12, cx + 2, cy - 2, shade(body, 0.85), 4)
    membrane(c, cx + 3, cy - 2, 11, body, seed=14)
    membrane(c, cx + 12, cy + 9, 6, body, seed=15)   # bud
    membrane(c, cx - 9, cy + 12, 4.5, body, seed=16)  # bud
    nucleus(c, cx + 3, cy - 2, 4.5, nuc)
    outline(c, OUTLINE)
    return PSZ, PSZ, c.px


def p_malaria():     # infected RBC with ring parasite
    c = C(PSZ, PSZ); cx = cy = PSZ / 2 - 0.5
    rbc = hx("#c34b56")
    membrane(c, cx, cy, 14, rbc, seed=21)
    c.disc(cx, cy, 6, shade(rbc, 0.7))     # RBC central pallor
    c.disc(cx, cy, 4.5, shade(rbc, 0.82))
    # ring-form parasite (purple signet ring)
    c.ring(cx + 4, cy - 3, 4, 2, hx("#7c5bd0"))
    c.disc(cx + 7, cy - 5, 2, hx("#b98ef0"))  # chromatin dot
    outline(c, OUTLINE)
    return PSZ, PSZ, c.px


def _cancer(body, nuc, seed):
    c = C(PSZ, PSZ); cx = cy = PSZ / 2 - 0.5
    membrane(c, cx, cy, 14, body, seed=seed, bumpy=0.22)
    # multiple irregular dark nuclei (hallmark of malignancy)
    rnd = random.Random(seed)
    for _ in range(3):
        nx, ny = cx + rnd.uniform(-5, 5), cy + rnd.uniform(-5, 5)
        nucleus(c, nx, ny, rnd.uniform(3, 4.5), nuc)
    outline(c, OUTLINE)
    return PSZ, PSZ, c.px


def p_lung_cancer():   return _cancer(hx("#8f8a93"), hx("#2c2730"), 31)
def p_melanoma():      return _cancer(hx("#5a4a3a"), hx("#141014"), 33)


def p_toxin():       # hazard droplet
    c = C(PSZ, PSZ); cx = PSZ / 2 - 0.5
    body, hi = hx("#caa83a"), hx("#f0d870")
    # teardrop: disc + triangle top
    c.disc(cx, 30, 11, body)
    for y in range(10, 30):
        wlin = (y - 10) / 20.0 * 9
        for x in range(int(cx - wlin), int(cx + wlin) + 1):
            c.set(x, y, body)
    # bevel
    for y in range(10, 42):
        for x in range(int(cx - 12), int(cx + 12)):
            if c.px[y * PSZ + x][3] > 0:
                d = (x - cx) + (y - 26)
                if d > 8:
                    c.set(x, y, shade(body, 0.7))
                elif d < -8:
                    c.set(x, y, shade(body, 1.25))
    c.disc(cx - 3, 26, 3, hi)  # shine
    # skull hint
    dark = hx("#3a2f10")
    c.disc(cx - 3, 30, 1.4, dark); c.disc(cx + 3, 30, 1.4, dark)
    c.rect(cx - 1, 33, 2, 3, dark)
    outline(c, OUTLINE)
    return PSZ, PSZ, c.px


# ---- immune cells ----
def _immune(body, nuc, seed, R=14):
    c = C(PSZ, PSZ); cx = cy = PSZ / 2 - 0.5
    membrane(c, cx, cy, R, body, seed=seed)
    nucleus(c, cx, cy, R * 0.5, nuc)
    return c, cx, cy


def _tcell(body, nuc, seed, receptor):
    c, cx, cy = _immune(body, nuc, seed)
    spikes(c, cx, cy, 14, 9, 4, receptor, knob=True, thick=1.2)  # TCRs
    outline(c, OUTLINE)
    return PSZ, PSZ, c.px


def i_cytotoxic():   # killer T: red, perforin granules
    c, cx, cy = _immune(hx("#e06a5a"), hx("#7a2a22"), 41)
    spikes(c, cx, cy, 14, 8, 5, hx("#f0a090"), knob=True, thick=1.3)
    rnd = random.Random(2)
    for _ in range(6):
        a = rnd.random() * math.tau; rr = rnd.random() * 7
        c.disc(cx + math.cos(a) * rr, cy + math.sin(a) * rr, 1.4, hx("#ffd24a"))  # lytic granules
    outline(c, OUTLINE)
    return PSZ, PSZ, c.px


def i_helper():      return _tcell(hx("#49a7ff"), hx("#1f4f8a"), 42, hx("#8cc8ff"))


def i_regulatory():  # calm teal T with shield/stop ring
    c, cx, cy = _immune(hx("#3fb59a"), hx("#1d6a5a"), 49)
    spikes(c, cx, cy, 14, 7, 4, hx("#8fe0cf"), knob=True, thick=1.2)
    c.ring(cx, cy, 6, 1.4, hx("#d7fff2"))  # suppression halo
    outline(c, OUTLINE)
    return PSZ, PSZ, c.px


def _bcell(body, nuc, seed):
    c, cx, cy = _immune(body, nuc, seed)
    # antibody "Y" shapes on surface
    for a in (0.6, 2.0, 3.6, 5.0):
        bx, by = cx + math.cos(a) * 14, cy + math.sin(a) * 14
        c.line(cx + math.cos(a) * 11, cy + math.sin(a) * 11, bx, by, hx("#eef6ff"), 1.0)
        c.line(bx, by, bx + math.cos(a - 0.5) * 4, by + math.sin(a - 0.5) * 4, hx("#eef6ff"), 1.0)
        c.line(bx, by, bx + math.cos(a + 0.5) * 4, by + math.sin(a + 0.5) * 4, hx("#eef6ff"), 1.0)
    return c, cx, cy


def i_memory_b():    # teal B with memory ring
    c, cx, cy = _bcell(hx("#3fb0c2"), hx("#1d6470"), 43)
    c.ring(cx, cy, 8, 1.3, hx("#bff0f8"))
    outline(c, OUTLINE)
    return PSZ, PSZ, c.px


def i_plasma_b():    # purple-blue B spewing antibodies
    c, cx, cy = _bcell(hx("#6f8be0"), hx("#2f3f86"), 44)
    rnd = random.Random(3)
    for _ in range(5):
        a = rnd.random() * math.tau; rr = 16 + rnd.random() * 5
        bx, by = cx + math.cos(a) * rr, cy + math.sin(a) * rr
        c.line(bx, by, bx + math.cos(a) * 3, by + math.sin(a) * 3, hx("#dfe8ff"), 0.9)
    outline(c, OUTLINE)
    return PSZ, PSZ, c.px


def i_nk():          # NK: green, granules + reticle
    c, cx, cy = _immune(hx("#5fcf7a"), hx("#286a3a"), 45)
    rnd = random.Random(5)
    for _ in range(8):
        a = rnd.random() * math.tau; rr = rnd.random() * 8
        c.disc(cx + math.cos(a) * rr, cy + math.sin(a) * rr, 1.5, hx("#d6ff9a"))
    c.ring(cx, cy, 10, 1.0, hx("#eaffd0"))
    for d in (-12, 12):
        c.line(cx + d, cy, cx + d * 0.6, cy, hx("#eaffd0"), 0.8)
        c.line(cx, cy + d, cx, cy + d * 0.6, hx("#eaffd0"), 0.8)
    outline(c, OUTLINE)
    return PSZ, PSZ, c.px


def i_macrophage():  # big amoeboid with pseudopods + vacuoles
    c = C(PSZ, PSZ); cx = cy = PSZ / 2 - 0.5
    body, nuc = hx("#c07fd0"), hx("#5e2f70")
    membrane(c, cx, cy, 15, body, seed=46, bumpy=0.28)
    # pseudopods
    for a in (0.3, 1.5, 2.7, 4.0, 5.2):
        ex, ey = cx + math.cos(a) * 19, cy + math.sin(a) * 19
        c.disc(ex, ey, 4, body)
        c.line(cx + math.cos(a) * 12, cy + math.sin(a) * 12, ex, ey, body, 3)
    membrane(c, cx, cy, 14, body, seed=46)  # redraw core over pseudopod bases
    nucleus(c, cx - 3, cy + 2, 6, nuc)
    # phagocytic vacuoles
    for vx, vy in [(cx + 5, cy - 4), (cx + 6, cy + 4)]:
        c.disc(vx, vy, 3, shade(body, 0.7)); c.ring(vx, vy, 3, 1, shade(body, 1.2))
    outline(c, OUTLINE)
    return PSZ, PSZ, c.px


def i_neutrophil():  # multi-lobed nucleus + granules
    c, cx, cy = _immune(hx("#7fb0d8"), hx("#2f4f6a"), 47)
    # multi-lobed nucleus (3 connected lobes)
    nl = hx("#3a2a6a")
    for (lx, ly, lr) in [(cx - 4, cy - 3, 4), (cx + 3, cy - 4, 3.6), (cx + 1, cy + 4, 4)]:
        c.disc(lx, ly, lr, nl)
        c.disc(lx - lr * 0.3, ly - lr * 0.3, lr * 0.4, shade(nl, 1.4))
    c.line(cx - 4, cy - 3, cx + 3, cy - 4, nl, 1.4)
    c.line(cx + 3, cy - 4, cx + 1, cy + 4, nl, 1.4)
    rnd = random.Random(7)
    for _ in range(10):
        a = rnd.random() * math.tau; rr = 8 + rnd.random() * 4
        c.disc(cx + math.cos(a) * rr, cy + math.sin(a) * rr, 1.1, hx("#cfe6f5"))
    outline(c, OUTLINE)
    return PSZ, PSZ, c.px


def i_dendritic():   # star-shaped with long dendrite arms
    c = C(PSZ, PSZ); cx = cy = PSZ / 2 - 0.5
    body, nuc = hx("#e0c25a"), hx("#7a5e1c")
    for i in range(8):
        a = i / 8 * math.tau + 0.2
        L = 20 if i % 2 == 0 else 16
        ex, ey = cx + math.cos(a) * L, cy + math.sin(a) * L
        c.line(cx, cy, ex, ey, body, 2.2)
        # branch tips
        c.line(ex, ey, ex + math.cos(a - 0.6) * 4, ey + math.sin(a - 0.6) * 4, body, 1.4)
        c.line(ex, ey, ex + math.cos(a + 0.6) * 4, ey + math.sin(a + 0.6) * 4, body, 1.4)
    membrane(c, cx, cy, 10, body, seed=48)
    nucleus(c, cx, cy, 4.5, nuc)
    outline(c, OUTLINE)
    return PSZ, PSZ, c.px


def i_eosinophil():  # bilobed nucleus + bright red-orange granules
    c, cx, cy = _immune(hx("#e88f6a"), hx("#7a3a22"), 50)
    nl = hx("#5e2f6a")
    c.disc(cx - 4, cy, 4.5, nl); c.disc(cx + 4, cy, 4.5, nl)
    c.line(cx - 4, cy, cx + 4, cy, nl, 2)
    rnd = random.Random(9)
    for _ in range(14):
        a = rnd.random() * math.tau; rr = rnd.random() * 10
        c.disc(cx + math.cos(a) * rr, cy + math.sin(a) * rr, 1.3, hx("#ff7a4a"))
    outline(c, OUTLINE)
    return PSZ, PSZ, c.px


PORTRAITS = {
    "p_01": p_influenza, "p_02": p_hiv, "p_03": p_rhino, "p_04": p_sars,
    "p_05": p_ecoli, "p_06": p_strep, "p_07": p_staph, "p_08": p_candida,
    "p_09": p_malaria, "p_10": p_lung_cancer, "p_11": p_melanoma, "p_12": p_toxin,
    "i_01": i_cytotoxic, "i_02": i_helper, "i_03": i_memory_b, "i_04": i_plasma_b,
    "i_05": i_nk, "i_06": i_macrophage, "i_07": i_neutrophil, "i_08": i_dendritic,
    "i_09": i_regulatory, "i_10": i_eosinophil,
}


# ============================================================ UI FRAMES =====
def _frame(S, fill, border, edge, hi, bevel=2):
    """Generic beveled 9-slice frame: outer dark edge, colored border band,
    inner fill, single bright top highlight line."""
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
        c.set(x, 1 + bevel, hi)               # top inner highlight
    for y in range(1 + bevel, S - 1 - bevel):
        c.set(1 + bevel, y, shade(hi, 0.8))   # left inner highlight
    return S, S, c.px


def frame_panel():     return _frame(24, hx("#14222d"), hx("#356b86"), hx("#0a131a"), hx("#4d86a0"))
def frame_pathogen():  return _frame(26, hx("#26131c"), hx("#b5476a"), hx("#0c0608"), hx("#e0728e"))
def frame_immune():    return _frame(26, hx("#102433"), hx("#3f8cc0"), hx("#06101a"), hx("#73c0e8"))
def frame_window():    return _frame(28, hx("#101a26"), hx("#d8b24a"), hx("#0a0e15"), hx("#f4dc82"), bevel=3)


def frame_slot():
    # recessed empty drafted slot: dark fill, inset (dark top, light bottom)
    S = 22; c = C(S, S)
    c.rect(0, 0, S, S, hx("#0b141d"))
    for x in range(S):
        c.set(x, 0, hx("#05090d")); c.set(x, S - 1, hx("#1d3240"))
    for y in range(S):
        c.set(0, y, hx("#05090d")); c.set(S - 1, y, hx("#1d3240"))
    for x in range(2, S - 2):
        c.set(x, 1, hx("#243a48"))
    for y in range(2, S - 2):
        c.set(1, y, hx("#243a48"))
    return S, S, c.px


def frame_banner():
    # title plate: dark teal with double gold rule
    S = 24; c = C(S, S)
    c.rect(0, 0, S, S, hx("#0e1a26"))
    for x in range(S):
        c.set(x, 0, OUTLINE); c.set(x, S - 1, OUTLINE)
    for y in range(S):
        c.set(0, y, OUTLINE); c.set(S - 1, y, OUTLINE)
    for x in range(1, S - 1):
        c.set(x, 1, hx("#d8b24a")); c.set(x, S - 2, hx("#a07c22"))
        c.set(x, 3, hx("#2f5d72"))
    for y in range(1, S - 1):
        c.set(1, y, hx("#c79e36")); c.set(S - 2, y, hx("#8a6a1c"))
    return S, S, c.px


def button():
    # near-white so it tints cleanly via modulate_color; dark outline stays dark
    S = 22; c = C(S, S)
    c.rect(0, 0, S, S, (228, 236, 233, 255))
    for x in range(S):
        c.set(x, 1, (255, 255, 255, 255)); c.set(x, 2, (246, 250, 248, 255))
        c.set(x, S - 2, (146, 154, 156, 255)); c.set(x, S - 3, (184, 192, 190, 255))
    for y in range(S):
        c.set(1, y, (250, 252, 250, 255)); c.set(S - 2, y, (164, 172, 170, 255))
    edge = (14, 20, 26, 255)
    for x in range(S):
        c.set(x, 0, edge); c.set(x, S - 1, edge)
    for y in range(S):
        c.set(0, y, edge); c.set(S - 1, y, edge)
    return S, S, c.px


# ============================================================ ICONS =========
def icon_hp():
    S = 16; c = C(S, S); base = hx("#ff5a6a")
    # pixel heart
    rows = [
        "..##.##..",
        ".#######.",
        ".#######.",
        ".#######.",
        "..#####..",
        "...###...",
        "....#....",
    ]
    ox = (S - 9) // 2; oy = 3
    for ry, row in enumerate(rows):
        for rx, ch in enumerate(row):
            if ch == "#":
                col = shade(base, 1.3) if ry < 2 else (shade(base, 0.7) if ry > 4 else base)
                c.set(ox + rx, oy + ry, col)
    c.set(ox + 2, oy + 1, hx("#ffd0d6"))
    outline(c, hx("#5a1018"))
    return S, S, c.px


def icon_atk():
    S = 16; c = C(S, S)
    steel, edge, hilt = hx("#cdd6df"), hx("#8a96a4"), hx("#a8742f")
    # diagonal blade bottom-left -> top-right
    for i in range(10):
        x = 3 + i; y = 12 - i
        c.set(x, y, steel); c.set(x - 1, y, edge); c.set(x, y + 1, shade(steel, 1.3))
    c.set(12, 2, hx("#eef4fa")); c.set(13, 2, steel)
    # hilt + guard (bottom-left)
    c.set(3, 13, hilt); c.set(2, 13, hilt); c.set(2, 12, hilt)
    c.set(4, 11, hx("#e0c24a")); c.set(3, 12, hx("#e0c24a"))  # guard
    outline(c, hx("#1a2028"))
    return S, S, c.px


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

    fill = hx("#ffd54a") if filled else hx("#2b3a45")
    hi = hx("#fff0a8") if filled else hx("#3b4d59")
    for y in range(S):
        for x in range(S):
            if inside(x + 0.5, y + 0.5):
                c.set(x, y, hi if (x - cx) + (y - cy) < -1 else fill)
    outline(c, hx("#15202a") if filled else hx("#22323c"))
    return S, S, c.px


def star_full():   return _star(True)
def star_empty():  return _star(False)


def _badge(symbol, col):
    S = 16; c = C(S, S); cx = cy = S / 2 - 0.5
    c.disc(cx, cy, 7, shade(col, 0.5))
    c.disc(cx, cy, 6, col)
    c.disc(cx - 1.5, cy - 1.5, 2.4, shade(col, 1.3))
    w = hx("#ffffff")
    if symbol == "check":
        c.line(4, 8, 7, 11, w, 1.0); c.line(7, 11, 12, 4, w, 1.0)
    elif symbol == "check2":
        c.line(3, 8, 5, 10, w, 0.9); c.line(5, 10, 9, 4, w, 0.9)
        c.line(7, 8, 9, 10, w, 0.9); c.line(9, 10, 13, 4, w, 0.9)
    elif symbol == "cross":
        c.line(4, 4, 11, 11, w, 1.1); c.line(11, 4, 4, 11, w, 1.1)
    else:  # dot / neutral
        c.disc(cx, cy, 2.2, w)
    outline(c, OUTLINE)
    return S, S, c.px


def badge_perfect():  return _badge("check2", hx("#3ad17a"))
def badge_good():     return _badge("check", hx("#49a7ff"))
def badge_bad():      return _badge("cross", hx("#e0556a"))
def badge_neutral():  return _badge("dot", hx("#7d8a96"))


# ============================================================ BACKGROUND ====
def make_bg():
    W, H = 1152, 648; c = C(W, H)
    top, bot = hx("#101a2a"), hx("#080d16")
    for y in range(H):
        f = y / H
        c.px[y * W:(y + 1) * W] = [mix(top, bot, f)] * W
    rnd = random.Random(20)
    # soft out-of-focus cells (bokeh) — immune cyan + a few pathogen red
    for _ in range(34):
        x = rnd.randint(0, W); y = rnd.randint(0, H); r = rnd.randint(26, 70)
        red = rnd.random() < 0.28
        base = (210, 90, 110) if red else (90, 180, 210)
        for ring_r in range(r, r - 4, -1):
            for a in range(0, 360, 5):
                ar = math.radians(a)
                c.set(x + math.cos(ar) * ring_r, y + math.sin(ar) * ring_r, (base[0], base[1], base[2], 14))
        c.disc(x, y, r - 5, (base[0], base[1], base[2], 7))
    # faint hex/grid lab overlay
    for gx in range(0, W, 64):
        for y in range(H):
            c.set(gx, y, (255, 255, 255, 7))
    for gy in range(0, H, 64):
        for x in range(W):
            c.set(x, gy, (255, 255, 255, 7))
    # drifting "platelet" specks
    for _ in range(120):
        x = rnd.randint(0, W); y = rnd.randint(0, H)
        c.disc(x, y, rnd.choice([1, 1, 2]), (150, 200, 220, rnd.randint(12, 30)))
    # vignette
    for y in range(H):
        for x in range(W):
            dx = (x - W / 2) / (W / 2); dy = (y - H / 2) / (H / 2); d = dx * dx + dy * dy
            if d > 0.55:
                c.set(x, y, (0, 0, 0, int(min(150, (d - 0.55) * 200))))
    return W, H, c.px


# ============================================================ MAIN ==========
def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/generated/immune"
    os.makedirs(out, exist_ok=True)

    def w(name, tup):
        write_png(os.path.join(out, name + ".png"), *tup)

    # frames + buttons
    w("frame_panel", frame_panel())
    w("frame_pathogen", frame_pathogen())
    w("frame_immune", frame_immune())
    w("frame_slot", frame_slot())
    w("frame_window", frame_window())
    w("frame_banner", frame_banner())
    w("button", button())
    # icons
    w("icon_hp", icon_hp())
    w("icon_atk", icon_atk())
    w("star_full", star_full())
    w("star_empty", star_empty())
    w("badge_perfect", badge_perfect())
    w("badge_good", badge_good())
    w("badge_bad", badge_bad())
    w("badge_neutral", badge_neutral())
    # portraits
    for cid, fn in PORTRAITS.items():
        w(cid, fn())
    # background
    w("bg", make_bg())

    print("Wrote %d immune-quest assets to %s" % (7 + 8 + len(PORTRAITS) + 1, out))


if __name__ == "__main__":
    main()
