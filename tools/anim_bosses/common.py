"""Pipeline offline dos bonecos de chefe (GNOSIS) — utilidades comuns.

Recorta cada pintura da folha original NAS MESMAS coordenadas (Rect2 do
PaintedLibrary), calcula o alfa com a mesma fórmula do painted_key.gdshader e
preenche a cor por baixo do alfa 0 (evita franja magenta no filtro bilinear).
"""
import os
import numpy as np
import cv2

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PAINTED = os.path.join(ROOT, "assets", "painted")
OUT = os.path.join(PAINTED, "derived", "puppets")

# Mesmas regiões de scripts/fx/painted_library.gd (identidade do boneco -> folha, Rect2)
ARCHON_RECTS = [(0,0,379,505),(379,0,408,503),(787,0,380,516),(1167,0,369,507),
	(0,506,373,518),(373,523,427,473),(800,510,367,514),(1167,507,369,517)]
PUPPETS = {i: ("archons", r) for i, r in enumerate(ARCHON_RECTS)}
PUPPETS[8] = ("yaldabaoth", (15,0,1046,1024))
NAMES = ["athoth","harmas","galila","yabel","astaphaios","belias","armupiel","colosso","rei"]


def smoothstep(e0, e1, x):
	t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def load_crop(identity):
	"""Devolve (rgb float32 0..1, alfa float32 0..1) do recorte, já sem o magenta."""
	sheet, (x, y, w, h) = PUPPETS[identity]
	img = cv2.imread(os.path.join(PAINTED, sheet + ".png"), cv2.IMREAD_COLOR)
	img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
	crop = img[y:y+h, x:x+w].copy()
	r, g, b = crop[..., 0], crop[..., 1], crop[..., 2]
	key = np.minimum(r, b) - g
	cut = smoothstep(0.20, 0.48, key)
	spill = np.maximum(0.0, key - 0.08) * 0.8
	crop[..., 0] = np.maximum(0.0, r - spill)
	crop[..., 2] = np.maximum(0.0, b - spill)
	alpha = smoothstep(0.10, 0.85, 1.0 - cut)
	return crop, alpha.astype(np.float32)


def pad_color(rgb, alpha, iterations=24):
	"""Espalha a cor das bordas para dentro do transparente (sangria de textura)."""
	rgb = rgb.copy()
	known = alpha > 0.35
	acc = rgb * known[..., None]
	weight = known.astype(np.float32)
	for _ in range(iterations):
		blur = cv2.blur(acc, (3, 3))
		wb = cv2.blur(weight, (3, 3))
		fill = (~known) & (wb > 1e-4)
		rgb[fill] = blur[fill] / wb[fill][:, None]
		known = known | fill
		acc = rgb * known[..., None]
		weight = known.astype(np.float32)
	return rgb


def save_rgba(path, rgb, alpha):
	out = np.dstack([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)])
	out = (out * 255.0 + 0.5).astype(np.uint8)
	cv2.imwrite(path, cv2.cvtColor(out, cv2.COLOR_RGBA2BGRA))


def poly_mask(shape, uv_points, feather=0.0):
	"""Máscara 0..1 de um polígono em UV (0..1 do recorte)."""
	h, w = shape[:2]
	pts = np.array([[u * w, v * h] for u, v in uv_points], np.float32)
	m = np.zeros((h, w), np.uint8)
	cv2.fillPoly(m, [np.round(pts * 4).astype(np.int32)], 255, lineType=cv2.LINE_AA, shift=2)
	m = m.astype(np.float32) / 255.0
	if feather > 0:
		m = cv2.GaussianBlur(m, (0, 0), feather)
	return m


def preview(rgb, alpha, bg=(0.07, 0.09, 0.11)):
	bgc = np.array(bg, np.float32)
	comp = rgb * alpha[..., None] + bgc * (1 - alpha[..., None])
	return cv2.cvtColor((np.clip(comp, 0, 1) * 255).astype(np.uint8), cv2.COLOR_RGB2BGR)
