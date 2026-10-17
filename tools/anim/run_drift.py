"""Mede a DERIVA DO PÉ APOIADO na corrida (fora do jogo), a partir do JSON
do atlas: na troca do quadro i → i+1 o corpo avançou `advance[i]`; o pé
apoiado (bota mais baixa) deveria cair no MESMO ponto do mundo.
  deriva_i = (pé_i − âncora_i) − advance_i − (pé_{i+1} − âncora_{i+1})
(pares em que o quadro seguinte é um novo apoio — "steps" — ficam de fora:
ali o pé de apoio troca). Também informa o deslizamento DENTRO de cada quadro
(= o avanço enquanto o quadro está na tela), que só some com mais quadros.
Valores em px do MUNDO (Sophia com 46×1,19 px de altura) e px de TELA (×2 em 1280×720).

Uso: python tools/anim/run_drift.py [estado=rund]
"""
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
meta = json.load(open(os.path.join(ROOT, "assets", "painted", "derived", "sophia_frames.json"), encoding="utf-8"))
name = sys.argv[1] if len(sys.argv) > 1 else "rund"
st = meta["states"][name]
k = 46.0 * 1.19 / meta["body_px"]
fr = [meta["frames"][e["f"]] for e in st["frames"]]
ax = [float(e["anchor"][0]) for e in st["frames"]]   # x=0 do nó em cada quadro
adv = st["advance"]
# troca do pé de apoio: quadros de novo apoio (steps) e, nos intercalados, o
# meio que já traz o outro pé descendo (support_change)
steps = set(int(s) for s in st.get("steps", [])) | set(int(s) for s in st.get("support_change", []))
n = len(fr)
worst = 0.0
sup = st.get("support", {})
print("%s: %d quadros, ciclo %.1f px de mundo" % (name, n, sum(adv) * k))
for i in range(n):
	j = (i + 1) % n
	slide = adv[i] * k
	if j in steps:
		print("  %2d->%-2d  troca de apoio           desliza no quadro %.1f px" % (i, j, slide))
		continue
	# pé de apoio de cada quadro (bota mais baixa ou o `support` da receita)
	ki = {"rear": "rear_x", "front": "front_x"}.get(sup.get(st["frames"][i]["f"]), "low_x")
	kj = {"rear": "rear_x", "front": "front_x"}.get(sup.get(st["frames"][j]["f"]), "low_x")
	d = ((fr[i][ki] - ax[i]) - adv[i] - (fr[j][kj] - ax[j])) * k
	worst = max(worst, abs(d))
	print("  %2d->%-2d  deriva na troca %+5.2f px  desliza no quadro %.1f px" % (i, j, d, slide))
print("PIOR deriva na troca: %.2f px de mundo (%.2f px de tela)" % (worst, worst * 2))
