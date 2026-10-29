"""NEURO R18 — contraste da Sophia contra o fundo LOCAL (WCAG: (L1+0,05)/(L2+0,05)).
Lê <base>_off.png, <base>_on.png e <base>_bg.png (tools/ContrastProbe.tscn).
Máscara = onde _off difere do fundo puro. Mede:
  borda  = faixa de 2 px por DENTRO da silhueta (o que o olho usa para separar)
  fundo  = anel de 3–8 px por FORA
e o contraste borda×fundo antes (off) e depois (on). Uso: contrast_r18.py <base> [<base> ...]"""
import sys

import numpy as np
from PIL import Image
from scipy import ndimage


def lum(rgb: np.ndarray) -> np.ndarray:
	c = rgb / 255.0
	c = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
	return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]


def ratio(a: float, b: float) -> float:
	hi, lo = max(a, b), min(a, b)
	return (hi + 0.05) / (lo + 0.05)


for base in sys.argv[1:]:
	off = np.asarray(Image.open(base + "_off.png").convert("RGB")).astype(np.float32)
	on = np.asarray(Image.open(base + "_on.png").convert("RGB")).astype(np.float32)
	bg = np.asarray(Image.open(base + "_bg.png").convert("RGB")).astype(np.float32)
	mask = np.abs(off - bg).sum(2) > 24
	mask = ndimage.binary_opening(mask, iterations=1)
	lab, n = ndimage.label(mask)
	if n == 0:
		print(base, "sem Sophia na imagem")
		continue
	sizes = ndimage.sum(mask, lab, range(1, n + 1))
	mask = lab == (int(np.argmax(sizes)) + 1)
	inner = mask & ~ndimage.binary_erosion(mask, iterations=2)
	ring = ndimage.binary_dilation(mask, iterations=8) & ~ndimage.binary_dilation(mask, iterations=3)
	out = []
	for name, img in (("antes", off), ("depois", on)):
		L = lum(img)
		lb, lf = float(L[ring].mean()), float(L[inner].mean())
		out.append("%s %.2f:1" % (name, ratio(lf, lb)))
	print("%s  borda×fundo: %s" % (base.replace("\\\\", "/").split("/")[-1], " | ".join(out)))
