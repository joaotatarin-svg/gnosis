"""Gera as camadas derivadas dos bonecos de chefe (GNOSIS).

Uso:  python tools/anim_bosses/build_puppets.py [--preview DIR]

Para cada boneco (mesmas coordenadas do PaintedLibrary):
  <nome>_body.png  — corpo RGBA com alfa real; armas/cristais removidos e o que
                     ficava por trás reconstruído (OpenCV inpaint) onde há corpo.
  <nome>_parts.png — só as peças rígidas (lâmina, cajado, cristais), alfa real.
As peças continuam com as coordenadas UV do recorte original: o GDScript usa os
MESMOS polígonos (scripts/fx/boss_puppet.gd, PARTS) para montar as peças.
"""
import os, sys, json
import numpy as np
import cv2
import common

# Polígonos em UV do recorte. Mantenha em sincronia com BossPuppet.PARTS.
PARTS = {
	2: {"weapon": [(0.50,0.465),(0.535,0.48),(0.575,0.505),(0.60,0.50),(0.615,0.525),(0.67,0.56),(0.685,0.585),(0.655,0.59),(0.60,0.575),(0.475,0.752),(0.336,0.912),(0.247,0.997),(0.205,0.997),(0.198,0.97),(0.318,0.828),(0.438,0.69),(0.53,0.57),(0.55,0.535),(0.52,0.50)]},
	6: {"weapon": [(0.589,0.50),(0.64,0.513),(0.70,0.515),(0.745,0.52),(0.792,0.56),(0.802,0.60),(0.778,0.636),(0.70,0.648),(0.61,0.692),(0.465,0.762),(0.31,0.85),(0.20,0.912),(0.116,0.958),(0.066,0.988),(0.056,0.975),(0.066,0.935),(0.094,0.873),(0.148,0.81),(0.226,0.748),(0.308,0.702),(0.384,0.636),(0.492,0.58),(0.568,0.534)]},
	4: {"weapon": [[(0.08,0.165),(0.085,0.10),(0.14,0.045),(0.175,-0.01),(0.205,-0.01),(0.235,0.045),(0.28,0.075),(0.34,0.125),(0.315,0.18),(0.27,0.215),(0.258,0.245),(0.248,0.292),(0.212,0.292),(0.195,0.245),(0.15,0.215),(0.10,0.21)],
			[(0.2326,0.345),(0.3205,0.83),(0.322,0.86),(0.326,0.89),(0.348,0.975),(0.356,0.998),(0.364,0.998),(0.368,0.975),(0.352,0.89),(0.352,0.86),(0.3405,0.83),(0.2506,0.345)]],
		"crystal_0": [(0.128,0.235),(0.146,0.235),(0.19,0.35),(0.17,0.46),(0.15,0.46),(0.10,0.35)],
		"crystal_1": [(0.195,0.43),(0.215,0.43),(0.24,0.52),(0.22,0.605),(0.19,0.605),(0.175,0.52)],
		"crystal_2": [(0.32,0.165),(0.368,0.16),(0.368,0.262),(0.326,0.262)],
		"crystal_3": [(0.368,0.015),(0.435,-0.005),(0.435,0.152),(0.37,0.152)],
		"crystal_4": [(0.70,0.055),(0.765,0.055),(0.805,0.17),(0.785,0.255),(0.745,0.255),(0.705,0.15)],
		"crystal_5": [(0.715,0.245),(0.765,0.245),(0.78,0.32),(0.755,0.395),(0.725,0.395),(0.71,0.32)],
		"crystal_6": [(0.815,0.185),(0.885,0.185),(0.935,0.33),(0.895,0.485),(0.845,0.485),(0.805,0.33)]},
}


METHOD = "shiftmap"
# Alcance (fração da largura) da busca de corpo dos dois lados da peça.
REACH = {4: 0.05}


def inpaint(rgb, alpha, hole_b):
	"""Reconstrói o que ficava atrás da peça. O fundo transparente também é
	marcado como desconhecido (senão a franja magenta escura vaza para dentro)."""
	unknown = (hole_b > 0) | (alpha < 0.6)
	img8 = (np.clip(common.pad_color(rgb, alpha * (1 - hole_b)), 0, 1) * 255).astype(np.uint8)
	if METHOD == "telea":
		out = cv2.inpaint(img8, unknown.astype(np.uint8) * 255, 9, cv2.INPAINT_TELEA)
	else:
		valid = (~unknown).astype(np.uint8) * 255
		out = np.zeros_like(img8)
		flag = cv2.xphoto.INPAINT_FSR_FAST if METHOD == "fsr" else cv2.xphoto.INPAINT_SHIFTMAP
		src = cv2.cvtColor(img8, cv2.COLOR_RGB2BGR)
		cv2.xphoto.inpaint(src, valid, out, flag)
		out = cv2.cvtColor(out, cv2.COLOR_BGR2RGB)
	return out.astype(np.float32) / 255.0


