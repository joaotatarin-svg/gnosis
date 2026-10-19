"""FUNDOS HD POR ÉON (Diretor de Cenário 7).

Lê as camadas em resolução cheia que a Produção (GPT) gera — cópia em
`artes/gpt/bg/` (originais em C:\\gnosis-wt\\_gpt\\out, MANIFESTO FILA 12):
  bg_<i>_<nome>_far_a.png        céu + distância, sem chão (RGB, sem magenta)
  bg_<i>_<nome>_mid_{a,b,c}.png  estruturas do meio sobre magenta #FF00FF
  bg_<i>_<nome>_wings_{a,b}.png  pilares das bordas + entulho + chão vazio, sobre magenta
e grava em `assets/backgrounds/hd/`:
  eon_<i>_far.png            o far recortado (só as linhas visíveis)
  eon_<i>_mid_<v>.png        mid com alfa (chave magenta sem franja), só as linhas com conteúdo
  eon_<i>_wings_<v>.png      asas com alfa, cortadas na linha do chão MEDIDA
  eon_<i>_floor.png          o chão pintado (abaixo da linha do chão das asas), luz achatada
e reescreve o bloco "# >>> GERADO HD" de `scripts/fx/scenery_library.gd`.

LINHA DO CHÃO MEDIDA (o GPT não acerta os 77% pedidos): para as asas, a 1ª linha
em que ≥ 90% das colunas são opacas (alfa ≥ 0,5) — onde começa o chão; para o mid,
a BASE: a última linha com ≥ 8% das colunas opacas (pé das estruturas). Para o far (sem alfa), o "horizonte" = a última linha com detalhe
(energia de borda ≥ 30% da mediana do miolo), abaixo dela só névoa.
No jogo, cada camada é posta com a SUA linha em Scenery.FLOOR_Y (alinhamento por
camada, não por porcentagem).

Uso:  python tools/cenario7/build_hd.py [--only 0,1] [--partial]
(--partial aceita Éon só com o far — para teste; o jogo só deve receber Éon completo.)
Sem libs fora do pipeline (PIL, numpy, opencv).
"""
import os, sys, re, glob, json
import numpy as np, cv2
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = os.path.join(ROOT, 'artes', 'gpt', 'bg')
OUT = os.path.join(ROOT, 'assets', 'backgrounds', 'hd')
LIB = os.path.join(ROOT, 'scripts', 'fx', 'scenery_library.gd')
PAINT_H = 280.0          # = Scenery.PAINT_H (altura lógica da pintura acima do chão)
TOP_MIN = 6.0            # o topo do far tem de ficar a ≤ isto (px lógicos) do topo da pintura
NAMES = ['torpor', 'fome', 'corrente', 'silencio', 'espelho', 'praga', 'coroa', 'centro', 'mente']

# GRADAÇÃO (R18 do NEURO_SATISFACAO: o plano de fundo 10–25% menos saturado e com
# menos contraste interno que os personagens; saturação máxima fica pros golpes e
# telegrafos). sat = fração da saturação mantida; con = fração do contraste em
# torno da média; haze = mistura com a cor do ar do Éon; gain = brilho.
GRADE = {
	'far':   {'sat': 0.92, 'con': 0.90, 'haze': 0.06, 'gain': 1.00},
	'mid':   {'sat': 0.82, 'con': 0.85, 'haze': 0.10, 'gain': 0.92},
	'wings': {'sat': 0.84, 'con': 0.88, 'haze': 0.05, 'gain': 0.80},
	'floor': {'sat': 0.80, 'con': 0.85, 'haze': 0.00, 'gain': 0.92},
}


def log(*a):
	print(*a, flush=True)


def load_rgb(p):
	return np.asarray(Image.open(p).convert('RGB')).astype(np.float32) / 255.0


# --- chave magenta -------------------------------------------------------------------

