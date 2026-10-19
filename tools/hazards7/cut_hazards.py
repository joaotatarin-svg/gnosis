"""Perigos pintados (Onda 7): recorta as folhas hz_1..hz_7 em peças com alfa
real, escala de MUNDO e âncora, e escreve o catálogo lido por
scripts/fx/hazard_art.gd.

Uso: python tools/hazards7/cut_hazards.py
Saída: assets/painted/hazards/<peça>[_<quadro>].png (+ _sil.png = silhueta
branca para o contorno de AVISO) e assets/painted/hazards/hazards_data.gd
(const DATA, mesmo formato):
  {"<peça>": {"frames": [arquivos], "sil": [arquivos], "size": [w, h],
              "anchor": [ax, ay]}}
`size` e `anchor` em pixels de MUNDO (viewport 640x360): o jogo desenha o
quadro no retângulo (pos - anchor, size). A textura é guardada com ~2,5
texels por pixel de mundo (nítida na janela 1280x720, mipmaps no .import).

Coordenadas abaixo: pixels da FOLHA original (1536x1024), medidas em
_caps/perigos7/keyed/ (grade de 25 px). Todos os quadros de um mesmo perigo
dividem a MESMA tela (união das caixas, em coordenadas da célula): a âncora
vale para todos os estados.
"""
import json
import os

import numpy as np
from scipy import ndimage

import hz_common as H

SHEETS = {
	"hz_1": "hz_1_pendulo_guilhotina_a.png",
	"hz_2": "hz_2_lancas_boca_a.png",
	"hz_3": "hz_3_sino_casulo_a.png",
	"hz_4": "hz_4_totem_pedra_a.png",
	"hz_5": "hz_5_selo_altar_luz_a.png",
	"hz_6": "hz_6_luz_reflexo_cacos_a.png",
	"hz_7": "hz_7_mare_correntes_a.png",
}
TEXELS_PER_WORLD = 2.5
_cache = {}
CATALOG = {}


def sheet(key: str) -> np.ndarray:
	if key not in _cache:
		img = H.load_keyed(SHEETS[key])
		img[..., 3] = H.clean_specks(img[..., 3], 40, 6)
		_cache[key] = img
	return _cache[key]


def cell_piece(key: str, r: int, c: int):
	"""(rgba, origem na FOLHA) da peça da célula (componentes pelo centro)."""
	cs = H.cells(SHEETS[key], sheet(key))
	return cs[(r, c)]


def warm_pink(rgba: np.ndarray, strength: float = 1.0) -> np.ndarray:
	"""Tons ROSA/magenta (vazamento do fundo em brilho translúcido) → dourado
	quente, mantendo a luminância. Violeta de verdade (b >> r) fica intacto."""
	out = rgba.copy()
	r, g, b = out[..., 0], out[..., 1], out[..., 2]
	pink = (b > g + 25.0) & (r > g + 25.0) & (r >= b * 0.8)
	k = np.where(pink, strength, 0.0)
	lum = 0.3 * r + 0.59 * g + 0.11 * b
	gold = np.stack([np.minimum(255.0, lum * 1.25), lum * 0.95, lum * 0.55], -1)
	out[..., :3] = out[..., :3] * (1.0 - k[..., None]) + gold * k[..., None]
	return out


def keep_solid(rgba: np.ndarray, thr: float, near: int = 0, min_px: int = 60) -> np.ndarray:
	"""Mantém só o miolo opaco (tira brilho/fumaça translúcidos)."""
	out = rgba.copy()
	solid = out[..., 3] >= thr
	lab, n = ndimage.label(solid, structure=np.ones((3, 3), bool))
	if n:
		sizes = ndimage.sum(solid, lab, range(1, n + 1))
		ok = np.zeros(n + 1, bool)
		ok[1:] = sizes >= min_px
		solid = ok[lab]
	if near > 0:
		solid = ndimage.binary_dilation(solid, iterations=near) & (out[..., 3] > 0.3)
	out[..., 3] = np.where(solid, out[..., 3], 0.0)
	return out


