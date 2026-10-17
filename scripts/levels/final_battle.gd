extends Node2D
class_name FinalBattle
## A BATALHA FINAL (tela 68, a Mente): as DUAS formas do Demiurgo ao mesmo
## tempo — o Rei (a mentira, PNG) e o Colosso Oco (a verdade, procedural).
## Regra (Ornstein & Smough): quando uma cai, a outra a REFAZ em REVIVE_AFTER s;
## precisam cair num intervalo parecido. Os 7 Anéis giram em volta da arena e
## spawnam larvas sem parar (pressão, não chefes). Ao caírem juntas → `won`.

signal won

const REVIVE_AFTER := 14.0
const RING_SPAWN_EVERY := 6.0
const MAX_LARVAS := 3

var enemy_scene: PackedScene
var arena_center: Vector2 = Vector2(640, 250)
var forms: Array = []                # [Enemy, Enemy]
var down_since: Dictionary = {}      # enemy -> tempo real desde que caiu
var _spawn_timer: float = 4.0
var _larvas: Array = []
var _t: float = 0.0
var _done: bool = false
var _first_fall_done: bool = false
var _rings_free: bool = false       # a anagnórise levou os Anéis (não desenha mais)


func start(parent: Node, scene: PackedScene, spawn_points: Array) -> void:
	enemy_scene = scene
	var rei := _spawn("rei_final", parent, spawn_points[0].global_position)
	var col := _spawn("colosso", parent, spawn_points[spawn_points.size() - 1].global_position + Vector2(120, 0))
	forms = [rei, col]
	for f in forms:
		f.revivable = true
		f.defeated.connect(_on_form_down)
	get_tree().call_group("hud", "toast", "As duas formas precisam cair juntas.")
	# Card das duas faces (letterbox), como todo chefe ao nascer.
	Gnosis.boss_card("demiurgo", RunManager.MAX_SCREEN)


func _spawn(id: String, parent: Node, pos: Vector2) -> Enemy:
	var e: Enemy = enemy_scene.instantiate()
	e.type_id = id
	parent.add_child(e)
	e.global_position = pos
	return e


func _on_form_down(e: Enemy) -> void:
	if _done:
		return
	down_since[e] = 0.0
	var other := _other(e)
	if other != null and is_instance_valid(other) and down_since.has(other):
		# As duas caíram dentro da janela: QUEBRA.
		_done = true
		Juice.slow_mo(0.12, 1.6)
		Juice.shake(1.0)
		for l in _larvas:
			if is_instance_valid(l) and l.estate != Enemy.EState.DEAD:
				ImpactBurst.spawn(get_parent(), l.global_position, Color(1, 0.9, 0.6))
				l.queue_free()
		won.emit()
		return
	get_tree().call_group("hud", "toast", Narrative.final_form_fell(e.display_name))
	# A primeira queda devolve o 7º Anel (a Coroa): pico de poder no clímax.
	if not _first_fall_done:
		_first_fall_done = true
		var last := Progression.next_stolen_ring()
		if last != "":
			Progression.restore_ring(last)
		# M9: o pico de poder coincide com o de memória — legendas, sem pausar
		# (o relógio de 14 s corre). "Eu desci de propósito... para te buscar."
		Juice.slow_mo(0.2, 1.2)
		Gnosis.captions(Narrative.seventh_ring())
		_coroa_returns()



## Cena D (Staging): os 7 Anéis param onde estão e passam para a encenação,
## que os faz descer em espiral até a Sophia. Devolve as posições (mundo).
func release_rings() -> Array:
	var pts: Array = []
	for k in 7:
		pts.append(_ring_pos(k))
	_rings_free = true
	queue_redraw()
	return pts

## M9: o Anel da Coroa sai da órbita e voa para a mão dela (tempo real: o
## slow-mo da queda não o atrasa); clarão dourado na chegada.
func _coroa_returns() -> void:
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl == null:
		return
	var gem := Node2D.new()
	gem.z_index = 30
	gem.draw.connect(func() -> void:
		gem.draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.85, 0.45, 0.22))
		gem.draw_arc(Vector2.ZERO, 7.0, 0, TAU, 16, Color(1.0, 0.9, 0.55), 2.5)
		gem.draw_circle(Vector2.ZERO, 2.5, Color(1, 1, 0.9)))
	get_parent().add_child(gem)
	gem.global_position = _ring_pos(6)
	var t := gem.create_tween().set_ignore_time_scale(true)
	t.tween_method(func(k: float) -> void:
		if is_instance_valid(pl):
			var to := pl.global_position + Vector2(0, -20)
			gem.global_position = _ring_pos(6).lerp(to, k) + Vector2(0, -sin(k * PI) * 50.0), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		Audio.play_sfx("ring_gain")
		VfxLibrary.dodge_perfect(get_parent(), gem.global_position)
		gem.queue_free())


func _other(e: Enemy) -> Enemy:
	for f in forms:
		if f != e:
			return f
	return null


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	# Ressurreição: a forma caída se refaz se a outra demorar.
	for e in down_since.keys():
		if not is_instance_valid(e):
			continue
		down_since[e] += delta
		if down_since[e] >= REVIVE_AFTER:
			down_since.erase(e)
			e.revive(0.45)
			get_tree().call_group("hud", "toast", Narrative.final_revive(e.display_name))
			Juice.shake(0.6)
			break
	# Os Anéis spawnam larvas.
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = RING_SPAWN_EVERY
		_larvas = _larvas.filter(func(l): return is_instance_valid(l) and l.estate != Enemy.EState.DEAD)
		if _larvas.size() < MAX_LARVAS:
			var k := randi() % 7
			var pos := _ring_pos(k)
			var l := _spawn("larva" if k % 2 == 0 else "larva_ardente", get_parent(), Vector2(pos.x, arena_center.y))
			ImpactBurst.spawn(get_parent(), l.global_position, Color(1, 0.85, 0.5))
			_larvas.append(l)
	queue_redraw()


func _ring_pos(k: int) -> Vector2:
	var a := _t * 0.35 + TAU * float(k) / 7.0
	return arena_center + Vector2(cos(a) * 360.0, -140.0 + sin(a) * 40.0)


## Os 7 Anéis girando em volta da arena (glifo por Arconte, brilho pulsante).
func _draw() -> void:
	if _rings_free:
		return
	for k in 7:
		var p := to_local(_ring_pos(k))
		var pulse := 0.6 + 0.4 * sin(_t * 3.0 + float(k))
		var col := Color(1.0, 0.85, 0.45)
		if k < Bestiary.bosses.size():
			col = Bestiary.bosses[k].profile.eye
		draw_circle(p, 16.0, Color(col.r, col.g, col.b, 0.12 * pulse))
		draw_arc(p, 11.0, 0, TAU, 20, Color(col.r, col.g, col.b, 0.9), 3.0)
		draw_arc(p, 6.0, 0, TAU, 12, Color(1, 1, 1, 0.5 * pulse), 1.5)
	# a órbita
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * float(i) / 48.0
		pts.append(to_local(arena_center + Vector2(cos(a) * 360.0, -140.0 + sin(a) * 40.0)))
	pts.append(pts[0])
	draw_polyline(pts, Color(1, 0.9, 0.6, 0.12), 1.0)
