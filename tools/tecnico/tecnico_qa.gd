extends "res://tools/regressao/reg_base.gd"
## QA do TÉCNICO2 (Onda 2b, headless). Usa a base das regressões (level_at,
## pular_dialogos, frames…) e imprime também "QA PASS:"/"QA FAIL:" para o
## tools/validate.sh contar. Cobre:
##  1. checkpoints (backlog #3): tabela + morte REAL no Arconte (19 → antessala
##     18) e depois do Desafio (17 → 15), −20% de faíscas, "Continuar" do disco
##     retomando da antessala;
##  2. tela cheia na 1ª execução (#24) e o par fullscreen/window_mode;
##  3. DEMO (#27): passar do Athoth emite `demo_finished` e não carrega a 11;
##  4. desbloqueios (#26): bosses_beaten (Provação não conta), migração de save
##     antigo, `CodexSession.is_unlocked`, `Bestiary.seen` ao encontrar;
##  5. `RunManager.screen_rng` determinístico e isolado do randi() global;
##  6. conquistas (#49): lista, liberação, "Intocada" pela vida da Sophia.
## ISOLAMENTO: só grava em user://qa/tecnico/ (o save real nunca é aberto
## para escrita; conferido byte a byte no fim).
## Uso: godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/tecnico/TecnicoQA.tscn

const QA_DIR := "user://qa/tecnico"

var _real := {}


func check(nome: String, ok: bool, detalhe: String = "") -> bool:
	if ok:
		print("QA PASS: %s %s" % [nome, detalhe])
	else:
		push_error("QA FAIL: %s %s" % [nome, detalhe])
	return super.check(nome, ok, detalhe)


func rodar() -> void:
	id = "TECNICO"
	var reais: Array = [SaveManager.SAVE_PATH, Gnosis.SAVE_PATH, Achievements.SAVE_PATH]
	for p in reais:
		_real[p] = _ler(p)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(QA_DIR))
	SaveManager.SAVE_PATH = QA_DIR + "/save.json"
	Gnosis.SAVE_PATH = QA_DIR + "/chronicles.json"
	Achievements.SAVE_PATH = QA_DIR + "/achievements.json"
	_limpar()
	_tabela_checkpoints()
	_screen_rng()
	_lista_conquistas()
	_primeira_execucao()
	_fps_e_vsync()
	_desbloqueios()
	await _morte_no_arconte()
	await _morte_depois_do_desafio()
	await _bestiario_ao_encontrar()
	await _intocada()
	await _demo()
	_folhas_fora_do_export()
	_limpar()
	SaveManager.persist_enabled = false
	var intocado := true
	for p in reais:
		if _ler(p) != _real[p]:
			intocado = false
	check("save_real_intocado", intocado, "(QA grava só em %s)" % QA_DIR)


# --- utilidades --------------------------------------------------------------------

func _ler(p: String) -> String:
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""


func _limpar() -> void:
	for p in [SaveManager.SAVE_PATH, Gnosis.SAVE_PATH, Achievements.SAVE_PATH]:
		assert(String(p).begins_with(QA_DIR + "/"))
		for suf in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(p + suf):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p + suf))


## level_at da base, garantindo que a cena devolvida é a NOVA (logo depois de
## outra fase pronta, a troca ainda não aconteceu no 1º quadro).
func _nivel(screen: int) -> Level:
	var antiga: Node = get_tree().current_scene
	var lv := await level_at(screen)
	for i in 600:
		if lv != null and is_instance_valid(lv) and lv != antiga and lv.screen == screen and lv._ready_done:
			return lv
		await frames(1)
		pular_dialogos()
		var cs := get_tree().current_scene
		lv = cs as Level if cs is Level else null
	quebrado("Level da tela %d não ficou pronto" % screen)
	return lv


