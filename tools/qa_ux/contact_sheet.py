"""QA-UX: monta PRANCHAS de contato a partir dos PNGs da RunProbe.
Uso: python tools/qa_ux/contact_sheet.py <pasta_run> <pasta_saida> [telas_por_prancha=8]
Cada linha = uma tela; colunas = arrive, fight0, fight1, fight2, portal/shop, end (+ bug_*)."""
import sys, os, glob, re
from PIL import Image, ImageDraw, ImageFont

src, dst = sys.argv[1], sys.argv[2]
per = int(sys.argv[3]) if len(sys.argv) > 3 else 8
os.makedirs(dst, exist_ok=True)
W, H = 320, 180
COLS = ["dialog1", "arrive", "fight0", "fight1", "fight2", "shop", "portal", "end"]
try:
    font = ImageFont.truetype("arial.ttf", 14)
except Exception:
    font = ImageFont.load_default()
screens = sorted({int(m.group(1)) for f in glob.glob(os.path.join(src, "s*_*.png"))
                  for m in [re.match(r"s(\d+)_", os.path.basename(f))] if m})
for start in range(0, len(screens), per):
    chunk = screens[start:start + per]
    sheet = Image.new("RGB", (60 + W * len(COLS), 20 + H * len(chunk)), (20, 20, 24))
    d = ImageDraw.Draw(sheet)
    for ci, c in enumerate(COLS):
        d.text((60 + ci * W + 4, 2), c, fill=(230, 210, 140), font=font)
    for ri, s in enumerate(chunk):
        y = 20 + ri * H
        d.text((6, y + 80), "T%02d" % s, fill=(255, 255, 255), font=font)
        for ci, c in enumerate(COLS):
            p = os.path.join(src, "s%02d_%s.png" % (s, c))
            if os.path.exists(p):
                im = Image.open(p).convert("RGB").resize((W, H), Image.BILINEAR)
                sheet.paste(im, (60 + ci * W, y))
        bugs = glob.glob(os.path.join(src, "s%02d_bug_*.png" % s))
        if bugs:
            d.text((6, y + 100), "BUG", fill=(255, 80, 80), font=font)
    out = os.path.join(dst, "prancha_%02d-%02d.png" % (chunk[0], chunk[-1]))
    sheet.save(out)
    print(out)
