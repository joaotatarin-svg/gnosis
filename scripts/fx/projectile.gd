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
## Onda 6 (inimigos6): tiro MIRADO em qualquer direção (voadores atiram de cima).
## Zero = o antigo tiro horizontal por `direction`.
var aim: Vector2 = Vector2.ZERO
## Onda 6: tiro em ARCO (arc_gravity > 0): sobe e cai; ao tocar `ground_y` vira a
## zona `land_kind` ("poison"/"sleep") no chão — o arremesso do Portador/Sonâmbulo.
var arc_gravity: float = 0.0
var ground_y: float = INF          # y do chão (some ao tocar; INF = não confere)
var land_kind: String = ""
var land_radius: float = 40.0
var land_time: float = 3.0
var _vel: Vector2 = Vector2.ZERO
## Onda 6: TELEGUIADO lento — vira até `homing` rad/s na direção do alvo
## (fogo-fátuo, uivo). Lento de propósito: dá pra correr dele e esquivar.
var homing: float = 0.0
var homing_target: Node2D = null
## Onda 6: FORMA do tiro dos inimigos (a mesma leitura no jogo todo):
##  "" = orbe (o antigo) · "bolt" seta curta (rajada) · "wisp" chama que ondula
##  (teleguiado) · "seed" semente que gira (arco) · "spike" lâmina rasteira (chão)
##  · "page" folha que gira (Bibliotecário). Se o VFX7 publicar
##  `VfxLibrary.projectile_look(proj, look, color)`, ele assume o desenho.
var look: String = ""
var _premium: bool = false

var _time: float = 0.0
var _trail: Array[Vector2] = []


func _ready() -> void:
	collision_layer = 8
	collision_mask = 8
	monitoring = true
	z_index = 29                       # acima da névoa do Torpor (EonRule, z 28): tiro sempre se lê
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	area_entered.connect(_on_area_entered)
	Audio.play_sfx("proj_fire")
	_premium = _vfx7_look()
	if not _premium:
		VfxLibrary.projectile_trail(self, color)


## Gancho da API visual do VFX7 (dir7/vfx7): usa se existir — sem ela, o desenho
## por código abaixo. Procura o método no script (não quebra se não existir).
static var _vfx7_checked: int = -1
func _vfx7_look() -> bool:
	if _vfx7_checked < 0:
		_vfx7_checked = 0
		for m in (VfxLibrary as Script).get_script_method_list():
			if String(m.name) == "projectile_look":
				_vfx7_checked = 1
				break
	if _vfx7_checked == 0:
		return false
	var r = (VfxLibrary as Script).call("projectile_look", self, look if look != "" else "orb", color)
	return r != null and r != false


func _physics_process(delta: float) -> void:
	if arc_gravity > 0.0 or aim != Vector2.ZERO or homing > 0.0:
		if _vel == Vector2.ZERO:
			_vel = (aim.normalized() if aim != Vector2.ZERO else Vector2(direction, 0.0)) * speed
		if homing > 0.0 and homing_target != null and is_instance_valid(homing_target):
			var want: float = (homing_target.global_position + Vector2(0, -6) - global_position).angle()
			var cur: float = _vel.angle()
			var turn: float = clampf(wrapf(want - cur, -PI, PI), -homing * delta, homing * delta)
			_vel = Vector2.from_angle(cur + turn) * speed
		_vel.y += arc_gravity * delta
		position += _vel * delta
		if global_position.y >= ground_y:
			_land()
			return
	else:
		position.x += direction * speed * delta
	_time += delta
	_trail.push_front(global_position)
	if _trail.size() > 8:
		_trail.pop_back()
	queue_redraw()
	if _time >= lifetime:
		_vanish()


func _draw() -> void:
	if _premium:
		return                              # o VFX7 desenha
	if look != "":
		_draw_look()
		return
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
		# Status ANTES do dano: o dano liga os i-frames de dano da Sophia (0,6 s)
		# e o apply_root dela recusa durante i-frames — na ordem antiga a corrente
		# da Galila/do Carcereiro NUNCA prendia (achado do Combate2). Esquiva e
		# bloqueio continuam escapando (o apply_root confere antes).
		if root_time > 0.0 and area.owner != null and area.owner.has_method("apply_root"):
			area.owner.apply_root(root_time)
		if slow_time > 0.0 and area.owner != null and area.owner.has_method("apply_slow"):
			area.owner.apply_slow(slow_time)
		area.receive_hit(damage, global_position, knockback)
		Juice.hit_stop(0.04)
		Juice.shake(0.2)             # R3: vale o maior pedido do quadro (o dano na Sophia pede o seu)
		Audio.play_sfx_at("proj_hit", global_position)
		ImpactBurst.spawn(get_parent(), global_position, color)
		if explode_radius > 0.0:
			VfxLibrary.hit(get_parent(), global_position, true, color)
			AoeNova.spawn(get_parent(), global_position, int(damage * 0.6), explode_radius, color)
			_vanish()
		elif not pierce:
			_vanish()