## Espera a troca de tela depois da morte (fechando o diálogo de "revive").
func _esperar_respawn(de: int) -> bool:
	for i in 1500:
		await frames(1)
		pular_dialogos()
		var cs := get_tree().current_scene
		if cs is Level and (cs as Level).screen != de and (cs as Level)._ready_done:
			return true
		if i % 300 == 299:
			var l := cs as Level
			info("esperando respawn id=%d f=%d cena=%s/%s tela_run=%d morta=%s pendente=%s resolvida=%s sm_ocupado=%s dialogos=%d pausado=%s" % [cs.get_instance_id() if cs else 0, i, str(cs.name if cs else "-"), str(cs.get("screen") if cs else "-"),
				RunManager.current_screen, str(l.player.health.is_dead() if l and l.player else "-"), str(l.get("_death_pending") if l else "-"),
				str(l.get("_resolved") if l else "-"), str(SceneManager.call("is_busy") if SceneManager.has_method("is_busy") else "-"), dialogos_abertos().size(), str(get_tree().paused)])
	return false


# --- 1. checkpoints ---------------------------------------------------------------

func _tabela_checkpoints() -> void:
	# tela → checkpoint esperado (Éon 1 = 2..10, Éon 2 = 11..19, Éon 7 = 56..64)
	var esperado := {1: 1, 2: 2, 5: 2, 6: 6, 8: 6, 9: 9, 10: 9, 11: 11, 14: 11, 15: 15,
		17: 15, 18: 18, 19: 18, 56: 56, 60: 60, 63: 63, 64: 63, 65: 65, 67: 65, 68: 68}
	var erradas: Array = []
	for s in esperado:
		if RunManager.checkpoint_for(s) != esperado[s]:
			erradas.append("%d→%d (esperado %d)" % [s, RunManager.checkpoint_for(s), esperado[s]])
	check("checkpoint_tabela", erradas.is_empty(), str(erradas))
	# Os checkpoints são exatamente chegada, Desafio (santuário) e antessala.
	var papeis_ok := true
	for s in range(RunManager.FIRST_EON_SCREEN, RunManager.LAST_ARCHON_SCREEN + 1):
		var cp := RunManager.is_checkpoint(s)
		var role := RunManager.screen_role(s)
		if cp != (role in ["arrival", "trial", "antechamber"]):
			papeis_ok = false
	check("checkpoint_papeis", papeis_ok, "checkpoint = chegada · Desafio · antessala")


func _morte_no_arconte() -> void:
	var lv := await _nivel(19)
	Progression.orbs = 100
	# Progressão 7 (decisão do chefe, 29/10): a morte leva SÓ as faíscas ganhas
	# nesta tela (era 20% da carteira). 30 das 100 vieram desta tela.
	Progression.screen_gain = 30
	RunManager.deaths_this_run = 0
	await wait(0.5)
	lv.player.health.take_damage(99999)
	var ok := await _esperar_respawn(19)
	check("morte_arconte_volta_para_antessala", ok and RunManager.current_screen == 18,
		"tela=%d (esperado 18; antes voltava para 11)" % RunManager.current_screen)
	check("morte_custa_faiscas_da_tela", Progression.orbs == 70 and RunManager.deaths_this_run == 1,
		"faíscas=%d mortes=%d" % [Progression.orbs, RunManager.deaths_this_run])
	# "Continuar" depois de fechar o jogo: grava, esquece, lê do disco, retoma.
	SaveManager.persist_enabled = true
	SaveManager.save_game()
	SaveManager.persist_enabled = false
	RunManager.saved_run = {}
	RunManager.run_active = false
	SaveManager.load_game()
	check("continuar_salvo_na_antessala", RunManager.has_saved_run() and int(RunManager.saved_run.get("screen", 0)) == 18,
		"run=%s" % str(RunManager.saved_run.get("screen", "-")))
	var antiga: Node = get_tree().current_scene
	RunManager.continue_run()
	var pronto := false
	for i in 900:
		await frames(1)
		pular_dialogos()
		var cs := get_tree().current_scene
		if cs is Level and cs != antiga and (cs as Level)._ready_done:
			pronto = (cs as Level).screen == 18
			if pronto:
				break
	check("continuar_retoma_da_antessala", pronto and RunManager.current_screen == 18 and Progression.orbs == 70,
		"tela=%d faíscas=%d" % [RunManager.current_screen, Progression.orbs])


func _morte_depois_do_desafio() -> void:
	var lv := await _nivel(17)
	await wait(0.3)
	lv.player.health.take_damage(99999)
	var ok := await _esperar_respawn(17)
	check("morte_travessia_volta_para_o_desafio", ok and RunManager.current_screen == 15,
		"tela=%d (esperado 15 = Desafio/santuário)" % RunManager.current_screen)


