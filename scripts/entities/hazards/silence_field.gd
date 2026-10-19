extends LevelHazard
class_name SilenceField
## SILÊNCIO — coluna onde a magia NÃO RESPONDE: dentro dela o Éter da Sophia
## escorre a zero (o Anel e a Esfera falham) e todo projétil mágico que entra
## se desfaz — o dela E o dos inimigos. Não fere: muda a luta. Atire de fora,
## ou atraia os atiradores para dentro e lute no corpo a corpo.

const DRAIN := 90.0          # Éter/s escorrendo dentro do campo

var width: float = 160.0
var _inside: bool = false
var _glyphs: Array = []


func _ready() -> void:
	hazard_kind = "silence"
	z_index = 3
	var r := RandomNumberGenerator.new()
	r.seed = hash("silence/%d/%d" % [GameManager.current_screen, int(global_position.x)])
	for i in 10:
		_glyphs.append([r.randf_range(-width * 0.45, width * 0.45), r.randf(), r.randf_range(0.08, 0.16)])


func _tick(delta: float) -> void:
	var area := Rect2(global_position.x - width * 0.5, global_position.y - 420.0, width, 430.0)
	var p := _player()
	var now := p != null and area.has_point(p.global_position)
	if now and not _inside:
		Audio.play_sfx_at("cast_fail", global_position, 0.05)
	_inside = now
	if now and p.mana > 0.0:
		p.mana = maxf(0.0, p.mana - DRAIN * delta)
		p.mana_changed.emit(int(p.mana), p.max_mana_total)
	# projéteis (de qualquer time) se desfazem no silêncio
	var lv := get_parent()
	if lv == null:
		return
	for c in lv.get_children():
		if c is Projectile and area.has_point((c as Node2D).global_position) and not c.is_queued_for_deletion():
			ImpactBurst.spawn(lv, (c as Node2D).global_position, Color(0.85, 0.88, 0.95))
			c.queue_free()


func _draw() -> void:
	var hw := width * 0.5
	var top := -330.0
	var pale := Color(0.86, 0.9, 0.98)
	# a coluna: véu claro e frio, mais forte embaixo
	draw_rect(Rect2(-hw, top, width, -top), Color(pale, 0.05))
	draw_rect(Rect2(-hw, -90.0, width, 90.0), Color(pale, 0.06))
	# bordas tracejadas (lê "aqui dentro é outra regra")
	var y := top
	while y < 0.0:
		for sx in [-hw, hw]:
			draw_line(Vector2(sx, y), Vector2(sx, y + 8.0), Color(INK, 0.45), 3.0)
			draw_line(Vector2(sx, y), Vector2(sx, y + 8.0), Color(pale, 0.55), 1.2)
		y += 16.0
	# glifos de magia caindo e se apagando (a magia "morre" aqui)
	for g in _glyphs:
		var ph: float = fposmod(float(g[1]) + _t * float(g[2]), 1.0)
		var gp := Vector2(float(g[0]), top * 0.8 * (1.0 - ph))
		var a := sin(ph * PI) * 0.45
		draw_arc(gp, 4.0, 0, TAU, 10, Color(pale, a), 1.0, true)
		draw_line(gp + Vector2(-3, -3), gp + Vector2(3, 3), Color(pale, a), 1.0, true)
	# marca no chão: círculo cortado (o símbolo "sem magia")
	# (Onda 7, QA7 #25: o símbolo quase sumia no Silêncio — sublinhado escuro
	# + traço mais claro e grosso: lê em fundo claro e escuro)
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.25))
	draw_arc(Vector2.ZERO, hw * 0.8, 0, TAU, 32, Color(INK, 0.55), 6.0, true)
	draw_arc(Vector2.ZERO, hw * 0.8, 0, TAU, 32, Color(pale, 0.7 + (0.25 if _inside else 0.0)), 2.6, true)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	warn_line(Vector2(-hw * 0.55, 2 - hw * 0.14), Vector2(hw * 0.55, 2 + hw * 0.14), Color(pale, 0.65), 2.0)
