# Mede se o "grito" é grito: tom mediano (Hz), centróide espectral e energia 1-4 kHz relativa (esforço vocal).
import sys, glob, numpy as np, soundfile as sf, librosa
for p in sys.argv[1:]:
	for f in sorted(glob.glob(p)):
		x, sr = sf.read(f, dtype="float32")
		if x.ndim > 1: x = x.mean(axis=1)
		f0, vf, _ = librosa.pyin(x, fmin=60, fmax=600, sr=sr, frame_length=1024)
		f0 = f0[vf & np.isfinite(f0)]
		S = np.abs(librosa.stft(x, n_fft=1024)) ** 2
		fr = librosa.fft_frequencies(sr=sr, n_fft=1024)
		hi = S[(fr > 1000) & (fr < 4000)].sum() / (S[(fr > 80) & (fr < 1000)].sum() + 1e-9)
		print("%-34s f0 %4.0f Hz  centroide %5.0f  esforço(1-4k/80-1k) %.2f" % (f.split("\\")[-1].split("/")[-1], np.median(f0) if len(f0) else 0,
			librosa.feature.spectral_centroid(y=x, sr=sr).mean(), hi))
