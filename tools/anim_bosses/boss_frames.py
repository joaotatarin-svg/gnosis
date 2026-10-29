"""QUADROS DESENHADOS DOS CHEFES (GNOSIS) — folha do GPT → atlas + JSON.

Generaliza o pipeline da Sophia (tools/anim/build_frames.py) para os chefes.
Cada chefe tem uma RECEITA em tools/anim_bosses/recipes/<nome>.json:

  sheet        folha 1536x1024, fundo magenta, grade 4x2 (idle_0, idle_1,
               walk_0, walk_1, windup, strike, hurt, death), chefe olhando p/ DIREITA
  old_body     camada corpo do boneco antigo (assets/painted/derived/puppets/<nome>_body.png):
               mede a ALTURA DO CORPO, a folga do pé e o centro do corpo na pintura
               antiga → o chefe novo ocupa o MESMO tamanho/lugar em tela
               (colisões e _fit_body continuam coerentes)
  old_flip     a pintura antiga era espelhada no jogo (archons: true)
  body_px      altura do corpo do quadro de referência (idle_0) no atlas
  grid_only    recorta cada célula só dentro da grade (quadros que se tocam)
  erase        [[x0,y0,x1,y1], ...] px da folha apagados antes (efeito pintado → FX)
  anchors      modo de âncora por célula: pelvis (padrão) | top | lying
               top   = cabeça estável (espectros: a barra dos trapos varia)
               lying = corpo caído: centro do corpo, ponto mais baixo no chão
  anchor_fix   correção manual da âncora (px da FOLHA) por célula
  inbetween    pares para o RIFE (GPU): {"idle": ["idle_0","idle_1",2]} gera
               os meios idle_0-idle_1_25/_50/_75 (profundidade 2) ou _50 (1),
               montados com as âncoras alinhadas (o corpo não pula)
  flex         máscara do movimento secundário (G = trapos/pano na parte de baixo)
  states       estado do CharacterArt → sequência:
               frames | pingpong [a, b] (usa os meios), loop+fps, dur (s por
               quadro), at (limiares do PROGRESSO real do inimigo 0..1),
               cycle_bodies (andar pela DISTÂNCIA), impact_at (estalo na troca)

Saída: assets/painted/derived/bosses/<nome>_frames.png (+ _flex.png, .json) e a
prancha C:/gnosis-wt/_caps/arte-gpt/<nome>_contact.png (estados alinhados pela âncora).

Uso: python tools/anim_bosses/boss_frames.py athoth [--no-rife]
     (--no-rife reaproveita os meios já gerados em assets/painted/src/bosses/)
"""
import json
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "anim"))
from clean_sheets import fill_transparent_rgb, key_array  # noqa: E402
from build_frames import PAD, measure, pack, resize_rgba, scale_meas, slice_sheet  # noqa: E402
from geometry import measure_geometry  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "painted", "derived", "bosses")
SRC_MIDS = os.path.join(ROOT, "assets", "painted", "src", "bosses")
CAPS = "C:/gnosis-wt/_caps/arte-gpt"
RIFE = r"C:\Users\jmtat\gnosis-tools\rife\rife-ncnn-vulkan.exe"
MAGENTA = np.array([255.0, 0.0, 255.0])


# ---------------------------------------------------------------- medidas
def old_fit(path: str, flip: bool) -> dict:
	"""Medidas da pintura antiga (recorte = Rect2 do PaintedLibrary)."""
	arr = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32)
	m = measure(arr)
	H, W = arr.shape[:2]
	dx = (m["pelvis_x"] - W / 2.0) / H
	return {
		"body_frac": round((m["foot_y"] - m["top"]) / H, 5),        # altura do corpo / altura do recorte
		"foot_gap": round((H - 1 - m["foot_y"]) / H, 5),            # pé acima da base do recorte
		"dx": round(-dx if flip else dx, 5),                        # centro do corpo (olhando p/ direita)
		"rect_px": [W, H],
	}


def anchor_of(m: dict, mode: str, ref_h: float) -> list:
	if mode == "lying":
		return [m["center_x"], m["bottom"]]
	if mode == "top":
		return [m["pelvis_x"], m["top"] + ref_h]
	return [m["pelvis_x"], m["foot_y"]]


