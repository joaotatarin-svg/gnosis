extends BossBrain
## O COLOSSO OCO — A VERDADE (batalha final, tela 68). Gigante de pedra e
## ouro, lento e enorme: tudo nele é chão tremendo. Divide a arena com o Rei
## (um ataca de cada vez). Fases vêm do FinalBattle.
## Fase 1: Punhos (amarelos, ondas para os dois lados — PULE), Pisotear
## (vermelho, em volta dele), Investida. Fase 2: Salto (cai onde ela está) e
## punhos em dobro. Fase 3: DESABAMENTO — o teto da Mente cai em colunas.
## Janelas: depois do Pisotear e do Salto ele fica preso no chão.

const STONE := Color(1.0, 0.75, 0.4)


func _on_setup() -> void:
	marks = []
	dmg_scale = 0.38
	keep_dist = Vector2(40.0, 110.0)
	gap_by_phase = [1.2, 1.0, 0.85]
	escape_hits = 4
	escape_id = "pisotear"


func _build_moves() -> Dictionary:
	var punhos := {"id": "punhos", "kind": "slam", "anim": "slam", "wind": 0.9, "strike": 0.25, "recover": 0.9,
		"off": 20.0, "sx": 3.0, "sy": 1.3, "nova": 110.0, "waves": 2, "wave_dmg": 0.55, "wave_speed": 230.0,
		"dmg": 1.0, "rmax": 130.0, "w": 2.0, "cd": 1.2}
	var pisotear := {"id": "pisotear", "kind": "slam", "anim": "slam", "wind": 0.7, "strike": 0.25, "recover": 1.3,
		"unblock": true, "sx": 4.0, "sy": 1.5, "nova": 140.0, "dmg": 0.9, "kb": 380.0, "rmax": 120.0, "w": 1.0, "cd": 3.0}
	var investida := {"id": "investida", "kind": "charge", "anim": "charge", "wind": 0.85, "strike": 0.6,
		"recover": 1.0, "unblock": true, "speed": 330.0, "dmg": 1.0, "sx": 1.8, "rmin": 150.0, "rmax": 9999.0, "w": 1.2, "cd": 4.0}
	var salto := {"id": "salto", "kind": "leap", "anim": "slam", "wind": 0.7, "strike": 1.5, "recover": 1.3,
		"unblock": true, "dmg": 1.0, "land_r": 72.0, "waves": 2, "wave_dmg": 0.5, "rmin": 0.0, "rmax": 9999.0,
		"w": 1.0, "cd": 7.0, "aa": true}
	var dobro := punhos.duplicate()
	dobro.id = "dobro"
	dobro.chain = ["dobro_b"]
	dobro.recover = 0.3
	var dobro_b := punhos.duplicate()
	dobro_b.id = "dobro_b"
	dobro_b.wind = 0.6
	dobro_b.rmax = 9999.0
	dobro_b.w = 0.0
	dobro_b.cd = 0.0
	var desabamento := {"id": "desabamento", "kind": "cast", "anim": "slam", "wind": 0.9, "strike": 0.4, "recover": 1.0,
		"unblock": true, "rmin": 0.0, "rmax": 9999.0, "w": 1.3, "cd": 7.0, "aa": true}
	return {
		1: [punhos, pisotear, investida],
		2: [punhos, dobro, dobro_b, pisotear, investida, salto],
		3: [dobro, dobro_b, pisotear, salto, desabamento],
	}


func _on_strike(m: Dictionary) -> void:
	if m.id == "desabamento":
		Juice.shake(0.8)
		var b := arena_bounds()
		var w := b.y - b.x
		var skip := rng.randi() % 6
		for i in 6:
			if i == skip:
				continue        # sempre sobra um vão seguro
			var x: float = b.x + w * (float(i) + 0.5) / 6.0
			hazard(x, "column", 34.0, 1.1 + 0.18 * float(i % 3), 0.9, STONE)
