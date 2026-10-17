"""ATLAS DE QUADROS POR PERSONAGEM (GNOSIS) — genérico para N folhas / N quadros.

Lê uma RECEITA (ex.: tools/anim/sophia_recipe.json) e gera:
  assets/painted/derived/<char>_frames.png       atlas RGBA (alfa real, mipmaps no .import)
  assets/painted/derived/<char>_frames_flex.png  máscara de movimento secundário
                                                 (R = cabelo, G = barras do manto)
  assets/painted/derived/<char>_frames.json      quadros (rect no atlas, medidas) e
                                                 estados → sequência com ÂNCORA por quadro
  C:/gnosis-wt/_caps/anim-sophia/frames_contact.png  prancha de conferência (opcional)

Passos por folha: recorte cromático (clean_sheets.key_array: alfa linear,
desmistura, despill, erosão 1 px) → fatia por GRADE + COMPONENTES CONECTADOS
(cada pedaço vai pra célula do seu centróide: o cajado solto no chão continua
no quadro certo) → mede na máscara (linha do pé, botas, pélvis, quadril, orbe
do cajado) → normaliza a ESCALA ÚNICA (altura em pé do quadro de referência =
body_px; cada folha pode ter `scale` e cada quadro `frame_fix`) → empacota.

Âncoras (onde fica o x=0/chão do nó em cada quadro):
  front  bota da frente travada no mesmo ponto do mundo (golpes/idle)
  rear   bota de trás travada (recuo, dano)
  pelvis pélvis no x=0, pé na linha do chão (corrida, esquiva)
  air    pélvis no x=0 e quadril na altura do quadril em pé (pulo/queda/aéreos)
  lying  corpo deitado: centro do corpo em x=0, ponto mais baixo no chão
Um quadro pode forçar o modo: "s1a.hurt@rear".

Uso: python tools/anim/build_frames.py [receita.json] [--no-contact]
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
from clean_sheets import fill_transparent_rgb, key_array  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DER = os.path.join(ROOT, "assets", "painted", "derived")
CAPS = "C:/gnosis-wt/_caps/anim-sophia"
PAD = 6          # margem transparente de cada quadro no atlas
ATLAS_W = 2048


# ---------------------------------------------------------------- medidas
def boots_of(mask: np.ndarray, k: int):
	"""Botas = componentes largas na faixa de baixo (o cajado fino some na abertura)."""
	rows = np.nonzero(mask.any(1))[0]
	if rows.size == 0:
		return []
	bottom = int(rows.max())
	band = np.zeros_like(mask)
	top = max(0, bottom - 9 * k)
	band[top: bottom + 1] = mask[top: bottom + 1]
	opened = ndimage.binary_opening(band, structure=np.ones((2 * k + 1, 2 * k + 1), bool))
	lab, n = ndimage.label(opened)
	boots = []
	for i in range(1, n + 1):
		yy, xx = np.nonzero(lab == i)
		if yy.size < 4 * k * k or xx.max() - xx.min() < 4 * k:
			continue      # pequeno ou fino demais (ponta do cajado no chão) não é bota
		b = int(yy.max())
		low = yy >= b - max(2, k // 2)
		boots.append({"x0": int(xx.min()), "x1": int(xx.max()), "contact_x": float(xx[low].mean()), "bottom": b})
	boots.sort(key=lambda d: d["contact_x"])
	return boots


def measure(rgba: np.ndarray) -> dict:
	"""Medidas de um quadro já recortado (coordenadas locais do quadro)."""
	a = rgba[..., 3] > 128
	ys, xs = np.nonzero(a)
	H = rgba.shape[0]
	k = max(3, int(round(H / 75.0)))          # ~6 px a 466 de altura
	bts = boots_of(a, k)
	bottom = int(ys.max())
	foot_y = max([b["bottom"] for b in bts], default=bottom)
	body = ndimage.binary_opening(a, structure=np.ones((3 * k, 3 * k), bool))
	if not body.any():
		body = a
	byy, bxx = np.nonzero(body)
	top = int(byy.min())
	hip_y = int(foot_y - 0.47 * (foot_y - top))
	row = body[max(0, hip_y - k): hip_y + k]
	_, hx = np.nonzero(row)
	pelvis_x = float(hx.mean()) if hx.size else float(bxx.mean())
	# orbe ciano do cajado (maior blob ciano)
	r, g, b = (rgba[..., i].astype(int) for i in range(3))
	cyan = ndimage.binary_closing((b > 150) & (g > 150) & (r < 140) & a, iterations=2)
	lab, n = ndimage.label(cyan)
	tip = None
	if n:
		sizes = ndimage.sum(cyan, lab, range(1, n + 1))
		i = int(np.argmax(sizes))
		if sizes[i] >= 20:
			yy, xx = np.nonzero(lab == i + 1)
			tip = [float(xx.mean()), float(yy.mean())]
	return {
		"foot_y": float(foot_y), "bottom": float(bottom), "top": float(top), "hip_y": float(hip_y),
		"pelvis_x": pelvis_x, "center_x": float(bxx.mean()),
		"front_x": bts[-1]["contact_x"] if bts else pelvis_x,
		"rear_x": bts[0]["contact_x"] if bts else pelvis_x,
		"boots": len(bts), "tip": tip,
		# bota mais baixa = a que está apoiada (corrida: mede a passada)
		"low_x": max(bts, key=lambda q: q["bottom"])["contact_x"] if bts else pelvis_x,
	}


def scale_meas(m: dict, s: float, ox: float = 0.0, oy: float = 0.0) -> dict:
	out = dict(m)
	for key in ["foot_y", "bottom", "top", "hip_y"]:
		out[key] = m[key] * s + oy
	for key in ["pelvis_x", "center_x", "front_x", "rear_x", "low_x"]:
		out[key] = m[key] * s + ox
	if m["tip"] is not None:
		out["tip"] = [m["tip"][0] * s + ox, m["tip"][1] * s + oy]
	return out


# ---------------------------------------------------------------- fatiar
def slice_sheet(path: str, grid, names, raw_alpha_cells=()):
	"""`raw_alpha_cells`: células cujo alfa da folha é mantido como veio
	(translúcido DE PROPÓSITO, ex.: o "fade" do Soter)."""
	img = Image.open(path)
	a_raw = None
	if img.mode == "RGBA" and np.asarray(img)[..., 3].min() < 250:
		arr = np.asarray(img).astype(np.float32)
		F, a = arr[..., :3], arr[..., 3] / 255.0
		a_raw = a.copy()
		# Folhas que JÁ vêm com alfa (Harmas, Soter): o GPT entrega o corpo a
		# 0,94–0,996 de opacidade (nenhum pixel 255) → em jogo o fundo vazava
		# pelo corpo (bug "Harmas fantasma"). Miolo da silhueta = opaco; a borda
		# antisserrilhada e o que for translúcido de verdade (alfa < 0,6) ficam.
		core = ndimage.binary_erosion(a > 0.5, iterations=2)
		a = np.where((core & (a > 0.6)) | (a > 0.94), 1.0, a)
		a[a < 0.05] = 0.0
	else:
		F, a, _ = key_array(np.asarray(img.convert("RGB")).astype(np.float32))
	H, W = a.shape
	cols, rows = grid
	cw, ch = W / cols, H / rows
	lab, n = ndimage.label(a > 0.05, structure=np.ones((3, 3), bool))
	objs = ndimage.find_objects(lab)
	cell_of = {}
	for i in range(n):
		sl = objs[i]
		comp = lab[sl] == i + 1
		area = int(comp.sum())
		if area < 30:
			continue
		yy, xx = np.nonzero(comp)
		cy, cx = yy.mean() + sl[0].start, xx.mean() + sl[1].start
		c = int(min(cols - 1, cx // cw)) + cols * int(min(rows - 1, cy // ch))
		cell_of.setdefault(c, []).append(i + 1)
	frames = {}
	for c, name in enumerate(names):
		if name == "-" or c not in cell_of:
			continue
		# pedaços soltos só entram se forem grandes (cajado caído) ou estiverem
		# perto do corpo principal (faísca de outro quadro fica de fora)
		ids = cell_of[c]
		areas = {i: int((lab[objs[i - 1]] == i).sum()) for i in ids}
		main = max(ids, key=lambda i: areas[i])
		ms = objs[main - 1]
		keep = []
		for i in ids:
			sl = objs[i - 1]
			near = sl[0].start < ms[0].stop + 40 and sl[0].stop > ms[0].start - 40 and sl[1].start < ms[1].stop + 40 and sl[1].stop > ms[1].start - 40
			if i == main or areas[i] > 1500 or near:
				keep.append(i)
		m = np.isin(lab, keep)
		yy, xx = np.nonzero(m)
		y0, y1, x0, x1 = yy.min(), yy.max() + 1, xx.min(), xx.max() + 1
		src_a = a_raw if (a_raw is not None and name in raw_alpha_cells) else a
		alpha = src_a[y0:y1, x0:x1] * m[y0:y1, x0:x1]
		rgba = np.dstack([F[y0:y1, x0:x1], alpha * 255.0])
		frames[name] = (rgba, (int(x0), int(y0)))
	return frames


def resize_rgba(rgba: np.ndarray, s: float) -> np.ndarray:
	"""Redimensiona com alfa PRÉ-MULTIPLICADO (sem halo escuro na borda)."""
	a = rgba[..., 3:4] / 255.0
	pm = np.dstack([rgba[..., :3] * a, a[..., 0] * 255.0])
	h, w = rgba.shape[:2]
	nw, nh = max(1, int(round(w * s))), max(1, int(round(h * s)))
	ch = [np.asarray(Image.fromarray(pm[..., i].astype(np.float32), "F").resize((nw, nh), Image.LANCZOS)) for i in range(4)]
	out = np.dstack(ch)
	out = np.clip(out, 0, 255)
	al = out[..., 3:4] / 255.0
	rgb = np.where(al > 1e-3, out[..., :3] / np.maximum(al, 1e-3), 0.0)
	return np.dstack([np.clip(rgb, 0, 255), out[..., 3]])


def flex_mask(rgba: np.ndarray, m: dict) -> np.ndarray:
	"""R = cabelo (claro/dessaturado, metade de cima, atrás da cabeça),
	G = barras do manto (marfim, terço de baixo). Suavizadas e dilatadas pra
	o deslocamento do shader poder sair um pouco da silhueta."""
	H, W = rgba.shape[:2]
	a = rgba[..., 3] > 100
	r, g, b = (rgba[..., i] for i in range(3))
	mx = np.maximum(np.maximum(r, g), b)
	mn = np.minimum(np.minimum(r, g), b)
	sat = (mx - mn) / np.maximum(mx, 1.0)
	light = mx / 255.0
	yy = np.arange(H)[:, None].repeat(W, 1)
	xx = np.arange(W)[None, :].repeat(H, 0)
	h = max(1.0, m["foot_y"] - m["top"])
	rel = (m["foot_y"] - yy) / h
	k = max(2, int(H / 90))
	head_rows = a & (yy < m["top"] + 0.2 * h)
	head_x = float(xx[head_rows].mean()) if head_rows.any() else m["pelvis_x"]
	hair = a & (sat < 0.20) & (light > 0.55) & (rel > 0.50) & (xx < head_x + k)
	cloth = a & (sat < 0.35) & (light > 0.55) & (rel < 0.52) & (rel > 0.08)
	hm = ndimage.gaussian_filter(ndimage.binary_dilation(hair, iterations=3 * k).astype(np.float32), 2.5 * k)
	cm = ndimage.gaussian_filter(ndimage.binary_dilation(cloth, iterations=2 * k).astype(np.float32), 2 * k)
	hm *= 0.25 + 0.75 * np.clip((head_x - xx) / (0.25 * h), 0.0, 1.0)
	cm *= np.clip((0.52 - rel) / 0.35, 0.0, 1.0)
	return np.dstack([np.clip(hm * 1.4, 0, 1), np.clip(cm * 1.4, 0, 1), np.zeros((H, W))])


# ---------------------------------------------------------------- empacotar
def pack(sizes):
	"""Prateleiras simples (altura decrescente). Devolve posições e altura total."""
	order = sorted(range(len(sizes)), key=lambda i: -sizes[i][1])
	pos = [None] * len(sizes)
	x = y = shelf = 0
	for i in order:
		w, h = sizes[i]
		if x + w > ATLAS_W:
			x, y, shelf = 0, y + shelf, 0
		pos[i] = (x, y)
		x += w
		shelf = max(shelf, h)
	return pos, y + shelf


def main() -> None:
	args = [x for x in sys.argv[1:] if not x.startswith("--")]
	recipe_path = args[0] if args else os.path.join(os.path.dirname(__file__), "sophia_recipe.json")
	R = json.load(open(recipe_path, encoding="utf-8"))
	char = R["character"]
	body_px = float(R["body_px"])
	# 1) fatia todas as folhas e mede em escala de origem
	raw = {}
	fixed_anchor = {}
	for sid, src in R["sources"].items():
		path = os.path.join(ROOT, src["file"])
		if not os.path.exists(path):
			print("  (folha ausente, pulada)", src["file"])
			continue
		side = {}
		side_path = path.replace(".png", ".json")
		if os.path.exists(side_path):
			side = json.load(open(side_path, encoding="utf-8")).get("anchors", {})
		for name, (rgba, origin) in slice_sheet(path, src["grid"], src["cells"]).items():
			raw[sid + "." + name] = [rgba, src.get("scale", 1.0)]
			if name in side:
				# âncora fixa (px da folha) → px locais do recorte
				fixed_anchor[sid + "." + name] = (side[name][0] - origin[0], side[name][1] - origin[1])
	ref = R["ref_frame"]
	ref_m = measure(raw[ref][0])
	ref_body = ref_m["foot_y"] - ref_m["top"]
	# escala por folha: número fixo ou "auto:<célula em pé>" (iguala a altura
	# pé→topo da cabeça dessa célula à do quadro de referência)
	auto_scale = {}
	base_pre = float(R["body_px"]) / max(1.0, ref_body)
	for sid, src in R["sources"].items():
		sc = src.get("scale", 1.0)
		if isinstance(sc, str) and sc.startswith("auto:"):
			cell = sid + "." + sc[5:]
			if cell in raw:
				mm = measure(raw[cell][0])
				auto_scale[sid] = ref_body / max(1.0, mm["foot_y"] - mm["top"])
				print("  escala auto %s = %.3f (por %s)" % (sid, auto_scale[sid], cell))
	for n in raw:
		sid = n.split(".")[0]
		v = raw[n][1]
		if v == "atlas":
			raw[n][1] = 1.0 / base_pre        # folha já na escala do atlas (intercalados do RIFE)
		else:
			raw[n][1] = auto_scale.get(sid, 1.0) if isinstance(v, str) else float(v)
	base = body_px / (ref_m["foot_y"] - ref_m["top"])   # px de origem → px do atlas
	# 2) normaliza e mede
	used = []
	for st in R["states"].values():
		for f in st["frames"]:
			n = f.split("@")[0]
			if n in raw and n not in used:
				used.append(n)
	frames = {}
	for n in used:
		rgba, sheet_s = raw[n]
		fix = R.get("frame_fix", {}).get(n, {}).get("scale", 1.0)
		s = base * sheet_s * fix
		m_src = measure(rgba)
		small = resize_rgba(rgba, s)
		h, w = small.shape[:2]
		canvas = np.zeros((h + 2 * PAD, w + 2 * PAD, 4), np.float32)
		canvas[PAD:PAD + h, PAD:PAD + w] = small
		frames[n] = {"img": canvas, "m": scale_meas(m_src, s, PAD, PAD), "scale": s}
		if n in fixed_anchor:
			frames[n]["fixed"] = [fixed_anchor[n][0] * s + PAD, fixed_anchor[n][1] * s + PAD]
	refm = frames[ref]["m"] if ref in frames else scale_meas(ref_m, base, PAD, PAD)
	d_front = refm["front_x"] - refm["pelvis_x"]
	d_rear = refm["rear_x"] - refm["pelvis_x"]
	hip_h = refm["foot_y"] - refm["hip_y"]
	# 3) empacota
	names = list(frames.keys())
	pos, total_h = pack([(frames[n]["img"].shape[1], frames[n]["img"].shape[0]) for n in names])
	atlas_h = int(2 ** np.ceil(np.log2(max(total_h, 1))))
	atlas = np.zeros((atlas_h, ATLAS_W, 4), np.float32)
	flex = np.zeros((atlas_h, ATLAS_W, 3), np.float32)
	out_frames = {}
	for n, (x, y) in zip(names, pos):
		img = frames[n]["img"]
		h, w = img.shape[:2]
		atlas[y:y + h, x:x + w] = img
		flex[y:y + h, x:x + w] = flex_mask(img, frames[n]["m"])
		m = frames[n]["m"]
		out_frames[n] = {
			"rect": [x, y, w, h],
			"foot_y": round(m["foot_y"], 2), "bottom": round(m["bottom"], 2), "top": round(m["top"], 2),
			"hip_y": round(m["hip_y"], 2), "pelvis_x": round(m["pelvis_x"], 2), "center_x": round(m["center_x"], 2),
			"front_x": round(m["front_x"], 2), "rear_x": round(m["rear_x"], 2), "low_x": round(m["low_x"], 2), "boots": m["boots"],
			"tip": [round(m["tip"][0], 2), round(m["tip"][1], 2)] if m["tip"] else None,
			"scale": round(frames[n]["scale"], 5),
		}
		if "fixed" in frames[n]:
			out_frames[n]["fixed_anchor"] = [round(v, 2) for v in frames[n]["fixed"]]
	# 4) estados → sequências com âncora por quadro
	def anchor(fr: dict, mode: str):
		if "fixed_anchor" in fr:
			return list(fr["fixed_anchor"])
		if mode == "front":
			return [fr["front_x"] - d_front, fr["foot_y"]]
		if mode == "rear":
			return [fr["rear_x"] - d_rear, fr["foot_y"]]
		if mode == "air":
			return [fr["pelvis_x"], fr["hip_y"] + hip_h]
		if mode == "lying":
			return [fr["center_x"], fr["bottom"]]
		return [fr["pelvis_x"], fr["foot_y"]]
	out_states = {}
	for sname, st in R["states"].items():
		seq = []
		for f in st["frames"]:
			n, _, mode = f.partition("@")
			if n not in out_frames:
				continue
			ax, ay = anchor(out_frames[n], mode or st.get("anchor", "pelvis"))
			seq.append({"f": n, "anchor": [round(ax, 2), round(ay, 2)]})
		if not seq:
			continue
		entry = {"frames": seq, "dur": st.get("dur", []), "loop": bool(st.get("loop", False))}
		if "advance_split_of" in st and st["advance_split_of"] in out_states and "advance" in out_states[st["advance_split_of"]]:
			# intercalados: cada quadro original divide o seu avanço com o meio
			base_adv = out_states[st["advance_split_of"]]["advance"]
			adv = []
			for v in base_adv:
				adv += [round(v / 2.0, 2), round(v / 2.0, 2)]
			entry["advance"] = adv
			entry["cycle_bodies"] = round(sum(adv) / body_px, 4)
		elif st.get("cycle_bodies") == "auto":
			# CORRIDA: quanto o corpo avança em cada quadro = quanto o pé
			# apoiado recua em relação à pélvis até o quadro seguinte. Trocando
			# de quadro a cada `advance[i]` de distância, o pé apoiado volta ao
			# MESMO ponto do mundo em toda troca (deriva 0 no apoio).
			# pé de apoio = bota mais baixa; `support` força a bota de trás/da frente
			# num quadro (ex.: pé estendido antes do contato — o apoio ainda é o de trás)
			sup = st.get("support", {})
			low = [out_frames[e["f"]][{"rear": "rear_x", "front": "front_x"}.get(sup.get(e["f"]), "low_x")] - out_frames[e["f"]]["pelvis_x"] for e in seq]
			steps = set(st.get("steps", []))
			n = len(seq)
			adv = [None] * n
			for i in range(n):
				j = (i + 1) % n
				if j not in steps and low[i] - low[j] > 0:
					adv[i] = low[i] - low[j]
			known = [v for v in adv if v is not None]
			mean = sum(known) / max(1, len(known))
			adv = [round(v if v is not None else mean, 2) for v in adv]
			entry["advance"] = adv
			entry["cycle_bodies"] = round(sum(adv) / body_px, 4)
			print("  %s: avanço por quadro %s -> ciclo %.2f alturas" % (sname, adv, sum(adv) / body_px))
		for key in ["cycle_bodies", "steps", "smear_at", "fps", "flash_at", "support_change", "support"]:
			if key in st and key not in entry:
				entry[key] = st[key]
		out_states[sname] = entry
	# 5) grava
	a = atlas[..., 3] / 255.0
	rgb = fill_transparent_rgb(atlas[..., :3], a)
	Image.fromarray(np.dstack([rgb, atlas[..., 3]]).round().clip(0, 255).astype(np.uint8), "RGBA").save(os.path.join(DER, char + "_frames.png"), optimize=True)
	Image.fromarray((flex * 255).round().astype(np.uint8), "RGB").save(os.path.join(DER, char + "_frames_flex.png"), optimize=True)
	meta = {"character": char, "atlas": "res://assets/painted/derived/%s_frames.png" % char,
		"flex": "res://assets/painted/derived/%s_frames_flex.png" % char,
		"body_px": body_px, "atlas_size": [ATLAS_W, atlas_h], "frames": out_frames, "states": out_states}
	with open(os.path.join(DER, char + "_frames.json"), "w", encoding="utf-8") as fp:
		json.dump(meta, fp, indent=1, ensure_ascii=False)
	print("%s: %d quadros, %d estados, atlas %dx%d" % (char, len(out_frames), len(out_states), ATLAS_W, atlas_h))
	if "--no-contact" not in sys.argv:
		contact(meta, atlas)


def contact(meta: dict, atlas: np.ndarray, per_page: int = 9) -> None:
	"""Pranchas: cada estado numa linha, quadros alinhados pela ÂNCORA sobre a
	linha do chão (vermelha) e a altura da cabeça do quadro de referência
	(amarela); círculo ciano = ponta do cajado. Páginas de `per_page` estados."""
	S = 0.42
	cellw, cellh = 150, 150
	at = Image.fromarray(atlas.round().clip(0, 255).astype(np.uint8), "RGBA")
	head = meta["body_px"] * S
	items = list(meta["states"].items())
	maxn = max(len(s["frames"]) for _, s in items)
	W = 80 + cellw * maxn
	os.makedirs(CAPS, exist_ok=True)
	for page in range(0, len(items), per_page):
		chunk = items[page: page + per_page]
		img = Image.new("RGB", (W, cellh * len(chunk)), (34, 42, 50))
		d = ImageDraw.Draw(img)
		for row, (sname, st) in enumerate(chunk):
			gy = row * cellh + cellh - 18
			d.line([(0, gy), (W, gy)], fill=(160, 60, 60))
			d.line([(0, gy - head), (W, gy - head)], fill=(150, 140, 50))
			d.text((4, row * cellh + 4), sname, fill=(230, 230, 230))
			for i, e in enumerate(st["frames"]):
				fr = meta["frames"][e["f"]]
				x, y, w, h = fr["rect"]
				crop = at.crop((x, y, x + w, y + h)).resize((max(1, int(w * S)), max(1, int(h * S))), Image.LANCZOS)
				ox = 80 + i * cellw + cellw // 2
				img.paste(crop, (int(ox - e["anchor"][0] * S), int(gy - e["anchor"][1] * S)), crop)
				d.line([(ox - 4, gy), (ox + 4, gy)], fill=(80, 220, 120))
				d.line([(ox, gy - 4), (ox, gy + 4)], fill=(80, 220, 120))
				if fr["tip"]:
					tx = ox + (fr["tip"][0] - e["anchor"][0]) * S
					ty = gy + (fr["tip"][1] - e["anchor"][1]) * S
					d.ellipse([tx - 3, ty - 3, tx + 3, ty + 3], outline=(0, 255, 255))
				d.text((ox - cellw // 2 + 2, gy + 4), e["f"].split(".")[-1], fill=(170, 170, 170))
		out = os.path.join(CAPS, "frames_contact_%d.png" % (page // per_page + 1))
		img.save(out)
		print("prancha:", out, img.size)


if __name__ == "__main__":
	main()
