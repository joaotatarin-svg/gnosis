#!/usr/bin/env python3
"""Pacote de loja (Steam) v2 do GNOSIS — a partir da KEY ART pintada pelo GPT.

Fontes (somente leitura):
  artes/gpt/steam/keyart_wide_a_x4.jpg      6144x4096 (Real-ESRGAN x4 da 1536x1024)
  artes/gpt/steam/keyart_vertical_a_x4.jpg  4096x6144 (Real-ESRGAN x4 da 1024x1536)
  assets/fonts/cinzel_decorative/CinzelDecorative-Bold.ttf (OFL) — logotipo
  assets/fonts/alegreya/Alegreya-VF.ttf (OFL) — só os rótulos da prancha

Duas variações de título em TODAS as peças com texto:
  _ouro    Cinzel Decorative em ouro envelhecido (pátina) com brilho de faísca no "I"
  _marfim  marfim com contorno escuro e filete de ouro (o mais legível pequeno)

Saída: assets/store/v2/ (assets/store tem .gdignore — não entra no jogo).
A proposta anterior (assets/store/*.png, variante A "a Mente") fica como alternativa.
Determinístico (sementes fixas). Uso:
  python tools/store/build_store2.py                 (tudo + prancha)
  python tools/store/build_store2.py --only header,board
"""
import argparse
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_store as B  # utilidades e paleta da v1 (mesmo diretório)

Image.MAX_IMAGE_PIXELS = None
ROOT = B.ROOT
OUT = os.path.join(ROOT, "assets", "store", "v2")
OLD = os.path.join(ROOT, "assets", "store")
P = B.P

INK, INK_DEEP, PAPER = B.INK, B.INK_DEEP, B.PAPER
GOLD, GOLD_HI, GOLD_LO, SPARK = B.GOLD, B.GOLD_HI, B.GOLD_LO, B.SPARK
FONT_LOGO = B.FONT_LOGO

_SRC = {}


def src(kind):
    """Key art ampliada (x4). kind = 'wide' | 'vertical'."""
    if kind not in _SRC:
        _SRC[kind] = Image.open(P("artes", "gpt", "steam", "keyart_%s_a_x4.jpg" % kind)).convert("RGB")
    return _SRC[kind]


# --------------------------------------------------------------------------
# recorte da key art
# --------------------------------------------------------------------------


def crop_art(kind, W, H, cx, cy, hfrac):
    """Recorta a key art em torno de (cx, cy) (frações da imagem), com altura
    `hfrac` da imagem e o aspecto W/H do alvo; reduz para W×H (LANCZOS)."""
    im = src(kind)
    sw, sh = im.size
    h = hfrac * sh
    w = h * W / H
    if w > sw:  # não cabe: limita pela largura
        w = sw
        h = w * H / W
    x0 = min(max(0.0, cx * sw - w / 2), sw - w)
    y0 = min(max(0.0, cy * sh - h / 2), sh - h)
    box = tuple(int(round(v)) for v in (x0, y0, x0 + w, y0 + h))
    out = im.crop(box).resize((W, H), Image.LANCZOS)
    return out.convert("RGBA")


def extend_sides(im, W):
    """Alarga a imagem até W espelhando as bordas, com borrão crescente e
    escurecimento (a cena real fica no centro; as laterais viram penumbra)."""
    w, h = im.size
    if w >= W:
        return im
    ext = (W - w + 1) // 2
    canvas = Image.new("RGBA", (W, h), INK_DEEP + (255,))
    canvas.alpha_composite(im, (ext, 0))
    for side in (0, 1):
        strip = im.crop((0, 0, ext, h)) if side == 0 else im.crop((w - ext, 0, w, h))
        strip = strip.transpose(Image.FLIP_LEFT_RIGHT)
        a = B.to_np(strip)
        # borrão em camadas (perto da emenda pouco, longe muito)
        b1 = B.to_np(B.blur(strip, h * 0.006))
        b2 = B.to_np(B.blur(strip, h * 0.03))
        t = np.linspace(0, 1, ext, dtype=np.float32)  # 0 = emenda, 1 = borda externa
        if side == 0:
            t = t[::-1]
        t = t[None, :, None]
        mix = np.where(t < 0.5, a * (1 - t * 2) + b1 * (t * 2), b1 * (1 - (t - 0.5) * 2) + b2 * ((t - 0.5) * 2))
        dark = 1.0 - 0.92 * np.clip(t, 0, 1) ** 0.6
        mix[..., :3] = mix[..., :3] * dark + np.array(INK_DEEP, np.float32) / 255 * (1 - dark)
        mix[..., 3] = 1.0
        canvas.alpha_composite(B.to_im(mix), (0 if side == 0 else ext + w, 0))
    return canvas


