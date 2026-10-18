"""Monta uma PRANCHA (várias faixas de layout, uma por tela) num PNG só.
Uso: python prancha.py saida.png escala largura faixa1.png|rotulo faixa2.png|rotulo ...
Cada faixa (saída do Board.tscn) é reduzida por `escala`, quebrada em linhas
de `largura` px e empilhada com rótulo."""
import sys
from PIL import Image, ImageDraw

out, scale, width = sys.argv[1], float(sys.argv[2]), int(sys.argv[3])
rows = []
for arg in sys.argv[4:]:
    path, _, label = arg.partition("|")
    im = Image.open(path).convert("RGB")
    im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
    chunks = [im.crop((x, 0, min(x + width, im.width), im.height)) for x in range(0, im.width, width)]
    rows.append((chunks, label or path.split("/")[-1]))
h = sum(len(c) * (c[0].height + 2) + 18 for c, _ in rows)
board = Image.new("RGB", (width, h), (12, 12, 16))
d = ImageDraw.Draw(board)
y = 0
for chunks, label in rows:
    d.text((6, y + 3), label, fill=(240, 220, 150))
    y += 18
    for ch in chunks:
        board.paste(ch, (0, y))
        y += ch.height + 2
board.save(out)
print("prancha:", out, board.size)
