extends Node2D
## Teste com autoloads reais: spawna o Enemy "demiurgo" e confirma a arte + orbe.

func _ready() -> void:
	await get_tree().process_frame
	var scn = load("res://scenes/entities/Enemy.tscn")
	var e = scn.instantiate()
	e.type_id = "demiurgo"
	add_child(e)
	await get_tree().process_frame
	var vis = e.get_node_or_null("Visual")
	var has_tex: bool = vis != null and vis.texture != null
	var has_orb: bool = e.get("_orb") != null
	print("TEST demiurgo -> textura: ", has_tex, " | orbe: ", has_orb, " | boss: ", e.is_boss_enemy)
	if has_tex:
		print("  textura_height: ", vis.texture_height, " | tex ", vis.texture.get_width(), "x", vis.texture.get_height())
	if has_orb:
		print("  orbe pos: ", e._orb.position, " | escala: ", e._orb.scale)
	get_tree().quit(0 if (has_tex and has_orb) else 2)