def shade_ellipse(canvas, cx, cy, w, h, alpha):
    """Penumbra difusa atrás do título (legibilidade sem caixa visível)."""
    W, H = canvas.size
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    d.ellipse((cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), fill=int(255 * alpha))
    m = B.blur(m, max(w, h) * 0.18)
    canvas.alpha_composite(B.tint_alpha(m, INK_DEEP, 1.0))


def grain(w, h, seed, amp):
    rng = np.random.default_rng(seed)
    n = rng.normal(0, 1, (h // 3 + 2, w // 3 + 2)).astype(np.float32)
    n = np.asarray(Image.fromarray(((n * 0.25 + 0.5).clip(0, 1) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), np.float32) / 255
    return (n - 0.5) * 2 * amp


# --------------------------------------------------------------------------
# o logotipo GNOSIS — duas variações
# --------------------------------------------------------------------------


def _gradient(H, gy0, gy1, stops):
    yy = np.linspace(0, 1, H, dtype=np.float32)
    t = np.clip((yy - gy0 / H) / max(1e-6, (gy1 - gy0) / H), 0, 1)
    col = np.zeros((H, 3), np.float32)
    for (t0, c0), (t1, c1) in zip(stops[:-1], stops[1:]):
        k = np.clip((t - t0) / (t1 - t0), 0, 1)[:, None]
        sel = ((t >= t0) & (t <= t1))[:, None]
        col = np.where(sel, np.array(c0, np.float32) * (1 - k) + np.array(c1, np.float32) * k, col)
    return col / 255


def flare(size, x, y, r, color=SPARK, ratio=1.0, hr=1.0):
    """Faísca de 4 pontas com halo (camada RGBA do tamanho `size`).
    ratio = braço vertical / r; hr = braço horizontal / r."""
    W, H = size
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    t = max(1.0, r * 0.06)
    d.polygon([(x - r * hr, y), (x, y - t), (x + r * hr, y), (x, y + t)], fill=255)
    d.polygon([(x, y - r * ratio), (x + t, y), (x, y + r * ratio), (x - t, y)], fill=255)
    rr = r * 0.32
    d.polygon([(x - rr, y - rr), (x + t * 0.4, y - t * 0.4), (x + rr, y + rr), (x - t * 0.4, y + t * 0.4)], fill=120)
    d.polygon([(x + rr, y - rr), (x + t * 0.4, y + t * 0.4), (x - rr, y + rr), (x - t * 0.4, y - t * 0.4)], fill=120)
    m = B.blur(m, max(0.6, r * 0.01))
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    halo = Image.new("L", (W, H), 0)
    ImageDraw.Draw(halo).ellipse((x - r * 0.28, y - r * 0.28, x + r * 0.28, y + r * 0.28), fill=255)
    out.alpha_composite(B.tint_alpha(B.blur(halo, r * 0.22), (255, 190, 110), 0.85))
    out.alpha_composite(B.tint_alpha(m, color, 1.0))
    core = Image.new("L", (W, H), 0)
    ImageDraw.Draw(core).ellipse((x - r * 0.07, y - r * 0.07, x + r * 0.07, y + r * 0.07), fill=255)
    out.alpha_composite(B.tint_alpha(B.blur(core, r * 0.03), (255, 255, 245), 1.0))
    return out


def logo2(width, style="ouro", glow=True):
    """Logotipo 'GNOSIS' (Cinzel Decorative Bold). style: 'ouro' | 'marfim'.
    Devolve RGBA aparado com `width` px de largura."""
    text = "GNOSIS"
    ss = 2
    size = 400
    font = ImageFont.truetype(FONT_LOGO, size * ss)
    adv = [font.getlength(ch) for ch in text]
    track = 0.06 * size * ss
    tw = sum(adv) + track * (len(text) - 1)
    asc, desc = font.getmetrics()
    pad = int(size * ss * 0.6)
    W, H = int(tw + pad * 2), int(asc + desc + pad * 2)
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    x = pad
    i_box = None
    for k, (ch, a) in enumerate(zip(text, adv)):
        d.text((x, pad), ch, font=font, fill=255)
        if k == 4:  # o "I"
            i_box = d.textbbox((x, pad), ch, font=font)
        x += a + track
    mask = mask.resize((W // ss, H // ss), Image.LANCZOS)
    i_box = [v / ss for v in i_box]
    W, H = mask.size
    bb = mask.getbbox()
    gy0, gy1 = bb[1], bb[3]
    cap = gy1 - gy0
    m_np = np.asarray(mask, np.float32) / 255

    if style == "ouro":
        # ouro ENVELHECIDO: menos amarelo-limão, mais bronze; pátina granulada
        stops = [(0.0, (232, 206, 150)), (0.16, (250, 234, 190)), (0.38, (214, 180, 112)),
                 (0.55, (178, 138, 74)), (0.78, (140, 104, 56)), (1.0, (92, 68, 38))]
        col = _gradient(H, gy0, gy1, stops)
        fill = np.zeros((H, W, 4), np.float32)
        fill[..., :3] = col[:, None, :]
        pat = grain(W, H, 17, 0.10)[..., None]
        fill[..., :3] = np.clip(fill[..., :3] * (1 + pat), 0, 1)
        fill[..., 3] = m_np
        ow = max(2, int(size * 0.028))
        outline_col, glow_col, glow_a = (28, 18, 10), (230, 150, 70), 0.5
        hi_col, hi_a = SPARK, 0.85
    else:
        # marfim (papel do Códex) com contorno de tinta grosso + filete de ouro
        stops = [(0.0, (252, 247, 234)), (0.45, (240, 230, 208)), (0.8, (220, 206, 178)), (1.0, (196, 180, 150))]
        col = _gradient(H, gy0, gy1, stops)
        fill = np.zeros((H, W, 4), np.float32)
        fill[..., :3] = col[:, None, :]
        fill[..., 3] = m_np
        ow = max(3, int(size * 0.05))
        outline_col, glow_col, glow_a = INK_DEEP, (150, 190, 220), 0.28
        hi_col, hi_a = (255, 255, 250), 0.6

    fill_im = B.to_im(fill)
    up = np.asarray(B.blur(Image.fromarray((m_np * 255).astype(np.uint8)).transform(
        (W, H), Image.AFFINE, (1, 0, 0, 0, 1, -3)), 1.2), np.float32) / 255
    bevel = np.clip(m_np - up, 0, 1)
    hi = np.zeros((H, W, 4), np.float32)
    hi[..., :3] = np.array(hi_col, np.float32) / 255
    hi[..., 3] = bevel * hi_a

    outline = B.blur(B.dilate(mask, ow), 0.8)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sh = B.blur(B.dilate(mask, ow * 2), size * 0.08)
    out.alpha_composite(B.tint_alpha(sh, INK_DEEP, 0.8))
    if glow:
        out.alpha_composite(B.tint_alpha(B.blur(mask, size * 0.12), glow_col, glow_a))
    if style == "marfim":
        # filete de ouro por fora do contorno escuro
        ring = B.blur(B.dilate(mask, int(ow * 1.55)), 0.8)
        out.alpha_composite(B.tint_alpha(ring, (196, 160, 96), 1.0))
    out.alpha_composite(B.tint_alpha(outline, outline_col, 1.0))
    out.alpha_composite(fill_im)
    out.alpha_composite(B.to_im(hi))
    if style == "ouro":
        # a FAÍSCA: estrela de 4 pontas SOLTA acima do "I", como o pingo de um "i"
        # (braço horizontal curto e afastado da letra: não pode virar "T" pequeno)
        ix = (i_box[0] + i_box[2]) / 2
        out.alpha_composite(flare((W, H), ix, gy0 - cap * 0.22, cap * 0.44, ratio=1.0, hr=0.55))
        out.alpha_composite(flare((W, H), bb[0] + cap * 0.30, gy0 + cap * 0.10, cap * 0.16))
    out = B.trim(out, pad=int(size * 0.02))
    s = width / out.width
    return out.resize((int(round(out.width * s)), int(round(out.height * s))), Image.LANCZOS)


def ornament(width, style):
    return B.logo_ornament(width, color=GOLD if style == "ouro" else (214, 196, 160))


def put_title(canvas, cx, cy, width, style, orn=False, shade=0.55):
    lg = logo2(int(width), style)
    if shade > 0:
        shade_ellipse(canvas, cx, cy, lg.width * 1.45, lg.height * 2.6, shade)
    B.over(canvas, lg, (cx - lg.width / 2, cy - lg.height / 2))
    if orn:
        o = ornament(int(width * 0.7), style)
        B.over(canvas, o, (cx - o.width / 2, cy + lg.height * 0.5 + o.height * 0.3))
    return canvas


def finish(im, vig=0.35):
    if vig > 0:
        im = im.copy()
        im.alpha_composite(B.vignette(im.width, im.height, vig))
    return im.convert("RGB")


# --------------------------------------------------------------------------
# peças (coordenadas em frações da key art)
# --------------------------------------------------------------------------
# key art larga (1536x1024 original): Sophia ~ x0.25–0.45, y0.53–0.89;
# Rei: capuz y0.11, orbe-olho (0.81, 0.19); céu vazio no terço sup.-esquerdo.


def make_main(style):
    W, H = 1232, 706
    c = crop_art("wide", W, H, 0.5, 0.47, 0.90)
    put_title(c, W * 0.245, H * 0.20, W * 0.42, style, shade=0.5)
    return finish(c)


def make_header(style):
    W, H = 920, 430
    c = crop_art("wide", W, H, 0.5, 0.445, 0.70)
    put_title(c, W * 0.25, H * 0.25, W * 0.44, style, shade=0.55)
    return finish(c)


def make_small(style):
    W, H = 462, 174
    c = crop_art("wide", W, H, 0.44, 0.31, 0.47)
    put_title(c, W * 0.33, H * 0.50, W * 0.60, style, shade=0.7)
    return finish(c, vig=0.25)


def make_vertical(style):
    W, H = 748, 896
    c = crop_art("vertical", W, H, 0.5, 0.50, 0.80)
    put_title(c, W * 0.5, H * 0.105, W * 0.72, style, shade=0.6)
    return finish(c)


def make_library(style):
    W, H = 600, 900
    c = crop_art("vertical", W, H, 0.5, 0.5, 1.0)
    put_title(c, W * 0.5, H * 0.105, W * 0.80, style, orn=True, shade=0.55)
    return finish(c)


def make_hero():
    # SEM texto e sem logo (o Steam põe o logo da biblioteca por cima).
    W, H = 3840, 1240
    im = src("wide")
    y0, y1 = int(0.105 * im.height), int(0.80 * im.height)
    band = im.crop((0, y0, im.width, y1)).convert("RGBA")
    s = H / band.height
    band = band.resize((int(round(band.width * s)), H), Image.LANCZOS)
    c = extend_sides(band, W)
    c.alpha_composite(B.linear_shade(W, H, 0.7, 1.0, 0.0, 0.45))
    return finish(c, vig=0.25)


def make_page_bg():
    # fundo da página da loja: a mesma cena, escurecida, dessaturada e um pouco
    # desfocada; o centro (onde a Steam põe o conteúdo) fica ainda mais escuro.
    W, H = 1438, 810
    c = crop_art("wide", W, H, 0.5, 0.42, 0.85)
    c = B.blur(c, 2.2)
    c = B.grade(c, mul=(0.36, 0.36, 0.42), sat=0.55, gamma=1.15)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    col = np.clip(1 - np.abs(xx / W - 0.5) / 0.36, 0, 1) ** 1.5  # coluna central
    vert = np.clip((yy / H - 0.35) / 0.65, 0, 1) ** 1.2          # some embaixo
    a = np.clip(col * 0.45 + vert * 0.95, 0, 1)
    layer = np.zeros((H, W, 4), np.float32)
    layer[..., :3] = np.array((14, 18, 26), np.float32) / 255
    layer[..., 3] = a
    c.alpha_composite(B.to_im(layer))
    return c.convert("RGB")


def make_logo_library(style):
    # 1280x720 com transparência; o logo ocupa a largura útil, centrado.
    W, H = 1280, 720
    lg = logo2(1180, style)
    o = ornament(int(1180 * 0.7), style)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    th = lg.height + int(o.height * 1.3)
    y = (H - th) // 2
    B.over(out, lg, ((W - lg.width) / 2, y))
    B.over(out, o, ((W - o.width) / 2, y + lg.height + o.height * 0.3))
    return out


def make_icon_eye_painted(S=184):
    # o orbe-olho pintado na mão do Rei (recorte da key art x4) em disco com aro
    im = src("wide")
    cx, cy, r = 0.8125 * im.width, 0.186 * im.height, 0.034 * im.width
    crop = im.crop((int(cx - r), int(cy - r), int(cx + r), int(cy + r))).resize((S * 2, S * 2), Image.LANCZOS).convert("RGBA")
    return _disc(crop, S)


def make_icon_crystal_painted(S=184):
    # o cristal do cajado da Sophia (a faísca, ciano) — recorte da key art x4
    im = src("wide")
    cx, cy, r = 0.4475 * im.width, 0.556 * im.height, 0.026 * im.width
    crop = im.crop((int(cx - r), int(cy - r), int(cx + r), int(cy + r))).resize((S * 2, S * 2), Image.LANCZOS).convert("RGBA")
    crop = B.grade(crop, mul=(1.05, 1.05, 1.05), sat=1.1)
    return _disc(crop, S)


def _disc(img, S):
    N = img.width
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    d = np.sqrt((xx - N / 2) ** 2 + (yy - N / 2) ** 2) / (N / 2)
    a = B.to_np(img)
    a[..., 3] = np.clip((0.985 - d) * N * 0.5, 0, 1)
    out = B.to_im(a)
    dr = ImageDraw.Draw(out)
    w = int(N * 0.045)
    rr = N / 2 - w * 0.9
    c = N / 2
    dr.ellipse((c - rr, c - rr, c + rr, c + rr), outline=INK_DEEP + (255,), width=int(w * 1.6))
    dr.ellipse((c - rr, c - rr, c + rr, c + rr), outline=GOLD + (255,), width=w)
    return out.resize((S, S), Image.LANCZOS)


# --------------------------------------------------------------------------
# prancha
# --------------------------------------------------------------------------


def checker(w, h, ck=24):
    bg = Image.new("RGBA", (w, h), (40, 40, 48, 255))
    dd = ImageDraw.Draw(bg)
    for y in range(0, h, ck):
        for x in range(0, w, ck):
            if (x // ck + y // ck) % 2:
                dd.rectangle((x, y, x + ck - 1, y + ck - 1), fill=(56, 56, 66, 255))
    return bg


def thumb(path, maxw, maxh=10000):
    im = Image.open(path).convert("RGBA")
    if os.path.basename(path).startswith("logo"):
        bg = checker(im.width, im.height)
        bg.alpha_composite(im)
        im = bg
    s = min(1.0, maxw / im.width, maxh / im.height)
    if s < 1:
        im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    return im


def make_board():
    """Prancha: cada linha é uma peça; colunas = título OURO | título MARFIM |
    proposta ANTERIOR (A, a Mente). Embaixo: hero, fundo, logos, ícones e o
    teste de miniatura (tamanho real em que a Steam mostra)."""
    try:
        lf = ImageFont.truetype(P("assets", "fonts", "alegreya", "Alegreya-VF.ttf"), 17)
        tf = ImageFont.truetype(P("assets", "fonts", "alegreya", "Alegreya-VF.ttf"), 30)
        hf = ImageFont.truetype(P("assets", "fonts", "cinzel", "Cinzel-VF.ttf"), 22)
    except OSError:
        lf = tf = hf = ImageFont.load_default()
    BW = 2400
    pad = 28
    blocks = []  # (titulo, [(rotulo, imagem)])
    rows = [
        ("Main capsule 1232x706", "capsule_main_1232x706", "capsule_main_1232x706.png", 616),
        ("Header capsule 920x430", "capsule_header_920x430", "capsule_header_920x430.png", 616),
        ("Small capsule 462x174", "capsule_small_462x174", "capsule_small_462x174.png", 462),
        ("Vertical capsule 748x896", "capsule_vertical_748x896", "capsule_vertical_748x896.png", 420),
        ("Library capsule 600x900", "library_capsule_600x900", "library_capsule_600x900.png", 400),
        ("Library logo 1280x720 (transparente)", "logo_library_1280x720", "logo_library_1280x720.png", 560),
    ]
    for title, base, old, mw in rows:
        cells = []
        for st in ("ouro", "marfim"):
            p = os.path.join(OUT, "%s_%s.png" % (base, st))
            cells.append(("NOVA - título %s  (v2/%s_%s.png)" % (st.upper(), base, st), thumb(p, mw)))
        po = os.path.join(OLD, old)
        if os.path.exists(po):
            cells.append(("ANTERIOR - A, a Mente  (%s)" % old, thumb(po, mw)))
        blocks.append((title, cells))
    blocks.append(("Library hero 3840x1240 (sem texto) — nova x anterior", [
        ("NOVA  (v2/hero_3840x1240.png)", thumb(os.path.join(OUT, "hero_3840x1240.png"), 1160)),
        ("ANTERIOR  (hero_3840x1240.png)", thumb(os.path.join(OLD, "hero_3840x1240.png"), 1160)),
    ]))
    ic = []
    for n, lab in (("community_icon_184_olho.png", "olho pintado"), ("community_icon_184_cristal.png", "cristal pintado"),
                   ("community_icon_184_faisca.png", "faísca (desenho v1)")):
        ic.append(("Ícone 184 - %s  (v2/%s)" % (lab, n), thumb(os.path.join(OUT, n), 184)))
    blocks.append(("Page background 1438x810 + community icon 184x184", [
        ("Page background  (v2/page_background_1438x810.png)", thumb(os.path.join(OUT, "page_background_1438x810.png"), 960))] + ic))
    # teste de miniatura: tamanhos em que a Steam mostra de fato
    mini = []
    for st in ("ouro", "marfim"):
        for base, sz in (("capsule_small_462x174", (231, 87)), ("capsule_header_920x430", (292, 136)),
                         ("library_capsule_600x900", (150, 225))):
            im = Image.open(os.path.join(OUT, "%s_%s.png" % (base, st))).convert("RGBA").resize(sz, Image.LANCZOS)
            mini.append(("%s %dx%d" % (st, sz[0], sz[1]), im))
    blocks.append(("Teste de legibilidade no tamanho em que a Steam mostra (busca / lista / biblioteca)", mini))

    # layout
    lab_h, head_h = 24, 40
    laid = []
    y = 110
    for title, cells in blocks:
        y0 = y
        y += head_h
        x = pad
        rh = 0
        pos = []
        for lab, im in cells:
            cw = max(im.width, int(lf.getlength(lab)) + 10)
            if x + cw > BW - pad and pos:
                y += rh + lab_h + pad
                x, rh = pad, 0
            pos.append((x, y, lab, im))
            x += cw + pad
            rh = max(rh, im.height)
        y += rh + lab_h + pad * 2
        laid.append((y0, title, pos))
    sheet = Image.new("RGB", (BW, y + pad), (16, 16, 20))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 22), "GNOSIS — prancha da loja v2 (key art pintada). Escolha o TÍTULO (ouro ou marfim) e, por peça, NOVA ou ANTERIOR;"
           " e um ícone.", fill=(236, 212, 152), font=tf)
    d.text((pad, 64), "Arquivos em assets/store/v2/. A proposta anterior (variante A) continua em assets/store/. Miniaturas reduzidas;"
           " o teste no fim mostra o tamanho real da vitrine.", fill=(190, 180, 160), font=lf)
    for y0, title, pos in laid:
        d.line((pad, y0 + 4, BW - pad, y0 + 4), fill=(60, 56, 50), width=1)
        d.text((pad, y0 + 10), title, fill=(236, 212, 152), font=hf)
        for x, yy, lab, im in pos:
            d.text((x, yy), lab, fill=(215, 205, 185), font=lf)
            sheet.paste(im.convert("RGB"), (x, yy + lab_h))
    return sheet


# --------------------------------------------------------------------------


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    only = set(filter(None, args.only.split(",")))

    def want(k):
        return not only or k in only

    os.makedirs(OUT, exist_ok=True)
    styled = {"main": ("capsule_main_1232x706", make_main), "header": ("capsule_header_920x430", make_header),
              "small": ("capsule_small_462x174", make_small), "vertical": ("capsule_vertical_748x896", make_vertical),
              "library": ("library_capsule_600x900", make_library), "logo": ("logo_library_1280x720", make_logo_library)}
    for key, (base, fn) in styled.items():
        if want(key):
            for st in ("ouro", "marfim"):
                fn(st).save(os.path.join(OUT, "%s_%s.png" % (base, st)), optimize=True)
                print("ok", base, st)
    if want("hero"):
        make_hero().save(os.path.join(OUT, "hero_3840x1240.png"), optimize=True)
        print("ok hero")
    if want("page"):
        make_page_bg().save(os.path.join(OUT, "page_background_1438x810.png"), optimize=True)
        print("ok page")
    if want("icon"):
        make_icon_eye_painted().save(os.path.join(OUT, "community_icon_184_olho.png"))
        make_icon_crystal_painted().save(os.path.join(OUT, "community_icon_184_cristal.png"))
        B.make_icon_spark(184).save(os.path.join(OUT, "community_icon_184_faisca.png"))
        print("ok icons")
    if want("board"):
        make_board().save(os.path.join(OLD, "board2.png"), optimize=True)
        print("ok board2")


if __name__ == "__main__":
    sys.exit(main())
