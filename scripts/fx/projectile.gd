extends Area2D
class_name Projectile
## Projétil de luz vetorial (desenhado por código): orbe com halo + rastro.
## Monta a própria colisão em _ready — não precisa de .tscn.

var direction: int = 1
var speed: float = 420.0
var damage: int = 30
var knockback: float = 200.0
var color: Color = Color(1.0, 0.9, 0.5)
var pierce: bool = true            # atravessa inimigos (Onda Radiante)
var explode_radius: float = 0.0    # >0 = explode em área ao acertar (Esfera Solar)
var target_team: String = "enemy"  # "enemy" = tiro do player; "player" = tiro de Arconte
var lifetime: float = 1.2
var root_time: float = 0.0        # >0 = corrente: prende o alvo no lugar (Galila)
var slow_time: float = 0.0        # >0 = sono: deixa o alvo lento (Sonâmbulo)

var _time: float = 0.0
var _trail: Array[Vector2] = []


func _ready() -> void:
	collision_layer = 8
	collision_mask = 8
	monitoring = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	_time += delta
	_trail.push_front(global_position)
	if _trail.size() > 8:
		_trail.pop_back()
	queue_redraw()
	if _time >= lifetime:
		_vanish()


func _draw() -> void:
	# rastro (no espaço local)
	for i in _trail.size():
		var p := to_local(_trail[i])
		var a := 0.35 * (1.0 - float(i) / 8.0)
		draw_circle(p, 5.0 * (1.0 - float(i) / 10.0), Color(color.r, color.g, color.b, a))
	if target_team == "player":
		draw_arc(Vector2.ZERO, 7.0, 0, TAU, 28, Color(color, 0.9), 0.8, true)
	# orbe com halo pulsante
	var pulse := 1.0 + sin(_time * 18.0) * 0.15
	draw_circle(Vector2.ZERO, 9.0 * pulse, Color(color.r, color.g, color.b, 0.25))
	draw_circle(Vector2.ZERO, 5.5, color)
	draw_circle(Vector2.ZERO, 2.4, Color(1, 1, 1, 0.95))


func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox and area.team == target_team:
		area.receive_hit(damage, global_position, knockback)
		if root_time > 0.0 and area.owner != null and area.owner.has_method("apply_root"):
			area.owner.apply_root(root_time)
		if slow_time > 0.0 and area.owner != null and area.owner.has_method("apply_slow"):
			area.owner.apply_slow(slow_time)
		Juice.hit_stop(0.04)
		Juice.shake(0.25)
		ImpactBurst.spawn(get_parent(), global_position, color)
		if explode_radius > 0.0:
			AoeNova.spawn(get_parent(), global_position, int(damage * 0.6), explode_radius, color)
			_vanish()
		elif not pierce:
			_vanish()


func _vanish() -> void:
	set_physics_process(false)
	set_deferred("monitoring", false)   # dentro do sinal de área não pode mudar direto
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(queue_free)
