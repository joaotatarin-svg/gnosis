# Entrega o lote "limiar-2" no worktree dir7/dublagem-lote (CONTRATO_AUDIO.md):
#  1) REMOVE as 11 falas do lote "limiar-1" (sotaque PT-PT, texto velho; exceção autorizada pelo chefe em 29/10);
#  2) copia as 48 falas novas para assets/audio/voice/pt/<id>.ogg e as acrescenta no manifest.json;
#  3) escreve a tabela do Guardião e a lista de ids (para a Narrativa conferir o texto exato).
# Também monta a faixa corrida da amostra. Uso: python -I entrega_r4.py
import os, sys, json, shutil
sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); sys.path.insert(0, r"C:\gnosis-wt\dublagem\tools\voice")
import numpy as np, soundfile as sf
import voicelib as V, r4lib as L
WT = r"C:\gnosis-wt\dublagem-lote"
DST = WT + r"\assets\audio\voice\pt"
MAN = WT + r"\assets\audio\voice\manifest.json"
LOTE = "limiar-2"
FONTE = {"P": "cinematic.prologue", "D": "narrative.walk_arrival", "A": "narrative.king_intro", "C": "narrative.rei_combat",
	"F": "narrative.king_fall", "T": "narrative.eon_intro", "M": "narrative.death_revive", "G": "narrative.first_spark"}
falas = json.load(open(L.W + "falas_limiar2.json", encoding="utf-8"))
# fonte real no jogo (roteiro extraído do worktree com extract_lines.py), quando a fala já existe lá
_rot = json.load(open(L.W + "roteiro_14d7d2e.json", encoding="utf-8")) if os.path.exists(L.W + "roteiro_14d7d2e.json") else []
FONTE_JOGO = {r["id"]: r["source"] for r in (_rot["lines"] if isinstance(_rot, dict) else _rot)}
man = json.load(open(MAN, encoding="utf-8"))
velhas = [k for k, v in man["lines"].items() if v.get("lote") == "limiar-1"]
for k in velhas:
	del man["lines"][k]
	for ext in (".ogg", ".ogg.import"):
		p = DST + "\\" + k + ext
		if os.path.exists(p):
			os.remove(p)
tab = ["| # | id | falante (id) | texto_pt (id) | voz-base / conversor | dur (s) | onde | nível | LUFS-I | LUFS-S máx | TP | CER pós | sim. voz (cru) |",
	"|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
el = L.elenco()
sim = json.load(open(L.W + "qa_voz_cru.json"))
ids = []
for f in falas:
	o = L.W + "amostra/%s_%s.ogg" % (f["num"], f["quem"].lower())
	q = json.load(open(o + ".qa.json", encoding="utf-8"))
	assert q["ok"], f["num"]
	shutil.copy2(o, DST + "\%s.ogg" % f["id"])
	fonte = FONTE_JOGO.get(f["id"]) or FONTE[f["num"][0]]
	man["lines"][f["id"]] = {"speaker": f["falante"], "source": fonte, "lote": LOTE, "key": f["num"], "texto_pt": f["texto_pt"],
		"nivel": 1 if f["quem"] == "Rei" else None, "onde": f["onde"],
		"pt": {"file": "res://assets/audio/voice/pt/%s.ogg" % f["id"], "dur": q["dur"], "cer": q["cer_pos"], "tp": q["tp"], "lufs_s": q["lufs_s_max"]}}
	ids.append({"num": f["num"], "id": f["id"], "falante": f["falante"], "texto_pt": f["texto_pt"]})
	tab.append("| %s | %s | %s | %s | %s / %s | %.2f | %s | %s | %.1f | %.1f | %.1f | %.2f | %.2f |" % (f["num"], f["id"], f["falante"] or '""',
		f["texto_pt"].replace("\n", "\n").replace("|", "/"), f["voz"], el[f["voz"]]["conv"], q["dur"], f["onde"], 1 if f["quem"] == "Rei" else "—",
		q["lufs_i"], q["lufs_s_max"], q["tp"], q["cer_pos"], sim[f["num"]]))
man["lufs"] = -21.0
man["lines"] = dict(sorted(man["lines"].items()))
json.dump(man, open(MAN + ".tmp", "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent="\t")
os.replace(MAN + ".tmp", MAN)
json.dump(ids, open(L.W + "ids_limiar2.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
open(L.W + "tabela_limiar2.md", "w", encoding="utf-8").write("# Lote limiar-2 — %d falas (removidas %d do limiar-1)\n\n" % (len(falas), len(velhas)) + "\n".join(tab) + "\n")
# faixa corrida (cenas separadas por 1,4 s)
SR = V.SR
CENA_NOVA = {"D1", "A1", "C1", "F1a", "T1", "M1", "G1"}
partes = []
for f in falas:
	if f["num"] in CENA_NOVA:
		partes.append(np.zeros(int(1.4 * SR), np.float32))
	x, sr = sf.read(L.W + "amostra/%s_%s.ogg" % (f["num"], f["quem"].lower()), dtype="float32")
	x = x.mean(axis=1) if x.ndim > 1 else x
	partes += [x, np.zeros(int(0.55 * SR), np.float32)]
y = np.concatenate(partes)
tp = V.write_ogg(y, L.W + "amostra_limiar2_corrida.ogg")
print("removidas %d velhas; entregues %d; manifesto com %d falas; corrida %.0f s (tp %.1f)" % (len(velhas), len(falas), len(man["lines"]), len(y) / SR, tp))