# --- 2. 1ª execução ---------------------------------------------------------------

func _primeira_execucao() -> void:
	_limpar()
	GameManager.settings = GameManager.SETTINGS_DEFAULT.duplicate(true)
	GameManager.first_run = false
	var had := SaveManager.load_game()
	# Rodando por ferramenta (cena na linha de comando) a janela não muda.
	check("primeira_execucao_detectada", not had and GameManager.first_run and not bool(GameManager.settings["fullscreen"]),
		"first_run=%s fullscreen=%s (ferramenta fica em janela)" % [str(GameManager.first_run), str(GameManager.settings["fullscreen"])])
	GameManager.apply_first_run_defaults(true)   # como no jogo de verdade
	GameManager.apply_settings()
	check("primeira_execucao_tela_cheia", bool(GameManager.settings["fullscreen"]) and int(GameManager.settings["window_mode"]) == 2,
		"fullscreen=%s modo=%d" % [str(GameManager.settings["fullscreen"]), int(GameManager.settings["window_mode"])])
	# Com save (sem a chave): continua em janela — só a 1ª execução muda.
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"save_version": 2, "best_screen": 3, "settings": {"vsync": true}}))
	f.close()
	GameManager.settings = GameManager.SETTINGS_DEFAULT.duplicate(true)
	GameManager.first_run = false
	SaveManager.load_game()
	check("com_save_nao_forca_tela_cheia", not GameManager.first_run and not bool(GameManager.settings["fullscreen"]), "")
	# Menu antigo alterna o bool; menu novo escreve o modo: os dois andam juntos.
	GameManager.settings["fullscreen"] = true
	GameManager.apply_settings()
	var a := int(GameManager.settings["window_mode"])
	GameManager.set_window_mode(0)
	var b := bool(GameManager.settings["fullscreen"])
	GameManager.set_window_mode(1)
	var c := bool(GameManager.settings["fullscreen"])
	GameManager.settings["fullscreen"] = false
	GameManager.apply_settings()
	var d := int(GameManager.settings["window_mode"])
	check("modo_de_janela_coerente", a == 2 and not b and c and d == 0, "bool→modo=%d · modo0→fs=%s · modo1→fs=%s · bool off→modo=%d" % [a, str(b), str(c), d])
	# Chaves novas das Opções (UI-MENUS2) sobrevivem ao recarregar.
	GameManager.settings["text_speed"] = 2.0
	GameManager.settings["damage_numbers"] = false
	GameManager.settings["bindings"] = {"jump": [{"type": "key", "code": 87}]}
	SaveManager.persist_enabled = true
	SaveManager.save_game()
	SaveManager.persist_enabled = false
	GameManager.settings = GameManager.SETTINGS_DEFAULT.duplicate(true)
	SaveManager.load_game()
	check("opcoes_novas_persistem", is_equal_approx(float(GameManager.settings["text_speed"]), 2.0) and not bool(GameManager.settings["damage_numbers"]) and (GameManager.settings["bindings"] as Dictionary).has("jump"),
		str(GameManager.settings))
	GameManager.settings = GameManager.SETTINGS_DEFAULT.duplicate(true)
	GameManager.apply_settings()
	_limpar()


# --- 2b. qps / VSync (1.2.0) -------------------------------------------------------

func _fps_e_vsync() -> void:
	check("vsync_padrao_desligado", GameManager.SETTINGS_DEFAULT["vsync"] == false and int(GameManager.SETTINGS_DEFAULT["settings_rev"]) == GameManager.SETTINGS_REV, "")
	var casos := {144: 144, 60: 60, 165: 165, 360: 240, 0: 60, -1: 60}
	var ruins: Array = []
	for hz in casos:
		if GameManager.fps_cap_for(hz) != casos[hz]:
			ruins.append("%d→%d" % [hz, GameManager.fps_cap_for(hz)])
	check("teto_de_qps_pela_taxa_do_monitor", ruins.is_empty(), "144→144 · 0/-1→60 · 360→240 %s" % str(ruins))
	# Migração pura: antigo true → false (uma vez); rev 1 com true fica true.
	var a: Dictionary = SaveManager.migrate_settings({"vsync": true, "shake": 0.3})
	var b: Dictionary = SaveManager.migrate_settings({"vsync": true, "settings_rev": 1})
	var c: Dictionary = SaveManager.migrate_settings(a)
	check("migracao_vsync_uma_vez", a["vsync"] == false and int(a["settings_rev"]) == 1 and is_equal_approx(float(a["shake"]), 0.3)
		and b["vsync"] == true and c["vsync"] == false, "antigo=%s · rev1=%s" % [str(a), str(b)])
	# Boot com save antigo (como o do João): no load o vsync sai desligado.
	_limpar()
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"save_version": 2, "best_screen": 22, "settings": {"vsync": true, "shake": 1.0}}))
	f.close()
	GameManager.settings = GameManager.SETTINGS_DEFAULT.duplicate(true)
	SaveManager.load_game()
	check("save_antigo_sai_sem_vsync", GameManager.settings["vsync"] == false, "")
	GameManager.settings = GameManager.SETTINGS_DEFAULT.duplicate(true)
	GameManager.apply_settings()
	_limpar()


