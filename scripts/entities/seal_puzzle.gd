extends Node2D
class_name SealPuzzle
## Mini-puzzle: 3 Selos (obeliscos). Golpeie na ordem em que brilham.
## Errou → reseta com flash vermelho. Completou → chuva de faíscas.
## Ordem é determinística pela tela (mesma tela = mesma ordem).

const PERMS := [[0,1,2], [1,2,0], [2,0,1], [0,2,1], [1,0,2], [2,1,0]]

var screen: int = 1
var order: Array = []
var step: int = 0
var solved: bool = false
var pillars: Array = []


func _ready() -> void:
	order = PERMS[screen % PERMS.size()]
	for i in 3:
		var pil := SealPillar.new()
		pil.index = i
		pil.position = Vector2(i * 90.0 - 90.0, 0)
		add_child(pil)
		pil.struck.connect(_on_struck)
		pillars.append(pil)
	_update_glow()


func _update_glow() -> void:
	for i in 3:
		var st := "idle"
		var pos: int = order.find(i)
		if pos < step:
			st = "locked"
		elif pos == step:
			st = "next"
		pillars[i].set_state(st)


func _on_struck(index: int) -> void:
	if solved:
		return
	if index == order[step]:
		step += 1
		if step >= 3:
			_solve()
		else:
			_update_glow()
	else:
		# errou: reseta com flash vermelho em todos
		step = 0
		for pil in pillars:
			pil.flash_error()
		_update_glow()


func _solve() -> void:
	solved = true
	for pil in pillars:
		pil.set_state("locked")
	var gold := Color(1.0, 0.9, 0.5)
	AoeNova.spawn(get_parent(), global_position + Vector2(0, -10), 0, 90.0, gold)
	ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -30), gold)
	Progression.add_orbs(30 + screen * 3)
	Juice.shake(0.4)


class SealPillar extends Node2D:
	signal struck(index: int)

	var index: int = 0
	var state: String = "idle"     # idle / next / locked
	var _err: float = 0.0
	var _hurt: Hurtbox

	func _ready() -> void:
		_hurt = Hurtbox.new()
		_hurt.team = "enemy"
		_hurt.collision_layer = 8
		_hurt.collision_mask = 8
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(22, 52)
		shape.shape = rect
		shape.position = Vector2(0, -14)
		_hurt.add_child(shape)
		add_child(_hurt)
		_hurt.hit_received.connect(_on_hit)

	func set_state(s: String) -> void:
		state = s

	func flash_error() -> void:
		_err = 0.35

	func _on_hit(_d: int, _s: Vector2, _k: float, _u: bool = false, _a: Node = null) -> void:
		struck.emit(index)

	func _process(delta: float) -> void:
		if _err > 0.0:
			_err -= delta
		queue_redraw()

	func _draw() -> void:
		var stone := Color(0.28, 0.24, 0.38)
		var glyph := Color(0.45, 0.4, 0.55)
		match state:
			"next":
				var pulse := 0.6 + sin(Time.get_ticks_msec() * 0.008) * 0.4
				glyph = Color(1.0, 0.9, 0.5, clampf(pulse, 0.3, 1.0))
			"locked":
				glyph = Color(1.0, 0.92, 0.6)
		if _err > 0.0:
			glyph = Color(1.0, 0.3, 0.25)
		# obelisco
		draw_colored_polygon(PackedVector2Array([
			Vector2(-11, 12), Vector2(-8, -38), Vector2(0, -44), Vector2(8, -38), Vector2(11, 12)
		]), stone)
		draw_polyline(PackedVector2Array([
			Vector2(-11, 12), Vector2(-8, -38), Vector2(0, -44), Vector2(8, -38), Vector2(11, 12), Vector2(-11, 12)
		]), Color(0.1, 0.08, 0.16), 1.5, true)
		# glifo (triângulo do olho) — brilha conforme o estado
		if state == "locked" or state == "next" or _err > 0.0:
			draw_circle(Vector2(0, -18), 8.0, Color(glyph.r, glyph.g, glyph.b, 0.2))
		draw_arc(Vector2(0, -18), 5.0, 0, TAU, 12, glyph, 1.8)
		draw_circle(Vector2(0, -18), 1.8, glyph)
