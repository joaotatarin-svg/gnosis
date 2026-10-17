# -*- coding: utf-8 -*-
"""
Mosaico de espectrogramas (PIL) pra inspecionar sons sem ouvir.

  python tools/audio_synth/spectro.py saida.png arq1.ogg arq2.ogg ... [--cols 3]

Cada célula: espectrograma log-frequência (60 Hz–16 kHz, 80 dB de faixa) com a
forma de onda (envelope) por baixo e o nome do arquivo.
"""
import os, sys
import numpy as np
import soundfile as sf
from PIL import Image, ImageDraw
import librosa

W, H, EH = 300, 120, 24


def cell(path, maxdur):
	y, sr = sf.read(path, dtype="float32", always_2d=True)
	m = y.mean(axis=1)
	S = np.abs(librosa.stft(m, n_fft=1024, hop_length=128)) + 1e-9
	Sdb = 20 * np.log10(S / S.max())
	freqs = librosa.fft_frequencies(sr=sr, n_fft=1024)
	ylog = np.geomspace(60, 16000, H)
	idx = np.clip(np.searchsorted(freqs, ylog), 0, len(freqs) - 1)
	img = Sdb[idx][::-1]
	cols = int(W * min(1.0, (len(m) / sr) / maxdur))
	xs = np.linspace(0, img.shape[1] - 1, max(cols, 1)).astype(int)
	img = np.clip((img[:, xs] + 80) / 80, 0, 1)
	rgb = np.zeros((H + EH, W, 3), np.uint8)
	rgb[:H, :cols, 0] = (img ** 0.8 * 255).astype(np.uint8)
	rgb[:H, :cols, 1] = (img ** 1.6 * 230).astype(np.uint8)
	rgb[:H, :cols, 2] = (np.sqrt(img) * 120).astype(np.uint8)
	# envelope (pico por coluna)
	seg = np.array_split(np.abs(m), max(cols, 1))
	pk = np.array([s.max() if len(s) else 0 for s in seg])
	for c in range(cols):
		h = int(pk[c] * (EH - 2))
		rgb[H + EH - 1 - h:H + EH, c] = (90, 200, 255)
	im = Image.fromarray(rgb)
	ImageDraw.Draw(im).text((4, 2), os.path.basename(path), fill=(255, 255, 255))
	return im


if __name__ == "__main__":
	args = sys.argv[1:]
	cols = 3
	if "--cols" in args:
		i = args.index("--cols")
		cols = int(args[i + 1])
		del args[i:i + 2]
	out, files = args[0], args[1:]
	durs = [sf.info(f).duration for f in files]
	maxdur = max(durs)
	rows = (len(files) + cols - 1) // cols
	sheet = Image.new("RGB", (cols * (W + 4), rows * (H + EH + 4)), (20, 20, 24))
	for k, f in enumerate(files):
		sheet.paste(cell(f, maxdur), ((k % cols) * (W + 4), (k // cols) * (H + EH + 4)))
	sheet.save(out)
	print("mosaico:", out, "(%d sons, escala de tempo comum = %.2f s)" % (len(files), maxdur))
