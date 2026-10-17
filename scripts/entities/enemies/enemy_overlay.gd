extends Node2D
class_name EnemyOverlay
## Camada de LEITURA desenhada por código sobre/atrás de um inimigo (Onda 6):
##  - atrás: ASAS etéreas dos voadores (batem; mostram que ele voa) e a aura do
##    Campeão;
##  - na frente: modificador de Elite (escudo = bolha que racha, fúria = brasas
##    vermelhas, regeneração = fagulhas verdes subindo), a guarda (arco de
##    escudo quando bloqueia), a linha de aviso do mergulho/investida e o
##    diadema de luz do Campeão.
## Tudo leve (linhas/polígonos), em espaço local do inimigo (não vira com ele).

var enemy: Node2D
var front: bool = true
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var e = enemy
	if int(e.estate) == Enemy.EState.DEAD:
		return
	var s: float = float(e._art_scale)
	var col: Color = e.eye_color
	if not front:
		if float(e.fly_height) > 0.0 and not e.is_downed():
			_wings(s, col)
		if e.is_champion:
			_champion_aura(s, col)
		return
	match String(e.elite_mod):
		"escudo": _shield_bubble(s, float(e.barrier) / maxf(1.0, float(e.barrier_max)))
		"furia": _embers(s, Color(1.0, 0.35, 0.2))
		"regen": _motes(s, Color(0.45, 1.0, 0.5))
	if e.is_champion:
		_crest(s, col)
	if int(e.estate) == Enemy.EState.GUARD:
		_ward(s, int(e.guard_dir))
	var tl: Vector2 = e.tele_target
	if tl != Vector2.INF and int(e.estate) == Enemy.EState.WINDUP:
		_tele_line(to_local(tl), e.attack_hitbox.unblockable)


## Asas: duas membranas de luz que batem (mais rápido quando sobe/mergulha).
func _wings(s: float, col: Color) -> void:
	var flap: float = sin(_t * (11.0 if int(enemy.estate) == Enemy.EState.STRIKE else 7.0))
	var base := Vector2(0, -14.0 * s)
	for side in [-1.0, 1.0]:
		var span: float = 30.0 * s
		var tip := base + Vector2(side * span, -12.0 * s - flap * 14.0 * s)
		var mid := base + Vector2(side * span * 0.6, 6.0 * s - flap * 6.0 * s)
		var poly := PackedVector2Array([base + Vector2(side * 3.0 * s, -4.0 * s), tip, mid, base + Vector2(side * 4.0 * s, 6.0 * s)])
		draw_colored_polygon(poly, Color(col.r, col.g, col.b, 0.28))
		draw_polyline(PackedVector2Array([base, tip, mid]), Color(col.lightened(0.4), 0.75), 1.2, true)
		# nervuras
		for k in 3:
			var f := 0.35 + 0.22 * k
			draw_line(base, base.lerp(tip, 1.0).lerp(mid, f), Color(col.lightened(0.5), 0.35), 0.8, true)


## Escudo de elite: bolha hexagonal azul; racha e afina conforme absorve.
func _shield_bubble(s: float, frac: float) -> void:
	if frac <= 0.0:
		return
	var c := Vector2(0, -16.0 * s)
	var r: float = 30.0 * s
	var pts := PackedVector2Array()
	for i in 7:
		var a := TAU * float(i) / 6.0 + _t * 0.4
		pts.append(c + Vector2(cos(a), sin(a) * 1.15) * r)
	var a0: float = 0.25 + 0.5 * frac
	draw_polyline(pts, Color(0.55, 0.8, 1.0, a0), 1.6, true)
	var fill := PackedVector2Array(pts)
	fill.remove_at(6)
	draw_colored_polygon(fill, Color(0.4, 0.65, 1.0, 0.08 + 0.1 * frac))
	if frac < 0.6:
		draw_line(c + Vector2(-r * 0.5, -r * 0.3), c + Vector2(r * 0.1, r * 0.2), Color(0.8, 0.9, 1.0, 0.6), 1.0)
	if frac < 0.3:
		draw_line(c + Vector2(r * 0.4, -r * 0.6), c + Vector2(-r * 0.1, r * 0.4), Color(0.8, 0.9, 1.0, 0.6), 1.0)


