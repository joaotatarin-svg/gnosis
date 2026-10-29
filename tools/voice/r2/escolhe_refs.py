# Escolhe a voz-base de cada personagem entre as sementes do VoiceDesign: ASR (CER) primeiro,
# depois expressividade (desvio do tom em semitons) e tom grave. Grava refs/escolhidas.json.
import os, sys, json, glob
sys.path.insert(0, r"C:\gnosis-wt\_caps\dublagem\r2\_scripts\prod")
import numpy as np
import soundfile as sf
import librosa
import post_qa as Q
import voicelib as V

R = r"C:\gnosis-wt\_caps\dublagem\r2\refs"
E = json.load(open(r"C:\gnosis-wt\_caps\dublagem\r2\_scripts\prod\elenco_r2.json", encoding="utf-8"))


def f0_stats(x):
	f0, vf, _ = librosa.pyin(x, fmin=60, fmax=500, sr=V.SR, frame_length=1024)
	f = f0[vf & np.isfinite(f0)]
	if len(f) < 10:
		return 0, 0
	st = 12 * np.log2(f / np.median(f))
	return float(np.median(f)), float(np.std(st))


def main():
	sys.stdout.reconfigure(encoding="utf-8")
	out = {}
	for v, d in E["vozes"].items():
		cs = []
		for p in sorted(glob.glob(R + "\\%s_s*.wav" % v)):
			if p.endswith("_24.wav"):
				continue
			x, sr = sf.read(p, dtype="float32")
			if sr != V.SR:
				x = librosa.resample(x, orig_sr=sr, target_sr=V.SR)
			w = Q.asr(x, "pt")
			hyp = " ".join(t for t, _, _ in w)
			e = Q.cer(d["ref"], hyp)
			f0, sd = f0_stats(x)
			cs.append({"wav": p, "cer": round(e, 3), "f0": round(f0), "st_sd": round(sd, 2), "dur": round(len(x) / V.SR, 1), "hyp": hyp})
		if not cs:
			continue
		cs.sort(key=lambda c: (c["cer"] > 0.05, c["cer"] > 0.02, -c["st_sd"]))
		b = cs[0]
		x, sr = sf.read(b["wav"], dtype="float32")
		x = V.trim(x if sr == V.SR else librosa.resample(x, orig_sr=sr, target_sr=V.SR), -42, 60)
		w24 = R + "\\%s_ref_24.wav" % v
		sf.write(w24, x, V.SR, subtype="PCM_16")
		out[v] = {"wav": b["wav"], "wav24": w24, "text": d["ref"], "cands": cs}
		print(v, "->", os.path.basename(b["wav"]), b, flush=True)
	json.dump(out, open(R + "\\escolhidas.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
	main()
