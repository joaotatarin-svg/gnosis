extends Node2D
class_name Chest
## Baú de faíscas: acerte com um golpe pra abrir. Desenhado por código.
## Recompensa determinística por tela: faíscas, e em telas certas uma peça
## de gear (item que muda a aparência do herói).

var screen: int = 1
var opened: bool = false
var _hurt: Hurtbox
var _wobble: float = 0.0
var painted_chest: Sprite2D
var painted_lid: Sprite2D


func _ready() -> void:
	painted_chest = PaintedLibrary.sprite(1,32.0)
	painted_chest.texture = PaintedLibrary.region("architecture",Rect2(575,337,360,173))
	painted_chest.offset.y = -86.5
	painted_chest.position.y = 12
	add_child(painted_chest)
	painted_lid = Sprite2D.new()
	painted_lid.texture = PaintedLibrary.region("architecture",Rect2(575,205,360,132))
	painted_lid.material = PaintedLibrary.material()
	painted_lid.scale = Vector2.ONE*32.0/305.0
	painted_lid.offset = Vector2(0,-66)
	painted_lid.position.y = 12-173*32.0/305.0
	add_child(painted_lid)
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
	draw_set_transform(Vector2(0,12),0,Vector2(1,0.22))
	draw_circle(Vector2.ZERO,21,Color(0,0,0,0.3))
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if painted_chest != null:
		painted_chest.modulate = Color(0.52,0.59,0.59) if opened else Color.WHITE
		painted_chest.rotation = sin(_wobble*40)*_wobble*0.15
	if opened:
		painted_lid.rotation = -0.55
		painted_lid.position.y = -12
		draw_arc(Vector2(0,-8),13,PI,TAU,30,Color("d6c58f"),1.3,true)
	else:
		draw_circle(Vector2(0,-4),2,Color("bef6df"))


func _on_hit(_dmg: int, _src: Vector2, _kb: float, _unblock: bool = false, _atk: Node = null) -> void:
	if opened:
		return
	_wobble = 0.2
	Audio.play_sfx("chest_hit")
	opened = true
	_hurt.queue_free()
	_give_reward()


func _give_reward() -> void:
	Audio.play_sfx("chest_open")
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
