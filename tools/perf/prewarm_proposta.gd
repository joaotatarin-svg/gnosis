extends RefCounted
## CORREÇÃO PROPOSTA (agente de Desempenho, Onda 2) — NÃO faz parte do jogo ainda.
## É o corpo de `VfxLibrary.prewarm(level)`: o dono de `scripts/fx/vfx_library.gd`
## copia `prewarm` (+ constantes e `_warm_refs`) para lá e o dono de `level.gd`
## chama `VfxLibrary.prewarm(self)` no `_ready` da fase, logo depois de
## `_spawn_extras()` (antes de `await _play_narrative_beats()`).
## Patch pronto: tools/perf/patches/vfx_prewarm.patch.
##
## O que faz: no load da fase, desenha por 3 quadros, no centro da câmera e
## QUASE TRANSPARENTE (alfa 0,01 em escala 0,25: ~2/255 de brilho em poucos
## pixels, atrás do card de abertura), cada combinação nó × material que o
## combate só usaria pela 1ª vez no meio da luta; e carrega (segurando a
## referência) as texturas que a 1ª criatura/1º efeito carregariam do disco.
## Assim o driver compila as variantes de shader e sobe as texturas AGORA, e não
## no 1º golpe/1ª morte/1ª esquiva (engasgos medidos em docs/onda2/PERF.md).
## Não toca som, não sacode a câmera, não entra nos grupos do jogo.
##
## Por que não um SubViewport invisível: medido — as variantes compiladas lá
## não serviram para o desenho na tela (a 1ª morte ainda compilava). E alfa
## < 0,007 é descartado pelo Godot antes de desenhar (não compila nada).

## Texturas de VFX que o combate carrega sob demanda (assets/vfx/*.png, 128 px).
const PREWARM_TEX := ["circle", "dirt", "flame", "flame2", "flare", "glow", "halo", "light",
	"magic", "magic2", "scorch", "slash", "smoke", "smoke2", "spark", "spark2", "star",
	"star2", "symbol", "trace", "twirl", "window"]
## Folhas pintadas que as criaturas e os gibs usam (carregadas no 1º desenho).
const PREWARM_SHEETS := ["inhabitants", "archons"]
const PREWARM_ALPHA := 0.01      # >= 0,007 (abaixo disso o Godot nem desenha)
const PREWARM_FRAMES := 3

## Referências seguradas até a próxima fase (o cache de recursos do Godot solta
## o que ninguém segura; sem isto o load() seguinte relê do disco).
static var _warm_refs: Array = []


