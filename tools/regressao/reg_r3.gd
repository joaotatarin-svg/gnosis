extends "res://tools/regressao/reg_base.gd"
## REVISAO #3 (Alta): save NÃO atômico. `FileAccess.open(WRITE)` trunca o
## arquivo antes de gravar; fechar à força / queda entre o open e o store
## deixa save.json com 0 bytes ou cortado → no boot "save ilegível", melhor
## tela volta a 1, "Continuar" e finais somem. Mesmo esquema nas Crônicas.
## Esperado: depois de gravações BOAS, uma gravação interrompida não apaga o
## progresso (arquivo temporário + rename, e/ou cópia de segurança lida no load).
## O teste só olha o efeito (não exige nome de arquivo nenhum). Ele corta o
## save.json PRINCIPAL depois de duas gravações boas: passa quem lê uma cópia de
## segurança quando o principal está ilegível (a correção da REVISAO: tmp +
## rename + .bak). Só o rename, sem cópia lida no load, NÃO passa — de propósito
## (disco cheio, antivírus e sincronizadores também deixam o arquivo cortado).
## SEGURANÇA: só roda com user:// isolado (override.cfg do worktree / sonda).

const MARCAS := ["GNOSIS-WT-", "Sonda", "Regressao", "regressao"]


func rodar() -> void:
	var udir := ProjectSettings.globalize_path("user://")
	var isolado := false
	for m in MARCAS:
		if udir.contains(m):
			isolado = true
	if not isolado:
		quebrado("user:// NÃO isolado (%s) — recuso tocar no save (use override.cfg com custom_user_dir_name=GNOSIS-WT-<cargo>)" % udir)
		return
	info("user:// = %s" % udir)
	SceneManager._busy = true                 # nada de trocar de cena durante o teste
	var bak_save = _le(SaveManager.SAVE_PATH)
	var bak_cron = _le(Gnosis.SAVE_PATH)
	SaveManager.persist_enabled = true
	Gnosis.persist_enabled = true

	# --- save.json: arquivo zerado (morreu entre o open e o store) ----------------
	await _prepara_progresso()
	_trunca(SaveManager.SAVE_PATH, 0)
	_zera_memoria()
	SaveManager.load_game()
	check("save_zerado_preserva_progresso", RunManager.best_screen == 40 and RunManager.has_saved_run() and RunManager.endings_seen.has("ruptura"),
		"best=%d continuar=%s finais=%s aviso='%s'" % [RunManager.best_screen, str(RunManager.has_saved_run()), str(RunManager.endings_seen), SaveManager.notice])

	# --- save.json: arquivo cortado no meio -----------------------------------------
	await _prepara_progresso()
	_trunca(SaveManager.SAVE_PATH, -1)
	_zera_memoria()
	SaveManager.load_game()
	check("save_cortado_preserva_progresso", RunManager.best_screen == 40 and RunManager.has_saved_run(),
		"best=%d continuar=%s aviso='%s'" % [RunManager.best_screen, str(RunManager.has_saved_run()), SaveManager.notice])

	# --- chronicles.json ---------------------------------------------------------------
	var ids: Array = []
	for e in Gnosis.entries():
		if ids.size() < 3:
			ids.append(String(e.id))
	Gnosis.unlocked.clear()
	for id in ids:
		Gnosis.unlock(id)          # cada unlock grava
	Gnosis._save()
	_trunca(Gnosis.SAVE_PATH, 0)
	Gnosis._load()
	check("cronicas_zeradas_preservam_leituras", Gnosis.unlocked.size() == ids.size(), "esperado=%d lidas_depois=%d" % [ids.size(), Gnosis.unlocked.size()])

	# --- sanidade: gravação normal continua legível --------------------------------------
	await _prepara_progresso()
	var ok := SaveManager.load_game()
	check("gravacao_normal_legivel", ok and RunManager.best_screen == 40, "load=%s best=%d" % [str(ok), RunManager.best_screen])

	# Restaura o que havia no perfil isolado.
	SaveManager.persist_enabled = false
	Gnosis.persist_enabled = false
	_restaura(SaveManager.SAVE_PATH, bak_save)
	_restaura(Gnosis.SAVE_PATH, bak_cron)
	SceneManager._busy = false


## Progresso real gravado DUAS vezes (como no jogo: grava a cada tela).
func _prepara_progresso() -> void:
	RunManager.best_screen = 40
	RunManager.endings_seen = ["ruptura"]
	RunManager.run_active = false
	RunManager.saved_run = {"screen": 38, "orbs": 900}
	SaveManager.notice = ""
	SaveManager.save_game()
	await frames(2)
	SaveManager.save_game()
	await frames(2)


func _zera_memoria() -> void:
	RunManager.best_screen = 1
	RunManager.endings_seen = []
	RunManager.saved_run = {}
	SaveManager.notice = ""


## Simula a queda no meio da gravação: tamanho 0, ou metade (-1).
func _trunca(path: String, tamanho: int) -> void:
	var txt = _le(path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	if tamanho < 0 and txt != null:
		f.store_string(String(txt).substr(0, String(txt).length() / 2))
	f.close()


func _le(path: String):
	if not FileAccess.file_exists(path):
		return null
	return FileAccess.get_file_as_string(path)


func _restaura(path: String, txt) -> void:
	if txt == null:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(String(txt))
		f.close()
