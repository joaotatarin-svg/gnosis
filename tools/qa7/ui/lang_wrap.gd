extends Node
## SONDA QA7 (não faz parte do jogo): roda OUTRA ferramenta (Shot, CenaSeq,
## MenuProbe...) com o idioma forçado, sem mexer no save.
## Variáveis de ambiente: QA7_LANG = pt_BR | en ; QA7_TARGET = res://...tscn
## Os argumentos depois de `--` passam intactos para a ferramenta alvo.
## Ex.: QA7_LANG=en QA7_TARGET=res://tools/Shot.tscn godot --audio-driver Dummy --path . \
##        res://tools/qa7/ui/LangWrap.tscn -- res://scenes/ui/MainMenu.tscn C:/x.png 90


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	SaveManager.persist_enabled = false
	Gnosis.persist_enabled = false
	var lang := OS.get_environment("QA7_LANG")
	var target := OS.get_environment("QA7_TARGET")
	if target == "":
		target = "res://tools/Shot.tscn"
	# o SaveManager reaplica as opções no 1º quadro (call_deferred): espera passar
	await get_tree().process_frame
	await get_tree().process_frame
	if lang != "":
		GameManager.settings["locale"] = lang
		I18n.apply(lang)
	print("QA7LANG|locale=%s|tr=%s|alvo=%s" % [TranslationServer.get_locale(), tr("Continuar"), target])
	var ps = load(target)
	add_child(ps.instantiate())
