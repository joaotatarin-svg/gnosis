"""seams.py — QA-VISUAL: procura emendas verticais duras (1-2 px) numa faixa do chão.
Uso: python tools/qa_visual/seams.py <glob_png> [y0 y1]"""
import sys, glob, os
import numpy as np
from PIL import Image
pat = sys.argv[1]
y0, y1 = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (630, 700)
tot = 0; files = sorted(glob.glob(pat))
for f in files:
    a = np.asarray(Image.open(f).convert('L'), dtype=float)[y0:y1, :]
    d = np.abs(np.diff(a, axis=1))
    # emenda = coluna com degrau forte em quase TODAS as linhas da faixa (linha vertical reta)
    frac = (d > 10).mean(axis=0)
    cols = np.where(frac > 0.85)[0]
    if len(cols):
        tot += 1
        print(os.path.basename(f), len(cols), list(cols[:8]))
print('imagens com emenda vertical suspeita: %d de %d' % (tot, len(files)))
