extends Node2D
## Sonda local (não versionar): desenha a _FloorCrack abrindo e salva quadros.
var c
var f := 0
func _ready() -> void:
	var cam := Camera2D.new()
	add_child(cam)
	cam.position = Vector2(0, -40)
	cam.zoom = Vector2(2, 2)
	var bg := ColorRect.new()
	bg.color = Color(0.35, 0.3, 0.25)
	bg.position = Vector2(-400, -300)
	bg.size = Vector2(800, 600)
	add_child(bg)
	c = Staging._FloorCrack.new()
	add_child(c)
func _process(_d: float) -> void:
	f += 1
	c.open = clampf(float(f) / 60.0, 0.0, 1.0)
	if f in [15, 30, 45, 70]:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("C:/gnosis-wt/_caps/encenacao5/crack_%d.png" % f)
	if f > 75:
		get_tree().quit()
