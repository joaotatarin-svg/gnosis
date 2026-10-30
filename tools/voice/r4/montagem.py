# Etapa C: monta as tomadas convertidas para o pós: respiração sutil (inspiração antes de fala longa da Sophia/Voz/
# narradora, fora de combate), sussurro parcial no C5 ("quase sussurro", AMOSTRA §2) e grava o job do post_qa.
import os, sys, json
sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); sys.path.insert(0, r"C:\gnosis-wt\dublagem\tools\voice")
import numpy as np, soundfile as sf, librosa
import voicelib as V, r4lib as L
SR = V.SR
falas = json.load(open(L.W + "falas_limiar2.json", encoding="utf-8"))
rng = np.random.default_rng(29)
def inspira(ref_rms, dur=0.30):
	n = int(dur * SR); t = np.arange(n) / SR
	x = rng.standard_normal(n).astype(np.float32)
	x = V._butter(V._butter(x, "high", 350), "low", 2600)
	env = np.minimum(1, t / 0.13) * np.minimum(1, (dur - t) / 0.09)
	x = x * env.astype(np.float32)
	return (x / (np.sqrt(np.mean(x ** 2)) + 1e-9) * ref_rms * 10 ** (-30 / 20)).astype(np.float32)
itens = []
os.makedirs(L.W + "monta", exist_ok=True)
for f in falas:
	cands = []
	for t in (1, 2, 3):
		x, sr = sf.read(L.W + "raw/%s_v%d.wav" % (f["num"], t), dtype="float32")
		x = x.mean(axis=1) if x.ndim > 1 else x
		x = librosa.resample(x, orig_sr=sr, target_sr=SR) if sr != SR else x
		x = V.trim(x, -45, 20)
		rms = float(np.sqrt(np.mean(x ** 2)))
		if f["num"] == "C5":
			x = V.whisper(x, 0.35)
		if f["quem"] in ("Sophia", "Voz", "Narradora") and f["onde"] != "combate" and len(f["said"].split()) >= 7:
			x = np.concatenate([inspira(rms), np.zeros(int(0.06 * SR), np.float32), x])
		o = L.W + "monta/%s_t%d.wav" % (f["num"], t)
		sf.write(o, x, SR, subtype="PCM_16")
		cands.append(o)
	itens.append({"key": f["num"], "char": f["quem"], "fx": f["fx"], "said": f["said"], "lang": "pt", "mode": f["modo"], "cands": cands,
		"out": L.W + "amostra/%s_%s.ogg" % (f["num"], f["quem"].lower()), "grito": False, "onde": f["onde"],
		"combate": f["onde"] == "combate", "sim_min": 0.0, "nivel": 1 if f["quem"] == "Rei" else None})
json.dump({"items": itens}, open(L.W + "job_post_limiar2.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("itens", len(itens))
