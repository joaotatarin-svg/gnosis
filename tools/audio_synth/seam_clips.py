# -*- coding: utf-8 -*-
"""
Gera clipes de teste da EMENDA de cada loop (música e ambiência): os últimos
4 s + os primeiros 4 s colados — exatamente o que se ouve quando o loop volta.

  python tools/audio_synth/seam_clips.py <pasta_saida>
"""
import os, sys
import numpy as np
import soundfile as sf
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
for kind in ("music", "amb"):
	d = os.path.join(C.AUDIO, kind)
	for f in sorted(os.listdir(d)):
		if not f.endswith(".ogg") or f.startswith("roubo"):
			continue
		x, sr = sf.read(os.path.join(d, f), dtype="float32", always_2d=True)
		n = 4 * sr
		y = np.concatenate([x[-n:], x[:n]])
		C.write_ogg(os.path.join(out, f.replace(".ogg", "_emenda.ogg")), y, 4)
print("clipes de emenda em", out)
