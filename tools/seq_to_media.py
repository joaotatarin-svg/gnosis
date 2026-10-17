"""seq_to_media.py — monta GIF + MP4 + FOLHA DE CONTATO de uma sequência do Shot.

FERRAMENTA de pipeline (não vai no jogo). Lê os quadros que o `tools/Shot.tscn`
salva no MODO SEQUÊNCIA (`<prefixo>_000.png`, `<prefixo>_001.png`, ...) e o
`<prefixo>_meta.json` (opcional) e gera, ao lado:
    <prefixo>.gif         animação leve (paleta otimizada pelo ffmpeg)
    <prefixo>.mp4         H.264 (yuv420p) — abre em qualquer player
    <prefixo>_sheet.png   grade numerada (nº do quadro + estado/golpe da Sophia)

Uso:
    python tools/seq_to_media.py C:/caps/demo            (prefixo)
    python tools/seq_to_media.py C:/caps/demo.png        (o mesmo <saida> do Shot)
Opções:
    --fps N          qps de saída (padrão: 60/every do meta, senão 30)
    --scale F        escala dos quadros no GIF/MP4 (padrão 0.5 = 640x360)
    --crop x,y,w,h   recorte fixo em pixels da imagem original
    --follow player|boss   recorte que ACOMPANHA o personagem (usa o meta)
    --box WxH        tamanho do recorte do --follow (padrão 520x420)
    --cols N         colunas da folha (padrão 8)
    --sheet-max N    máx. de quadros na folha (padrão 48; pula pra caber)
    --sheet-scale F  escala de cada célula da folha (padrão 0.35; 1.0 com --follow)
    --no-gif / --no-mp4 / --no-sheet
    --suffix S       acrescenta S aos nomes de saída (ex.: _follow)

Exemplo completo (filmar a Sophia e montar):
    godot --path . --fixed-fps 60 --resolution 1280x720 --position 4000,4000 ^
        res://tools/Shot.tscn -- 3 C:/caps/sophia.png 60 seq=150 every=2 act=demo solo
    python tools/seq_to_media.py C:/caps/sophia --follow player --suffix _follow
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont


def achar_quadros(prefixo: str) -> list[str]:
    """Lista <prefixo>_NNN.png em ordem numérica."""
    padrao = re.compile(re.escape(os.path.basename(prefixo)) + r"_(\d{3,})\.png$", re.I)
    arqs = []
    for p in glob.glob(glob.escape(prefixo) + "_*.png"):
        m = padrao.search(os.path.basename(p))
        if m:
            arqs.append((int(m.group(1)), p))
    return [p for _, p in sorted(arqs)]


def normalizar_prefixo(arg: str) -> str:
    p = arg.replace("\\", "/")
    if p.lower().endswith(".png"):
        p = p[:-4]
    p = re.sub(r"_\d{3,}$", "", p)  # aceita também o caminho de um quadro
    return p


def suavizar(pontos: list[tuple[float, float] | None], janela: int = 5) -> list[tuple[float, float]]:
    """Média móvel (preenche buracos com o último ponto conhecido)."""
    ult = None
    cheios = []
    for p in pontos:
        if p is not None:
            ult = p
        cheios.append(ult)
    primeiro = next((p for p in cheios if p is not None), (640.0, 360.0))
    cheios = [p if p is not None else primeiro for p in cheios]
    out = []
    for i in range(len(cheios)):
        a, b = max(0, i - janela // 2), min(len(cheios), i + janela // 2 + 1)
        xs = [c[0] for c in cheios[a:b]]
        ys = [c[1] for c in cheios[a:b]]
        out.append((sum(xs) / len(xs), sum(ys) / len(ys)))
    return out


def caixas_follow(meta: dict, alvo: str, n: int, box: tuple[int, int], img_size: tuple[int, int]):
    frames = meta.get("frames", []) if meta else []
    pts: list[tuple[float, float] | None] = []
    for i in range(n):
        f = frames[i] if i < len(frames) else {}
        if alvo == "player":
            p = f.get("player")
        else:
            bs = f.get("bosses") or []
            p = bs[0]["pos"] if bs else None
        pts.append((float(p[0]), float(p[1])) if p else None)
    if all(p is None for p in pts):
        print(f"AVISO: meta sem posição de '{alvo}' — usando o centro da imagem")
    sm = suavizar(pts)
    bw, bh = box
    W, H = img_size
    caixas = []
    for cx, cy in sm:
        # A origem do personagem é o PÉ: centraliza um pouco acima.
        x0 = int(round(cx - bw / 2))
        y0 = int(round(cy - bh * 0.72))
        # Sem "grudar" na borda: o que sair da imagem vira preto e o
        # personagem fica SEMPRE no centro (é o que importa pra julgar animação).
        caixas.append((x0, y0, x0 + bw, y0 + bh))
    return caixas


def fonte(tam: int):
    for nome in ("consola.ttf", "arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(nome, tam)
        except OSError:
            continue
    return ImageFont.load_default()


def rotulo(meta: dict | None, i: int) -> str:
    if not meta:
        return f"{i:03d}"
    fr = meta.get("frames", [])
    if i >= len(fr):
        return f"{i:03d}"
    f = fr[i]
    partes = [f"{i:03d}"]
    if f.get("state"):
        partes.append(f["state"] + (":" + f["move"] if f.get("move") else ""))
    bs = f.get("bosses") or []
    if bs:
        partes.append(f"B{bs[0].get('phase', '')}:{bs[0].get('estate', '')}")
    return " ".join(partes)


def folha(imgs: list[Image.Image], idxs: list[int], meta, cols: int, escala: float, saida: str) -> None:
    cw = max(1, int(imgs[0].width * escala))
    ch = max(1, int(imgs[0].height * escala))
    faixa = 18
    linhas = (len(imgs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cw, linhas * (ch + faixa)), (18, 16, 22))
    d = ImageDraw.Draw(sheet)
    f = fonte(12)
    for k, (im, i) in enumerate(zip(imgs, idxs)):
        x = (k % cols) * cw
        y = (k // cols) * (ch + faixa)
        sheet.paste(im.convert("RGB").resize((cw, ch), Image.LANCZOS), (x, y + faixa))
        d.text((x + 3, y + 2), rotulo(meta, i), fill=(240, 220, 150), font=f)
        d.rectangle([x, y, x + cw - 1, y + ch + faixa - 1], outline=(60, 55, 70))
    sheet.save(saida)


def ffmpeg(args: list[str]) -> bool:
    exe = shutil.which("ffmpeg")
    if not exe:
        print("ERRO: ffmpeg não está no PATH")
        return False
    r = subprocess.run([exe, "-y", "-loglevel", "error", *args], capture_output=True, text=True)
    if r.returncode != 0:
        print("ERRO ffmpeg:", r.stderr.strip()[:800])
        return False
    return True


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("prefixo")
    ap.add_argument("--fps", type=float, default=0)
    ap.add_argument("--scale", type=float, default=0.5)
    ap.add_argument("--crop", default="")
    ap.add_argument("--follow", choices=["player", "boss"], default=None)
    ap.add_argument("--box", default="520x420")
    ap.add_argument("--cols", type=int, default=8)
    ap.add_argument("--sheet-max", type=int, default=48)
    ap.add_argument("--sheet-scale", type=float, default=0)
    ap.add_argument("--no-gif", action="store_true")
    ap.add_argument("--no-mp4", action="store_true")
    ap.add_argument("--no-sheet", action="store_true")
    ap.add_argument("--suffix", default="")
    a = ap.parse_args()

    prefixo = normalizar_prefixo(a.prefixo)
    quadros = achar_quadros(prefixo)
    if not quadros:
        print(f"ERRO: nenhum quadro {prefixo}_###.png")
        return 1
    meta = None
    if os.path.exists(prefixo + "_meta.json"):
        with open(prefixo + "_meta.json", encoding="utf-8") as fh:
            meta = json.load(fh)
    fps = a.fps or (60.0 / meta["every"] if meta and meta.get("every") else 30.0)

    primeira = Image.open(quadros[0])
    W, H = primeira.size
    n = len(quadros)
    if a.follow:
        bw, bh = (int(v) for v in a.box.lower().split("x"))
        bw, bh = min(bw, W), min(bh, H)
        caixas = caixas_follow(meta, a.follow, n, (bw, bh), (W, H))
    elif a.crop:
        x, y, w, h = (int(v) for v in a.crop.split(","))
        caixas = [(x, y, x + w, y + h)] * n
    else:
        caixas = [None] * n

    # Recorta/escala para uma pasta temporária (ffmpeg lê dali).
    tmp = tempfile.mkdtemp(prefix="gnosis_seq_")
    try:
        escala_mid = 1.0 if a.follow or a.crop else a.scale

        for i, p in enumerate(quadros):
            im = Image.open(p).convert("RGB")
            if caixas[i]:
                im = im.crop(caixas[i])
            if escala_mid != 1.0:
                im = im.resize((int(im.width * escala_mid), int(im.height * escala_mid)), Image.LANCZOS)
            # H.264 exige dimensões pares.
            im = im.crop((0, 0, im.width - im.width % 2, im.height - im.height % 2))
            im.save(os.path.join(tmp, f"f_{i:04d}.png"))
        base = prefixo + a.suffix
        entrada = ["-framerate", f"{fps:g}", "-i", os.path.join(tmp, "f_%04d.png")]
        feitos = []
        if not a.no_mp4:
            if ffmpeg([*entrada, "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-movflags", "+faststart", base + ".mp4"]):
                feitos.append(base + ".mp4")
        if not a.no_gif:
            filtro = "split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=4"
            if ffmpeg([*entrada, "-vf", filtro, "-loop", "0", base + ".gif"]):
                feitos.append(base + ".gif")
        if not a.no_sheet:
            passo = max(1, -(-n // a.sheet_max))
            idxs = list(range(0, n, passo))
            esc = a.sheet_scale or (1.0 if (a.follow or a.crop) else 0.35)
            # Folha sempre a partir do recorte em resolução cheia (sem a escala do GIF).
            imgs = []
            for i in idxs:
                im = Image.open(quadros[i]).convert("RGB")
                if caixas[i]:
                    im = im.crop(caixas[i])
                imgs.append(im)
            if a.follow or a.crop:
                esc = min(esc, 0.6)
            folha(imgs, idxs, meta, a.cols, esc, base + "_sheet.png")
            feitos.append(base + "_sheet.png")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print(f"SEQ: {n} quadros @ {fps:g} qps ->")
    for f in feitos:
        print("   ", f)
    return 0


if __name__ == "__main__":
    sys.exit(main())
