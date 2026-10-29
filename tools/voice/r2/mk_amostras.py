# Monta os jobs da rodada de amostras R2: (1) clone GPU da voz fixa; (2) pós/QA de todas as abordagens.
import json, sys
R2 = r"C:\gnosis-wt\_caps\dublagem\r2"
F = json.load(open(R2 + r"\_scripts\falas_r2.json", encoding="utf-8"))["falas"]
E = json.load(open(R2 + r"\_scripts\prod\elenco_r2.json", encoding="utf-8"))
REF = json.load(open(R2 + r"\refs\escolhidas.json", encoding="utf-8"))
SEEDS = (1, 2, 3)

clone = []
for fa in F:
	v = E["personagens"][fa["char"]]["voz"]
	txt = " ".join(s[0] for s in fa["segs"])
	for s in SEEDS:
		clone.append({"out": R2 + "\\raw\\%s_Q_s%d.wav" % (fa["id"], s), "text": txt, "lang": fa["lang"], "seed": s,
			"ref_wav": REF[v]["wav24"], "ref_text": REF[v]["text"]})
json.dump({"mode": "clone", "items": clone}, open(R2 + r"\_scripts\prod\job_clone_amostras.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)

# nome público de cada fala
NOME = {"sophia": "sophia", "yaldabaoth": "yaldabaoth", "narrador": "narrador", "a_voz": "a_voz", "athoth": "athoth",
	"astaphaios": "astaphaios", "o_rei": "o_rei", "sophia_en": "sophia_en", "yaldabaoth_en": "yaldabaoth_en",
	"rei_limiar": "rei_limiar", "rei_limiar_grito": "rei_limiar", "yald_grito": "yaldabaoth_grito"}
FX = {"Sophia": "sophia", "Yaldabaoth": "legiao3", "Narrador": "narrador", "A Voz": "a_voz", "Athoth": "athoth",
	"Astaphaios": "astaphaios", "O Rei": "legiao1"}
post = []
O = R2 + "\\"
def add(key, fa, cands, fx, out, grito=False, stereo=False):
	said = fa["texto"]
	post.append({"key": key, "char": fa["char"], "fx": fx, "said": said, "lang": fa["lang"], "cands": cands, "out": O + out,
		"grito": grito, "stereo": stereo})
for fa in F:
	i, n = fa["id"], NOME[fa["id"]]
	q = [R2 + "\\raw\\%s_Q_s%d.wav" % (i, s) for s in SEEDS]
	final = fa.get("modo") == "final"
	if i in ("rei_limiar",):
		add(i + "_1", fa, q, "legiao1", "rei_limiar_COMECO.ogg")
		add(i + "_1e", fa, q, "legiao1", "rei_limiar_COMECO_estereo.ogg", stereo=True)
		continue
	if i == "rei_limiar_grito" or i == "yald_grito":
		add(i + "_g1", fa, q, "legiao4", "%s_FINAL_grito1.ogg" % n, grito=True)
		add(i + "_g2", fa, q, "legiao5", "%s_FINAL_grito2.ogg" % n, grito=True)
		add(i + "_g2e", fa, q, "legiao5", "%s_FINAL_grito2_estereo.ogg" % n, grito=True, stereo=True)
		add(i + "_A", fa, [R2 + "\\raw\\%s_A.wav" % i], "legiao5", "%s_FINAL_grito2_A.ogg" % n, grito=True)
		add(i + "_B", fa, [R2 + "\\raw\\%s_B.wav" % i], "legiao5", "%s_FINAL_grito2_B.ogg" % n, grito=True)
		continue
	add(i + "_A", fa, [R2 + "\\raw\\%s_A.wav" % i], "cru", "%s_A.ogg" % n)
	add(i + "_B", fa, [R2 + "\\raw\\%s_B.wav" % i], "cru", "%s_B.ogg" % n)
	add(i + "_Q", fa, q, "cru", "%s_Q.ogg" % n)
	add(i + "_C", fa, q, FX[fa["char"]], "%s_C.ogg" % n)
	if fa["char"] == "Yaldabaoth":
		for lv in (1, 3, 5):
			add(i + "_L%d" % lv, fa, q, "legiao%d" % lv, "%s_C_legiao%d.ogg" % (n, lv))
		add(i + "_L5e", fa, q, "legiao5", "%s_C_legiao5_estereo.ogg" % n, stereo=True)
json.dump({"items": post}, open(R2 + r"\_scripts\prod\job_post_amostras.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(len(clone), "clones;", len(post), "pós")
