extends Node2D
## FERRAMENTA (não faz parte do jogo): gera o ÍCONE do GNOSIS — a faísca da
## Mônada cercada pelos 7 Anéis dos Arcontes, sobre o vazio do Kenoma.
## Rodar: godot --path . --resolution 256x256 --position 4000,4000 res://tools/IconGen.tscn
## Salva assets/icon_gnosis.png (256x256) e fecha sozinho.

const S := 256.0


func _ready() -> void:
	# 256x256 de verdade: sem o stretch 16:9 do projeto.
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().size = Vector2i(256, 256)
	queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://assets/icon_gnosis.png")
	print("ICONE salvo: assets/icon_gnosis.png ", img.get_width(), "x", img.get_height())
	get_tree().quit()


func _draw() -> void:
	var c := Vector2(S * 0.5, S * 0.5)
	# fundo: vazio arroxeado com vinheta radial (o Kenoma)
	draw_rect(Rect2(0, 0, S, S), Color(0.055, 0.045, 0.09))
	for i in 28:
		var t := float(i) / 28.0
		draw_circle(c, S * 0.72 * (1.0 - t), Color(0.10 + 0.05 * t, 0.07 + 0.04 * t, 0.16 + 0.06 * t, 0.10))
	# halo da faísca
	for i in 14:
		var t2 := float(i) / 14.0
		draw_circle(c, S * 0.30 * (1.0 - t2 * 0.85), Color(1.0, 0.88, 0.55, 0.05 + 0.05 * t2))
	# o ANEL maior (dourado, grosso) — o corpo do Demiurgo que é a própria Sophia
	draw_arc(c, S * 0.335, 0, TAU, 96, Color(0.45, 0.34, 0.14), S * 0.052)
	draw_arc(c, S * 0.335, 0, TAU, 96, Color(1.0, 0.84, 0.42), S * 0.030)
	draw_arc(c, S * 0.335 - S * 0.012, 0, TAU, 96, Color(1.0, 0.95, 0.75, 0.5), S * 0.008)
	# as 7 gemas dos Arcontes sobre o anel (cores dos Éons)
	var gem_cols := [
		Color(0.72, 0.78, 1.0),   # Torpor
		Color(1.0, 0.55, 0.25),   # Fome
		Color(0.85, 0.85, 0.95),  # Corrente
		Color(0.65, 0.78, 1.0),   # Silêncio
		Color(0.95, 0.97, 1.0),   # Espelho
		Color(0.72, 1.0, 0.5),    # Praga
		Color(1.0, 0.88, 0.45),   # Coroa
	]
	for k in 7:
		var a := -PI / 2.0 + TAU * float(k) / 7.0
		var p := c + Vector2(cos(a), sin(a)) * S * 0.335
		draw_circle(p, S * 0.036, Color(0.1, 0.08, 0.14))
		draw_circle(p, S * 0.026, gem_cols[k])
		draw_circle(p + Vector2(-S * 0.007, -S * 0.007), S * 0.009, Color(1, 1, 1, 0.85))
	# a FAÍSCA central (a Sophia): chama de 4 pontas com núcleo branco
	var flame := PackedVector2Array()
	for i in 8:
		var a2 := -PI / 2.0 + TAU * float(i) / 8.0
		var r := S * (0.155 if i % 2 == 0 else 0.062)
		flame.append(c + Vector2(cos(a2), sin(a2)) * r)
	draw_colored_polygon(flame, Color(1.0, 0.80, 0.35))
	var flame2 := PackedVector2Array()
	for i in 8:
		var a3 := -PI / 2.0 + TAU * float(i) / 8.0
		var r2 := S * (0.100 if i % 2 == 0 else 0.040)
		flame2.append(c + Vector2(cos(a3), sin(a3)) * r2)
	draw_colored_polygon(flame2, Color(1.0, 0.95, 0.8))
	draw_circle(c, S * 0.034, Color(1, 1, 1))
