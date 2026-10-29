extends "res://tools/contrast_probe.gd"
## FERRAMENTA (cenario7, R18): o MESMO ContrastProbe da Arte (tools/contrast_probe.gd),
## com a chave `oldbg` para medir o ANTES (fundos antigos, sem as camadas HD).
## Uso: godot --path . --audio-driver Dummy --resolution 640x360 --position 4000,4000 \
##        res://tools/cenario7/ProbeBg.tscn -- <tela> <saida_sem_extensao> [quadro=150] [oldbg]
## Contraste: python tools/anim/contrast_r18.py <saida_sem_extensao>


func _ready() -> void:
	Scenery.hd_disabled = OS.get_cmdline_user_args().has("oldbg")
	super()
