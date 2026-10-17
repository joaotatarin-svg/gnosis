"""QA-UX: grade simples de PNGs com legenda. Uso: python montage.py <saida.png> <colunas> <largura> img1 img2 ..."""
import sys, os
from PIL import Image, ImageDraw, ImageFont
out, cols, w = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
files = sys.argv[4:]
h = w * 9 // 16
try:
    font = ImageFont.truetype("arial.ttf", 13)
except Exception:
    font = ImageFont.load_default()
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (cols * w, rows * (h + 16)), (20, 20, 24))
d = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    x, y = (i % cols) * w, (i // cols) * (h + 16)
    im = Image.open(f).convert("RGB").resize((w, h), Image.BILINEAR)
    sheet.paste(im, (x, y + 16))
    d.text((x + 3, y + 1), os.path.basename(f), fill=(230, 210, 140), font=font)
sheet.save(out)
print(out)
