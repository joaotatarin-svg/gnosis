# QA7 UI: prancha PT | EN lado a lado. Uso: python prancha.py <saida.png> <raw_dir> nome1 nome2 ...
import sys, os
from PIL import Image, ImageDraw
out, raw, names = sys.argv[1], sys.argv[2], sys.argv[3:]
W, H = 640, 360
rows = []
for n in names:
	row = Image.new("RGB", (W * 2 + 10, H + 18), (40, 0, 40))
	d = ImageDraw.Draw(row)
	for i, l in enumerate(["pt_BR", "en"]):
		p = os.path.join(raw, f"{l}_{n}.png")
		if os.path.exists(p):
			im = Image.open(p).convert("RGB").resize((W, H), Image.LANCZOS)
			row.paste(im, (i * (W + 10), 18))
		d.text((i * (W + 10) + 4, 3), f"{l} {n}", fill=(255, 255, 0))
	rows.append(row)
sheet = Image.new("RGB", (W * 2 + 10, len(rows) * (H + 18)), (0, 0, 0))
for i, r in enumerate(rows):
	sheet.paste(r, (0, i * (H + 18)))
sheet.save(out)
print(out, sheet.size)
