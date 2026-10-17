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
##
## GRAVAÇÃO ATÔMICA (REVISAO #3): `FileAccess.open(WRITE)` trunca o arquivo
## antes de escrever — fechar/cair no meio zerava melhor tela, finais e o
## "Continuar". Agora toda gravação vai para `<arquivo>.tmp`; só depois de
## completa o arquivo atual (se legível) vira `<arquivo>.bak` e o `.tmp` é
## renomeado por cima. Na leitura, se o principal faltar/estiver vazio/ilegível,
## tenta o `.tmp` (gravação completa que não chegou a ser renomeada) e o `.bak`.
## O Gnosis (Crônicas) usa os mesmos helpers.

## Caminho do save. É `var` (não const) só para as QAs gravarem em
## `user://qa/` e NUNCA no save real (REVISAO #9). O jogo não muda isto.
var SAVE_PATH: String = "user://save.json"
const SAVE_VERSION := 2

## Ferramentas de dev (shot/balance_bot/combat_test) desligam isto pra não
## sujarem o save real do jogador com runs sintéticos.
var persist_enabled: bool = true

## Aviso pendente pro menu (run antigo descartado). O menu lê e limpa.
var notice: String = ""


func _ready() -> void:
	load_game()
	# O Juice nasce DEPOIS deste autoload: reaplica no próximo frame pra que
	# tremor/vibração salvos cheguem nele (apply_settings espelha se existir).
	GameManager.apply_settings.call_deferred()


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
	write_json_atomic(SAVE_PATH, data)


func load_game() -> bool:
	if not _any_copy_exists(SAVE_PATH):
		GameManager.apply_settings()   # padrões (e espelho no Juice)
		return false
	var got := read_json_safe(SAVE_PATH)
	if typeof(got.data) != TYPE_DICTIONARY:
		push_warning("SaveManager: save.json ilegível (e sem cópia de segurança) — começando do zero (arquivo preservado até o próximo save).")
		notice = "O arquivo de save estava ilegível e foi ignorado."
		return false
	if got.from != "main":
		push_warning("SaveManager: save.json danificado — progresso recuperado de %s." % got.path)
		notice = "O save principal estava danificado; o progresso foi recuperado da cópia de segurança."
	var d: Dictionary = got.data
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


# --- gravação atômica / leitura com recuperação ------------------------------

## Grava `data` como JSON em `path` sem nunca deixar o arquivo pela metade:
## escreve `path.tmp`, fecha, guarda o atual (só se legível — um principal
## corrompido não pode apagar um .bak bom) em `path.bak` e renomeia o .tmp por
## cima. Devolve false (e mantém o arquivo antigo) se algo falhar.
func write_json_atomic(path: String, data: Variant) -> bool:
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var tmp := path + ".tmp"
	var text := JSON.stringify(data)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: não abriu %s (%s)." % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.flush()
	var err := f.get_error()
	f.close()
	# Confere o que foi ao disco antes de trocar (disco cheio = arquivo curto).
	if err != OK or FileAccess.get_file_as_bytes(tmp).size() != text.to_utf8_buffer().size():
		push_warning("SaveManager: gravação de %s incompleta — o arquivo anterior foi mantido." % path)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return false
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) and typeof(_parse_file(path)) == TYPE_DICTIONARY:
		DirAccess.copy_absolute(abs_path, abs_path + ".bak")
	# rename_absolute substitui o destino (Linux: atômico; Windows: MoveFileEx).
	# Se a substituição falhar, apaga o principal e tenta de novo — o .bak e o
	# .tmp completos cobrem a janela entre os dois passos.
	var rerr := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_path)
	if rerr != OK:
		DirAccess.remove_absolute(abs_path)
		rerr = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_path)
	if rerr != OK:
		push_warning("SaveManager: não renomeou %s (%s)." % [tmp, error_string(rerr)])
		return false
	return true


## Lê o JSON de `path` com recuperação: principal → .tmp → .bak. Devolve
## {data, from ("main"/"tmp"/"bak"/""), path}; `data` é null se nenhum servir.
## Só aceita um candidato cujo JSON seja um Dictionary.
func read_json_safe(path: String) -> Dictionary:
	for c in [["main", path], ["tmp", path + ".tmp"], ["bak", path + ".bak"]]:
		var parsed = _parse_file(c[1])
		if typeof(parsed) == TYPE_DICTIONARY:
			return {"data": parsed, "from": c[0], "path": c[1]}
	return {"data": null, "from": "", "path": ""}


func _any_copy_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".tmp") or FileAccess.file_exists(path + ".bak")


## Conteúdo JSON de um arquivo (null se não existe, vazio ou quebrado).
func _parse_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	if txt.strip_edges().is_empty():
		return null
	return JSON.parse_string(txt)


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