## Fúria: brasas vermelhas subindo em volta do corpo + base pulsando.
func _embers(s: float, col: Color) -> void:
	for i in 8:
		var ph := fmod(_t * 1.4 + float(i) * 0.137, 1.0)
		var x := sin(float(i) * 2.3 + _t * 2.0) * 16.0 * s
		var y := 20.0 * s - ph * 52.0 * s
		draw_circle(Vector2(x, y), (2.2 - ph * 1.5) * s, Color(col.r, col.g * (1.0 - ph), col.b, 0.85 - ph * 0.7))
	var pulse := 0.5 + 0.5 * sin(_t * 9.0)
	draw_arc(Vector2(0, 22.0 * s), 18.0 * s, PI, TAU, 18, Color(col, 0.35 + 0.3 * pulse), 2.0, true)


## Regeneração: fagulhas verdes lentas e uma cruz de luz no peito.
func _motes(s: float, col: Color) -> void:
	for i in 6:
		var ph := fmod(_t * 0.6 + float(i) * 0.19, 1.0)
		var x := cos(float(i) * 1.7 + _t) * 14.0 * s
		var y := 16.0 * s - ph * 44.0 * s
		draw_circle(Vector2(x, y), 1.8 * s, Color(col, 0.75 - ph * 0.6))
	var p := 0.5 + 0.5 * sin(_t * 3.0)
	var c := Vector2(0, -36.0 * s)
	draw_line(c + Vector2(-4, 0) * s, c + Vector2(4, 0) * s, Color(col, 0.5 + 0.4 * p), 1.6)
	draw_line(c + Vector2(0, -4) * s, c + Vector2(0, 4) * s, Color(col, 0.5 + 0.4 * p), 1.6)


## Aura do Campeão (atrás): chamas na cor do Éon.
func _champion_aura(s: float, col: Color) -> void:
	var gold := Color(1.0, 0.82, 0.4)
	for i in 10:
		var ph := fmod(_t * 0.9 + float(i) * 0.1, 1.0)
		var x := sin(float(i) * 1.9) * 20.0 * s
		var y := 22.0 * s - ph * 64.0 * s
		var c := gold.lerp(col, ph)
		draw_circle(Vector2(x, y), (4.0 - ph * 3.0) * s, Color(c, 0.4 * (1.0 - ph)))
	draw_arc(Vector2(0, 22.0 * s), 24.0 * s, PI, TAU, 24, Color(gold, 0.45), 2.0, true)


## Diadema do Campeão: anel de luz com 5 pontas girando sobre a cabeça.
func _crest(s: float, col: Color) -> void:
	var c := Vector2(0, -50.0 * s + sin(_t * 2.0) * 2.0)
	var gold := Color(1.0, 0.85, 0.45)
	draw_arc(c, 9.0 * s, 0, TAU, 28, Color(gold, 0.9), 1.4, true)
	for i in 5:
		var a := -PI * 0.5 + TAU * float(i) / 5.0 + _t * 0.8
		var p := c + Vector2(cos(a), sin(a) * 0.45) * 9.0 * s
		draw_line(p, p + Vector2(0, -5.0 * s), Color(gold, 0.85), 1.2)
	draw_circle(c, 2.0 * s, Color(col.lightened(0.4), 0.9))


## Guarda: arco de escudo de luz do lado em que ele defende.
func _ward(s: float, dir: int) -> void:
	var c := Vector2(10.0 * s * dir, -14.0 * s)
	var a0 := -PI * 0.45 if dir > 0 else PI * 0.55
	var pulse := 0.7 + 0.3 * sin(_t * 20.0)
	draw_arc(c, 22.0 * s, a0, a0 + PI * 0.9, 16, Color(0.75, 0.88, 1.0, 0.85 * pulse), 2.4, true)
	draw_arc(c, 18.0 * s, a0, a0 + PI * 0.9, 16, Color(0.75, 0.88, 1.0, 0.35 * pulse), 4.0, true)


## Linha de aviso do mergulho/investida: tracejado até o alvo (amarelo/vermelho).
func _tele_line(to: Vector2, unb: bool) -> void:
	var c: Color = Enemy.TELEGRAPH_UNBLOCKABLE if unb else Enemy.TELEGRAPH_PARRYABLE
	var from := Vector2(0, -8.0)
	var n := 10
	for i in n:
		if i % 2 == 1:
			continue
		var a := from.lerp(to, float(i) / n)
		var b := from.lerp(to, float(i + 1) / n)
		draw_line(a, b, Color(c, 0.7), 1.6, true)
	draw_circle(to, 4.0 + 1.5 * sin(_t * 16.0), Color(c, 0.6))
