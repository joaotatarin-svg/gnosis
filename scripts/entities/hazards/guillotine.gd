extends LevelHazard
class_name Guillotine
## COROA — a guilhotina da guarda. A lâmina espera no alto; ritmo de 3,2 s:
## parada → AVISO 0,7 s (a sombra cresce no chão, a lâmina treme, brilho
## vermelho) → CAI (rápida) → fica cravada 0,5 s → sobe. Imparável: passe antes
## ou depois, ou esquive através. Corta inimigos também (muito) — atraia a escolta.

const PERIOD := 3.2
const WARN_AT := 1.9
const DROP_AT := 2.6
const DROP_TIME := 0.1
const STUCK_END := 3.0
const TOP := -190.0           # altura da lâmina parada (local)
const HALF_W := 24.0

var _hit_done: bool = false
var _warned: bool = false


func _ready() -> void:
	hazard_kind = "guilhotina"
	z_index = 4


## Altura da BASE da lâmina (local; 0 = chão).
func _blade_y() -> float:
	var c := _cycle(PERIOD)
	if c < DROP_AT:
		var shake := sin(_t * 70.0) * 1.5 if c >= WARN_AT else 0.0
		return TOP + shake
	if c < DROP_AT + DROP_TIME:
		var k := (c - DROP_AT) / DROP_TIME
		return lerpf(TOP, 0.0, k * k)
	if c < STUCK_END:
		return 0.0
	return lerpf(0.0, TOP, (c - STUCK_END) / (PERIOD - STUCK_END))


func _tick(_delta: float) -> void:
	var c := _cycle(PERIOD)
	if c < WARN_AT:
		_hit_done = false
		_warned = false
		return
	if c < DROP_AT:
		if not _warned:
			_warned = true
			var p0 := _player()
			if p0 != null and absf(p0.global_position.x - global_position.x) < 300.0:
				Audio.play_sfx_at("tell_unblock", global_position + Vector2(0, TOP), 0.05)
		return
	if c >= DROP_AT + DROP_TIME * 0.6 and c < STUCK_END and not _hit_done:
		_hit_done = true
		var area := Rect2(global_position.x - HALF_W, global_position.y - 110.0, HALF_W * 2.0, 116.0)
		hurt_enemies_in(area, hazard_damage(5) * 4, global_position + Vector2(0, -60), 60.0)
		if _live() and player_in(area):
			hurt_player(hazard_damage(5), global_position + Vector2(0, -60), 120.0, true)
		var p := _player()
		if p != null and absf(p.global_position.x - global_position.x) < 320.0:
			Audio.play_sfx_at("hit_heavy", global_position, 0.05)
			Juice.shake(0.18)
			VfxLibrary.dust(get_parent(), global_position)


func _draw() -> void:
	var by := _blade_y()
	var c := _cycle(PERIOD)
	var gold := Color(0.85, 0.7, 0.35)
	# trilhos (duas hastes) e travessa no alto
	for sx in [-1.0, 1.0]:
		var x: float = sx * (HALF_W + 6.0)
		draw_line(Vector2(x, TOP - 30.0), Vector2(x, 0), INK, 5.0)
		draw_line(Vector2(x, TOP - 30.0), Vector2(x, 0), Color(0.3, 0.25, 0.2), 2.5)
	draw_rect(Rect2(-HALF_W - 12.0, TOP - 40.0, HALF_W * 2.0 + 24.0, 10.0), INK)
	draw_line(Vector2(-HALF_W - 10.0, TOP - 36.0), Vector2(HALF_W + 10.0, TOP - 36.0), Color(gold, 0.6), 1.2)
	# sombra no chão (cresce no aviso — a leitura principal)
	if c >= WARN_AT and c < DROP_AT + DROP_TIME:
		var k := clampf((c - WARN_AT) / (DROP_AT - WARN_AT), 0.0, 1.0)
		draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.22))
		draw_circle(Vector2.ZERO, HALF_W * (0.5 + 0.7 * k), Color(0, 0, 0, 0.25 + 0.35 * k))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		draw_line(Vector2(-HALF_W, 3), Vector2(HALF_W, 3), Color(WARN_COL, 0.3 + 0.5 * k), 1.5)
	# lâmina (trapézio com gume em diagonal) + peso em cima
	var blade := PackedVector2Array([Vector2(-HALF_W, by - 46.0), Vector2(HALF_W, by - 46.0), Vector2(HALF_W, by - 14.0), Vector2(-HALF_W, by)])
	draw_colored_polygon(blade, INK)
	draw_colored_polygon(PackedVector2Array([Vector2(-HALF_W + 2, by - 44.0), Vector2(HALF_W - 2, by - 44.0), Vector2(HALF_W - 2, by - 15.0), Vector2(-HALF_W + 2, by - 2.0)]), Color(0.42, 0.44, 0.5))
	draw_line(Vector2(HALF_W - 2, by - 15.0), Vector2(-HALF_W + 2, by - 2.0), Color(0.9, 0.92, 1.0, 0.9), 1.4, true)
	draw_rect(Rect2(-HALF_W - 2.0, by - 58.0, HALF_W * 2.0 + 4.0, 12.0), INK)
	draw_line(Vector2(-HALF_W, by - 52.0), Vector2(HALF_W, by - 52.0), Color(gold, 0.7), 1.5)
	draw_line(Vector2(0, TOP - 30.0), Vector2(0, by - 58.0), Color(0.5, 0.45, 0.4, 0.8), 1.5)
	if c >= WARN_AT and c < DROP_AT:
		draw_circle(Vector2(0, by - 30.0), 10.0 + 3.0 * sin(_t * 30.0), Color(WARN_COL, 0.25))
