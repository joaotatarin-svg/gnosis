# FERRAMENTA (chefes6, 28/10): FAIXAS DO CORPO DESENHADO de um chefe com quadros.
# Playtest do João: "a Sophia atravessa o MANTO do Rei; só o centro é atingível".
# A caixa genérica (enemy._fit_hurtbox) usa metade da largura do recorte em
# volta da pélvis — o manto largo do Rei fica de fora. Aqui medimos, por QUADRO,
# a silhueta pintada em N faixas horizontais (do topo ao pé). Em cada faixa, uma
# coluna só conta como "corpo" se estiver opaca em >= COL_FILL das linhas da
# faixa — franjas finas, pontas de pano e a mão estendida NÃO entram (sem apelão).
# Saída: um .gd com `const SLABS := {quadro: [[y0, y1, x0, x1], ...]}` em px do
# RECORTE do quadro (o BossBodyBox subtrai a âncora e aplica o transform do Visual).
# Uso: python -I tools/chefes6/body_slabs.py bosses/rei scripts/entities/bosses/rei_body_data.gd
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

N_SLABS = 6
ALPHA = 128          # opaco o bastante (a borda suave do recorte não conta)
COL_FILL = 0.30      # fração mínima de linhas opacas p/ a coluna contar
SHRINK = 3           # px do recorte: folga para dentro de cada lado


def main() -> None:
	root = Path(__file__).resolve().parents[2]
	char = sys.argv[1] if len(sys.argv) > 1 else "bosses/rei"
	out = Path(sys.argv[2]) if len(sys.argv) > 2 else root / "scripts/entities/bosses/rei_body_data.gd"
	meta = json.loads((root / f"assets/painted/derived/{char}_frames.json").read_text(encoding="utf-8"))
	atlas = Image.open(root / meta["atlas"].replace("res://", "")).convert("RGBA")
	a = np.asarray(atlas)[:, :, 3]
	slabs: dict = {}
	for name, fr in meta["frames"].items():
		x, y, w, h = fr["rect"]
		crop = a[y:y + h, x:x + w] >= ALPHA
		top = int(round(fr.get("top", 0)))
		foot = int(round(fr.get("foot_y", h)))
		foot = min(foot, h)
		rows = []
		edges = np.linspace(top, foot, N_SLABS + 1)
		for i in range(N_SLABS):
			y0, y1 = int(edges[i]), max(int(edges[i + 1]), int(edges[i]) + 1)
			band = crop[y0:y1]
			if band.size == 0:
				continue
			fill = band.mean(axis=0)
			cols = np.nonzero(fill >= COL_FILL)[0]
			if cols.size == 0:
				continue
			x0 = int(cols.min()) + SHRINK
			x1 = int(cols.max()) + 1 - SHRINK
			if x1 - x0 < 4:
				continue
			rows.append([y0, y1, x0, x1])
		slabs[name] = rows
	lines = [
		"extends RefCounted",
		"## GERADO por tools/chefes6/body_slabs.py (não editar à mão) — %s." % char,
		"## Faixas do corpo DESENHADO por quadro: [y0, y1, x0, x1] em px do recorte.",
		"## Coluna conta só se opaca em >= %d %% da faixa; %d px de folga para dentro." % (int(COL_FILL * 100), SHRINK),
		"",
		"const SLABS := {",
	]
	for name in sorted(slabs):
		lines.append('\t"%s": %s,' % (name, json.dumps(slabs[name])))
	lines.append("}")
	out.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
	print("ok", out, len(slabs), "quadros")


if __name__ == "__main__":
	main()
