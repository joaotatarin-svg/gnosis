"""anim_strip.py — QA-VISUAL: tira de quadros recortados em volta da Sophia/chefe.
Uso: python tools/qa_visual/anim_strip.py <saida.png> <alvo: player|boss> <n_quadros> <box> <prefixo1> [prefixo2 ...]
Lê <prefixo>_meta.json e <prefixo>_NNN.png do Shot (modo seq); uma linha por prefixo."""
import json, sys
from PIL import Image, ImageDraw
out, alvo, n, box = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
rows = []
for pre in sys.argv[5:]:
    meta = json.load(open(pre + "_meta.json"))
    fr = meta["frames"]
    idx = [round(i * (len(fr) - 1) / max(1, n - 1)) for i in range(n)]
    cells = []
    for i in idx:
        f = fr[i]
        im = Image.open("%s_%03d.png" % (pre, f["i"])).convert("RGB")
        if alvo == "boss" and f.get("bosses"):
            b = f["bosses"][0]
            cx, cy = b["pos"] if isinstance(b, dict) and "pos" in b else (b[0], b[1]) if isinstance(b, list) else f["player"]
        else:
            cx, cy = f["player"]
        x0, y0 = int(cx - box / 2), int(cy - box * 0.75)
        c = im.crop((x0, y0, x0 + box, y0 + box))
        d = ImageDraw.Draw(c)
        lab = f["bosses"][0].get("estate", "") if alvo == "boss" and f.get("bosses") else "%s %s" % (f.get("state", ""), f.get("move", ""))
        d.text((4, 2), "%03d %s" % (f["i"], lab), fill=(255, 255, 0))
        cells.append(c)
    rows.append((pre.split("/")[-1].split("\\")[-1], cells))
W = box * n
sheet = Image.new("RGB", (W + 120, box * len(rows)), (20, 20, 24))
d = ImageDraw.Draw(sheet)
for r, (name, cells) in enumerate(rows):
    d.text((4, r * box + 4), name, fill=(255, 255, 255))
    for k, c in enumerate(cells):
        sheet.paste(c, (120 + k * box, r * box))
sheet.save(out)
print(out, sheet.size)
