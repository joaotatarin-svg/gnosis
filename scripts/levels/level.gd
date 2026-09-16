extends Node2D
class_name Level
## Uma tela do run — o ARCO DOS ANÉIS: o Rei (tela 1), waves + Arconte por Éon
## (2–50), o roubo (50), o Centro com ecos (51–53) e a batalha dupla (54).
## Limpou → loja pós-chefe (avança) ou portal. Morte → fim.

@export var enemy_scene: PackedScene
@export var screen: int = 1

var waves: Array = []
var wave_index: int = 0
var alive: int = 0

@onready var spawns: Node2D = $Spawns
@onready var player: Player = $Player


func _ready() -> void:
	if RunManager.run_active:
		screen = RunManager.current_screen
	GameManager.current_screen = screen
	GameManager.set_state(GameManager.State.PLAYING)
	if player:
		player.died.connect(_on_player_died)

	# Cenário do Éon (scenery.gd): céu+astro, skyline, props, névoa, chão com
	# relevo, primeiro plano e vinheta. Se houver PNG do Éon, ele é usado.
	_build_eon_scenery()

	_build_platforms()
	_build_walls()

	if RunManager.run_active:
		waves = RunManager.wave_plan(screen)
	else:
		waves = [_test_wave()]     # rodando Level01.tscn direto (teste)

	_spawn_extras()
	await _play_narrative_beats()
	_start_wave()


## Diálogos de entrada da tela: intro + o Rei (1), chegada num Éon, tentação
## do Arconte, o Centro (51) e a batalha final (54).
func _play_narrative_beats() -> void:
	if not RunManager.run_active:
		return
	# Cada bico narrativo toca UMA vez por run (Narrative.once): com os
	# checkpoints, morrer recarrega a tela — sem isto, tudo repetiria.
	if RunManager.is_king_screen(screen):
		if Narrative.once("intro"):
			await DialogueBox.play(Narrative.intro()).finished
			await DialogueBox.play(Narrative.king_intro()).finished
		return
	if RunManager.is_eon_start(screen) and Narrative.once("eon_%d" % RunManager.eon_index(screen)):
		await DialogueBox.play(Narrative.eon_intro(RunManager.eon_index(screen))).finished
	elif screen == RunManager.CENTER_FIRST and Narrative.once("centro"):
		await DialogueBox.play(Narrative.center_intro()).finished

	if RunManager.is_final(screen):
		if Narrative.once("mente"):
			await DialogueBox.play(Narrative.final_pre()).finished
	elif RunManager.is_archon_screen(screen) and Narrative.once("tentacao_%d" % screen):
		var d := DialogueBox.play(Narrative.temptation(RunManager.boss_id_for(screen)), ["Recusar", "Ceder"])
		var choice: int = await d.choice_made
		if choice == 0:
			await DialogueBox.play(Narrative.refusal_response()).finished
		else:
			Progression.add_orbs(80)      # o suborno do Arconte
			await DialogueBox.play(Narrative.concession_response()).finished


## Cenário do Éon via Scenery (Background.tscn). O chão visual, o primeiro plano
## e a vinheta são filhos do Level (coords de mundo); o GroundVisual estático é
## substituído pelo relevo procedural.
func _build_eon_scenery() -> void:
	if not has_node("Background"):
		return
	var sc: Scenery = $Background
	var eon := RunManager.eon_index(screen) if RunManager.run_active else 0
	var used_png: bool = sc.build(eon, screen)
	if has_node("Ground/GroundVisual"):
		$Ground/GroundVisual.visible = used_png
	if not used_png:
		sc.build_ground(self, 310.0)
		sc.build_foreground(self)
	sc.build_vignette(self)


## Plataformas one-way (sobe por baixo, pousa em cima). Foco em jogabilidade:
## dão reposicionamento e verticalidade sem tirar o combate do chão. Layout
## determinístico por tela; telas de chefe ficam limpas.
func _build_platforms() -> void:
	if RunManager.run_active and RunManager.is_boss_screen(screen):
		return
	var layouts := [
		[Vector2(320, 250), Vector2(600, 214)],
		[Vector2(220, 250), Vector2(470, 250), Vector2(720, 214)],
		[Vector2(400, 224)],
		[Vector2(260, 250), Vector2(640, 250)],
		[Vector2(180, 250), Vector2(430, 216), Vector2(700, 250)],
	]
	var layout: Array = layouts[screen % layouts.size()]
	for pos in layout:
		add_child(_make_platform(pos, 130.0))


## Paredes invisíveis nas bordas da arena: ninguém (jogador, inimigo, knockback)
## sai do chão e cai no vazio. (Bug real: o chão acaba ~x 1900 e dava pra cair.)
func _build_walls() -> void:
	for wx in [-720.0, 1720.0]:
		var wall := StaticBody2D.new()
		wall.position = Vector2(wx, 60.0)
		wall.collision_layer = 1
		wall.collision_mask = 0
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(40, 1600)
		col.shape = rect
		wall.add_child(col)
		add_child(wall)


