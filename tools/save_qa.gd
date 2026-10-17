extends Node
## QA do SAVE (headless): escreve variantes do save e chama
## SaveManager.load_game() — save v1 (sem versão, tela 40 do mapa antigo) perde
## só o run com aviso; save v2 válido restaura o run; tela fora do mapa é
## descartada; JSON quebrado não derruba nada; gravação atômica com .bak
## (REVISAO #3) e tipos errados (REVISAO #5).
## ISOLAMENTO (REVISAO #9): tudo vai para `user://qa/` — o save real
## (`user://save.json`, `user://chronicles.json`) nunca é aberto para escrita.
## Uso: godot --headless --audio-driver Dummy --path . res://tools/SaveQA.tscn

const QA_DIR := "user://qa"

var errors: int = 0
var _real_save: String = ""
var _real_chron: String = ""


func check(cond: bool, msg: String) -> void:
	if cond:
		print("QA PASS: ", msg)
	else:
		errors += 1
		push_error("QA FAIL: " + msg)


func _write(txt: String, path: String = "") -> void:
	var p := SaveManager.SAVE_PATH if path == "" else path
	assert(p.begins_with(QA_DIR + "/"))
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(txt)
	f.close()


func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


## Apaga o save de QA e as cópias (.tmp/.bak) para cada caso começar limpo.
func _wipe() -> void:
	for p in [SaveManager.SAVE_PATH, Gnosis.SAVE_PATH]:
		for suf in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(p + suf):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p + suf))


func _ready() -> void:
	SaveManager.persist_enabled = false
	Gnosis.persist_enabled = false
	# Desvia os caminhos ANTES de qualquer escrita e guarda o conteúdo real
	# só para provar no fim que nada mudou.
	_real_save = _read(SaveManager.SAVE_PATH)
	_real_chron = _read(Gnosis.SAVE_PATH)
	var real_paths := [SaveManager.SAVE_PATH, Gnosis.SAVE_PATH]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(QA_DIR))
	SaveManager.SAVE_PATH = QA_DIR + "/save.json"
	Gnosis.SAVE_PATH = QA_DIR + "/chronicles.json"
	if not SaveManager.SAVE_PATH.begins_with(QA_DIR) or not Gnosis.SAVE_PATH.begins_with(QA_DIR):
		push_error("QA FAIL: caminhos de QA não desviados — abortando sem tocar no save")
		get_tree().quit(1)
		return
	_wipe()
	_cases_legacy()
	_cases_atomic()
	_cases_persist_run()
	_cases_vsync_migration()
	_wipe()
	await _cases_types()
	_wipe()
	# O save real continua byte a byte igual (nada foi gravado nele).
	check(_read(real_paths[0]) == _real_save and _read(real_paths[1]) == _real_chron, "save real intocado (QA grava só em user://qa/)")
	print("QA RESULT: ", errors, " falhas")
	get_tree().quit(0 if errors == 0 else 1)


# --- casos herdados (versão / mapa / tipos / JSON quebrado) -------------------

func _cases_legacy() -> void:
	# 1. Save antigo (v1): sem save_version, run na tela 40, faíscas/finais/volumes.
	_write(JSON.stringify({"best_screen": 40, "endings_seen": ["ruptura"], "run": {"screen": 40, "orbs": 999}, "vol_music": 0.33}))
	SaveManager.notice = ""
	check(SaveManager.load_game(), "v1 carrega sem erro")
	check(not RunManager.has_saved_run(), "v1: run descartado")
	check(SaveManager.notice != "", "v1: aviso pendente pro menu")
	check(RunManager.best_screen == 40 and RunManager.endings_seen.has("ruptura"), "v1: melhor tela e finais preservados")
	check(is_equal_approx(Audio.music_vol, 0.33), "v1: volume preservado")
	# 2. Save v2 válido com run na tela 29 e opções.
	_write(JSON.stringify({"save_version": 2, "best_screen": 29, "run": {"screen": 29, "orbs": 120}, "settings": {"shake": 0.4, "caption_size": 2, "rumble": false, "lixo": 1}}))
	SaveManager.notice = ""
	check(SaveManager.load_game(), "v2 carrega")
	check(RunManager.has_saved_run() and int(RunManager.saved_run.get("orbs", 0)) == 120, "v2: run restaurado")
	check(SaveManager.notice == "", "v2: sem aviso")
	check(is_equal_approx(GameManager.shake_multiplier(), 0.4) and GameManager.caption_font_size() == 16 and not GameManager.rumble_enabled(), "v2: opções aplicadas")
	check(not GameManager.settings.has("lixo"), "v2: chave desconhecida ignorada")
	# 3. v2 com tela fora do mapa (68).
	_write(JSON.stringify({"save_version": 2, "run": {"screen": 90}}))
	SaveManager.notice = ""
	SaveManager.load_game()
	check(not RunManager.has_saved_run() and SaveManager.notice != "", "tela 90: run descartado com aviso")
	# 4. Tipos errados e JSON quebrado.
	_write(JSON.stringify({"save_version": "2", "best_screen": "abc", "run": [1, 2], "vol_master": null, "settings": "x"}))
	SaveManager.load_game()
	check(RunManager.best_screen >= 1 and not RunManager.has_saved_run(), "tipos errados: tolerado")
	_write("{ isto nao e json")
	SaveManager.notice = ""
	check(not SaveManager.load_game() and SaveManager.notice != "", "JSON quebrado: ignorado com aviso")


