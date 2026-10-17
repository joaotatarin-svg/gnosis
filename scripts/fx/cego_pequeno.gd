extends Node2D
class_name CegoPequeno
## O CEGO PEQUENO (cena D, anagnórise): o que sobra dentro do Colosso oco —
## encolhido e cego, do tamanho do pé da Sophia. Quadros pintados (folha do GPT
## `artes/gpt/cego_pequeno_a.png` → tools/anim_bosses/boss_frames.py cego_pequeno →
## assets/painted/derived/npcs/cego_pequeno_frames.*).
##
## Substitui o `_Little` de staging.gd (um disco desenhado) com a MESMA interface:
##  - `glow` 0..1 (a encenação anima): 0 = encolhido, sobe → olha pra cima →
##    estende a mão → é erguido; com `glow` cheio e a escala reduzida (vai pra
##    mão dela) → aninhado;
##  - `modulate`, `scale`, `global_position` como qualquer Node2D.
## Também aceita `set_anim("curled"|"trembling"|"look_up"|"reach"|"lifted"|"nestled")`,
## que trava a pose (desliga a escolha automática pelo `glow`).
## Origem do nó = chão (a base do manto); altura ≈ HEIGHT px de mundo na escala 1.

const DB := "npcs/cego_pequeno"
const HEIGHT := 22.0                 # altura do corpo encolhido (px de mundo, escala 1)

var glow: float = 0.0
var auto_pose: bool = true
var pose: String = "curled"
var _t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # a cena pode pausar a árvore
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## Trava uma pose (a encenação manda); "" volta à escolha automática pelo glow.
func set_anim(state: String) -> void:
	if state == "":
		auto_pose = true
		return
	auto_pose = false
	pose = state


func _process(d: float) -> void:
	_t += d
	if auto_pose:
		pose = _pose_for_glow()
	queue_redraw()


func _pose_for_glow() -> String:
	if glow <= 0.01:
		# encolhido (a máscara caída só existe neste quadro: o tremor é do
		# corpo todo, no _draw, sem trocar a pintura)
		return "curled"
	if glow >= 0.99 and absf(scale.x) < 0.8:
		return "nestled"                           # já na mão dela
	if glow < 0.45:
		return "look_up"
	if glow < 0.9:
		return "reach"
	return "lifted"


func _draw() -> void:
	var db: Dictionary = CharacterArt.frame_db(DB)
	if db.is_empty():
		_draw_fallback()
		return
	var meta: Dictionary = db.meta
	var st: String = pose if meta.states.has(pose) else "curled"
	var e: Dictionary = meta.states[st].frames[0]
	var fr: Dictionary = meta.frames[e.f]
	var rr: Array = fr.rect
	var src := Rect2(rr[0], rr[1], rr[2], rr[3])
	var k: float = HEIGHT / float(meta.body_px)
	var anchor := Vector2(e.anchor[0], e.anchor[1])
	# respiração e tremor (encolhido): corpo inteiro, pés no chão
	var breath: float = 1.0 + 0.025 * sin(_t * 2.4)
	var shake: float = 0.0
	if st in ["curled", "trembling"]:
		# tremor em surtos (≈1 s a cada 4 s), mais forte na pose "trembling"
		var burst: float = 1.0 if fmod(_t, 4.0) > 2.8 else 0.3
		shake = sin(_t * 31.0) * (0.4 if st == "trembling" else 0.25) * burst
	draw_set_transform(Vector2(shake, 0.0), 0.0, Vector2(1.0, breath))
	var dst := Rect2(-anchor * k, src.size * k)
	# halo quente quando a Sophia o ergue (como o _Little antigo)
	if glow > 0.0:
		draw_circle(Vector2(0, -HEIGHT * 0.5), HEIGHT * 0.95, Color(1, 0.95, 0.75, 0.22 * glow))
	# contorno pálido: lê no fundo escuro da Mente
	var sil: Texture2D = db.get("sil", null)
	if sil != null:
		for j in 8:
			var off := Vector2.from_angle(TAU * j / 8.0) * 0.8
			draw_texture_rect_region(sil, Rect2(dst.position + off, dst.size), src, Color(0.85, 0.82, 0.95, 0.11))
	var tint := Color.WHITE.lerp(Color(1.15, 1.08, 0.95), glow)
	draw_texture_rect_region(db.atlas, dst, src, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Sem atlas (export sem os derivados): o desenho antigo, para não sumir.
func _draw_fallback() -> void:
	var body := Color(0.08, 0.07, 0.1).lerp(Color(1, 0.95, 0.8), glow)
	draw_circle(Vector2(0, -7), 9.0, Color(0.85, 0.82, 0.95, 0.18))
	draw_circle(Vector2(0, -7), 7.5, body)
	draw_circle(Vector2(3, -13), 4.6, body)
