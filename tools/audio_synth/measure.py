# -*- coding: utf-8 -*-
"""
Mede loudness/pico de todo áudio em assets/audio/ (ou de uma pasta qualquer).

  python tools/audio_synth/measure.py [pasta_audio] [saida.json]

Por arquivo: duração, canais, loudness integrada (LUFS), maior momentânea
(M-max, régua dos SFX), true peak (dBTP), LRA (música) e — pra música e
ambiência — a EMENDA do loop: salto de amostra na volta (fim→começo, em
múltiplos do passo típico) e degrau de loudness entre o último e o primeiro
segundo (dB). Mono é medido como dual-mono (como o Godot toca).
"""
import os, sys, json
import numpy as np
import soundfile as sf
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C


def seam(x):
	"""Qualidade da emenda do loop: (salto relativo, degrau em dB)."""
	m = x if x.ndim == 1 else x.mean(axis=1)
	d = np.abs(np.diff(m))
	typ = float(np.median(d[d > 0])) if np.any(d > 0) else 1e-9
	jump = abs(float(m[0]) - float(m[-1])) / max(typ, 1e-9)
	w = C.SR
	a = np.sqrt(np.mean(m[-w:] ** 2)) + 1e-9
	b = np.sqrt(np.mean(m[:w] ** 2)) + 1e-9
	return jump, 20 * np.log10(b / a)


def measure_file(path, kind):
	data, sr = sf.read(path, dtype="float32", always_2d=True)
	x = data[:, 0] if data.shape[1] == 1 else data[:, :2]
	r = {
		"file": os.path.relpath(path, C.AUDIO).replace("\\", "/"),
		"dur": round(len(x) / sr, 2),
		"ch": int(data.shape[1]),
		"I": round(float(C.integrated_lufs(x)), 1),
		"Mmax": round(float(C.max_momentary(x)), 1),
		"TP": round(float(C.true_peak_db(x)), 1),
	}
	if kind in ("music", "amb"):
		r["LRA"] = round(float(C.lra(x)), 1)
		j, s = seam(x)
		r["seam_jump"] = round(float(j), 1)
		r["seam_step_db"] = round(float(s), 1)
	return r


def measure_all(root=C.AUDIO):
	out = []
	for kind in ("music", "amb", "sfx"):
		d = os.path.join(root, kind)
		if not os.path.isdir(d):
			continue
		for f in sorted(os.listdir(d)):
			if f.split(".")[-1].lower() in ("ogg", "wav", "mp3"):
				out.append(dict(kind=kind, **measure_file(os.path.join(d, f), kind)))
	return out


if __name__ == "__main__":
	root = sys.argv[1] if len(sys.argv) > 1 else C.AUDIO
	res = measure_all(root)
	for r in res:
		extra = ""
		if "LRA" in r:
			extra = "  LRA %4.1f  emenda: salto %6.1f×  degrau %+5.1f dB" % (r["LRA"], r["seam_jump"], r["seam_step_db"])
		print("%-28s %6.2fs %dch  I %6.1f  Mmax %6.1f  TP %5.1f%s" % (r["file"], r["dur"], r["ch"], r["I"], r["Mmax"], r["TP"], extra))
	if len(sys.argv) > 2:
		with open(sys.argv[2], "w", encoding="utf-8") as f:
			json.dump(res, f, ensure_ascii=False, indent=1)
