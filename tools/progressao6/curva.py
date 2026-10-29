#!/usr/bin/env python3
"""GNOSIS — leitura da CURVA de compra jogada pelo ProgBot (Progressão 7).

Lê um ou mais CSV do tools/progressao6/ProgBot.tscn rodado com `loja=real`
(compras pela API real da Progression) e mostra, por Éon: faíscas ganhas e
gastas (acumuladas), nível da arma, compras de vida/Éter, magias no Nv.3,
quantas compras houve no Éon, o maior "jejum" (telas seguidas sem compra), e a
pressão do combate: quase-mortes (vida < 45%), mortes reais, timeouts e o maior
golpe em % da vida máxima. No fim: em que tela cada trilha chegou ao topo.

Uso:  python tools/progressao6/curva.py <a.csv> [b.csv ...]
"""
from __future__ import annotations


import sys
from pathlib import Path

EON_ENDS = [(1, "Rei"), (10, "Torpor"), (19, "Fome"), (28, "Corrente"), (37, "Silêncio"),
	(46, "Espelho"), (55, "Praga"), (64, "Coroa"), (67, "Centro"), (68, "Mente")]
TOPS = (("arma", lambda r: int(r["weapon"]) >= 5), ("vida", lambda r: int(r["hpb"]) >= 10),
	("éter", lambda r: int(r["mpb"]) >= 6), ("magias", lambda r: int(r["skmax"]) >= 8))


def ler(path: str) -> list[dict]:
	"""O campo `left` (inimigos vivos no timeout, "tipo@x,y") tem vírgulas: lê
	os 18 primeiros campos pela frente, os de depois de `left` por trás."""
	lines = open(path, encoding="utf-8").read().splitlines()
	head = lines[0].split(",")
	i_left = head.index("left")
	tail = len(head) - i_left - 1
	rows = []
	for ln in lines[1:]:
		f = ln.split(",")
		vals = f[:i_left] + [",".join(f[i_left:len(f) - tail])] + f[len(f) - tail:]
		rows.append(dict(zip(head, vals)))
	rows.sort(key=lambda r: int(r["screen"]))
	return rows


def resumo(path: str) -> dict:
	rows = ler(path)
	print("== %s ==" % Path(path).stem)
	print("%-9s %4s %6s %6s %5s %4s %5s %4s %5s %6s %5s %5s %4s %4s %6s" % ("Éon", "tela", "ganhas", "gastas", "sobra",
		"arma", "vida", "éter", "mag3", "compr", "jejum", "q.mrt", "real", "tout", "golpe%"))
	earned = spent = 0
	start = 0
	tops: dict[str, int] = {}
	tot = {"deaths": 0, "zero": 0, "timeout": 0, "buys": 0}
	gap_global = 0
	gap_run = 0
	for end, nome in EON_ENDS:
		seg = [r for r in rows if start < int(r["screen"]) <= end]
		start = end
		if not seg:
			continue
		buys = 0
		gap = 0
		run = 0
		for r in seg:
			earned += int(r["earned"])
			spent += int(r["spent"])
			n = len([b for b in r["buys"].split("|") if b])
			buys += n
			run = 0 if n else run + 1
			gap = max(gap, run)
			gap_run = 0 if n else gap_run + 1
			gap_global = max(gap_global, gap_run)
			for k, ok in TOPS:
				if ok(r) and k not in tops:
					tops[k] = int(r["screen"])
		last = seg[-1]
		d = sum(int(r["deaths"]) for r in seg)
		z = sum(int(r["zero"]) for r in seg)
		t = sum(1 for r in seg if int(r["timeout"]) > 0)
		golpe = max(int(r["maxhit"]) / max(1, int(r["maxhp"])) for r in seg)
		tot["deaths"] += d
		tot["zero"] += z
		tot["timeout"] += t
		tot["buys"] += buys
		print("%-9s %4d %6d %6d %5d %4s %3s/10 %2s/6 %3s/8 %5d %6d %5d %4d %4d %5.0f%%" % (nome, end, earned, spent,
			int(last["orbs"]), last["weapon"], last["hpb"], last["mpb"], last["skmax"], buys, gap, d, z, t, 100 * golpe))
	print("topo na tela: " + ", ".join("%s %s" % (k, tops.get(k, "nunca")) for k, _ in TOPS))
	print("run: %d compras · maior jejum %d telas · quase-mortes %d · mortes reais %d · telas com timeout %d · %.1f min de jogo" % (
		tot["buys"], gap_global, tot["deaths"], tot["zero"], tot["timeout"], sum(float(r["time"]) for r in rows) / 60.0))
	print()
	tot["tops"] = tops
	tot["earned"] = earned
	return tot


def main() -> None:
	if len(sys.argv) < 2:
		print(__doc__)
		sys.exit(2)
	for p in sys.argv[1:]:
		resumo(p)


if __name__ == "__main__":
	main()
