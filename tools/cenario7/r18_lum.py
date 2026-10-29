"""R18 (cenario7): igual ao tools/anim/contrast_r18.py (borda 2 px por dentro × anel
3–8 px por fora, imagem _on), mas imprime também as luminâncias e a parte de cima/
baixo do anel — para saber se o fundo atrás da Sophia precisa CLAREAR ou ESCURECER.
Uso: python tools/cenario7/r18_lum.py <base> [<base> ...]"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage


def lum(rgb):
	c = rgb / 255.0
	c = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
	return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]


def ratio(a, b):
	return (max(a, b) + 0.05) / (min(a, b) + 0.05)


def measure(base, which="_on"):
	off = np.asarray(Image.open(base + "_off.png").convert("RGB")).astype(np.float32)
	img = np.asarray(Image.open(base + which + ".png").convert("RGB")).astype(np.float32)
	bg = np.asarray(Image.open(base + "_bg.png").convert("RGB")).astype(np.float32)
	mask = np.abs(off - bg).sum(2) > 24
	mask = ndimage.binary_opening(mask, iterations=1)
	lab, n = ndimage.label(mask)
	if n == 0:
		return None
	sizes = ndimage.sum(mask, lab, range(1, n + 1))
	mask = lab == (int(np.argmax(sizes)) + 1)
	inner = mask & ~ndimage.binary_erosion(mask, iterations=2)
	ring = ndimage.binary_dilation(mask, iterations=8) & ~ndimage.binary_dilation(mask, iterations=3)
	L = lum(img)
	ys = np.nonzero(mask)[0]
	mid = (ys.min() + ys.max()) / 2
	yy = np.arange(L.shape[0])[:, None] * np.ones((1, L.shape[1]))
	lf, lb = float(L[inner].mean()), float(L[ring].mean())
	return {"r": ratio(lf, lb), "lf": lf, "lb": lb,
		"lb_top": float(L[ring & (yy < mid)].mean()), "lb_bot": float(L[ring & (yy >= mid)].mean()),
		"lf_top": float(L[inner & (yy < mid)].mean()), "lf_bot": float(L[inner & (yy >= mid)].mean()),
		"bbox": (int(ys.min()), int(ys.max()))}


if __name__ == "__main__":
	for b in sys.argv[1:]:
		m = measure(b)
		if m is None:
			print(b, "sem Sophia")
			continue
		print("%-10s %.2f:1 | borda %.3f (cima %.3f baixo %.3f) | anel %.3f (cima %.3f baixo %.3f) | y %d-%d" % (
			b.split("/")[-1], m["r"], m["lf"], m["lf_top"], m["lf_bot"], m["lb"], m["lb_top"], m["lb_bot"], m["bbox"][0], m["bbox"][1]))
