"""R18 (NEURO_SATISFACAO): a Sophia "salta" do fundo? Mede, num par de capturas
com/sem a Sophia (HdShot ... seq=2 every=1 blink), o contraste de luminância na
borda da silhueta: para cada pixel da borda, luminância média 3 px para dentro
× 3 px para fora (razão WCAG (L1+0,05)/(L2+0,05)). Reporta mediana e % ≥ 3:1,
mais a saturação média do fundo em volta × a da Sophia.
Uso: python tools/cenario7/contrast.py <prefixo_seq> [<prefixo_seq> ...]"""
import sys
import numpy as np, cv2
from PIL import Image


def rel_lum(rgb):
	c = rgb / 255.0
	c = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
	return c @ np.array([0.2126, 0.7152, 0.0722])


def measure(prefix):
	a = np.asarray(Image.open(prefix + '_000.png').convert('RGB')).astype(np.float32)
	b = np.asarray(Image.open(prefix + '_001.png').convert('RGB')).astype(np.float32)
	d = np.abs(a - b).max(2)
	m = (d > 24).astype(np.uint8)
	m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
	n, lab, st, _ = cv2.connectedComponentsWithStats(m, 8)
	if n < 2:
		return None
	k = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
	m = (lab == k).astype(np.uint8)
	with_s = a if (a[m > 0].std() > 0) and a[m > 0].mean() != b[m > 0].mean() else a
	# qual dos dois tem a Sophia: o que difere mais da vizinhança imediata não importa —
	# o fundo é o mesmo fora da máscara; escolhe o que tem mais borda dentro dela
	ea = cv2.Laplacian(cv2.cvtColor(a.astype(np.uint8), cv2.COLOR_RGB2GRAY), cv2.CV_32F)
	eb = cv2.Laplacian(cv2.cvtColor(b.astype(np.uint8), cv2.COLOR_RGB2GRAY), cv2.CV_32F)
	sop, bg = (a, b) if np.abs(ea[m > 0]).mean() > np.abs(eb[m > 0]).mean() else (b, a)
	L_s = rel_lum(sop)
	L_b = rel_lum(bg)
	inner = cv2.erode(m, np.ones((7, 7), np.uint8))
	outer = cv2.dilate(m, np.ones((7, 7), np.uint8)) - m
	ring_in = (m - inner) > 0
	# por pixel de borda: médias locais (janela 7) dentro × fora
	ker = np.ones((9, 9), np.float32)
	si = cv2.filter2D(L_s * (inner > 0), -1, ker) / np.maximum(cv2.filter2D((inner > 0).astype(np.float32), -1, ker), 1e-3)
	so = cv2.filter2D(L_b * (outer > 0), -1, ker) / np.maximum(cv2.filter2D((outer > 0).astype(np.float32), -1, ker), 1e-3)
	r1, r2 = si[ring_in], so[ring_in]
	ratio = (np.maximum(r1, r2) + 0.05) / (np.minimum(r1, r2) + 0.05)
	hsv_s = cv2.cvtColor(sop.astype(np.uint8), cv2.COLOR_RGB2HSV)[..., 1][m > 0].mean() / 255
	big_ring = (cv2.dilate(m, np.ones((61, 61), np.uint8)) - m) > 0
	hsv_b = cv2.cvtColor(bg.astype(np.uint8), cv2.COLOR_RGB2HSV)[..., 1][big_ring].mean() / 255
	return {'px': int(m.sum()), 'med': float(np.median(ratio)), 'ge3': float((ratio >= 3).mean() * 100),
		'Ls': float(L_s[m > 0].mean()), 'Lbg': float(L_b[big_ring].mean()), 'sat_s': float(hsv_s), 'sat_bg': float(hsv_b)}


if __name__ == '__main__':
	for p in sys.argv[1:]:
		r = measure(p)
		if r is None:
			print(p, 'sem máscara')
			continue
		print('%s: borda mediana %.2f:1, %.0f%% da borda >= 3:1 | lum Sophia %.3f fundo %.3f | sat Sophia %.2f fundo %.2f (%d px)' % (
			p, r['med'], r['ge3'], r['Ls'], r['Lbg'], r['sat_s'], r['sat_bg'], r['px']))
