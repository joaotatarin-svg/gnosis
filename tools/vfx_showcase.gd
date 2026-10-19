extends Node2D
## VITRINE DOS VFX (ferramenta da IA): monta o cenário de um Éon, dispara todos
## os efeitos da VfxLibrary em posições fixas e salva capturas em 3 instantes.
## Uso: godot --path . --resolution 1280x720 --position 4000,4000 res://tools/VfxShowcase.tscn -- <saida_base> [eon]
##   → grava <saida_base>_a.png (0,1 s), _b.png (0,35 s) e _c.png (0,8 s) após o disparo.

var out_base: String = "shots/vfx_showcase"
var eon: int = 0
var _frame: int = 0
var _fired: bool = false
const SHOTS := {8: "a", 22: "b", 50: "c"}     # frame -> sufixo (60 fps)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		out_base = args[0]
	if args.size() >= 2:
		eon = int(args[1])
	var sc := Scenery.new()
	add_child(sc)
	sc.build(eon, 3)
	var ground := Node2D.new()
	add_child(ground)
	sc.build_ground(ground, 316.0)
	var cam := Camera2D.new()
	cam.position = Vector2(320, 180)
	add_child(cam)
	cam.make_current()


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 4 and not _fired:
		_fired = true
		_fire()
	if SHOTS.has(_frame - 4):
		var img := get_viewport().get_texture().get_image()
		var path := "%s_%s.png" % [out_base, SHOTS[_frame - 4]]
		img.save_png(path)
		print("VFX SHOT salvo: ", path, " vivos=", get_tree().get_nodes_in_group(VfxLibrary.GROUP).size())
	if _frame >= 60:
		get_tree().quit()


## Todos os efeitos numa fileira (y = 290, quase no chão).
func _fire() -> void:
	var y := 290.0
	var gold := Color(1.0, 0.85, 0.5)
	VfxLibrary.hit(self, Vector2(40, y), false, gold)
	VfxLibrary.hit(self, Vector2(100, y), true, gold)
	VfxLibrary.parry(self, Vector2(160, y))
	VfxLibrary.dodge_perfect(self, Vector2(215, y))
	VfxLibrary.enemy_death(self, Vector2(275, y), Color(0.6, 0.9, 1.0))
	VfxLibrary.elite_death(self, Vector2(345, y), Color(1.0, 0.5, 0.3))
	VfxLibrary.cast(self, Vector2(410, y), Color(0.7, 0.4, 1.0))
	VfxLibrary.nova_ring(self, Vector2(470, y), 60.0, Color(0.6, 0.8, 1.0))
	VfxLibrary.spark_pickup(self, Vector2(530, y - 30))
	VfxLibrary.portal(self, Vector2(590, y - 20), Color(0.8, 0.9, 1.0))
	VfxLibrary.boss_phase2(self, Vector2(160, 150), Color(1.0, 0.6, 0.4))
	VfxLibrary.boss_death(self, Vector2(430, 150), Color(1.0, 0.8, 0.4))
	VfxLibrary.boss_appear(self, Vector2(560, 150), gold)
	# VFX7: impactos de ataque à distância por família (fileira do meio) e as
	# antecipações (Sophia, Arconte, Rei) — o resto está em tools/VfxShowcase7.
	var x := 50.0
	for st in ["light", "explosion", "chain", "dark", "king", "sleep", "wave"]:
		VfxLibrary.attack_impact(self, Vector2(x, 225), gold if st in ["light", "explosion", "king"] else Color(1.0, 0.55, 0.3), st, 1.0, 250.0)
		x += 80.0
	for i in 3:
		var h := Node2D.new()
		add_child(h)
		h.position = Vector2(80.0 + i * 60.0, 60.0)
		VfxLibrary.charge_up(h, Vector2.ZERO, [gold, Color(1.0, 0.55, 0.3), gold][i], 0.6, ["light", "dark", "king"][i])
