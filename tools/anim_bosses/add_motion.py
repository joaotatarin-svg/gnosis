"""FILA 7 — liga as folhas de INTERMEDIÁRIOS DESENHADOS (`<id>_motion_a.png`)
às receitas: copia a folha para artes/gpt, declara `extra_sheets` (escala
normalizada pela pose quase-parada: recover_1 × idle_0) e troca os estados:
  walk    = 6 quadros desenhados pela DISTÂNCIA (contato A, desce A, passagem A,
            sobe A, contato B, passagem B)
  recover = golpe → recover_0 → recover_1 → parado (pelo progresso real)
Padrão A (bots/criaturas): 0 walk_contact_A · 1 walk_down_A · 2 walk_pass_A ·
3 walk_up_A · 4 walk_contact_B · 5 walk_pass_B · 6 recover_0 · 7 recover_1.

Uso: python tools/anim_bosses/add_motion.py bot_sonambulo=bot_1_sonambulo_motion_a ...
"""
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = r"C:\gnosis-wt\_gpt\out"
CELLS_A = ["walk_contact_A", "walk_down_A", "walk_pass_A", "walk_up_A", "walk_contact_B", "walk_pass_B", "recover_0", "recover_1"]

# Padrão B (chefes `boss_<n>_<nome>_motion_a`): andar 4 novos + preparação em 2
# etapas + golpe em 2 etapas (ordem do MANIFESTO FILA 7; --cells sobrescreve).
CELLS_B = ["walk_c0", "walk_p0", "walk_c1", "walk_p1", "windup_0", "windup_1", "strike_0", "strike_1"]
BOSSES = ["athoth", "harmas", "galila", "yabel", "astaphaios", "belias", "armupiel", "colosso", "rei"]


def boss_pattern(R: dict, sheet: str, cells: list) -> None:
	R["extra_sheets"] = [{"sheet": "artes/gpt/%s.png" % sheet, "grid": [4, 2], "cells": cells,
		"scale": "auto", "ref": cells[1], "main_ref": "idle_0"}]
	R["states"]["walk"] = {"frames": cells[:4], "cycle_bodies": 0.9}
	# preparação: sai do parado em 2 etapas e chega à pose desenhada (hold)
	R["states"]["windup"] = {"frames": [cells[4], cells[5], "windup"], "at": [0.0, 0.18, 0.4]}
	# golpe: arranque → pico desenhado → seguimento
	R["states"]["attack"] = {"frames": [cells[6], "strike", cells[7]], "at": [0.0, 0.12, 0.55], "impact_at": [1]}
	R["states"]["recover"] = {"frames": [cells[7], "idle_0"], "at": [0.0, 0.45]}


for arg in [a for a in sys.argv[1:] if not a.startswith("--") and "=" in a]:
	recipe, sheet = arg.split("=")
	shutil.copy(os.path.join(OUT, sheet + ".png"), os.path.join(ROOT, "artes", "gpt", sheet + ".png"))
	p = os.path.join(HERE, "recipes", recipe + ".json")
	R = json.load(open(p, encoding="utf-8"))
	if recipe in BOSSES:
		cells = sys.argv[sys.argv.index("--cells") + 1].split(",") if "--cells" in sys.argv else CELLS_B
		boss_pattern(R, sheet, cells)
		json.dump(R, open(p, "w", encoding="utf-8", newline="\n"), indent=1, ensure_ascii=False)
		print(recipe, "<-", sheet, "(padrão B)")
		continue
	R["extra_sheets"] = [{"sheet": "artes/gpt/%s.png" % sheet, "grid": [4, 2], "cells": CELLS_A,
		"scale": "auto", "ref": "recover_1", "main_ref": "idle_0"}]
	walk = CELLS_A[:6]
	spirit_loop = R.get("kind") == "spirit" and R["states"].get("walk", {}).get("loop", False)
	R["states"]["walk"] = {"frames": walk, "loop": True, "fps": 8.0} if spirit_loop else {"frames": walk, "cycle_bodies": 0.9}
	R["states"]["recover"] = {"frames": ["strike", "recover_0", "recover_1", "idle_0"], "at": [0.0, 0.25, 0.55, 0.85]}
	json.dump(R, open(p, "w", encoding="utf-8", newline="\n"), indent=1, ensure_ascii=False)
	print(recipe, "<-", sheet)
