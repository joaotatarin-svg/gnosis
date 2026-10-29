extends Node2D
class_name BossHazard
## PERIGO TELEGRAFADO de chefe (Onda 6). Toda área que fere passa por aqui:
## primeiro o AVISO (contorno que se fecha + losango vermelho + som "imparável"),
## depois o golpe. Nada fere sem aviso; tudo é imparável (rolar/pular/sair).
## Formas:
##   "circle" — elipse no chão (raio = half_w)
##   "band"   — faixa no chão de largura 2·half_w (altura `height`, acima do chão)
##   "column" — coluna que cai do céu (largura 2·half_w, cobre toda a altura)
##   "arena"  — o chão inteiro da arena, MENOS os buracos (`holes`)
## Efeitos (além do dano): sleep (sonolência) · root (corrente) · silence (cala
## magias) · nojump (sem voo) · poison (tique) · pull (puxa pro centro) ·
## devour (morde e segura) · "" (só dano).

signal struck()

var shape: String = "circle"
var half_w: float = 50.0
var height: float = 60.0
var delay: float = 0.9             # aviso (s)
var active: float = 0.15           # golpe/efeito ativo (s)
var damage: int = 10
var tick: float = 0.0              # >0 = fere a cada `tick` s enquanto ativo
var effect: String = ""
var effect_time: float = 1.0
var color: Color = Color(1.0, 0.3, 0.3)
var knockback: float = 160.0
var follow: Node2D = null          # durante o aviso, segue este nó (x)…
var lock_at: float = 0.35          # …até faltar `lock_at` s pro golpe (aí trava)
var holes: Array = []              # "arena": outros BossHazard que são abrigo
var owner_enemy: Node = null       # quem fere (esquiva perfeita / reflexo)
var silent: bool = false           # sem som de aviso (perigos contínuos)
var hit_air: bool = true           # false = só fere quem está no chão (onda rasteira)
var safe: bool = false             # true = é ABRIGO (zona muda), não fere
var vel_x: float = 0.0             # px/s: a área ANDA enquanto ativa (onda de névoa)
var strike_sound: bool = true      # false = quem criou já tem som no impacto (pouso do salto)
var _saw_sfx: bool = false
var look: String = ""              # "saw" = Anel girando como serra (desenho próprio)
var bounce: bool = false           # bate na parede e volta (serra de Anel)
var grow: float = 0.0              # px/s: o raio CRESCE enquanto ativa (poça que se espalha)
var max_w: float = INF
var min_x: float = -INF            # para de andar nas paredes da arena
var max_x: float = INF

var _t: float = 0.0
var _hit_once: bool = false
var _tick_t: float = 0.0
var _struck: bool = false


static func make(parent: Node, pos: Vector2, p_shape: String, p_half_w: float, p_delay: float, p_damage: int, p_color: Color) -> BossHazard:
	var h := BossHazard.new()
	h.shape = p_shape
	h.half_w = p_half_w
	h.delay = p_delay
	h.damage = p_damage
	h.color = p_color
	h.z_index = -1 if p_shape in ["circle", "band", "arena"] else 20
	parent.add_child(h)
	h.global_position = pos
	return h


## R5: nada fere sem aviso próprio — mínimo de MIN_WARN s de contorno antes.
const MIN_WARN := 0.45


func _ready() -> void:
	add_to_group("boss_hazard")
	if not safe and (damage > 0 or effect != ""):
		delay = maxf(delay, MIN_WARN)
	if not silent and delay > 0.25:
		_tell_sound("tell_unblock")


func _physics_process(delta: float) -> void:
	if look == "saw" and not _saw_sfx:
		_saw_sfx = true
		_tell_sound("hz_saw")
	_t += delta
	if _t < delay:
		if follow != null and is_instance_valid(follow) and delay - _t > lock_at:
			global_position.x = lerpf(global_position.x, follow.global_position.x, minf(1.0, delta * 6.0))
		queue_redraw()
		return
	if not _struck:
		_struck = true
		struck.emit()
		if shape == "column" and strike_sound:
			_tell_sound("hz_column")
		if shape == "arena":
			Juice.shake(0.35)       # só o golpe de arena inteira treme (R3: tremor é raro)
	if _t >= delay + active:
		queue_free()
		return
	if grow != 0.0:
		half_w = minf(max_w, half_w + grow * delta)
	if vel_x != 0.0:
		global_position.x += vel_x * delta
		if global_position.x < min_x or global_position.x > max_x:
			if bounce:
				vel_x = -vel_x
				global_position.x = clampf(global_position.x, min_x, max_x)
			else:
				queue_free()
				return
	queue_redraw()
	if safe:
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null or not is_instance_valid(p):
		return
	if not contains(p.global_position):
		return
	if tick > 0.0:
		_tick_t -= delta
		if _tick_t > 0.0:
			_apply_effect(p)
			return
		_tick_t = tick
	elif _hit_once:
		return
	_hit_once = true
	_apply_effect(p)
	if damage > 0 and p.has_method("_on_hit_received"):
		p._on_hit_received(damage, global_position + Vector2(0, -10), knockback, true, owner_enemy)


