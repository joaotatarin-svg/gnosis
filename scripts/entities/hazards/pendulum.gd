extends LevelHazard
class_name Pendulum
## CORRENTE — pêndulo de lâmina preso no alto por corrente. Balança SEMPRE, num
## ritmo regular (a leitura é o próprio movimento): passe quando ele subir do
## outro lado, pule por cima no ponto baixo ou esquive através (vale esquiva
## perfeita). Quem a lâmina pega é PRESO um instante (a mesma raiz da Galila) e
## leva dano leve — os inimigos também.
## Estilo "bell" (SILÊNCIO): o BADALO MUDO — um sino sem som que balança; o
## golpe dele não prende, mas apaga o Éter (a magia some no silêncio).

const SWING := 0.95          # amplitude (rad, ~54°)
const HIT_R := 17.0

var length: float = 290.0     # pivô a `length` acima da ponta mais baixa
var period: float = 2.8
var style: String = "chain"   # "chain" (Corrente) | "bell" (Silêncio)
var _hit_cd: float = 0.0
var _last_side: float = 0.0


func _ready() -> void:
	hazard_kind = "badalo" if style == "bell" else "pêndulo"
	z_index = 4


func _angle() -> float:
	return SWING * sin(_cycle(period) / period * TAU)


## Ponta (centro da lâmina) em coordenadas LOCAIS: pivô em (0, -length - 14).
func _tip_local() -> Vector2:
	var a := _angle()
	return Vector2(0, -length - 14.0) + Vector2(sin(a), cos(a)) * length


func _tick(delta: float) -> void:
	_hit_cd = maxf(0.0, _hit_cd - delta)
	var tip := to_global(_tip_local())
	# som do vento no ponto baixo (perto da Sophia)
	var side := signf(sin(_cycle(period) / period * TAU))
	if side != _last_side:
		_last_side = side
		var p0 := _player()
		if p0 != null and absf(p0.global_position.x - global_position.x) < 260.0:
			Audio.play_sfx_at("swing_heavy", tip, 0.08)
	if _hit_cd > 0.0:
		return
	var area := Rect2(tip.x - HIT_R - 10.0, tip.y - HIT_R - 26.0, (HIT_R + 10.0) * 2.0, (HIT_R + 26.0) * 2.0)
	if hurt_enemies_in(area, hazard_damage(4) * 3, tip, 180.0) > 0:
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and area.has_point((e as Node2D).global_position):
				e.apply_root(0.8)
		_hit_cd = 0.4
	if _live() and player_in(area):
		var p := _player()
		if style == "chain" and p.invuln_timer <= 0.0 and p.state != Player.State.DODGE:
			p.apply_root(0.45)       # prende ANTES do dano (o dano liga i-frames)
		if hurt_player(hazard_damage(4), tip, 160.0, true):
			if style == "bell":
				p.mana = 0.0
				p.mana_changed.emit(0, p.max_mana_total)
		_hit_cd = 0.6


func _draw() -> void:
	var pivot := Vector2(0, -length - 14.0)
	var tip := _tip_local()
	var dir := tip - pivot
	var u := dir.normalized()
	var metal := Color(0.62, 0.62, 0.7) if style == "chain" else Color(0.78, 0.8, 0.86)
	# suporte no teto
	draw_rect(Rect2(pivot.x - 14, pivot.y - 6, 28, 8), INK)
	draw_circle(pivot, 4.0, metal.darkened(0.3))
	# corrente (elos) ou haste do badalo
	if style == "chain":
		var n := int(dir.length() / 8.0)
		for i in n:
			var p := pivot + dir * (float(i) + 0.5) / float(n)
			draw_set_transform(p, u.angle(), Vector2(1.0, 0.6))
			if i % 2 == 0:
				draw_arc(Vector2.ZERO, 5.0, 0, TAU, 12, INK, 3.2, true)
				draw_arc(Vector2.ZERO, 5.0, 0, TAU, 12, metal, 1.6, true)
			else:
				draw_line(Vector2(-5, 0), Vector2(5, 0), INK, 4.0, true)
				draw_line(Vector2(-4.5, 0), Vector2(4.5, 0), metal.lightened(0.15), 1.8, true)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	else:
		draw_line(pivot, tip, INK, 4.0, true)
		draw_line(pivot, tip, metal.darkened(0.2), 2.0, true)
	# rastro do arco (lê o caminho da lâmina)
	draw_arc(pivot, length, PI * 0.5 - SWING, PI * 0.5 + SWING, 32, Color(1, 1, 1, 0.06), 6.0, true)
	if style == "chain":
		# lâmina em meia-lua perpendicular à corrente
		var perp := Vector2(-u.y, u.x)
		var blade := PackedVector2Array()
		for k in 13:
			var a := lerpf(-1.0, 1.0, float(k) / 12.0)
			blade.append(tip + perp * a * 22.0 + u * (1.0 - a * a) * 12.0)
		for k in 13:
			var a := lerpf(1.0, -1.0, float(k) / 12.0)
			blade.append(tip + perp * a * 18.0 + u * (1.0 - a * a) * 4.0 - u * 2.0)
		draw_colored_polygon(blade, INK)
		draw_polyline(blade, metal.lightened(0.3), 1.2, true)
	else:
		# o sino (boca para baixo) — mudo: sem brilho, só a forma
		var bell := PackedVector2Array()
		var perp2 := Vector2(-u.y, u.x)
		for k in 15:
			var a := lerpf(-1.0, 1.0, float(k) / 14.0)
			bell.append(tip - u * 16.0 + perp2 * a * (8.0 + 12.0 * (a * a)) + u * (a * a) * 18.0)
		draw_colored_polygon(bell, Color(0.2, 0.22, 0.28))
		draw_polyline(bell, Color(0.85, 0.88, 0.95, 0.6), 1.2, true)
		draw_circle(tip + u * 6.0, 4.0, Color(0.85, 0.88, 0.95, 0.5))