def magenta_key(rgb):
	"""Alfa + cor sem franja a partir do fundo magenta.
	Força da chave k = min(R,B) − G (magenta puro ≈ 0,97; pedra/vela/estandarte < 0,1).
	Nos pixels de borda (mistura tinta+magenta) a cor é DESMISTURADA:
	C = α·F + (1−α)·M  →  F = (C − (1−α)·M)/α, e o que sobrar de rosa é cortado."""
	k = np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]
	pure = k > 0.80
	M = np.median(rgb[pure], axis=0) if pure.any() else np.array([1.0, 0.0, 1.0], np.float32)
	k_bg = float(np.minimum(M[0], M[2]) - M[1])
	k_fg = 0.16
	a = np.clip((k_bg - 0.05 - k) / (k_bg - 0.05 - k_fg), 0.0, 1.0)
	# pedacinhos soltos (respingos de chave) somem; buracos minúsculos fecham
	solid = (a > 0.5).astype(np.uint8)
	n, lab, st, _ = cv2.connectedComponentsWithStats(solid, 8)
	small = np.zeros(n, bool)
	small[1:] = st[1:, cv2.CC_STAT_AREA] < 40
	a[small[lab]] = 0.0
	# borda: 1 px pra dentro (a desmistura já tira o rosa; isto tira o halo de 1 px)
	a_er = cv2.erode(a, np.ones((3, 3), np.uint8))
	a = np.minimum(a, cv2.GaussianBlur(a_er, (0, 0), 0.7) * 1.08)
	a = np.clip(a, 0, 1)
	safe = np.maximum(a, 1e-3)[..., None]
	F = (rgb - (1.0 - a[..., None]) * M) / safe
	F = np.where(a[..., None] > 0.02, F, 0.0)
	F = np.clip(F, 0, 1)
	# rosa residual: min(R,B) não pode passar muito do G onde a borda é semitransparente
	edge = (a < 0.98) & (a > 0.0)
	spill = np.clip(np.minimum(F[..., 0], F[..., 2]) - F[..., 1] - 0.06, 0, None)
	spill = np.where(edge, spill, 0.0)
	F[..., 0] -= spill
	F[..., 2] -= spill
	a[a < 0.04] = 0.0
	return np.clip(F, 0, 1), a, M


def pink_residue(rgb, a):
	"""% de pixels visíveis (α ≥ 0,5) com cara de magenta (para o relatório)."""
	k = np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]
	vis = a >= 0.5
	return float(((k > 0.25) & vis).sum()) / max(1, int(vis.sum())) * 100.0


def floor_line(a, frac=0.90):
	"""1ª linha (de cima) em que ≥ frac das colunas são opacas."""
	op = (a >= 0.5).mean(1)
	rows = np.where(op >= frac)[0]
	if rows.size:
		return int(rows[0])
	# sem faixa contínua (espelhos soltos, colunas): a base = última linha com ≥ 3% de conteúdo
	return int(np.where(op > 0.03)[0].max())


def base_line(a):
	"""MID: a base = a última linha com ≥ 8% das colunas opacas (o pé das
	estruturas; grades e colunas finas não chegam a 50% numa linha, por isso
	não dá pra exigir faixa cheia)."""
	op = (a >= 0.5).mean(1)
	return int(np.where(op >= 0.08)[0].max())


def far_horizon(rgb):
	"""Última linha com detalhe (abaixo dela é névoa lisa)."""
	g = cv2.cvtColor((rgb * 255).astype(np.uint8), cv2.COLOR_RGB2GRAY).astype(np.float32)
	lap = np.abs(cv2.Laplacian(cv2.GaussianBlur(g, (0, 0), 1.2), cv2.CV_32F))
	e = cv2.GaussianBlur(lap.mean(1).reshape(-1, 1), (1, 0), 12).ravel()
	H = len(e)
	ref = np.median(e[int(H * 0.15):int(H * 0.55)])
	rows = np.where(e >= ref * 0.30)[0]
	h = int(rows.max()) if rows.size else int(H * 0.7)
	return int(np.clip(h, H * 0.55, H * 0.85))


def astro(rgb, line):
	"""Centro do maior foco de luz (lua/sol/esfera) acima da linha — vira o foco
	dos raios. Em px da imagem original."""
	g = cv2.cvtColor((rgb[:line] * 255).astype(np.uint8), cv2.COLOR_RGB2GRAY).astype(np.float32)
	b = cv2.GaussianBlur(g, (0, 0), 25)
	y, x = np.unravel_index(np.argmax(b), b.shape)
	return float(x), float(y)


# --- gradação ------------------------------------------------------------------------

def grade(rgb, kind, haze, alpha=None):
	gp = GRADE[kind]
	lum = (rgb @ np.array([0.299, 0.587, 0.114], np.float32))[..., None]
	out = lum + (rgb - lum) * gp['sat']
	w = alpha[..., None] if alpha is not None else None
	if w is not None and w.sum() > 0:
		mean = (out * w).sum((0, 1)) / max(1e-3, float(w.sum()))
	else:
		mean = out.reshape(-1, 3).mean(0)
	out = mean + (out - mean) * gp['con']
	out = out * (1 - gp['haze']) + np.asarray(haze, np.float32) * gp['haze']
	return np.clip(out * gp['gain'], 0, 1)


