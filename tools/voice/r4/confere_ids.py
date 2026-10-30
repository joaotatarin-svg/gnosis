# Confere os 48 ids do lote com o texto que ESTÁ no jogo (roteiro extraído de integracao/onda1).
import json, sys
sys.stdout.reconfigure(encoding="utf-8")
W = "C:/gnosis-wt/_caps/dublagem/r4_limiar2/"
rot = json.load(open(W + "roteiro_14d7d2e.json", encoding="utf-8"))
rot = rot["lines"] if isinstance(rot, dict) and "lines" in rot else rot
jogo = {r["id"]: r for r in rot}
meus = json.load(open(W + "falas_limiar2.json", encoding="utf-8"))
ok = [f for f in meus if f["id"] in jogo]
print("batem: %d / %d" % (len(ok), len(meus)))
import difflib
for f in meus:
	if f["id"] in jogo: continue
	cand = [r for r in rot if r.get("key_speaker") == f["falante"]]
	best = max(cand, key=lambda r: difflib.SequenceMatcher(None, r["text_pt"], f["texto_pt"]).ratio(), default=None)
	print("FALTA %s %s | meu: %r | jogo: %r (%s, %s)" % (f["num"], f["id"], f["texto_pt"], best and best["text_pt"], best and best["id"], best and best["source"]))
