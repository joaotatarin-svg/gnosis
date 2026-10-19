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
	hazard_kind = "guillotine"
	z_index = 4
	if HazardArt.has("gu_frame"):
		# a MOLDURA fica atrás da Sophia (ela passa por dentro); a lâmina, na frente
		_back = HazardArt.back_layer(self, _draw_back)


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


## Moldura pintada (camada de trás).
func _draw_back(layer: Node2D) -> void:
	if HazardArt.has("gu_frame"):
		HazardArt.draw(layer, "gu_frame", 0, Vector2.ZERO)


func _draw() -> void:
	if HazardArt.has("gu_frame") and HazardArt.has("gu_blade"):
		_draw_art()
	else:
		_draw_code()


## PINTURA (Onda 7): a lâmina pintada desce pelos trilhos da moldura no
## MESMO tempo da lógica (o curso pintado é um pouco mais curto que o da
## lógica: a altura é mapeada em proporção — a queda dura 0,1 s, não se nota).
## AVISO por cima, por código: sombra crescendo no chão + linha vermelha +
## contorno vermelho pulsante (2 Hz) na lâmina + tremor (já na altura).
func _draw_art() -> void:
	var by := _blade_y()
	var c := _cycle(PERIOD)
	var open_base := HazardArt.num("gu_frame", "blade_open_base", TOP)
	var vy := by * (open_base / TOP)
	var bsz := HazardArt.size("gu_blade")
	var ban := HazardArt.anchor("gu_blade")
	var blade_top := vy - ban.y
	# haste da lâmina (da travessa até o topo da lâmina)
	var rod_top := HazardArt.num("gu_frame", "rod_top", TOP - 30.0)
	if HazardArt.has("gu_rod") and blade_top > rod_top:
		var rw := HazardArt.size("gu_rod").x
		draw_texture_rect(HazardArt.tex("gu_rod"), Rect2(-rw * 0.5, rod_top, rw, blade_top - rod_top), false)
	# sombra no chão (cresce no aviso — a leitura principal)
	var warn := 0.0
	if c >= WARN_AT and c < DROP_AT + DROP_TIME:
		warn = clampf((c - WARN_AT) / (DROP_AT - WARN_AT), 0.0, 1.0)
		draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.22))
		draw_circle(Vector2.ZERO, HALF_W * (0.5 + 0.7 * warn), Color(0, 0, 0, 0.25 + 0.35 * warn))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		warn_line(Vector2(-HALF_W, 3), Vector2(HALF_W, 3), Color(WARN_COL, 0.4 + 0.6 * warn), 2.0)
	var at := Vector2(0, vy)
	if c >= WARN_AT and c < DROP_AT:
		warn_outline("gu_blade", 0, at, warn)
	else:
		HazardArt.draw_outline(self, "gu_blade", 0, at, RIM_COL, 1.0)
	HazardArt.draw(self, "gu_blade", 0, at)
	if c >= WARN_AT and c < DROP_AT:
		# brilho no gume (forma + cor; 2 Hz)
		var g := HazardArt.pulse(_t) * HazardArt.flash_k()
		draw_circle(Vector2(0, vy - bsz.y * 0.45), 9.0 + 3.0 * g, Color(WARN_COL, 0.18 + 0.12 * g))


## Desenho por CÓDIGO (fallback sem a pintura; também a prancha "antes").
func _draw_code() -> void:
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
