extends Node2D
class_name SummonTotem
## OBJETIVO "TOTEM" — um obelisco profano na zona que CHAMA reforços: enquanto a
## zona luta, a cada 5,5 s ele invoca um bicho do Éon (no máximo 3). Quebre o
## totem (golpes) e as invocações param — com faíscas de recompensa. Se a zona
## acabar com ele de pé, ele racha sozinho (sem prêmio). Escolha: limpar a wave
## ou correr pro totem no meio dela.
## Quem liga é o Level (arm/disarm); a invocação usa o `enemy_scene` do Level e
## entra na conta da wave por `_on_minion` (precisa morrer também).

signal destroyed

const EVERY := 5.5
const MAX_SUMMONS := 3

var hazard_kind: String = "totem"
var pool: Array = []           # type_ids que ele invoca (os da tela)
var screen: int = 1
var _hp: int = 60
var _max_hp: int = 60
var _armed: bool = false
var _timer: float = 2.5
var _summons: int = 0
var _dead: bool = false
var _flash: float = 0.0
var _t: float = 0.0
var _hurt: Hurtbox


func _enter_tree() -> void:
	add_to_group("lv6_objective")
	add_to_group("fg_guard")          # CENARIO5: o objetivo não fica atrás de coluna
	set_meta("fg_half", 60.0)


func _ready() -> void:
	HazardArt.setup(self)
	_max_hp = 50 + screen * 4
	_hp = _max_hp
	_hurt = Hurtbox.new()
	_hurt.team = "enemy"
	_hurt.collision_layer = 8
	_hurt.collision_mask = 8
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 64)
	shape.shape = rect
	shape.position = Vector2(0, -32)
	_hurt.add_child(shape)
	add_child(_hurt)
	_hurt.hit_received.connect(_on_hit)


## A zona trancou: começa a chamar.
func arm() -> void:
	_armed = true


## A zona acabou: se ainda de pé, racha sozinho (sem prêmio).
func disarm() -> void:
	_armed = false
	if not _dead:
		_crumble(false)


func is_dead() -> bool:
	return _dead


func _on_hit(dmg: int, _s: Vector2, _k: float, _u: bool = false, _a: Node = null) -> void:
	if _dead:
		return
	_hp -= maxi(1, dmg)
	_flash = 0.12
	Audio.play_sfx_at("hz_totem_hit", global_position, 0.1)
	DamageNumber.spawn(get_parent(), global_position + Vector2(0, -40), dmg, Color(1.0, 0.85, 0.5))
	if _hp <= 0:
		_crumble(true)


func _crumble(reward: bool) -> void:
	_dead = true
	_armed = false
	_hurt.set_deferred("monitorable", false)
	_hurt.set_deferred("monitoring", false)
	var col := Color(0.9, 0.4, 0.35) if reward else Color(0.5, 0.45, 0.5)
	ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -30), col, true)
	if reward:
		Audio.play_sfx_at("hz_totem_break", global_position, 0.05)
		Progression.add_orbs(12 + screen)
		Juice.shake(0.25)
		get_tree().call_group("hud", "toast", "Totem quebrado: os reforços cessam.")
	destroyed.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()
	if not _armed or _dead or GameManager.state != GameManager.State.PLAYING:
		return
	_timer -= delta
	if _timer > 0.0 or _summons >= MAX_SUMMONS:
		return
	_timer = EVERY
	_summon()


func _summon() -> void:
	var lv := get_parent()
	if lv == null or pool.is_empty() or not ("enemy_scene" in lv):
		return
	var scene: PackedScene = lv.get("enemy_scene")
	if scene == null:
		return
	var e: Enemy = scene.instantiate()
	e.type_id = String(pool[(_summons + screen) % pool.size()])
	lv.add_child(e)
	e.global_position = global_position + Vector2(0, -60)
	_summons += 1
	if lv.has_method("_on_minion"):
		lv.call("_on_minion", e)
	VfxLibrary.portal(lv, global_position + Vector2(0, -30), Color(0.9, 0.4, 0.35), 0.6)
	Audio.play_sfx_at("hz_totem_summon", global_position, 0.1)


