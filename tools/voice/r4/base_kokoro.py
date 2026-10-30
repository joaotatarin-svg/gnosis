# Etapa A das vozes-base: Kokoro pt-BR lê a frase-diagnóstico e a frase de referência de cada voz.
import os, sys
sys.stdout.reconfigure(encoding="utf-8")
os.environ["HF_HOME"] = r"C:\Users\jmtat\gnosis-tools\voice\hf"; os.environ["HF_HUB_OFFLINE"] = "1"
import numpy as np, soundfile as sf
from kokoro import KPipeline
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r4lib as L
p = KPipeline(lang_code="p", repo_id="hexgrad/Kokoro-82M")
def gen(t, v, sp):
	ch = []
	for fala, pausa in L.pedacos(t):
		a = np.concatenate([x.numpy() for _, _, x in p(fala, voice=v, speed=sp)]).astype(np.float32)
		ch += [a, np.zeros(int(pausa * 24000), np.float32)]
	return np.concatenate(ch)
for voz, (kv, sp, alvo, ref) in L.VOZES.items():
	for k, t in (("diag", L.DIAG), ("ref", ref)):
		o = L.W + "base/%s_k_%s.wav" % (voz, k)
		sf.write(o, gen(t, kv, sp), 24000, subtype="PCM_16")
	print(voz, flush=True)