# --- 2c. export sem as folhas originais (1.2.0) -------------------------------------

## As 5 folhas cromáticas originais e assets/characters/ ficam FORA do .pck.
## Roda depois de várias fases (Sophia, Rei, Athoth, Harmas): nada disso pode
## ter sido carregado — o PaintedLibrary só cai na original se a derivada
## faltar, então as 5 derivadas têm de existir.
const FORA_DO_EXPORT := ["assets/painted/sophia.png", "assets/painted/archons.png", "assets/painted/yaldabaoth.png",
	"assets/painted/architecture.png", "assets/painted/inhabitants.png"]


func _folhas_fora_do_export() -> void:
	var cfg := ConfigFile.new()
	var exc := ""
	if cfg.load("res://export_presets.cfg") == OK:
		exc = String(cfg.get_value("preset.0", "exclude_filter", "")) + " | " + String(cfg.get_value("preset.1", "exclude_filter", ""))
	var faltam: Array = []
	for f in FORA_DO_EXPORT + ["assets/characters/*"]:
		if exc.count(f) < 2:
			faltam.append(f)
	check("export_exclui_folhas_originais", faltam.is_empty() and not "eons.png" in exc, "faltam=%s (eons.png fica: não tem derivada)" % str(faltam))
	# Cada folha cromática pedida ao catálogo sai da derivada (não da original).
	var origem: Array = []
	for f in PaintedLibrary.KEYED_SHEETS:
		var tx := PaintedLibrary.sheet(String(f))
		if tx == null or not tx.resource_path.begins_with(PaintedLibrary.DERIVED_DIR):
			origem.append("%s→%s" % [f, tx.resource_path if tx != null else "null"])
	check("derivadas_existem", PaintedLibrary.has_clean_sheets() and origem.is_empty(), str(origem))
	var usadas: Array = []
	for k in PaintedLibrary.textures:
		var t = PaintedLibrary.textures[k]
		if t is Resource:
			var rp := String((t as Resource).resource_path)
			if rp.trim_prefix("res://") in FORA_DO_EXPORT or rp.contains("assets/characters/"):
				usadas.append(rp)
	for f in FORA_DO_EXPORT:
		if ResourceLoader.has_cached("res://" + f):
			usadas.append(f)
	check("folhas_originais_nao_carregadas", usadas.is_empty() and PaintedLibrary.textures.size() > 0,
		"folhas em uso=%s · carregadas=%s" % [str(usadas), str(PaintedLibrary.textures.keys())])


# --- 3. demo ----------------------------------------------------------------------

