# Entrega um lote no CONTRATO_AUDIO.md: copia os .ogg aprovados para assets/audio/voice/pt/<id>.ogg
# do worktree da Dublagem, ACRESCENTA as falas no manifest.json e escreve a tabela do Guardião.
# Uso: python -I entrega.py <nome_lote>
import json, sys, os, shutil
R2 = r"C:\gnosis-wt\_caps\dublagem\r2"
P = R2 + r"\_scripts\prod"
WT = r"C:\gnosis-wt\dublagem-lote"
DST = WT + r"\assets\audio\voice\pt"
MAN = WT + r"\assets\audio\voice\manifest.json"
TAB = R2 + r"\entregas"


def main():
	sys.stdout.reconfigure(encoding="utf-8")
	nome = sys.argv[1]
	job = {it["key"]: it for it in json.load(open(P + "\\job_post_%s.json" % nome, encoding="utf-8"))["items"]}
	res = json.load(open(P + "\\job_post_%s_res.json" % nome, encoding="utf-8"))
	os.makedirs(DST, exist_ok=True)
	os.makedirs(TAB, exist_ok=True)
	man = json.load(open(MAN, encoding="utf-8")) if os.path.exists(MAN) else {"version": 1, "lufs": -21.0, "lines": {}}
	man["lufs"] = -21.0
	linhas = ["| id | personagem | texto | dur (s) | nível | onde | LUFS-I | LUFS-S máx | TP (dBTP) | CER pós | sim. locutor |",
		"|---|---|---|---|---|---|---|---|---|---|---|"]
	ok = ruins = 0
	for r in res:
		it = job.get(r["key"])
		if it is None:
			continue
		if not r.get("ok"):
			ruins += 1
			linhas.append("| %s | %s | %s | — | — | %s | — | — | — | %.2f | REPROVADA (fica no blip) |" % (r["key"], it["char"], it["text_pt"].replace("\n", " ").replace("|", "/"), it["onde"], r.get("cer_pos", 1)))
			continue
		ok += 1
		shutil.copy2(r["out"], DST + "\\%s.ogg" % r["key"])
		man["lines"][r["key"]] = {"speaker": it["char"], "source": it["source"], "lote": nome, "nivel": it.get("nivel"), "onde": it["onde"],
			"pt": {"file": "res://assets/audio/voice/pt/%s.ogg" % r["key"], "dur": r["dur"], "cer": r["cer_pos"], "tp": r["tp"], "lufs_s": r["lufs_s_max"]}}
		linhas.append("| %s | %s | %s | %.2f | %s | %s | %.1f | %.1f | %.1f | %.2f | %s |" % (r["key"], it["char"], it["text_pt"].replace("\n", " ").replace("|", "/"),
			r["dur"], it.get("nivel") or "—", it["onde"], r["lufs_i"], r["lufs_s_max"], r["tp"], r["cer_pos"], r.get("spk_sim")))
	man["lines"] = dict(sorted(man["lines"].items()))
	tmp = MAN + ".tmp"
	json.dump(man, open(tmp, "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent="\t")
	os.replace(tmp, MAN)
	open(TAB + "\\%s.md" % nome, "w", encoding="utf-8").write("# Lote %s — %d aprovadas, %d reprovadas\n\n" % (nome, ok, ruins) + "\n".join(linhas) + "\n")
	print("lote %s: %d entregues, %d reprovadas; manifesto com %d falas" % (nome, ok, ruins, len(man["lines"])))


if __name__ == "__main__":
	main()
