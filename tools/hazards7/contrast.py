"""Contraste do AVISO dos perigos contra os fundos (R18 / QA7 #25).

O aviso por código é uma borda tripla: ESCURA por fora (INK, 2,8 px), VERMELHA
(WARN_COL, 1,6 px) e um FIO QUENTE claro (0,8 px). Ele lê se PELO MENOS uma tem
contraste >= 3:1 com o fundo local (WCAG 1.4.11 adaptado); e a vermelha contra a
escura tem ~6:1, então a forma da borda sempre se destaca.
Também confere a marca clara do campo de silêncio (pálida + sublinhado escuro).

Uso: python contrast.py <imagem ou pasta> [...]
Amostra blocos de 16x16 na faixa de jogo (40%..95% da altura) e informa,
por imagem, o pior bloco e a fração de blocos que passam.
"""
import glob
import os
import sys

import numpy as np
from PIL import Image

INK = (0.04, 0.04, 0.06)
WARN = (1.0, 0.32, 0.25)
PALE = (0.86, 0.9, 0.98)
HOT = (1.0, 0.74, 0.68)       # fio quente no meio da borda (Onda 7)


def lin(c):
	c = np.asarray(c, np.float64)
	return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lum(rgb):
	l = lin(rgb)
	return 0.2126 * l[..., 0] + 0.7152 * l[..., 1] + 0.0722 * l[..., 2]


def ratio(a, b):
	hi, lo = np.maximum(a, b), np.minimum(a, b)
	return (hi + 0.05) / (lo + 0.05)


def check(path):
	im = np.asarray(Image.open(path).convert("RGB"), np.float64) / 255.0
	h, w = im.shape[:2]
	band = im[int(h * 0.4):int(h * 0.95)]
	bh, bw = band.shape[0] // 16 * 16, band.shape[1] // 16 * 16
	blocks = band[:bh, :bw].reshape(bh // 16, 16, bw // 16, 16, 3).mean((1, 3))
	L = lum(blocks)
	l_ink, l_warn, l_pale = lum(np.array(INK)), lum(np.array(WARN)), lum(np.array(PALE))
	l_hot = lum(np.array(HOT))
	warn_ok = np.maximum(np.maximum(ratio(L, l_ink), ratio(L, l_warn)), ratio(L, l_hot))
	pale_ok = np.maximum(ratio(L, l_ink), ratio(L, l_pale))
	return float(warn_ok.min()), float((warn_ok >= 3.0).mean()), float(pale_ok.min()), float(L.mean())


def main():
	files = []
	for a in sys.argv[1:]:
		files += sorted(glob.glob(os.path.join(a, "*.png"))) if os.path.isdir(a) else [a]
	print("%-44s %8s %7s %8s %6s" % ("imagem", "aviso_min", "%>=3", "palido", "lum"))
	worst = 99.0
	for f in files:
		mn, frac, pmn, lm = check(f)
		worst = min(worst, mn)
		print("%-44s %8.2f %6.0f%% %8.2f %6.3f" % (os.path.basename(f)[:44], mn, frac * 100, pmn, lm))
	print("PIOR aviso_min: %.2f (>= 3,0 = legível em todo bloco)" % worst)
	print("razão vermelho x escuro (forma da borda): %.1f" % ratio(lum(np.array(WARN)), lum(np.array(INK))))


if __name__ == "__main__":
	main()
