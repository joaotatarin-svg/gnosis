"""hitbox_overlay.py — desenha a caixa de acerto da Sophia sobre o quadro DESENHADO.

FERRAMENTA (Combate 6, não vai no jogo). Lê o JSON que a `tools/combate/HitboxProbe.tscn`
grava (geometria quadro a quadro: sequência/quadro do atlas, mão, ponta do cajado,
caixa de acerto, se estava ligada e a hurtbox do inimigo) e monta uma prancha PNG:
    quadro do atlas (sophia_frames.png) na escala do jogo × ZOOM
    amarelo = cajado (mão → ponta) · vermelho = caixa LIGADA · cinza = caixa desligada
    azul = hurtbox do inimigo (verde se o cajado encostou nela neste quadro)
Tudo sem janela (headless + PIL).

Uso:  python tools/combate/hitbox_overlay.py <geo.json> <saida.png> [--zoom 4] [--cols 8]
"""
from __future__ import annotations

import argparse
import json
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(os.path.dirname(HERE))
FRAMES_JSON = os.path.join(PROJ, "assets", "painted", "derived", "sophia_frames.json")
GROUND_Y = 24.0


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("geo")
    ap.add_argument("out")
    ap.add_argument("--zoom", type=float, default=4.0)
    ap.add_argument("--cols", type=int, default=8)
    a = ap.parse_args()
    geo = json.load(open(a.geo, encoding="utf-8"))
    db = json.load(open(FRAMES_JSON, encoding="utf-8"))
    atlas = Image.open(os.path.join(PROJ, db["atlas"].replace("res://", ""))).convert("RGBA")
    height = float(geo["k_height"])
    k = height * 1.19 / float(db["body_px"])
    foot = (0.0, GROUND_Y * height / 44.0)
    z = a.zoom
    # janela de mundo de cada célula: x -50..80, y -70..40 (coords do Player)
    wx0, wx1, wy0, wy1 = -50.0, 80.0, -70.0, 40.0
    cw, ch = int((wx1 - wx0) * z), int((wy1 - wy0) * z)
    frames = geo["frames"]
    rows = (len(frames) + a.cols - 1) // a.cols
    sheet = Image.new("RGBA", (cw * a.cols, ch * rows), (28, 28, 34, 255))

    def P(x: float, y: float) -> tuple[float, float]:
        return ((x - wx0) * z, (y - wy0) * z)

    for n, f in enumerate(frames):
        cell = Image.new("RGBA", (cw, ch), (52, 52, 62, 255))
        d = ImageDraw.Draw(cell)
        seq = db["states"].get(f.get("seq", ""), None)
        if seq is not None and 0 <= int(f["i"]) < len(seq["frames"]):
            e = seq["frames"][int(f["i"])]
            fr = db["frames"][e["f"]]
            x, y, w, h = fr["rect"]
            crop = atlas.crop((x, y, x + w, y + h))
            sw, sh = max(1, int(w * k * z)), max(1, int(h * k * z))
            crop = crop.resize((sw, sh), Image.LANCZOS)
            ox = foot[0] - e["anchor"][0] * k
            oy = foot[1] - e["anchor"][1] * k
            px, py = P(ox, oy)
            cell.alpha_composite(crop, (int(px), int(py)))
            label = "%s %s#%d" % (f["move"], f["seq"], int(f["i"]))
        else:
            label = "%s (sem quadro)" % f["move"]
        hx, hy, hw, hh = f["hurt"]
        col = (60, 220, 90, 255) if f.get("touch") else (80, 140, 255, 255)
        d.rectangle([P(hx, hy), P(hx + hw, hy + hh)], outline=col, width=2)
        bx, by, bw, bh = f["hit_rect"]
        hcol = (255, 60, 60, 255) if f.get("live") else (150, 150, 150, 200)
        d.rectangle([P(bx - bw / 2, by - bh / 2), P(bx + bw / 2, by + bh / 2)], outline=hcol, width=2)
        if f.get("hand") and f.get("tip"):
            d.line([P(*f["hand"]), P(*f["tip"])], fill=(255, 230, 60, 255), width=3)
        d.line([P(0, wy0), P(0, wy1)], fill=(255, 255, 255, 50))
        d.text((4, 4), label, fill=(255, 255, 140, 255))
        sheet.paste(cell, ((n % a.cols) * cw, (n // a.cols) * ch))
    sheet.save(a.out)
    print("prancha:", a.out, sheet.size, "quadros:", len(frames))


if __name__ == "__main__":
    main()
