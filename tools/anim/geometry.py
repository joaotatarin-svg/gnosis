"""GEOMETRIA POR QUADRO (Onda 6, PLAYTEST 2: "o cajado atravessa").

Medidas tiradas da SILHUETA de cada quadro (px locais do quadro no atlas),
gravadas no JSON do atlas e expostas pelo CharacterArt.frame_geometry():
  body       [x, y, w, h]  caixa do CORPO (sem cajado/arma fina, fios de cabelo,
                           trapos soltos): abertura morfológica da máscara e o
                           maior componente
  body_poly  [[x,y],...]   contorno convexo simplificado do corpo (≤ 10 pontos)
  staff      [bx,by,tx,ty] eixo do CAJADO da Sophia: do cabo (b) até a ponta
                           de cristal (t). Só quando o quadro tem a ponta medida.
"""
import numpy as np
from scipy import ndimage

try:
	import cv2
except Exception:  # noqa: BLE001
	cv2 = None


def _body_mask(a: np.ndarray, h_ref: float) -> np.ndarray:
	k = max(3, int(round(h_ref * 0.06)))
	op = ndimage.binary_opening(a, structure=np.ones((k, k), bool))
	if not op.any():
		return a
	lab, n = ndimage.label(op)
	if n > 1:
		sizes = ndimage.sum(op, lab, range(1, n + 1))
		big = int(np.argmax(sizes)) + 1
		# corpo = maior pedaço + pedaços grandes encostados (cabeça separada por um pescoço fino)
		keep = [i + 1 for i in range(n) if sizes[i] >= 0.12 * sizes[big - 1]]
		op = np.isin(lab, keep)
	return op


def measure_geometry(rgba: np.ndarray, tip=None) -> dict:
	a = rgba[..., 3] > 128
	if not a.any():
		return {}
	ys, xs = np.nonzero(a)
	h_ref = float(ys.max() - ys.min() + 1)
	body = _body_mask(a, h_ref)
	by, bx = np.nonzero(body)
	# pernas/botas finas somem na abertura: a caixa desce até o pixel mais
	# baixo da silhueta dentro da largura do corpo (pés no chão = hurtbox no chão)
	cols = a[:, bx.min():bx.max() + 1]
	low = int(np.nonzero(cols.any(1))[0].max())
	y1 = max(int(by.max()), low)
	out = {"body": [int(bx.min()), int(by.min()), int(bx.max() - bx.min() + 1), int(y1 - by.min() + 1)]}
	if cv2 is not None:
		cnts, _ = cv2.findContours(body.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
		if cnts:
			pts = np.vstack(cnts).reshape(-1, 2)
			hull = cv2.convexHull(pts.astype(np.int32))
			eps = 0.01 * cv2.arcLength(hull, True)
			poly = cv2.approxPolyDP(hull, eps, True).reshape(-1, 2)
			while len(poly) > 10:
				eps *= 1.4
				poly = cv2.approxPolyDP(hull, eps, True).reshape(-1, 2)
			out["body_poly"] = [[int(p[0]), int(p[1])] for p in poly]
	if tip is not None:
		# cajado = parte FINA da silhueta (fora do corpo engordado) ligada à ponta
		thin = a & ~ndimage.binary_dilation(body, iterations=2)
		near = np.zeros_like(a)
		tx, ty = int(round(tip[0])), int(round(tip[1]))
		r = max(4, int(h_ref * 0.06))
		near[max(0, ty - r):ty + r, max(0, tx - r):tx + r] = True
		lab, n = ndimage.label(ndimage.binary_dilation(thin, iterations=1))
		ids = np.unique(lab[near & (lab > 0)])
		if ids.size:
			comp = np.isin(lab, ids) & a
			py, px = np.nonzero(comp)
			if px.size >= 20:
				P = np.stack([px, py], 1).astype(np.float64)
				c = P.mean(0)
				_, _, vt = np.linalg.svd(P - c, full_matrices=False)
				d = vt[0]
				proj = (P - c) @ d
				e0, e1 = c + d * proj.min(), c + d * proj.max()
				t = np.array([tip[0], tip[1]], np.float64)
				butt = e0 if np.linalg.norm(e0 - t) > np.linalg.norm(e1 - t) else e1
				# só a parte VISÍVEL (o que fica atrás da mão/corpo não acerta nada)
				out["staff"] = [round(float(butt[0]), 2), round(float(butt[1]), 2), round(float(t[0]), 2), round(float(t[1]), 2)]
		if "staff" not in out:
			# cajado cruzando o corpo (não sobra parte fina): estimado da ponta
			# rumo ao centro do corpo, com o comprimento típico (~0,75 da altura)
			cx = float(bx.mean())
			cy = float(by.mean())
			t = np.array([tip[0], tip[1]], np.float64)
			d = np.array([cx, cy]) - t
			nd = np.linalg.norm(d)
			if nd > 1.0:
				butt = t + d / nd * 0.75 * h_ref
				out["staff"] = [round(float(butt[0]), 2), round(float(butt[1]), 2), round(float(t[0]), 2), round(float(t[1]), 2)]
				out["staff_est"] = True
	return out