func _demo() -> void:
	check("demo_desligada_no_projeto", not GameManager.detect_demo() and not GameManager.demo, "")
	await _nivel(10)
	GameManager.demo = true
	var fired := [0]
	var cb := func(): fired[0] += 1
	GameManager.demo_finished.connect(cb)
	RunManager.advance_and_reload()
	await frames(30)
	var cs := get_tree().current_scene
	var ainda_10 := cs is Level and (cs as Level).screen == 10
	check("demo_termina_apos_athoth", fired[0] == 1 and RunManager.current_screen == 10 and not RunManager.run_active and ainda_10,
		"sinal=%d tela=%d run_ativo=%s cena=%s" % [fired[0], RunManager.current_screen, str(RunManager.run_active), str(cs.name if cs else "-")])
	check("demo_sem_continuar", not RunManager.has_saved_run(), "")
	GameManager.demo_finished.disconnect(cb)
	# Sem ninguém ligado ao sinal: cai na tela de fim (nunca trava).
	await _nivel(10)
	RunManager.advance_and_reload()
	var fim := false
	for i in 300:
		await frames(1)
		var c2 := get_tree().current_scene
		if c2 != null and String(c2.scene_file_path).ends_with("EndScreen.tscn"):
			fim = true
			break
	check("demo_sem_ui_vai_para_tela_de_fim", fim and GameManager.end_title == "Fim da demo", "título='%s'" % GameManager.end_title)
	GameManager.demo = false
	# Fora da demo, a 10 segue para a 11 normalmente.
	await _nivel(10)
	RunManager.advance_and_reload()
	check("fora_da_demo_segue_para_11", RunManager.current_screen == 11, "tela=%d" % RunManager.current_screen)


# --- 4. desbloqueios --------------------------------------------------------------

func _desbloqueios() -> void:
	Progression.bosses_beaten.clear()
	GameManager.selected_character = GameContent.characters[0]
	Progression.reset_run()
	RunManager.begin()
	var sk_sono := ""
	for sk in GameContent.characters[0].skills:
		if sk.ring == "arconte_sono":
			sk_sono = sk.id
	Progression.add_ring("arconte_sono", sk_sono)
	check("vencido_na_campanha", Progression.is_boss_beaten("arconte_sono") and CodexSession.is_unlocked(0) and not CodexSession.is_unlocked(1),
		"vencidos=%s liberados=%s" % [str(Progression.bosses_beaten), str(CodexSession.unlocked_bosses())])
	Progression.reset_run()
	check("reset_run_nao_apaga_vencidos", Progression.is_boss_beaten("arconte_sono"), "")
	# Provação não libera nada.
	CodexSession.active = true
	var rec := Progression.record_boss_beaten("arconte_fome")
	CodexSession.active = false
	check("provacao_nao_libera", not rec and not CodexSession.is_unlocked(1), "")
	# Gravado no save e lido de volta (com o Bestiário).
	Bestiary.set_seen_ids(["larva", "sonambulo"])
	SaveManager.persist_enabled = true
	SaveManager.save_game()
	SaveManager.persist_enabled = false
	Progression.bosses_beaten.clear()
	Bestiary.set_seen_ids([])
	SaveManager.load_game()
	check("desbloqueios_no_save", Progression.is_boss_beaten("arconte_sono") and Bestiary.seen("larva") and Bestiary.seen("sonambulo") and not Bestiary.seen("glutao"),
		"vencidos=%s vistos=%s" % [str(Progression.bosses_beaten), str(Bestiary.seen_ids())])
	# Save antigo (sem a chave): deduz da melhor tela.
	var mig := SaveManager.bosses_beaten_from_progress(20, false)
	check("migracao_save_antigo", str(mig) == str(["rei", "arconte_sono", "arconte_fome"]), str(mig))
	var mig2 := SaveManager.bosses_beaten_from_progress(1, true)
	check("migracao_com_final", mig2.size() == 9 and mig2.has("demiurgo"), str(mig2))
	Progression.bosses_beaten.clear()
	Bestiary.set_seen_ids([])
	RunManager.end_run()
	_limpar()


func _bestiario_ao_encontrar() -> void:
	Bestiary.set_seen_ids([])
	var lv := await _nivel(13)
	ir_para_zona(lv, 0)
	var vivos: Array = []
	for i in 600:
		await frames(1)
		pular_dialogos()
		vivos = inimigos_vivos()
		if not vivos.is_empty():
			break
	var faltam: Array = []
	for e in vivos:
		if not Bestiary.seen(String(e.type_id)):
			faltam.append(e.type_id)
	check("bestiario_marca_ao_encontrar", not vivos.is_empty() and faltam.is_empty(),
		"vivos=%d vistos=%s faltam=%s" % [vivos.size(), str(Bestiary.seen_ids()), str(faltam)])
	# A meta da conquista "Todos os nomes" só pede criaturas que a campanha
	# realmente põe em campo (planos das telas 2..67).
	var em_campo := {}
	for s in range(RunManager.FIRST_EON_SCREEN, RunManager.CENTER_LAST + 1):
		for zone in RunManager.zone_plan(s):
			for wave in zone:
				for t in wave:
					em_campo[String(t)] = true
	var impossiveis: Array = []
	for t in Achievements.campaign_creature_ids():
		if not em_campo.has(t):
			impossiveis.append(t)
	check("bestiario_meta_alcancavel", impossiveis.is_empty(), "fora dos planos: %s" % str(impossiveis))


