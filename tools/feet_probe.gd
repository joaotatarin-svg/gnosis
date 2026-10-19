extends Node
## FERRAMENTA (arte, QA7 #18): abre a tela de um chefe e compara onde os PÉS
## DESENHADOS do chefe e da Sophia tocam (fundo da caixa do corpo do quadro,
## CharacterArt.frame_geometry) com o chão físico (base da colisão).
## Uso: godot --path . --audio-driver Dummy res://tools/FeetProbe.tscn -- <tela> [quadro=150]
## Saída: "FEET <id> no=<y do nó> pe=<y do pé desenhado> chao=<base da colisão> folga=<chao - pe>"


func _ready() -> void:
	var w := Worker.new()
	var args := OS.get_cmdline_user_args()
	w.screen = int(args[0]) if args.size() >= 1 else 19
	w.at = int(args[1]) if args.size() >= 2 else 150
	get_tree().root.add_child.call_deferred(w)


class Worker extends Node:
	var screen: int = 19
	var at: int = 150
	var _n: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		Gnosis.persist_enabled = false
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func _process(_d: float) -> void:
		_n += 1
		if _n < at:
			return
		var who: Array = get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("player")
		for e in who:
			var vis = e.get("visual")
			if not (vis is CharacterArt):
				continue
			var g: Dictionary = (vis as CharacterArt).frame_geometry(true)
			var pe: float = (g.body as Rect2).end.y if g.has("body") else NAN
			var chao: float = NAN
			var col: CollisionShape2D = e.get_node_or_null("Collision") as CollisionShape2D
			if col == null:
				col = e.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if col != null and col.shape != null:
				chao = (col.global_transform * Vector2(0, col.shape.get_rect().end.y)).y
			var id: String = String(e.get("type_id")) if e.get("type_id") != null else "sophia"
			print("FEET %s no=%.1f pe=%.1f chao=%.1f folga=%.1f anim=%s chao_fisico=%s" % [id, (e as Node2D).global_position.y, pe, chao, chao - pe, (vis as CharacterArt).anim_state, str((e as CharacterBody2D).is_on_floor()) if e is CharacterBody2D else "?"])
		get_tree().quit()