def body_behind(rest, hole_b, reach):
	"""Pixel do furo fica com corpo se houver corpo dos DOIS lados (em alguma
	das 4 direções) a menos de `reach` px — a peça cruzava o corpo ali."""
	h, w = rest.shape
	r = rest > 0
	behind = np.zeros_like(r)
	for dx, dy in [(1, 0), (0, 1), (1, 1), (1, -1)]:
		hits = []
		for sgn in (1, -1):
			acc = np.zeros_like(r)
			for k in range(1, reach + 1):
				sx, sy = dx * k * sgn, dy * k * sgn
				shifted = np.zeros_like(r)
				ys = slice(max(0, -sy), min(h, h - sy)); yd = slice(max(0, sy), min(h, h + sy))
				xs = slice(max(0, -sx), min(w, w - sx)); xd = slice(max(0, sx), min(w, w + sx))
				shifted[yd, xd] = r[ys, xs]
				acc |= shifted
			hits.append(acc)
		behind |= hits[0] & hits[1]
	return behind & (hole_b > 0)


def drop_islands(alpha, min_area):
	"""Some com farelos soltos (pontas de espinho que sobraram fora do polígono)."""
	m = (alpha > 0.3).astype(np.uint8)
	n, lab, stats, _ = cv2.connectedComponentsWithStats(m, 8)
	keep = np.zeros(n, bool)
	keep[1:] = stats[1:, cv2.CC_STAT_AREA] >= min_area
	grown = cv2.dilate((keep[lab] & (m > 0)).astype(np.uint8), np.ones((3, 3), np.uint8))
	return alpha * grown


def build(identity, preview_dir=None):
	name = common.NAMES[identity]
	rgb, alpha = common.load_crop(identity)
	h, w = alpha.shape
	body_rgb = rgb.copy()
	body_a = alpha.copy()
	parts = PARTS.get(identity, {})
	if parts:
		parts_a = np.zeros_like(alpha)
		hole = np.zeros_like(alpha)
		for pid, poly in parts.items():
			for sub in (poly if isinstance(poly[0], list) else [poly]):
				m = common.poly_mask(alpha.shape, sub, 0.6)
				parts_a = np.maximum(parts_a, m * alpha)
				hole = np.maximum(hole, m)
		# Buraco do corpo um pouco maior que a peça: sem fantasma da borda da lâmina.
		hole_b = (hole > 0.02).astype(np.uint8)
		hole_b = cv2.dilate(hole_b, np.ones((5, 5), np.uint8))
		rest = (alpha > 0.5).astype(np.uint8) * (1 - hole_b)
		behind = body_behind(rest, hole_b, int(REACH.get(identity, 0.30) * w))
		fill = inpaint(rgb, alpha, hole_b)
		body_rgb = np.where(hole_b[..., None] > 0, fill, rgb)
		body_a = np.where(hole_b > 0, 0.0, alpha)
		soft = cv2.GaussianBlur(behind.astype(np.float32), (0, 0), 1.2)
		body_a = np.maximum(body_a, np.where(hole_b > 0, np.clip(soft * 1.6, 0, 1), 0))
		parts_rgb = common.pad_color(rgb, parts_a)
		common.save_rgba(os.path.join(common.OUT, name + "_parts.png"), parts_rgb, parts_a)
		if preview_dir:
			cv2.imwrite(os.path.join(preview_dir, name + "_parts_prev.png"), common.preview(rgb, parts_a))
	body_a = drop_islands(body_a, int(0.0015 * w * h))
	body_rgb = common.pad_color(body_rgb, body_a)
	common.save_rgba(os.path.join(common.OUT, name + "_body.png"), body_rgb, body_a)
	if preview_dir:
		cv2.imwrite(os.path.join(preview_dir, name + "_body_prev.png"), common.preview(body_rgb, body_a))
	return name


if __name__ == "__main__":
	os.makedirs(common.OUT, exist_ok=True)
	prev = None
	if "--preview" in sys.argv:
		prev = sys.argv[sys.argv.index("--preview") + 1]
		os.makedirs(prev, exist_ok=True)
	if "--method" in sys.argv:
		METHOD = sys.argv[sys.argv.index("--method") + 1]
	only = [int(a) for a in sys.argv[1:] if a.isdigit()]
	for i in (only or range(9)):
		print("boneco", i, build(i, prev))
