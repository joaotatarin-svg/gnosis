extends Node
## QA do SAVE (headless): escreve variantes de user://save.json e chama
## SaveManager.load_game() — save v1 (sem versão, tela 40 do mapa antigo) perde
## só o run com aviso; save v2 válido restaura o run; tela fora do mapa é
## descartada; JSON quebrado não derruba nada. Restaura o save real no fim.
## Uso: godot --headless --path . res://tools/SaveQA.tscn --quit-after 300

var errors: int = 0
var backup: String = ""


func check(cond: bool, msg: String) -> void:
	if cond:
		print("QA PASS: ", msg)
	else:
		errors += 1
		push_error("QA FAIL: " + msg)


func _write(txt: String) -> void:
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(txt)
	f.close()


func _ready() -> void:
	SaveManager.persist_enabled = false
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
		backup = f.get_as_text()
		f.close()
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
	# Restaura o save real.
	if backup != "":
		_write(backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	SaveManager.load_game()
	print("QA RESULT: ", errors, " falhas")
	get_tree().quit(0 if errors == 0 else 1)
