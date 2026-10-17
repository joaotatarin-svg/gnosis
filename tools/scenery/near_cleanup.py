"""Limpeza da faixa NEAR (VFX.md, falta 2). O GrabCut da build_backgrounds.py
às vezes leva para a near pedaços do FUNDO enevoado (arcadas e torres claras no
Silêncio e no Centro, manchas no Corrente) e fios finos soltos. Na near (que anda
a 0,32 da câmera) esses pedaços viram blocos chapados de borda reta.

Regras (por pixel, suaves):
  1. "névoa": região grande e clara (luminância borrada σ=6 acima de T) sai da
     máscara — o entulho de verdade é escuro; brilho pequeno (vela, aresta) sobrevive
     porque o borrão o dilui.
  2. fios: abertura morfológica (elipse 5×5) tira traços de 1–4 px.
  3. pedaço solto: componente que não encosta na base da faixa sai inteiro.
  4. borda: o alfa ganha um desfoque leve (σ=1) e nunca cresce além do original.
O far já tem esse conteúdo por baixo, então o que sai da near continua visível
lá atrás, no ritmo certo.

Uso: python3 tools/scenery/near_cleanup.py [--only 3,7] [--preview saida.png] [--dry]
Roda também no fim da build_backgrounds.py (se ela for rodada de novo)."""
import os
import sys

import cv2
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
BG = os.path.normpath(os.path.join(HERE, '..', '..', 'assets', 'backgrounds'))
# limiar de "névoa" por Éon (luminância borrada); None = não aplica a regra 1.
# Espelho (4) tem cacos claros DE VERDADE e a Fome (1) é toda escura.
BASE = 10   # linhas de baixo que contam como "chão" (regra 4)
# Caixas apagadas à mão (px da near, x0, y0, x1, y1): sobra de névoa colada num
# bloco de verdade, que as regras não separam.
ERASE = {3: [(1020, 0, 1165, 100)]}
HAZE_T = {0: 0.30, 1: None, 2: 0.26, 3: 0.20, 4: None, 5: 0.30, 6: None, 7: 0.24, 8: 0.30}


def smoothstep(e0, e1, x):
	t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def clean(rgba, eon):
	a = rgba.astype(np.float32) / 255.0
	lum = a[..., :3] @ np.array([0.3, 0.59, 0.11], np.float32)
	al = a[..., 3]
	keep = np.ones_like(al)
	t = HAZE_T.get(eon)
	if t is not None:
		# borrão PONDERADO pelo alfa (fora da máscara não puxa a média)
		num = cv2.GaussianBlur(lum * al, (0, 0), 6)
		den = cv2.GaussianBlur(al, (0, 0), 6) + 1e-4
		keep *= 1.0 - smoothstep(t, t + 0.08, num / den)
	for (x0, y0, x1, y1) in ERASE.get(eon, []):
		keep[y0:y1, x0:x1] = 0.0
	k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
	opened = cv2.morphologyEx(al, cv2.MORPH_OPEN, k)
	new = np.minimum(al, opened) * keep
	# 4. só fica o que ASSENTA no chão: pedaço solto no ar (sobra da névoa, fio)
	#    que não encosta nas últimas BASE linhas sai inteiro.
	h = new.shape[0]
	n, lab = cv2.connectedComponents((new > 0.25).astype(np.uint8), connectivity=8)
	grounded = np.zeros(n, bool)
	grounded[np.unique(lab[h - BASE:, :])] = True
	grounded[0] = False
	m = grounded[lab].astype(np.uint8)
	m = cv2.dilate(m, k)                      # conserva a borda macia em volta
	new *= m.astype(np.float32)
	new = np.minimum(cv2.GaussianBlur(new, (0, 0), 1.0), al)
	out = rgba.copy()
	out[..., 3] = np.clip(new * 255.0 + 0.5, 0, 255).astype(np.uint8)
	return out


def main():
	args = sys.argv[1:]
	only = list(range(9))
	preview = None
	dry = '--dry' in args
	if '--only' in args:
		only = [int(x) for x in args[args.index('--only') + 1].split(',')]
	if '--preview' in args:
		preview = args[args.index('--preview') + 1]
	rows = []
	for e in only:
		p = os.path.join(BG, f'eon_{e}_near.png')
		src = np.asarray(Image.open(p).convert('RGBA'))
		dst = clean(src, e)
		before = (src[..., 3] > 127).mean()
		after = (dst[..., 3] > 127).mean()
		print(f'eon {e}: cobertura {before:.3f} -> {after:.3f}')
		if not dry:
			Image.fromarray(dst).save(p, optimize=True)
		if preview:
			for img in (src, dst):
				im = Image.fromarray(img)
				bg = Image.new('RGBA', im.size, (255, 0, 255, 255))
				bg.alpha_composite(im)
				rows.append(bg.convert('RGB').resize((im.size[0] // 2, im.size[1] // 2)))
	if preview and rows:
		w = max(r.size[0] for r in rows)
		sheet = Image.new('RGB', (w, sum(r.size[1] + 3 for r in rows)), (20, 20, 20))
		y = 0
		for r in rows:
			sheet.paste(r, (0, y))
			y += r.size[1] + 3
		sheet.save(preview)


if __name__ == '__main__':
	main()
