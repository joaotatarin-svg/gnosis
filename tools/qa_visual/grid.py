"""QA-VISUAL 2: monta uma grade de PNGs com rótulo. Uso:
python tools/qa_visual/grid.py <saida.png|.jpg> <colunas> <largura_célula> <img1> [img2 ...]"""
import sys, os
from PIL import Image, ImageDraw, ImageFont
out, cols, cw = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
files = sys.argv[4:]
ims = [Image.open(f).convert("RGB") for f in files]
ch = int(cw * ims[0].height / ims[0].width)
rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (cols * cw, rows * (ch + 16)), (16, 16, 20))
d = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("arial.ttf", 12)
except Exception:
    font = ImageFont.load_default()
for i, (f, im) in enumerate(zip(files, ims)):
    x, y = (i % cols) * cw, (i // cols) * (ch + 16)
    sheet.paste(im.resize((cw, ch), Image.LANCZOS), (x, y + 16))
    d.text((x + 3, y + 1), os.path.basename(f)[:60], fill=(240, 220, 150), font=font)
if out.lower().endswith(".jpg"):
    sheet.save(out, quality=82)
else:
    sheet.save(out)
print(out, sheet.size)
