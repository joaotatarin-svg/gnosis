"""REI AJOELHADO (Arte, 29/10): as duas poses HD (de pé: rei_pose_kneel / rei_pose_kneel_cracked, 1024x1536 sobre
magenta, a MESMA escala de tela da pintura base HD) viram 12 quadros cada, animados LEVEMENTE em camadas (mesma
técnica da parada HD do Lab3D): respiração (capuz/ombros sobem), capuz que balança, manto que ondula e a barra que
levanta (as pontas no chão ficam PREGADAS), e a brasa da fenda da máscara (a rachada pulsa a luz dourada). O ORBE-OLHO
fica FORA da pintura (é um sprite do jogo, o ponto fraco do Chefes6): a posição dele vem em `orbe_rel_ancora_atlas`.
Reduz com alfa PRÉ-MULTIPLICADO (Lanczos) e nitidez leve para o tamanho de jogo (escala da parada HD: fenda->pé da
pose de pé = 422,06 px do atlas, body_px 450), tira o resto de magenta da borda e escreve:
  artes/gpt/boss_9_rei_kneel_camadas.png      folha 6x4 (alfa real; kneel_a00..11, crack_a00..11), já no tamanho de jogo
  tools/anim_bosses/recipes/rei_kneel_trecho.json  (extra_sheet, anchor_fix, estados kneel / kneel_cracked)
O trecho é aplicado a rei.json por `--aplicar`. Âncora: a ESTOLA (faixa dourada da frente) cai no mesmo x do mundo da
estola da pose de pé, e o pé (barra) no chão; o chão da rachada (~32 px mais alto na pintura) sai pela âncora do pé.
Uso: python tools/anim_bosses/rei_kneel.py [--aplicar]      (depois: boss_frames.py rei --no-rife)
"""
import json
import math
import os
import sys

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "anim"))
from build_frames import measure, slice_sheet  # noqa: E402

POSES = {"kneel": "artes/gpt/rei_pose_kneel.png", "crack": "artes/gpt/rei_pose_kneel_cracked.png"}
SHEET = "artes/gpt/boss_9_rei_kneel_camadas.png"
RECIPE = os.path.join(ROOT, "tools", "anim_bosses", "recipes", "rei.json")
TRECHO = os.path.join(ROOT, "tools", "anim_bosses", "recipes", "rei_kneel_trecho.json")
N = 12                       # quadros por laço (5 qps = 2,4 s)
FPS = 5.0
FENDA_PE_JOGO = 421.125 * 450.0 / 449.0     # fenda->pé da pose de pé HD no atlas (px)
SB = FENDA_PE_JOGO / 1328.0                  # px HD -> px de jogo (0,3178)
S = 1.0 / SB                                 # px HD por px de jogo (3,147)
OFF_JOGO = 77.7 / 2.0                        # estola - pélvis, em px de jogo (a mesma da parada HD)
M = 48                                       # margem em volta do recorte (px HD) p/ a deformação
REF_SCALE = 449.0 / 450.0                    # `scale` da folha no recipe (1:1, o boss_frames não reamostra)
COLS, ROWS = 6, 4


