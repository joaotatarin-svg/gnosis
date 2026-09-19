extends Node
## Persistência do GNOSIS (user://save.json): melhor tela, finais vistos,
## volumes, OPÇÕES e o run em andamento (checkpoint + progressão → menu
## "Continuar"). Autoload `SaveManager`. Carrega no boot.
##
## VERSÃO do save (`save_version`): mudou o mapa do run (54 → 68 telas) em
## setembro/2026. Um save sem versão, de versão antiga ou com `screen` fora do
## mapa atual tem SÓ o `run` descartado (com aviso no menu); faíscas/melhor
## progresso, finais vistos e opções são preservados. JSON velho ou quebrado
## nunca derruba o jogo.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2

## Ferramentas de dev (shot/balance_bot/combat_test) desligam isto pra não
## sujarem o save real do jogador com runs sintéticos.
var persist_enabled: bool = true

## Aviso pendente pro menu (run antigo descartado). O menu lê e limpa.
var notice: String = ""


func _ready() -> void:
	load_game()


func save_game() -> void:
	if not persist_enabled:
		return
	var data := {
		"save_version": SAVE_VERSION,
		"best_screen": RunManager.best_screen,
		"endings_seen": RunManager.endings_seen,
		"run": RunManager.run_snapshot(),   # run em andamento (menu "Continuar")
		"vol_master": Audio.master_vol,
		"vol_sfx": Audio.sfx_vol,
		"vol_music": Audio.music_vol,
		"settings": GameManager.settings,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		GameManager.apply_settings()   # padrões (e espelho no Juice)
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: save.json ilegível — começando do zero (arquivo preservado até o próximo save).")
		notice = "O arquivo de save estava ilegível e foi ignorado."
		return false
	var d: Dictionary = parsed
	RunManager.best_screen = clampi(_int(d.get("best_screen", 1), 1), 1, RunManager.MAX_SCREEN)
	var endings = d.get("endings_seen", [])
	RunManager.endings_seen = endings if typeof(endings) == TYPE_ARRAY else []
	# --- run em andamento: só se a versão e o mapa baterem ---
	var version := _int(d.get("save_version", 0), 0)
	var run = d.get("run", {})
	var run_ok := typeof(run) == TYPE_DICTIONARY
	var run_screen := _int(run.get("screen", 0), 0) if run_ok else 0
	if run_ok and run_screen >= 1:
		if version < SAVE_VERSION:
			notice = "Um progresso de versão anterior foi descartado (o mapa mudou). Faíscas totais, finais e opções foram preservados."
			run = {}
		elif run_screen > RunManager.MAX_SCREEN:
			notice = "O checkpoint salvo não existe neste mapa e foi descartado. Faíscas, finais e opções foram preservados."
			run = {}
	RunManager.saved_run = run if typeof(run) == TYPE_DICTIONARY else {}
	# --- áudio ---
	Audio.set_volume("Master", clampf(_float(d.get("vol_master", 0.9), 0.9), 0.0, 1.0))
	Audio.set_volume("SFX", clampf(_float(d.get("vol_sfx", 0.9), 0.9), 0.0, 1.0))
	Audio.set_volume("Music", clampf(_float(d.get("vol_music", 0.7), 0.7), 0.0, 1.0))
	# --- opções (só chaves conhecidas; o resto fica no padrão) ---
	var st = d.get("settings", {})
	if typeof(st) == TYPE_DICTIONARY:
		for k in GameManager.SETTINGS_DEFAULT:
			if st.has(k):
				GameManager.settings[k] = st[k]
	GameManager.apply_settings()
	return true


## Lê e limpa o aviso pendente (menu principal).
func take_notice() -> String:
	var n := notice
	notice = ""
	return n


## Conversões tolerantes: JSON velho pode trazer string/float/null onde
## esperamos número — nunca derrubar o jogo por isso.
func _int(v, fallback: int) -> int:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT, TYPE_BOOL: return int(v)
		TYPE_STRING: return int(v) if (v as String).is_valid_int() else fallback
	return fallback


func _float(v, fallback: float) -> float:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT: return float(v)
		TYPE_STRING: return float(v) if (v as String).is_valid_float() else fallback
	return fallback
