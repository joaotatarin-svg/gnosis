extends Node2D
## Regressão de articulações e pranchas reais renderizadas pelo jogo.
var failures: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	SaveManager.persist_enabled = false
	GameManager.set_state(GameManager.State.MENU)
	RenderingServer.set_default_clear_color(Color("11171d"))
	await get_tree().process_frame
	for page in 3:
		var stage := Node2D.new()
		add_child(stage)
		for row in 3:
			var index: int = page*3+row
			var p: ArtProfile
			if index < 7: p = Bestiary.bosses[index].profile.duplicate(true)
			else:
				p = Bestiary.bosses[1].profile.duplicate(true)
				p.painted_id = "colosso" if index == 7 else "rei_final"
			for col in 3:
				var art := CharacterArt.new()
				stage.add_child(art)
				art.set_profile(p)
				art.set_process(false)
				var h: float = 190.0 if index == 8 else p.height*1.3
				art.scale = Vector2.ONE*89.0/h
				art.position = Vector2(112+col*205,113+row*118-24*p.height/44.0*89.0/h)
				var puppet: BossPuppet = art.boss_puppet
				check(puppet != null,"Chefe sem esqueleto: "+str(index))
				if puppet.skin != null:
					check(puppet.skin.get_bone_count() == puppet.bones.size(),"Vínculos incompletos")
					for vertex in puppet.skin.polygon.size():
						var sum: float = 0
						for bone in puppet.skin.get_bone_count(): sum += puppet.skin.get_bone_weights(bone)[vertex]
						check(absf(sum-1.0)<0.001,"Pesos não normalizados")
				else:
					check(puppet.pieces.size() >= 10,"Recortes incompletos")
					for piece in puppet.pieces:
						check(piece.get_parent() is Bone2D and piece.polygon.size()>=3,"Peça sem articulação")
				var state: String = ["walk","windup_heavy","attack_heavy"][col]
				for frame in 24: puppet.drive(state,0.4,1.0/60.0,0.85 if col == 1 else 0.1)
				var joint: Bone2D = (puppet.bones.head if col == 2 else puppet.bones.front) if index == 5 else puppet.bones.arm_l
				check(absf(joint.rotation)>0.03,"Articulação imóvel: "+str(index)+state)
				var label := Label.new()
				label.position = Vector2(col*205+22,row*118+2)
				label.add_theme_font_size_override("font_size",9)
				label.text = str(index+1)+" · "+["CAMINHAR","PREPARAR","ATACAR"][col]
				stage.add_child(label)
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://shots/puppets-%d.png" % page)
		stage.queue_free()
		await get_tree().process_frame
	print("PUPPET QA: ",failures," falhas; nove chefes, pesos e articulações verificados")
	get_tree().quit(0 if failures == 0 else 1)