def sstep(a, b, x):
	t = np.clip((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)


def premul(a):
	p = a.copy()
	p[..., :3] *= a[..., 3:4] / 255.0
	return p


def unpremul(p):
	a = p[..., 3:4] / 255.0
	o = p.copy()
	o[..., :3] = np.where(a > 1e-3, p[..., :3] / np.maximum(a, 1e-3), 0)
	return o.clip(0, 255)


def remap(p, mx, my):
	return cv2.remap(p, mx.astype(np.float32), my.astype(np.float32), cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT, borderValue=0).clip(0, 255)


def reduzir(pm, s, nitidez=0.25):
	"""Lanczos com alfa pré-multiplicado + nitidez leve; borda sem magenta."""
	h, w = pm.shape[:2]
	nw, nh = max(1, int(round(w * s))), max(1, int(round(h * s)))
	ch = [np.asarray(Image.fromarray(pm[..., i].astype(np.float32), "F").resize((nw, nh), Image.LANCZOS)) for i in range(4)]
	out = np.dstack(ch).clip(0, 255)
	if nitidez > 0:
		bl = cv2.GaussianBlur(out, (0, 0), 0.8)
		out = (out + nitidez * (out - bl)).clip(0, 255)
		out[..., :3] = np.minimum(out[..., :3], out[..., 3:4])
	out[out[..., 3] < 2.5] = 0
	o = unpremul(out)
	semi = o[..., 3] < 250
	ex = np.clip(np.minimum(o[..., 0], o[..., 2]) - o[..., 1], 0, None) * semi
	o[..., 0] -= ex
	o[..., 2] -= ex
	return o


def estola_x(rgba):
	"""x da faixa dourada central da frente (rubis) na parte de baixo do manto ajoelhado (x > 55 % da largura)."""
	r, g, b, al = (rgba[..., i] for i in range(4))
	mx = np.maximum(np.maximum(r, g), b)
	mn = np.minimum(np.minimum(r, g), b)
	ouro = (al > 128) & ((mx - mn) / np.maximum(mx, 1) > 0.45) & (r > 90) & (b < 0.65 * r)
	H, W = al.shape
	y0, y1 = int(H * 0.55), int(H * 0.93)
	prof = np.zeros(W)
	x0 = int(W * 0.55)
	prof[x0:] = ouro[y0:y1, x0:].mean(0)
	return float(np.argmax(ndimage.uniform_filter1d(prof, 40, mode="constant")))


def tira_orbe(rgba):
	"""O ORBE-OLHO do jogo é um sprite à parte (é o ponto fraco, a caixa dele é do Chefes6): a pintura sai SEM o orbe
	(esfera, espetos e a hastezinha que a mão segura), senão ele apareceria em dobro. Devolve (rgba limpo, centro do
	íris em px do recorte). A mão fica; o pano sob a esfera é completado por inpaint."""
	r, g, b, al = (rgba[..., i] for i in range(4))
	mx = np.maximum(np.maximum(r, g), b)
	mn = np.minimum(np.minimum(r, g), b)
	sat = (mx - mn) / np.maximum(mx, 1)
	H, W = al.shape
	am = (al > 200) & (r > 215) & (g > 140) & (g < 225) & (b < 110) & (sat > 0.6)
	am[:, :int(W * 0.78)] = False
	am[:int(H * 0.53)] = False
	lab, n = ndimage.label(ndimage.binary_closing(am, iterations=3))
	sz = ndimage.sum(am, lab, range(1, n + 1))
	iris = lab == (1 + int(np.argmax(sz)))
	ys, xs = np.nonzero(iris)
	cx, cy = float(xs.mean()), float(ys.mean())
	R = float(np.sqrt(sz.max() / np.pi))
	yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
	d = np.hypot(xx - cx, yy - cy)
	m = d <= 3.9 * R                                              # a esfera
	m |= (np.abs(xx - cx) <= 0.9 * R) & (yy >= cy - 6.5 * R) & (yy <= cy - 2.0 * R)   # a hastezinha até a mão
	m |= (xx >= cx + 3.0 * R) & (d <= 7.6 * R)                    # espetos da direita (só há fundo ali)
	m |= (np.abs(xx - cx) <= 0.7 * R) & (yy >= cy + 3.0 * R) & (yy <= cy + 6.6 * R)   # espeto de baixo
	m |= (np.abs(yy - cy) <= 0.5 * R) & (xx <= cx - 3.0 * R) & (xx >= cx - 6.8 * R)     # espeto da esquerda (sobre o pano)
	m &= al > 0
	m = ndimage.binary_dilation(m, iterations=2)
	out = rgba.copy()
	fora = m & (xx >= cx - 3.7 * R)                               # sem pano atrás: some
	dentro = m & ~fora                                            # pano atrás (esquerda): inpaint
	out[fora, 3] = 0
	if dentro.any():
		rgb8 = rgba[..., :3].clip(0, 255).astype(np.uint8)
		fill = cv2.inpaint(rgb8, (dentro).astype(np.uint8) * 255, 7, cv2.INPAINT_TELEA)
		out[dentro, :3] = fill[dentro]
	return out, (cx, cy)


def animar(rgba, nome):
	"""Devolve (lista de quadros HD RGBA com margem M, âncora (x, y) em px HD do quadro com margem)."""
	rgba, orbe = tira_orbe(rgba)
	h0, w0 = rgba.shape[:2]
	H, W = h0 + 2 * M, w0 + 2 * M
	src = np.zeros((H, W, 4), np.float32)
	src[M:M + h0, M:M + w0] = rgba
	al = src[..., 3] > 8
	yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
	xx -= M
	yy -= M
	mxc = np.maximum(np.maximum(src[..., 0], src[..., 1]), src[..., 2])
	mnc = np.minimum(np.minimum(src[..., 0], src[..., 1]), src[..., 2])
	sat = (mxc - mnc) / np.maximum(mxc, 1)
	m_ = measure(rgba)
	foot = m_["foot_y"]
	top = m_["top"]
	# pesos (coordenadas do recorte: a pose ocupa ~990 x 790 px HD)
	hh = foot - top
	w_resp = sstep(top + 0.60 * hh, top + 0.12 * hh, yy)                      # capuz e ombros sobem, o colo fica
	w_cap = sstep(top + 0.34 * hh, top + 0.08 * hh, yy) * sstep(w0 * 0.56, w0 * 0.70, xx)
	saia = sstep(top + 0.38 * hh, top + 0.60 * hh, yy)
	w_chao = 1 - sstep(foot - 0.17 * hh, foot - 0.02 * hh, yy)                # perto do chão: as pontas pregadas
	w_manto = saia * w_chao
	w_barra = sstep(top + 0.66 * hh, top + 0.80 * hh, yy) * (1 - sstep(foot - 0.06 * hh, foot, yy))
	# mão + orbe: pregados ao corpo (é onde o jogo põe a caixa do ponto fraco)
	pin = ((xx > w0 * 0.80) & (yy > top + 0.42 * hh) & (yy < top + 0.90 * hh)).astype(np.float32)
	w_pin = 1 - np.clip(ndimage.gaussian_filter(pin, 14.0) * 3.0, 0, 1)
	# brasa da fenda (caixa conferida nas duas poses): escuros (inteira) / dourados (rachada)
	box = np.zeros((H, W), bool)
	box[M + 52:M + 160, M + 712:M + 800] = True
	escuro = box & al & (mxc < 75)
	ambar = box & al & (sat > 0.55) & (mxc > 170)
	ouro = ndimage.gaussian_filter(ambar.astype(np.float32), 2.0)
	fenda = ndimage.gaussian_filter(escuro.astype(np.float32), 1.5)
	quadros = []
	L = premul(src)
	for i in range(N):
		ph = 2 * math.pi * i / N
		resp = 0.5 - 0.5 * math.cos(ph)
		dyr = -S * 1.5 * resp * w_resp * w_pin
		dxr = S * (0.25 * resp * w_resp + 0.7 * w_cap * math.sin(ph - 0.9)) * w_pin
		fase = ph - 2.2 * (yy - top) / hh + (xx - w0 * 0.5) / (0.7 * w0)
		dx = dxr + S * 1.1 * w_manto * np.sin(fase) * w_pin
		dx = dx + S * 0.9 * w_manto * (xx - w0 * 0.45) / (0.5 * w0) * (0.5 - 0.5 * math.cos(ph - 1.2)) * w_pin
		dy = dyr - S * 0.9 * w_barra * (0.5 + 0.5 * np.sin(ph - 2.6 * np.abs(xx - w0 * 0.45) / (0.5 * w0)))
		q = remap(L, xx + M - dx, yy + M - dy)
		out = unpremul(q)
		# brasa: pulsa com a respiração
		fq = cv2.remap(fenda, (xx + M - dxr).astype(np.float32), (yy + M - dyr).astype(np.float32), cv2.INTER_LINEAR)
		oq = cv2.remap(ouro, (xx + M - dxr).astype(np.float32), (yy + M - dyr).astype(np.float32), cv2.INTER_LINEAR)
		if nome == "kneel":
			k = (0.50 * resp * fq)[..., None]
			out[..., :3] = out[..., :3] * (1 - k) + np.array([255, 196, 90], np.float32) * k
		else:
			out[..., :3] = (out[..., :3] * (1 + (0.20 + 0.40 * resp) * oq)[..., None]).clip(0, 255)
		quadros.append(out)
	sx = estola_x(rgba)
	ancora = ((sx - OFF_JOGO * S) + M, foot + M)
	return quadros, ancora, dict(estola=sx, foot=foot, top=top, orbe_crop=[round(orbe[0], 1), round(orbe[1], 1)],
		orbe_rel_ancora_atlas=[round((orbe[0] + M - ancora[0]) * SB, 1), round((orbe[1] + M - ancora[1]) * SB, 1)])


def principal(aplicar):
	frames_all = []        # (nome, imagem de jogo RGBA float, âncora (x, y) em px de jogo do quadro)
	info = {}
	for nome, rel in POSES.items():
		fr = slice_sheet(os.path.join(ROOT, rel), [1, 1], [nome])
		rgba, org = fr[nome]
		qs, anc, inf = animar(rgba, nome)
		inf["org"] = list(org)
		info[nome] = inf
		pref = "kneel" if nome == "kneel" else "crack"
		for i, q in enumerate(qs):
			red = reduzir(premul(q), SB)
			frames_all.append(("%s_a%02d" % (pref, i), red, (anc[0] * SB, anc[1] * SB)))
	cw = max(f[1].shape[1] for f in frames_all) + 40
	ch = max(f[1].shape[0] for f in frames_all) + 40
	rows = (len(frames_all) + COLS - 1) // COLS
	assert rows == ROWS, rows
	sheet = Image.new("RGBA", (cw * COLS, ch * ROWS), (0, 0, 0, 0))
	pos = []
	for k, (n, im, _) in enumerate(frames_all):
		img = Image.fromarray(im.round().clip(0, 255).astype(np.uint8), "RGBA")
		x0, y0 = (k % COLS) * cw + 20, (k // COLS) * ch + 20 + (ch - 40 - img.height)     # pés na mesma linha
		sheet.alpha_composite(img, (x0, y0))
		pos.append((x0, y0))
	out_png = os.path.join(ROOT, SHEET)
	sheet.save(out_png, optimize=True)
	nomes = [f[0] for f in frames_all]
	cells = nomes
	check = slice_sheet(out_png, [COLS, ROWS], cells)
	fix = {}
	for k, n in enumerate(nomes):
		rgba, org = check[n]
		m = measure(rgba)
		ax, ay = frames_all[k][2]
		d = np.array([pos[k][0] + ax - org[0], pos[k][1] + ay - org[1]]) - np.array([m["pelvis_x"], m["foot_y"]])
		if abs(d[0]) > 0.01 or abs(d[1]) > 0.01:
			fix[n] = [round(float(d[0]), 2), round(float(d[1]), 2)]
	est = {
		"kneel": {"frames": [n for n in nomes if n.startswith("kneel_a")], "loop": True, "fps": FPS},
		"kneel_cracked": {"frames": [n for n in nomes if n.startswith("crack_a")], "loop": True, "fps": FPS},
	}
	T = {"extra_sheet": {"sheet": SHEET, "grid": [COLS, ROWS], "cells": cells, "scale": REF_SCALE},
		"anchor_fix": fix, "states": est, "medidas": info,
		"_doc": "Rei ajoelhado (Arte 29/10): poses HD kneel / kneel_cracked animadas em camadas (tools/anim_bosses/rei_kneel.py), já no tamanho de jogo (body_px 450, escala da parada HD). Âncora pela estola; o chão da rachada sai pelo pé."}
	json.dump(T, open(TRECHO, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
	print(out_png, sheet.size, len(nomes), "quadros; estola", {k: v["estola"] for k, v in info.items()}, "foot", {k: v["foot"] for k, v in info.items()})
	if aplicar:
		R = json.load(open(RECIPE, encoding="utf-8-sig"))
		R["extra_sheets"] = [e for e in R["extra_sheets"] if e["sheet"] != SHEET] + [T["extra_sheet"]]
		R.setdefault("anchor_fix", {}).update(fix)
		R["states"]["kneel"] = est["kneel"]
		R["states"]["kneel_cracked"] = est["kneel_cracked"]
		R["flex_off_states"] = sorted(set(R.get("flex_off_states", [])) | {"kneel", "kneel_cracked"})
		R["_doc_kneel"] = T["_doc"]
		json.dump(R, open(RECIPE, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
		print("receita do Rei atualizada")


if __name__ == "__main__":
	principal("--aplicar" in sys.argv)
