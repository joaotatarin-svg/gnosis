# QA7: grade de miniaturas. Uso: python grade.py <saida.png> <colunas> <largura_miniatura> arq1 arq2 ...
import sys, os
from PIL import Image, ImageDraw
out, cols, tw, files = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4:]
th = tw * 9 // 16
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (cols * (tw + 4), rows * (th + 16)), (40, 0, 40))
d = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
	x, y = (i % cols) * (tw + 4), (i // cols) * (th + 16)
	sheet.paste(Image.open(f).convert("RGB").resize((tw, th), Image.LANCZOS), (x, y + 14))
	d.text((x + 2, y + 1), os.path.basename(f)[:60], fill=(255, 255, 0))
sheet.save(out)
print(out, sheet.size, len(files))
