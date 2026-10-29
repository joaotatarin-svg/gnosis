extends LevelHazard
class_name SpearTrap
## Fileira de fendas no chão que dispara de baixo. Ritmo de 3,6 s: fechada →
## AVISO 0,6 s (as fendas brilham) → sobe 0,5 s → recolhe. Quem está NO CHÃO
## em cima leva; em plataforma por cima, está a salvo (é a escalada que manda).
## Estilos:
##   "spears"   (COROA/SILÊNCIO) — lanças da guarda: dano e empurrão pra cima.
##   "shackles" (CORRENTE) — correntes que brotam do chão e PRENDEM (raiz 0,8 s)
##              com dano leve: a corrente que prende.

const PERIOD := 3.6
const WARN_AT := 2.2
const UP_AT := 2.8
const UP_END := 3.3

var width: float = 120.0
var style: String = "spears"
var _hit_done: bool = false
var _warned: bool = false


func _ready() -> void:
	hazard_kind = style
	z_index = 3


func _tick(_delta: float) -> void:
	var c := _cycle(PERIOD)
	if c < WARN_AT:
		_hit_done = false
		_warned = false
		return
	if c < UP_AT:
		if not _warned:
			_warned = true
			var p0 := _player()
			if p0 != null and absf(p0.global_position.x - global_position.x) < 300.0:
				Audio.play_sfx_at("tell_unblock", global_position, 0.05)
		return
	if c < UP_END and not _hit_done:
		_hit_done = true
		var area := Rect2(global_position.x - width * 0.5, global_position.y - 50.0, width, 56.0)
		var mult := 3 if style == "spears" else 2
		var n := hurt_enemies_in(area, hazard_damage(4) * mult, global_position + Vector2(0, 30), 60.0)
		if style == "shackles" and n > 0:
			for e in get_tree().get_nodes_in_group("enemy"):
				if e is Enemy and area.has_point((e as Node2D).global_position):
					e.apply_root(1.2)
		if _live() and player_in(area) and player_grounded_low():
			var p := _player()
			if style == "shackles" and p.invuln_timer <= 0.0 and p.state != Player.State.DODGE:
				p.apply_root(0.8)
			hurt_player(hazard_damage(3 if style == "shackles" else 4), global_position + Vector2(0, 30), 60.0, true)
		var pp := _player()
		if pp != null and absf(pp.global_position.x - global_position.x) < 300.0:
			Audio.play_sfx_at("hz_shackles" if style == "shackles" else "hz_spears", global_position, 0.06)


## Fase visual: (aviso 0..1, subida 0..1) — a mesma conta do desenho antigo.
func _phase_vis() -> Vector2:
	var c := _cycle(PERIOD)
	var warn := 0.0
	var up := 0.0
	if c >= WARN_AT and c < UP_AT:
		warn = (c - WARN_AT) / (UP_AT - WARN_AT)
	elif c >= UP_AT and c < UP_END:
		up = clampf((c - UP_AT) / 0.06, 0.0, 1.0)
	elif c >= UP_END:
		up = clampf(1.0 - (c - UP_END) / (PERIOD - UP_END), 0.0, 1.0)
	return Vector2(warn, up)


func _draw() -> void:
	var piece := "spear_slab" if style == "spears" else "shackles"
	if HazardArt.has(piece):
		if style == "spears":
			_draw_art_spears()
		else:
			_draw_art_shackles()
	else:
		_draw_code()


## Brilho das FENDAS no aviso (por cima da pintura): 6 bocas acendendo.
func _draw_slots(warn: float, n: int, col: Color) -> void:
	var hw := width * 0.5 * 0.84
	for i in n:
		var x := lerpf(-hw, hw, float(i) / float(n - 1))
		warn_line(Vector2(x - 5, 0), Vector2(x + 5, 0), Color(col, 0.25 + 0.75 * warn), 2.0)
		if warn > 0.0:
			draw_circle(Vector2(x, -1), 3.0 + 3.0 * warn, Color(col, 0.18 * warn * (0.6 + 0.4 * HazardArt.pulse(_t))))


