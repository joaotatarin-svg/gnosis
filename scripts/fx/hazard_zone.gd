extends Node2D
class_name HazardZone
## Zona de perigo no chão, desenhada por código. Usada pelos Arcontes:
##  - "sleep"  (Torpor): dentro dela a Sophia anda devagar (névoa do sono).
##  - "poison" (Praga): dano contínuo enquanto ficar em cima.
##  - "pillar" (Onda 6, inimigos): AVISO no chão (anel que enche por `warn` s) e
##    depois uma coluna de luz que fere UMA vez quem estiver dentro (qualquer
##    altura). Ataque de área de conjuradores e voadores: lê-se e sai-se dele.
## Some sozinha após `duration`.

var kind: String = "sleep"
var radius: float = 60.0
var duration: float = 4.0
var color: Color = Color(0.6, 0.55, 0.9)
var hostile_to: String = "player"   # "player" (zona de Arconte) ou "enemy" (magia da Sophia)
var damage: int = 0                 # dano por tick quando hostil a inimigos

var warn: float = 0.8               # pillar: tempo de aviso antes da coluna
var _t: float = 0.0
var _tick: float = 0.0
var _struck: bool = false


static func spawn(parent: Node, pos: Vector2, p_kind: String, p_radius: float, p_duration: float, p_color: Color, p_hostile_to: String = "player", p_damage: int = 0) -> void:
	var z := HazardZone.new()
	z.kind = p_kind
	z.radius = p_radius
	z.duration = p_duration
	z.color = p_color
	z.hostile_to = p_hostile_to
	z.damage = p_damage
	z.z_index = -1          # fica atrás dos personagens (é chão)
	parent.add_child(z)
	z.global_position = pos


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()
	if hostile_to == "enemy":
		# Magia da Sophia: inimigos dentro tomam dano (praga) ou ficam lentos (sono).
		_tick -= delta
		if _tick > 0.0:
			return
		_tick = 0.6
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e):
				continue
			if absf(e.global_position.x - global_position.x) <= radius and absf(e.global_position.y - global_position.y) < 70.0:
				if kind == "sleep":
					if e.has_method("apply_slow"):
						e.apply_slow(0.8)
				elif e.has_method("apply_damage"):
					e.apply_damage(damage, global_position, 30.0)
		return
	var p := get_tree().get_first_node_in_group("player")
	if kind == "pillar":
		if not _struck and _t >= warn:
			_struck = true
			Juice.shake(0.18)
			if p != null and is_instance_valid(p) and absf(p.global_position.x - global_position.x) <= radius 					and p.global_position.y > global_position.y - 260.0 and p.global_position.y < global_position.y + 20.0:
				p._on_hit_received(damage, global_position + Vector2(0, -40), 150.0, false, null)
		return
	if p != null and is_instance_valid(p):
		var inside := absf(p.global_position.x - global_position.x) <= radius \
			and absf(p.global_position.y - global_position.y) < 60.0
		if inside:
			if kind == "sleep":
				p.status_slow = 0.25
			else:
				_tick -= delta
				if _tick <= 0.0:
					_tick = 0.7
					var dmg := 3 + int(GameManager.current_screen / 10)
					p._on_hit_received(dmg, global_position, 40.0, true, null)


func _draw() -> void:
	if kind == "pillar":
		_draw_pillar()
		return
	var life := 1.0 - _t / duration
	var fade := minf(1.0, life * 3.0)          # apaga suave no fim
	var pulse := 0.5 + sin(_t * 4.0) * 0.5
	var ry := radius * 0.32
	# elipse no chão
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		pts.append(Vector2(cos(a) * radius, sin(a) * ry))
	draw_colored_polygon(pts, Color(color.r, color.g, color.b, (0.16 + 0.1 * pulse) * fade))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(color.r, color.g, color.b, 0.55 * fade), 1.5, true)
	# bolhas / fiapos subindo (sono = névoa lenta; praga = bolhas rápidas)
	var speed := 0.6 if kind == "sleep" else 1.6
	for i in 6:
		var ph := fmod(_t * speed + float(i) * 0.37, 1.0)
		var x := sin(float(i) * 2.1 + _t * 0.3) * radius * 0.7
		var y := -ph * (18.0 if kind == "sleep" else 12.0)
		var r := (4.0 if kind == "sleep" else 2.2) * (1.0 - ph * 0.6)
		draw_circle(Vector2(x, y), r, Color(color.r, color.g, color.b, (0.35 - ph * 0.3) * fade))


## Coluna de luz: aviso (anel + enchimento que cresce + fio de luz) → golpe.
func _draw_pillar() -> void:
	var ry := radius * 0.32
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		pts.append(Vector2(cos(a) * radius, sin(a) * ry))
	if not _struck:
		var k := clampf(_t / maxf(warn, 0.01), 0.0, 1.0)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(color.r, color.g, color.b, 0.85), 1.5, true)
		var inner := PackedVector2Array()
		for q in pts:
			inner.append(q * k)
		draw_colored_polygon(inner, Color(color.r, color.g, color.b, 0.22 + 0.2 * k))
		draw_line(Vector2(0, 0), Vector2(0, -240), Color(color.r, color.g, color.b, 0.12 + 0.25 * k), 1.0 + 2.0 * k)
		return
	var f := clampf(1.0 - (_t - warn) / maxf(duration - warn, 0.01), 0.0, 1.0)
	var w := radius * (0.55 + 0.45 * f)
	draw_rect(Rect2(-w, -260, w * 2.0, 260), Color(color.r, color.g, color.b, 0.35 * f))
	draw_rect(Rect2(-w * 0.4, -260, w * 0.8, 260), Color(1, 1, 1, 0.55 * f))
	draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.4 * f))


## Atalho do pilar: aviso de `p_warn` s e dano `dmg` uma vez.
static func pillar(parent: Node, pos: Vector2, p_radius: float, p_warn: float, dmg: int, p_color: Color) -> void:
	var z := HazardZone.new()
	z.kind = "pillar"
	z.radius = p_radius
	z.warn = p_warn
	z.duration = p_warn + 0.35
	z.color = p_color
	z.damage = dmg
	z.z_index = -1
	parent.add_child(z)
	z.global_position = pos
