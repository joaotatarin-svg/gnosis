import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r4lib as L
cb, ov = [], []
for voz, (kv, sp, alvo, ref) in L.VOZES.items():
	for k in ("diag", "ref"):
		s = L.W + "base/%s_k_%s.wav" % (voz, k)
		cb.append([s, alvo, L.W + "base/%s_cbx_%s.wav" % (voz, k)])
		ov.append([s, alvo, L.W + "base/%s_ov_%s.wav" % (voz, k), L.W + "base/%s_k_ref.wav" % voz])
json.dump(cb, open(L.W + "base/lista_cbx.json", "w")); json.dump(ov, open(L.W + "base/lista_ov.json", "w"))
