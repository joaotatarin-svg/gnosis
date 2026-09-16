extends Node2D
## FERRAMENTA (não faz parte do jogo): as POSES da Sophia em tamanho grande +
## um desmembramento de teste, pra a IA ler o golpe no meio da animação.
## Capturar com: tools/shot.gd -- res://tools/Poses.tscn <saida.png> 20


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.09, 0.15)
	bg.position = Vector2(-200, -200)
	bg.size = Vector2(1100, 800)
	add_child(bg)

	var hero := GameContent.get_character("sophia")
	var p1 := Bestiary.player_profile(hero, 1, [])
	var p5 := Bestiary.player_profile(hero, 5, [])
	_label("SOPHIA Nv.1 — poses congeladas no meio do golpe", Vector2(16, 6), 11)
	var poses := [
		["idle", 0.4], ["walk", 0.12], ["windup", 0.2], ["attack", 0.13], ["windup_heavy", 0.3], ["attack_heavy", 0.42],
		["attack_up", 0.2], ["attack_air", 0.16], ["block", 0.2], ["dodge", 0.1],
	]
	var x := 40.0
	for p in poses:
		_pose(p1, p[0], p[1], Vector2(x, 130), 1.7)
		x += 64.0
	poses = [["cast", 0.3], ["jump", 0.2], ["fall", 0.2], ["hurt", 0.1], ["dead", 0.5]]
	x = 40.0
	for p in poses:
		_pose(p1, p[0], p[1], Vector2(x, 250), 1.7)
		x += 64.0
	_label("Nv.5", Vector2(352, 150), 10, 60)
	_pose(p5, "idle", 0.4, Vector2(380, 250), 1.7)
	_label("gigante (3x)", Vector2(470, 150), 10, 100)
	_pose(p1, "idle", 0.5, Vector2(520, 262), 3.0)

	# desmembramento de teste em câmera parada
	_label("desmembramento: servo · besta · wraith", Vector2(16, 268), 10)
	var ids := ["cornudo", "canino", "sombra"]
	x = 80.0
	for id in ids:
		var art := CharacterArt.new()
		art.set_profile(Bestiary.get_type(id).profile)
		art.scale = Vector2(1.6, 1.6)
		add_child(art)
		var parts: Array = art.gib_parts()
		# escala as peças (o gib é desenhado em px de mundo)
		for part in parts:
			var sc := PackedVector2Array()
			for v in part.pts:
				sc.append(v * 1.6)
			part.pts = sc
		art.queue_free()
		Gib.burst(self, Vector2(x, 330), parts, 1.0, 350.0, Vector2(-90.0, -60.0), Color(1, 0.7, 0.5), Color(0.1, 0.05, 0.08))
		x += 150.0


## Pose congelada num instante da animação.
func _pose(p: ArtProfile, state: String, t: float, foot: Vector2, sc: float) -> void:
	var s := p.height / 44.0
	var shadow := Polygon2D.new()
	shadow.color = Color(0, 0, 0, 0.35)
	shadow.position = foot
	var w := 14.0 * s * sc
	shadow.polygon = PackedVector2Array([Vector2(w, 0), Vector2(0, 4 * sc), Vector2(-w, 0), Vector2(0, -4 * sc)])
	add_child(shadow)
	var art := CharacterArt.new()
	art.set_profile(p)
	art.set_anim(state)
	art.anim_time = t
	art.set_process(false)
	art.scale = Vector2(sc, sc)
	art.position = foot + Vector2(0, -24.0 * s * sc)
	add_child(art)
	_label(state, Vector2(foot.x - 30, foot.y + 4), 8, 60)


func _label(text: String, pos: Vector2, size: int, width: float = 500.0) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(width, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if width < 200.0 else HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
	add_child(l)
