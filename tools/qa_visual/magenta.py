"""magenta.py — QA-VISUAL: conta pixels "magenta de chroma" (R e B altos, G baixo) em capturas.
Uso: python tools/qa_visual/magenta.py <glob_png> [min_pixels=40]"""
import sys, glob, os
import numpy as np
from PIL import Image
pat = sys.argv[1]; mn = int(sys.argv[2]) if len(sys.argv) > 2 else 40
hits = 0; files = sorted(glob.glob(pat))
for f in files:
    a = np.asarray(Image.open(f).convert('RGB')).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = (r > 200) & (b > 200) & (g < 90)
    n = int(m.sum())
    if n >= mn:
        ys, xs = np.where(m)
        hits += 1
        print(os.path.basename(f), n, 'bbox x=[%d,%d] y=[%d,%d]' % (xs.min(), xs.max(), ys.min(), ys.max()))
print('capturas com magenta: %d de %d' % (hits, len(files)))
