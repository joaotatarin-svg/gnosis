#!/usr/bin/env python3
"""GNOSIS — simulador da ECONOMIA (Onda 6, diretor de Progressão).

Lê a renda de faíscas POR TELA medida pelo bot de balance (coluna `earned` do
CSV de tools/BalanceBot.tscn) e simula um jogador comprando na loja com as
regras ANTIGAS (base 37ea6f5) e as NOVAS (Progression, Onda 6). Mostra, por
Éon, faíscas ganhas × gastas, o nível da arma, as compras de vida/Éter, as
magias no máximo e EM QUE TELA cada trilha chega ao topo.

Uso:  python tools/progressao6/econ_sim.py <bot.csv> [--perfil guloso|arma|vida] [--perola]
  guloso = compra sempre o item mais BARATO que couber (o pior caso: o que
           maximiza "upgrades no máximo" cedo — a queixa do playtest).
  arma   = FOCADO: arma > vida > magias > Éter; junta faísca para o 1º item
           aberto (selado não conta) em vez de gastar no resto.
  vida   = FOCADO: vida > arma > magias > Éter.
  --perola = (regras novas) compra a Pérola do Hino assim que der (+25% de renda).
A loja abre pela PAUSA a qualquer hora (as duas regras): o jogador compra ao
fim de toda tela. Os Anéis chegam nas telas de Arconte (10, 19, ..., 64).
Os números NOVOS espelham scripts/autoload/progression_manager.gd — se mudar
lá, mude aqui (o teste `--checa` compara com o .gd).
"""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
ARCHON_SCREENS = [10, 19, 28, 37, 46, 55, 64]
EON_ENDS = [(1, "Rei"), (10, "Torpor"), (19, "Fome"), (28, "Corrente"), (37, "Silêncio"),
	(46, "Espelho"), (55, "Praga"), (64, "Coroa"), (67, "Centro"), (68, "Mente")]
SKILLS = 8          # Esfera Solar + 7 Anéis
SKILL_MAX = 3


def tier_at(screen: int) -> int:
	"""Arcontes vencidos AO FIM da tela (o Anel cai antes da loja pós-chefe)."""
	return sum(1 for a in ARCHON_SCREENS if a <= screen)


class Rules:
	name = ""

	def weapon_cost(self, lvl):  # custo para ir de lvl a lvl+1
		raise NotImplementedError

	def weapon_tier(self, lvl):
		return 0

	def skill_cost(self, k, lvl):
		raise NotImplementedError

	def skill_tier(self, k, lvl):
		return 0

	hp_max = 10

	def hp_cost(self, n):
		raise NotImplementedError

	def hp_cap(self, t):
		return self.hp_max

	mp_max = 6

	def mp_cost(self, n):
		raise NotImplementedError

	def mp_cap(self, t):
		return self.mp_max


class Old(Rules):
	name = "ANTES"

	def weapon_cost(self, lvl):
		return lvl * 50

	def skill_cost(self, k, lvl):
		return lvl * 40

	def hp_cost(self, n):
		return 60 * (n + 1)

	mp_max = 99         # sem teto (60 fixo)

	def mp_cost(self, n):
		return 60


class New(Rules):
	name = "DEPOIS"
	WEAPON_COSTS = [0, 0, 200, 450, 900, 1500]
	WEAPON_TIER = [0, 0, 0, 1, 3, 5]

	def weapon_cost(self, lvl):
		return self.WEAPON_COSTS[lvl + 1]

	def weapon_tier(self, lvl):
		return self.WEAPON_TIER[lvl + 1]

	def skill_cost(self, k, lvl):
		return 150 + 40 * k if lvl <= 1 else 400 + 80 * k

	def skill_tier(self, k, lvl):
		return k if lvl <= 1 else min(7, k + 2)

	def hp_cost(self, n):
		return 90 * (n + 1)

	def hp_cap(self, t):
		return min(10, 3 + t)

	def mp_cost(self, n):
		return 80 * (n + 1)

	def mp_cap(self, t):
		return min(6, 1 + t)


