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
## SONDA DE CAIXAS (depuração/QA): desenha a Hurtbox (verde) e a caixa do golpe
## (vermelha quando ativa) por cima do desenho. Liga com `EnemyOverlay.debug_boxes`.
static var debug_boxes: bool = false


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
	if front and debug_boxes:
		_debug_boxes()
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


## Asas: leque de 4 penas de luz por lado (folha alongada, translúcida, mais
## clara na borda) que BATEM juntas — lê como "voa" sem tapar a pintura.
func _wings(s: float, col: Color) -> void:
	var fast: bool = int(enemy.estate) == Enemy.EState.STRIKE
	var flap: float = sin(_t * (13.0 if fast else 7.5))
	var base := Vector2(0, -16.0 * s)
	var light := col.lightened(0.45)
	for side in [-1.0, 1.0]:
		for j in 4:
			var ang: float = deg_to_rad(-62.0 + 17.0 * j) - flap * 0.42
			var dir := Vector2(cos(ang) * side, sin(ang))
			var length: float = (24.0 - 3.5 * j) * s
			var w: float = (3.6 - 0.5 * j) * s
			var tip := base + dir * length
			var nrm := Vector2(-dir.y, dir.x) * w
			var mid := base + dir * length * 0.45
			var leaf := PackedVector2Array([base, mid + nrm, tip, mid - nrm])
			draw_colored_polygon(leaf, Color(col.r, col.g, col.b, 0.22 + 0.05 * j))
			draw_polyline(PackedVector2Array([base, mid + nrm, tip]), Color(light, 0.55), 0.9, true)


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


## Caixas reais (formas de colisão) no espaço local do inimigo.
func _debug_boxes() -> void:
	var hs: CollisionShape2D = enemy.get_node_or_null("Hurtbox/HurtShape")
	if hs != null and hs.shape is RectangleShape2D:
		var sz: Vector2 = (hs.shape as RectangleShape2D).size
		var r := Rect2(-sz * 0.5, sz)
		var xf: Transform2D = (enemy.get_node("Hurtbox") as Node2D).transform * hs.transform
		_rect_outline(xf, r, Color(0.3, 1.0, 0.4, 0.9))
	var ab: Area2D = enemy.get_node_or_null("AttackHitbox")
	var ash: CollisionShape2D = enemy.get_node_or_null("AttackHitbox/AttackShape")
	if ab != null and ash != null and ash.shape is RectangleShape2D:
		var sz2: Vector2 = (ash.shape as RectangleShape2D).size
		var on: bool = ab.monitoring
		_rect_outline(ab.transform * ash.transform, Rect2(-sz2 * 0.5, sz2), Color(1.0, 0.25, 0.2, 0.95 if on else 0.18))


func _rect_outline(xf: Transform2D, r: Rect2, c: Color) -> void:
	var pts := PackedVector2Array([xf * r.position, xf * Vector2(r.end.x, r.position.y), xf * r.end, xf * Vector2(r.position.x, r.end.y), xf * r.position])
	draw_polyline(pts, c, 1.2)
