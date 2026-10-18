extends Node2D
class_name FinalBattle
## A BATALHA FINAL (tela 68, a Mente): as DUAS formas do Demiurgo ao mesmo
## tempo — o Rei (a mentira, PNG) e o Colosso Oco (a verdade, procedural).
## Regra (Ornstein & Smough): quando uma cai, a outra a REFAZ em REVIVE_AFTER s;
## precisam cair num intervalo parecido. Os 7 Anéis giram em volta da arena e
## spawnam larvas sem parar (pressão, não chefes). Ao caírem juntas → `won`.

signal won

const REVIVE_AFTER := 14.0
const RING_SPAWN_EVERY := 9.0
const MAX_LARVAS := 2
# Onde as formas nascem (px a partir da parede esquerda da arena trancada da
# Mente — Level._lock_final_arena). A vista (zoom 1,2) cobre ~533 px de mundo:
# Sophia a 70, Rei (~85 px de largura) a 215, Colosso (~160 px) a 420.
const ARENA_LEFT := Level.ZONE_FIRST_X - Level.ZONE_HALF
const REI_DX := 215.0
const COL_DX := 420.0
# Na luta, as duas formas não se EMPILHAM (o Colosso por cima do Rei virava um
# borrão dourado): se ficam a menos de APART_MIN px por STACK_TIME s, o Rei
# (a mentira, que luta à distância) pisca para o outro lado da Sophia.
const APART_MIN := 120.0
const STACK_TIME := 0.5
const BLINK_COOLDOWN := 3.5
const BLINK_DIST := 190.0

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
var _stack_t: float = 0.0           # há quanto tempo as formas estão empilhadas
var _blink_cd: float = 0.0
var _revives: int = 0               # quantas vezes uma forma se refez (fases da batalha)
# Sorteio PRÓPRIO da batalha (Balance): o randi() global também é consumido
# pelo Áudio/gibs em quantidades que dependem do relógio real — a tela 68 dava
# dano diferente em duas rodadas iguais do bot. Semeado pela tela.
var _rng: RandomNumberGenerator


func start(parent: Node, scene: PackedScene, spawn_points: Array) -> void:
	enemy_scene = scene
	_rng = _screen_rng(RunManager.MAX_SCREEN)
	# F2: as duas formas nascem DENTRO do quadro e separadas — o Rei à
	# esquerda-centro, o Colosso à direita (a arena trancada começa em
	# ARENA_LEFT; a Sophia acorda a 70 px dela e a câmera mostra ARENA_LEFT..+533).
	var y: float = (spawn_points[0] as Node2D).global_position.y if not spawn_points.is_empty() else 250.0
	var rei := _spawn("rei_final", parent, Vector2(ARENA_LEFT + REI_DX, y))
	var col := _spawn("colosso", parent, Vector2(ARENA_LEFT + COL_DX, y))
	forms = [rei, col]
	for f in forms:
		f.revivable = true
		f.defeated.connect(_on_form_down)
	# chefes6: um ataca de cada vez (nunca dois telegrafos juntos)
	if rei.brain != null and col.brain != null:
		rei.brain.partner = col.brain
		col.brain.partner = rei.brain
	get_tree().call_group("hud", "toast", "As duas formas precisam cair juntas.")
	# Card das duas faces (letterbox), como todo chefe ao nascer.
	Gnosis.boss_card("demiurgo", RunManager.MAX_SCREEN)


## RNG da tela: `RunManager.screen_rng(tela)` (Técnico) se existir; senão um
## próprio, com a mesma semente sempre (determinístico por tela).
func _screen_rng(s: int) -> RandomNumberGenerator:
	if RunManager.has_method("screen_rng"):
		var r = RunManager.call("screen_rng", s)
		if r is RandomNumberGenerator:
			return r
	var own := RandomNumberGenerator.new()
	own.seed = hash("final_%d" % s)
	return own


func _spawn(id: String, parent: Node, pos: Vector2) -> Enemy:
	var e: Enemy = enemy_scene.instantiate()
	e.type_id = id
	parent.add_child(e)
	e.global_position = pos
	# Nasce virado para a Sophia (no card o mundo está congelado).
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	var vis = e.get("visual")
	if pl != null and vis is Node2D and pl.global_position.x < pos.x:
		(vis as Node2D).scale.x = -absf((vis as Node2D).scale.x)
	return e


## F2: separa as formas empilhadas — o Rei pisca para o outro lado da Sophia.
func _keep_apart(delta: float) -> void:
	_blink_cd -= delta
	if forms.size() < 2:
		return
	var rei: Enemy = forms[0]
	var col: Enemy = forms[1]
	if not (is_instance_valid(rei) and is_instance_valid(col)) or down_since.has(rei) or down_since.has(col):
		_stack_t = 0.0
		return
	if absf(rei.global_position.x - col.global_position.x) >= APART_MIN:
		_stack_t = 0.0
		return
	_stack_t += delta
	if _stack_t < STACK_TIME or _blink_cd > 0.0 or rei.estate != Enemy.EState.CHASE:
		return
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl == null:
		return
	var lo := ARENA_LEFT + 50.0
	var hi := ARENA_LEFT + Level.ZONE_HALF * 2.0 - 50.0
	var side := -signf(col.global_position.x - pl.global_position.x)
	if side == 0.0:
		side = -1.0
	var x := clampf(pl.global_position.x + side * BLINK_DIST, lo, hi)
	if absf(x - col.global_position.x) < APART_MIN or absf(x - pl.global_position.x) < 90.0:
		# Ela está contra a parede: o outro lado não cabe; vai além do Colosso.
		x = clampf(col.global_position.x - side * BLINK_DIST, lo, hi)
		if absf(x - col.global_position.x) < APART_MIN:
			return
	if rei.has_method("_blink_to"):
		rei.call("_blink_to", x)
	_blink_cd = BLINK_COOLDOWN
	_stack_t = 0.0


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
		# chefes6: FASE 2 da batalha dupla — a forma que ficou de pé se enfurece
		if other != null and is_instance_valid(other) and other.brain != null and other.brain.phase < 2:
			other.brain.set_phase(2)
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
	_keep_apart(delta)
	# Ressurreição: a forma caída se refaz se a outra demorar.
	for e in down_since.keys():
		if not is_instance_valid(e):
			continue
		down_since[e] += delta
		if down_since[e] >= REVIVE_AFTER:
			down_since.erase(e)
			e.revive(0.45)
			# chefes6: a 1ª forma que se refaz leva as DUAS à fase 3
			_revives += 1
			for f in forms:
				if is_instance_valid(f) and f.brain != null:
					f.brain.revived(3 if _revives >= 1 else 2, f == e)
			get_tree().call_group("hud", "toast", Narrative.final_revive(e.display_name))
			Juice.shake(0.6)
			break
	# Os Anéis spawnam larvas.
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = RING_SPAWN_EVERY
		_larvas = _larvas.filter(func(l): return is_instance_valid(l) and l.estate != Enemy.EState.DEAD)
		if _larvas.size() < MAX_LARVAS:
			var k := (_rng.randi() if _rng != null else randi()) % 7
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
