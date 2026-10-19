extends LevelHazard
class_name ShardFall
## CENTRO — o teto do mundo está rachando: CACOS caem num trecho da tela. A
## cada 1,5 s um ponto (sorteio fixo pela tela) ganha uma SOMBRA no chão
## (0,8 s de aviso); o caco cai e estilhaça (raio 26). Fere inimigos também.
## Só cai quando a Sophia está por perto (não gasta nada longe da vista).

const EVERY := 1.5
const WARN := 0.8
const FALL := 0.18
const HIT_R := 26.0

var width: float = 600.0
var _rng := RandomNumberGenerator.new()
var _next: float = 0.6
var _drops: Array = []        # {x, t} — t conta de 0 até WARN+FALL


func _ready() -> void:
	hazard_kind = "shards"
	z_index = 5
	_rng.seed = hash("shards/%d/%d" % [GameManager.current_screen, int(global_position.x)])


func _tick(delta: float) -> void:
	var p := _player()
	var near := p != null and absf(p.global_position.x - global_position.x) < width * 0.5 + 260.0
	_next -= delta
	if _next <= 0.0 and near and GameManager.state == GameManager.State.PLAYING:
		_next = EVERY
		# metade das vezes mira perto da Sophia (sem ser em cima: ±40..120 px)
		var x := _rng.randf_range(-width * 0.5, width * 0.5)
		if _rng.randf() < 0.5 and p != null:
			var lx := p.global_position.x - global_position.x
			x = clampf(lx + _rng.randf_range(40.0, 120.0) * (1.0 if _rng.randf() < 0.5 else -1.0), -width * 0.5, width * 0.5)
		_drops.append({"x": x, "t": 0.0})
	var keep: Array = []
	for d in _drops:
		var before: float = d.t
		d.t = before + delta
		if before < WARN + FALL and d.t >= WARN + FALL:
			_impact(float(d.x))
		if d.t < WARN + FALL + 0.35:
			keep.append(d)
	_drops = keep


func _impact(x: float) -> void:
	var at := global_position + Vector2(x, 0)
	var area := Rect2(at.x - HIT_R, at.y - 80.0, HIT_R * 2.0, 86.0)
	hurt_enemies_in(area, hazard_damage(4) * 3, at + Vector2(0, -60), 80.0)
	if _live() and player_in(area):
		hurt_player(hazard_damage(4), at + Vector2(0, -60), 100.0, true)
	ImpactBurst.spawn(get_parent(), at + Vector2(0, -6), Color(0.85, 0.9, 1.0))
	Audio.play_sfx_at("shard", at, 0.1)


func _draw() -> void:
	if HazardArt.has("shard_1"):
		_draw_art()
	else:
		_draw_code()


## PINTURA (Onda 7): a SOMBRA no chão e o anel vermelho continuam por código
## (o aviso, 0,8 s); o caco que cai é a pintura (3 tamanhos, pela posição),
## com o BRILHO por efeito (a folha trouxe um brilho rosado: refeito aqui).
func _draw_art() -> void:
	var glass := Color(0.82, 0.88, 1.0)
	var warm := Color(1.0, 0.85, 0.55)
	for d in _drops:
		var x: float = d.x
		var t: float = d.t
		if t < WARN + FALL:
			var k := clampf(t / WARN, 0.0, 1.0)
			draw_set_transform(Vector2(x, 2), 0, Vector2(1, 0.25))
			draw_circle(Vector2.ZERO, HIT_R * (0.4 + 0.6 * k), Color(0, 0, 0, 0.2 + 0.4 * k))
			draw_arc(Vector2.ZERO, HIT_R, 0, TAU, 20, Color(INK, 0.5 + 0.3 * k), 5.0, true)
			draw_arc(Vector2.ZERO, HIT_R, 0, TAU, 20, Color(WARN_COL, 0.4 + 0.6 * k), 2.2, true)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			var piece := "shard_%d" % (int(absf(x) * 0.37) % 3)
			if t >= WARN:
				var f := (t - WARN) / FALL
				var y := lerpf(-320.0, 0.0, f * f)
				# rastro de luz atrás do caco + halo
				draw_line(Vector2(x, y - 70.0), Vector2(x, y - 20.0), Color(warm, 0.35 * HazardArt.flash_k()), 3.0, true)
				draw_circle(Vector2(x, y - 18.0), 12.0, Color(warm, 0.14 * HazardArt.flash_k()))
				HazardArt.draw_outline(self, piece, 0, Vector2(x, y), Color(warm, 0.55), 1.0)
				HazardArt.draw(self, piece, 0, Vector2(x, y))
			else:
				# o caco se soltando lá em cima: pendurado, tremendo e acendendo
				var sh := sin(_t * 40.0) * 1.2 * k
				draw_circle(Vector2(x, -300.0), 4.0 + 5.0 * k, Color(warm, (0.12 + 0.25 * k) * HazardArt.flash_k()))
				HazardArt.draw(self, piece, 0, Vector2(x + sh, -290.0), 0.0, Vector2.ONE * 0.8, Color(1, 1, 1, 0.4 + 0.6 * k))
		else:
			var a := 1.0 - (t - WARN - FALL) / 0.35
			for i in 5:
				var ang := -PI * float(i + 1) / 6.0
				draw_line(Vector2(x, -2), Vector2(x, -2) + Vector2(cos(ang), sin(ang)) * (8.0 + 18.0 * (1.0 - a)), Color(glass, a), 1.2)


## Desenho por CÓDIGO (fallback sem a pintura; também a prancha "antes").
func _draw_code() -> void:
	var glass := Color(0.82, 0.88, 1.0)
	for d in _drops:
		var x: float = d.x
		var t: float = d.t
		if t < WARN + FALL:
			var k := clampf(t / WARN, 0.0, 1.0)
			draw_set_transform(Vector2(x, 2), 0, Vector2(1, 0.25))
			draw_circle(Vector2.ZERO, HIT_R * (0.4 + 0.6 * k), Color(0, 0, 0, 0.2 + 0.4 * k))
			draw_arc(Vector2.ZERO, HIT_R, 0, TAU, 20, Color(WARN_COL, 0.2 + 0.5 * k), 1.5, true)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			if t >= WARN:
				var f := (t - WARN) / FALL
				var y := lerpf(-320.0, 0.0, f * f)
				var shard := PackedVector2Array([Vector2(x - 6, y - 26), Vector2(x + 7, y - 30), Vector2(x + 3, y), Vector2(x - 2, y - 4)])
				draw_colored_polygon(shard, INK)
				draw_polyline(shard, glass, 1.2, true)
			else:
				# o brilho do caco se soltando lá em cima
				draw_circle(Vector2(x, -300.0), 2.0 + 2.0 * k, Color(glass, 0.3 + 0.6 * k))
		else:
			var a := 1.0 - (t - WARN - FALL) / 0.35
			for i in 5:
				var ang := -PI * float(i + 1) / 6.0
				draw_line(Vector2(x, -2), Vector2(x, -2) + Vector2(cos(ang), sin(ang)) * (8.0 + 18.0 * (1.0 - a)), Color(glass, a), 1.2)