# ---------------------------------------------------------------- máscara
def flex_mask(rgba: np.ndarray, m: dict, cfg: dict) -> np.ndarray:
	"""G = pano/trapos (parte de baixo do corpo, mais forte na barra);
	R = mechas/véu de cima (opcional, `veil_top`). Suavizada e dilatada."""
	H, W = rgba.shape[:2]
	out = np.zeros((H, W, 3), np.float32)
	a = rgba[..., 3] > 60
	if not a.any():
		return out
	h = max(1.0, m["foot_y"] - m["top"])
	yy = np.arange(H, dtype=np.float32)[:, None].repeat(W, 1)
	rel = (m["foot_y"] - yy) / h                     # 0 no pé, 1 no topo
	k = max(2, int(H / 90))
	top = float(cfg.get("cloth_top", 0.0))
	if top > 0.0:
		cloth = a & (rel < top)
		cm = ndimage.gaussian_filter(ndimage.binary_dilation(cloth, iterations=2 * k).astype(np.float32), 2 * k)
		cm *= np.clip((top - rel) / max(0.05, top * 0.8), 0.0, 1.0)
		out[..., 1] = np.clip(cm * 1.3, 0, 1)
	return out


# ---------------------------------------------------------------- RIFE
def compose(rgba: np.ndarray, anchor, W: int, H: int, X0: float, GY: float) -> np.ndarray:
	out = np.zeros((H, W, 3), np.float32) + MAGENTA
	h, w = rgba.shape[:2]
	x0, y0 = int(round(X0 - anchor[0])), int(round(GY - anchor[1]))
	al = rgba[..., 3:4] / 255.0
	reg = out[y0:y0 + h, x0:x0 + w]
	reg[:] = rgba[..., :3] * al + reg * (1.0 - al)
	return out


def rife_mid(fa: dict, fb: dict, tmp: str, tag: str) -> dict:
	"""Quadro do meio entre fa e fb (já na escala do atlas), âncoras alinhadas."""
	ia, ib = fa["img"], fb["img"]
	aa, ab = fa["anchor"], fb["anchor"]
	left = max(aa[0], ab[0])
	right = max(ia.shape[1] - aa[0], ib.shape[1] - ab[0])
	top = max(aa[1], ab[1])
	bot = max(ia.shape[0] - aa[1], ib.shape[0] - ab[1])
	M = 24
	W = int(np.ceil(left + right)) + 2 * M
	H = int(np.ceil(top + bot)) + 2 * M
	X0, GY = left + M, top + M
	ca = compose(ia, aa, W, H, X0, GY)
	cb = compose(ib, ab, W, H, X0, GY)
	p0, p1, pm = (os.path.join(tmp, "%s_%s.png" % (tag, t)) for t in "abm")
	Image.fromarray(ca.round().astype(np.uint8)).resize((W * 2, H * 2), Image.LANCZOS).save(p0)
	Image.fromarray(cb.round().astype(np.uint8)).resize((W * 2, H * 2), Image.LANCZOS).save(p1)
	subprocess.run([RIFE, "-0", p0, "-1", p1, "-o", pm, "-m", os.path.join(os.path.dirname(RIFE), "rife-v4.6")], check=True, capture_output=True)
	mid = np.asarray(Image.open(pm).convert("RGB").resize((W, H), Image.LANCZOS)).astype(np.float32)
	F, al, _ = key_array(mid)
	# só o corpo principal e o que estiver colado nele (sem respingos do fluxo)
	lab, n = ndimage.label(al > 0.05, structure=np.ones((3, 3), bool))
	if n > 1:
		sizes = ndimage.sum(np.ones_like(al), lab, range(1, n + 1))
		keep = [i + 1 for i in range(n) if sizes[i] >= 40]
		al = al * np.isin(lab, keep)
	ys, xs = np.nonzero(al > 0.02)
	y0, y1, x0, x1 = max(0, ys.min() - PAD), min(H, ys.max() + 1 + PAD), max(0, xs.min() - PAD), min(W, xs.max() + 1 + PAD)
	rgba = np.dstack([F[y0:y1, x0:x1], al[y0:y1, x0:x1] * 255.0])
	return {"img": rgba, "anchor": [X0 - x0, GY - y0], "m": measure(rgba), "mid": True}


