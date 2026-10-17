"""QA-VISUAL 2: converte PNG em JPEG reduzido (<= limite KB), baixando qualidade/largura até caber.
Uso: python tools/qa_visual/to_jpg.py <entrada.png> <saida.jpg> [largura_max=1280] [kb_max=300]"""
import sys, io
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
wmax = int(sys.argv[3]) if len(sys.argv) > 3 else 1280
kb = int(sys.argv[4]) if len(sys.argv) > 4 else 300
im = Image.open(src).convert("RGB")
w = min(wmax, im.width)
while True:
    r = im.resize((w, int(im.height * w / im.width)), Image.LANCZOS) if w != im.width else im
    for q in (85, 78, 70, 62, 55):
        b = io.BytesIO(); r.save(b, "JPEG", quality=q, optimize=True)
        if b.tell() <= kb * 1024:
            open(dst, "wb").write(b.getvalue()); print(dst, r.size, q, b.tell() // 1024, "KB"); sys.exit(0)
    w = int(w * 0.85)
