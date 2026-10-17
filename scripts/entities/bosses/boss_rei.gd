extends BossBrain
## O REI (tela 1) — o duelo-TUTORIAL. A mentira de máscara branca ensina a
## ler a luta, uma lição por fase, com golpes lentos e janelas largas:
## Fase 1 — APARAR: o Orbe (amarelo, lento) e o Gesto (empurrão amarelo de
##   perto). Aparar o Gesto abre o contra-ataque.
## Fase 2 — PULAR: a Onda corre rente ao chão; pule por cima.
## Fase 3 — ROLAR: a Coluna de luz (losango vermelho) cai onde ela está;
##   não dá pra aparar — role ou saia.
## Quem cola e só bate leva a repulsão (vermelha): "3–4 golpes e sai".

const LIGHT := Color(1.0, 0.85, 0.5)


func _on_setup() -> void:
	dmg_scale = 0.75
	keep_dist = Vector2(110.0, 220.0)
	gap_by_phase = [1.25, 1.1, 0.95]
	escape_hits = 5


func _build_moves() -> Dictionary:
	var orbe := {"id": "orbe", "kind": "shot", "anim": "ranged", "wind": 0.95, "strike": 0.3, "recover": 0.8,
		"offs": [0.0], "speed": 190.0, "dmg": 0.9, "color": LIGHT, "life": 2.6,
		"rmin": 90.0, "rmax": 9999.0, "w": 1.5, "cd": 1.5, "aa": true}
	var gesto := {"id": "gesto", "kind": "melee", "anim": "melee", "wind": 0.85, "strike": 0.22, "recover": 1.0,
		"off": 34.0, "sx": 2.2, "sy": 1.5, "dmg": 0.9, "kb": 260.0, "rmax": 100.0, "w": 2.0, "cd": 1.0}
	var passo := {"id": "passo", "kind": "cast", "anim": "ranged", "wind": 0.45, "strike": 0.12, "recover": 0.4,
		"rmin": 0.0, "rmax": 80.0, "w": 0.6, "cd": 6.0}
	var onda := {"id": "onda", "kind": "slam", "anim": "slam", "wind": 0.9, "strike": 0.25, "recover": 0.9,
		"sx": 1.4, "sy": 1.0, "nova": 70.0, "waves": 1, "wave_dmg": 0.8, "wave_speed": 200.0, "dmg": 0.8,
		"rmin": 0.0, "rmax": 9999.0, "w": 1.6, "cd": 2.5}
	var orbes3 := orbe.duplicate()
	orbes3.id = "orbes3"
	orbes3.offs = [0.0, 0.0, 0.0]
	orbes3.stagger = 0.3
	orbes3.dmg = 0.6
	var coluna := {"id": "coluna", "kind": "cast", "anim": "ranged", "wind": 0.9, "strike": 0.4, "recover": 1.0,
		"unblock": true, "rmin": 0.0, "rmax": 9999.0, "w": 1.6, "cd": 3.0, "aa": true}
	var onda2 := onda.duplicate()
	onda2.id = "onda2"
	onda2.waves = 2
	return {
		1: [orbe, gesto, passo],
		2: [orbe, gesto, onda, passo],
		3: [orbes3, gesto, onda2, coluna, passo],
	}


func _on_windup(m: Dictionary) -> void:
	if m.id == "coluna":
		var pl := _player()
		if pl != null:
			var c := hazard(pl.global_position.x, "column", 30.0, m.wind + 0.4, 1.0, LIGHT)
			c.follow = pl
			c.lock_at = 0.5


func _on_strike(m: Dictionary) -> void:
	if m.id == "passo":
		var pl := _player()
		if pl == null:
			return
		var b := arena_bounds()
		var away: float = signf(e.global_position.x - pl.global_position.x)
		if away == 0.0:
			away = 1.0
		e._blink_to(clampf(pl.global_position.x + away * 200.0, b.x + 40.0, b.y - 40.0))