func _apply_effect(p: Node) -> void:
	match effect:
		"sleep":
			p.set("status_slow", maxf(float(p.get("status_slow")), 0.25))
			if p.has_meta("boss_drowsy"):
				p.set_meta("boss_drowsy", float(p.get_meta("boss_drowsy")) + get_physics_process_delta_time())
			else:
				p.set_meta("boss_drowsy", get_physics_process_delta_time())
		"root":
			if p.has_method("apply_root"):
				p.apply_root(effect_time)
		"silence":
			p.set("silenced_timer", maxf(float(p.get("silenced_timer")), 0.3))
		"nojump":
			BossHazard.ground_player(p)
		"pull":
			p.global_position.x += signf(global_position.x - p.global_position.x) * 140.0 * get_physics_process_delta_time()


## "Sem voo": anula a subida (a gravidade puxa já). Se o combate6 der um
## `nojump_timer` à Sophia, usa ele (mais limpo); senão, corta a velocidade.
static func ground_player(p: Node) -> void:
	if "nojump_timer" in p:
		p.set("nojump_timer", maxf(float(p.get("nojump_timer")), 0.2))
		return
	if p is CharacterBody2D:
		var cb := p as CharacterBody2D
		if cb.velocity.y < 0.0:
			cb.velocity.y = 0.0


## O personagem (origem no meio do corpo; pés 24 px abaixo) está dentro?
func contains(pt: Vector2) -> bool:
	var d := pt + Vector2(0, 24) - global_position
	match shape:
		"circle":
			return absf(d.x) <= half_w and d.y < 20.0 and d.y > -46.0 and (hit_air or d.y > -16.0)
		"band":
			return absf(d.x) <= half_w and d.y <= 20.0 and d.y > -height and (hit_air or d.y > -16.0)
		"column":
			return absf(d.x) <= half_w and d.y <= 20.0
		"arena":
			if absf(d.x) > half_w or d.y > 20.0 or d.y < -height:
				return false
			if not hit_air and d.y < -16.0:
				return false
			for h in holes:
				if is_instance_valid(h) and h.contains(pt):
					return false
			return true
	return false


## Para a SONDA (bot): ameaça neste ponto (0 = nenhuma) e por onde escapar.
func threat_at(pt: Vector2) -> float:
	if safe or damage <= 0 and effect == "":
		return 0.0
	var left: float = delay - _t
	var lead: float = 2.0 if shape == "arena" else 0.6
	if left > lead or not contains(pt):
		return 0.0
	return 1.0


func escape_dir(pt: Vector2) -> String:
	if shape == "arena" and holes.is_empty() and not hit_air:
		# chão todo tomado: sobe numa plataforma (a mais perto)
		var bx := INF
		var px := pt.x
		for pf in get_tree().get_nodes_in_group("boss_platform"):
			if is_instance_valid(pf) and absf(pf.global_position.x - pt.x) < absf(bx - pt.x):
				bx = pf.global_position.x
		if bx == INF:
			return "jump"
		if absf(bx - px) < 30.0:
			return "jump"
		return "move_right" if bx > px else "move_left"
	if shape == "arena":
		# corre para o abrigo mais perto; sem abrigo: pula se for rasteira
		var best := INF
		var go := "jump" if not hit_air else "dodge"
		for h in holes:
			if is_instance_valid(h):
				var dx: float = h.global_position.x - pt.x
				if absf(dx) < best:
					best = absf(dx)
					go = "move_right" if dx > 0.0 else "move_left"
		return go
	if not hit_air:
		return "jump"
	return "move_left" if pt.x < global_position.x else "move_right"