def simulate(rows, rules: Rules, perfil: str, perola: bool):
	orbs = 0
	earned_total = 0
	spent = 0
	weapon = 1
	hp = 0
	mp = 0
	skills = [1] * SKILLS       # 0 = Esfera; k = Anel k
	pearl = False
	out = []
	first_max = {}
	for r in rows:
		s = int(r["screen"])
		gain = int(r["earned"])
		if pearl:
			gain = int(round(gain * 1.25))
		orbs += gain
		earned_total += gain
		t = tier_at(s)
		owned = [0] + [k for k in range(1, 8) if ARCHON_SCREENS[k - 1] <= s]
		while True:
			opts = []
			if perola and isinstance(rules, New) and not pearl and t >= 3:
				opts.append((500, -1, "perola"))
			if weapon < 5 and t >= rules.weapon_tier(weapon):
				opts.append((rules.weapon_cost(weapon), 0, "arma"))
			if hp < rules.hp_max and hp < rules.hp_cap(t):
				opts.append((rules.hp_cost(hp), 1, "vida"))
			if mp < min(rules.mp_max, 6) and mp < rules.mp_cap(t):
				opts.append((rules.mp_cost(mp), 3, "eter"))
			for k in owned:
				if skills[k] < SKILL_MAX and t >= rules.skill_tier(k, skills[k]):
					opts.append((rules.skill_cost(k, skills[k]), 2, "magia%d" % k))
			if perfil == "guloso":
				# compra o mais barato que couber (não junta para nada)
				opts = [o for o in opts if o[0] <= orbs]
				opts.sort(key=lambda o: (o[1] != -1, o[0]))
			else:
				# FOCADO: segue a prioridade e JUNTA faísca para o 1º item aberto
				if perfil == "arma":
					order = {-1: -1, 0: 0, 1: 1, 2: 2, 3: 3}
				else:   # vida
					order = {-1: -1, 1: 0, 0: 1, 2: 2, 3: 3}
				opts.sort(key=lambda o: (order[o[1]], o[0]))
				if opts and opts[0][0] > orbs:
					opts = []
			if not opts:
				break
			cost, _, what = opts[0]
			orbs -= cost
			spent += cost
			if what == "arma":
				weapon += 1
			elif what == "vida":
				hp += 1
			elif what == "eter":
				mp += 1
			elif what == "perola":
				pearl = True
			else:
				skills[int(what[5:])] += 1
		maxed = sum(1 for k in owned if skills[k] >= SKILL_MAX)
		for key, ok in (("arma", weapon >= 5), ("vida", hp >= 10), ("eter", mp >= 6),
				("magias", all(skills[k] >= SKILL_MAX for k in range(SKILLS)))):
			if ok and key not in first_max:
				first_max[key] = s
		out.append({"screen": s, "earned": earned_total, "spent": spent, "orbs": orbs, "weapon": weapon,
			"hp": hp, "mp": mp, "skills_max": maxed, "skills_owned": len(owned)})
	return out, first_max


def total_cost(rules: Rules) -> int:
	c = sum(rules.weapon_cost(l) for l in range(1, 5))
	c += sum(rules.hp_cost(n) for n in range(10))
	c += sum(rules.mp_cost(n) for n in range(6))
	c += sum(rules.skill_cost(k, l) for k in range(SKILLS) for l in (1, 2))
	if isinstance(rules, New):
		c += 350 + 350 + 500
	return c


def checa() -> None:
	"""Confere que as constantes daqui batem com o progression_manager.gd."""
	gd = (ROOT / "scripts/autoload/progression_manager.gd").read_text(encoding="utf-8")
	def const(name):
		m = re.search(r"const %s := (.+)" % name, gd)
		return m.group(1).strip() if m else None
	assert const("WEAPON_COSTS") == "[0, 0, 200, 450, 900, 1500]", const("WEAPON_COSTS")
	assert const("WEAPON_TIER") == "[0, 0, 0, 1, 3, 5]", const("WEAPON_TIER")
	for n, v in (("HP_BASE_COST", "90"), ("HP_FREE_BUYS", "3"), ("MP_BASE_COST", "80"), ("MP_FREE_BUYS", "1"),
			("SKILL_COST_L2", "150"), ("SKILL_COST_L2_RING", "40"), ("SKILL_COST_L3", "400"),
			("SKILL_COST_L3_RING", "80"), ("SKILL_L3_TIER_GAP", "2")):
		assert const(n) == v, (n, const(n))
	print("checa: constantes do simulador = progression_manager.gd")


def main() -> None:
	args = sys.argv[1:]
	if "--checa" in args:
		checa()
		return
	if not args:
		print(__doc__)
		sys.exit(2)
	perfil = "guloso"
	if "--perfil" in args:
		perfil = args[args.index("--perfil") + 1]
	perola = "--perola" in args
	rows = list(csv.DictReader(open(args[0], encoding="utf-8")))
	rows.sort(key=lambda r: int(r["screen"]))
	print("renda medida: %d faíscas em %d telas (%s)" % (sum(int(r["earned"]) for r in rows), len(rows), args[0]))
	print("custo de TUDO na loja: antes %d · depois %d (relíquias inclusas)" % (total_cost(Old()), total_cost(New())))
	print("perfil: %s%s\n" % (perfil, " + Pérola" if perola else ""))
	for rules in (Old(), New()):
		out, first = simulate(rows, rules, perfil, perola)
		print("== %s ==" % rules.name)
		print("%-9s %5s %7s %7s %6s %4s %6s %5s %8s" % ("Éon", "tela", "ganhas", "gastas", "sobra", "arma", "vida", "éter", "mag.máx"))
		by = {o["screen"]: o for o in out}
		for end, nm in EON_ENDS:
			o = by.get(end)
			if o is None:
				continue
			print("%-9s %5d %7d %7d %6d %4d %3d/10 %3d/6 %4d/%d" % (nm, end, o["earned"], o["spent"], o["orbs"],
				o["weapon"], o["hp"], o["mp"], o["skills_max"], o["skills_owned"]))
		print("topo alcançado na tela: " + ", ".join("%s %s" % (k, first.get(k, "nunca")) for k in ("arma", "vida", "eter", "magias")))
		print()


if __name__ == "__main__":
	main()
