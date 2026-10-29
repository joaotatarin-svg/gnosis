extends "res://scripts/entities/bosses/boss_rei.gd"
## O REI — A MENTIRA (batalha final, tela 68). O mesmo repertório do duelo da
## tela 1, mas inteiro desde o início e mais rápido: Leque, Gesto, Raio do
## olho, Mão, Anéis-serra, Teleporte com golpe. O OLHO desce depois dos golpes
## grandes (ponto fraco). Divide a arena com o Colosso: UM ataca de cada vez
## (partner). As fases vêm do FinalBattle (1ª queda → 2; 1ª forma refeita → 3).


func _on_setup() -> void:
	super._on_setup()
	marks = []
	dmg_scale = 0.3
	keep_dist = Vector2(130.0, 230.0)
	gap_by_phase = [1.1, 0.95, 0.8]
	escape_hits = 3
	escape_id = "teleporte"


func _build_moves() -> Dictionary:
	var base: Dictionary = super._build_moves()
	var all: Array = []
	for p in [1, 2, 3]:
		for m in base[p]:
			var found := false
			for a in all:
				if a.id == m.id:
					found = true
			if not found and m.id != "larvas":
				var c: Dictionary = m.duplicate()
				c.wind = float(c.wind) * 0.85
				all.append(c)
	var p1: Array = all.filter(func(m): return m.id in ["leque", "gesto", "raio", "mao", "aneis", "teleporte", "gesto_b"])
	var p2: Array = all.filter(func(m): return m.id in ["leque", "gesto", "raio", "mao", "aneis", "combo", "raio_b", "teleporte", "gesto_b"])
	var p3: Array = all.duplicate()
	return {1: p1, 2: p2, 3: p3}
