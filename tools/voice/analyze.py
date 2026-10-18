"""Mede as amostras (o 'ouvido' objetivo da IA, que não escuta áudio):
tom médio (F0 mediana, Hz), loudness integrada (LUFS), duração e brilho
(centróide espectral). Gera uma tabela Markdown e uma prancha de espectrogramas.

Uso: python tools/voice/analyze.py <pasta_amostras>
"""
from __future__ import annotations

import sys
from pathlib import Path

import librosa
import numpy as np


def main() -> int:
	sys.stdout.reconfigure(encoding="utf-8")
	d = Path(sys.argv[1])
	import pyloudnorm as pyln
	rows = []
	files = sorted(d.glob("*.ogg"))
	for f in files:
		x, sr = librosa.load(f, sr=24000, mono=True)
		f0, vflag, _ = librosa.pyin(x, fmin=50, fmax=600, sr=sr, frame_length=1024)
		f0v = f0[vflag] if vflag is not None else np.array([])
		med = float(np.nanmedian(f0v)) if f0v.size else float("nan")
		voiced = float(np.mean(vflag)) if vflag is not None else 0.0
		lufs = pyln.Meter(sr).integrated_loudness(x.astype(np.float64))
		cent = float(np.mean(librosa.feature.spectral_centroid(y=x, sr=sr)))
		rows.append((f.name, len(x) / sr, med, voiced, lufs, cent))
	print("| arquivo | dur (s) | F0 mediana (Hz) | % vozeado | LUFS | centróide (Hz) |")
	print("|---|---|---|---|---|---|")
	for r in rows:
		print("| %s | %.1f | %s | %.0f%% | %.1f | %.0f |" % (r[0], r[1], "—" if np.isnan(r[2]) else "%.0f" % r[2], 100 * r[3], r[4], r[5]))
	# prancha de espectrogramas (para a IA conferir os efeitos com os olhos)
	try:
		import matplotlib
		matplotlib.use("Agg")
		import matplotlib.pyplot as plt
		n = len(files)
		cols = 4
		rws = (n + cols - 1) // cols
		fig, axs = plt.subplots(rws, cols, figsize=(cols * 4, rws * 1.6))
		for ax, f in zip(np.ravel(axs), files):
			x, sr = librosa.load(f, sr=24000, mono=True)
			S = librosa.amplitude_to_db(np.abs(librosa.stft(x, n_fft=1024, hop_length=256)), ref=np.max)
			ax.imshow(S[:300], origin="lower", aspect="auto", cmap="magma", vmin=-70, vmax=0)
			ax.set_title(f.stem, fontsize=7)
			ax.axis("off")
		for ax in np.ravel(axs)[n:]:
			ax.axis("off")
		fig.tight_layout()
		fig.savefig(d / "_espectrogramas.png", dpi=70)
	except ImportError:
		pass
	return 0


if __name__ == "__main__":
	sys.exit(main())