func _tell_sound(snd: String) -> void:
	var cat = Audio.get("CATALOG")
	if cat is Dictionary:
		var sfx = cat.get("sfx", [])
		if sfx is Array and sfx.has(snd):
			Audio.play_sfx_at(snd, global_position)


func _draw() -> void:
	if look == "saw":
		_draw_saw()
		return
	var warn: bool = _t < delay
	var k: float = clampf(_t / maxf(delay, 0.01), 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_t * TAU * 2.0)
	var c := color
	var a_fill: float = (0.10 + 0.22 * k) if warn else 0.55 * (1.0 - clampf((_t - delay) / maxf(active, 0.01), 0.0, 1.0)) + 0.25
	if safe:
		a_fill = 0.18 + 0.06 * pulse
	match shape:
		"circle":
			var ry := half_w * 0.32
			var pts := _ellipse(half_w, ry)
			draw_colored_polygon(pts, Color(c.r, c.g, c.b, a_fill))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(c.r, c.g, c.b, 0.9), 1.5, true)
			if warn:
				# o contorno de dentro se FECHA até o tamanho real: lê o tempo
				var inner := _ellipse(half_w * (1.0 - k) + 4.0, ry * (1.0 - k) + 1.5)
				draw_polyline(inner + PackedVector2Array([inner[0]]), Color(1, 1, 1, 0.5 + 0.4 * k), 1.0, true)
		"band", "arena":
			var h := height if shape == "band" else 40.0
			var r := Rect2(-half_w, -h, half_w * 2.0, h + 8.0)
			draw_rect(r, Color(c.r, c.g, c.b, a_fill * 0.7))
			draw_line(Vector2(-half_w, 6), Vector2(half_w, 6), Color(c.r, c.g, c.b, 0.95), 2.0)
			if warn:
				var ww := half_w * k
				draw_line(Vector2(-ww, 2), Vector2(ww, 2), Color(1, 1, 1, 0.7), 1.5)
		"column":
			var top := -420.0
			var w := half_w * (0.35 + 0.65 * k) if warn else half_w
			draw_rect(Rect2(-w, top, w * 2.0, -top + 8.0), Color(c.r, c.g, c.b, a_fill * (0.5 if warn else 1.0)))
			draw_line(Vector2(-half_w, 6), Vector2(half_w, 6), Color(c.r, c.g, c.b, 0.95), 2.0)
			if not warn:
				draw_rect(Rect2(-w * 0.4, top, w * 0.8, -top + 8.0), Color(1, 1, 1, 0.5 * a_fill))
	if warn and not safe:
		# losango vermelho = imparável (forma + som, não só cor — NEURO R5)
		var y := -height - 14.0 if shape == "band" else -26.0
		if shape == "column":
			y = -60.0
		var s := 5.0 + 2.0 * pulse
		var dpts := PackedVector2Array([Vector2(0, y - s), Vector2(s, y), Vector2(0, y + s), Vector2(-s, y)])
		draw_colored_polygon(dpts, Color(1.0, 0.25, 0.25, 0.6 + 0.4 * k))
		draw_polyline(dpts + PackedVector2Array([dpts[0]]), Color(1, 1, 1, 0.8), 1.0)


func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Anel-serra: aro dourado girando com dentes, rente ao chão (pule por cima).
func _draw_saw() -> void:
	var warn: bool = _t < delay
	var r: float = half_w
	var c := Vector2(0, -r)
	var a0: float = _t * 9.0 * signf(vel_x if vel_x != 0.0 else 1.0)
	var al: float = 0.45 if warn else 1.0
	draw_circle(c, r + 4.0, Color(color.r, color.g, color.b, 0.15 * al))
	draw_arc(c, r, 0, TAU, 28, Color(color, al), 3.0, true)
	draw_arc(c, r * 0.55, 0, TAU, 20, Color(1, 1, 1, 0.6 * al), 1.5, true)
	for k in 8:
		var a := a0 + TAU * float(k) / 8.0
		var d := Vector2(cos(a), sin(a))
		draw_colored_polygon(PackedVector2Array([c + d * r, c + d.rotated(0.25) * (r + 6.0), c + d.rotated(0.4) * r]), Color(color, al))
	if warn:
		draw_line(Vector2(-r, 4), Vector2(r, 4), Color(1.0, 0.3, 0.3, 0.8), 2.0)
