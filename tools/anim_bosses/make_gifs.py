"""Corta os quadros do PuppetQA (modo seq, grade 4×3 de 400×300) em um GIF por boneco.
Uso: python make_gifs.py <pasta_quadros> <pasta_gifs> [fps]"""
import os, sys, subprocess
NAMES = ["athoth","harmas","galila","yabel","astaphaios","belias","armupiel","colosso","rei","glutao_criatura","pretoriano_criatura"]
src, out = sys.argv[1], sys.argv[2]
fps = sys.argv[3] if len(sys.argv) > 3 else "30"
os.makedirs(out, exist_ok=True)
for i, name in enumerate(NAMES):
	x, y = (i % 4) * 400, (i // 4) * 300
	gif = os.path.join(out, name + ".gif")
	vf = f"crop=400:300:{x}:{y},split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4"
	subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", fps, "-i", os.path.join(src, "f_%04d.png"), "-vf", vf, gif], check=True)
	print(name, os.path.getsize(gif) // 1024, "KB")