def keep_largest(rgba: np.ndarray, near: int = 4) -> np.ndarray:
	"""Só o maior componente (e o que encosta nele): tira lascas de vizinhos."""
	out = rgba.copy()
	m = out[..., 3] > 0.08
	lab, n = ndimage.label(m, structure=np.ones((3, 3), bool))
	if n > 1:
		sizes = ndimage.sum(m, lab, range(1, n + 1))
		big = lab == (int(np.argmax(sizes)) + 1)
		keep = ndimage.binary_dilation(big, iterations=near) & m
		out[..., 3] = np.where(keep, out[..., 3], 0.0)
	return out


def emit(name: str, frames: list, world_scale: float, anchor_src, origin, sil: bool = True,
		store_scale: float = 0.0) -> None:
	"""Grava os quadros (mesma tela) e registra no catálogo.
	frames: lista de rgba já na mesma tela; origin: (x0, y0) da tela no espaço
	onde `anchor_src` foi medido."""
	h, w = frames[0].shape[:2]
	st = store_scale if store_scale > 0 else min(1.0, TEXELS_PER_WORLD * world_scale)
	files, sils = [], []
	for i, f in enumerate(frames):
		tag = "" if len(frames) == 1 else "_%d" % i
		small = H.resize(f, st)
		fn = "%s%s.png" % (name, tag)
		H.save(os.path.join(H.OUT, fn), small)
		files.append("res://assets/painted/hazards/" + fn)
		if sil:
			s = small.copy()
			s[..., :3] = 255.0
			fs = "%s%s_sil.png" % (name, tag)
			H.save(os.path.join(H.OUT, fs), s)
			sils.append("res://assets/painted/hazards/" + fs)
	ax = (anchor_src[0] - origin[0]) * world_scale
	ay = (anchor_src[1] - origin[1]) * world_scale
	CATALOG[name] = {"frames": files, "sil": sils, "size": [round(w * world_scale, 2), round(h * world_scale, 2)],
		"anchor": [round(ax, 2), round(ay, 2)]}
	print("%-16s %d quadro(s)  mundo %.0fx%.0f  âncora (%.1f, %.1f)  textura %dx%d" % (
		name, len(frames), w * world_scale, h * world_scale, ax, ay, small.shape[1], small.shape[0]))


def shared_canvas(key: str, cells_rc: list, fix=None):
	"""Peças de várias células numa tela comum (coordenadas LOCAIS da célula).
	Devolve (quadros, origem_local). `fix(i, rgba)` ajusta cada quadro antes."""
	pieces = []
	for (r, c) in cells_rc:
		rgba, (x0, y0) = cell_piece(key, r, c)
		cx0, cy0, _, _ = H.cell_rect(SHEETS[key], r, c)
		pieces.append((rgba, x0 - cx0, y0 - cy0))
	lx0 = min(p[1] for p in pieces)
	ly0 = min(p[2] for p in pieces)
	lx1 = max(p[1] + p[0].shape[1] for p in pieces)
	ly1 = max(p[2] + p[0].shape[0] for p in pieces)
	frames = []
	for i, (rgba, x, y) in enumerate(pieces):
		cv = np.zeros((ly1 - ly0, lx1 - lx0, 4), np.float32)
		cv[y - ly0:y - ly0 + rgba.shape[0], x - lx0:x - lx0 + rgba.shape[1]] = rgba
		if fix is not None:
			cv = fix(i, cv)
		frames.append(cv)
	return frames, (lx0, ly0)


def region(img: np.ndarray, x0: int, y0: int, x1: int, y1: int) -> np.ndarray:
	return img[y0:y1, x0:x1].copy()


