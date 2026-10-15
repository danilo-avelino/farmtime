# Renderiza uma seta 3D (malha extrudada com aresta central) em N ângulos e
# monta uma folha de sprites 8x8 para o WoW (TGA 32 bits, origem no topo).
import math, struct, sys
import numpy as np
from PIL import Image, ImageFilter

N, COLS = 64, 8
FRAME = 128
SS = 3
R = FRAME * SS

# Contorno (visto de cima, CCW). +Y = frente, +X = direita.
outline = [(0, 1.0), (-0.62, 0.12), (-0.22, 0.12), (-0.22, -0.92),
           (0.22, -0.92), (0.22, 0.12), (0.62, 0.12)]
EDGE_Z = 0.10
ridge = {"tip": (0, 1.0, 0.16), "mid": (0, 0.12, 0.34), "tail": (0, -0.92, 0.26)}

def top_tris():
    T, M, Ta = ridge["tip"], ridge["mid"], ridge["tail"]
    def p(i): x, y = outline[i]; return (x, y, EDGE_Z)
    tris = []
    for hd, nt, tl in ((1, 2, 3), (6, 5, 4)):   # lado esquerdo e direito
        tris += [(T, p(hd), M), (M, p(hd), p(nt)), (M, p(nt), p(tl)), (M, p(tl), Ta)]
    return tris

def side_tris():
    tris = []
    n = len(outline)
    for i in range(n):
        x1, y1 = outline[i]; x2, y2 = outline[(i + 1) % n]
        a, b = (x1, y1, 0.0), (x2, y2, 0.0)
        z1 = ridge["tip"][2] if i == 0 else EDGE_Z
        z2 = ridge["tip"][2] if (i + 1) % n == 0 else EDGE_Z
        c, d = (x1, y1, z1), (x2, y2, z2)
        tris += [(a, b, d), (a, d, c)]
    return tris

TOP, SIDE = top_tris(), side_tris()

PITCH = math.radians(52)
DIST = 6.0
C = np.array([0, -DIST * math.cos(PITCH), DIST * math.sin(PITCH)])
f = -C / np.linalg.norm(C)
r = np.array([1.0, 0, 0])
u = np.cross(r, f)
FOCAL = R * 0.5 / math.tan(math.radians(11))
L = np.array([-0.45, -0.35, 1.0]); L /= np.linalg.norm(L)
V = -f

def rotz(p, a):
    c, s = math.cos(a), math.sin(a)
    return np.array([p[0] * c - p[1] * s, p[0] * s + p[1] * c, p[2]])

def project(P):
    v = P - C
    zc = v @ f
    return R / 2 + FOCAL * (v @ r) / zc, R / 2 + R * 0.04 - FOCAL * (v @ u) / zc, zc

def raster(tris, rot, color_fn, img, zbuf, mask):
    for tri in tris:
        P = [rotz(np.array(p, float), rot) for p in tri]
        n = np.cross(P[1] - P[0], P[2] - P[0])
        if np.linalg.norm(n) < 1e-9: continue
        n /= np.linalg.norm(n)
        centroid = sum(P) / 3
        if n[2] < -1e-6 or (abs(n[2]) < 0.3 and n @ np.array([centroid[0], centroid[1], 0]) < 0):
            n = -n
        if n @ (C - centroid) <= 0: continue  # de costas para a câmera
        shade = color_fn(n)
        S = [project(p) for p in P]
        xs = [s[0] for s in S]; ys = [s[1] for s in S]
        x0, x1 = max(int(min(xs)), 0), min(int(max(xs)) + 1, R)
        y0, y1 = max(int(min(ys)), 0), min(int(max(ys)) + 1, R)
        if x0 >= x1 or y0 >= y1: continue
        gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        (ax, ay, az), (bx, by, bz), (cx, cy, cz) = S
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9: continue
        w1 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
        w2 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / den
        w3 = 1 - w1 - w2
        inside = (w1 >= -1e-4) & (w2 >= -1e-4) & (w3 >= -1e-4)
        z = w1 * az + w2 * bz + w3 * cz
        sub = zbuf[y0:y1, x0:x1]
        upd = inside & (z < sub)
        sub[upd] = z[upd]
        img[y0:y1, x0:x1][upd] = shade
        mask[y0:y1, x0:x1][upd] = 1

def top_color(n):
    diff = max(0.0, n @ L)
    h = (L + V); h /= np.linalg.norm(h)
    spec = max(0.0, n @ h) ** 40
    return min(1.0, 0.42 + 0.62 * diff + 0.35 * spec)

def side_color(n):
    return 0.22 + 0.3 * max(0.0, n @ L)

def footprint(rot, dx, dy):
    pts = [project(rotz(np.array((x + 0, y + 0, 0.0)), rot) + np.array([dx, dy, 0]))[:2] for x, y in outline]
    return pts

from PIL import ImageDraw
sheet = Image.new("RGBA", (FRAME * COLS, FRAME * (N // COLS)), (0, 0, 0, 0))
for k in range(N):
    rot = 2 * math.pi * k / N
    img = np.zeros((R, R)); zbuf = np.full((R, R), np.inf); mask = np.zeros((R, R))
    raster(SIDE, rot, side_color, img, zbuf, mask)
    raster(TOP, rot, top_color, img, zbuf, mask)

    # sombra no chão (pegada da seta deslocada para longe da luz, borrada)
    sh = Image.new("L", (R, R), 0)
    ImageDraw.Draw(sh).polygon(footprint(rot, 0.10, -0.06), fill=150)
    sh = sh.filter(ImageFilter.GaussianBlur(SS * 3))
    # contorno escuro: máscara dilatada
    m = Image.fromarray((mask * 255).astype(np.uint8))
    ol = m.filter(ImageFilter.MaxFilter(2 * SS + 1)).filter(ImageFilter.GaussianBlur(SS * 0.6))

    sa = np.asarray(sh, float) / 255
    oa = np.asarray(ol, float) / 255
    ma = mask
    # composição: sombra -> contorno -> seta
    out_a = sa
    out_v = np.zeros((R, R))
    out_v = out_v * (1 - oa) + 0.06 * oa; out_a = oa + out_a * (1 - oa)
    out_v = out_v * (1 - ma) + img * ma;  out_a = ma + out_a * (1 - ma)
    v8 = np.clip(out_v * 255, 0, 255).astype(np.uint8)
    a8 = np.clip(out_a * 255, 0, 255).astype(np.uint8)
    frame = Image.merge("RGBA", [Image.fromarray(v8)] * 3 + [Image.fromarray(a8)])
    frame = frame.resize((FRAME, FRAME), Image.LANCZOS)
    sheet.paste(frame, ((k % COLS) * FRAME, (k // COLS) * FRAME))

sheet.save(sys.argv[2])
W, H = sheet.size
px = np.asarray(sheet)[:, :, [2, 1, 0, 3]].tobytes()  # BGRA, de cima para baixo
header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, W, H, 32, 0x28)
open(sys.argv[1], "wb").write(header + px)
