"""Perigos pintados (Onda 7) — funções comuns do recorte das folhas hz_1..hz_7.

As folhas do GPT (artes/gpt/hazards/hz_<n>_*_a.png) são grades 2x3 de células
512x512: linha de cima = perigo A em 3 estados, linha de baixo = perigo B.
- hz_1 veio com FUNDO TRANSPARENTE (alfa real, com halo escuro de alfa ~0..10);
- hz_2..hz_7 vêm com fundo MAGENTA (chave + desmistura do clean_sheets.key_array);
- hz_1..hz_3 têm linhas finas de GRADE entre as células (apagadas aqui).
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "anim"))
from clean_sheets import key_array  # noqa: E402  (mesma chave das outras folhas)

SRC = os.path.join(ROOT, "artes", "gpt", "hazards")
OUT = os.path.join(ROOT, "assets", "painted", "hazards")
CELL = 512


def load_keyed(name: str) -> np.ndarray:
	"""Folha → RGBA float (0..255, alfa 0..1) com fundo removido e grade apagada."""
	im = Image.open(os.path.join(SRC, name))
	if im.mode == "RGBA" and np.array(im)[..., 3].min() == 0:
		a8 = np.array(im).astype(np.float32)
		rgb = a8[..., :3]
		a = a8[..., 3] / 255.0
		# halo escuro de alfa baixíssimo (0..12/255) e poeira somem
		a = np.where(a < 0.05, 0.0, a)
		# o halo "sombra" em volta das peças é escuro e meio transparente: corta
		lum = rgb.mean(-1)
		a = np.where((a < 0.55) & (lum < 30.0), 0.0, a)
	else:
		c = np.array(im.convert("RGB")).astype(np.float32)
		rgb, a, _k = key_array(c)
	a = erase_grid(name, a)
	return np.dstack([rgb, a])


# Linhas da GRADE por folha (medidas: hz_1 tem a divisória horizontal em y≈442,
# não em 512; as outras dividem em 512). Bandas de ±4 px e 3 px da moldura.
SPLITS = {"hz_1": ([512, 1024], [442]), "hz_2": ([512, 1024], [512]), "hz_3": ([512, 1024], [512])}


def splits_of(name: str):
	return SPLITS.get(name[:4], ([512, 1024], [512]))


def erase_grid(name: str, a: np.ndarray) -> np.ndarray:
	"""Apaga as linhas finas de grade (e a moldura) das folhas que as têm."""
	if name[:4] not in SPLITS:
		return a
	a = a.copy()
	xs, ys = SPLITS[name[:4]]
	for x in xs:
		a[:, x - 4:x + 5] = 0.0
	for y in ys:
		a[y - 4:y + 5, :] = 0.0
	a[:3, :] = 0.0
	a[-3:, :] = 0.0
	a[:, :3] = 0.0
	a[:, -3:] = 0.0
	return a


def clean_specks(a: np.ndarray, min_px: int = 40, keep_near: int = 0) -> np.ndarray:
	"""Remove componentes minúsculos (poeira, restos de grade). `keep_near` > 0
	preserva peças pequenas a até N px do corpo principal (faíscas, lascas)."""
	m = a > 0.08
	lab, n = ndimage.label(m, structure=np.ones((3, 3), bool))
	if n == 0:
		return a
	sizes = ndimage.sum(m, lab, range(1, n + 1))
	big = np.zeros(n + 1, bool)
	big[1:] = sizes >= min_px
	keep = big[lab]
	if keep_near > 0 and keep.any():
		near = ndimage.binary_dilation(keep, iterations=keep_near)
		keep = keep | (m & near)
	return np.where(keep, a, 0.0)


def cell_rect(name: str, row: int, col: int):
	"""Retângulo (x0, y0, x1, y1) da célula na folha."""
	xs, ys = splits_of(name)
	bx = [0] + xs + [1536]
	by = [0] + ys + [1024]
	return bx[col], by[row], bx[col + 1], by[row + 1]


def cell(img: np.ndarray, name: str, row: int, col: int) -> np.ndarray:
	x0, y0, x1, y1 = cell_rect(name, row, col)
	return img[y0:y1, x0:x1].copy()


def bbox(a: np.ndarray, thr: float = 0.08):
	ys, xs = np.nonzero(a > thr)
	if len(xs) == 0:
		return None
	return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def fill_rgb(rgba: np.ndarray) -> np.ndarray:
	"""Cor dos pixels transparentes = cor do sólido mais próximo (sem franja no
	filtro bilinear/mipmap)."""
	rgb = rgba[..., :3]
	a = rgba[..., 3]
	solid = a > 0.5
	if solid.any() and (~solid).any():
		_, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
		rgb = np.where(solid[..., None], rgb, rgb[iy, ix])
	return np.dstack([rgb, a])


def save(path: str, rgba: np.ndarray) -> None:
	rgba = fill_rgb(rgba)
	out = np.dstack([np.clip(rgba[..., :3], 0, 255), np.clip(rgba[..., 3] * 255.0, 0, 255)]).astype(np.uint8)
	os.makedirs(os.path.dirname(path), exist_ok=True)
	Image.fromarray(out, "RGBA").save(path, optimize=True)


def resize(rgba: np.ndarray, scale: float) -> np.ndarray:
	"""Reduz com alfa pré-multiplicado (sem halo escuro/rosado na borda)."""
	h, w = rgba.shape[:2]
	nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
	a = rgba[..., 3:4]
	pm = np.dstack([rgba[..., :3] * a, a[..., 0] * 255.0])
	im = Image.fromarray(np.clip(pm, 0, 255).astype(np.uint8), "RGBA").resize((nw, nh), Image.LANCZOS)
	r = np.array(im).astype(np.float32)
	al = r[..., 3] / 255.0
	rgb = r[..., :3] / np.maximum(al, 1e-3)[..., None]
	return np.dstack([np.clip(rgb, 0, 255), al])


def preview(rgba: np.ndarray, bg=(70, 74, 82)) -> Image.Image:
	a = rgba[..., 3:4]
	out = rgba[..., :3] * a + np.array(bg, np.float32) * (1 - a)
	return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


# Divisória usada para DISTRIBUIR as peças entre as linhas (o centro de cada
# componente decide a célula): o totem da hz_4 desce até y≈600 e as correntes
# da hz_7 sobem acima de 512 — cortar a grade fixa decepava as peças.
ASSIGN_Y = {"hz_1": 442, "hz_4": 640, "hz_6": 500}


def cells(name: str, img: np.ndarray, min_px: int = 40):
	"""Peças da folha por célula: {(linha, coluna): (rgba_recortado, (x0, y0))}.
	Cada componente conectado vai para a célula do seu centro de massa."""
	a = img[..., 3]
	m = a > 0.08
	lab, n = ndimage.label(m, structure=np.ones((3, 3), bool))
	coms = ndimage.center_of_mass(m, lab, range(1, n + 1))
	sizes = ndimage.sum(m, lab, range(1, n + 1))
	xs, ys = splits_of(name)
	ys = [ASSIGN_Y.get(name[:4], ys[0])]
	owner = np.zeros(n + 1, np.int32) - 1
	for i, (cy, cx) in enumerate(coms):
		if sizes[i] < min_px:
			continue
		col = int(np.searchsorted(xs, cx, side="right"))
		row = int(np.searchsorted(ys, cy, side="right"))
		owner[i + 1] = row * 3 + col
	out = {}
	own = owner[lab]
	for r in range(2):
		for c in range(3):
			mask = own == r * 3 + c
			if not mask.any():
				continue
			yy, xx = np.nonzero(mask)
			x0, y0, x1, y1 = xx.min(), yy.min(), xx.max() + 1, yy.max() + 1
			crop = img[y0:y1, x0:x1].copy()
			crop[..., 3] = np.where(mask[y0:y1, x0:x1], crop[..., 3], 0.0)
			out[(r, c)] = (crop, (int(x0), int(y0)))
	return out
