extends "res://tools/regressao/reg_base.gd"
## A4 (QA_UX_BUGS, Alta): a Sophia morta CONGELA no ar (o _physics_process sai
## antes do move_and_slide) e nunca toca a animação "dead" (fica em jump/idle).
## Esperado: morreu no ar → cai até o chão; de pé ou no ar → anima "dead".

const CHAO_TOL := 6.0


func rodar() -> void:
	# 1) Morte no ar.
	var lv := await level_at(2)
	_limpa(lv)
	var pl: Player = lv.player
	await wait(0.3)
	var chao_y := pl.global_position.y
	await tecla_segura(KEY_SPACE, 0.22)
	var y_ar := pl.global_position.y
	if chao_y - y_ar < 20.0:
		quebrado("o pulo não subiu (y chão=%.0f y=%.0f)" % [chao_y, y_ar])
		return
	pl.health.take_damage(99999)
	await wait(1.2)
	var y_depois := pl.global_position.y
	check("morte_no_ar_cai_ate_o_chao", absf(y_depois - chao_y) <= CHAO_TOL, "y_chao=%.0f y_no_golpe=%.0f y_1.2s=%.0f no_chao=%s" % [chao_y, y_ar, y_depois, str(pl.is_on_floor())])
	check("morte_no_ar_anima_dead", _anim(pl) == "dead", "estado=%d anim=%s" % [pl.state, _anim(pl)])

	# 2) Morte de pé.
	lv = await level_at(2)
	_limpa(lv)
	pl = lv.player
	await wait(0.4)
	pl.health.take_damage(99999)
	await wait(0.6)
	check("morte_de_pe_anima_dead", _anim(pl) == "dead", "estado=%d anim=%s" % [pl.state, _anim(pl)])


func _limpa(lv: Level) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	lv.zones = []


func _anim(pl: Player) -> String:
	if pl.visual == null:
		return "<sem visual>"
	for k in ["anim_state", "anim", "current_anim"]:
		if k in pl.visual:
			return str(pl.visual.get(k))
	return "<?>"


func tecla_segura(k: Key, s: float) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	await wait(s)
	var r := e.duplicate()
	r.pressed = false
	Input.parse_input_event(r)
	await frames(1)
