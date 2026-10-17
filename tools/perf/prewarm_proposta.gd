extends RefCounted
## CORREÇÃO PROPOSTA (agente de Desempenho, Onda 2) — NÃO faz parte do jogo ainda.
## É o corpo de `VfxLibrary.prewarm(level)`: o dono de `scripts/fx/vfx_library.gd`
## copia a função `prewarm` (e as constantes) para lá e o dono de `level.gd`
## chama `VfxLibrary.prewarm(self)` no `_ready` da fase, logo depois de
## `_spawn_extras()` (antes de `await _play_narrative_beats()`).
## O patch pronto está em tools/perf/patches/vfx_prewarm.patch.
##
## O que faz: no load da fase (atrás do card de abertura), desenha UMA vez, num
## SubViewport 32×32 que ninguém vê e que some sozinho em ~0,2 s, cada
## combinação nó × material × textura que o combate só usaria pela 1ª vez no
## meio da luta. Assim o driver compila os shaders e sobe as texturas AGORA, e
## não no 1º golpe/1ª morte/1ª esquiva (os engasgos medidos em docs/onda2/PERF.md).
## Não toca som, não sacode a câmera, não entra no grupo "enemy"/"player" e tem
## o próprio World2D (o SubViewport isola a física: nada acerta ninguém).

## Texturas de VFX que o combate carrega sob demanda (assets/vfx/*.png, 128 px).
const PREWARM_TEX := ["circle", "dirt", "flame", "flame2", "flare", "glow", "halo", "light",
	"magic", "magic2", "scorch", "slash", "smoke", "smoke2", "spark", "spark2", "star",
	"star2", "symbol", "trace", "twirl", "window"]
## Folhas pintadas que as criaturas e os gibs usam (carregadas no 1º desenho).
const PREWARM_SHEETS := ["inhabitants", "archons"]


static func prewarm(level: Node) -> void:
	if level == null or not level.is_inside_tree():
		return
	# 1) Disco → memória (CPU): texturas de VFX e folhas das criaturas.
	for n in PREWARM_TEX:
		VfxLibrary.tex(n)
	var sheets: Array = PREWARM_SHEETS.duplicate()
	if RunManager.run_active and (RunManager.is_king_screen(RunManager.current_screen) or RunManager.is_final(RunManager.current_screen)):
		sheets.append("yaldabaoth")
	# 2) Memória → GPU + compilar shaders: um palco invisível.
	var vp := SubViewport.new()
	vp.name = "PrewarmStage"
	vp.size = Vector2i(32, 32)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	level.add_child(vp)
	var root := Node2D.new()
	vp.add_child(root)
	var c := Vector2(16, 16)
	var col := Color(1.0, 0.85, 0.5)
	# 2a) folhas pintadas com o material das pinturas (sobe a textura com mipmaps)
	for sh in sheets:
		var s := Sprite2D.new()
		s.texture = PaintedLibrary.sheet(sh)
		s.material = PaintedLibrary.material()
		s.scale = Vector2.ONE * 0.01
		s.position = c
		root.add_child(s)
	# 2b) gib: polígono texturizado com o material das pinturas (1ª morte desmembrada)
	var part := {
		"pts": PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)]),
		"col": Color.WHITE, "kind": "painted", "size": Vector2(8, 8), "flip": 1.0,
		"tex": PaintedLibrary.region("inhabitants", Rect2(0, 0, 64, 64)),
	}
	Gib.burst(root, c, [part], 1.0, 9999.0, Vector2.ZERO, col, Color.BLACK)
	# 2c) afterimage da esquiva (shader painted_ghost em malha de triângulos)
	var ghosts := CharacterArt.AfterimageLayer.new()
	root.add_child(ghosts)
	var tex: Texture2D = PaintedLibrary.sheet("inhabitants")
	var mesh: Dictionary = CharacterArt.grid_mesh("prewarm", Rect2(0, 0, 64, 64), Vector2(32, 64), Vector2(tex.get_width(), tex.get_height()))
	ghosts.add(Transform2D(0.0, Vector2(0.1, 0.1), 0.0, c), mesh, tex, Color(0.55, 0.85, 1.0, 0.5), 0.3)
	# 2d) os efeitos de partícula/sprite do combate, pelas funções reais
	#     (boss_death fica de fora: sacode a câmera; os nós dele já estão cobertos)
	VfxLibrary.hit(root, c, false, col)
	VfxLibrary.hit(root, c, true, col)
	VfxLibrary.parry(root, c)
	VfxLibrary.dodge_perfect(root, c)
	VfxLibrary.cast(root, c)
	VfxLibrary.nova_ring(root, c, 10.0)
	VfxLibrary.dust(root, c)
	VfxLibrary.spark_pickup(root, c)
	VfxLibrary.enemy_death(root, c, col)
	VfxLibrary.elite_death(root, c, col)
	VfxLibrary.boss_appear(root, c, col)
	VfxLibrary.boss_phase2(root, c, col)
	VfxLibrary.portal(root, c, Color(0.8, 0.9, 1.0), 0.1)
	var trail_host := Node2D.new()
	root.add_child(trail_host)
	VfxLibrary.projectile_trail(trail_host, col)
	ImpactBurst.spawn(root, c, col)
	DamageNumber.spawn(root, c, 1, col)
	# 3) Some depois de alguns quadros (tempo REAL: ignora hit-stop/pausa).
	level.get_tree().create_timer(0.2, true, false, true).timeout.connect(vp.queue_free)
