"""PIPELINE OFFLINE DOS FUNDOS (Diretor de Cenário).

Lê `assets/painted/eons.png` (9 pinturas ~512×341 numa folha 1536×1024) e gera,
por Éon, as camadas de paralaxe em `assets/backgrounds/`:
  eon_<i>_far.png    céu + distância (as "asas" removidas e preenchidas com névoa)
  eon_<i>_mid.png    as ASAS (pilares/estantes/estandartes das bordas) com alfa
  eon_<i>_near.png   a faixa de entulho/velas logo acima da linha do chão, com alfa
  eon_<i>_floor.png  o chão pintado (abaixo da linha do chão) p/ o shader do chão
  eon_<i>_fgcol.png  coluna de primeiro plano (asa escurecida e desfocada)
e genéricos `fg_rubble.png`, `fg_pillar.png` (silhuetas de primeiro plano a
partir de `assets/painted/architecture.png`).

Upscale: Real-ESRGAN (ncnn-vulkan, modelo x4plus, roda na RX 7600 via Vulkan)
→ 4×, depois Lanczos até 3× (supersample na janela 1280×720) com 15% do
Lanczos misturado de volta (devolve a textura de pincel que a IA alisa).
Sem o executável, cai em Lanczos + nitidez adaptativa (unsharp só nas bordas).
Recorte: GrabCut guiado por faixas (asas nas bordas, entulho na base),
refinado com guided filter na resolução final (borda macia que segue a tinta).
No fim reescreve o bloco GERADO de `scripts/fx/scenery_library.gd`.

Uso:  python tools/scenery/build_backgrounds.py [--no-ai] [--only 0,3]
"""
import os, sys, subprocess, re
import numpy as np, cv2
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import near_cleanup

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SHEET = os.path.join(ROOT, 'assets', 'painted', 'eons.png')
ARCH = os.path.join(ROOT, 'assets', 'painted', 'architecture.png')
OUT = os.path.join(ROOT, 'assets', 'backgrounds')
LIB = os.path.join(ROOT, 'scripts', 'fx', 'scenery_library.gd')
CACHE = os.path.join(os.environ.get('LOCALAPPDATA', ROOT), 'gnosis_scenery_cache')
ESRGAN = r'C:\Users\jmtat\gnosis-tools\realesrgan\realesrgan-ncnn-vulkan.exe'
FINAL = 3                     # escala final em relação à pintura original

# Recorte de cada pintura na folha (sem as linhas pretas de separação).
COLS = [(2, 509), (515, 1021), (1027, 1534)]
ROWS = [(2, 338), (343, 657), (663, 1022)]
# Linha do chão (px da pintura recortada) — medida à mão numa prancha com grade.
FLOOR = [263, 263, 263, 242, 242, 242, 244, 244, 244]
# Asas: tudo à esquerda de l e à direita de r é candidato a "asa" (camada mid).
WINGS = [(70, 455), (45, 470), (85, 455), (80, 440), (60, 445), (75, 430), (50, 420), (60, 455), (85, 445)]
# Altura (px da pintura) da faixa de entulho acima do chão (camada near).
BAND = [34, 34, 30, 30, 30, 30, 36, 30, 30]


def log(*a):
	print(*a, flush=True)


def tile(i):
	im = Image.open(SHEET).convert('RGB')
	r, c = i // 3, i % 3
	return im.crop((COLS[c][0], ROWS[r][0], COLS[c][1], ROWS[r][1]))