# --------------------------------------------------------------------------
def pendulum() -> None:
	"""CORRENTE: suporte fixo + elo (ladrilho) + lâmina que GIRA pelo pivô
	(código). Célula do meio (lâmina parada embaixo do pivô)."""
	img = sheet("hz_1")
	# suporte (braço + coluna), sem a corrente que desce da engrenagem
	br = region(img, 690, 4, 1000, 190)
	br[80:, 750 - 690:780 - 690, 3] = 0.0
	br[..., 3] = H.clean_specks(br[..., 3], 80)
	emit("pend_bracket", [br], 0.25, (764, 66), (690, 4))
	# elo de corrente reto (entre a engrenagem e a roseta): ladrilho vertical
	ch = region(img, 752, 92, 777, 168)
	emit("pend_chain", [ch], 0.3, (764.5, 92), (752, 92), sil=False)
	# lâmina (roseta + 3 correntes + meia-lua). Âncora = ponto de pendurar.
	bl = region(img, 600, 172, 940, 442)
	emit("pend_blade", [bl], 0.19, (764, 176), (600, 172))
	CATALOG["pend_blade"]["center"] = [round((770 - 600) * 0.19, 2), round((350 - 172) * 0.19, 2)]


def bell() -> None:
	"""SILÊNCIO: o badalo mudo — suporte de parede + sino que gira (código)."""
	img = sheet("hz_3")
	br = region(img, 56, 4, 420, 505)
	# tira o sino e a corrente dele (x 160..410, y > 96)
	br[96:, 160 - 56:, 3] = 0.0
	br[..., 3] = H.clean_specks(br[..., 3], 80)
	br = warm_pink(br)
	emit("bell_bracket", [br], 0.21, (297, 70), (56, 4))
	bd = region(img, 160, 96, 412, 500)
	bd = keep_largest(bd)
	bd = warm_pink(bd)
	emit("bell_body", [bd], 0.21, (297, 98), (160, 96))
	CATALOG["bell_body"]["center"] = [round((297 - 160) * 0.21, 2), round((290 - 96) * 0.21, 2)]


def guillotine() -> None:
	"""COROA: moldura (atrás da Sophia) + lâmina que desce (código) + haste."""
	img = sheet("hz_1")
	c0 = region(img, 60, 450, 450, 1010)      # aberta (lâmina no alto)
	c2 = region(img, 1084, 450, 1474, 1010)   # cravada (mesmo enquadramento: +1024)
	# vão interno entre as colunas, medido na linha y=700 da aberta (transparente)
	row = c0[700 - 450, :, 3]
	mid = row.shape[0] // 2
	L = mid
	while L > 0 and row[L - 1] < 0.1:
		L -= 1
	R = mid
	while R < row.shape[0] - 1 and row[R + 1] < 0.1:
		R += 1
	print("guilhotina: vão interno x local %d..%d" % (L, R))
	y0, y1 = 528 - 450, 648 - 450
	blade = c0[y0:y1, L - 10:R + 11].copy()
	frame = c0.copy()
	frame[y0:y1, L:R + 1, 3] = 0.0
	# devolve as correntes/trilhos que a lâmina tapava (da cravada, sem lâmina ali)
	for xa, xb in [(L - 10, L), (R + 1, R + 11)]:
		frame[y0:y1, xa:xb] = c2[y0:y1, xa:xb]
	# haste central da cravada (entre a travessa e a lâmina): ladrilho vertical
	rod_row = c2[700 - 450, L:R + 1, 3]
	# a haste é o trecho opaco que contém o MEIO do vão (as correntes ficam nas bordas)
	m = len(rod_row) // 2
	a0 = m
	while a0 > 0 and rod_row[a0 - 1] > 0.3:
		a0 -= 1
	a1 = m
	while a1 < len(rod_row) - 1 and rod_row[a1 + 1] > 0.3:
		a1 += 1
	rx0, rx1 = L + a0 - 1, L + a1 + 2
	rod = c2[640 - 450:760 - 450, rx0:rx1].copy()
	s = 0.42
	floor_y = 1005 - 450
	cx = (L + R) / 2.0
	emit("gu_frame", [frame], s, (cx, floor_y), (0, 0))
	emit("gu_blade", [blade], s, ((R - L) / 2.0 + 10, y1 - y0 - 10), (0, 0))
	emit("gu_rod", [rod], s, ((rx1 - rx0) / 2.0, 0), (0, 0), sil=False)
	# alturas úteis (mundo, relativas ao chão): base da lâmina aberta e topo da moldura
	CATALOG["gu_frame"]["blade_open_base"] = round(-(floor_y - (y1 - 10)) * s, 2)
	CATALOG["gu_frame"]["rod_top"] = round(-(floor_y - (545 - 450)) * s, 2)


