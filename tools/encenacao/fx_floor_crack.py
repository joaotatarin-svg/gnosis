"""ENCENAÇÃO (pipeline, não roda no jogo): decalque da FENDA DO CHÃO do roubo.
Entrada: artes/gpt/fx/fx_floor_crack_a.png (Produção GPT, 3×2 quadros de 512 px
sobre magenta: fissura → ramifica → luz âmbar → placas caindo → abismo → poeira;
cada quadro é um bloco de piso gótico em 3/4 com o rodapé).
Saída: assets/cinematic/fx_floor_crack_a.png — tira horizontal de 6 quadros, só o
TAMPO do bloco (sem o rodapé), magenta removido com despill e borda oval suave
para fundir no chão do jogo. `Staging._FloorCrack` toca os quadros pelo `open`.
Uso: python -I tools/encenacao/fx_floor_crack.py   (na raiz do projeto)"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC = "artes/gpt/fx/fx_floor_crack_a.png"
OUT = "assets/cinematic/fx_floor_crack_a.png"
COLS, ROWS = 3, 2
# Recorte do tampo dentro de cada quadro de 512 (medido na folha).
TOP = (12, 150, 500, 400)
OUT_W = 420                       # largura de cada quadro na saída


def key_magenta(rgb: np.ndarray) -> tuple:
    r, g, b = rgb[..., 0].astype(np.float32), rgb[..., 1].astype(np.float32), rgb[..., 2].astype(np.float32)
    # "magentice": quanto R e B passam de G
    m = np.minimum(r, b) - g
    alpha = np.clip(1.0 - (m - 60.0) / 90.0, 0.0, 1.0)
    # despill: tira o excesso de R/B onde o magenta vazou
    spill = np.clip(m, 0, None) * (1.0 - alpha * 0.0)
    lim = g + np.clip(np.minimum(r, b) - g, 0, None) * 0.35
    r2 = np.where(m > 10, np.minimum(r, np.maximum(lim, g)), r)
    b2 = np.where(m > 10, np.minimum(b, np.maximum(lim, g)), b)
    out = np.stack([r2, g, b2], axis=-1)
    return out, alpha


def main() -> int:
    sheet = Image.open(SRC).convert("RGB")
    cw, ch = sheet.width // COLS, sheet.height // ROWS
    frames = []
    for row in range(ROWS):
        for col in range(COLS):
            cell = sheet.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))
            cell = cell.crop(TOP)
            rgb, alpha = key_magenta(np.asarray(cell))
            w, h = cell.size
            # borda oval suave: o tampo some nas pontas e funde no chão do jogo
            mask = Image.new("L", (w, h), 0)
            ImageDraw.Draw(mask).ellipse((w * 0.04, h * 0.06, w * 0.96, h * 0.98), fill=255)
            mask = mask.filter(ImageFilter.GaussianBlur(min(w, h) * 0.09))
            a = (alpha * (np.asarray(mask).astype(np.float32) / 255.0) * 255.0).astype(np.uint8)
            im = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")
            im.putalpha(Image.fromarray(a, "L"))
            oh = int(round(h * OUT_W / w))
            frames.append(im.resize((OUT_W, oh), Image.LANCZOS))
    fh = frames[0].height
    strip = Image.new("RGBA", (OUT_W * len(frames), fh), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * OUT_W, 0), f)
    strip.save(OUT)
    print(OUT, strip.size, "quadros:", len(frames), "de", OUT_W, "x", fh)
    return 0


if __name__ == "__main__":
    sys.exit(main())