func _draw() -> void:
	if _dead and modulate.a <= 0.0:
		return
	if HazardArt.has("totem"):
		_draw_art()
	else:
		_draw_code()


## PINTURA (Onda 7): aceso (parado) → PULSANDO quando a invocação se
## aproxima (o cristal acende, contorno violeta a 2 Hz) → quebrado. Golpe =
## véu claro (sem escurecer a pintura); rachas por código mostram a vida.
func _draw_art() -> void:
	var red := Color(0.95, 0.35, 0.3)
	var violet := Color(0.75, 0.45, 1.0)
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, 26.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if _dead:
		HazardArt.draw(self, "totem", 2, Vector2.ZERO)
		return
	var k := 1.0 - clampf(_timer / EVERY, 0.0, 1.0) if _armed else 0.0
	var f := 1 if k > 0.6 else 0
	if _armed:
		var a := (0.25 + 0.6 * k) * (0.5 + 0.5 * HazardArt.pulse(_t))
		HazardArt.draw_outline(self, "totem", f, Vector2.ZERO, Color(violet, a), 1.5)
	HazardArt.draw(self, "totem", f, Vector2.ZERO)
	if _flash > 0.0:
		HazardArt.draw_wash(self, "totem", f, Vector2.ZERO, Color(1, 0.95, 0.9, 0.55 * HazardArt.flash_k()))
	# rachas = vida perdida
	var dmg := 1.0 - float(_hp) / float(maxi(1, _max_hp))
	var cracks := int(dmg * 6.0)
	for i in cracks:
		var y := -12.0 - float(i) * 8.0
		draw_line(Vector2(-7 + i % 3, y), Vector2(5 - i % 2 * 3, y - 6), Color(red, 0.75), 1.0)
	# brilho do cristal: pulsa mais rápido perto de invocar (≤ 2 Hz no máximo)
	var eye := HazardArt.point("totem", "eye", Vector2(0, -60))
	var g := 0.5 + 0.5 * sin(_t * TAU * (0.6 + 1.4 * k))
	draw_circle(eye, 6.0 + 4.0 * k * g, Color(violet, (0.12 + 0.25 * k) * HazardArt.flash_k()))
	# contas: quantas invocações ainda tem
	for i in MAX_SUMMONS - _summons:
		draw_circle(Vector2(-6 + i * 6, -10), 1.8, Color(red, 0.8))


## Desenho por CÓDIGO (fallback sem a pintura; também a prancha "antes").
func _draw_code() -> void:
	var red := Color(0.95, 0.35, 0.3)
	var stone := Color(0.18, 0.13, 0.16) if _flash <= 0.0 else Color(0.9, 0.85, 0.8)
	# sombra
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# obelisco com rachas (mais rachas = menos vida)
	var body := PackedVector2Array([Vector2(-13, 0), Vector2(-9, -58), Vector2(0, -70), Vector2(9, -58), Vector2(13, 0)])
	draw_colored_polygon(body, LevelHazard.INK)
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -1), Vector2(-7.5, -57), Vector2(0, -67), Vector2(7.5, -57), Vector2(11, -1)]), stone)
	var dmg := 1.0 - float(_hp) / float(maxi(1, _max_hp))
	var cracks := int(dmg * 6.0)
	for i in cracks:
		var y := -10.0 - float(i) * 9.0
		draw_line(Vector2(-8 + i % 3, y), Vector2(5 - i % 2 * 3, y - 6), Color(red, 0.7), 1.0)
	# olho que pulsa mais rápido perto de invocar
	if not _dead:
		var k := 1.0 - clampf(_timer / EVERY, 0.0, 1.0) if _armed else 0.2
		var r := 4.0 + 2.0 * sin(_t * (3.0 + 10.0 * k))
		draw_circle(Vector2(0, -44), r + 3.0, Color(red, 0.2 + 0.3 * k))
		draw_circle(Vector2(0, -44), r, Color(red.lightened(0.3), 0.85))
		# contas: quantas invocações ainda tem
		for i in MAX_SUMMONS - _summons:
			draw_circle(Vector2(-6 + i * 6, -20), 1.8, Color(red, 0.8))
