"""PIPELINE DE FOLHAS LIMPAS (GNOSIS) — gera assets/painted/derived/<folha>.png.

Cada folha pintada vem com fundo magenta chapado (ou já RGBA, no caso de
`inhabitants`). O jogo recortava o magenta NO SHADER, depois do filtro bilinear:
a borda misturava pele com magenta antes do corte e sobrava franja rosa/escura,
e sem mipmaps as pinturas grandes exibidas a ~1/4 cintilavam.

Aqui o recorte vira offline e definitivo:
  1. estima a cor do fundo K pela mediana da moldura da folha;
  2. "quanto de K tem no pixel": s = min((r-g)/(Kr-Kg), (b-g)/(Kb-Kg));
     para fundo s~1, para tinta neutra s~0 → alfa = 1 - s (linear, com folgas);
  3. DESMISTURA a cor da borda: F = (C - (1-a)K) / a (tira o magenta de dentro
     do cabelo, dos véus translúcidos e do contorno);
  4. despill residual (borda) + EROSÃO de 1 px só onde encosta em fundo puro;
  5. pinta o RGB dos pixels transparentes com a cor do pixel opaco mais próximo
     (mipmap e bilinear não puxam preto/magenta pra dentro da borda).
Saída com as MESMAS dimensões e coordenadas da original (os Rect2 do
PaintedLibrary e do BossPuppet continuam valendo).

Uso:  python tools/anim/clean_sheets.py            (todas)
      python tools/anim/clean_sheets.py sophia      (só uma)
Relatório: imprime % de pixels transparentes/parciais e magenta residual.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "painted")
DST = os.path.join(SRC, "derived")

# folhas com fundo cromático (magenta / rosa) e a folha já recortada
KEYED = ["sophia", "archons", "yaldabaoth", "architecture"]
RGBA_READY = ["inhabitants"]

S_OPAQUE = 0.14   # s abaixo disto = tinta (alfa 1)
S_BG = 0.86       # s acima disto = fundo (alfa 0)


def fill_transparent_rgb(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
	"""RGB dos pixels quase transparentes = cor do pixel visível mais próximo."""
	solid = alpha > 0.5
	if not solid.any():
		return rgb
	_, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
	out = rgb.copy()
	hole = alpha <= 0.02
	out[hole] = rgb[iy[hole], ix[hole]]
	return out


def magenta_residual(rgb: np.ndarray, alpha: np.ndarray) -> int:
	"""Pixels visíveis com cara de fundo magenta (o que o QA mede)."""
	r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
	mag = (np.minimum(r, b) - g > 90) & (r > 170) & (b > 120) & (alpha > 0.25)
	return int(mag.sum())


def key_array(c: np.ndarray):
	"""Recorta o fundo cromático de uma imagem RGB float (0..255).
	Devolve (F, a, K): cor desmisturada, alfa 0..1 e a cor de fundo estimada.
	Reutilizado por build_frames.py (folhas novas da Sophia)."""
	border = np.concatenate([c[:4].reshape(-1, 3), c[-4:].reshape(-1, 3), c[:, :4].reshape(-1, 3), c[:, -4:].reshape(-1, 3)])
	K = np.median(border, 0)
	r, g, b = c[..., 0], c[..., 1], c[..., 2]
	s = np.minimum((r - g) / max(1.0, K[0] - K[1]), (b - g) / max(1.0, K[2] - K[1]))
	a = np.clip((S_BG - s) / (S_BG - S_OPAQUE), 0.0, 1.0)
	# ruído do fundo: componentes minúsculas com alfa baixo somem
	a[a < 0.04] = 0.0
	# desmistura: C = a*F + (1-a)*K  →  F = (C - (1-a)K)/a
	safe = np.maximum(a, 0.05)[..., None]
	F = (c - (1.0 - a)[..., None] * K[None, None, :]) / safe
	F = np.clip(F, 0.0, 255.0)
	# erosão de 1 px apenas no contorno que encosta em fundo puro
	pure_bg = a <= 0.0
	touch = ndimage.binary_dilation(pure_bg, structure=np.ones((3, 3), bool)) & ~pure_bg
	a_min = ndimage.minimum_filter(a, size=3)
	a = np.where(touch, np.minimum(a, 0.5 * a + 0.5 * a_min) * 0.85, a)
	# despill residual na borda: tira o tom magenta (r e b acima do g)
	edge = (a < 0.999) | ndimage.binary_dilation(touch, iterations=2)
	m = np.minimum(F[..., 0], F[..., 2]) - F[..., 1]
	spill = np.clip(m - 18.0, 0.0, None) * edge
	F[..., 0] -= spill
	F[..., 2] -= spill
	# a desmistura não pode inventar verde (r,b caíram demais): g <= max(r,b)
	F[..., 1] = np.where(edge, np.minimum(F[..., 1], np.maximum(F[..., 0], F[..., 2]) + 4.0), F[..., 1])
	F = np.clip(F, 0.0, 255.0)
	# pixel muito transparente tem cor desmisturada ruidosa: puxa pra cor do
	# vizinho sólido mais próximo (fio de cabelo continua da cor do cabelo)
	solid = a > 0.6
	if solid.any():
		_, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
		near = F[iy, ix]
		w = np.clip(1.0 - a / 0.6, 0.0, 1.0)[..., None] * 0.7
		F = F * (1.0 - w) + near * w
	F = fill_transparent_rgb(F, a)
	return F, a, K


def clean_keyed(name: str) -> None:
	img = Image.open(os.path.join(SRC, name + ".png")).convert("RGB")
	c = np.asarray(img).astype(np.float32)
	F, a, K = key_array(c)
	out = np.dstack([F, a * 255.0]).round().astype(np.uint8)
	os.makedirs(DST, exist_ok=True)
	Image.fromarray(out, "RGBA").save(os.path.join(DST, name + ".png"), optimize=True)
	part = ((a > 0) & (a < 1)).mean() * 100
	print("%-13s K=%s transp=%.1f%% parcial=%.2f%% magenta_resid=%d (antes no RGB cru: %d)" % (
		name, K.astype(int), (a == 0).mean() * 100, part, magenta_residual(F, a), magenta_residual(c, np.ones_like(a))))


def clean_rgba(name: str) -> None:
	img = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")
	c = np.asarray(img).astype(np.float32)
	a = c[..., 3] / 255.0
	# bichos já recortados: corpo "quase opaco" (252) vira opaco; névoa < 5% some
	a = np.where(a > 0.94, 1.0, a)
	a[a < 0.05] = 0.0
	rgb = fill_transparent_rgb(c[..., :3], a)
	out = np.dstack([rgb, a * 255.0]).round().astype(np.uint8)
	os.makedirs(DST, exist_ok=True)
	Image.fromarray(out, "RGBA").save(os.path.join(DST, name + ".png"), optimize=True)
	print("%-13s RGBA pronto: transp=%.1f%% parcial=%.2f%%" % (name, (a == 0).mean() * 100, ((a > 0) & (a < 1)).mean() * 100))


def main() -> None:
	only = sys.argv[1:]
	for n in KEYED:
		if not only or n in only:
			clean_keyed(n)
	for n in RGBA_READY:
		if not only or n in only:
			clean_rgba(n)


if __name__ == "__main__":
	main()
