extends Node
## SONDA DE REVISÃO (não faz parte do jogo): testa o save/crônicas com
## entradas hostis/corrompidas. SÓ roda se o user:// estiver redirecionado
## para um perfil de teste (override.cfg com custom_user_dir_name contendo
## "Revisao-Sonda") — nunca toca no save real do João.
## Uso: godot --headless --audio-driver Dummy --path . res://tools/revisao/SondaSave.tscn

const MARCA := "Revisao-Sonda"


func _ready() -> void:
	var udir := ProjectSettings.globalize_path("user://")
	print("SONDA user:// = ", udir)
	if not udir.contains(MARCA):
		push_error("SONDA ABORTADA: user:// não é o perfil de teste")
		get_tree().quit(2)
		return
	SceneManager._busy = true          # impede troca de cena real durante a sonda
	_caso_tipos_no_run()
	_caso_settings()
	_caso_cronicas()
	_caso_truncado()
	_caso_profundo()
	print("SONDA FIM")
	get_tree().quit(0)


func _write(path: String, txt: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(txt)
	f.close()


## Save JSON VÁLIDO, mas com tipos errados dentro do "run" → "Continuar".
func _caso_tipos_no_run() -> void:
	var variantes := {
		"skill_levels_lista": {"skill_levels": [1, 2]},
		"rings_stolen_texto": {"rings_stolen": "sim"},
		"seen_numeros": {"seen": [1, 2]},
		"items_numeros": {"items": [1]},
		"orbs_lista": {"orbs": [5]},
	}
	for nome in variantes:
		var run := {"screen": 11, "orbs": 50}
		run.merge(variantes[nome], true)
		_write(SaveManager.SAVE_PATH, JSON.stringify({"save_version": 2, "best_screen": 11, "run": run}))
		SaveManager.load_game()
		RunManager.current_screen = -777   # sentinela: continue_run grava aqui perto do fim
		RunManager.run_active = false
		RunManager.continue_run()
		var chegou := RunManager.current_screen != -777
		print("SONDA run[%s]: has_saved_run=%s continue_run_chegou_ao_fim=%s run_active=%s orbs=%d" % [nome, str(RunManager.has_saved_run()), str(chegou), str(RunManager.run_active), Progression.orbs])


## Opções com tipos errados: entram no GameManager.settings sem validação.
func _caso_settings() -> void:
	for nome in ["fullscreen_texto", "shake_lista"]:
		var st := {"fullscreen": "sim"} if nome == "fullscreen_texto" else {"shake": [1]}
		_write(SaveManager.SAVE_PATH, JSON.stringify({"save_version": 2, "settings": st}))
		GameManager.settings = GameManager.SETTINGS_DEFAULT.duplicate()
		var ok := SaveManager.load_game()
		print("SONDA settings[%s]: load_game=%s settings=%s" % [nome, str(ok), str(GameManager.settings)])
		# O próximo save grava o lixo de volta (persistente).
		SaveManager.persist_enabled = true
		SaveManager.save_game()
		print("SONDA settings[%s]: regravado=%s" % [nome, FileAccess.get_file_as_string(SaveManager.SAVE_PATH).substr(0, 220)])
		GameManager.settings = GameManager.SETTINGS_DEFAULT.duplicate()


## Crônicas com ids numéricos.
func _caso_cronicas() -> void:
	_write(Gnosis.SAVE_PATH, JSON.stringify({"version": 1, "unlocked": [3, "x"]}))
	Gnosis._load()
	print("SONDA cronicas[ids_numericos]: unlocked=", Gnosis.unlocked)


## Arquivo truncado (escrita interrompida: FileAccess.WRITE trunca antes de gravar).
func _caso_truncado() -> void:
	_write(SaveManager.SAVE_PATH, JSON.stringify({"save_version": 2, "best_screen": 40, "endings_seen": ["ruptura"], "run": {"screen": 38, "orbs": 900}}))
	SaveManager.load_game()
	print("SONDA truncado[antes]: best=%d continuar=%s" % [RunManager.best_screen, str(RunManager.has_saved_run())])
	# Simula o que sobra quando o processo morre entre o open(WRITE) e o store_string.
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.close()
	RunManager.best_screen = 1
	RunManager.endings_seen = []
	RunManager.saved_run = {}
	SaveManager.notice = ""
	var ok := SaveManager.load_game()
	print("SONDA truncado[depois]: tamanho=%d load_game=%s best=%d continuar=%s aviso='%s' backup_existe=%s" % [FileAccess.get_file_as_string(SaveManager.SAVE_PATH).length(), str(ok), RunManager.best_screen, str(RunManager.has_saved_run()), SaveManager.notice, str(FileAccess.file_exists(SaveManager.SAVE_PATH + ".bak"))])


## JSON muito aninhado / grande: não pode travar nem derrubar.
func _caso_profundo() -> void:
	_write(SaveManager.SAVE_PATH, "[".repeat(100000))
	var t0 := Time.get_ticks_msec()
	var ok := SaveManager.load_game()
	print("SONDA profundo: load_game=%s em %d ms" % [str(ok), Time.get_ticks_msec() - t0])
	var big := "{\"save_version\":2,\"endings_seen\":[" + ",".join(PackedStringArray(range(2000000).map(func(i): return "\"x\""))) + "]}"
	_write(SaveManager.SAVE_PATH, big)
	t0 = Time.get_ticks_msec()
	ok = SaveManager.load_game()
	print("SONDA grande(%d MB): load_game=%s em %d ms endings=%d" % [big.length() / 1048576, str(ok), Time.get_ticks_msec() - t0, RunManager.endings_seen.size()])
