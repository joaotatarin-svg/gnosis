# FERRAMENTA (chefes6, 28/10): CAIXA × DESENHO em TODOS os quadros de um chefe.
# Para cada quadro do atlas: cobertura da silhueta pintada (alpha >= 128) pela
# caixa GENÉRICA do Enemy (_fit_hurtbox: metade da largura do recorte em volta
# da pélvis) e pelas FAIXAS do BossBodyBox (tabela do body_slabs.py), e quanto
# de cada caixa cai fora do desenho ("apelão"). Mede só a metade de BAIXO do
# corpo (onde o cajado da Sophia bate no chão) e o corpo inteiro.
# Gera também uma folha PNG: vermelho = ½ recorte, azul = contorno (Polimento7), verde = faixas.
# Uso: python -I tools/chefes6/body_cover.py bosses/rei C:/gnosis-wt/_caps/chefes6/rei_quadros
import json
import sys
from pathlib import Path

import cv2
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
	# --abrir N: "cobre" mede o CORPO MACIÇO (mesma abertura do body_slabs: sem fiapos,
	# cajado, cacos soltos); "fora" continua contra o desenho bruto (alpha).
	k_open = int(sys.argv[sys.argv.index("--abrir") + 1]) if "--abrir" in sys.argv else 0
	# --mundo K: px de mundo por px do recorte (faixa do cajado = 62 px de mundo = 1 Sophia)
	k_w = float(sys.argv[sys.argv.index("--mundo") + 1]) if "--mundo" in sys.argv else 0.35
	gaps = []
	meta = json.loads((root / f"assets/painted/derived/{char}_frames.json").read_text(encoding="utf-8"))
	atlas = Image.open(root / meta["atlas"].replace("res://", "")).convert("RGBA")
	a = np.asarray(atlas)[:, :, 3]
	slabs = slabs_for(char, root)
	rows = []
	tiles = []
	big = []                  # 4 quadros-chave em tamanho cheio (folha de prova)
	for name, fr in sorted(meta["frames"].items()):
		x, y, w, h = fr["rect"]
		drawn = a[y:y + h, x:x + w] >= body_slabs.ALPHA
		solid = body_slabs.solid_mask(drawn, k_open)
		top, foot = float(fr.get("top", 0)), float(fr.get("foot_y", h))
		bh = foot - top
		gw = min(max(w * 0.5, bh * 0.3), bh * 1.0)
		cx = float(fr.get("pelvis_x", w * 0.5))
		gen = np.zeros_like(drawn)
		gen[int(top):int(foot), max(0, int(cx - gw / 2)):int(cx + gw / 2)] = True
		# CONTORNO do Polimento7 (enemy._fit_hurt_poly, 2854fc0): casco convexo de
		# body_poly + os 2 cantos de baixo de body, 90 % da largura, topo a 92 % dos pés
		con = np.zeros_like(drawn)
		cpts = None
		if "body_poly" in fr and "body" in fr:
			bx, by, bw, bh2 = fr["body"]
			pts = np.array(list(fr["body_poly"]) + [[bx, by + bh2], [bx + bw, by + bh2]], dtype=np.float64)
			lx0, ly0 = pts.min(axis=0)
			lx1, ly1 = pts.max(axis=0)
			ccx = (lx0 + lx1) * 0.5
			ctop = ly1 - (ly1 - ly0) * 0.92
			pts[:, 0] = ccx + (pts[:, 0] - ccx) * 0.9
			pts[:, 1] = np.maximum(pts[:, 1], ctop)
			cpts = cv2.convexHull(pts.astype(np.float32)).reshape(-1, 2)
			m8 = np.zeros(drawn.shape, np.uint8)
			cv2.fillConvexPoly(m8, np.round(cpts).astype(np.int32), 1)
			con = m8.astype(bool)
		new = np.zeros_like(drawn)
		for y0, y1, x0, x1 in slabs.get(name, []):
			new[y0:y1, x0:x1] = True
		low = np.zeros_like(drawn)
		low[int(top + bh * 0.5):int(foot)] = True

		def cov(box, mask):
			d = solid & mask
			return 100.0 * (box & d).sum() / max(1, d.sum()), 100.0 * (box & ~drawn & mask).sum() / max(1, (box & mask).sum())

		def gap(box):
			"""Faixa do cajado (pés → 1 Sophia), por linha: pano BRUTO fora da caixa e sobra."""
			g = o = 0.0
			n = 0
			for yy in range(max(0, int(foot - 62.0 / k_w)), int(foot) - 2):
				xs = np.nonzero(drawn[yy])[0]
				if xs.size == 0:
					continue
				xl, xr = xs.min(), xs.max()
				bs = np.nonzero(box[yy])[0]
				n += 1
				if bs.size == 0:
					g += xr - xl
					continue
				hl, hr = bs.min(), bs.max()
				g += max(0, hl - xl) + max(0, xr - hr)
				o += max(0, xl - hl) + max(0, hr - xr)
			return g / max(1, n) * k_w, o / max(1, n) * k_w

		gaps.append(gap(gen) + gap(con) + gap(new))
		gc, go = cov(gen, low)
		nc, no = cov(new, low)
		cc, co = cov(con, low)
		gca, goa = cov(gen, np.ones_like(drawn))
		nca, noa = cov(new, np.ones_like(drawn))
		rows.append((name, gc, go, cc, co, nc, no, gca, goa, nca, noa))
		im = atlas.crop((x, y, x + w, y + h)).convert("RGBA")
		bg = Image.new("RGBA", im.size, (30, 34, 44, 255))
		bg.alpha_composite(im)
		d = ImageDraw.Draw(bg)
		d.rectangle([cx - gw / 2, top, cx + gw / 2, foot], outline=(255, 40, 40), width=3)
		if cpts is not None:
			d.polygon([tuple(q) for q in cpts.tolist()], outline=(80, 200, 255), width=3)
		for y0, y1, x0, x1 in slabs.get(name, []):
			d.rectangle([x0, y0, x1, y1], outline=(60, 255, 90), width=2)
		d.text((4, 4), name, fill=(255, 255, 255))
		tiles.append(bg)
		if name in ("idle_0", "walk_p0", "strike_1", "hurt"):
			big.append(bg)
	lines = ["quadro | metade de baixo (cobre/fora): ½ recorte (prévia 3) | contorno (Polimento7) | FAIXAS || corpo todo: ½ recorte | FAIXAS"]
	for r in rows:
		lines.append("%-16s | %3.0f%% / %2.0f%% | %3.0f%% / %2.0f%% | %3.0f%% / %2.0f%% || %3.0f%% / %2.0f%% | %3.0f%% / %2.0f%%" % r)
	m = np.array([r[1:] for r in rows])
	lines.append("MÉDIA            | %3.0f%% / %2.0f%% | %3.0f%% / %2.0f%% | %3.0f%% / %2.0f%% || %3.0f%% / %2.0f%% | %3.0f%% / %2.0f%%" % tuple(m.mean(axis=0)))
	lines.append("PIOR (cobre)     | %3.0f%%       | %3.0f%%       | %3.0f%%       || %3.0f%%       | %3.0f%%" % (m[:, 0].min(), m[:, 2].min(), m[:, 4].min(), m[:, 6].min(), m[:, 8].min()))
	gm = np.array(gaps).mean(axis=0)
	gx = np.array(gaps).max(axis=0)
	lines.append("FAIXA DO CAJADO (px de mundo/linha, pano fora / sobra): ½ recorte %.1f / %.1f | contorno %.1f / %.1f | FAIXAS %.1f / %.1f" % tuple(gm))
	lines.append("FAIXA pior quadro (pano fora): ½ recorte %.1f | contorno %.1f | FAIXAS %.1f" % (gx[0], gx[2], gx[4]))
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
	if big:
		bh3 = max(t.height for t in big)
		key = Image.new("RGB", (sum(t.width for t in big), bh3), (20, 20, 26))
		xx = 0
		for t in big:
			key.paste(t.convert("RGB"), (xx, 0))
			xx += t.width
		key.save(out + "_chave.png")


if __name__ == "__main__":
	main()
