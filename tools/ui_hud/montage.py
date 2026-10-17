"""Prancha de capturas (ferramenta do agente ui-hud).
Uso: python3 -I tools/ui_hud/montage.py <saida.png> <a.png> [b.png ...]
Cada captura vira 640x360 (base do jogo), 2 colunas, nome embaixo."""
import sys
from PIL import Image, ImageDraw

out, files = sys.argv[1], sys.argv[2:]
W, H, LBL = 640, 360, 16
cols = 2
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (W * cols, (H + LBL) * rows), (20, 20, 20))
d = ImageDraw.Draw(sheet)
for k, f in enumerate(files):
    im = Image.open(f).convert("RGB").resize((W, H), Image.LANCZOS)
    x, y = (k % cols) * W, (k // cols) * (H + LBL)
    sheet.paste(im, (x, y))
    d.text((x + 4, y + H + 2), f.split("/")[-1], fill=(230, 220, 190))
sheet.save(out)
