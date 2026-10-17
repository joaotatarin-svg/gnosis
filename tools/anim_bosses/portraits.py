"""RETRATOS (bustos) recortados das folhas do GPT → assets/painted/derived/portraits/.

Fundo cromático estimado pela moldura (clean_sheets.key_array: alfa, desmistura,
despill), fatia por grade, pega o maior componente da célula (+ pedaços colados)
e recorta com margem. Saída RGBA.

  rei_revelado.png                 ← artes/gpt/rei_revelado_a.png, célula 5 (grade 3×2)
  cego_pequeno_<humor>.png         ← artes/gpt/retrato_cego_pequeno_a.png (2×2):
                                     assustado · olhando · sereno · aninhado
Uso: python tools/anim_bosses/portraits.py
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "anim"))
from clean_sheets import key_array  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "painted", "derived", "portraits")
JOBS = [
	("artes/gpt/rei_revelado_a.png", (3, 2), {5: "rei_revelado"}),
	("artes/gpt/retrato_cego_pequeno_a.png", (2, 2), {0: "cego_pequeno_assustado", 1: "cego_pequeno_olhando", 2: "cego_pequeno_sereno", 3: "cego_pequeno_aninhado"}),
]
PAD = 8


def main() -> None:
	os.makedirs(OUT, exist_ok=True)
	for sheet, (cols, rows), cells in JOBS:
		img = np.asarray(Image.open(os.path.join(ROOT, sheet)).convert("RGB")).astype(np.float32)
		F, a, K = key_array(img)
		H, W = a.shape
		cw, ch = W // cols, H // rows
		for idx, name in cells.items():
			x0, y0 = (idx % cols) * cw, (idx // cols) * ch
			ca = a[y0:y0 + ch, x0:x0 + cw]
			lab, n = ndimage.label(ca > 0.05, structure=np.ones((3, 3), bool))
			if n == 0:
				continue
			sizes = ndimage.sum(np.ones_like(ca), lab, range(1, n + 1))
			main = int(np.argmax(sizes)) + 1
			# o corpo + pedaços grandes (fios de cabelo soltos colados ficam)
			keep = [i + 1 for i in range(n) if sizes[i] >= 0.002 * sizes[main - 1] or i + 1 == main]
			m = np.isin(lab, keep)
			ys, xs = np.nonzero(m)
			by0, by1 = max(0, ys.min() - PAD), min(ch, ys.max() + 1 + PAD)
			bx0, bx1 = max(0, xs.min() - PAD), min(cw, xs.max() + 1 + PAD)
			al = (ca * m)[by0:by1, bx0:bx1]
			rgb = F[y0 + by0:y0 + by1, x0 + bx0:x0 + bx1].copy()
			# fios de cabelo finos misturados ao fundo: despill forte (tira o
			# rosa/roxo onde r e b sobram sobre o g), em qualquer alfa
			spill = np.clip(np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1] - 12.0, 0.0, None)
			rgb[..., 0] -= spill
			rgb[..., 2] -= spill
			out = np.dstack([rgb, al * 255.0]).round().clip(0, 255).astype(np.uint8)
			Image.fromarray(out, "RGBA").save(os.path.join(OUT, name + ".png"), optimize=True)
			print("%-26s %dx%d  (fundo %s)" % (name, out.shape[1], out.shape[0], K.astype(int)))


if __name__ == "__main__":
	main()