# ---------------------------------------------------------------- principal
def build(name: str, use_rife: bool = True) -> None:
	R = json.load(open(os.path.join(HERE, "recipes", name + ".json"), encoding="utf-8-sig"))
	sheet = os.path.join(ROOT, R["sheet"])
	cells = R.get("cells", ["idle_0", "idle_1", "walk_0", "walk_1", "windup", "strike", "hurt", "death"])
	raw = slice_sheet(sheet, R.get("grid", [4, 2]), cells, R.get("raw_alpha_cells", []), R.get("grid_only", False), R.get("erase", []), R.get("strip_glow", False), R.get("min_part", 0), R.get("despill_full", False))
	# recolorir células (ex.: o "fade" do Soter veio rosado: o GPT pintou o
	# fantasma já misturado ao magenta) — mantém a luminância, troca a cor
	for cn, col in R.get("recolor", {}).items():
		if cn in raw:
			rgba, origin = raw[cn]
			rgb = rgba[..., :3]
			lum = (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2])[..., None]
			tgt = np.array(col, np.float32)
			tl = 0.299 * tgt[0] + 0.587 * tgt[1] + 0.114 * tgt[2]
			raw[cn] = (np.dstack([np.clip(lum * tgt / tl, 0, 255), rgba[..., 3]]), origin)
	# grupo de saída: derived/<grupo>/ (bosses | creatures) e src/<grupo>/ (meios)
	group = R.get("group", "bosses")
	OUT = os.path.join(ROOT, "assets", "painted", "derived", group)
	SRC_MIDS = os.path.join(ROOT, "assets", "painted", "src", group)
	if "old_rect" in R:
		# criaturas: a pintura antiga é um Rect2 da folha derivada (inhabitants)
		x, y, w, h = R["old_rect"]
		img = Image.open(os.path.join(ROOT, R["old_sheet"])).convert("RGBA").crop((x, y, x + w, y + h))
		tmp_old = os.path.join(tempfile.mkdtemp(prefix="oldfit_"), "old.png")
		img.save(tmp_old)
		fit = old_fit(tmp_old, bool(R.get("old_flip", False)))
	elif "old_body" in R:
		fit = old_fit(os.path.join(ROOT, R["old_body"]), bool(R.get("old_flip", True)))
	else:
		# personagem novo, sem pintura antiga: o tamanho em tela vem do código
		fit = {"body_frac": 1.0, "foot_gap": 0.0, "dx": 0.0, "rect_px": [0, 0]}
	# correção de tamanho (silhueta nova com asas/coroa mais altas que a antiga)
	fit["body_frac"] = round(fit["body_frac"] * float(R.get("size_fix", 1.0)), 5)
	fit.update(R.get("fit_override", {}))      # ex.: {"foot_gap": 0} quando a silhueta nova pisa no chão
	ref = R.get("ref", "idle_0")
	ref_m = measure(raw[ref][0])
	ref_body_src = ref_m["foot_y"] - ref_m["top"]
	body_px = float(R.get("body_px", 300))
	base = body_px / ref_body_src
	ref_h = body_px                                  # altura de referência no atlas
	# FOLHAS EXTRAS (intermediários desenhados, FILA 7: <id>_motion_a): mesma
	# pipeline; escala normalizada pela altura do corpo EM PÉ (célula `ref` da
	# extra × `ref` da folha principal) → mesma escala e mesma linha de pés.
	sheet_scale = {}
	for ex in R.get("extra_sheets", []):
		exr = slice_sheet(os.path.join(ROOT, ex["sheet"]), ex.get("grid", [4, 2]), ex["cells"], ex.get("raw_alpha_cells", []), ex.get("grid_only", False), ex.get("erase", []), ex.get("strip_glow", False))
		sc = ex.get("scale", "auto")
		if sc == "auto":
			# compara POSES EQUIVALENTES: `ref` da extra × `main_ref` da principal
			em = measure(exr[ex["ref"]][0])
			mm = measure(raw[ex.get("main_ref", ref)][0])
			sc = (mm["foot_y"] - mm["top"]) / max(1.0, em["foot_y"] - em["top"]) * float(ex.get("ref_ratio", 1.0))
		for n, v in exr.items():
			raw[n] = v
			sheet_scale[n] = float(sc)
		print("  folha extra %s: %d quadros, escala %.3f" % (os.path.basename(ex["sheet"]), len(exr), float(sc)))
	frames = {}
	for n, (rgba, origin) in raw.items():
		s = base * sheet_scale.get(n, 1.0) * float(R.get("scale_fix", {}).get(n, 1.0))
		small = resize_rgba(rgba, s)
		h, w = small.shape[:2]
		canvas = np.zeros((h + 2 * PAD, w + 2 * PAD, 4), np.float32)
		canvas[PAD:PAD + h, PAD:PAD + w] = small
		m = scale_meas(measure(rgba), s, PAD, PAD)
		an = anchor_of(m, R.get("anchors", {}).get(n, "pelvis"), ref_h)
		fx = R.get("anchor_fix", {}).get(n)
		if fx:
			an = [an[0] + fx[0] * s, an[1] + fx[1] * s]
		frames[n] = {"img": canvas, "m": m, "anchor": an}
	# meios do RIFE (gravados em src/bosses p/ reaproveitar sem GPU)
	os.makedirs(SRC_MIDS, exist_ok=True)
	tmp = tempfile.mkdtemp(prefix="bossrife_")
	for key, (a, b, depth) in R.get("inbetween", {}).items():
		names = {1: ["50"], 2: ["25", "50", "75"]}[int(depth)]
		pairs = [(a, b, "50")]
		if int(depth) == 2:
			pairs += [(a, "%s-%s_50" % (a, b), "25"), ("%s-%s_50" % (a, b), b, "75")]
		for (pa, pb, tag) in pairs:
			mid_name = "%s-%s_%s" % (a, b, tag)
			cache_png = os.path.join(SRC_MIDS, "%s_%s.png" % (name, mid_name))
			cache_js = cache_png.replace(".png", ".json")
			if use_rife or not os.path.exists(cache_png):
				f = rife_mid(frames[pa], frames[pb], tmp, mid_name)
				Image.fromarray(f["img"].round().clip(0, 255).astype(np.uint8), "RGBA").save(cache_png)
				json.dump({"anchor": f["anchor"]}, open(cache_js, "w"))
			img = np.asarray(Image.open(cache_png).convert("RGBA")).astype(np.float32)
			an = json.load(open(cache_js))["anchor"]
			frames[mid_name] = {"img": img, "anchor": an, "m": measure(img), "mid": True}
		print("  meios %s: %s" % (key, ", ".join("%s-%s_%s" % (a, b, t) for t in names)))
	# estados → listas de quadros
	states = {}
	for sname, st in R["states"].items():
		if "pingpong" in st:
			a, b = st["pingpong"]
			mids = [k for k in ["%s-%s_25" % (a, b), "%s-%s_50" % (a, b), "%s-%s_75" % (a, b)] if k in frames]
			seq = [a] + mids + [b] + mids[::-1]
		else:
			seq = list(st["frames"])
		seq = [f for f in seq if f in frames]
		if not seq:
			continue
		entry = {"frames": [{"f": f, "anchor": [round(v, 2) for v in frames[f]["anchor"]]} for f in seq]}
		for k in ["loop", "fps", "dur", "at", "cycle_bodies", "impact_at", "hold", "puff"]:
			if k in st:
				entry[k] = st[k]
		states[sname] = entry
	# empacota só o que é usado
	used = []
	for st in states.values():
		for e in st["frames"]:
			if e["f"] not in used:
				used.append(e["f"])
	pos, total_h = pack([(frames[n]["img"].shape[1], frames[n]["img"].shape[0]) for n in used])
	atlas_h = int(2 ** np.ceil(np.log2(max(total_h, 1))))
	atlas = np.zeros((atlas_h, 2048, 4), np.float32)
	flex = np.zeros((atlas_h, 2048, 3), np.float32)
	out_frames = {}
	for n, (x, y) in zip(used, pos):
		img = frames[n]["img"]
		h, w = img.shape[:2]
		atlas[y:y + h, x:x + w] = img
		m = frames[n]["m"]
		flex[y:y + h, x:x + w] = flex_mask(img, m, R.get("flex", {}))
		out_frames[n] = {"rect": [x, y, w, h], "top": round(m["top"], 2), "foot_y": round(m["foot_y"], 2),
			"bottom": round(m["bottom"], 2), "pelvis_x": round(m["pelvis_x"], 2), "mid": bool(frames[n].get("mid", False)),
			"translucent": n in R.get("raw_alpha_cells", [])}
		# CABEÇA (px locais do quadro): centro da faixa de cima do corpo — para
		# o jogo prender máscara/rachadura/olho ao quadro (CharacterArt.head_point)
		al = img[..., 3] > 128
		hh = max(1.0, m["foot_y"] - m["top"])
		y0h, y1h = int(m["top"]), int(m["top"] + 0.14 * hh)
		cols_h = np.nonzero(al[y0h:y1h].any(0))[0]
		if cols_h.size:
			band = al[y0h:y1h]
			xs_h = np.nonzero(band)[1]
			out_frames[n]["head"] = [round(float(xs_h.mean()), 2), round(m["top"] + 0.07 * hh, 2)]
		# geometria por quadro (caixa/contorno do corpo) — hurtbox no jogo
		out_frames[n].update(measure_geometry(img))
	os.makedirs(OUT, exist_ok=True)
	a = atlas[..., 3] / 255.0
	rgb = fill_transparent_rgb(atlas[..., :3], a)
	Image.fromarray(np.dstack([rgb, atlas[..., 3]]).round().clip(0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + "_frames.png"), optimize=True)
	# silhueta branca (mesmo alfa): contorno do telegrafo no jogo
	sil = np.dstack([np.full(atlas.shape[:2] + (3,), 255.0), atlas[..., 3]])
	Image.fromarray(sil.round().clip(0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + "_frames_sil.png"), optimize=True)
	has_flex = bool(flex.any())
	if has_flex:
		Image.fromarray((flex * 255).round().astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_frames_flex.png"), optimize=True)
	rp = "res://assets/painted/derived/%s/%s" % (group, name)
	meta = {"character": group + "/" + name, "atlas": rp + "_frames.png",
		"flex": (rp + "_frames_flex.png") if has_flex else "",
		"sil": rp + "_frames_sil.png",
		"body_px": body_px, "kind": R.get("kind", "biped"), "fit": fit,
		"cloth_amp": R.get("flex", {}).get("cloth_amp", 0.0), "hem_wave": R.get("hem_wave", 0.0),
		"spring_mul": R.get("spring_mul", 1.0), "flex_off_states": R.get("flex_off_states", []),
		"atlas_size": [2048, atlas_h], "frames": out_frames, "states": states}
	with open(os.path.join(OUT, name + "_frames.json"), "w", encoding="utf-8") as fp:
		json.dump(meta, fp, indent=1, ensure_ascii=False)
	print("%s: %d quadros (%d meios), %d estados, atlas 2048x%d, ajuste %s" % (
		name, len(out_frames), sum(1 for f in out_frames.values() if f["mid"]), len(states), atlas_h, fit))
	contact(name, meta, atlas)


def contact(name: str, meta: dict, atlas: np.ndarray) -> None:
	"""Prancha: um estado por linha, quadros alinhados pela âncora (chão vermelho,
	altura do corpo de referência em amarelo)."""
	S = 0.38
	cw, ch = 140, 150
	at = Image.fromarray(atlas.round().clip(0, 255).astype(np.uint8), "RGBA")
	items = list(meta["states"].items())
	maxn = max(len(s["frames"]) for _, s in items)
	img = Image.new("RGB", (90 + cw * maxn, ch * len(items)), (34, 42, 50))
	d = ImageDraw.Draw(img)
	head = meta["body_px"] * S
	for row, (sname, st) in enumerate(items):
		gy = row * ch + ch - 14
		d.line([(0, gy), (img.width, gy)], fill=(160, 60, 60))
		d.line([(0, gy - head), (img.width, gy - head)], fill=(150, 140, 50))
		d.text((4, row * ch + 4), sname, fill=(230, 230, 230))
		for i, e in enumerate(st["frames"]):
			fr = meta["frames"][e["f"]]
			x, y, w, h = fr["rect"]
			crop = at.crop((x, y, x + w, y + h)).resize((max(1, int(w * S)), max(1, int(h * S))), Image.LANCZOS)
			ox = 90 + i * cw + cw // 2
			img.paste(crop, (int(ox - e["anchor"][0] * S), int(gy - e["anchor"][1] * S)), crop)
			d.line([(ox, gy - 4), (ox, gy + 4)], fill=(80, 220, 120))
			d.text((ox - cw // 2 + 2, gy + 2), e["f"][-10:], fill=(170, 170, 170))
	os.makedirs(CAPS, exist_ok=True)
	out = os.path.join(CAPS, "%s_contact.png" % name)
	img.save(out)
	print("prancha:", out, img.size)


if __name__ == "__main__":
	args = [a for a in sys.argv[1:] if not a.startswith("--")]
	for nm in args or ["athoth"]:
		build(nm, use_rife="--no-rife" not in sys.argv)
