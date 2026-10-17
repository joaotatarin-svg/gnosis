"""Gera os retratos circulares da UI (HUD e caixa de diálogo) a partir das
folhas ilustradas de assets/painted/. Pipeline versionado do diretor de UI.
Uso (na raiz do projeto):  python -I assets/ui/build_portraits.py
Saída: assets/ui/portraits/<id>.png  (128x128 RGBA, fundo azul-noite, máscara
circular com borda suave — a moldura dourada é desenhada pelo jogo)."""
import os
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PAINTED = os.path.join(ROOT, "assets", "painted")
OUT = os.path.join(ROOT, "assets", "ui", "portraits")
SIZE = 128

# id -> (folha, centro x, centro y, lado do recorte) em pixels da folha
CROPS = {
    "sophia":     ("sophia.png",      272,  74, 104),
    "athoth":     ("archons.png",     176,  96, 120),
    "harmas":     ("archons.png",     544, 120, 190),
    "galila":     ("archons.png",     904,  86, 130),
    "yabel":      ("archons.png",    1280,  84, 130),
    "astaphaios": ("archons.png",     190, 600, 120),
    "belias":     ("archons.png",     430, 690, 150),
    "armupiel":   ("archons.png",     930, 586, 140),
    "rei":        ("yaldabaoth.png",  554,  86, 150),
    "soter":      ("inhabitants.png", 250, 828, 100),
    "velkar":     ("inhabitants.png", 722, 852, 110),
}

INK_TOP = np.array([22, 40, 50], dtype=np.float32)      # azul-noite claro
INK_BOT = np.array([7, 14, 19], dtype=np.float32)       # azul-noite fundo


def key_alpha(rgb: np.ndarray) -> np.ndarray:
    """Alfa a partir do fundo magenta das folhas (1 = figura, 0 = fundo)."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mag = np.clip(((r + b) * 0.5 - g - 60.0) / 90.0, 0.0, 1.0)
    return 1.0 - mag


def build(pid: str, sheet: str, cx: int, cy: int, side: int) -> None:
    im = Image.open(os.path.join(PAINTED, sheet)).convert("RGBA")
    half = side // 2
    crop = im.crop((cx - half, cy - half, cx - half + side, cy - half + side))
    crop = crop.resize((SIZE, SIZE), Image.LANCZOS)
    a = np.asarray(crop).astype(np.float32)
    rgb, alpha = a[..., :3], a[..., 3] / 255.0
    if sheet != "inhabitants.png":
        alpha = alpha * key_alpha(rgb)
    # Fundo: gradiente vertical azul-noite + halo dourado discreto atrás da cabeça.
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    t = (yy / SIZE)[..., None]
    bg = INK_TOP * (1 - t) + INK_BOT * t
    d = np.sqrt((xx - SIZE * 0.5) ** 2 + (yy - SIZE * 0.42) ** 2) / (SIZE * 0.5)
    halo = np.clip(1.0 - d, 0.0, 1.0)[..., None] ** 2 * np.array([70, 55, 25], dtype=np.float32)
    bg = bg + halo
    # Remove a franja magenta que sobra nas bordas da figura.
    fringe = np.clip(1.0 - alpha, 0, 1)[..., None]
    rgb = rgb * (1 - fringe * 0.6) + np.array([30, 25, 30], dtype=np.float32) * fringe * 0.6
    out = rgb * alpha[..., None] + bg * (1 - alpha[..., None])
    # Máscara circular com borda suave (o anel dourado cobre a borda no jogo).
    r = np.sqrt((xx - SIZE / 2 + 0.5) ** 2 + (yy - SIZE / 2 + 0.5) ** 2)
    mask = np.clip((SIZE / 2 - 1.0 - r) / 1.5, 0.0, 1.0)
    img = np.dstack([np.clip(out, 0, 255), mask * 255.0]).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, pid + ".png"))


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for pid, (sheet, cx, cy, side) in CROPS.items():
        build(pid, sheet, cx, cy, side)
        print("retrato:", pid)


if __name__ == "__main__":
    main()
