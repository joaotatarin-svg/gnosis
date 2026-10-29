# Abordagem A: Chatterbox pt-br (MIT) ATUANDO com referência teatral (a voz-base projetada no
# Qwen, sintética) + texto quebrado em segmentos com pausas montadas à mão. venv-rocm (GPU).
import os, sys, json
sys.path.insert(0, r"C:\gnosis-wt\dublagem\tools\voice")
os.environ["HF_HOME"] = r"C:\Users\jmtat\gnosis-tools\voice\hf"
os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["VOICE_THREADS"] = "4"
import numpy as np
import soundfile as sf
import voicelib as V

R2 = r"C:\gnosis-wt\_caps\dublagem\r2"
F = json.load(open(R2 + r"\_scripts\falas_r2.json", encoding="utf-8"))["falas"]
REF = json.load(open(R2 + r"\refs\escolhidas.json", encoding="utf-8"))
VOZ = {"Sophia": "sophia", "Yaldabaoth": "demiurgo", "O Rei": "demiurgo", "A Voz": "demiurgo", "Narrador": "narrador", "Athoth": "athoth", "Astaphaios": "sophia"}
# atuação por personagem (exaggeration, cfg, temperatura): teto PT 0,75 (finetune desanda acima)
P = {"Sophia": (0.6, 0.35, 0.8), "Yaldabaoth": (0.7, 0.3, 0.8), "O Rei": (0.55, 0.35, 0.75), "A Voz": (0.5, 0.35, 0.75),
	"Narrador": (0.5, 0.35, 0.75), "Athoth": (0.4, 0.4, 0.7), "Astaphaios": (0.55, 0.35, 0.8)}


def main():
	V.low_priority()
	cbs = {}
	for fa in F:
		out = R2 + "\\raw\\%s_A.wav" % fa["id"]
		if os.path.exists(out):
			continue
		lang = fa["lang"]
		if lang not in cbs:
			for k in list(cbs):
				cbs.pop(k).close()
			cbs[lang] = V.Chatterbox(lang, device="cuda")
		cb = cbs[lang]
		ex, cfg, t = P[fa["char"]]
		if fa.get("modo") == "final":
			ex, cfg = (0.75 if lang == "pt" else 1.0), 0.3
		ref = REF[VOZ[fa["char"]]]["wav24"]
		partes = []
		for txt, pausa in fa["segs"]:
			w = cb.gen(txt, ref, ex, cfg, t, 7)
			w = V.trim(w, -42, 40)
			partes.append(w)
			partes.append(np.zeros(int(V.SR * pausa / 1000), dtype=np.float32))
		x = np.concatenate(partes)
		sf.write(out, x, V.SR, subtype="PCM_16")
		print(fa["id"], "%.1f s" % (len(x) / V.SR), flush=True)


if __name__ == "__main__":
	main()
