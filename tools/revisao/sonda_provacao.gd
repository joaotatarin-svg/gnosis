extends Node
## SONDA DE REVISÃO: música da Provação. A CodexSession põe o run na tela
## `2 + boss*7` (mapa antigo de 7 telas/Éon); compara com a tela do Éon certo.
## Uso: godot --headless --audio-driver Dummy --path . res://tools/revisao/SondaProvacao.tscn

func _ready() -> void:
	RunManager.begin()      # o que CodexSession.start_demo faz
	print("PROVA run_active após begin() = ", RunManager.run_active, "  (Audio usa o ramo de campanha, não o da Provação)")
	for i in 7:
		var usada := 2 + i * 7
		var certa := RunManager.FIRST_EON_SCREEN + i * RunManager.EON_LEN
		var chefe := certa + RunManager.EON_LEN - 1
		print("PROVA arconte=%s tela_usada=%d musica_tocada=%s | esperado: encontros 1-2=%s, encontro 3=%s" % [
			Bestiary.bosses[i].id, usada, Audio.track_for_screen(usada), Audio.track_for_screen(certa), Audio.track_for_screen(chefe)])
	RunManager.end_run()
	get_tree().quit()
