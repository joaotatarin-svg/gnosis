"""Polimento 7 (R10/R18): luminância média de cada atlas pintado (corpo, alfa > 0,5)
e o fator do flash aditivo por atlas para EnemyFlashLayer.LUMA_K.

Flash aditivo soma a mesma quantidade em toda a pintura: numa pintura CLARA
(Astaphaios, Rei, Soter) o pico estoura o corpo em branco (risco R10, área grande
de chefe); numa ESCURA (conjurador, cornudo) quase não aparece (R1/R18). O fator
normaliza: k = clamp((1 - L) / (1 - L_REF), 0,55, 1,25), com L_REF = média dos atlas.

Uso (headless, sem janela): python -I tools/combate/flash_luma.py  → cola a tabela no GDScript.
"""
import glob
import os
import sys

import numpy as np
from PIL import Image

L_REF = 0.35
W = np.array([0.2126, 0.7152, 0.0722])


def luma(path: str) -> float:
    im = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
    v = im[..., :3][im[..., 3] > 0.5]
    return float((v @ W).mean()) if len(v) else -1.0


def main() -> None:
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    pats = ["assets/painted/derived/creatures/*_frames.png", "assets/painted/derived/bosses/*_frames.png",
            "assets/painted/derived/npcs/*_frames.png"]
    rows = []
    for p in pats:
        for f in sorted(glob.glob(os.path.join(root, p))):
            l = luma(f)
            k = min(1.25, max(0.55, (1.0 - l) / (1.0 - L_REF)))
            rows.append((os.path.basename(f), l, k))
    print("const LUMA_K := {")
    for n, l, k in rows:
        print('\t"%s": %.2f,   # L %.3f' % (n, k, l))
    print("}")


if __name__ == "__main__":
    main()