func _make_platform(center: Vector2, w: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, 12)
	col.shape = rect
	col.one_way_collision = true
	body.add_child(col)
	# Cor da paleta do Éon (não briga com o cenário).
	var base_col := Color(0.20, 0.17, 0.27)
	if has_node("Background") and $Background is Scenery:
		base_col = ($Background as Scenery).pal().ground
	var vis := Polygon2D.new()
	vis.color = base_col.darkened(0.25)
	vis.polygon = PackedVector2Array([Vector2(-w * 0.5, -6), Vector2(w * 0.5, -6), Vector2(w * 0.5, 6), Vector2(-w * 0.5, 6)])
	body.add_child(vis)
	var edge := Polygon2D.new()
	edge.color = base_col.lightened(0.25)
	edge.polygon = PackedVector2Array([Vector2(-w * 0.5, -6), Vector2(w * 0.5, -6), Vector2(w * 0.5, -3), Vector2(-w * 0.5, -3)])
	body.add_child(edge)
	return body


## Conteúdo opcional da tela (determinístico: mesma tela = mesmo conteúdo).
## Nada disso aparece em tela de chefe — chefe é só o chefe.
func _spawn_extras() -> void:
	if RunManager.run_active and RunManager.is_boss_screen(screen):
		return
	if screen % 3 == 1:
		var c := Chest.new()
		c.screen = screen
		add_child(c)
		c.global_position = Vector2(1150, 298)
	if screen % 4 == 2:
		var sl := Sleeper.new()
		sl.screen = screen
		add_child(sl)
		sl.global_position = Vector2(-450, 288)
	if screen % 7 == 3:
		var puz := SealPuzzle.new()
		puz.screen = screen
		add_child(puz)
		puz.global_position = Vector2(1500, 298)
	# Encontros da história: Soter (3x) e Velkar (1x, perto do fim).
	var soter_screens := [10, 24, 38]
	if screen in soter_screens:
		var soter := NpcEncounter.new()
		soter.kind = "soter"
		soter.meeting = soter_screens.find(screen)
		add_child(soter)
		soter.global_position = Vector2(760, 288)
	elif screen == 45:
		var velkar := NpcEncounter.new()
		velkar.kind = "velkar"
		add_child(velkar)
		velkar.global_position = Vector2(760, 286)


func _test_wave() -> Array:
	var ids: Array = Bestiary.types_for_screen(screen)
	if ids.is_empty():
		ids = ["servo"]
	return ids.slice(0, mini(3, ids.size()))


func _start_wave() -> void:
	# Tela 54: a batalha dupla tem controlador próprio (FinalBattle).
	if RunManager.run_active and RunManager.is_final(screen):
		if not has_node("FinalBattle"):
			var fb := FinalBattle.new()
			fb.name = "FinalBattle"
			add_child(fb)
			fb.won.connect(_win)
			fb.start(self, enemy_scene, spawns.get_children())
		return
	if enemy_scene == null or wave_index >= waves.size():
		return
	var wave: Array = waves[wave_index]
	var is_boss := RunManager.run_active and RunManager.is_boss_screen(screen)
	var is_last_wave := wave_index == waves.size() - 1
	var points := spawns.get_children()
	alive = 0
	for i in wave.size():
		var e := enemy_scene.instantiate()
		e.type_id = wave[i]
		# Em tela normal, o último inimigo da última wave é um Elite.
		if not is_boss and is_last_wave and i == wave.size() - 1:
			e.is_elite = true
		add_child(e)
		var p: Node2D = points[i % points.size()]
		e.global_position = p.global_position
		e.defeated.connect(_on_enemy_defeated)
		e.minion_spawned.connect(_on_minion)
		alive += 1


## Invocações (invocador, Coroa, Espelho) contam na wave: precisam morrer também.
func _on_minion(m: Node) -> void:
	alive += 1
	m.defeated.connect(_on_enemy_defeated)
	m.minion_spawned.connect(_on_minion)


func _on_enemy_defeated(e) -> void:
	# No Centro, quebrar um eco devolve o caco de memória daquele Anel.
	if e is Enemy and String(e.type_id).begins_with("eco_"):
		_restore_echo(String(e.type_id).trim_prefix("eco_"))
	alive -= 1
	if alive > 0:
		return
	wave_index += 1
	if wave_index >= waves.size():
		_on_screen_cleared()
	else:
		await get_tree().create_timer(0.8).timeout
		if is_inside_tree():
			_start_wave()


