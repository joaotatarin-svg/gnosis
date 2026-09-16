extends Node2D
## FERRAMENTA (não faz parte do jogo): vitrine dos 7 Arcontes, dos bots e das
## POSES do herói em tamanho grande, pra a IA e o usuário verem lado a lado.
## Capturar com: tools/shot.gd -- res://tools/Showcase.tscn <saida.png>
## Também dispara um desmembramento de teste (canto inferior direito).


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.12)
	bg.position = Vector2(-200, -200)
	bg.size = Vector2(1100, 800)
	add_child(bg)

	_label("OS SETE ARCONTES", Vector2(20, 4), 11)
	var x := 50.0
	for b in Bestiary.bosses:
		_place(b.profile, b.name.split(",")[0], Vector2(x, 118), 0.8)
		x += 80.0

	_label("WAVES (tier 1→4) · SOMBRA · NPCs", Vector2(20, 132), 11)
	var row2: Array = []
	for t in Bestiary.wave_types:
		row2.append({"n": t.name, "p": t.profile})
	row2.append({"n": "Soter", "p": Bestiary.soter_profile()})
	row2.append({"n": "Velkar", "p": Bestiary.velkar_profile()})
	x = 34.0
	var y := 205.0
	for i in row2.size():
		var e: Dictionary = row2[i]
		_place(e.p, e.n, Vector2(x, y), 0.85)
		x += 68.0
		if (i + 1) % 9 == 0:
			x = 34.0
			y += 63.0

	_label("SOPHIA Nv.1 · Nv.3 · Nv.5   ·   AS FORMAS DO DEMIURGO (procedural)", Vector2(20, 348), 11)
	var hero := GameContent.get_character("sophia")
	x = 60.0
	for lvl in [1, 3, 5]:
		_place(Bestiary.player_profile(hero, lvl, []), "Sophia Nv.%d" % lvl, Vector2(x, 410), 1.0)
		x += 80.0
	x = 340.0
	for s in Bestiary.specials:
		_place(s.profile, s.name.split(",")[0].split(" — ")[0], Vector2(x, 410), 0.55)
		x += 90.0
	_place(Bestiary.demiurge.profile, "Yaldabaoth", Vector2(x, 410), 0.6)


func _place(p: ArtProfile, name: String, foot: Vector2, sc: float) -> void:
	var s := p.height / 44.0
	_shadow(foot, 16.0 * s * sc, sc)
	var art := CharacterArt.new()
	art.set_profile(p)
	art.set_anim("idle")
	art.scale = Vector2(sc, sc)
	art.position = foot + Vector2(0, -24.0 * s * sc)
	add_child(art)
	_label(name, Vector2(foot.x - 40, foot.y + 4), 8, 80)


func _shadow(foot: Vector2, w: float, sc: float) -> void:
	var shadow := Polygon2D.new()
	shadow.color = Color(0, 0, 0, 0.35)
	shadow.position = foot
	shadow.polygon = PackedVector2Array([Vector2(w, 0), Vector2(0, 4 * sc), Vector2(-w, 0), Vector2(0, -4 * sc)])
	add_child(shadow)


func _label(text: String, pos: Vector2, size: int, width: float = 500.0) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(width, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if width < 200.0 else HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
	add_child(l)
