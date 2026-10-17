"""Antes × depois por chefe: empilha as pranchas (sem a coluna de ossos)
e amplia o recorte do golpe. Uso: compare_boards.py <antes> <depois> <saida>"""
import os, sys, cv2, numpy as np
a_dir, d_dir, out = sys.argv[1:4]
os.makedirs(out, exist_ok=True)
for f in sorted(os.listdir(d_dir)):
	if not f.startswith("board_"): continue
	a = cv2.imread(os.path.join(a_dir, f)); d = cv2.imread(os.path.join(d_dir, f))
	if a is None or d is None: continue
	a, d = a[:, :1440], d[:, :1440]
	for img, txt in ((a, "ANTES"), (d, "DEPOIS")):
		cv2.putText(img, txt, (1300, 30), 0, 0.8, (80, 220, 255), 2)
	cv2.imwrite(os.path.join(out, "cmp_" + f[6:]), cv2.resize(np.vstack([a, d]), None, fx=0.75, fy=0.75, interpolation=cv2.INTER_AREA))
	# Zoom 2× do pico do golpe (3ª célula).
	za, zd = a[40:480, 720:1080], d[40:480, 720:1080]
	cv2.imwrite(os.path.join(out, "zoom_golpe_" + f[6:]), cv2.resize(np.hstack([za, zd]), None, fx=1.6, fy=1.6, interpolation=cv2.INTER_CUBIC))
print("ok")
