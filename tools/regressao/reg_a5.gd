extends "res://tools/regressao/reg_base.gd"
## A5 (QA_UX_BUGS, Alta): a antecipação da câmera (±90 px em `offset`) é somada
## DEPOIS dos limites; perto da parede esquerda, virada para a direita, a
## Sophia sai da tela (x de tela −48 px na tela 10) e a câmera mostra além da
## parede. Esperado: a Sophia sempre inteira na tela e a câmera nunca além dos
## limites (zona trancada ou arena).

const MARGEM := 12.0     # px de tela (base 640×360) que o corpo precisa de folga


func rodar() -> void:
	# 1) Zona trancada (tela 10, zona do Arconte: limites [150, 1090]).
	var lv := await level_at(10)
	_limpa(lv)
	var c := lv.zone_center(0)
	lv._lock_zone(c)
	await _parada_na_parede(lv, c - Level.ZONE_HALF, "zona")

	# 2) Arena inteira (parede fixa esquerda).
	lv = await level_at(5)
	_limpa(lv)
	await _parada_na_parede(lv, Level.WALL_LEFT, "arena")


func _limpa(lv: Level) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	lv.zones = []


## Encosta a Sophia na parede esquerda, virada para a DIREITA, parada 2 s.
func _parada_na_parede(lv: Level, parede: float, nome: String) -> void:
	var pl: Player = lv.player
	pl.global_position = Vector2(parede + 40.0, Level.GROUND_Y - 14.0)
	pl.velocity = Vector2.ZERO
	# vira para a direita com um toque curto e para
	Input.action_press("move_right")
	await frames(4)
	Input.action_release("move_right")
	pl.global_position.x = parede + 40.0
	await wait(2.0)
	var cam: Camera2D = pl.get_node("Camera2D")
	var vis := tela()
	var scr := pl.get_global_transform_with_canvas().origin
	var centro := cam.get_screen_center_position()
	var borda_esq := centro.x - vis.size.x * 0.5 / cam.zoom.x
	info("%s: facing=%d player_x=%.0f tela_x=%.0f centro=%.0f limites=[%d,%d] offset=%s vis=%s" % [nome, pl.facing, pl.global_position.x, scr.x, centro.x, cam.limit_left, cam.limit_right, str(cam.offset), str(vis.size)])
	check(nome + "_sophia_na_tela", scr.x >= MARGEM and scr.x <= vis.size.x - MARGEM, "x de tela=%.0f (tela 0..%.0f)" % [scr.x, vis.size.x])
	check(nome + "_camera_nao_passa_da_parede_olhando_direita", borda_esq >= float(cam.limit_left) - 1.0, "borda esquerda visível=%.0f limite=%d" % [borda_esq, cam.limit_left])
	# Agora virada para a ESQUERDA, colada na parede: a câmera não pode mostrar além dela.
	Input.action_press("move_left")
	await frames(4)
	Input.action_release("move_left")
	pl.global_position.x = parede + 40.0
	await wait(2.0)
	centro = cam.get_screen_center_position()
	borda_esq = centro.x - vis.size.x * 0.5 / cam.zoom.x
	scr = pl.get_global_transform_with_canvas().origin
	info("%s (esquerda): facing=%d tela_x=%.0f centro=%.0f" % [nome, pl.facing, scr.x, centro.x])
	check(nome + "_camera_nao_passa_da_parede_olhando_esquerda", borda_esq >= float(cam.limit_left) - 1.0, "borda esquerda visível=%.0f limite=%d (mostra %.0f px além)" % [borda_esq, cam.limit_left, float(cam.limit_left) - borda_esq])
	check(nome + "_sophia_na_tela_olhando_esquerda", scr.x >= MARGEM and scr.x <= vis.size.x - MARGEM, "x de tela=%.0f" % scr.x)
