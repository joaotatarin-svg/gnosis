extends Node2D
class_name NpcEncounter
## Encontro com um personagem da história (Soter ou Velkar). Aproximou →
## diálogo; Soter oferece bênção (escolha); Velkar dá faíscas e a verdade.
## kind: "soter" | "velkar" · meeting: índice do encontro de Soter (0..2)

var kind: String = "soter"
var meeting: int = 0
var triggered: bool = false
var _art: CharacterArt


func _ready() -> void:
	_art = CharacterArt.new()
	_art.set_profile(Bestiary.soter_profile() if kind == "soter" else Bestiary.velkar_profile())
	_art.set_anim("idle")
	add_child(_art)

	if kind == "soter":
		# Facho de luz sutil sobre ele
		var beam := Polygon2D.new()
		beam.color = Color(1.0, 0.95, 0.7, 0.08)
		beam.polygon = PackedVector2Array([Vector2(-26, -160), Vector2(26, -160), Vector2(16, 26), Vector2(-16, 26)])
		add_child(beam)
		move_child(beam, 0)

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 56.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if triggered or not body.is_in_group("player"):
		return
	triggered = true
	if kind == "soter":
		_do_soter(body)
	else:
		_do_velkar()


func _do_soter(player: Node) -> void:
	var d := DialogueBox.play(Narrative.soter_meeting(meeting), Narrative.soter_blessings())
	var choice: int = await d.choice_made
	match choice:
		0:
			if player.health:
				player.health.heal(player.health.max_health)
		1:
			if Progression.weapon_level < Progression.MAX_WEAPON_LEVEL:
				Progression.weapon_level += 1
				Progression.weapon_level_changed.emit(Progression.weapon_level)
			else:
				Progression.add_orbs(120)     # arma já desperta: faíscas no lugar
		2:
			Progression.bonus_max_health += 25
			Progression.stats_changed.emit()
			if player.health:
				player.health.max_health += 25
				player.health.heal(25)
	# Soter parte em luz.
	AoeNova.spawn(get_parent(), global_position + Vector2(0, -10), 0, 60.0, Color(1.0, 0.95, 0.7))
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.8)
	# A Voz volta a falar só depois que ele some — ela não o viu (o Cego não o vê).
	var n := meeting
	t.tween_callback(func() -> void: Gnosis.captions(Narrative.after_soter(n)))
	t.tween_callback(queue_free)


func _do_velkar() -> void:
	# Termina numa escolha sem efeito mecânico ("Vem comigo" / "Fica em paz").
	var d := DialogueBox.play(Narrative.velkar_meeting(), Narrative.velkar_choices())
	var choice: int = await d.choice_made
	await DialogueBox.play(Narrative.velkar_farewell(choice)).finished
	if not is_inside_tree():
		return
	Progression.add_orbs(150)
	ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -20), Color(0.75, 0.6, 0.5))
	# Velkar fica — mancando pro canto dele. Só escurece um pouco.
	var t := create_tween()
	t.tween_property(self, "modulate", Color(0.7, 0.7, 0.7, 1.0), 1.0)


## Ouro indica encontro, nunca hostilidade. A sombra ancora os pés no palco.
func _draw() -> void:
	draw_set_transform(Vector2(0,26),0,Vector2(1,0.25))
	draw_circle(Vector2.ZERO,21,Color(0,0,0,0.26))
	draw_arc(Vector2.ZERO,25,0,TAU,48,Color(0.77,0.65,0.42,0.4),1,true)
	draw_set_transform(Vector2.ZERO)
	var col := Color("e0c48c") if kind == "soter" else Color("aa9890")
	draw_polyline(PackedVector2Array([Vector2(-3,-40),Vector2(0,-44),Vector2(3,-40),Vector2(0,-36),Vector2(-3,-40)]),col,0.7,true)