# --- gravação atômica + .bak (REVISAO #3) -------------------------------------

func _cases_atomic() -> void:
	_wipe()
	SaveManager.persist_enabled = true
	Gnosis.persist_enabled = true
	# Duas gravações: a 1ª cria o principal; a 2ª guarda a 1ª em .bak.
	RunManager.best_screen = 40
	RunManager.endings_seen = ["ruptura"]
	SaveManager.save_game()
	RunManager.best_screen = 41
	SaveManager.save_game()
	var main_txt := _read(SaveManager.SAVE_PATH)
	check(main_txt.contains("\"best_screen\":41") and FileAccess.file_exists(SaveManager.SAVE_PATH + ".bak")
		and not FileAccess.file_exists(SaveManager.SAVE_PATH + ".tmp"), "atômico: principal novo, .bak criado, sem .tmp sobrando")
	# Queda no meio da gravação = principal truncado (0 bytes) → recupera do .bak.
	_write("")
	RunManager.best_screen = 1
	RunManager.endings_seen = []
	SaveManager.notice = ""
	check(SaveManager.load_game() and RunManager.best_screen == 40 and RunManager.endings_seen.has("ruptura"), "truncado (0 bytes): recupera melhor tela/finais do .bak")
	check(SaveManager.notice != "", "truncado: aviso de recuperação pro menu")
	# Cortado no meio do JSON → também recupera.
	_write(main_txt.substr(0, main_txt.length() / 2))
	RunManager.best_screen = 1
	check(SaveManager.load_game() and RunManager.best_screen == 40, "cortado no meio: recupera do .bak")
	# O próximo save com o principal corrompido NÃO pode apagar o .bak bom.
	_write("{ corrompido")
	RunManager.best_screen = 42
	SaveManager.save_game()
	var bak = JSON.parse_string(_read(SaveManager.SAVE_PATH + ".bak"))
	check(bak is Dictionary and int(bak.get("best_screen", 0)) == 40, "principal corrompido não sobrescreve o .bak bom")
	# .tmp completo que não chegou a ser renomeado (queda entre os passos) e
	# principal ausente → usa o .tmp (mais novo que o .bak).
	DirAccess.rename_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH), ProjectSettings.globalize_path(SaveManager.SAVE_PATH + ".tmp"))
	RunManager.best_screen = 1
	check(SaveManager.load_game() and RunManager.best_screen == 42, "principal ausente + .tmp completo: recupera do .tmp")
	SaveManager.save_game()
	check(not FileAccess.file_exists(SaveManager.SAVE_PATH + ".tmp"), "gravação seguinte limpa o .tmp")
	# Crônicas (Gnosis) com o mesmo esquema.
	var ids: Array = []
	for e in Gnosis.entries():
		ids.append(String(e.id))
	Gnosis.unlocked.clear()
	Gnosis.unlock(ids[0])
	Gnosis.unlock(ids[1])
	_write("", Gnosis.SAVE_PATH)
	Gnosis._load()
	check(Gnosis.unlocked == [ids[0]], "Crônicas truncadas: recupera do .bak (%s)" % [Gnosis.unlocked])
	Gnosis.unlocked.clear()
	SaveManager.persist_enabled = false
	Gnosis.persist_enabled = false


# --- Provação: opções gravam, progresso não (REVISAO #13) + volumes padrão ---

