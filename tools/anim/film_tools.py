"""Utilitários de filmagem do AnimQA (fora do jogo).

  python tools/anim/film_tools.py gif   <pasta_png> <saida.gif> [largura=640] [fps=30]
  python tools/anim/film_tools.py sheet <pasta_png> <saida.png> [passo=3] [colunas=8] [largura_celula=200] [ini=0] [fim=-1] [crop=x0,y0,x1,y1]
A pasta vem do `--write-movie <pasta>/f.png` do Godot (f00000000.png ...).
"""
import glob
import os
import subprocess
import sys

from PIL import Image


def frames(d):
	return sorted(glob.glob(os.path.join(d, "*.png")))


def gif(d, out, width=640, fps=30):
	pattern = os.path.join(d, "f%08d.png")
	vf = "fps=%d,scale=%d:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=160[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" % (fps, width)
	subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "30", "-i", pattern, "-vf", vf, out], check=True)
	print("gif:", out, os.path.getsize(out) // 1024, "KB")


def sheet(d, out, step=3, cols=8, cw=200, a=0, b=-1, crop=None):
	fs = frames(d)[a:(b if b > 0 else None):step]
	if not fs:
		print("sem quadros")
		return
	im0 = Image.open(fs[0])
	if crop:
		im0 = im0.crop(crop)
	ch = int(cw * im0.height / im0.width)
	rows = (len(fs) + cols - 1) // cols
	S = Image.new("RGB", (cols * cw, rows * ch), (0, 0, 0))
	for i, f in enumerate(fs):
		im = Image.open(f).convert("RGB")
		if crop:
			im = im.crop(crop)
		S.paste(im.resize((cw, ch), Image.LANCZOS), ((i % cols) * cw, (i // cols) * ch))
	S.save(out)
	print("folha:", out, S.size, len(fs), "quadros")


if __name__ == "__main__":
	cmd = sys.argv[1]
	if cmd == "gif":
		gif(sys.argv[2], sys.argv[3], *(int(x) for x in sys.argv[4:6]))
	else:
		extra = [int(x) for x in sys.argv[4:9]]
		crop = None
		if len(sys.argv) > 9:
			crop = tuple(int(v) for v in sys.argv[9].split(","))
		sheet(sys.argv[2], sys.argv[3], *extra, crop=crop)