def upscale(i, t, use_ai):
	"""4× por IA (com cache) → Lanczos até FINAL×. Retorna float32 RGB 0..1."""
	os.makedirs(CACHE, exist_ok=True)
	src = os.path.join(CACHE, f't{i}.png')
	dst = os.path.join(CACHE, f'u{i}.png')
	t.save(src)
	w, h = t.size
	lz = np.asarray(t.resize((w * FINAL, h * FINAL), Image.LANCZOS)).astype(np.float32) / 255
	if use_ai and os.path.exists(ESRGAN):
		if not os.path.exists(dst) or os.path.getmtime(dst) < os.path.getmtime(SHEET):
			subprocess.run([ESRGAN, '-i', src, '-o', dst, '-n', 'realesrgan-x4plus', '-s', '4'],
				stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
		u = Image.open(dst).convert('RGB')
		ai = np.asarray(u.resize((w * FINAL, h * FINAL), Image.LANCZOS)).astype(np.float32) / 255
		return np.clip(ai * 0.85 + lz * 0.15, 0, 1)
	# nitidez adaptativa: unsharp forte só onde há borda (não realça o ruído liso)
	blur = cv2.GaussianBlur(lz, (0, 0), 1.6)
	edge = cv2.Sobel(cv2.cvtColor(lz, cv2.COLOR_RGB2GRAY), cv2.CV_32F, 1, 1, ksize=3)
	k = np.clip(np.abs(edge) * 6.0, 0.2, 1.0)[..., None]
	return np.clip(lz + (lz - blur) * 1.2 * k, 0, 1)


def grabcut(img_bgr, lab):
	m = lab.copy()
	bg = np.zeros((1, 65), np.float64)
	fg = np.zeros((1, 65), np.float64)
	cv2.grabCut(img_bgr, m, None, bg, fg, 5, cv2.GC_INIT_WITH_MASK)
	return np.where((m == cv2.GC_FGD) | (m == cv2.GC_PR_FGD), 1.0, 0.0).astype(np.float32)


def masks(i, t):
	"""Máscaras (asa, entulho) na resolução 2× da pintura, só acima do chão."""
	S = 2
	a = np.asarray(t.resize((t.width * S, t.height * S), Image.BICUBIC))
	fl = FLOOR[i] * S
	a = cv2.cvtColor(np.ascontiguousarray(a[:fl]), cv2.COLOR_RGB2BGR)
	W = a.shape[1]
	l, r = WINGS[i][0] * S, WINGS[i][1] * S
	lab = np.full(a.shape[:2], cv2.GC_BGD, np.uint8)
	lab[:, :l + 40] = cv2.GC_PR_BGD
	lab[:, r - 40:] = cv2.GC_PR_BGD
	lab[:, :l] = cv2.GC_PR_FGD
	lab[:, r:] = cv2.GC_PR_FGD
	lab[:, :int(l * 0.45)] = cv2.GC_FGD
	lab[:, W - int((W - r) * 0.45):] = cv2.GC_FGD
	wing = grabcut(a, lab)
	b = BAND[i] * S
	lab2 = np.full(a.shape[:2], cv2.GC_BGD, np.uint8)
	lab2[fl - b * 2:fl] = cv2.GC_PR_BGD
	lab2[fl - b:fl] = cv2.GC_PR_FGD
	lab2[fl - int(b * 0.25):fl] = cv2.GC_FGD
	near = grabcut(a, lab2)
	return wing, near


def refine(m, guide, fl_px, r=10, eps=1e-3):
	"""Sobe a máscara pra resolução final e cola a borda na tinta (guided filter)."""
	w = guide.shape[1]
	m = cv2.resize(m, (w, fl_px), interpolation=cv2.INTER_LINEAR)
	m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
	g = np.ascontiguousarray(guide[:fl_px]).astype(np.float32)
	out = cv2.ximgproc.guidedFilter(g, m, r, eps)
	return np.clip((out - 0.15) / 0.7, 0, 1)


def save_rgba(path, rgb, alpha):
	# RGB zerado onde o alfa é 0: o PNG comprime ~5× melhor (camadas são quase vazias)
	rgb = np.where(alpha[..., None] > 0.004, rgb, 0.0)
	a = np.dstack([rgb, alpha])
	Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), 'RGBA').save(path, optimize=True)


def save_rgb(path, rgb):
	Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), 'RGB').save(path, optimize=True)


