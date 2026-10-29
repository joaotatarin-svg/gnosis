# Planeja um LOTE da dublagem completa (PT): jobs de clone (GPU) e pós/QA (CPU) + entrega no contrato.
# Uso: python -I mk_lote.py <nome_lote> <fontes separadas por vírgula | speaker:Nome> [--seeds 1,2] [--retry]
#   ex.: mk_lote.py limiar-1 cinematic.prologue,narrative.intro,narrative.king_intro,narrative.king_fall
import json, sys, os
R2 = r"C:\gnosis-wt\_caps\dublagem\r2"
P = R2 + r"\_scripts\prod"
E = json.load(open(P + r"\elenco_r2.json", encoding="utf-8"))
REF = json.load(open(R2 + r"\refs\escolhidas.json", encoding="utf-8"))
L = json.load(open(P + r"\roteiro.json", encoding="utf-8"))
RAW = R2 + r"\prod_raw"
OUT = R2 + r"\prod_ogg\pt"

# onde a fala toca (Guardião §6) e intensidade do Demiurgo (escada §15)
COMBATE = {"narrative.archon_phase2", "narrative.archon_phase3"}
MORTE_CHEFE = {"narrative._archon_death"}
FINAL = {"narrative.final_pre", "narrative.final_lines", "narrative.center_intro", "narrative.ending_lines"}


def onde(l):
	s = l["source"]
	if s in COMBATE:
		return "combate"
	if s in FINAL:
		return "final"
	if s in MORTE_CHEFE:
		return "morte_chefe"
	if "pool" in s or s.startswith("narrative.walk") or s == "narrative.node_arrival":
		return "caminhada"
	return "cena"


def grito(l):
	t = l["text_pt"]
	import re
	return bool(re.search(r"\b[A-ZÁÉÍÓÚÂÊÔÃÕÇ]{3,}\b", t)) and "!" in t


def preset(l):
	sp = l["speaker"]
	fx = E["personagens"][sp]["fx"]
	nivel = None
	if sp == "O Rei":
		fx, nivel = "legiao1", 2
	elif sp == "Yaldabaoth":
		o = onde(l)
		if o == "final":
			fx, nivel = ("legiao5", 5) if grito(l) else ("legiao4", 4)
		else:
			fx, nivel = ("legiao4", 4) if grito(l) else ("legiao3", 3)
	elif sp == "Sophia" and l["mode"] == "pensamento":
		fx = "sophia"
	return fx, nivel


def main():
	nome, fontes = sys.argv[1], sys.argv[2].split(",")
	seeds = [int(s) for s in (sys.argv[sys.argv.index("--seeds") + 1] if "--seeds" in sys.argv else "1,2").split(",")]
	sel = []
	for l in L:
		if l["mode"] == "rubrica" or l["dynamic"] or not l["said_pt"].strip():
			continue
		ok = any((f.startswith("speaker:") and l["speaker"] == f[8:]) or l["source"] == f for f in fontes)
		if ok:
			sel.append(l)
	clone, post = [], []
	for l in sel:
		v = E["personagens"][l["speaker"]]["voz"]
		for s in seeds:
			clone.append({"out": RAW + "\\%s_s%d.wav" % (l["id"], s), "text": l["said_pt"], "lang": "pt", "seed": s,
				"ref_wav": REF[v]["wav24"], "ref_text": REF[v]["text"]})
		fx, nivel = preset(l)
		post.append({"key": l["id"], "char": l["speaker"], "fx": fx, "said": l["said_pt"], "lang": "pt", "mode": l["mode"],
			"cands": [RAW + "\\%s_s%d.wav" % (l["id"], s) for s in seeds], "out": OUT + "\\%s.ogg" % l["id"],
			"grito": grito(l), "nivel": nivel, "onde": onde(l), "combate": onde(l) == "combate",
			"source": l["source"], "text_pt": l["text_pt"], "lote": nome, "retry_failed": "--retry" in sys.argv,
			"sim_min": 0.90})
	json.dump({"mode": "clone", "items": clone}, open(P + "\\job_clone_%s.json" % nome, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
	json.dump({"items": post}, open(P + "\\job_post_%s.json" % nome, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
	from collections import Counter
	print(nome, len(sel), "falas", dict(Counter(l["speaker"] for l in sel)), "clones", len(clone))


if __name__ == "__main__":
	main()
