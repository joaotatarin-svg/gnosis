extends SceneTree
## Pré-calcula malhas e pesos de todos os bonecos (chefe e criatura) e grava
## assets/painted/derived/puppets/mesh_cache.res (comprimido).
## Uso: godot --headless --audio-driver Dummy --path . --script res://tools/anim_bosses/bake_meshes.gd
## Rode de novo sempre que mudar pivôs, camadas, pesos ou as texturas derivadas.

func _init() -> void:
	BossPuppet.clear_cache()
	BossPuppet._bake_loaded = true   # não reaproveita o bake antigo
	var ids := ["arconte_sono","arconte_fome","arconte_corrente","arconte_silencio","arconte_espelho","arconte_praga","arconte_coroa","colosso","rei"]
	for id in ids:
		var p := ArtProfile.new()
		p.painted_id = id
		var paint: Dictionary = PaintedLibrary.character(p)
		for creature in [0,1]:
			if id == "rei" and creature == 1: continue
			var puppet := BossPuppet.new()
			puppet.configure(paint)
			puppet.ensure_built(creature)
			print(id," criatura" if creature == 1 else " chefe","  vértices ",puppet.vertex_count)
			puppet.free()
	var res := Resource.new()
	res.set_meta("cache",BossPuppet.cache())
	var err: int = ResourceSaver.save(res,BossPuppet.BAKE_PATH,ResourceSaver.FLAG_COMPRESS)
	print("bake: ",BossPuppet.cache().size()," malhas, erro ",err)
	quit(err)