## As formas dos tiros de inimigo (cor do inimigo, núcleo claro, rastro próprio).
func _draw_look() -> void:
	var dir: Vector2 = _vel.normalized() if _vel != Vector2.ZERO else Vector2(direction, 0)
	var ang := dir.angle()
	var c := color
	var white := Color(1, 1, 1, 0.95)
	for i in _trail.size():
		var p := to_local(_trail[i])
		var k := 1.0 - float(i) / 8.0
		draw_circle(p, (3.5 if look == "bolt" else 4.5) * k, Color(c.r, c.g, c.b, 0.3 * k))
	match look:
		"bolt":
			var tail := -dir * 16.0
			draw_line(tail, Vector2.ZERO, Color(c, 0.55), 5.0, true)
			draw_line(tail * 0.6, Vector2.ZERO, white, 2.0, true)
			draw_colored_polygon(PackedVector2Array([dir * 6.0, dir.orthogonal() * 3.0, -dir.orthogonal() * 3.0]), white)
		"wisp":
			var fl := 1.0 + sin(_time * 22.0) * 0.18
			draw_circle(Vector2.ZERO, 10.0 * fl, Color(c.r, c.g, c.b, 0.22))
			for j in 3:
				var a := ang + PI + sin(_time * 9.0 + j * 2.1) * 0.6
				draw_line(Vector2.ZERO, Vector2.from_angle(a) * (10.0 + j * 3.0), Color(c, 0.5 - j * 0.12), 3.0 - j * 0.7, true)
			draw_circle(Vector2.ZERO, 5.0, c)
			draw_circle(Vector2(1.5, -1.5), 2.2, white)
		"seed":
			var rot := _time * 12.0
			var pts := PackedVector2Array()
			for j in 4:
				pts.append(Vector2.from_angle(rot + j * PI * 0.5) * (7.0 if j % 2 == 0 else 3.5))
			draw_colored_polygon(pts, c)
			draw_circle(Vector2.ZERO, 2.0, white)
		"spike":
			for j in 3:
				var x := -float(j) * 9.0 * signf(dir.x if dir.x != 0.0 else 1.0)
				var hgt := 12.0 - j * 3.0 + sin(_time * 30.0 + j) * 2.0
				draw_colored_polygon(PackedVector2Array([Vector2(x - 4.0, 4.0), Vector2(x, 4.0 - hgt), Vector2(x + 4.0, 4.0)]), Color(c, 0.9 - j * 0.25))
			draw_line(Vector2(-22.0 * signf(dir.x if dir.x != 0.0 else 1.0), 4.0), Vector2(6.0 * signf(dir.x if dir.x != 0.0 else 1.0), 4.0), Color(c, 0.5), 2.0)
		"page":
			var r := _time * 8.0
			var q := PackedVector2Array([Vector2(-5, -6).rotated(r), Vector2(5, -6).rotated(r), Vector2(5, 6).rotated(r), Vector2(-5, 6).rotated(r)])
			draw_colored_polygon(q, Color(0.92, 0.9, 0.82, 0.95))
			draw_polyline(q + PackedVector2Array([q[0]]), Color(c, 0.9), 1.0, true)
			draw_line(Vector2(-3, -2).rotated(r), Vector2(3, -2).rotated(r), Color(c, 0.8), 1.0)
			draw_line(Vector2(-3, 1).rotated(r), Vector2(3, 1).rotated(r), Color(c, 0.8), 1.0)
		_:
			draw_circle(Vector2.ZERO, 8.0, Color(c.r, c.g, c.b, 0.25))
			draw_circle(Vector2.ZERO, 5.0, c)
			draw_circle(Vector2.ZERO, 2.2, white)
	# aviso de que é tiro INIMIGO: aro fino na cor
	draw_arc(Vector2.ZERO, 8.0, 0, TAU, 20, Color(c, 0.7), 0.8, true)


## Tocou o chão (tiro em arco/mirado): estoura e, se pedir, deixa a zona.
func _land() -> void:
	ImpactBurst.spawn(get_parent(), global_position, color)
	if land_kind != "":
		HazardZone.spawn(get_parent(), Vector2(global_position.x, ground_y), land_kind, land_radius, land_time, color)
	_vanish()


func _vanish() -> void:
	set_physics_process(false)
	set_deferred("monitoring", false)   # dentro do sinal de área não pode mudar direto
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(queue_free)
