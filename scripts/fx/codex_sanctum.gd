extends Node2D
## Arquitetura vetorial determinística. A mesma arte atende menu e mundo.

var tint: Color = Color("73b8b4")
var time: float = 0.0
var menu: bool = false

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	if menu:
		draw_rect(Rect2(-400, -400, 2000, 1200), Color("09141c"))
	var center := Vector2(430, 132) if menu else Vector2(490, 104)
	for i in range(9, 0, -1):
		draw_circle(center, 25.0 + i * 15.0, Color(tint, 0.009))
	for radius in [69.0, 75.0, 109.0, 112.0]:
		draw_arc(center, radius, 0, TAU, 160, Color(tint, 0.26), 0.65, true)
	for i in 56:
		var a: float = TAU * i / 56.0
		var d := Vector2.from_angle(a)
		draw_line(center + d * 100, center + d * (111 if i % 7 == 0 else 105), Color(tint, 0.38), 0.65, true)
	for i in 7:
		var a: float = TAU * i / 7.0 - PI * 0.5 + time * 0.013
		var p := center + Vector2.from_angle(a) * 75
		draw_circle(p, 4.0, Color("09141c"))
		draw_arc(p, 4.0, 0, TAU, 24, Color("c5a56a"), 0.8, true)
	# Portais de pedra recortados; frisos, juntas e nervuras dão escala.
	for i in range(-2, 9):
		var x: float = i * 180.0 + 10
		var base := Color("11252e") if menu else tint.darkened(0.79)
		draw_rect(Rect2(x, 35, 19, 295), base)
		draw_rect(Rect2(x + 2, 40, 3, 284), Color(tint, 0.13))
		for y in range(57, 326, 26):
			draw_line(Vector2(x, y), Vector2(x + 19, y), Color(0, 0, 0, 0.24), 1)
		for y in [35, 47, 299, 308]:
			draw_rect(Rect2(x - 6, y, 31, 4), base.lightened(0.035))
		var arch := PackedVector2Array()
		for k in 41:
			var a: float = PI + PI * k / 40.0
			arch.append(Vector2(x + 99 + cos(a) * 80, 125 + sin(a) * 100))
		draw_polyline(arch, base, 12, true)
		draw_polyline(arch, Color(tint, 0.14), 0.8, true)
		# Luminárias suaves preservam a leitura dos combatentes.
		var lamp := Vector2(x + 9, 227)
		for r in range(5, 0, -1):
			draw_circle(lamp, r * 5.0, Color(0.95, 0.65, 0.3, 0.014))
		draw_line(lamp + Vector2(0, 5), lamp + Vector2(0, -5), Color("e6bf77"), 1.5, true)
	if menu:
		draw_rect(Rect2(-20, 303, 900, 200), Color("0a151c"))
		for j in 7:
			draw_line(Vector2(-20, 310 + j * j * 2), Vector2(850, 310 + j * j * 2), Color(tint, 0.08), 0.6)
		for j in 14:
			draw_line(Vector2(430 + (j - 7) * 24, 303), Vector2(430 + (j - 7) * 140, 450), Color(tint, 0.08), 0.6)
	for i in 50:
		var p := Vector2(fposmod(i * 97.13 + sin(time * 0.3 + i) * 5, 900), fposmod(i * 41.73 - time * (2 + i % 4), 330))
		draw_circle(p, 0.45 if i % 3 else 0.8, Color(tint, 0.2 + 0.18 * sin(time + i)))