def spears() -> None:
	"""COROA/SILÊNCIO: laje com fendas (chão) + lanças que SOBEM da fenda."""
	img = sheet("hz_2")
	slab, o = shared_canvas("hz_2", [(0, 0)])
	s = 0.25            # 480 px → 120 de mundo (largura padrão); o jogo reescala pela largura
	hole = 316 - 0      # linha das fendas (y local da célula)
	emit("spear_slab", slab, s, (256, hole), o)
	ext, o2 = shared_canvas("hz_2", [(0, 2)])
	# só as lanças: acima da linha das fendas
	cut = hole + 4 - o2[1]
	sp = ext[0][:cut].copy()
	emit("spear_tips", [sp], s, (256, hole + 4), o2)
	mid, o3 = shared_canvas("hz_2", [(0, 1)])
	emit("spear_mid", mid, s, (256, hole), o3, sil=False)


def maw() -> None:
	"""FOME: a boca no chão — fechada / abrindo (aviso) / mordendo."""
	fr, o = shared_canvas("hz_2", [(1, 0), (1, 1), (1, 2)])
	emit("maw", fr, 0.16, (256, 795 - 512), o)


def shackles() -> None:
	"""CORRENTE: correntes que brotam do chão — rachada / saindo / estendidas."""
	fr, o = shared_canvas("hz_7", [(1, 0), (1, 1), (1, 2)])
	emit("shackles", fr, 0.245, (256, 838 - 512), o)


def spores() -> None:
	"""PRAGA: casulo — fechado / inchando / estourado (a nuvem é por código)."""
	def fix(i, cv):
		if i == 2:
			cv = keep_solid(cv, 0.9, near=1, min_px=120)
		return warm_pink(cv)
	fr, o = shared_canvas("hz_3", [(1, 0), (1, 1), (1, 2)], fix)
	bottom = 970 - 512
	emit("spore_pod", fr, 0.112, (256, bottom), o)


def totem() -> None:
	"""TOTEM: aceso / pulsando / quebrado."""
	fr, o = shared_canvas("hz_4", [(0, 0), (0, 1), (0, 2)])
	emit("totem", fr, 0.133, (268, 597), o)
	# ponto do cristal (olho) no quadro aceso, em mundo relativo à âncora
	CATALOG["totem"]["eye"] = [round((268 - 268) * 0.133, 2), round((95 - 597) * 0.133, 2)]


def sinking() -> None:
	"""TORPOR: pedra do sono — inteira / rachada (aviso) / afundando."""
	fr, o = shared_canvas("hz_4", [(1, 0), (1, 1), (1, 2)])
	# largura de referência: 485 px da folha = largura do perigo (o jogo reescala)
	emit("sink_stone", fr, 0.2474, (256, 688 - 512), o)
	CATALOG["sink_stone"]["ref_w"] = round(485 * 0.2474, 2)


def mirror() -> None:
	"""ESPELHO: só a plataforma SÓLIDA (o reflexo/fantasma é a mesma pintura
	translúcida com tremor, por código — a pintada saiu rosada)."""
	fr, o = shared_canvas("hz_6", [(0, 1)])
	emit("mirror_plat", fr, 0.241, (256, 210), o)
	CATALOG["mirror_plat"]["ref_w"] = round(498 * 0.241, 2)


