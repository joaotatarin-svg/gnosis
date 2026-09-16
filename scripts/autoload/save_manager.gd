extends Node
## Persistência do GNOSIS (user://save.json): melhor tela, finais vistos,
## volumes E o run em andamento (checkpoint + progressão → menu "Continuar").
## Autoload `SaveManager`. Carrega no boot.

const SAVE_PATH := "user://save.json"

## Ferramentas de dev (shot/balance_bot/combat_test) desligam isto pra não
## sujarem o save real do jogador com runs sintéticos.
var persist_enabled: bool = true


func _ready() -> void:
	load_game()


func save_game() -> void:
	if not persist_enabled:
		return
	var data := {
		"best_screen": RunManager.best_screen,
		"endings_seen": RunManager.endings_seen,
		"run": RunManager.run_snapshot(),   # run em andamento (menu "Continuar")
		"vol_master": Audio.master_vol,
		"vol_sfx": Audio.sfx_vol,
		"vol_music": Audio.music_vol,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	RunManager.best_screen = int(parsed.get("best_screen", 1))
	RunManager.endings_seen = parsed.get("endings_seen", [])
	var run = parsed.get("run", {})
	RunManager.saved_run = run if typeof(run) == TYPE_DICTIONARY else {}
	Audio.set_volume("Master", float(parsed.get("vol_master", 0.9)))
	Audio.set_volume("SFX", float(parsed.get("vol_sfx", 0.9)))
	Audio.set_volume("Music", float(parsed.get("vol_music", 0.7)))
	return true
