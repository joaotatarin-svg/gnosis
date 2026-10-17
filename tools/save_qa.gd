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
