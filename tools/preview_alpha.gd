extends SceneTree
## Compoe um PNG transparente sobre magenta pra inspecionar o recorte (halo/bordas).
func _initialize() -> void:
	var src: String = "res://assets/characters/sophia.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		src = args[0]
	var img := Image.load_from_file(src)
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var bg := Color(1, 0, 1, 1)
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			var m := bg.lerp(Color(c.r, c.g, c.b, 1.0), c.a)
			out.set_pixel(x, y, m)
	out.save_png("res://tools/_preview.png")
	print("preview salvo: res://tools/_preview.png")
	quit(0)
