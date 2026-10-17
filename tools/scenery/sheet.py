"""Prancha de capturas (cenário). Uso:
  python3 tools/scenery/sheet.py <saida.png> <a.png> [b.png ...]           (grade 2 colunas)
  python3 tools/scenery/sheet.py --pairs <saida.png> <antes_prefixo> <depois_prefixo> <telas...>
O modo --pairs põe ANTES (esq.) e DEPOIS (dir.) lado a lado, uma linha por tela."""
import sys
from PIL import Image, ImageDraw

W = 640


def thumb(p):
    im = Image.open(p).convert("RGB")
    return im.resize((W, int(im.height * W / im.width)), Image.LANCZOS)


def label(im, txt):
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 8 * len(txt) + 10, 16], fill=(0, 0, 0))
    d.text((5, 2), txt, fill=(255, 255, 255))
    return im


def main():
    a = sys.argv[1:]
    if a[0] == "--pairs":
        out, pa, pb, telas = a[1], a[2], a[3], a[4:]
        rows = [(label(thumb(f"{pa}_{t}.png"), f"antes {t}"), label(thumb(f"{pb}_{t}.png"), f"depois {t}")) for t in telas]
        h = rows[0][0].height
        sheet = Image.new("RGB", (W * 2 + 4, (h + 4) * len(rows)), (20, 20, 20))
        for i, (x, y) in enumerate(rows):
            sheet.paste(x, (0, i * (h + 4)))
            sheet.paste(y, (W + 4, i * (h + 4)))
    else:
        out, files = a[0], a[1:]
        ims = [label(thumb(f), f.rsplit("/", 1)[-1]) for f in files]
        h = ims[0].height
        n = (len(ims) + 1) // 2
        sheet = Image.new("RGB", (W * 2 + 4, (h + 4) * n), (20, 20, 20))
        for i, im in enumerate(ims):
            sheet.paste(im, ((i % 2) * (W + 4), (i // 2) * (h + 4)))
    sheet.save(out)


main()
