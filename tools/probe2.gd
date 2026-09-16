extends SceneTree
func _initialize() -> void:
	var img := Image.load_from_file("res://assets/characters/sophia.png")
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	print("dim salvo: ", w, "x", h)
	# amostra alpha numa grade
	for fy in [0.1, 0.35, 0.5, 0.7, 0.9]:
		var line := ""
		for fx in [0.05, 0.25, 0.5, 0.75, 0.95]:
			var c := img.get_pixel(int(fx * (w - 1)), int(fy * (h - 1)))
			line += ("A%.1f " % c.a)
		print("y=%.2f: %s" % [fy, line])
	quit(0)
