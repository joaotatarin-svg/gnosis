extends LevelHazard
class_name SporePod
## PRAGA — casulo de esporos no chão. Ritmo de 4,2 s: incha (aviso 0,8 s,
## pulsa verde) → SOLTA uma nuvem de esporos (raio ~56, 1,8 s) que corrói quem
## estiver dentro, Sophia ou inimigo. Dá pra estourar o casulo com 2 golpes:
## ele solta um último sopro (fraco) e some de vez, com faíscas. Volta a crescer
## só quando a tela recarrega.

const PERIOD := 4.2
const SWELL_AT := 2.4
const BURST_AT := 3.2
const CLOUD_TIME := 1.8
const TICK := 0.6
const RADIUS := 56.0

var _hp: int = 2
var _dead: bool = false
var _cloud: float = 0.0        # s de nuvem restantes
var _cloud_weak: bool = false
var _tick_cd: float = 0.0
var _burst_done: bool = false
var _hurt: Hurtbox


func _ready() -> void:
	hazard_kind = "spores"
	z_index = 2
	_hurt = Hurtbox.new()
	_hurt.team = "enemy"           # o golpe da Sophia acerta
	_hurt.collision_layer = 8
	_hurt.collision_mask = 8
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 26)
	shape.shape = rect
	shape.position = Vector2(0, -14)
	_hurt.add_child(shape)
	add_child(_hurt)
	_hurt.hit_received.connect(_on_hit)


func _on_hit(_d: int, _s: Vector2, _k: float, _u: bool = false, _a: Node = null) -> void:
	if _dead:
		return
	_hp -= 1
	Audio.play_sfx_at("enemy_hurt", global_position, 0.1)
	if _hp <= 0:
		_dead = true
		_hurt.set_deferred("monitorable", false)
		_hurt.set_deferred("monitoring", false)
		_cloud = CLOUD_TIME * 0.5
		_cloud_weak = true
		ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -14), Color(0.6, 0.9, 0.4))
		Progression.add_orbs(4)


func _tick(delta: float) -> void:
	_tick_cd = maxf(0.0, _tick_cd - delta)
	if not _dead:
		var c := _cycle(PERIOD)
		if c < SWELL_AT:
			_burst_done = false
		elif c >= BURST_AT and not _burst_done:
			_burst_done = true
			_cloud = CLOUD_TIME
			_cloud_weak = false
			var p0 := _player()
			if p0 != null and absf(p0.global_position.x - global_position.x) < 300.0:
				Audio.play_sfx_at("cast_praga", global_position, 0.1)
	if _cloud <= 0.0:
		return
	_cloud -= delta
	if _tick_cd > 0.0:
		return
	_tick_cd = TICK
	var area := Rect2(global_position.x - RADIUS, global_position.y - 90.0, RADIUS * 2.0, 96.0)
	var dmg := maxi(1, hazard_damage(2) / (2 if _cloud_weak else 1))
	hurt_enemies_in(area, dmg * 2, global_position, 20.0)
	if _live() and player_in(area) and not _cloud_weak:
		hurt_player(dmg, global_position, 40.0, true)


func _draw() -> void:
	if HazardArt.has("spore_pod"):
		_draw_art()
	else:
		_draw_code()


## Nuvem de esporos (código, sobre a pintura também).
func _draw_cloud() -> void:
	var green := Color(0.55, 0.85, 0.35)
	if _cloud > 0.0:
		var k := clampf(_cloud / CLOUD_TIME, 0.0, 1.0)
		for i in 7:
			var a := TAU * float(i) / 7.0 + _t * 0.4
			var rr := RADIUS * (0.4 + 0.5 * (1.0 - k)) * (0.8 + 0.2 * sin(_t * 3.0 + i))
			draw_circle(Vector2(cos(a) * rr * 0.9, -30.0 + sin(a) * rr * 0.5), 18.0 + 6.0 * (1.0 - k), Color(green, 0.12 * k + 0.04))


## PINTURA (Onda 7): fechado (respira) → INCHANDO no aviso (as veias verdes
## acendem, cresce e treme, contorno vermelho pulsante) → ESTOURADO enquanto
## a nuvem sai → volta a crescer. Morto (2 golpes): a casca estourada, apagada.
func _draw_art() -> void:
	if _dead:
		HazardArt.draw(self, "spore_pod", 2, Vector2.ZERO, 0.0, Vector2.ONE * 0.9, Color(0.45, 0.45, 0.4))
		_draw_cloud()
		return
	var c := _cycle(PERIOD)
	var swell := 0.0
	if c >= SWELL_AT and c < BURST_AT:
		swell = (c - SWELL_AT) / (BURST_AT - SWELL_AT)
	var f := 1 if swell > 0.3 else 0
	var s := 1.0 + 0.08 * swell + sin(_t * (5.0 + 14.0 * swell)) * (0.01 + 0.025 * swell)
	var mod := Color.WHITE
	if _cloud > CLOUD_TIME * 0.5 and not _cloud_weak:
		f = 2                                # estourado enquanto a nuvem sai
		s = 1.0
	elif _cloud > 0.0 and not _cloud_weak:
		var g := 1.0 - (_cloud / (CLOUD_TIME * 0.5))
		s = 0.7 + 0.3 * g                    # volta a crescer
		mod.a = 0.5 + 0.5 * g
	var sc := Vector2(1.0 + (s - 1.0) * 0.6, s)
	warn_outline("spore_pod", f, Vector2.ZERO, swell, 0.0, sc)
	HazardArt.draw(self, "spore_pod", f, Vector2.ZERO, 0.0, sc, mod)
	_draw_cloud()


## Desenho por CÓDIGO (fallback sem a pintura; também a prancha "antes").
func _draw_code() -> void:
	var green := Color(0.55, 0.85, 0.35)
	if _cloud > 0.0:
		var k := clampf(_cloud / CLOUD_TIME, 0.0, 1.0)
		for i in 7:
			var a := TAU * float(i) / 7.0 + _t * 0.4
			var rr := RADIUS * (0.4 + 0.5 * (1.0 - k)) * (0.8 + 0.2 * sin(_t * 3.0 + i))
			draw_circle(Vector2(cos(a) * rr * 0.9, -30.0 + sin(a) * rr * 0.5), 18.0 + 6.0 * (1.0 - k), Color(green, 0.12 * k + 0.04))
	if _dead:
		# casca murcha
		draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(-8, -6), Vector2(0, -4), Vector2(9, -7), Vector2(12, 0)]), Color(0.2, 0.25, 0.15))
		return
	var c := _cycle(PERIOD)
	var swell := 0.0
	if c >= SWELL_AT and c < BURST_AT:
		swell = (c - SWELL_AT) / (BURST_AT - SWELL_AT)
	var r := 11.0 + 5.0 * swell + sin(_t * (6.0 + 20.0 * swell)) * (0.6 + 1.6 * swell)
	# caule e bulbo (contorno escuro + corpo + pintas que acendem no aviso)
	draw_line(Vector2(0, 0), Vector2(0, -10), INK, 5.0)
	draw_circle(Vector2(0, -12 - r * 0.6), r + 1.5, INK)
	draw_circle(Vector2(0, -12 - r * 0.6), r, Color(0.3, 0.42, 0.2))
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.6
		draw_circle(Vector2(cos(a) * r * 0.55, -12 - r * 0.6 + sin(a) * r * 0.5), 1.8, Color(green.lightened(0.3), 0.3 + 0.7 * swell))
