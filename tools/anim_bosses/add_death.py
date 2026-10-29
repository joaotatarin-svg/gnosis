"""FILA 10: MORTE DE CHEFE EM 4 ETAPAS (folhas boss_<n>_<nome>_death_a.png, 2x2:
0 stagger_0 · 1 stagger_1 · 2 kneel · 3 collapse). Acrescenta a folha como
`extra_sheets` na receita do chefe e o estado `dying` (o CharacterArt toca as 4
pelo relógio da morte encenada — play_boss_death — antes do estilhaço).
Escala: `auto` comparando o 1º tranco com o quadro `hurt` da folha principal.
Uso: python tools/anim_bosses/add_death.py  (depois boss_frames.py <nome> --no-rife)"""
import glob
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BOSSES = ["athoth", "harmas", "galila", "yabel", "astaphaios", "belias", "armupiel", "colosso", "rei"]
CELLS = ["d_stagger0", "d_stagger1", "d_kneel", "d_collapse"]
done = []
for name in BOSSES:
	cands = sorted(glob.glob(os.path.join(ROOT, "artes", "gpt", "boss_*_%s_death_a.png" % name)))
	if not cands:
		continue
	p = os.path.join(HERE, "recipes", name + ".json")
	R = json.load(open(p, encoding="utf-8-sig"))
	sheet = "artes/gpt/" + os.path.basename(cands[0])
	ex = [e for e in R.get("extra_sheets", []) if not e.get("cells", [""])[0].startswith("d_")]
	ex.append({"sheet": sheet, "grid": [2, 2], "cells": CELLS, "scale": "auto", "ref": "d_stagger0", "main_ref": "hurt"})
	R["extra_sheets"] = ex
	an = R.setdefault("anchors", {})
	an["d_collapse"] = "lying"
	# tranco → cambaleio → joelhos → tombado (s por quadro; o último segura até o estilhaço)
	R["states"]["dying"] = {"frames": CELLS, "dur": [0.17, 0.17, 0.28]}
	json.dump(R, open(p, "w", encoding="utf-8", newline="\n"), indent=1, ensure_ascii=False)
	done.append(name)
print(" ".join(done))
