# Etapa A: Kokoro pt-BR lê cada fala em 3 tomadas (ritmo/pausas um pouco diferentes) + listas de conversão de timbre.
# Atuação: o texto é dividido em trechos; cada pausa (". ? ! : ...") é posta por nós (Kokoro lê "..." errado).
import os, sys, json
sys.stdout.reconfigure(encoding="utf-8")
os.environ["HF_HOME"] = r"C:\Users\jmtat\gnosis-tools\voice\hf"; os.environ["HF_HUB_OFFLINE"] = "1"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np, soundfile as sf
from kokoro import KPipeline
import r4lib as L
p = KPipeline(lang_code="p", repo_id="hexgrad/Kokoro-82M")
falas = json.load(open(L.W + "falas_limiar2.json", encoding="utf-8"))
el = L.elenco()
TOMADAS = [(1.00, 1.00), (0.96, 1.15), (1.04, 0.88)]   # (fator de velocidade, fator de pausa)
os.makedirs(L.W + "raw", exist_ok=True)
cb, ov = [], []
for f in falas:
	kv = el[f["voz"]]["kokoro"]
	for t, (fv, fp) in enumerate(TOMADAS, 1):
		o = L.W + "raw/%s_k%d.wav" % (f["num"], t)
		if not os.path.exists(o):
			ch = []
			tr = [(x, 0.35) for x in f["tts"].split("|")] if "|" in f["tts"] else L.pedacos(f["tts"])
			tr[-1] = (tr[-1][0], 0.0)
			for fala, pausa in tr:
				if fala.startswith("#"):   # fonema cru
					a = np.concatenate([r.audio.numpy() for r in p.generate_from_tokens(fala[1:], voice=kv, speed=f["vel"] * fv)]).astype(np.float32)
				else:
					a = np.concatenate([x.numpy() for _, _, x in p(fala, voice=kv, speed=f["vel"] * fv)]).astype(np.float32)
				ch += [a, np.zeros(int(pausa * fp * 24000), np.float32)]
			sf.write(o, np.concatenate(ch), 24000, subtype="PCM_16")
		e = el[f["voz"]]
		dst = L.W + "raw/%s_v%d.wav" % (f["num"], t)
		(cb if e["conv"] == "cbx" else ov).append([o, e["alvo"], dst, L.W + "base/%s_k_ref.wav" % f["voz"]][: 3 if e["conv"] == "cbx" else 4])
	print(f["num"], end=" ", flush=True)
json.dump(cb, open(L.W + "raw/lista_cbx.json", "w")); json.dump(ov, open(L.W + "raw/lista_ov.json", "w"))
print("\ncbx %d, ov %d" % (len(cb), len(ov)))