def build_eon(i, use_ai):
	t = tile(i)
	img = upscale(i, t, use_ai)
	H, W = img.shape[:2]
	fl = FLOOR[i] * FINAL
	wing_s, near_s = masks(i, t)
	wing = refine(wing_s, img, fl)
	near = refine(near_s, img, fl, r=6) * (1.0 - wing)
	above = img[:fl]
	# Cor da névoa do Éon: média dos tons claros do miolo (o "ar" da pintura).
	core = above[:, int(W * 0.3):int(W * 0.7)].reshape(-1, 3)
	lum = core @ np.array([0.299, 0.587, 0.114], np.float32)
	haze = core[lum > np.percentile(lum, 70)].mean(0)
	sky = above[:max(4, H // 30)].reshape(-1, 3).mean(0)
	# FAR: asas preenchidas por reflexo do miolo vizinho + névoa (lê como distância).
	l, r = WINGS[i][0] * FINAL, WINGS[i][1] * FINAL
	xs = np.arange(W)
	src = xs.copy()
	src[:l] = np.clip(2 * l - xs[:l], 0, W - 1)
	src[r:] = np.clip(2 * r - xs[r:], 0, W - 1)
	fill = cv2.GaussianBlur(above[:, src], (0, 0), 2)
	fill = fill * 0.78 + haze * 0.14
	mf = cv2.GaussianBlur(cv2.dilate(wing, np.ones((7, 7), np.uint8)), (0, 0), 4)[..., None]
	far = above * (1 - mf) + fill * mf
	# névoa de horizonte na base do far (esconde o entulho repetido da near)
	yy = np.linspace(0, 1, fl, dtype=np.float32)[:, None, None]
	hz = np.clip((yy - 0.72) / 0.28, 0, 1) ** 1.5 * 0.45
	far = far * (1 - hz) + cv2.GaussianBlur(far, (0, 0), 3) * hz * 0.5 + haze * hz * 0.5
	save_rgb(os.path.join(OUT, f'eon_{i}_far.png'), far)
	save_rgba(os.path.join(OUT, f'eon_{i}_mid.png'), above, wing)
	# NEAR: só as linhas com conteúdo (a faixa da base); near_y = onde ela começa
	rows = np.where(near.max(1) > 0.01)[0]
	ny = max(0, int(rows.min()) - 4) if rows.size else fl - 8
	save_rgba(os.path.join(OUT, f'eon_{i}_near.png'), above[ny:], near[ny:])
	# limpeza da near (névoa do fundo, fios e pedaços soltos) — near_cleanup.py
	_np = os.path.join(OUT, f'eon_{i}_near.png')
	Image.fromarray(near_cleanup.clean(np.asarray(Image.open(_np).convert('RGBA')), i)).save(_np, optimize=True)
	# FLOOR: o chão pintado (abaixo da linha), inteiro.
	save_rgb(os.path.join(OUT, f'eon_{i}_floor.png'), img[fl:])
	# FGCOL: a asa esquerda, quase preta e desfocada (coluna em primeiro plano).
	wl = wing[:, :int(l * 1.25)]
	cols = np.where(wl.max(0) > 0.5)[0]
	x1 = int(cols.max()) + 8 if cols.size else int(l)
	col_a = cv2.GaussianBlur(np.ascontiguousarray(wing[:, :x1]), (0, 0), 6)
	col_rgb = cv2.GaussianBlur(np.ascontiguousarray(above[:, :x1]), (0, 0), 6) * 0.18
	save_rgba(os.path.join(OUT, f'eon_{i}_fgcol.png'), col_rgb, col_a)
	info = {'size': [W, fl], 'floor_h': H - fl, 'wings': [l, r], 'near_y': ny,
		'haze': [float(v) for v in haze], 'sky': [float(v) for v in sky]}
	log(f'eon {i}: far {W}x{fl} chão {H - fl}px névoa {np.round(haze, 2)}')
	return info


def build_generic():
	"""Silhuetas genéricas de primeiro plano (entulho, pilar) do architecture.png."""
	a = np.asarray(Image.open(ARCH).convert('RGB')).astype(np.float32) / 255
	for name, (x, y, w, h) in {'fg_rubble': (5, 564, 530, 409), 'fg_pillar': (85, 0, 325, 545)}.items():
		c = np.ascontiguousarray(a[y:y + h, x:x + w])
		key = np.minimum(c[..., 0], c[..., 2]) - c[..., 1]
		alpha = 1.0 - np.clip((key - 0.2) / 0.28, 0, 1)
		alpha = cv2.erode(alpha, np.ones((3, 3), np.uint8))
		alpha = cv2.GaussianBlur(alpha, (0, 0), 2.5)
		rgb = cv2.GaussianBlur(c, (0, 0), 2.5) * 0.10
		save_rgba(os.path.join(OUT, name + '.png'), rgb, alpha)


def write_lib(data):
	"""Reescreve o bloco GERADO de scenery_library.gd."""
	if not os.path.exists(LIB):
		log('scenery_library.gd ausente: dados não gravados')
		return
	s = open(LIB, encoding='utf-8').read()
	lines = ['## DADOS GERADOS por tools/scenery/build_backgrounds.py — não editar à mão.',
		'## Por Éon: tamanho do far (px), altura do chão pintado, asas (px), início da faixa near (px),',
		'## cor da névoa e do céu (médias da pintura).',
		'const LAYERS := [']
	for d in data:
		lines.append('\t{"size": Vector2(%d, %d), "floor_h": %d, "wings": Vector2(%d, %d), "near_y": %d, "haze": Color(%.3f, %.3f, %.3f), "sky": Color(%.3f, %.3f, %.3f)},' % (
			d['size'][0], d['size'][1], d['floor_h'], d['wings'][0], d['wings'][1], d['near_y'], *d['haze'], *d['sky']))
	lines.append(']')
	s = re.sub(r'# >>> GERADO.*?# <<< GERADO', lambda _m: '# >>> GERADO\n' + '\n'.join(lines) + '\n# <<< GERADO', s, flags=re.S)
	open(LIB, 'w', encoding='utf-8', newline='\n').write(s)


def contact_sheet(n):
	"""Prancha reduzida: far com mid (vermelho) e near (verde) por cima."""
	ims = []
	for i in range(n):
		far = Image.open(os.path.join(OUT, f'eon_{i}_far.png')).convert('RGB')
		w = 480
		hgt = int(far.height * w / far.width)
		base = np.asarray(far.resize((w, hgt))).astype(np.float32)
		for k, tint in (('mid', (255, 60, 60)), ('near', (60, 255, 60))):
			im = Image.open(os.path.join(OUT, f'eon_{i}_{k}.png'))
			full = Image.new('RGBA', far.size)
			full.paste(im, (0, far.height - im.height))
			lay = np.asarray(full.resize((w, hgt))).astype(np.float32)
			a = lay[..., 3:4] / 255
			base = base * (1 - a) + (lay[..., :3] * 0.6 + np.array(tint) * 0.4) * a
		ims.append(Image.fromarray(base.astype(np.uint8)))
	H = max(im.height for im in ims)
	sheet = Image.new('RGB', (480 * 3, H * 3))
	for i, im in enumerate(ims):
		sheet.paste(im, ((i % 3) * 480, (i // 3) * H))
	p = os.path.join(CACHE, 'layers_sheet.png')
	sheet.save(p)
	log('prancha:', p)


if __name__ == '__main__':
	use_ai = '--no-ai' not in sys.argv
	only = None
	if '--only' in sys.argv:
		only = [int(x) for x in sys.argv[sys.argv.index('--only') + 1].split(',')]
	os.makedirs(OUT, exist_ok=True)
	data = []
	for i in range(9):
		if only is not None and i not in only:
			continue
		data.append(build_eon(i, use_ai))
	if only is None:
		build_generic()
		write_lib(data)
		contact_sheet(9)
