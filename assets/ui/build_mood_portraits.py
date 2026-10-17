"""Retratos POR EMOÇÃO da caixa de diálogo, a partir das folhas 2x4 do GPT
(artes/gpt/portraits/). Pipeline versionado da UI (irmão do build_portraits.py).
Uso (na raiz do projeto):  python -I assets/ui/build_mood_portraits.py
Saída: assets/ui/portraits/<falante>_<emoção>.png (128x128 RGBA, fundo azul-noite
com halo, máscara circular de borda suave — a moldura dourada é do jogo).

Folhas (4 colunas x 2 linhas, células lidas linha a linha):
  portrait_sophia_a.png: neutra · determinada · triste · raiva · medo · ternura · choque · serena
  portrait_npcs_a.png:   rei_regio · rei_ironico · rei_revelado · rei_quebrado ·
                         soter_sereno · soter_triste · velkar_elmo · velkar_arrependido
Os NPCs vêm em "cartões" com o fundo magenta em volta: a chave do magenta tira o
cartão e o recorte quadrado em volta da CABEÇA (topo da silhueta) fica só com o busto."""
import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "artes", "gpt", "portraits")
OUT = os.path.join(ROOT, "assets", "ui", "portraits")
SIZE = 128

SHEETS = {
    "portrait_sophia_a.png": [
        "sophia_neutra", "sophia_determinada", "sophia_triste", "sophia_raiva",
        "sophia_medo", "sophia_ternura", "sophia_choque", "sophia_serena"],
    "portrait_npcs_a.png": [
        "rei_regio", "rei_ironico", "rei_revelado", "rei_quebrado",
        "soter_sereno", "soter_triste", "velkar_elmo", "velkar_arrependido"],
}

# Ajuste fino por falante: (lado do recorte em fração da largura da célula,
# deslocamento x do centro em fração da célula, folga acima do topo da cabeça
# em fração do lado). A Sophia está 3/4 à direita (o rosto fica à direita do
# centro da silhueta); o Rei tem o capuz alto e pontudo.
TUNE = {
    "sophia": (0.66, 0.06, 0.04),
    "rei":    (0.80, 0.00, 0.02),
    "soter":  (0.70, -0.02, 0.04),
    "velkar": (0.74, 0.04, 0.03),
}

INK_TOP = np.array([22, 40, 50], dtype=np.float32)
INK_BOT = np.array([7, 14, 19], dtype=np.float32)


def key_alpha(rgb: np.ndarray) -> np.ndarray:
    """Alfa a partir do fundo magenta (1 = figura, 0 = fundo), com tolerância
    para a franja antisserrilhada."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mag = np.clip(((r + b) * 0.5 - g - 60.0) / 90.0, 0.0, 1.0)
    return 1.0 - mag


def build(cell: Image.Image, pid: str) -> None:
    who = pid.split("_")[0]
    side_k, dx_k, top_k = TUNE[who]
    a = np.asarray(cell.convert("RGB")).astype(np.float32)
    alpha = key_alpha(a)
    h, w = alpha.shape
    rows = np.where((alpha > 0.5).sum(1) > 6)[0]
    top = int(rows[0]) if rows.size else 0
    # Centro x da cabeça: média dos pixels da figura nas 80 linhas do topo.
    band = alpha[top: top + 80] > 0.5
    xs = np.where(band)[1]
    cx = float(xs.mean()) if xs.size else w * 0.5
    side = int(w * side_k)
    cx += w * dx_k
    x0 = int(round(cx - side / 2))
    y0 = int(round(top - side * top_k))
    box = (x0, y0, x0 + side, y0 + side)
    crop = cell.convert("RGB").crop(box).resize((SIZE, SIZE), Image.LANCZOS)
    rgb = np.asarray(crop).astype(np.float32)
    al = key_alpha(rgb)
    # fora da célula (crop além da borda) o PIL põe preto: conta como fundo
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    t = (yy / SIZE)[..., None]
    bg = INK_TOP * (1 - t) + INK_BOT * t
    d = np.sqrt((xx - SIZE * 0.5) ** 2 + (yy - SIZE * 0.42) ** 2) / (SIZE * 0.5)
    halo = np.clip(1.0 - d, 0.0, 1.0)[..., None] ** 2 * np.array([70, 55, 25], dtype=np.float32)
    bg = bg + halo
    # despill: tira o rosado da franja
    fringe = np.clip(1.0 - al, 0, 1)[..., None]
    rgb = rgb * (1 - fringe * 0.6) + np.array([30, 25, 30], dtype=np.float32) * fringe * 0.6
    out = rgb * al[..., None] + bg * (1 - al[..., None])
    r = np.sqrt((xx - SIZE / 2 + 0.5) ** 2 + (yy - SIZE / 2 + 0.5) ** 2)
    mask = np.clip((SIZE / 2 - 1.0 - r) / 1.5, 0.0, 1.0)
    img = np.dstack([np.clip(out, 0, 255), mask * 255.0]).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, pid + ".png"), optimize=True)
    print("retrato:", pid, box)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, ids in SHEETS.items():
        im = Image.open(os.path.join(SRC, name)).convert("RGB")
        cw, ch = im.width // 4, im.height // 2
        for k, pid in enumerate(ids):
            c, r = k % 4, k // 4
            cell = im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
            build(cell, pid)


if __name__ == "__main__":
    main()
