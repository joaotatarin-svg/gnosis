extends Node2D
class_name Chest
## Baú de faíscas: acerte com um golpe pra abrir. Desenhado por código.
## Recompensa determinística por tela: faíscas, e em telas certas uma peça
## de gear (item que muda a aparência do herói).

var screen: int = 1
var opened: bool = false
var _hurt: Hurtbox
var _wobble: float = 0.0


func _ready() -> void:
	_hurt = Hurtbox.new()
	_hurt.team = "enemy"           # golpes do player acertam
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 24)
	shape.shape = rect
	_hurt.add_child(shape)
	_hurt.collision_layer = 8
	_hurt.collision_mask = 8
	add_child(_hurt)
	_hurt.hit_received.connect(_on_hit)


func _process(delta: float) -> void:
	if _wobble > 0.0:
		_wobble -= delta
	queue_redraw()


func _draw() -> void:
	var gold := Color(0.85, 0.70, 0.35)
	var dark := Color(0.32, 0.24, 0.12)
	var glow := 0.5 + sin(Time.get_ticks_msec() * 0.004) * 0.25
	var wob: float = sin(_wobble * 40.0) * 2.0 if _wobble > 0.0 else 0.0
	draw_set_transform(Vector2(wob, 0), 0.0, Vector2.ONE)
	if opened:
		# aberto: tampa levantada, luz saindo
		draw_circle(Vector2(0, -8), 16.0, Color(1.0, 0.9, 0.5, 0.18))
		draw_colored_polygon(PackedVector2Array([Vector2(-15,0), Vector2(15,0), Vector2(13,12), Vector2(-13,12)]), dark)
		draw_colored_polygon(PackedVector2Array([Vector2(-15,-2), Vector2(-13,-14), Vector2(13,-16), Vector2(15,-4)]), dark.lightened(0.15))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-15,-6), Vector2(15,-6), Vector2(13,12), Vector2(-13,12)]), dark)
		draw_colored_polygon(PackedVector2Array([Vector2(-16,-6), Vector2(16,-6), Vector2(14,-14), Vector2(-14,-14)]), dark.lightened(0.2))
		# fecho brilhante (a "faísca" presa)
		draw_circle(Vector2(0, -5), 4.5, Color(1.0, 0.9, 0.5, glow * 0.4))
		draw_circle(Vector2(0, -5), 2.5, Color(1.0, 0.92, 0.6, glow + 0.3))
		draw_line(Vector2(-16, -6), Vector2(16, -6), gold, 1.5)


func _on_hit(_dmg: int, _src: Vector2, _kb: float, _unblock: bool = false, _atk: Node = null) -> void:
	if opened:
		return
	_wobble = 0.2
	opened = true
	_hurt.queue_free()
	_give_reward()


func _give_reward() -> void:
	ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -10), Color(1.0, 0.9, 0.5))
	# Em telas múltiplas de 5-1 (4, 9, 14...), tenta dropar uma peça de gear inédita.
	var gave_item := false
	if screen % 5 == 4:
		for it in Bestiary.items:
			if not Progression.items.has(it.feature):
				Progression.items.append(it.feature)
				Progression.stats_changed.emit()   # atualiza o visual do herói
				gave_item = true
				break
	var sparks := 15 + screen * 2
	if gave_item:
		sparks = int(sparks * 0.5)
	Progression.add_orbs(sparks)
	# cura leve de bônus
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.health != null:
		p.health.heal(10)
