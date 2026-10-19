# QA7 — analisa as rodadas do tools/qa7/QA7Bot.tscn (várias sementes).
# Uso: python tools/qa7/analisa_bot.py <dir> s1 s2 s3
#   lê <dir>/<rótulo>.csv e .log; imprime (markdown):
#   1) curva de dificuldade por Éon (média entre sementes);
#   2) telas quentes / timeouts / travas / redes de segurança / mortes reais;
#   3) erros do log agrupados (números e ids normalizados) com contagem.
import csv, re, sys, os
from collections import defaultdict, Counter

EONS = ["Torpor", "Fome", "Corrente", "Silêncio", "Espelho", "Praga", "Coroa"]


def eon_of(screen):
	if screen == 1:
		return "Rei (1)"
	if 2 <= screen <= 64:
		k = (screen - 2) // 9
		return "%d %s (%d-%d)" % (k + 1, EONS[k], 2 + 9 * k, 10 + 9 * k)
	return "Centro+Final (65-68)"


def load(d, lab):
	rows = []
	p = os.path.join(d, lab + ".csv")
	if not os.path.exists(p):
		return rows
	with open(p, encoding="utf-8") as f:
		for r in csv.DictReader(f):
			rows.append(r)
	return rows


def norm(line):
	s = line.strip()
	s = re.sub(r"0x[0-9a-fA-F]+", "0x#", s)
	s = re.sub(r"<[A-Za-z0-9_]+#-?\d+>", "<obj>", s)
	s = re.sub(r"\b\d+(\.\d+)?\b", "#", s)
	return s[:220]


def errors(path):
	c = Counter()
	if not os.path.exists(path):
		return c
	lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
	for i, l in enumerate(lines):
		if re.search(r"(SCRIPT ERROR|^ERROR:|WARNING:|Parse Error|Function blocked)", l):
			# a linha "at:" seguinte diz a origem
			nxt = lines[i + 1].strip() if i + 1 < len(lines) else ""
			key = norm(l)
			if nxt.startswith("at:"):
				key += "  ‹" + norm(nxt) + "›"
			c[key] += 1
	return c


def main():
	d = sys.argv[1]
	labs = sys.argv[2:]
	per = {lab: load(d, lab) for lab in labs}
	# 1) curva por Éon
	agg = defaultdict(lambda: defaultdict(float))
	seeds_in = defaultdict(set)          # Éon -> sementes que chegaram nele
	for lab, rows in per.items():
		for r in rows:
			e = eon_of(int(r["screen"]))
			seeds_in[e].add(lab)
			a = agg[e]
			a["t"] += float(r["time"])
			a["dmg"] += int(r["dmg"])
			a["qm"] += int(r["deaths"])
			a["zero"] += int(r.get("zero", 0) or 0)
			a["to"] += 1 if int(r["timeout"]) > 0 else 0
			a["telas"] += 1
			a["minhp"] = min(a.get("minhp", 1.0) if "minhp" in a else 1.0, float(r.get("minhp", 1) or 1))
			a["earned"] += int(r["earned"])
			a["wmax"] = max(a.get("wmax", 0), int(r.get("weapon", 0) or 0))
			a["maxhp"] = max(a.get("maxhp", 0), int(r["maxhp"]))
	n = max(1, len([l for l in labs if per[l]]))
	print("## Curva por Éon (média das sementes que chegaram ao Éon; até %d)" % n)
	print("| Éon | telas | tempo (min) | dano | quase-mortes | mortes reais | timeouts | faíscas ganhas | arma máx. | vida máx. | menor vida |")
	print("|---|---|---|---|---|---|---|---|---|---|---|")
	order = ["Rei (1)"] + ["%d %s (%d-%d)" % (k + 1, EONS[k], 2 + 9 * k, 10 + 9 * k) for k in range(7)] + ["Centro+Final (65-68)"]
	for e in order:
		if e not in agg:
			continue
		a = agg[e]
		n = max(1, len(seeds_in[e]))
		print("| %s | %d | %.1f | %.0f | %.1f | %.1f | %.1f | %.0f | %d | %d | %.0f%% |" % (e, a["telas"] / n, a["t"] / n / 60, a["dmg"] / n, a["qm"] / n, a["zero"] / n, a["to"] / n, a["earned"] / n, a["wmax"], a["maxhp"], 100 * a.get("minhp", 1)))
	# 2) anomalias por tela
	print("\n## Por semente")
	for lab, rows in per.items():
		if not rows:
			print("- %s: SEM CSV (run não terminou?)" % lab)
			continue
		tt = sum(float(r["time"]) for r in rows) / 60
		print("- %s: %d telas, %.1f min, dano %d, quase-mortes %d, mortes reais %d, arma final %s, faíscas finais %s" % (
			lab, len(rows), tt, sum(int(r["dmg"]) for r in rows), sum(int(r["deaths"]) for r in rows),
			sum(int(r.get("zero", 0) or 0) for r in rows), rows[-1].get("weapon"), rows[-1]["orbs"]))
	print("\n## Telas com anomalia (semente: tela nó → o quê)")
	for lab, rows in per.items():
		for r in rows:
			w = []
			if int(r["timeout"]) == 2: w.append("TRAVOU")
			elif int(r["timeout"]) == 1: w.append("TIMEOUT(vivos: %s)" % r.get("left", ""))
			if int(r.get("zero", 0) or 0): w.append("MORTE REAL x%s" % r["zero"])
			if int(r["dmg"]) >= 90: w.append("HOT dano=%s" % r["dmg"])
			if int(r["deaths"]) >= 3: w.append("quase-mortes=%s" % r["deaths"])
			nets = r.get("nets", "")
			if nets and nets != "fenda": w.append("rede=%s" % nets)
			if float(r["time"]) > 45 + 60 * int(r["zones"]) and int(r["timeout"]) == 0: w.append("SLOW %.0fs" % float(r["time"]))
			if w:
				print("- %s: %s %s (%s) → %s" % (lab, r["screen"], r["node"], r["boss"], "; ".join(w)))
	# fontes de dano totais
	src = Counter()
	for rows in per.values():
		for r in rows:
			for p in (r["sources"] or "").split(";"):
				if ":" in p:
					k, v = p.rsplit(":", 1)
					src[k] += int(v)
	print("\n## Fontes de dano (soma das sementes, top 15)")
	print(", ".join("%s=%d" % kv for kv in src.most_common(15)))
	# nós visitados
	kinds = Counter()
	for rows in per.values():
		for r in rows:
			kinds[r["node"]] += 1
	print("\n## Tipos de nó jogados: " + ", ".join("%s=%d" % kv for kv in kinds.most_common()))
	# 3) erros
	print("\n## Erros de console agrupados")
	tot = Counter()
	for lab in labs:
		tot.update(errors(os.path.join(d, lab + ".log")))
		tot.update(errors(os.path.join(d, lab + ".err")))   # reteste.ps1 separa o stderr
	for k, v in tot.most_common(40):
		print("- %dx `%s`" % (v, k))


if __name__ == "__main__":
	main()
