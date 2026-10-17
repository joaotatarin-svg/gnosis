#!/usr/bin/env python3
"""Gera TODA a arte de loja (Steam) do GNOSIS a partir da arte pintada que já
está no projeto + capturas reais do jogo. Determinístico: mesmas fontes ->
mesmos PNGs (sementes fixas, sem relógio, sem IA).

Fontes usadas (somente leitura):
  assets/painted/src/sophia_s10_a.png   Sophia (pose "alcança a luz", fundo magenta)
  assets/painted/derived/sophia.png     Sophia (pose de magia, com alfa)
  assets/painted/derived/yaldabaoth.png O Rei/Yaldabaoth + o Olho
  assets/painted/derived/archons.png    os Arcontes
  assets/backgrounds/eon_8_far.png      a Mente (céu com o olho)
  assets/backgrounds/eon_0_far.png      o Limiar (janela da lua)
  assets/fonts/cinzel_decorative/CinzelDecorative-Bold.ttf (OFL)
  /home/user/caps/loja/raw/sN_NNN.png   quadros 1920x1080 do jogo (tools/store/capture.sh; fora do git)

Saída: assets/store/ (tem .gdignore — não entra no jogo).
Uso:  python3 tools/store/build_store.py            (tudo)
      python3 tools/store/build_store.py --only header,main
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "store")


def P(*a):
    return os.path.join(ROOT, *a)


# Paleta do CodexStyle (docs/UI.md) -------------------------------------------
INK = (10, 21, 28)
INK_DEEP = (6, 13, 18)
PAPER = (238, 228, 205)
GOLD = (197, 165, 106)
GOLD_HI = (236, 212, 152)
GOLD_LO = (111, 90, 53)
SPARK = (255, 240, 191)
LIFE = (201, 71, 91)      # carmim
ETHER_HI = (166, 225, 245)

FONT_LOGO = P("assets", "fonts", "cinzel_decorative", "CinzelDecorative-Bold.ttf")

# --------------------------------------------------------------------------
# utilidades de imagem (float32 0..1, RGBA)
# --------------------------------------------------------------------------


def to_np(im):
    return np.asarray(im.convert("RGBA"), dtype=np.float32) / 255.0


def to_im(a):
    return Image.fromarray(np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8), "RGBA")


def dilate(mask, r):
    """Dilatação aproximada e rápida (borrão + limiar) — MaxFilter grande é lento."""
    if r <= 1:
        return mask.filter(ImageFilter.MaxFilter(3))
    b = mask.filter(ImageFilter.GaussianBlur(r * 0.6))
    return b.point(lambda v: 255 if v > 24 else int(v * 255 / 24))


def blur(im, r):
    return im.filter(ImageFilter.GaussianBlur(r)) if r > 0 else im


def over(dst, src, xy=(0, 0)):
    """Compõe src (RGBA) sobre dst (RGBA) na posição xy (pode ser negativa)."""
    x, y = int(round(xy[0])), int(round(xy[1]))
    sx0, sy0 = max(0, -x), max(0, -y)
    dx0, dy0 = max(0, x), max(0, y)
    w = min(src.width - sx0, dst.width - dx0)
    h = min(src.height - sy0, dst.height - dy0)
    if w <= 0 or h <= 0:
        return
    dst.alpha_composite(src.crop((sx0, sy0, sx0 + w, sy0 + h)), dest=(dx0, dy0))


def add_light(dst, light, strength=1.0):
    """Soma luz (modo 'screen') de uma imagem RGBA (cor * alfa) sobre dst."""
    d = to_np(dst)
    l = to_np(light)
    c = l[..., :3] * l[..., 3:4] * strength
    d[..., :3] = 1.0 - (1.0 - d[..., :3]) * (1.0 - np.clip(c, 0, 1))
    return to_im(d)


def tint_alpha(mask, color, alpha=1.0):
    """Máscara L -> camada RGBA de cor sólida."""
    layer = Image.new("RGBA", mask.size, color + (0,))
    a = mask.point(lambda v: int(v * alpha))
    layer.putalpha(a)
    return layer


def fit_cover(im, w, h, cx=0.5, cy=0.5, zoom=1.0):
    """Redimensiona para COBRIR w×h e recorta em torno de (cx, cy) normalizado."""
    s = max(w / im.width, h / im.height) * zoom
    nw, nh = max(w, int(round(im.width * s))), max(h, int(round(im.height * s)))
    r = im.resize((nw, nh), Image.LANCZOS)
    x = int(round(cx * nw - w / 2))
    y = int(round(cy * nh - h / 2))
    x = min(max(0, x), nw - w)
    y = min(max(0, y), nh - h)
    return r.crop((x, y, x + w, y + h))


def sharpen_up(im, scale):
    """Depois de ampliar uma pintura: devolve um pouco de nitidez."""
    if scale <= 1.15:
        return im
    rad = min(3.0, 0.8 * scale)
    return im.filter(ImageFilter.UnsharpMask(radius=rad, percent=70, threshold=2))


def grade(im, mul=(1, 1, 1), lift=(0, 0, 0), sat=1.0, gamma=1.0):
    a = to_np(im)
    rgb = a[..., :3]
    if sat != 1.0:
        lum = (rgb * np.array([0.299, 0.587, 0.114], np.float32)).sum(-1, keepdims=True)
        rgb = lum + (rgb - lum) * sat
    rgb = np.clip(rgb, 0, 1) ** gamma
    rgb = rgb * np.array(mul, np.float32) + np.array(lift, np.float32)
    a[..., :3] = rgb
    return to_im(a)


def vignette(w, h, strength=0.6, cx=0.5, cy=0.5, power=2.2, color=INK_DEEP):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx = (xx / w - cx) * (w / max(w, h)) * 2
    dy = (yy / h - cy) * (h / max(w, h)) * 2
    d = np.sqrt(dx * dx + dy * dy)
    a = np.clip(d / 1.25, 0, 1) ** power * strength
    out = np.zeros((h, w, 4), np.float32)
    out[..., :3] = np.array(color, np.float32) / 255
    out[..., 3] = a
    return to_im(out)


def linear_shade(w, h, y0, y1, a0, a1, color=INK_DEEP, axis="y"):
    """Degradê linear de opacidade (para escurecer topo/base/lado)."""
    n = h if axis == "y" else w
    t = np.clip((np.arange(n, dtype=np.float32) / max(1, n - 1) - y0) / max(1e-6, y1 - y0), 0, 1)
    t = t * t * (3 - 2 * t)
    al = a0 + (a1 - a0) * t
    out = np.zeros((h, w, 4), np.float32)
    out[..., :3] = np.array(color, np.float32) / 255
    out[..., 3] = al[:, None] if axis == "y" else al[None, :]
    return to_im(out)


def radial_glow(w, h, cx, cy, r, color, alpha=1.0, power=2.0):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / max(1.0, r)
    a = np.clip(1 - d, 0, 1) ** power * alpha
    out = np.zeros((h, w, 4), np.float32)
    out[..., :3] = np.array(color, np.float32) / 255
    out[..., 3] = a
    return to_im(out)


def fog(w, h, seed, scale=0.18, alpha=0.35, color=(120, 60, 90), y0=0.55, y1=1.0):
    """Névoa determinística: ruído em baixa resolução, ampliado e borrado."""
    rng = np.random.default_rng(seed)
    sw, sh = max(4, int(w * scale / 16)), max(4, int(h * scale / 16))
    n = rng.random((sh, sw)).astype(np.float32)
    nim = Image.fromarray((n * 255).astype(np.uint8), "L").resize((w, h), Image.BICUBIC)
    nim = blur(nim, max(w, h) / 60)
    n = np.asarray(nim, np.float32) / 255
    n = np.clip((n - 0.35) * 1.8, 0, 1)
    yy = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    band = np.clip((yy - y0) / max(1e-6, (y1 - y0)), 0, 1)
    band = np.sin(band * np.pi * 0.5 + 0.0) * (yy > y0)
    out = np.zeros((h, w, 4), np.float32)
    out[..., :3] = np.array(color, np.float32) / 255
    out[..., 3] = n * band * alpha
    return to_im(out)


def motes(w, h, seed, n=60, color=SPARK, rmin=0.6, rmax=2.4, region=(0, 0, 1, 1), alpha=0.9):
    """Faíscas/poeira de luz determinísticas."""
    rng = np.random.default_rng(seed)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    k = max(w, h) / 1232.0
    for _ in range(n):
        x = (region[0] + rng.random() * (region[2] - region[0])) * w
        y = (region[1] + rng.random() * (region[3] - region[1])) * h
        r = (rmin + rng.random() ** 2.5 * (rmax - rmin)) * k
        a = int(255 * alpha * (0.35 + 0.65 * rng.random()))
        d.ellipse((x - r, y - r, x + r, y + r), fill=color + (a,))
    glow = blur(layer, 3.0 * k)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out = Image.alpha_composite(out, glow)
    out = Image.alpha_composite(out, glow)
    out = Image.alpha_composite(out, layer)
    return out


def radial_rays(im_light, cx, cy, steps=24, zoom=0.012):
    """Raios de luz ('god rays'): borrão radial por ampliações sucessivas."""
    acc = np.zeros(to_np(im_light).shape, np.float32)
    w, h = im_light.size
    for i in range(steps):
        s = 1.0 + zoom * i
        nw, nh = int(w * s), int(h * s)
        r = im_light.resize((nw, nh), Image.BILINEAR)
        x0 = int(cx * s - cx)
        y0 = int(cy * s - cy)
        acc += to_np(r.crop((x0, y0, x0 + w, y0 + h))) * (1.0 - i / steps)
    acc /= steps / 2.0
    return to_im(np.clip(acc, 0, 1))


# --------------------------------------------------------------------------
# recorte dos personagens
# --------------------------------------------------------------------------


def key_magenta(im):
    """Fundo magenta -> alfa, com remoção do respingo de magenta na borda."""
    a = np.asarray(im.convert("RGB"), np.float32) / 255
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # "magentice": quanto R e B dominam o G
    m = np.minimum(r, b) - g
    alpha = 1.0 - np.clip((m - 0.25) / 0.45, 0, 1)
    # tira o respingo: limita R e B ao G + margem na borda
    edge = (alpha < 0.999) | (m > 0.12)
    cap = g + 0.12
    r2 = np.where(edge, np.minimum(r, np.maximum(cap, g + (r - g) * 0.4)), r)
    b2 = np.where(edge, np.minimum(b, np.maximum(cap, g + (b - g) * 0.4)), b)
    out = np.dstack([r2, g, b2, alpha]).astype(np.float32)
    # respingo dentro dos fios de cabelo (perto da borda): puxa R/B para o G
    near = np.asarray(Image.fromarray((alpha < 0.98).astype(np.uint8) * 255).filter(ImageFilter.GaussianBlur(6)), np.float32) / 255
    mm = np.minimum(out[..., 0], out[..., 2]) - out[..., 1]
    sup = np.clip(mm - 0.04, 0, 1) * np.clip(near * 3, 0, 1) * 0.9
    out[..., 0] -= sup
    out[..., 2] -= sup
    im2 = to_im(out)
    # alfa um pouco mais justo e suave (tira franja)
    al = im2.getchannel("A").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
    im2.putalpha(al)
    return im2


def trim(im, pad=4):
    bb = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if bb is None:
        return im
    x0, y0, x1, y1 = bb
    return im.crop((max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad)))


def largest_only(im):
    """Mantém só o maior blob (tira pedaços de quadros vizinhos)."""
    al = np.asarray(im.getchannel("A")) > 20
    h, w = al.shape
    # rotulagem simples por varredura em baixa resolução
    small = Image.fromarray((al * 255).astype(np.uint8)).resize((w // 4 + 1, h // 4 + 1), Image.NEAREST)
    s = np.asarray(small) > 0
    lab = np.zeros(s.shape, np.int32)
    cur = 0
    sizes = {}
    for y in range(s.shape[0]):
        for x in range(s.shape[1]):
            if s[y, x] and lab[y, x] == 0:
                cur += 1
                stack = [(y, x)]
                lab[y, x] = cur
                cnt = 0
                while stack:
                    cy, cx = stack.pop()
                    cnt += 1
                    for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1), (cy + 1, cx + 1), (cy - 1, cx - 1), (cy + 1, cx - 1), (cy - 1, cx + 1)):
                        if 0 <= ny < s.shape[0] and 0 <= nx < s.shape[1] and s[ny, nx] and lab[ny, nx] == 0:
                            lab[ny, nx] = cur
                            stack.append((ny, nx))
                sizes[cur] = cnt
    if not sizes:
        return im
    keep = max(sizes, key=sizes.get)
    m = Image.fromarray(((lab == keep) * 255).astype(np.uint8)).resize(small.size, Image.NEAREST)
    m = m.resize((w, h), Image.NEAREST).filter(ImageFilter.MaxFilter(9))
    out = im.copy()
    out.putalpha(ImageChops.multiply(im.getchannel("A"), m))
    return out


_cache = {}


def sprite(name):
    """Personagens recortados (RGBA, aparados)."""
    if name in _cache:
        return _cache[name]
    if name == "sophia_reach":       # mão erguida para a luz
        src = Image.open(P("assets", "painted", "src", "sophia_s10_a.png"))
        im = largest_only(key_magenta(src.crop((540, 10, 1000, 512))))
    elif name == "sophia_cast":      # orbe de luz na mão
        src = Image.open(P("assets", "painted", "derived", "sophia.png")).convert("RGBA")
        im = largest_only(src.crop((1100, 512, 1500, 1000)))
    elif name == "sophia_staff":     # cajado erguido
        src = Image.open(P("assets", "painted", "src", "sophia_s7_b.png"))
        im = largest_only(key_magenta(src.crop((40, 0, 520, 500))))
    elif name == "rei":
        src = Image.open(P("assets", "painted", "derived", "yaldabaoth.png")).convert("RGBA")
        im = largest_only(src.crop((0, 0, 1062, 1024)))
    elif name == "eye":
        src = Image.open(P("assets", "painted", "derived", "yaldabaoth.png")).convert("RGBA")
        im = largest_only(src.crop((1062, 140, 1470, 710)))
    elif name.startswith("archon"):
        k = int(name[6:])            # 0..7 (2 linhas × 4 colunas)
        src = Image.open(P("assets", "painted", "derived", "archons.png")).convert("RGBA")
        col, row = k % 4, k // 4
        im = largest_only(src.crop((col * 384, row * 512, col * 384 + 384, row * 512 + 512)))
    else:
        raise KeyError(name)
    im = trim(im)
    _cache[name] = im
    return im


# pontos de luz no sprite (fração da largura/altura do recorte aparado)
ANCHORS = {
    "sophia_reach": {"hand": (0.955, -0.035), "orb": (0.14, 0.165)},
}


def star_flare(w, h, x, y, r, color=SPARK):
    """Brilho de 4 pontas (a faísca)."""
    ss = 2
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    t = max(1.0, r * 0.05)
    d.polygon([(x - r, y), (x, y - t), (x + r, y), (x, y + t)], fill=255)
    d.polygon([(x, y - r * 1.25), (x + t, y), (x, y + r * 0.8), (x - t, y)], fill=255)
    rr = r * 0.4
    d.polygon([(x - rr, y - rr), (x + t * 0.5, y - t * 0.5), (x + rr, y + rr), (x - t * 0.5, y + t * 0.5)], fill=110)
    d.polygon([(x + rr, y - rr), (x + t * 0.5, y + t * 0.5), (x - rr, y + rr), (x - t * 0.5, y - t * 0.5)], fill=110)
    im = blur(im, max(0.6, r * 0.012))
    return tint_alpha(im, color, 1.0)


def place(canvas, im, cx, foot, height, flip=False, shadow=0.0):
    """Põe o sprite com altura `height` px, centro x `cx`, pés em `foot`."""
    s = height / im.height
    r = im.resize((max(1, int(round(im.width * s))), max(1, int(round(im.height * s)))), Image.LANCZOS)
    r = sharpen_up(r, s)
    if flip:
        r = r.transpose(Image.FLIP_LEFT_RIGHT)
    x = cx - r.width / 2
    y = foot - r.height
    return r, (x, y)


def rim_light(sp, color, width, strength=1.0, side=None):
    """Luz de recorte: borda do alfa, colorida; `side` = (dx, dy) da luz."""
    al = sp.getchannel("A")
    shrink = al.filter(ImageFilter.MinFilter(max(3, int(width) | 1)))
    if side is not None:
        dx, dy = side
        shrink = ImageChops.offset(al, int(-dx * width), int(-dy * width))
        shrink = ImageChops.multiply(shrink, al)
    edge = ImageChops.subtract(al, shrink)
    edge = blur(edge, width * 0.35)
    edge = ImageChops.multiply(edge, al)
    return tint_alpha(edge, color, strength)


def darken_sprite(sp, mul, lift=(0, 0, 0), sat=1.0):
    return grade(sp, mul=mul, lift=lift, sat=sat)


def outer_glow(sp, color, radius, alpha):
    al = blur(sp.getchannel("A"), radius)
    return tint_alpha(al, color, alpha)


# --------------------------------------------------------------------------
# o logotipo GNOSIS
# --------------------------------------------------------------------------


def logo(width, glow=True, tracking=0.06, bg_shadow=True):
    """Logotipo 'GNOSIS' (Cinzel Decorative Bold) em ouro, com contorno de
    tinta e brilho. Devolve RGBA aparado, com `width` px de largura útil."""
    text = "GNOSIS"
    ss = 2  # superamostragem
    size = 400
    font = ImageFont.truetype(FONT_LOGO, size * ss)
    # mede letra a letra (tracking)
    adv = []
    for ch in text:
        adv.append(font.getlength(ch))
    track = tracking * size * ss
    tw = sum(adv) + track * (len(text) - 1)
    asc, desc = font.getmetrics()
    pad = int(size * ss * 0.5)
    W, H = int(tw + pad * 2), int(asc + desc + pad * 2)
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    x = pad
    for ch, a in zip(text, adv):
        d.text((x, pad), ch, font=font, fill=255)
        x += a + track
    mask = mask.resize((W // ss, H // ss), Image.LANCZOS)
    W, H = mask.size
    bb = mask.getbbox()
    gy0, gy1 = bb[1], bb[3]
    # preenchimento: ouro em degradê vertical com faixa de brilho
    yy = np.linspace(0, 1, H, dtype=np.float32)
    t = np.clip((yy - gy0 / H) / max(1e-6, (gy1 - gy0) / H), 0, 1)
    stops = [(0.0, GOLD_HI), (0.18, SPARK), (0.42, GOLD_HI), (0.58, GOLD), (0.78, (168, 132, 74)), (1.0, GOLD_LO)]
    col = np.zeros((H, 3), np.float32)
    for (t0, c0), (t1, c1) in zip(stops[:-1], stops[1:]):
        k = np.clip((t - t0) / (t1 - t0), 0, 1)[:, None]
        sel = ((t >= t0) & (t <= t1))[:, None]
        col = np.where(sel, np.array(c0, np.float32) * (1 - k) + np.array(c1, np.float32) * k, col)
    fill = np.zeros((H, W, 4), np.float32)
    fill[..., :3] = (col / 255)[:, None, :]
    fill[..., 3] = np.asarray(mask, np.float32) / 255
    fill_im = to_im(fill)
    # bisel: realce no topo das letras (máscara deslocada)
    m_np = np.asarray(mask, np.float32) / 255
    up = np.asarray(ImageChops.offset(mask, 0, 3).filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255
    bevel = np.clip(m_np - up, 0, 1)
    hi = np.zeros((H, W, 4), np.float32)
    hi[..., :3] = np.array(SPARK, np.float32) / 255
    hi[..., 3] = bevel * 0.9
    # contorno de tinta (ink) e sombra
    ow = max(2, int(size * 0.035))
    outline = dilate(mask, ow)
    outline = blur(outline, 0.8)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if bg_shadow:
        sh = blur(dilate(mask, ow * 2), size * 0.08)
        out = Image.alpha_composite(out, tint_alpha(sh, INK_DEEP, 0.85))
    if glow:
        g = blur(mask, size * 0.12)
        out = Image.alpha_composite(out, tint_alpha(g, (224, 150, 80), 0.55))
    out = Image.alpha_composite(out, tint_alpha(outline, INK_DEEP, 1.0))
    # filete interno escuro dá peso de gravura
    out = Image.alpha_composite(out, fill_im)
    out = Image.alpha_composite(out, to_im(hi))
    out = trim(out, pad=int(size * 0.02))
    s = width / out.width
    return out.resize((int(round(out.width * s)), int(round(out.height * s))), Image.LANCZOS)


def logo_ornament(width, color=GOLD):
    """Filete com losango central (assinatura do Códex) — sob o título."""
    h = max(6, int(width * 0.05))
    ss = 4
    im = Image.new("RGBA", (width * ss, h * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cy = h * ss / 2
    lw = max(1, int(width * ss * 0.004))
    d.line((0, cy, width * ss * 0.44, cy), fill=color + (255,), width=lw)
    d.line((width * ss * 0.56, cy, width * ss, cy), fill=color + (255,), width=lw)
    r = h * ss * 0.42
    c = width * ss / 2
    d.polygon([(c, cy - r), (c + r, cy), (c, cy + r), (c - r, cy)], fill=SPARK + (255,))
    for k in (-1, 1):
        cx = c + k * width * ss * 0.035
        r2 = r * 0.45
        d.polygon([(cx, cy - r2), (cx + r2, cy), (cx, cy + r2), (cx - r2, cy)], fill=color + (255,))
    im = im.resize((width, h), Image.LANCZOS)
    # fade nas pontas
    a = np.asarray(im.getchannel("A"), np.float32)
    x = np.linspace(-1, 1, width, dtype=np.float32)
    fade = np.clip((1 - np.abs(x)) * 3.0, 0, 1)
    im.putalpha(Image.fromarray((a * fade[None, :]).astype(np.uint8)))
    return im


# --------------------------------------------------------------------------
# a cena-chave (key art)
# --------------------------------------------------------------------------


# "mente" = céu carmim com o Olho (eon_8); "limiar" = catedral azul da lua (eon_0),
# onde o jogo começa (a luta com o Rei).
PALETTES = {
    "mente": {"bg_mul": (1.0, 0.86, 0.92), "bg_lift": (0.012, 0.0, 0.01), "bg_sat": 0.9, "bg_gamma": 1.12,
              "sky_glow": (230, 90, 110), "rays": (255, 170, 160), "rei_mul": (0.82, 0.64, 0.66),
              "rei_glow": (190, 40, 80), "rei_rim": (255, 140, 150), "fog": (110, 50, 80)},
    "limiar": {"bg_mul": (0.92, 1.0, 1.05), "bg_lift": (0.0, 0.005, 0.015), "bg_sat": 0.95, "bg_gamma": 1.1,
               "sky_glow": (150, 210, 240), "rays": (200, 235, 255), "rei_mul": (0.78, 0.76, 0.76),
               "rei_glow": (60, 110, 160), "rei_rim": (190, 230, 255), "fog": (50, 90, 120)},
}


def key_art(W, H, L):
    """Monta a cena: fundo da Mente (olho no céu), o Rei ao fundo, a Sophia
    na frente alcançando a luz. `L` = dicionário de layout (frações de W/H)."""
    k = H / 706.0  # escala de referência (cápsula principal 2x)
    bg = Image.open(P("assets", "backgrounds", L.get("bg", "eon_8_far.png"))).convert("RGBA")
    zoom = L.get("bg_zoom", 1.0)
    scale = max(W / bg.width, H / bg.height) * zoom
    base = fit_cover(bg, W, H, L.get("bg_cx", 0.55), L.get("bg_cy", 0.45), zoom)
    base = sharpen_up(base, scale)
    pal = PALETTES[L.get("pal", "mente")]
    base = grade(base, mul=pal["bg_mul"], lift=pal["bg_lift"], sat=pal["bg_sat"], gamma=pal["bg_gamma"])
    canvas = base

    # a fonte de luz do céu (o Olho / a lua): dada em fração da imagem de fundo
    if "light_src" in L:
        nw, nh = bg.width * scale, bg.height * scale
        ox = min(max(0.0, L.get("bg_cx", 0.55) * nw - W / 2), nw - W)
        oy = min(max(0.0, L.get("bg_cy", 0.45) * nh - H / 2), nh - H)
        ex = (L["light_src"][0] * nw - ox) / W
        ey = (L["light_src"][1] * nh - oy) / H
    else:
        ex, ey = L.get("eye_xy", (0.7, 0.2))
    er = L.get("eye_r", 0.22) * H
    canvas = add_light(canvas, radial_glow(W, H, ex * W, ey * H, er * 1.6, pal["sky_glow"], 0.45, 1.6))
    if L.get("rays", True):
        bright = to_np(canvas)
        lum = bright[..., :3].mean(-1)
        m = np.clip((lum - 0.42) * 3.0, 0, 1)
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        dist = np.sqrt((xx - ex * W) ** 2 + (yy - ey * H) ** 2) / (er * 2.4)
        m *= np.clip(1 - dist, 0, 1)
        li = np.zeros((H, W, 4), np.float32)
        li[..., :3] = np.array(pal["rays"], np.float32) / 255
        li[..., 3] = m
        rays = radial_rays(to_im(li), ex * W, ey * H, steps=26, zoom=0.03)
        canvas = add_light(canvas, rays, 0.55)

    # Arcontes como silhuetas ao longe (opcional)
    for (name, cx, foot, hh, al) in L.get("archons", []):
        sp = sprite(name)
        r, xy = place(canvas, sp, cx * W, foot * H, hh * H)
        r = darken_sprite(r, (0.32, 0.2, 0.28), lift=(0.03, 0.01, 0.03), sat=0.4)
        r.putalpha(r.getchannel("A").point(lambda v: int(v * al)))
        over(canvas, r, xy)
        canvas.alpha_composite(fog(W, H, 11, alpha=0.25, color=pal["fog"], y0=0.5))

    # O REI: grande, ao fundo, na sombra; a luz do Olho o recorta por trás
    if L.get("rei"):
        cx, foot, hh = L["rei"]
        sp = sprite("rei")
        flip = L.get("rei_flip", True)
        r, xy = place(canvas, sp, cx * W, foot * H, hh * H, flip=flip)
        lit = grade(r, mul=pal["rei_mul"], sat=0.75, gamma=1.35)
        # base do manto some na névoa (degradê vertical no alfa)
        al = np.asarray(lit.getchannel("A"), np.float32)
        t = np.linspace(0, 1, lit.height, dtype=np.float32)[:, None]
        fade = 1.0 - np.clip((t - 0.62) / 0.38, 0, 1) ** 1.4 * 0.75
        lit.putalpha(Image.fromarray((al * fade).astype(np.uint8)))
        over(canvas, outer_glow(r, pal["rei_glow"], 30 * k, 0.5), xy)
        over(canvas, lit, xy)
        over(canvas, rim_light(r, pal["rei_rim"], 7 * k, 0.75, side=(1 if flip else -1, -1)), xy)

    # névoa no chão e entre os planos
    canvas.alpha_composite(fog(W, H, 3, alpha=0.42, color=pal["fog"], y0=0.55))
    canvas.alpha_composite(linear_shade(W, H, 0.62, 1.0, 0.0, 0.85))

    # SOPHIA: em primeiro plano, saltando para a luz (faísca na mão erguida)
    if L.get("sophia"):
        name, cx, foot, hh = L["sophia"]
        sp = sprite(name)
        flip = L.get("sophia_flip", False)
        r, xy = place(canvas, sp, cx * W, foot * H, hh * H, flip=flip)

        def anchor(fx, fy):
            fx = 1.0 - fx if flip else fx
            return xy[0] + fx * r.width, xy[1] + fy * r.height

        over(canvas, outer_glow(r, (255, 226, 170), 40 * k, 0.22), xy)
        over(canvas, grade(r, mul=(1.04, 1.0, 0.97), sat=1.05), xy)
        over(canvas, rim_light(r, SPARK, 5 * k, 0.85, side=(1 if flip else -1, -0.8)), xy)
        anc = ANCHORS.get(name, {})
        if "orb" in anc:          # gema do cajado acesa (Éter)
            ox, oy = anchor(*anc["orb"])
            canvas = add_light(canvas, radial_glow(W, H, ox, oy, 60 * k, ETHER_HI, 0.7, 2.0))
        if "hand" in anc:         # a faísca que ela alcança
            hx, hy = anchor(*anc["hand"])
            canvas = add_light(canvas, radial_glow(W, H, hx, hy, 300 * k, (255, 196, 140), 0.32, 1.4))
            canvas = add_light(canvas, radial_glow(W, H, hx, hy, 90 * k, SPARK, 0.95, 2.0))
            canvas.alpha_composite(star_flare(W, H, hx, hy, 120 * k))

    # faíscas subindo
    canvas.alpha_composite(motes(W, H, 7, n=int(L.get("motes", 70)), region=L.get("motes_region", (0, 0.1, 1, 0.95))))
    canvas.alpha_composite(vignette(W, H, L.get("vig", 0.75), cx=L.get("vig_cx", 0.5), cy=0.5))
    return canvas


def put_title(canvas, cx, cy, width, ornament=True, darken=0.5):
    """Título GNOSIS centrado em (cx, cy) com `width` px."""
    W, H = canvas.size
    lg = logo(int(width))
    if darken > 0:
        # sombra difusa atrás do título (legibilidade)
        pad = int(lg.height * 0.9)
        back = Image.new("RGBA", (lg.width + pad * 2, lg.height + pad * 2), (0, 0, 0, 0))
        dd = ImageDraw.Draw(back)
        dd.ellipse((pad * 0.4, pad * 0.55, back.width - pad * 0.4, back.height - pad * 0.55), fill=INK_DEEP + (int(255 * darken),))
        back = blur(back, pad * 0.45)
        over(canvas, back, (cx - back.width / 2, cy - back.height / 2))
    over(canvas, lg, (cx - lg.width / 2, cy - lg.height / 2))
    if ornament:
        orn = logo_ornament(int(width * 0.78))
        over(canvas, orn, (cx - orn.width / 2, cy + lg.height * 0.5 + orn.height * 0.4))
    return canvas


def finish(im):
    return im.convert("RGB")


# --------------------------------------------------------------------------
# peças
# --------------------------------------------------------------------------

# layouts (frações de W/H). Sophia à esquerda saltando para a direita
# (onde estão o Rei e a luz do céu). Variante "a" = a Mente (céu carmim com o
# Olho); variante "b" = o Limiar (catedral azul da lua, onde o jogo começa).
VARIANTS = {
    "a": {"pal": "mente", "bg": "eon_8_far.png", "light_src": (0.71, 0.18)},
    "b": {"pal": "limiar", "bg": "eon_0_far.png", "light_src": (0.665, 0.19)},
}


def lay(v, **kw):
    L = {"bg_cx": 0.70, "bg_cy": 0.40, "bg_zoom": 1.05, "eye_r": 0.2,
         "rei": (0.77, 1.05, 1.0), "sophia": ("sophia_reach", 0.33, 1.02, 0.78), "vig": 0.7}
    L.update(VARIANTS[v])
    L.update(kw)
    return L


def make_main(W, H, v="a"):
    c = key_art(W, H, lay(v))
    put_title(c, W * 0.235, H * 0.14, W * 0.40, ornament=False, darken=0.45)
    return finish(c)


def make_header(W, H, v="a"):
    c = key_art(W, H, lay(v, sophia=("sophia_reach", 0.20, 1.02, 0.92), rei=(0.86, 1.06, 1.0)))
    put_title(c, W * 0.56, H * 0.5, W * 0.52, darken=0.55)
    return finish(c)


def make_small(W, H, v="a"):
    c = key_art(W, H, lay(v, sophia=("sophia_reach", 0.11, 1.05, 1.0), rei=(0.93, 1.1, 1.1), motes=25))
    put_title(c, W * 0.54, H * 0.5, W * 0.66, ornament=False, darken=0.6)
    return finish(c)


def make_vertical(W, H, v="a"):
    c = key_art(W, H, lay(v, bg_cx=0.72, bg_cy=0.4, rei=(0.72, 0.86, 0.66),
                          sophia=("sophia_reach", 0.42, 0.99, 0.52), vig=0.8))
    put_title(c, W * 0.5, H * 0.83, W * 0.82, darken=0.6)
    return finish(c)


def make_library(W, H, v="a"):
    c = key_art(W, H, lay(v, bg_cx=0.72, bg_cy=0.4, rei=(0.66, 0.78, 0.56),
                          sophia=("sophia_reach", 0.42, 0.96, 0.44), vig=0.8))
    put_title(c, W * 0.5, H * 0.86, W * 0.8, darken=0.6)
    return finish(c)


def make_hero(W, H, v="a"):
    # sem texto; o Steam põe o logo por cima, embaixo à esquerda — o centro
    # e a direita levam a cena.
    return finish(key_art(W, H, lay(v, bg_cx=0.6, bg_cy=0.42, eye_r=0.22, rei=(0.72, 1.04, 0.98),
                                     sophia=("sophia_reach", 0.44, 0.98, 0.78), motes=160, vig=0.55)))


def make_logo():
    lg = logo(1600)
    orn = logo_ornament(int(1600 * 0.78))
    pad = 40
    out = Image.new("RGBA", (lg.width + pad * 2, lg.height + orn.height * 2 + pad * 2), (0, 0, 0, 0))
    over(out, lg, (pad, pad))
    over(out, orn, ((out.width - orn.width) / 2, pad + lg.height + orn.height * 0.4))
    return trim(out, pad=8)


# ícone: o Olho do Rei sobre carmim, com aro de ouro
def make_icon_eye(S):
    ss = 2
    N = S * ss
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    # disco de fundo
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    d = np.sqrt((xx - N / 2) ** 2 + (yy - N / 2) ** 2) / (N / 2)
    rgb = np.zeros((N, N, 4), np.float32)
    inner = np.array((110, 24, 44), np.float32) / 255
    outer = np.array((22, 8, 18), np.float32) / 255
    t = np.clip(d, 0, 1)[..., None]
    rgb[..., :3] = inner * (1 - t) + outer * t
    rgb[..., 3] = np.clip((0.985 - d) * N * 0.5, 0, 1)
    im = to_im(rgb)
    eye = sprite("eye")
    s = (N * 0.78) / max(eye.width, eye.height)
    e = eye.resize((int(eye.width * s), int(eye.height * s)), Image.LANCZOS)
    e = grade(e, mul=(1.08, 1.02, 0.95), sat=1.1)
    im.alpha_composite(tint_alpha(blur(e.getchannel("A"), N * 0.03), (255, 200, 120), 0.7), ((N - e.width) // 2, (N - e.height) // 2))
    im.alpha_composite(e, ((N - e.width) // 2, (N - e.height) // 2))
    # aro de ouro
    d2 = ImageDraw.Draw(im)
    w = int(N * 0.035)
    d2.ellipse((w // 2 + 1, w // 2 + 1, N - w // 2 - 2, N - w // 2 - 2), outline=GOLD + (255,), width=w)
    d2.ellipse((w * 1.6, w * 1.6, N - w * 1.6, N - w * 1.6), outline=GOLD_LO + (200,), width=max(1, w // 4))
    return im.resize((S, S), Image.LANCZOS)


# ícone B: Sophia (rosto/cabelo) — mais pessoal; recortado da pose de magia
def make_icon_spark(S):
    ss = 2
    N = S * ss
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    d = np.sqrt((xx - N / 2) ** 2 + (yy - N / 2) ** 2) / (N / 2)
    rgb = np.zeros((N, N, 4), np.float32)
    inner = np.array((40, 70, 92), np.float32) / 255
    outer = np.array(INK_DEEP, np.float32) / 255
    t = np.clip(d, 0, 1)[..., None]
    rgb[..., :3] = inner * (1 - t) + outer * t
    rgb[..., 3] = np.clip((0.985 - d) * N * 0.5, 0, 1)
    im = to_im(rgb)
    # faísca de 4 pontas
    star = Image.new("L", (N, N), 0)
    ds = ImageDraw.Draw(star)
    c = N / 2
    R, r = N * 0.36, N * 0.07
    pts = []
    import math
    for i in range(8):
        ang = -math.pi / 2 + i * math.pi / 4
        rad = R if i % 2 == 0 else r
        pts.append((c + math.cos(ang) * rad, c + math.sin(ang) * rad))
    ds.polygon(pts, fill=255)
    im.alpha_composite(tint_alpha(blur(star, N * 0.06), (255, 200, 120), 0.9))
    im.alpha_composite(tint_alpha(star, SPARK, 1.0))
    im.alpha_composite(tint_alpha(blur(star, N * 0.01), (255, 255, 240), 0.6))
    # 7 anéis (gemas) no aro
    d2 = ImageDraw.Draw(im)
    w = int(N * 0.05)
    rr = N / 2 - w * 1.1
    d2.ellipse((c - rr, c - rr, c + rr, c + rr), outline=GOLD + (255,), width=w)
    gems = [(120, 160, 230), (200, 90, 70), (150, 150, 160), (90, 90, 170), (200, 200, 230), (110, 170, 90), (230, 190, 90)]
    for i, gc in enumerate(gems):
        ang = -math.pi / 2 + i * 2 * math.pi / 7
        gx, gy = c + math.cos(ang) * rr, c + math.sin(ang) * rr
        gr = w * 0.95
        d2.ellipse((gx - gr, gy - gr, gx + gr, gy + gr), fill=gc + (255,), outline=INK_DEEP + (255,), width=max(1, w // 4))
    return im.resize((S, S), Image.LANCZOS)


# --------------------------------------------------------------------------
# capturas de tela: só normaliza (1920x1080, RGB, PNG otimizado)
# --------------------------------------------------------------------------


# Capturas escolhidas (quadros REAIS do jogo, tools/store/capture.sh). Os
# quadros brutos (1920x1080, ~2,7 MB cada) ficam FORA do git, em --raw
# (padrão /home/user/caps/loja/raw); sem eles, as capturas já geradas em
# assets/store/ são mantidas. Saem em JPG q=93 (a Steam aceita JPG/PNG; poupa
# ~2 MB por imagem no repositório).
# (nome final, quadro bruto, o que mostra)
SHOTS = [
    ("01_rei_limiar", "s1_016", "Tela 1: Sophia contra o Rei no Limiar (catedral da lua)"),
    ("02_athoth_magia", "s10_014", "Tela 10: magia de luz contra Athoth, Arconte do Torpor"),
    ("03_galila_corrente", "s28_016", "Tela 28: Galila, Arconte da Corrente, entre gaiolas suspensas"),
    ("04_astaphaios_espelho", "s46_016", "Tela 46: Astaphaios no salão de espelhos"),
    ("05_armupiel_coroa", "s64_010", "Tela 64: golpe contra Armupiel, Arconte da Coroa"),
    ("06_centro_horda", "s65_002", "Tela 65: o Centro, Sophia cercada por criaturas"),
]


def make_screens(raw_dir):
    out = []
    for name, frame, _desc in SHOTS:
        src = os.path.join(raw_dir, frame + ".png")
        dst = os.path.join(OUT, "screenshot_%s.jpg" % name)
        if not os.path.exists(src):
            if os.path.exists(dst):
                print("mantida (sem bruto):", os.path.basename(dst))
            else:
                print("FALTA bruto:", src)
            continue
        im = Image.open(src).convert("RGB")
        if im.size != (1920, 1080):
            im = fit_cover(im.convert("RGBA"), 1920, 1080).convert("RGB")
        im.save(dst, quality=93, subsampling=0, optimize=True)
        out.append(os.path.basename(dst))
    return out


# --------------------------------------------------------------------------
# prancha (para o João escolher) e teste de miniatura
# --------------------------------------------------------------------------


def board(items):
    """Prancha com todas as peças lado a lado (escala real até 616 px)."""
    pad = 24
    lab_h = 22
    cells = []
    for name in items:
        p = os.path.join(OUT, name)
        im = Image.open(p).convert("RGBA")
        if name.startswith("logo"):
            bg = Image.new("RGBA", im.size, (40, 40, 48, 255))
            # xadrez para ver transparência
            ck = 32
            dd = ImageDraw.Draw(bg)
            for y in range(0, im.height, ck):
                for x in range(0, im.width, ck):
                    if (x // ck + y // ck) % 2:
                        dd.rectangle((x, y, x + ck - 1, y + ck - 1), fill=(56, 56, 66, 255))
            bg.alpha_composite(im)
            im = bg
        maxw = 616 if not name.startswith(("hero", "screenshot")) else 940
        if name.startswith("icon_") and im.width <= 512:
            maxw = 256
        if im.width > maxw:
            im = im.resize((maxw, int(im.height * maxw / im.width)), Image.LANCZOS)
        cells.append((name, im))
    # empacota em linhas de até 1960 px
    rows, cur, cw = [], [], 0
    for c in cells:
        if cur and cw + c[1].width + pad > 1960:
            rows.append(cur)
            cur, cw = [], 0
        cur.append(c)
        cw += c[1].width + pad
    if cur:
        rows.append(cur)
    W = 1960 + pad
    top = 70
    H = sum(max(c[1].height for c in r) + lab_h + pad for r in rows) + pad + top
    sheet = Image.new("RGB", (W, H), (18, 18, 22))
    d = ImageDraw.Draw(sheet)
    try:
        lf = ImageFont.truetype(P("assets", "fonts", "alegreya", "Alegreya-VF.ttf"), 16)
        tf = ImageFont.truetype(P("assets", "fonts", "alegreya", "Alegreya-VF.ttf"), 26)
    except OSError:
        lf = tf = ImageFont.load_default()
    d.text((pad, 18), "GNOSIS — prancha da loja. Cada peça tem duas versões: sem sufixo = A (a Mente, carmim);"
           " _b = B (o Limiar, azul). Escolha A ou B por peça, e um dos dois ícones.", fill=(236, 212, 152), font=tf)
    y = pad + top
    for r in rows:
        x = pad
        rh = max(c[1].height for c in r)
        for name, im in r:
            src = Image.open(os.path.join(OUT, name))
            tag = "B" if "_b." in name else ("A" if name.startswith(("capsule", "library_capsule", "hero")) else "")
            d.text((x, y), "%s%s  (%dx%d)" % ("[%s] " % tag if tag else "", name, src.width, src.height), fill=(220, 210, 190), font=lf)
            sheet.paste(im.convert("RGB"), (x, y + lab_h))
            x += im.width + pad
        y += rh + lab_h + pad
    return sheet


def half_test(items):
    """Teste de legibilidade: cada cápsula reduzida a 50%."""
    ims = [Image.open(os.path.join(OUT, n)).convert("RGB") for n in items]
    ims = [i.resize((i.width // 2, i.height // 2), Image.LANCZOS) for i in ims]
    W = sum(i.width for i in ims) + 16 * (len(ims) + 1)
    H = max(i.height for i in ims) + 32
    sheet = Image.new("RGB", (W, H), (18, 18, 22))
    x = 16
    for i in ims:
        sheet.paste(i, (x, 16))
        x += i.width + 16
    return sheet


# --------------------------------------------------------------------------

# (nome-base, tamanho). Cada peça sai nas variantes "a" (Mente) e "b" (Limiar):
# <nome>.png e <nome>_b.png. Tamanhos pedidos + os 2x que o Steamworks pede hoje.
PIECES = {
    "header": [("capsule_header_460x215", (460, 215)), ("capsule_header_920x430", (920, 430))],
    "small": [("capsule_small_231x87", (231, 87)), ("capsule_small_462x174", (462, 174))],
    "main": [("capsule_main_616x353", (616, 353)), ("capsule_main_1232x706", (1232, 706))],
    "vertical": [("capsule_vertical_374x448", (374, 448)), ("capsule_vertical_748x896", (748, 896))],
    "library": [("library_capsule_600x900", (600, 900))],
    "hero": [("hero_3840x1240", (3840, 1240))],
}
MAKERS = {"header": make_header, "small": make_small, "main": make_main,
          "vertical": make_vertical, "library": make_library, "hero": make_hero}


def render_scaled(maker, size, v):
    """Renderiza no tamanho final. Peças pequenas são feitas em 2x e reduzidas
    (o título fica mais limpo)."""
    W, H = size
    if W < 600:
        im = maker(W * 2, H * 2, v)
        return im.resize((W, H), Image.LANCZOS)
    return maker(W, H, v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="", help="lista: header,small,main,vertical,library,hero,logo,icon,screens,board")
    ap.add_argument("--raw", default="/home/user/caps/loja/raw", help="pasta dos quadros brutos (capture.sh)")
    args = ap.parse_args()
    only = set(filter(None, args.only.split(",")))
    want = lambda k: not only or k in only
    os.makedirs(OUT, exist_ok=True)
    gdi = os.path.join(OUT, ".gdignore")
    if not os.path.exists(gdi):
        open(gdi, "w").close()

    made = []
    for key, outs in PIECES.items():
        if not want(key):
            continue
        for base, size in outs:
            for v in VARIANTS:
                fname = base + ("" if v == "a" else "_" + v) + ".png"
                im = render_scaled(MAKERS[key], size, v)
                im.save(os.path.join(OUT, fname), optimize=True)
                print("ok", fname, im.size)
                made.append(fname)
    if want("logo"):
        lg = make_logo()
        lg.save(os.path.join(OUT, "logo_1600.png"), optimize=True)
        # logo da biblioteca (Steam: 1280x720, transparente, logo centrado)
        lib = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
        l2 = lg.resize((1180, int(lg.height * 1180 / lg.width)), Image.LANCZOS)
        over(lib, l2, ((1280 - l2.width) / 2, (720 - l2.height) / 2))
        lib.save(os.path.join(OUT, "logo_library_1280x720.png"), optimize=True)
        print("ok logo", lg.size)
    if want("icon"):
        for tag, fn in (("eye", make_icon_eye), ("spark", make_icon_spark)):
            big = fn(512)
            big.save(os.path.join(OUT, "icon_%s_512.png" % tag), optimize=True)
            # .ico com 256/128/64/48/32/16 (cada tamanho renderizado direto)
            sizes = [256, 128, 64, 48, 32, 16]
            frames = {s: fn(s) for s in sizes}
            frames[256].save(os.path.join(OUT, "icon_%s.ico" % tag), format="ICO",
                             sizes=[(s, s) for s in sizes], append_images=[frames[s] for s in sizes[1:]])
            # prova de miniaturas
            strip = Image.new("RGBA", (sum(sizes) + 8 * 7, 264), (24, 24, 28, 255))
            x = 8
            for s in sizes:
                strip.alpha_composite(frames[s], (x, 4))
                x += s + 8
            strip.save(os.path.join(OUT, "icon_%s_sizes.png" % tag))
            print("ok icon", tag)
    if want("screens"):
        for n in make_screens(args.raw):
            print("ok", n)

    if want("board"):
        allp = sorted(f for f in os.listdir(OUT) if f.endswith((".png", ".jpg")) and not f.startswith(("board", "half")) and not f.endswith("_sizes.png"))
        order = []
        for base in ("capsule_main_616x353", "capsule_header_460x215", "capsule_small_231x87",
                     "capsule_vertical_374x448", "library_capsule_600x900"):
            order += [base + ".png", base + "_b.png"]
        order += ["icon_eye_512.png", "icon_spark_512.png", "logo_1600.png",
                  "hero_3840x1240.png", "hero_3840x1240_b.png"]
        items = [o for o in order if o in allp] + [f for f in allp if f.startswith("screenshot_")]
        board(items).save(os.path.join(OUT, "board.png"), optimize=True)
        half = [n for n in ["capsule_main_616x353.png", "capsule_header_460x215.png", "capsule_small_231x87.png", "capsule_vertical_374x448.png"] if n in allp]
        if half:
            half_test(half).save(os.path.join(OUT, "half_test.png"))
        print("ok board")


if __name__ == "__main__":
    sys.exit(main())
