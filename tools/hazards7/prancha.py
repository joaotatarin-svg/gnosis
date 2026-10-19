"""Monta as pranchas ANTES (código) x DEPOIS (pintura) de cada perigo a partir
das capturas de tools/hazards7/boards.sh. Uso: python prancha.py [pasta_raw] [saida]"""
import os
import sys
from collections import defaultdict

from PIL import Image, ImageDraw

RAW = sys.argv[1] if len(sys.argv) > 1 else "C:/gnosis-wt/_caps/perigos7/raw"
OUT = sys.argv[2] if len(sys.argv) > 2 else "C:/gnosis-wt/_caps/perigos7"
TW, TH = 640, 360

shots = defaultdict(lambda: defaultdict(dict))
for f in sorted(os.listdir(RAW), key=lambda n: os.path.getmtime(os.path.join(RAW, n))):
	if not f.endswith(".png") or "_seq_" in f:
		continue
	kind, tag, state = f[:-4].split("_", 2)
	shots[kind][tag][state] = os.path.join(RAW, f)
for kind, tags in shots.items():
	states = list(tags.get("paint", tags.get("code", {})).keys())
	W = TW * len(states)
	img = Image.new("RGB", (W, TH * 2 + 28), (20, 20, 24))
	d = ImageDraw.Draw(img)
	for r, tag in enumerate(["code", "paint"]):
		for c, st in enumerate(states):
			p = tags.get(tag, {}).get(st)
			if p is None:
				continue
			im = Image.open(p).convert("RGB").resize((TW, TH), Image.LANCZOS)
			img.paste(im, (c * TW, 28 + r * TH))
			d.text((c * TW + 6, 28 + r * TH + 4), "%s - %s" % ("ANTES (codigo)" if tag == "code" else "DEPOIS (pintura)", st), fill=(255, 230, 120))
	d.text((6, 8), "PERIGO: %s" % kind, fill=(255, 255, 255))
	img.save(os.path.join(OUT, "prancha_%s.png" % kind))
	print("prancha_%s.png" % kind, img.size)
