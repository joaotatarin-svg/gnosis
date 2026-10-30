# Junta as falas da amostra em UMA faixa (ordem do roteiro, pausas curtas) para o João ouvir de uma vez.
import glob, os, sys, json
sys.path.insert(0, r"C:\gnosis-wt\dublagem\tools\voice")
import numpy as np
import soundfile as sf
import voicelib as V

D = r"C:\gnosis-wt\_caps\dublagem\r3_ptbr\amostra_limiar"
arqs = sorted(glob.glob(D + "\\[0-9][0-9]_*.ogg"))
secao = lambda p: os.path.basename(p).split("_")[1][0]   # P, D, A, C, F, T, M, G
partes, ant = [], None
for p in arqs:
	x, sr = sf.read(p, dtype="float32")
	if x.ndim > 1:
		x = x.mean(axis=1)
	if ant is not None:
		partes.append(np.zeros(int(V.SR * (1.4 if secao(p) != ant else 0.55)), dtype=np.float32))
	partes.append(x)
	ant = secao(p)
extra = D + "\\extra_rei_FINAL_legiao5_A5.ogg"
if os.path.exists(extra):
	x, _ = sf.read(extra, dtype="float32")
	partes += [np.zeros(int(V.SR * 2.5), dtype=np.float32), x if x.ndim == 1 else x.mean(axis=1)]
y = np.concatenate(partes)
tp = V.write_ogg(V.tp_limit(y, V.TP_PRE_DB), D + "\\amostra_limiar_corrida.ogg")
print("%d falas, %.1f s, TP %.1f dBTP" % (len(arqs), len(y) / V.SR, tp))