def shards() -> None:
	"""CENTRO: cacos pequeno / médio / grande — só os corpos (o brilho rosado
	vira efeito por código)."""
	sizes = [(1, 0, 0.12), (1, 1, 0.105), (1, 2, 0.09)]
	for i, (r, c, s) in enumerate(sizes):
		rgba, (x0, y0) = cell_piece("hz_6", r, c)
		core = keep_solid(rgba, 0.8, near=1, min_px=150)
		core = warm_pink(core, 1.0)
		b = H.bbox(core[..., 3], 0.1)
		core = core[b[1]:b[3], b[0]:b[2]]
		# ponta (embaixo, no meio) = ponto de impacto
		emit("shard_%d" % i, [core], s, (core.shape[1] / 2.0, core.shape[0]), (0, 0))


def tide() -> None:
	"""FUGA: a borda da maré escura (3 quadros de onda, a frente à direita)."""
	fr, o = shared_canvas("hz_7", [(0, 0), (0, 1), (0, 2)])
	right = max(H.bbox(f[..., 3])[2] for f in fr) + o[0]
	emit("tide_wave", fr, 0.95, (right, 440), o, sil=False, store_scale=0.9)


def vault() -> None:
	"""SALA SECRETA: a porta do selo — selada / abrindo / aberta."""
	fr, o = shared_canvas("hz_5", [(0, 0), (0, 1), (0, 2)])
	emit("vault_door", fr, 0.165, (265, 504), o, sil=False)


def altar() -> None:
	"""SANTUÁRIO: altar adormecido / aceso."""
	fr, o = shared_canvas("hz_5", [(1, 0), (1, 1)], lambda i, cv: warm_pink(cv, 0.8))
	emit("altar", fr, 0.15, (264, 946 - 512), o, sil=False)


def ward() -> None:
	"""LUZ DO ADORMECIDO: frágil (hz_5, chama clara) / forte (hz_6, dourada)."""
	weak, (x0, y0) = cell_piece("hz_5", 1, 2)
	weak = warm_pink(weak, 1.0)
	strong, (x1, y1) = cell_piece("hz_6", 0, 0)
	s_w = 50.0 / weak.shape[0]
	s_s = 54.0 / strong.shape[0]
	emit("ward_weak", [weak], s_w, (weak.shape[1] / 2.0, weak.shape[0]), (0, 0), sil=False)
	emit("ward_strong", [strong], s_s, (strong.shape[1] / 2.0, strong.shape[0]), (0, 0), sil=False)
	# altura da chama (mundo, acima da base) para o brilho por código
	CATALOG["ward_weak"]["flame"] = [0.0, round(-0.62 * 50.0, 2)]
	CATALOG["ward_strong"]["flame"] = [0.0, round(-0.66 * 54.0, 2)]


def main() -> None:
	os.makedirs(H.OUT, exist_ok=True)
	for f in os.listdir(H.OUT):
		if f.endswith(".png") or f.endswith(".json") or f == "hazards_data.gd":
			os.remove(os.path.join(H.OUT, f))
	for fn in [pendulum, bell, guillotine, spears, maw, shackles, spores, totem, sinking, mirror,
			shards, tide, vault, altar, ward]:
		fn()
	# catálogo como GDScript (um .json solto não entraria no export do jogo)
	nl = chr(10)
	with open(os.path.join(H.OUT, "hazards_data.gd"), "w", encoding="utf-8", newline=nl) as fh:
		fh.write("extends RefCounted" + nl)
		fh.write("## GERADO por tools/hazards7/cut_hazards.py - nao edite a mao." + nl)
		fh.write("## Catalogo dos perigos pintados (lido por scripts/fx/hazard_art.gd)." + nl)
		fh.write("const DATA := " + json.dumps(CATALOG, ensure_ascii=False) + nl)
	print("catalogo: %d pecas -> hazards_data.gd" % len(CATALOG))


if __name__ == "__main__":
	main()
