"""Detector de emendas verticais de 1 px (bug M5). Para cada coluna mede o quanto
ela destoa das vizinhas (c - (esq+dir)/2) de forma CONSISTENTE ao longo das linhas
(mediana com sinal). Emenda real = valor alto e mesmo sinal em quase toda a altura.
Uso: python3 tools/scenery/seams.py <img.png> [y0 y1] [limiar]"""
import sys
import numpy as np
from PIL import Image


def seams(path, y0=520, y1=700, thr=4.0):
    a = np.asarray(Image.open(path).convert("RGB")).astype(float).mean(2)[y0:y1]
    c = a[:, 1:-1] - (a[:, :-2] + a[:, 2:]) * 0.5
    med = np.median(c, axis=0)
    cons = (np.sign(c) == np.sign(med)[None, :]).mean(0)
    hits = [(int(i) + 1, round(float(med[i]), 1), round(float(cons[i]), 2)) for i in np.where((np.abs(med) >= thr) & (cons > 0.8))[0]]
    return hits


if __name__ == "__main__":
    p = sys.argv[1]
    y0 = int(sys.argv[2]) if len(sys.argv) > 2 else 520
    y1 = int(sys.argv[3]) if len(sys.argv) > 3 else 700
    thr = float(sys.argv[4]) if len(sys.argv) > 4 else 4.0
    h = seams(p, y0, y1, thr)
    print(p, "emendas:", len(h), h[:20])
