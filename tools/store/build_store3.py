#!/usr/bin/env python3
"""Pacote de loja (Steam) v3 do GNOSIS — cápsulas com a Sophia GRANDE e inteira.

Fontes (somente leitura; artes/gpt/steam/):
  keyart_capsule_b(_x4)   1536x1024 — Sophia de corpo inteiro à direita, Rei ao fundo,
                          terço esquerdo escuro para o título (APROVADA, base das cápsulas)
  keyart_pan_left_a / keyart_wide_a / keyart_pan_right_a (+ _x4) — panorama do hero
  (_x4 = Real-ESRGAN realesrgan-x4plus; sem o _x4 usa a original 1x)

Títulos: os mesmos da v2 (build_store2.logo2): _ouro e _marfim.
Saída: assets/store/v3/ + assets/store/board3.png. Determinístico.
Uso: python tools/store/build_store3.py [--only main,header,small,vertical,library,hero,board]
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_store as B   # utilidades (v1)
import build_store2 as B2  # títulos ouro/marfim (v2)

Image.MAX_IMAGE_PIXELS = None
ROOT = B.ROOT
P = B.P
STORE = os.path.join(ROOT, "assets", "store")
OUT = os.path.join(STORE, "v3")
INK_DEEP = B.INK_DEEP

# trabalho em "2x" (3072x2048 por quadro): resolução de sobra p/ todas as peças
WORK = 2

_C = {}


def art(name):
    """Quadro da key art em resolução de trabalho (1536*WORK de largura), RGB."""
    if name not in _C:
        base = P("artes", "gpt", "steam", name)
        f = base + "_x4.jpg" if os.path.exists(base + "_x4.jpg") else base + ".png"
        im = Image.open(f).convert("RGB")
        _C[name] = im.resize((1536 * WORK, 1024 * WORK), Image.LANCZOS)
    return _C[name]


# --------------------------------------------------------------------------
# extensão de borda (só céu/nuvem escuros) e recorte
# --------------------------------------------------------------------------


def extend(im, left=0, top=0):
    """Estende a imagem para a esquerda e/ou para cima espelhando a borda,
    com borrão e escurecimento crescentes. Usado só onde a borda é céu escuro
    ou nuvem (terço esquerdo e topo da keyart_capsule_b)."""
    a = np.asarray(im, np.float32) / 255
    h, w = a.shape[:2]
    out = np.zeros((h + top, w + left, 3), np.float32)
    out[top:, left:] = a
    ink = np.array(INK_DEEP, np.float32) / 255
    if left:
        strip = a[:, :left][:, ::-1]
        bl = np.asarray(Image.fromarray((strip * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(h * 0.012)), np.float32) / 255
        t = np.linspace(1, 0, left, dtype=np.float32)[None, :, None]  # 1 = borda externa
        mix = strip * (1 - t) + bl * t
        dk = 1 - 0.55 * t
        out[top:, :left] = mix * dk + ink * (1 - dk)
    if top:
        src = out[top:top * 2 + 1][:top][::-1].copy()
        bl = np.asarray(Image.fromarray((np.clip(src, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(h * 0.012)), np.float32) / 255
        t = np.linspace(1, 0, top, dtype=np.float32)[:, None, None]
        mix = src * (1 - t) + bl * t
        dk = 1 - 0.6 * t
        out[:top] = mix * dk + ink * (1 - dk)
    return Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8))


def crop_px(im, W, H, box1x):
    """Recorta (x0, y0, x1, y1) em coordenadas da arte 1536x1024 (podem ser
    negativas: a imagem é estendida para a esquerda/cima) e reduz a W×H.
    O aspecto da caixa é corrigido pela LARGURA (mantém y0..y1)."""
    x0, y0, x1, y1 = box1x
    hh = y1 - y0
    ww = hh * W / H
    cx = (x0 + x1) / 2
    x1 = min(cx + ww / 2, 1536.0)  # a borda direita é a da arte (a Sophia fica lá)
    x0 = x1 - ww
    left = int(np.ceil(max(0.0, -x0) * WORK))
    top = int(np.ceil(max(0.0, -y0) * WORK))
    src = extend(im, left, top) if (left or top) else im
    box = (int(round(x0 * WORK + left)), int(round(y0 * WORK + top)), int(round(x1 * WORK + left)), int(round(y1 * WORK + top)))
    assert box[2] <= src.width + 1 and box[3] <= src.height + 1, ("recorte fora da arte", box, src.size)
    return src.crop(box).resize((W, H), Image.LANCZOS).convert("RGBA")


# --------------------------------------------------------------------------
# cápsulas (keyart_capsule_b): Sophia x≈1000–1350, y≈270–910 (cabeça→botas);
# Rei x≈640–1110, capuz y≈165; anéis y≈40–300; terço esquerdo escuro.
# --------------------------------------------------------------------------


def cap(W, H, box, title_xy, title_w, style, orn=False, shade=0.55, vig=0.3):
    c = crop_px(art("keyart_capsule_b"), W, H, box)
    B2.put_title(c, W * title_xy[0], H * title_xy[1], W * title_w, style, orn=orn, shade=shade)
    return B2.finish(c, vig=vig)


def make_main(st):
    return cap(1232, 706, (0, 40, 1536, 950), (0.235, 0.30), 0.44, st)


def make_header(st):
    return cap(920, 430, (-120, 100, 1536, 945), (0.255, 0.36), 0.46, st)


def make_small(st):
    return cap(462, 174, (-260, 240, 1440, 940), (0.32, 0.50), 0.58, st, shade=0.65, vig=0.2)


def make_vertical(st):
    return cap(748, 896, (500, -150, 1460, 960), (0.5, 0.095), 0.80, st, shade=0.6)


def make_library(st):
    return cap(600, 900, (560, -170, 1440, 960), (0.5, 0.085), 0.84, st, orn=True, shade=0.6)


# --------------------------------------------------------------------------
# hero: panorama L | wide | R com costura de custo mínimo + degradê largo
# --------------------------------------------------------------------------


def match_color(side, ref_band, side_band, k=0.85):
    """Ajusta média/desvio por canal de `side` para casar a faixa da emenda
    (`side_band`) com a do centro (`ref_band`). k = força."""
    s = side.astype(np.float32)
    for ch in range(3):
        ms, ss = side_band[..., ch].mean(), side_band[..., ch].std() + 1e-4
        mr, sr = ref_band[..., ch].mean(), ref_band[..., ch].std() + 1e-4
        g = 1 + (sr / ss - 1) * k
        s[..., ch] = (s[..., ch] - ms) * g + ms + (mr - ms) * k
    return np.clip(s, 0, 1)


def min_seam(cost):
    """Caminho vertical de custo mínimo (programação dinâmica). Devolve x por linha."""
    h, w = cost.shape
    acc = cost.copy()
    back = np.zeros((h, w), np.int32)
    for y in range(1, h):
        prev = acc[y - 1]
        l = np.r_[np.inf, prev[:-1]]
        r = np.r_[prev[1:], np.inf]
        stack = np.vstack([l, prev, r])
        i = stack.argmin(0)
        acc[y] += stack[i, np.arange(w)]
        back[y] = np.arange(w) + i - 1
    xs = np.zeros(h, np.int32)
    xs[-1] = int(acc[-1].argmin())
    for y in range(h - 1, 0, -1):
        xs[y - 1] = back[y, xs[y]]
    return xs


def stitch(center, side, side_is_left, overlap, feather, keep=None):
    """Cola `side` ao lado de `center` com `overlap` px sobrepostos (escala de
    trabalho). Costura de custo mínimo na sobreposição + degradê `feather`."""
    h = center.shape[0]
    sw = side.shape[1]
    if side_is_left:
        c_band = center[:, :overlap]
        s_band = side[:, sw - overlap:]
    else:
        c_band = center[:, -overlap:]
        s_band = side[:, :overlap]
    side = match_color(side, c_band, s_band, 0.8)
    s_band = side[:, sw - overlap:] if side_is_left else side[:, :overlap]
    # custo em escala reduzida (rápido), penaliza diferença de cor e de brilho
    q = 4
    cb = np.asarray(Image.fromarray((c_band * 255).astype(np.uint8)).resize((overlap // q, h // q), Image.BILINEAR), np.float32) / 255
    sb = np.asarray(Image.fromarray((s_band * 255).astype(np.uint8)).resize((overlap // q, h // q), Image.BILINEAR), np.float32) / 255
    cost = np.abs(cb - sb).sum(-1)
    cost = np.asarray(Image.fromarray((np.clip(cost / 3, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3)), np.float32)
    # empurra a costura para o meio da sobreposição (evita as bordas)
    xx = np.linspace(-1, 1, cost.shape[1], dtype=np.float32)
    cost += (xx ** 2)[None, :] * 8
    if keep is not None:
        # protege uma área do CENTRO (ex.: o 7º anel): a costura não passa por ela
        ky, kx = keep
        hq = cost.shape[0]
        k = int(kx * WORK / q)
        if side_is_left:
            cost[:int(ky * hq), cost.shape[1] - k:] += 1e4
        else:
            cost[:int(ky * hq), :k] += 1e4
    xs = min_seam(cost) * q
    xs = np.asarray(Image.fromarray(xs.astype(np.float32)[:, None]).resize((1, h), Image.BILINEAR), np.float32)[:, 0]
    # máscara: 1 = centro
    X = np.arange(overlap, dtype=np.float32)[None, :]
    m = (X >= xs[:, None]).astype(np.float32) if side_is_left else (X <= xs[:, None]).astype(np.float32)
    m8 = Image.fromarray((m * 255).astype(np.uint8))
    # mistura em 2 bandas: cor/luz (baixa frequência) com degradê LARGO
    # (`feather`); detalhe (alta frequência) com degradê CURTO — sem fantasmas.
    m_lo = np.asarray(m8.filter(ImageFilter.GaussianBlur(feather / 2.5)), np.float32)[..., None] / 255
    m_hi = np.asarray(m8.filter(ImageFilter.GaussianBlur(12 * WORK / 2.5)), np.float32)[..., None] / 255

    def split(a):
        lo = np.asarray(Image.fromarray((a * 255 + 0.5).astype(np.uint8)).filter(ImageFilter.GaussianBlur(30 * WORK)), np.float32) / 255
        return lo, a - lo
    cl, ch = split(c_band)
    sl, sh = split(s_band)
    blend = np.clip(cl * m_lo + sl * (1 - m_lo) + ch * m_hi + sh * (1 - m_hi), 0, 1)
    if side_is_left:
        return np.concatenate([side[:, :sw - overlap], blend, center[:, overlap:]], 1)
    return np.concatenate([center[:, :-overlap], blend, side[:, overlap:]], 1)


def panorama():
    f = lambda n: np.asarray(art(n), np.float32) / 255
    C, L, R = f("keyart_wide_a"), f("keyart_pan_left_a"), f("keyart_pan_right_a")
    ov, fe = 300 * WORK, 220 * WORK  # sobreposição 300 px; degradê de cor ~220 px (escala 1x)
    pano = stitch(C, L, True, ov, fe)
    pano = stitch(pano, R, False, ov, fe, keep=(0.32, 200))  # o 7º anel do centro fica
    return pano, L.shape[1] - ov  # (imagem, x onde começa o centro)


def make_hero_pano():
    W, H = 3840, 1240
    pano, cx0 = panorama()
    h = pano.shape[0]
    w = int(round(h * W / H))
    mid = cx0 + 1536 * WORK // 2  # centro da key art
    x0 = int(mid - w / 2)
    x0 = max(0, min(x0, pano.shape[1] - w))
    im = Image.fromarray((pano[:, x0:x0 + w] * 255 + 0.5).astype(np.uint8)).resize((W, H), Image.LANCZOS).convert("RGBA")
    im.alpha_composite(B.linear_shade(W, H, 0.75, 1.0, 0.0, 0.4))
    return B2.finish(im, vig=0.22), pano


# --------------------------------------------------------------------------
# prancha
# --------------------------------------------------------------------------


def make_board():
    try:
        lf = ImageFont.truetype(P("assets", "fonts", "alegreya", "Alegreya-VF.ttf"), 17)
        tf = ImageFont.truetype(P("assets", "fonts", "alegreya", "Alegreya-VF.ttf"), 30)
        hf = ImageFont.truetype(P("assets", "fonts", "cinzel", "Cinzel-VF.ttf"), 22)
    except OSError:
        lf = tf = hf = ImageFont.load_default()
    BW, pad = 2600, 28
    th = B2.thumb
    V2 = os.path.join(STORE, "v2")
    rows = [
        ("Main capsule 1232x706", "capsule_main_1232x706", "capsule_main_1232x706.png", 560),
        ("Header capsule 920x430", "capsule_header_920x430", "capsule_header_920x430.png", 560),
        ("Small capsule 462x174", "capsule_small_462x174", "capsule_small_462x174.png", 462),
        ("Vertical capsule 748x896", "capsule_vertical_748x896", "capsule_vertical_748x896.png", 400),
        ("Library capsule 600x900", "library_capsule_600x900", "library_capsule_600x900.png", 380),
    ]
    blocks = []
    for title, base, old, mw in rows:
        cells = [("v3 NOVA - ouro  (v3/%s_ouro.png)" % base, th(os.path.join(OUT, base + "_ouro.png"), mw)),
                 ("v3 NOVA - marfim  (v3/%s_marfim.png)" % base, th(os.path.join(OUT, base + "_marfim.png"), mw)),
                 ("v2 - marfim  (v2/%s_marfim.png)" % base, th(os.path.join(V2, base + "_marfim.png"), mw)),
                 ("v1 ANTERIOR - A  (%s)" % old, th(os.path.join(STORE, old), mw))]
        blocks.append((title, cells))
    blocks.append(("Library hero 3840x1240 (sem texto)", [
        ("v3 PANORAMA  (v3/hero_3840x1240.png)", th(os.path.join(OUT, "hero_3840x1240.png"), 1250)),
        ("v2  (v2/hero_3840x1240.png)", th(os.path.join(V2, "hero_3840x1240.png"), 1250)),
        ("v1 ANTERIOR  (hero_3840x1240.png)", th(os.path.join(STORE, "hero_3840x1240.png"), 1250)),
    ]))
    blocks.append(("Emendas do panorama em 100% (recortes 1:1 do hero v3)", [
        ("emenda esquerda 1:1", Image.open(os.path.join(OUT, "_seam_left.png")).convert("RGBA")),
        ("emenda direita 1:1", Image.open(os.path.join(OUT, "_seam_right.png")).convert("RGBA")),
    ]))
    blocks.append(("Logo, fundo da página e ícone (sem mudança desde a v2)", [
        ("logo ouro (v2)", th(os.path.join(V2, "logo_library_1280x720_ouro.png"), 420)),
        ("logo marfim (v2)", th(os.path.join(V2, "logo_library_1280x720_marfim.png"), 420)),
        ("page background (v2)", th(os.path.join(V2, "page_background_1438x810.png"), 560)),
        ("ícone olho", th(os.path.join(V2, "community_icon_184_olho.png"), 184)),
        ("ícone cristal", th(os.path.join(V2, "community_icon_184_cristal.png"), 184)),
        ("ícone faísca", th(os.path.join(V2, "community_icon_184_faisca.png"), 184)),
    ]))
    # teste no tamanho real da vitrine
    mini = []
    for lab, folder, suf in (("v3 ouro", OUT, "_ouro"), ("v3 marfim", OUT, "_marfim"), ("v1 A", STORE, "")):
        for base, sz in (("capsule_small_462x174", (231, 87)), ("capsule_header_920x430", (292, 136)),
                         ("capsule_main_1232x706", (308, 176)), ("library_capsule_600x900", (150, 225))):
            p = os.path.join(folder, base + suf + ".png")
            im = Image.open(p).convert("RGBA").resize(sz, Image.LANCZOS)
            mini.append(("%s %dx%d" % (lab, sz[0], sz[1]), im))
    blocks.append(("Teste no tamanho REAL da vitrine (busca 231x87 / lista 292x136 / destaque / biblioteca 150x225)", mini))

    lab_h, head_h = 24, 40
    laid, y = [], 110
    for title, cells in blocks:
        y0 = y
        y += head_h
        x, rh, pos = pad, 0, []
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
    d.text((pad, 22), "GNOSIS — prancha da loja v3 (Sophia grande e inteira). Por peça: v3 ouro | v3 marfim | v2 | v1 anterior.",
           fill=(236, 212, 152), font=tf)
    d.text((pad, 64), "Arquivos: assets/store/v3/ (novos), assets/store/v2/, assets/store/ (v1). Miniaturas reduzidas; o teste no fim"
           " mostra o tamanho real; as emendas do hero aparecem em 100%.", fill=(190, 180, 160), font=lf)
    for y0, title, pos in laid:
        d.line((pad, y0 + 4, BW - pad, y0 + 4), fill=(60, 56, 50), width=1)
        d.text((pad, y0 + 10), title, fill=(236, 212, 152), font=hf)
        for x, yy, lab, im in pos:
            d.text((x, yy), lab, fill=(215, 205, 185), font=lf)
            sheet.paste(im.convert("RGB"), (x, yy + lab_h))
    return sheet


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    only = set(filter(None, args.only.split(",")))
    want = lambda k: not only or k in only
    os.makedirs(OUT, exist_ok=True)
    makers = {"main": ("capsule_main_1232x706", make_main), "header": ("capsule_header_920x430", make_header),
              "small": ("capsule_small_462x174", make_small), "vertical": ("capsule_vertical_748x896", make_vertical),
              "library": ("library_capsule_600x900", make_library)}
    for k, (base, fn) in makers.items():
        if want(k):
            for st in ("ouro", "marfim"):
                fn(st).save(os.path.join(OUT, "%s_%s.png" % (base, st)), optimize=True)
                print("ok", base, st)
    if want("hero"):
        hero, pano = make_hero_pano()
        hero.save(os.path.join(OUT, "hero_3840x1240.png"), optimize=True)
        # recortes 1:1 das emendas (prova para a prancha; prefixo _ = não subir)
        s = 1240 / pano.shape[0]
        w = int(round(pano.shape[0] * 3840 / 1240))
        cx0 = (1536 - 300) * WORK
        x0 = max(0, int(cx0 + 1536 * WORK // 2 - w / 2))
        for tag, xs in (("left", cx0 + 150 * WORK), ("right", cx0 + 1536 * WORK - 150 * WORK)):
            hx = int((xs - x0) * s)
            hero.crop((max(0, hx - 600), 0, max(0, hx - 600) + 1200, 760)).save(os.path.join(OUT, "_seam_%s.png" % tag))
        print("ok hero")
    if want("board"):
        make_board().save(os.path.join(STORE, "board3.png"), optimize=True)
        print("ok board3")


if __name__ == "__main__":
    sys.exit(main())