def flatten_light(rgb, sigma=36.0):
	"""Chão: tira a luz de baixa frequência (reflexos pintados dos pilares, que
	no jogo andariam fora do lugar — o shader do chão já reflete a tela de
	verdade) e mantém a textura (rachaduras, pedras). Média por linha preservada."""
	low = cv2.GaussianBlur(rgb, (0, 0), sigma)
	W = rgb.shape[1]
	row = np.median(low[:, int(W * 0.25):int(W * 0.75)], axis=1, keepdims=True)
	return np.clip(rgb - low + row, 0, 1)


# --- saída ---------------------------------------------------------------------------

def save_rgba(path, rgb, alpha):
	rgb = np.where(alpha[..., None] > 0.004, rgb, 0.0)
	a = np.dstack([rgb, alpha])
	Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA').save(path, optimize=True)


def save_rgb(path, rgb):
	Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGB').save(path, optimize=True)


def find(i, kind):
	return sorted(glob.glob(os.path.join(SRC, f'bg_{i}_*_{kind}_*.png')))


def build_eon(i, haze):
	d = {}
	fars, mids, wings = find(i, 'far'), find(i, 'mid'), find(i, 'wings')
	# Só Éon COMPLETO (far + mid + asas): o far novo é "céu e distância, sem
	# chão"; as estruturas do meio que a pintura antiga tinha no far (gaiolas da
	# Corrente, molduras do Espelho) vêm no mid novo. Far novo + camadas antigas
	# perdia a cara do Éon (conferido nas capturas de 19/10) — então espera o jogo.
	# Asas podem faltar (chegam depois): aí o jogo usa as asas/entulho ANTIGOS na
	# frente do mid novo (Scenery._build_painted).
	if not fars or (not mids and '--partial' not in sys.argv):
		log(f'eon {i}: incompleto (far={len(fars)} mid={len(mids)} asas={len(wings)}) — fica o fundo antigo')
		return None
	# ASAS primeiro: a linha do chão delas define a escala do Éon.
	wl = []
	for p in wings:
		rgb, a, M = magenta_key(load_rgb(p))
		fl = floor_line(a)
		wl.append((p, rgb, a, fl))
	s = PAINT_H / wl[0][3] if wl else PAINT_H / 711.0
	d['s'] = s
	# FAR
	far = load_rgb(fars[0])
	fh = far_horizon(far)
	s_far = max(s, (PAINT_H - TOP_MIN) / fh)
	ax, ay = astro(far, fh)
	cut = min(far.shape[0], fh + int(40 / s_far))      # 40 px lógicos abaixo do chão bastam
	save_rgb(os.path.join(OUT, f'eon_{i}_far.png'), grade(far[:cut], 'far', haze))
	d['far'] = {'tex': f'eon_{i}_far', 'w': far.shape[1], 'h': cut, 'y0': 0, 'line': fh, 's': s_far, 'astro': [ax, ay]}
	log(f'eon {i}: far horizonte={fh} ({fh / far.shape[0]:.0%}) s={s_far:.3f} astro=({ax:.0f},{ay:.0f})')
	# MID
	d['mid'] = []
	for p in mids:
		v = os.path.splitext(p)[0][-1]
		rgb, a, M = magenta_key(load_rgb(p))
		fl = base_line(a)
		# conteúdo pendurado no topo (cortinas da Fome, correntes da Corrente):
		# some em degradê, sem linha reta quando a câmera sobe
		if (a[:4] > 0.5).mean() > 0.03:
			yy = np.arange(a.shape[0], dtype=np.float32)[:, None]
			a = a * np.clip(yy / 90.0, 0, 1) ** 0.8
		rows = np.where(a.max(1) > 0.02)[0]
		y0 = max(0, int(rows.min()) - 2)
		y1 = min(a.shape[0], fl + int(12 / s))
		g = grade(rgb, 'mid', haze, a)
		save_rgba(os.path.join(OUT, f'eon_{i}_mid_{v}.png'), g[y0:y1], a[y0:y1])
		d['mid'].append({'tex': f'eon_{i}_mid_{v}', 'w': a.shape[1], 'h': y1 - y0, 'y0': y0, 'line': fl})
		log(f'  mid_{v}: linha={fl} ({fl / a.shape[0]:.0%}) conteúdo {y0}..{y1} rosa={pink_residue(rgb, a):.3f}% M={np.round(M * 255)}')
	# WINGS (só acima da linha do chão; o chão vai pro eon_<i>_floor)
	d['wings'] = []
	for p, rgb, a, fl in wl:
		v = os.path.splitext(p)[0][-1]
		aw = a.copy()
		# corte macio na linha do chão (4 px) e topo que some (o pilar não termina
		# numa linha reta quando a câmera sobe nos pulos)
		yy = np.arange(a.shape[0], dtype=np.float32)[:, None]
		aw *= np.clip((fl + 4 - yy) / 4.0, 0, 1)
		aw *= np.clip(yy / 90.0, 0, 1) ** 0.8
		rows = np.where(aw.max(1) > 0.02)[0]
		y0 = max(0, int(rows.min()) - 2)
		y1 = fl + 4
		g = grade(rgb, 'wings', haze, aw)
		save_rgba(os.path.join(OUT, f'eon_{i}_wings_{v}.png'), g[y0:y1], aw[y0:y1])
		d['wings'].append({'tex': f'eon_{i}_wings_{v}', 'w': a.shape[1], 'h': y1 - y0, 'y0': y0, 'line': fl})
		log(f'  wings_{v}: linha={fl} ({fl / a.shape[0]:.0%}) rosa={pink_residue(rgb, aw):.3f}% M={np.round(M * 255)}')
	# FLOOR: do primeiro wings (abaixo da linha medida + 6 px de folga da borda do entulho)
	if wl:
		p, rgb, a, fl = wl[0]
		f0 = fl + 6
		fr = flatten_light(rgb[f0:])
		save_rgb(os.path.join(OUT, f'eon_{i}_floor.png'), grade(fr, 'floor', haze))
		d['floor'] = {'tex': f'eon_{i}_floor', 'w': rgb.shape[1], 'h': rgb.shape[0] - f0}
	return d


