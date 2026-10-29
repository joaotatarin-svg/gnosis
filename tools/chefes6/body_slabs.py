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
#      [--abrir N] [--fill F]
# --abrir N: antes de medir, ABRE a máscara (erode+dilata com disco de N px) e fica só
# com a maior peça — some com o que é FINO ou SOLTO e não é corpo: fiapos de névoa
# (Athoth), cajado/espelho na ponta do braço e cacos flutuando (Astaphaios). O Rei
# (manto maciço) usa o padrão (sem abrir). --fill F troca o COL_FILL. --bruto G: coluna
# do desenho BRUTO opaca em >= G das linhas da faixa também conta (barra em pontas).
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

N_SLABS = 6
ALPHA = 128          # opaco o bastante (a borda suave do recorte não conta)
COL_FILL = 0.30      # fração mínima de linhas opacas p/ a coluna contar
SHRINK = 3           # px do recorte: folga para dentro de cada lado


def solid_mask(crop: np.ndarray, k: int) -> np.ndarray:
	"""Máscara do corpo MACIÇO: abertura com disco k px + maior componente conexa."""
	if k <= 1:
		return crop
	m = crop.astype(np.uint8)
	ker = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k))
	m = cv2.morphologyEx(m, cv2.MORPH_OPEN, ker)
	n, lab, stats, _ = cv2.connectedComponentsWithStats(m, connectivity=8)
	if n <= 1:
		return m.astype(bool)
	big = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
	return lab == big


def main() -> None:
	global COL_FILL
	root = Path(__file__).resolve().parents[2]
	args = [x for x in sys.argv[1:]]
	opts = {}
	pos = []
	i = 0
	while i < len(args):
		if args[i].startswith("--"):
			opts[args[i][2:]] = args[i + 1]
			i += 2
		else:
			pos.append(args[i])
			i += 1
	char = pos[0] if len(pos) > 0 else "bosses/rei"
	out = Path(pos[1]) if len(pos) > 1 else root / "scripts/entities/bosses/rei_body_data.gd"
	k_open = int(opts.get("abrir", 0))
	raw_fill = float(opts.get("bruto", 0.0))
	if "fill" in opts:
		COL_FILL = float(opts["fill"])
	meta = json.loads((root / f"assets/painted/derived/{char}_frames.json").read_text(encoding="utf-8"))
	atlas = Image.open(root / meta["atlas"].replace("res://", "")).convert("RGBA")
	a = np.asarray(atlas)[:, :, 3]
	slabs: dict = {}
	for name, fr in meta["frames"].items():
		x, y, w, h = fr["rect"]
		raw = a[y:y + h, x:x + w] >= ALPHA
		crop = solid_mask(raw, k_open)
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
			ok = fill >= COL_FILL
			if raw_fill > 0.0:
				# pano DENSO do desenho bruto também conta (barra recortada em pontas,
				# que a abertura apaga): coluna opaca em >= raw_fill das linhas
				ok = ok | (raw[y0:y1].mean(axis=0) >= raw_fill)
			cols = np.nonzero(ok)[0]
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
		"## Coluna conta só se opaca em >= %d %% da faixa; %d px de folga para dentro; abertura %d px." % (int(COL_FILL * 100), SHRINK, k_open),
		"## Gerar de novo: python -I tools/chefes6/body_slabs.py %s <saida.gd>%s" % (char, (" --abrir %d --fill %s --bruto %s" % (k_open, COL_FILL, raw_fill)) if k_open > 0 else ""),
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
