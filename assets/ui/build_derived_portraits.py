"""Retratos da caixa de diálogo a partir dos BUSTOS DERIVADOS da arte
(assets/painted/derived/portraits/*.png — PNG com alfa, sem fundo magenta).
Pipeline versionado da UI (irmão de build_portraits.py e build_mood_portraits.py).
Uso (na raiz do projeto):  python -I assets/ui/build_derived_portraits.py
Saída: assets/ui/portraits/<id>.png (128x128 RGBA, fundo azul-noite com halo,
máscara circular de borda suave — a moldura dourada é desenhada pelo jogo).

  cego_<humor>  "O Cego" pequeno (cena D, tela 68): assustado · olhando · sereno · aninhado
  rei_revelado  o Rei sem máscara, olho âmbar (substitui o de máscara rachada)"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "painted", "derived", "portraits")
OUT = os.path.join(ROOT, "assets", "ui", "portraits")
SIZE = 128

# id -> (arquivo, centro x, centro y, lado do recorte) em pixels do PNG derivado.
# O centro fica um pouco abaixo dos olhos: rosto + cabelo no círculo.
CROPS = {
    "cego_aninhado":  ("cego_pequeno_aninhado.png",  440, 232, 350),
    "cego_assustado": ("cego_pequeno_assustado.png", 430, 230, 350),
    "cego_olhando":   ("cego_pequeno_olhando.png",   410, 180, 350),
    "cego_sereno":    ("cego_pequeno_sereno.png",    420, 230, 350),
    "rei_revelado":   ("rei_revelado.png",           280, 175, 330),
}

INK_TOP = np.array([22, 40, 50], dtype=np.float32)
INK_BOT = np.array([7, 14, 19], dtype=np.float32)


def build(pid: str, name: str, cx: int, cy: int, side: int) -> None:
    im = Image.open(os.path.join(SRC, name)).convert("RGBA")
    half = side // 2
    # recorte além da borda: o PIL completa com transparente (vira fundo)
    crop = im.crop((cx - half, cy - half, cx - half + side, cy - half + side))
    crop = crop.resize((SIZE, SIZE), Image.LANCZOS)
    a = np.asarray(crop).astype(np.float32)
    rgb, alpha = a[..., :3], a[..., 3] / 255.0
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    t = (yy / SIZE)[..., None]
    bg = INK_TOP * (1 - t) + INK_BOT * t
    d = np.sqrt((xx - SIZE * 0.5) ** 2 + (yy - SIZE * 0.42) ** 2) / (SIZE * 0.5)
    halo = np.clip(1.0 - d, 0.0, 1.0)[..., None] ** 2 * np.array([70, 55, 25], dtype=np.float32)
    bg = bg + halo
    out = rgb * alpha[..., None] + bg * (1 - alpha[..., None])
    r = np.sqrt((xx - SIZE / 2 + 0.5) ** 2 + (yy - SIZE / 2 + 0.5) ** 2)
    mask = np.clip((SIZE / 2 - 1.0 - r) / 1.5, 0.0, 1.0)
    img = np.dstack([np.clip(out, 0, 255), mask * 255.0]).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, pid + ".png"), optimize=True)
    print("retrato:", pid)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for pid, (name, cx, cy, side) in CROPS.items():
        build(pid, name, cx, cy, side)


if __name__ == "__main__":
    main()
