extends BossBrain
## O REI — A MENTIRA (batalha final, tela 68). Luta de longe, pisca, e faz a
## luz cair. Divide a arena com o Colosso: UM ataca de cada vez (partner).
## As fases da batalha dupla vêm do FinalBattle (1ª queda → fase 2; a 1ª
## forma que se refaz → fase 3), não da vida de cada forma.

const LIGHT := Color(1.0, 0.85, 0.5)


func _on_setup() -> void:
	marks = []
	dmg_scale = 0.55
	keep_dist = Vector2(140.0, 240.0)
	gap_by_phase = [1.2, 1.0, 0.85]
	escape_hits = 3
	escape_id = "pisca"


func _build_moves() -> Dictionary:
	var orbes := {"id": "orbes", "kind": "shot", "anim": "ranged", "wind": 0.75, "strike": 0.5, "recover": 0.6,
		"offs": [0.0, 0.0, 0.0], "stagger": 0.22, "speed": 250.0, "dmg": 0.5, "color": LIGHT,
		"rmin": 90.0, "rmax": 9999.0, "w": 1.4, "cd": 2.0, "aa": true}
	var gesto := {"id": "gesto", "kind": "melee", "anim": "melee", "wind": 0.6, "strike": 0.2, "recover": 0.7,
		"off": 34.0, "sx": 2.2, "sy": 1.5, "dmg": 0.9, "kb": 300.0, "rmax": 95.0, "w": 1.5, "cd": 1.0}
	var coluna := {"id": "coluna", "kind": "cast", "anim": "ranged", "wind": 0.8, "strike": 0.4, "recover": 0.8,
		"unblock": true, "n": 1, "rmin": 0.0, "rmax": 9999.0, "w": 1.4, "cd": 3.0, "aa": true}
	var pisca := {"id": "pisca", "kind": "cast", "anim": "ranged", "wind": 0.35, "strike": 0.12, "recover": 0.3,
		"rmin": 0.0, "rmax": 9999.0, "w": 0.5, "cd": 5.0, "chain": ["orbes_p"]}
	var orbes_p := orbes.duplicate()
	orbes_p.id = "orbes_p"
	orbes_p.w = 0.0
	orbes_p.cd = 0.0
	orbes_p.wind = 0.55
	var chuva := coluna.duplicate()
	chuva.id = "chuva"
	chuva.n = 3
	chuva.cd = 5.0
	var onda := {"id": "onda", "kind": "slam", "anim": "slam", "wind": 0.75, "strike": 0.25, "recover": 0.8,
		"sx": 1.4, "nova": 70.0, "waves": 2, "wave_dmg": 0.6, "wave_speed": 260.0, "dmg": 0.7,
		"rmin": 0.0, "rmax": 9999.0, "w": 1.1, "cd": 3.5}
	var orbes5 := orbes.duplicate()
	orbes5.id = "orbes5"
	orbes5.offs = [0.0, 0.0, 0.0, 0.0, 0.0]
	orbes5.stagger = 0.16
	var chuva5 := chuva.duplicate()
	chuva5.id = "chuva5"
	chuva5.n = 5
	return {
		1: [orbes, gesto, coluna, pisca, orbes_p],
		2: [orbes, gesto, chuva, onda, pisca, orbes_p],
		3: [orbes5, gesto, chuva5, onda, pisca, orbes_p],
	}


func _on_windup(m: Dictionary) -> void:
	if not m.has("n"):
		return
	var pl := _player()
	if pl == null:
		return
	var b := arena_bounds()
	var n: int = int(m.n)
	for i in n:
		var off: float = (float(i) - float(n - 1) * 0.5) * 80.0
		var x: float = clampf(pl.global_position.x + off, b.x + 30.0, b.y - 30.0)
		var c := hazard(x, "column", 28.0, m.wind + 0.35 + 0.15 * float(i), 0.9, LIGHT)
		if i == n / 2:
			c.follow = pl
			c.lock_at = 0.45


func _on_strike(m: Dictionary) -> void:
	if m.id == "pisca":
		var pl := _player()
		if pl == null:
			return
		var b := arena_bounds()
		var away: float = -signf(pl.global_position.x - (b.x + b.y) * 0.5)
		if away == 0.0:
			away = 1.0
		e._blink_to(clampf(pl.global_position.x + away * 210.0, b.x + 40.0, b.y - 40.0))
