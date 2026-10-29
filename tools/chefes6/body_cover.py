# FERRAMENTA (chefes6, 28/10): CAIXA × DESENHO em TODOS os quadros de um chefe.
# Para cada quadro do atlas: cobertura da silhueta pintada (alpha >= 128) pela
# caixa GENÉRICA do Enemy (_fit_hurtbox: metade da largura do recorte em volta
# da pélvis) e pelas FAIXAS do BossBodyBox (tabela do body_slabs.py), e quanto
# de cada caixa cai fora do desenho ("apelão"). Mede só a metade de BAIXO do
# corpo (onde o cajado da Sophia bate no chão) e o corpo inteiro.
# Gera também uma folha PNG: vermelho = genérica, verde = faixas.
# Uso: python -I tools/chefes6/body_cover.py bosses/rei C:/gnosis-wt/_caps/chefes6/rei_quadros
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import body_slabs  # noqa: E402


def slabs_for(char: str, root: Path) -> dict:
	"""Lê a tabela gerada (.gd) do chefe."""
	name = char.split("/")[-1]
	txt = (root / f"scripts/entities/bosses/{name}_body_data.gd").read_text(encoding="utf-8")
	out = {}
	for line in txt.splitlines():
		line = line.strip()
		if line.startswith('"') and '": ' in line:
			k, v = line.split('": ', 1)
			out[k.strip('"')] = json.loads(v.rstrip(","))
	return out


def main() -> None:
	root = Path(__file__).resolve().parents[2]
	char = sys.argv[1] if len(sys.argv) > 1 else "bosses/rei"
	out = sys.argv[2] if len(sys.argv) > 2 else "body_cover"
	meta = json.loads((root / f"assets/painted/derived/{char}_frames.json").read_text(encoding="utf-8"))
	atlas = Image.open(root / meta["atlas"].replace("res://", "")).convert("RGBA")
	a = np.asarray(atlas)[:, :, 3]
	slabs = slabs_for(char, root)
	rows = []
	tiles = []
	for name, fr in sorted(meta["frames"].items()):
		x, y, w, h = fr["rect"]
		drawn = a[y:y + h, x:x + w] >= body_slabs.ALPHA
		top, foot = float(fr.get("top", 0)), float(fr.get("foot_y", h))
		bh = foot - top
		gw = min(max(w * 0.5, bh * 0.3), bh * 1.0)
		cx = float(fr.get("pelvis_x", w * 0.5))
		gen = np.zeros_like(drawn)
		gen[int(top):int(foot), max(0, int(cx - gw / 2)):int(cx + gw / 2)] = True
		new = np.zeros_like(drawn)
		for y0, y1, x0, x1 in slabs.get(name, []):
			new[y0:y1, x0:x1] = True
		low = np.zeros_like(drawn)
		low[int(top + bh * 0.5):int(foot)] = True

		def cov(box, mask):
			d = drawn & mask
			return 100.0 * (box & d).sum() / max(1, d.sum()), 100.0 * (box & ~drawn & mask).sum() / max(1, (box & mask).sum())

		gc, go = cov(gen, low)
		nc, no = cov(new, low)
		gca, goa = cov(gen, np.ones_like(drawn))
		nca, noa = cov(new, np.ones_like(drawn))
		rows.append((name, gc, go, nc, no, gca, goa, nca, noa))
		im = atlas.crop((x, y, x + w, y + h)).convert("RGBA")
		bg = Image.new("RGBA", im.size, (30, 34, 44, 255))
		bg.alpha_composite(im)
		d = ImageDraw.Draw(bg)
		d.rectangle([cx - gw / 2, top, cx + gw / 2, foot], outline=(255, 40, 40), width=3)
		for y0, y1, x0, x1 in slabs.get(name, []):
			d.rectangle([x0, y0, x1, y1], outline=(60, 255, 90), width=2)
		d.text((4, 4), name, fill=(255, 255, 255))
		tiles.append(bg)
	lines = ["quadro | metade de baixo: genérica cobre/fora | faixas cobre/fora || corpo todo: genérica cobre/fora | faixas cobre/fora"]
	for r in rows:
		lines.append("%-12s | %3.0f%% / %2.0f%% | %3.0f%% / %2.0f%% || %3.0f%% / %2.0f%% | %3.0f%% / %2.0f%%" % r)
	m = np.array([r[1:] for r in rows])
	lines.append("MÉDIA        | %3.0f%% / %2.0f%% | %3.0f%% / %2.0f%% || %3.0f%% / %2.0f%% | %3.0f%% / %2.0f%%" % tuple(m.mean(axis=0)))
	lines.append("PIOR (cobre) | %3.0f%%       | %3.0f%%       || %3.0f%%       | %3.0f%%" % (m[:, 0].min(), m[:, 2].min(), m[:, 4].min(), m[:, 6].min()))
	Path(out + ".txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
	print("\n".join(lines))
	# folha 6 por linha, cada quadro reduzido a 200 px de altura
	th = 200
	sm = [t.resize((max(1, int(t.width * th / t.height)), th)) for t in tiles]
	cols = 6
	cw = max(t.width for t in sm)
	sheet = Image.new("RGB", (cw * cols, th * ((len(sm) + cols - 1) // cols)), (20, 20, 26))
	for i, t in enumerate(sm):
		sheet.paste(t.convert("RGB"), ((i % cols) * cw, (i // cols) * th))
	sheet.save(out + ".png")


if __name__ == "__main__":
	main()
