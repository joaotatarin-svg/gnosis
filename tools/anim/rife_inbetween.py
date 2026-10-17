"""IN-BETWEENS da corrida com RIFE (GPU, rife-ncnn-vulkan) — fora do jogo.

Para cada par de quadros vizinhos da sequência `run` do atlas
(assets/painted/derived/sophia_frames.json) monta as duas imagens num quadro
comum com o PÉ APOIADO alinhado (o quadro i+1 entra deslocado pelo avanço do
corpo, `advance[i]`, como no mundo), pinta o fundo de magenta puro, pede o
quadro do meio ao RIFE (2× de resolução pra o fluxo ficar estável) e recorta o
magenta de volta (clean_sheets.key_array). Grava uma folha-fonte
`assets/painted/src/sophia_run_inb.png` (grade 4×2, magenta, ESCALA DO ATLAS)
que a receita junta à corrida (quadros run_m0..m7 intercalados).

Uso: python tools/anim/rife_inbetween.py [modelo=rife-v4.6]
Depois: python tools/anim/build_frames.py
"""
import json
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from clean_sheets import key_array  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DER = os.path.join(ROOT, "assets", "painted", "derived")
RIFE = r"C:\Users\jmtat\gnosis-tools\rife\rife-ncnn-vulkan.exe"
MAGENTA = np.array([255.0, 0.0, 255.0])
CW, CH = 480, 360          # célula da folha de saída (escala do atlas)


def frame_rgba(atlas: np.ndarray, fr: dict) -> np.ndarray:
	x, y, w, h = fr["rect"]
	return atlas[y:y + h, x:x + w].astype(np.float32)


def place(canvas_w: int, canvas_h: int, rgba: np.ndarray, ox: float, oy: float) -> np.ndarray:
	"""Compõe sobre magenta com o canto em (ox, oy) (inteiro)."""
	out = np.zeros((canvas_h, canvas_w, 3), np.float32) + MAGENTA
	h, w = rgba.shape[:2]
	x0, y0 = int(round(ox)), int(round(oy))
	a = rgba[..., 3:4] / 255.0
	region = out[y0:y0 + h, x0:x0 + w]
	region[:] = rgba[..., :3] * a + region * (1.0 - a)
	return out


def main() -> None:
	model = sys.argv[1] if len(sys.argv) > 1 else "rife-v4.6"
	meta = json.load(open(os.path.join(DER, "sophia_frames.json"), encoding="utf-8"))
	atlas = np.asarray(Image.open(os.path.join(DER, "sophia_frames.png")).convert("RGBA"))
	seq = meta["states"]["run"]
	src_frames = [e for e in seq["frames"] if "run_m" not in e["f"]]
	n = len(src_frames)
	# avanço entre os quadros ORIGINAIS (se já houver intercalados, soma os pares)
	adv_all = seq.get("advance", [0.0] * len(seq["frames"]))
	adv = []
	k = 0
	for i, e in enumerate(seq["frames"]):
		if "run_m" in e["f"]:
			adv[-1] += adv_all[i]
		else:
			adv.append(adv_all[i])
	sheet = np.zeros((CH * 2, CW * 4, 3), np.float32) + MAGENTA
	tmp = tempfile.mkdtemp(prefix="rife_")
	anchors = {}
	for i in range(n):
		j = (i + 1) % n
		a, b = src_frames[i], src_frames[j]
		fa, fb = meta["frames"][a["f"]], meta["frames"][b["f"]]
		ra, rb = frame_rgba(atlas, fa), frame_rgba(atlas, fb)
		# âncora (pélvis, pé) em coordenadas da tela comum; b avança adv[i] no mundo
		# — o pé apoiado fica no mesmo lugar, o corpo anda. Na tela comum o
		# mundo é fixo: a está em X0, b em X0 + adv.
		W, H = 900, 420
		X0, GY = 330.0, 380.0
		ax, ay = a["anchor"]
		bx, by = b["anchor"]
		ia = place(W, H, ra, X0 - ax, GY - ay)
		ib = place(W, H, rb, X0 + adv[i] - bx, GY - by)
		p0, p1, pm = (os.path.join(tmp, "%d_%s.png" % (i, t)) for t in "abm")
		Image.fromarray(ia.astype(np.uint8)).resize((W * 2, H * 2), Image.LANCZOS).save(p0)
		Image.fromarray(ib.astype(np.uint8)).resize((W * 2, H * 2), Image.LANCZOS).save(p1)
		subprocess.run([RIFE, "-0", p0, "-1", p1, "-o", pm, "-m", os.path.join(os.path.dirname(RIFE), model)], check=True, capture_output=True)
		mid = np.asarray(Image.open(pm).convert("RGB").resize((W, H), Image.LANCZOS)).astype(np.float32)
		# o meio está com a pélvis em X0 + adv/2: recorta uma célula em volta
		F, al, _ = key_array(mid)
		ys, xs = np.nonzero(al > 0.3)
		cx = int((xs.min() + xs.max()) / 2)
		y1 = int(ys.max())
		x0 = max(0, min(W - CW, cx - CW // 2))
		y0 = max(0, min(H - CH, y1 + 8 - CH))
		cell = mid[y0:y0 + CH, x0:x0 + CW]
		col, row = i % 4, i // 4
		sheet[row * CH:(row + 1) * CH, col * CW:(col + 1) * CW] = cell
		# âncora POR CONSTRUÇÃO: a pélvis do meio fica na metade do avanço
		# (o pé apoiado não se mexe no mundo); em px da folha-fonte
		anchors["run_m%d" % i] = [round(col * CW + X0 + adv[i] / 2.0 - x0, 2), round(row * CH + GY - y0, 2)]
		print("  meio %d (%s -> %s) avanço %.1f" % (i, a["f"], b["f"], adv[i]))
	out = os.path.join(ROOT, "assets", "painted", "src", "sophia_run_inb.png")
	Image.fromarray(sheet.round().clip(0, 255).astype(np.uint8)).save(out)
	with open(out.replace(".png", ".json"), "w", encoding="utf-8") as fp:
		json.dump({"anchors": anchors, "_doc": "âncoras (px da folha) dos intercalados; build_frames usa no lugar da medida"}, fp, indent=1, ensure_ascii=False)
	print("folha de intercalados:", out)


if __name__ == "__main__":
	main()
