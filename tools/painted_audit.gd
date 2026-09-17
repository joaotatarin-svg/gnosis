extends Node

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Audit.new())

class Audit extends Node:
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_run.call_deferred()

	func wait(seconds: float) -> void:
		await get_tree().create_timer(seconds,true,false,true).timeout

	func shot(id: String) -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/review-"+id+".png")
		print("VISUAL: ",id," | FPS=",Engine.get_frames_per_second()," | memória MB=",Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0)

	func _run() -> void:
		SaveManager.persist_enabled = false
		for page in ["PreGame","OptionsMenu","Gallery","CharacterAtelier","EndScreen"]:
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/ui/"+page+".tscn")
			await wait(0.6)
			await shot(page)
		CodexSession.start_demo()
		await wait(0.8)
		SceneManager.instance_overlay("res://scenes/ui/PauseMenu.tscn")
		await wait(0.4)
		await shot("Pause")
		for skill in GameContent.characters[0].skills:
			if skill.ring != "": Progression.add_ring(skill.ring,skill.id)
		SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
		await wait(0.4)
		await shot("Upgrade")
		get_tree().paused = false
		CodexSession.leave_demo()
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		await wait(0.5)
		# Vitrine grande de NPCs e Demiurgo usa o mesmo desenhador da campanha.
		var stage := Node2D.new()
		get_tree().root.add_child(stage)
		var panel := ColorRect.new()
		panel.color = Color("0b1b24")
		panel.size = Vector2(640,360)
		stage.add_child(panel)
		var profiles: Array = [Bestiary.soter_profile(),Bestiary.velkar_profile(),Bestiary.demiurge.profile]
		for i in 3:
			var art := CharacterArt.new()
			art.set_profile(profiles[i])
			art.scale = Vector2.ONE*(2.3 if i<2 else 1.2)
			art.position = Vector2(105+i*205,285-24*profiles[i].height/44*art.scale.y)
			stage.add_child(art)
			CodexStyle.label(stage,["SOTER","VELKAR","YALDABAOTH"][i],Vector2(60+i*205,309),12,CodexStyle.GOLD)
		await wait(0.5)
		await shot("inhabitants")
		stage.queue_free()
		for boss in 7:
			CodexSession.start_demo(boss)
			await wait(1.0)
			CodexSession.stage = 2
			CodexSession._load_stage()
			await wait(1.0)
			var level = get_tree().current_scene
			var found: bool = false
			for enemy in get_tree().get_nodes_in_group("enemy"):
				if enemy is Enemy and enemy.is_boss_enemy:
					found = true
					enemy._on_hit_received(145,level.player.global_position,0,false,null)
					assert(enemy.phase == 2,"Arconte precisa estar na fase 2")
			assert(found,"Arconte ausente da inspeção")
			await wait(0.2)
			await shot("archon-"+str(boss))
		get_tree().quit()