func _cases_persist_run() -> void:
	_wipe()
	# 1ª execução (sem save): Master 0,7 e Música 0,6.
	Audio.set_volume("Master", 1.0)
	Audio.set_volume("Music", 1.0)
	SaveManager.load_game()
	check(is_equal_approx(Audio.master_vol, 0.7) and is_equal_approx(Audio.music_vol, 0.6), "1ª execução: Master 0,7 e Música 0,6")
	_write(JSON.stringify({"save_version": 2, "best_screen": 30, "endings_seen": ["semente"], "run": {"screen": 20, "orbs": 77}}))
	SaveManager.load_game()
	SaveManager.persist_enabled = true
	SaveManager.persist_run = false          # como a Provação deixa
	RunManager.best_screen = 2
	RunManager.saved_run = {}
	RunManager.endings_seen = []
	GameManager.settings["shake"] = 0.25
	GameManager.settings["reduce_flashes"] = true
	Audio.set_volume("Music", 0.15)
	SaveManager.save_game()                  # o que o menu de opções chama
	var disk = JSON.parse_string(_read(SaveManager.SAVE_PATH))
	check(disk is Dictionary and is_equal_approx(float(disk.settings.shake), 0.25) and disk.settings.reduce_flashes == true
		and is_equal_approx(float(disk.vol_music), 0.15), "Provação: opções e volume gravados")
	check(disk is Dictionary and int(disk.run.screen) == 20 and int(disk.best_screen) == 30 and disk.endings_seen == ["semente"], "Provação: run/melhor tela/finais do disco intactos")
	SaveManager.persist_run = true
	SaveManager.persist_enabled = false
	GameManager.settings = GameManager.SETTINGS_DEFAULT.duplicate()
	GameManager.apply_settings()


# --- migração do VSync (1.2.0: padrão desligado, settings_rev 1) -------------

## Lê `settings` do disco de QA (ou {} se não der).
func _disk_settings() -> Dictionary:
	var disk = JSON.parse_string(_read(SaveManager.SAVE_PATH))
	if disk is Dictionary and disk.get("settings") is Dictionary:
		return disk.settings
	return {}


func _cases_vsync_migration() -> void:
	_wipe()
	# 1ª execução: VSync desligado e revisão atual.
	GameManager.settings = GameManager.SETTINGS_DEFAULT.duplicate(true)
	SaveManager.load_game()
	check(GameManager.settings.vsync == false and int(GameManager.settings.settings_rev) == GameManager.SETTINGS_REV, "1ª execução: vsync=false, settings_rev=%d" % GameManager.SETTINGS_REV)
	# Save ANTIGO (o do João em 17/10: sem settings_rev, vsync=true) → false.
	_write(JSON.stringify({"save_version": 2, "best_screen": 22, "settings": {"caption_size": 1, "fullscreen": false, "rumble": false, "shake": 0.5, "vsync": true}}))
	SaveManager.load_game()
	check(GameManager.settings.vsync == false, "save antigo com vsync=true → migrado para false")
	check(int(GameManager.settings.settings_rev) == 1 and not GameManager.rumble_enabled() and is_equal_approx(GameManager.shake_multiplier(), 0.5), "migração só mexe no vsync (rev=1, outras opções preservadas)")
	# A migração vai ao disco no próximo save (rev 1, vsync false).
	SaveManager.persist_enabled = true
	SaveManager.save_game()
	var st := _disk_settings()
	check(st.get("vsync") == false and int(st.get("settings_rev", 0)) == 1, "save seguinte grava vsync=false e settings_rev=1 (%s)" % [st])
	# Quem RELIGA o VSync depois é respeitado (não migra de novo).
	GameManager.settings["vsync"] = true
	SaveManager.save_game()
	SaveManager.persist_enabled = false
	GameManager.settings = GameManager.SETTINGS_DEFAULT.duplicate(true)
	SaveManager.load_game()
	check(GameManager.settings.vsync == true, "religado depois da migração: vsync=true respeitado no load")
	# Save antigo com vsync=false fica false; tipo errado no vsync não vira true.
	_write(JSON.stringify({"save_version": 2, "settings": {"vsync": false}}))
	SaveManager.load_game()
	check(GameManager.settings.vsync == false and int(GameManager.settings.settings_rev) == 1, "save antigo com vsync=false: continua false")
	_write(JSON.stringify({"save_version": 2, "settings": {"vsync": true, "settings_rev": "x"}}))
	SaveManager.load_game()
	check(GameManager.settings.vsync == false, "settings_rev inválido conta como 0 (migra)")
	# Revisão futura (save de versão mais nova) não é rebaixada nem mexida.
	_write(JSON.stringify({"save_version": 2, "settings": {"vsync": true, "settings_rev": 7}}))
	SaveManager.load_game()
	check(GameManager.settings.vsync == true and int(GameManager.settings.settings_rev) == 7, "settings_rev futuro (7): intocado")
	GameManager.settings = GameManager.SETTINGS_DEFAULT.duplicate(true)
	GameManager.apply_settings()
	_wipe()


