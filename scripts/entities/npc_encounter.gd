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
	# O encontro anima COM o mundo pausado pela caixa (fala, abençoa, ajoelha).
	process_mode = Node.PROCESS_MODE_ALWAYS
	if kind == "soter":
		_do_soter(body)
	else:
		_do_velkar()


## A pose de quem fala (atlas do GPT — docs/onda2/ARTE_GPT.md §NPCs): ele fala
## (`talk`) nas próprias falas e escuta (`idle`) nas da Sophia; o Velkar se
## ajoelha quando conta do pai e se ergue para dar as faíscas.
func _on_line(_index: int, line: Dictionary) -> void:
	if _art == null:
		return
	var who := String(line.get("speaker", ""))
	var text := String(line.get("text", ""))
	if kind == "velkar":
		if text.begins_with("Lá em cima não há tirano"):
			_art.set_anim("kneel")
			return
		if _art.anim_state == "kneel":
			if text.begins_with("Quando chegares nele"):
				_art.set_anim("rise")          # levanta (0,4 s) e volta a falar
				var t := create_tween()
				t.tween_interval(0.5)
				t.tween_callback(_art.set_anim.bind("talk"))
			return                             # ajoelhado durante "Tu choras por ele?" e "Era meu pai."
	if who.to_lower().contains(kind):
		_art.set_anim("talk")
	else:
		_art.set_anim("idle")


func _do_soter(player: Node) -> void:
	var d := _dialog(Narrative.soter_meeting(meeting), Narrative.soter_blessings(), "soter")
	d.line_shown.connect(_on_line)
	_art.set_anim("talk")
	var choice: int = await d.choice_made
	# A bênção: as mãos sobem antes da luz (bless, 2 quadros).
	_art.set_anim("bless")
	await get_tree().create_timer(0.55, true, false, true).timeout
	if not is_inside_tree():
		return
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
	_art.set_anim("fade")                    # vira as costas e se desfaz em luz
	var t := create_tween()
	t.tween_interval(0.3)
	t.tween_property(self, "modulate:a", 0.0, 0.8)
	# A Voz volta a falar só depois que ele some — ela não o viu (o Cego não o vê).
	var n := meeting
	t.tween_callback(func() -> void: Gnosis.captions(Narrative.after_soter(n)))
	t.tween_callback(queue_free)


## Diálogo pela encenação do Level (cues como `wait_2s`/`chime`, música
## baixa) quando houver; senão, a caixa pura.
func _dialog(lines: Array, choices: Array, scene: String) -> DialogueBox:
	var lv := get_parent()
	if lv != null and lv.has_method("stage"):
		return lv.call("stage").play(lines, choices, scene)
	return DialogueBox.play(lines, choices)


func _do_velkar() -> void:
	# Termina numa escolha sem efeito mecânico ("Vem comigo" / "Fica em paz").
	# Pela encenação (cena "velkar"): a câmera sobe os dois acima da caixa.
	var d := _dialog(Narrative.velkar_meeting(), Narrative.velkar_choices(), "velkar")
	d.line_shown.connect(_on_line)
	_art.set_anim("talk")
	var choice: int = await d.choice_made
	# A despedida: a mão no peito, sem voltar a falar.
	_art.set_anim("farewell")
	await _dialog(Narrative.velkar_farewell(choice), [], "velkar").finished
	if not is_inside_tree():
		return
	Progression.add_orbs(150)
	ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -20), Color(0.75, 0.6, 0.5))
	# Velkar fica — mancando pro canto dele (walk, devagar), e escurece um pouco.
	_art.set_anim("walk")
	var t := create_tween()
	t.tween_property(self, "global_position:x", global_position.x + 46.0, 2.6)
	t.parallel().tween_property(self, "modulate", Color(0.7, 0.7, 0.7, 1.0), 2.6)
	t.tween_callback(_art.set_anim.bind("idle"))
	t.tween_callback(func() -> void: process_mode = Node.PROCESS_MODE_INHERIT)


## Ouro indica encontro, nunca hostilidade. A sombra ancora os pés no palco.
func _draw() -> void:
	draw_set_transform(Vector2(0,26),0,Vector2(1,0.25))
	draw_circle(Vector2.ZERO,21,Color(0,0,0,0.26))
	draw_arc(Vector2.ZERO,25,0,TAU,48,Color(0.77,0.65,0.42,0.4),1,true)
	draw_set_transform(Vector2.ZERO)
	var col := Color("e0c48c") if kind == "soter" else Color("aa9890")
	draw_polyline(PackedVector2Array([Vector2(-3,-40),Vector2(0,-44),Vector2(3,-40),Vector2(0,-36),Vector2(-3,-40)]),col,0.7,true)