def gd_value(v):
	if isinstance(v, dict):
		return '{' + ', '.join(f'"{k}": {gd_value(x)}' for k, x in v.items()) + '}'
	if isinstance(v, list):
		if len(v) == 2 and all(isinstance(x, float) for x in v):
			return 'Vector2(%.4f, %.4f)' % tuple(v)
		return '[' + ', '.join(gd_value(x) for x in v) + ']'
	if isinstance(v, float):
		return '%.5f' % v
	if isinstance(v, str):
		return f'"{v}"'
	return str(v)


def write_lib(hd):
	s = open(LIB, encoding='utf-8').read()
	lines = ['## DADOS GERADOS por tools/cenario7/build_hd.py — não editar à mão.',
		'## Por Éon com arte HD: s = escala (px lógicos por px da imagem) do Éon; por camada:',
		'## tex, w×h da textura, y0 = 1ª linha da imagem original na textura, line = linha',
		'## do chão MEDIDA (px da imagem original), far.s = escala própria do far, far.astro =',
		'## foco de luz (px da imagem original).',
		'const HD := {']
	for i in sorted(hd):
		lines.append(f'\t{i}: {gd_value(hd[i])},')
	lines.append('}')
	block = '# >>> GERADO HD\n' + '\n'.join(lines) + '\n# <<< GERADO HD'
	if '# >>> GERADO HD' in s:
		s = re.sub(r'# >>> GERADO HD.*?# <<< GERADO HD', lambda _m: block, s, flags=re.S)
	else:
		s = s.replace('# <<< GERADO\n', '# <<< GERADO\n\n' + block + '\n', 1)
	open(LIB, 'w', encoding='utf-8', newline='\n').write(s)


def haze_of(i):
	"""Cor da névoa do Éon = a mesma do catálogo (LAYERS) — o resto do cenário usa ela."""
	s = open(LIB, encoding='utf-8').read()
	rows = re.findall(r'"haze": Color\(([\d.]+), ([\d.]+), ([\d.]+)\)', s.split('# <<< GERADO')[0])
	return [float(x) for x in rows[i]] if i < len(rows) else [0.5, 0.55, 0.6]


if __name__ == '__main__':
	only = None
	if '--only' in sys.argv:
		only = [int(x) for x in sys.argv[sys.argv.index('--only') + 1].split(',')]
	os.makedirs(OUT, exist_ok=True)
	# preserva os Éons já gerados que não estão no --only
	hd = {}
	cache = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'hd_data.json')
	if os.path.exists(cache):
		hd = {int(k): v for k, v in json.load(open(cache, encoding='utf-8')).items()}
	for i in range(9):
		if only is not None and i not in only:
			continue
		d = build_eon(i, haze_of(i))
		if d is not None:
			hd[i] = d
		else:
			hd.pop(i, None)
			for f in glob.glob(os.path.join(OUT, f'eon_{i}_*.png*')):
				os.remove(f)
	json.dump(hd, open(cache, 'w', encoding='utf-8'), indent=1)
	write_lib(hd)
	log('ok:', sorted(hd))
