"""FILA 7 da Sophia — liga S15 (recuperações) e S16 (respiração) à receita
quando as folhas chegam em C:\\gnosis-wt\\_gpt\\out. Só mexe no que existe.

S15 `s15_recover_<v>.png` (2×4): uma volta por ação, na ordem
  rec_light1 · rec_light2 · rec_light3 · rec_heavy · rec_cast · rec_air · rec_dodge · rec_hurt
  → estados rec_* = [s15.rec_X, s3.ready_0] (o CharacterArt toca ao voltar pro parado).
S16 `s16_idle_<v>.png` (2×4): respiração contínua breath_0..7 → estado idle (laço).
Ordem real das células: conferir no MANIFESTO (FILA 7) e passar com --s15-cells/--s16-cells.

Uso: python tools/anim/sophia_motion.py [--s15-cells a,b,...] [--s16-cells ...]
     depois: python tools/anim/build_frames.py
"""
import glob
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = r"C:\gnosis-wt\_gpt\out"
REC = ["rec_light1", "rec_light2", "rec_light3", "rec_heavy", "rec_cast", "rec_air", "rec_dodge", "rec_hurt"]
BREATH = ["breath_%d" % i for i in range(8)]


def arg(name, default):
	if name in sys.argv:
		return sys.argv[sys.argv.index(name) + 1].split(",")
	return default


def pick(prefix):
	c = sorted(glob.glob(os.path.join(OUT, prefix + "_*.png")))
	pref = [x for x in c if x.endswith("_a.png")]
	return (pref or c or [None])[0]


p = os.path.join(HERE, "sophia_recipe.json")
R = json.load(open(p, encoding="utf-8"))
s15 = pick("s15_recover")
if s15:
	dst = "assets/painted/src/sophia_s15.png"
	shutil.copy(s15, os.path.join(ROOT, dst))
	cells = arg("--s15-cells", REC)
	R["sources"]["s15"] = {"file": dst, "grid": [4, 2], "scale": float(arg("--s15-scale", ["1.0"])[0]), "cells": cells}
	for c in cells:
		if c.startswith("rec_"):
			R["states"][c] = {"frames": ["s15." + c, "s3.ready_0"], "dur": [0.16], "anchor": "front"}
	print("S15:", os.path.basename(s15), cells)
s16 = pick("s16_idle")
if s16:
	dst = "assets/painted/src/sophia_s16.png"
	shutil.copy(s16, os.path.join(ROOT, dst))
	cells = arg("--s16-cells", BREATH)
	R["sources"]["s16"] = {"file": dst, "grid": [4, 2], "scale": "auto:" + cells[0], "cells": cells}
	R["states"]["idle"] = {"frames": ["s16." + c for c in cells], "loop": True, "fps": 5.0, "anchor": "front"}
	print("S16:", os.path.basename(s16), cells)
json.dump(R, open(p, "w", encoding="utf-8", newline="\n"), indent=1, ensure_ascii=False)
