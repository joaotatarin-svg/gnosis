extends Node
## CAPTURA da loja (Onda 6, Progressão): abre o Santuário de Ascensão num estado
## de run montado à mão e salva um PNG. Ferramenta, não entra no jogo.
## Uso (janela, para renderizar):
##   godot --audio-driver Dummy --path . --resolution 1280x720 --position 1200,600 \
##         res://tools/progressao6/ShopShot.tscn -- <arcontes 0..7> <faíscas> <arma 1..5> <saida.png> [pausa|santuario]
## Ex.: "1 900 2 C:/gnosis-wt/_caps/progressao6/loja_depois_athoth.png" = logo
## depois de Athoth, 900 faíscas, arma Nv.2, loja aberta pela pausa.

const BOSS_RINGS := [
	["arconte_sono", "r_torpor"], ["arconte_fome", "r_fome"], ["arconte_corrente", "r_corrente"],
	["arconte_silencio", "r_silencio"], ["arconte_espelho", "r_espelho"], ["arconte_praga", "r_praga"],
	["arconte_coroa", "r_coroa"],
]


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var tier := int(a[0]) if a.size() > 0 else 1
	var orbs := int(a[1]) if a.size() > 1 else 900
	var weapon := int(a[2]) if a.size() > 2 else 2
	var out: String = a[3] if a.size() > 3 else "user://shop_shot.png"
	var mode: String = a[4] if a.size() > 4 else "pausa"
	SaveManager.persist_enabled = false
	await get_tree().process_frame
	GameManager.selected_character = GameContent.characters[0]
	RunManager.begin()
	Progression.reset_run()
	for i in clampi(tier, 0, 7):
		Progression.add_ring(BOSS_RINGS[i][0], BOSS_RINGS[i][1])
	Progression.weapon_level = clampi(weapon, 1, 5)
	Progression.orbs = orbs
	RunManager.current_screen = 2 + 9 * clampi(tier, 0, 6) + 4
	GameManager.current_screen = RunManager.current_screen
	RunManager.pending_advance = mode == "santuario"
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = -5
	layer.add_child(bg)
	add_child(layer)
	var shop: Node = load("res://scenes/ui/UpgradeMenu.tscn").instantiate()
	get_tree().root.add_child(shop)
	for i in 40:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("SHOP SHOT: ", out)
	RunManager.pending_advance = false
	RunManager.run_active = false
	get_tree().quit(0)