## PINTURA (Onda 7) — LANÇAS: a laje com fendas fica embutida no chão; no
## aviso as fendas acendem, a laje ganha contorno vermelho e as PONTAS
## espiam (forma, não só cor — R5); na subida as lanças pintadas saem da
## fenda (recorte da textura: as pontas primeiro).
func _draw_art_spears() -> void:
	var v := _phase_vis()
	var sc := Vector2.ONE * (width / maxf(1.0, HazardArt.size("spear_slab").x))
	warn_outline("spear_slab", 0, Vector2.ZERO, v.x, 0.0, sc)
	HazardArt.draw(self, "spear_slab", 0, Vector2.ZERO, 0.0, sc)
	var peek := 0.1 * v.x * v.x               # as pontas espiam no fim do aviso
	var up := maxf(v.y, peek)
	if up > 0.0 and HazardArt.has("spear_tips"):
		var tsz := HazardArt.size("spear_tips") * sc
		var tan := HazardArt.anchor("spear_tips") * sc
		var h := tsz.y * up
		HazardArt.draw_part(self, "spear_tips", 0, Rect2(0, 0, 1, up), Rect2(-tan.x, -h + (tsz.y - tan.y), tsz.x, h))
	_draw_slots(v.x, 6, WARN_COL)


## PINTURA (Onda 7) — CORRENTES DO CHÃO: laje rachada (espera/aviso, rachas
## acendendo + contorno) → correntes saindo → estendidas (prendem).
func _draw_art_shackles() -> void:
	var v := _phase_vis()
	var sc := Vector2.ONE * (width / maxf(1.0, HazardArt.size("shackles").x))
	var f := 0
	if v.y > 0.6:
		f = 2
	elif v.y > 0.0:
		f = 1
	var shake := Vector2(sin(_t * 47.0) * 0.8 * v.x, 0.0)
	warn_outline("shackles", f, shake, v.x, 0.0, sc)
	HazardArt.draw(self, "shackles", f, shake, 0.0, sc)
	_draw_slots(v.x, 5, WARN_COL)


## Desenho por CÓDIGO (fallback sem a pintura; também a prancha "antes").
func _draw_code() -> void:
	var c := _cycle(PERIOD)
	var hw := width * 0.5
	var n := int(width / 16.0)
	var warn := 0.0
	var up := 0.0
	if c >= WARN_AT and c < UP_AT:
		warn = (c - WARN_AT) / (UP_AT - WARN_AT)
	elif c >= UP_AT and c < UP_END:
		up = clampf((c - UP_AT) / 0.06, 0.0, 1.0)
	elif c >= UP_END:
		up = clampf(1.0 - (c - UP_END) / (PERIOD - UP_END), 0.0, 1.0)
	var metal := Color(0.75, 0.72, 0.6) if style == "spears" else Color(0.62, 0.62, 0.7)
	for i in n:
		var x := lerpf(-hw + 8.0, hw - 8.0, float(i) / maxf(1.0, float(n - 1)))
		# a fenda (sempre visível) — acende no aviso
		draw_line(Vector2(x - 4, 1), Vector2(x + 4, 1), INK, 3.0)
		draw_line(Vector2(x - 3, 1), Vector2(x + 3, 1), Color(WARN_COL, 0.15 + 0.8 * warn), 1.2)
		if up <= 0.0:
			continue
		var h := 40.0 * up * (0.85 + 0.15 * float((i * 7) % 3))
		if style == "spears":
			draw_line(Vector2(x, 0), Vector2(x, -h), INK, 3.6)
			draw_line(Vector2(x, 0), Vector2(x, -h), metal.darkened(0.3), 1.6)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 3.5, -h + 4), Vector2(x + 3.5, -h + 4), Vector2(x, -h - 7)]), metal)
		else:
			var k := int(h / 7.0)
			for j in k:
				var p := Vector2(x + sin(float(j) * 1.3 + _t * 8.0) * 1.5, -3.5 - float(j) * 7.0)
				if j % 2 == 0:
					draw_arc(p, 3.5, 0, TAU, 10, INK, 2.6, true)
					draw_arc(p, 3.5, 0, TAU, 10, metal, 1.2, true)
				else:
					draw_line(p + Vector2(0, -3), p + Vector2(0, 3), metal.lightened(0.1), 1.6)