static func prewarm(level: Node) -> void:
	if level == null or not level.is_inside_tree():
		return
	_warm_refs.clear()
	# 1) Disco → memória → GPU: texturas de VFX, folhas das criaturas e o
	#    boneco articulado da variante do Éon (família do Arconte).
	for n in PREWARM_TEX:
		VfxLibrary.tex(n)
	var screen: int = RunManager.current_screen if RunManager.run_active else 0
	var sheets: Array = PREWARM_SHEETS.duplicate()
	if RunManager.run_active and (RunManager.is_king_screen(screen) or RunManager.is_final(screen)):
		sheets.append("yaldabaoth")
	for sh in sheets:
		_warm_refs.append(PaintedLibrary.sheet(sh))
	var eon: int = RunManager.eon_index(screen) if RunManager.run_active else -1
	var puppet_tex: Texture2D = null
	if eon >= 0 and eon < 7 and not RunManager.is_king_screen(screen):
		if ResourceLoader.exists(BossPuppet.BAKE_PATH):
			_warm_refs.append(load(BossPuppet.BAKE_PATH))
		for layer in ["body", "parts", "arm_l", "arm_r"]:
			var path: String = BossPuppet.DERIVED + BossPuppet.NAMES[eon] + "_" + layer + ".png"
			if ResourceLoader.exists(path):
				var t = load(path)
				_warm_refs.append(t)
				if puppet_tex == null:
					puppet_tex = t
	# 2) Compilar as variantes: um palco quase transparente no centro da câmera.
	var stage := Node2D.new()
	stage.name = "PrewarmStage"
	stage.modulate = Color(1, 1, 1, PREWARM_ALPHA)
	stage.scale = Vector2.ONE * 0.25
	level.add_child(stage)
	var cam := level.get_viewport().get_camera_2d()
	stage.global_position = cam.get_screen_center_position() if cam != null else Vector2(320, 180)
	var at := stage.global_position
	var col := Color(1.0, 0.85, 0.5)
	# 2a) folhas pintadas com o material das pinturas (rect + painted_clean),
	#     na escala em que aparecem no jogo (~1/5: usa os mesmos mipmaps)
	for t in _warm_refs:
		if t is Texture2D:
			var spr := Sprite2D.new()
			spr.texture = t
			spr.material = PaintedLibrary.material()
			spr.scale = Vector2.ONE * 0.8
			stage.add_child(spr)
	# 2b) as criaturas desta tela: o VISUAL real (CharacterArt, sem Enemy: fora
	#     do grupo "enemy", sem física/IA) — material próprio, folha, e o boneco
	#     articulado da variante do Éon — e o 1º desmembramento de cada uma
	#     (gibs reais, recortes da folha + painted_clean).
	var types: Array = []
	for id in Bestiary.types_for_screen(screen):
		if not id in types:
			types.append(id)
	for id in types:
		var prof = Bestiary.get_type(id).get("profile", null)
		if prof == null:
			continue
		var art := CharacterArt.new()
		stage.add_child(art)
		art.set_profile(prof)
		var parts: Array = art.gib_parts()
		if not parts.is_empty():
			Gib.burst(stage, at, parts, 1.0, at.y + 9999.0, Vector2.ZERO, col, Color.BLACK)
	# 2c) afterimage da esquiva (painted_ghost em malha de triângulos, sobre o
	#     atlas da Sophia). A camada é top_level (coordenadas de MUNDO): o alfa
	#     vai na cor da cópia.
	var ghosts := CharacterArt.AfterimageLayer.new()
	stage.add_child(ghosts)
	var db: Dictionary = CharacterArt.frame_db("sophia")
	var tex: Texture2D = db.atlas if not db.is_empty() else PaintedLibrary.sheet("inhabitants")
	var mesh: Dictionary = CharacterArt.grid_mesh("prewarm", Rect2(0, 0, 64, 64), Vector2(32, 64), Vector2(tex.get_width(), tex.get_height()))
	ghosts.add(Transform2D(0.0, Vector2(0.25, 0.25), 0.0, at), mesh, tex, Color(0.55, 0.85, 1.0, PREWARM_ALPHA * 2.0), 0.5)
	# 2d) boneco articulado (Skeleton2D deforma Polygon2D: shader de esqueleto)
	var sk := Skeleton2D.new()
	sk.name = "Sk"
	var bone := Bone2D.new()
	bone.name = "B"
	bone.rest = Transform2D.IDENTITY
	bone.set_autocalculate_length_and_angle(false)
	bone.set_length(8.0)
	sk.add_child(bone)
	stage.add_child(sk)
	var poly := Polygon2D.new()
	poly.texture = puppet_tex if puppet_tex != null else PaintedLibrary.sheet("inhabitants")
	poly.polygon = PackedVector2Array([Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)])
	poly.uv = PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)])
	stage.add_child(poly)
	poly.skeleton = poly.get_path_to(sk)
	poly.add_bone(NodePath("B"), PackedFloat32Array([1.0, 1.0, 1.0, 1.0]))
	# 2e) os efeitos do combate, pelas funções reais
	#     (boss_death fica de fora: sacode a câmera; os nós dele já estão cobertos)
	VfxLibrary.hit(stage, at, false, col)
	VfxLibrary.hit(stage, at, true, col)
	VfxLibrary.parry(stage, at)
	VfxLibrary.dodge_perfect(stage, at)
	VfxLibrary.cast(stage, at)
	VfxLibrary.nova_ring(stage, at, 10.0)
	VfxLibrary.dust(stage, at)
	VfxLibrary.spark_pickup(stage, at)
	VfxLibrary.enemy_death(stage, at, col)
	VfxLibrary.elite_death(stage, at, col)
	VfxLibrary.boss_appear(stage, at, col)
	VfxLibrary.boss_phase2(stage, at, col)
	VfxLibrary.portal(stage, at, Color(0.8, 0.9, 1.0), 0.1)
	var trail_host := Node2D.new()
	stage.add_child(trail_host)
	VfxLibrary.projectile_trail(trail_host, col)
	ImpactBurst.spawn(stage, at, col)
	DamageNumber.spawn(stage, at, 1234567890, col)   # todos os glifos 0–9 da fonte
	# 3) Some depois de PREWARM_FRAMES quadros DESENHADOS (compila no desenho).
	var left := [PREWARM_FRAMES]
	var done := func() -> void:
		left[0] -= 1
		if left[0] == 0 and is_instance_valid(stage):
			stage.queue_free()
	RenderingServer.frame_post_draw.connect(done)
	stage.tree_exited.connect(func(): RenderingServer.frame_post_draw.disconnect(done), CONNECT_ONE_SHOT)