# --- JSON válido com tipos errados (REVISAO #5) -------------------------------

func _cases_types() -> void:
	# "Continuar" troca de cena: um nó vazio vira a cena atual para esta QA
	# sobreviver à troca (ela fica como irmã, filha da raiz). Espera um quadro:
	# dentro do _ready a raiz ainda está montando os filhos e recusa add_child.
	await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	var valid_id: String = String(Gnosis.entries()[2].id)
	_write(JSON.stringify({"save_version": 2, "best_screen": 30,
		"run": {"screen": 20, "difficulty": 1, "weapon_level": 3, "rings": ["arconte_sono", 7],
			"skill_levels": [1, 2], "rings_stolen": "sim", "seen": [1, 2, "intro_ok"], "orbs": [5],
			"items": "nada", "bonus_hp": 40, "selected_ring": "x", "deaths": null},
		"settings": {"shake": [1], "fullscreen": "sim", "vsync": 0.0, "caption_size": 2.0, "rumble": "não"}}))
	_write(JSON.stringify({"version": 1, "unlocked": [3, "x", valid_id, null, [1]]}), Gnosis.SAVE_PATH)
	SaveManager.notice = ""
	check(SaveManager.load_game() and RunManager.has_saved_run(), "tipos errados: save carrega e o 'Continuar' existe")
	var st := GameManager.settings
	check(is_equal_approx(float(st.shake), 1.0) and typeof(st.shake) == TYPE_FLOAT, "settings.shake=[1] → padrão 1.0")
	check(typeof(st.fullscreen) == TYPE_BOOL and st.fullscreen == false, "settings.fullscreen=\"sim\" → padrão false")
	check(typeof(st.rumble) == TYPE_BOOL and st.rumble == true, "settings.rumble=\"não\" → padrão true")
	check(typeof(st.caption_size) == TYPE_INT and st.caption_size == 2, "settings.caption_size=2.0 (float do JSON) aceito como 2")
	# Opção-lixo não pode ser regravada: grava e relê o disco.
	SaveManager.persist_enabled = true
	SaveManager.save_game()
	SaveManager.persist_enabled = false
	var disk = JSON.parse_string(_read(SaveManager.SAVE_PATH))
	check(disk is Dictionary and typeof(disk.settings.shake) == TYPE_FLOAT and typeof(disk.settings.fullscreen) == TYPE_BOOL, "lixo das opções não volta ao disco")
	Gnosis._load()
	check(Gnosis.unlocked == [valid_id], "Crônicas unlocked:[3,\"x\",…] → só o id válido fica (%s)" % [Gnosis.unlocked])
	Gnosis.unlocked.clear()
	# Continuar: só os campos ruins voltam ao padrão; o resto vale e a cena troca.
	await get_tree().create_timer(0.8).timeout   # nenhum fade em andamento
	RunManager.continue_run()
	check(RunManager.run_active and RunManager.current_screen == 20, "continue_run chega ao fim (tela 20)")
	check(Progression.skill_levels.is_empty(), "skill_levels:[1,2] → vazio")
	check(Progression.rings_stolen == false, "rings_stolen:\"sim\" → false")
	check(not Narrative.seen.has("1") and Narrative.seen.has("intro_ok"), "seen:[1,2,…] → descarta só os números")
	check(Progression.orbs == 0, "orbs:[5] → 0")
	check(Progression.items.is_empty() and Progression.selected_ring == 0 and RunManager.deaths_this_run == 0, "items/selected_ring/deaths inválidos → padrão")
	check(Progression.weapon_level == 3 and Progression.bonus_max_health == 40 and Progression.rings == ["arconte_sono"] and GameManager.difficulty == 1, "campos bons preservados (arma 3, +40 HP, anel, dificuldade)")
	await get_tree().create_timer(1.2).timeout
	var cur := get_tree().current_scene
	check(cur != null and cur.scene_file_path == "res://scenes/levels/Level01.tscn", "'Continuar' troca para a fase")
	RunManager.end_run()
	# has_saved_run com screen de tipo errado não pode dar SCRIPT ERROR.
	RunManager.saved_run = {"screen": [1]}
	check(not RunManager.has_saved_run(), "run.screen=[1] → sem 'Continuar', sem erro")
	RunManager.saved_run = {}