func _on_screen_cleared() -> void:
	if not RunManager.run_active:
		SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
		return

	if player and player.health:
		RunManager.store_health(player.health.current_health, player.health.max_health)

	if RunManager.is_final(screen):
		_win()
	elif RunManager.is_king_screen(screen):
		# O Rei "cai": o selo racha, os 7 tronos acordam. Sem loja — é prólogo.
		await DialogueBox.play(Narrative.king_fall()).finished
		RunManager.advance_and_reload()
	elif RunManager.is_archon_screen(screen):
		# Arconte caído: a essência vira um ANEL (uma magia nova).
		await _grant_ring()
		if RunManager.is_theft_screen(screen):
			# O ROUBO: o Rei reaparece, leva os 7 Anéis, a máscara cai.
			await DialogueBox.play(Narrative.theft()).finished
			Progression.steal_rings()
			RunManager.advance_and_reload()
		else:
			# Loja de recompensa pós-chefe; ao fechar, avança.
			RunManager.pending_advance = true
			SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
	else:
		# Tela normal limpa: abre a fenda à direita — o jogador ANDA até ela.
		_open_exit()


## Fenda de saída à direita; ao entrar nela, avança de tela.
func _open_exit() -> void:
	var portal := ExitPortal.new()
	portal.position = Vector2(1500, 300)
	add_child(portal)
	portal.entered.connect(_advance_via_exit)


func _advance_via_exit() -> void:
	if player and player.health:
		RunManager.store_health(player.health.current_health, player.health.max_health)
	RunManager.advance_and_reload()


## Ao vencer um Arconte, seu Anel se condensa: a magia dele passa pra Sophia.
func _grant_ring() -> void:
	var boss_id := RunManager.boss_id_for(screen)
	var ch: CharacterData = GameManager.selected_character
	if ch == null:
		return
	for skill in ch.skills:
		if skill.ring == boss_id:
			Progression.add_ring(boss_id, skill.id)
			# Equipa o Anel novo (o jogador experimenta na hora).
			Progression.selected_ring = maxi(0, GameContent.ring_skills(ch).find(skill))
			Progression.rings_changed.emit()
			# A essência do Arconte REFAZ a Sophia (cura cheia — o respiro do Éon).
			if player and player.health:
				player.health.heal(player.health.max_health)
			await DialogueBox.play(Narrative.ring_gained(boss_id, skill.display_name, Progression.rings.size())).finished
			return


## No Centro: um eco quebrado devolve o PODER de um Anel roubado.
func _restore_echo(boss_id: String) -> void:
	if not Progression.rings.has(boss_id) or Progression.restored_rings.has(boss_id):
		return
	Progression.restore_ring(boss_id)
	var ch: CharacterData = GameManager.selected_character
	if ch == null:
		return
	for skill in ch.skills:
		if skill.ring == boss_id:
			get_tree().call_group("hud", "toast", Narrative.echo_shard(boss_id, skill.display_name))
			return


func _win() -> void:
	RunManager.best_screen = maxi(RunManager.best_screen, screen)
	RunManager.clear_saved_run()   # o run acabou de verdade — "Continuar" some
	RunManager.end_run()
	GameManager.set_state(GameManager.State.GAME_OVER)
	# O dilema final: Ascensão / Ruptura / Semente (esta exige os Adormecidos).
	var d := DialogueBox.play(Narrative.final_lines(), Narrative.final_choices(Progression.sleepers_freed))
	var idx: int = await d.choice_made
	Narrative.apply_ending(idx)
	SaveManager.save_game()
	SceneManager.change_scene("res://scenes/ui/EndScreen.tscn")


func _on_player_died() -> void:
	GameManager.set_state(GameManager.State.GAME_OVER)
	RunManager.best_screen = maxi(RunManager.best_screen, screen)
	# Fora de run (cena de teste direto): fim simples, como era.
	if not RunManager.run_active:
		SaveManager.save_game()
		await get_tree().create_timer(1.3).timeout
		GameManager.end_title = "Você caiu no Kenoma"
		GameManager.end_subtitle = "Chegou até a Tela %d." % screen
		SceneManager.change_scene("res://scenes/ui/EndScreen.tscn")
		return
	# CHECKPOINT: a morte não pega. Algo te recompõe — antes do roubo é a Voz
	# (o carcereiro precisa da chave viva), depois são os próprios cacos.
	# Custo: parte das faíscas escorre na queda.
	RunManager.deaths_this_run += 1
	var lost := int(Progression.orbs * 0.2)
	if lost > 0:
		Progression.add_orbs(-lost)
	SaveManager.save_game()
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		return
	await DialogueBox.play(Narrative.death_revive(screen, RunManager.deaths_this_run, lost)).finished
	RunManager.respawn_at_checkpoint()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and GameManager.state == GameManager.State.PLAYING:
		SceneManager.instance_overlay("res://scenes/ui/PauseMenu.tscn")
		GameManager.set_state(GameManager.State.PAUSED)