# --- 5. RNG por tela ----------------------------------------------------------------

func _screen_rng() -> void:
	var a := RunManager.screen_rng(68)
	var seq_a: Array = []
	for i in 5:
		seq_a.append(a.randi())
	randomize()
	for i in 37:
		randi()                        # o Áudio/VFX consomem o global
	var b := RunManager.screen_rng(68)
	var seq_b: Array = []
	for i in 5:
		seq_b.append(b.randi())
	var c := RunManager.screen_rng(67)
	check("screen_rng_deterministico", seq_a == seq_b and c.randi() != seq_a[0], "68=%s" % str(seq_a))


# --- 6. conquistas ----------------------------------------------------------------

func _lista_conquistas() -> void:
	var ids := AchievementData.ids()
	var unicos := {}
	var ruins: Array = []
	for a in AchievementData.LIST:
		unicos[a.id] = true
		var txt: String = String(a.title) + " " + String(a.desc)
		if txt.contains(" pra ") or txt.contains("amanhã") or txt.contains("sorte") or typeof(a.hidden) != TYPE_BOOL:
			ruins.append(a.id)
	check("conquistas_lista", ids.size() >= 18 and ids.size() <= 24 and unicos.size() == ids.size() and ruins.is_empty(),
		"n=%d ruins=%s" % [ids.size(), str(ruins)])
	for b in Bestiary.bosses:
		if not AchievementData.BOSS_TO_ACH.has(String(b.id)):
			ruins.append(b.id)
	check("conquista_por_arconte", ruins.is_empty(), str(ruins))
	Achievements.reset_for_qa()
	var got := [""]
	var cb := func(x: String): got[0] = x
	Achievements.unlocked.connect(cb)
	Progression.bosses_beaten.clear()
	RunManager.begin()
	Progression.record_boss_beaten("arconte_sono")
	check("conquista_ao_vencer_arconte", Achievements.is_unlocked("athoth") and got[0] == "athoth", "sinal=%s" % got[0])
	RunManager.endings_seen = ["ruptura"]
	Achievements.check_progress()
	check("conquista_final", Achievements.is_unlocked("ruptura") and not Achievements.is_unlocked("tres_portas"), "")
	RunManager.endings_seen = ["ruptura", "ascensao", "semente"]
	Achievements.check_progress()
	check("conquista_tres_finais", Achievements.is_unlocked("tres_portas"), "")
	# Gravação local e leitura.
	SaveManager.persist_enabled = true
	Achievements.unlock("arma_maxima")
	SaveManager.persist_enabled = false
	Achievements.reset_for_qa()
	Achievements.load_state()
	check("conquistas_gravadas", Achievements.is_unlocked("arma_maxima") and Achievements.is_unlocked("athoth"), "%d/%d" % [Achievements.unlocked_count(), Achievements.total()])
	Achievements.unlocked.disconnect(cb)
	RunManager.endings_seen = []
	Progression.bosses_beaten.clear()
	RunManager.end_run()
	Achievements.reset_for_qa()


func _intocada() -> void:
	Achievements.reset_for_qa()
	await _nivel(10)
	await wait(0.3)
	Achievements.on_boss_cleared("arconte_sono", 10)
	check("intocada_sem_dano", Achievements.is_unlocked("intocada") and Achievements.is_unlocked("passo_firme"), "")
	Achievements.reset_for_qa()
	var lv := await _nivel(10)
	await wait(0.3)
	lv.player.health.take_damage(5)
	await frames(2)
	Achievements.on_boss_cleared("arconte_sono", 10)
	check("intocada_com_dano_nao_libera", not Achievements.is_unlocked("intocada"), "")
	# Na Provação, nada.
	Achievements.reset_for_qa()
	CodexSession.active = true
	Achievements.on_boss_cleared("arconte_sono", 10)
	CodexSession.active = false
	check("intocada_provacao_nao_libera", not Achievements.is_unlocked("intocada"), "")
	Achievements.reset_for_qa()
