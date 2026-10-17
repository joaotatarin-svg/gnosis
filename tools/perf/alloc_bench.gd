extends Node
## FERRAMENTA (não faz parte do jogo): MICRO-MEDIÇÃO da alocação por quadro no
## desenho das ilustrações (REVISAO #16). Mede, em µs por chamada, cada pedaço
## que `CharacterArt._draw_painted` refaz TODO quadro para CADA personagem, e a
## versão proposta (cache por instância / const). Headless, sem janela:
##   godot --headless --audio-driver Dummy --path . res://tools/perf/AllocBench.tscn -- [n=20000] [out=x.json]
## Multiplique por (personagens na tela × qps) para ter o custo por segundo.

var n: int = 20000
var out: String = ""

const CHAIN_CONST := {
	"walk": ["run"], "charge": ["run"], "dodge_back": ["dodge"], "attack_up": ["attack_heavy", "attack"],
	"attack_air": ["attack_heavy", "attack"], "attack_dive": ["attack_air", "attack_heavy", "attack"],
	"windup_heavy": ["windup"], "windup_cast": ["cast"], "fall": ["jump"], "dead": ["hurt"],
	"recover": ["idle"], "attack_heavy": ["attack"],
}


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "n":
			n = int(kv[1])
		elif kv.size() == 2 and kv[0] == "out":
			out = kv[1]
	_run.call_deferred()


func _bench(label: String, f: Callable) -> float:
	# melhor de 5 (a máquina é compartilhada: o mínimo é o custo real)
	var best := INF
	for r in 5:
		var t0 := Time.get_ticks_usec()
		f.call()
		best = minf(best, float(Time.get_ticks_usec() - t0))
	var us := best / float(n)
	print("ALLOC %-46s %8.3f us/chamada" % [label, us])
	return us


func _run() -> void:
	var res := {}
	var rect := Rect2(425, 0, 425, 400)
	var anchor := Vector2(637.5, 400)
	var sheet := "inhabitants"
	var flip := false
	var painted := {"sheet": sheet, "rect": rect, "flip": flip}
	var tex: Texture2D = PaintedLibrary.sheet(sheet)
	var sz := Vector2(tex.get_width(), tex.get_height())
	# aquece os caches estáticos (como no jogo depois do 1º quadro)
	CharacterArt.grid_mesh("%s:%s@%s:%s" % [sheet, rect, anchor, flip], rect, anchor, sz, flip)
	PaintedLibrary.region(sheet, rect)

	# --- HOJE: chave do cache da malha formatada a cada quadro (Rect2/Vector2 → texto)
	res["hoje_chave_malha_formatada"] = _bench("hoje: chave da malha (\"%s:%s@%s:%s\" % ...)", func():
		for i in n:
			var _k: String = "%s:%s@%s:%s" % [painted.get("sheet", "sophia"), rect, anchor, painted.get("flip", false)])
	res["hoje_grid_mesh_com_chave"] = _bench("hoje: grid_mesh(chave formatada) [acerto]", func():
		for i in n:
			var _m: Dictionary = CharacterArt.grid_mesh("%s:%s@%s:%s" % [painted.get("sheet", "sophia"), rect, anchor, painted.get("flip", false)], rect, anchor, sz, painted.get("flip", false)))
	# --- PROPOSTO: a malha guardada na instância (só refaz se a folha/recorte mudar)
	var cache := {"mesh": {}, "rect": Rect2()}
	res["proposto_malha_na_instancia"] = _bench("proposto: malha guardada na instância", func():
		for i in n:
			var m: Dictionary = cache.mesh
			if m.is_empty() or cache.rect != rect:
				cache.mesh = CharacterArt.grid_mesh("%s:%s@%s:%s" % [sheet, rect, anchor, flip], rect, anchor, sz, flip)
				cache.rect = rect
				m = cache.mesh
			var _x := m)
	# --- Sophia: chave "sophia:%s@%s" % [e.f, anchor] a cada quadro
	res["hoje_chave_sophia"] = _bench("hoje: chave da Sophia (\"sophia:%s@%s\" % ...)", func():
		for i in n:
			var _k: String = "sophia:%s@%s" % [37, anchor])
	# --- _hero_seq: dicionário `chain` montado a cada quadro × const
	res["hoje_chain_literal"] = _bench("hoje: dicionário chain literal (_hero_seq)", func():
		for i in n:
			var chain := {
				"walk": ["run"], "charge": ["run"], "dodge_back": ["dodge"], "attack_up": ["attack_heavy", "attack"],
				"attack_air": ["attack_heavy", "attack"], "attack_dive": ["attack_air", "attack_heavy", "attack"],
				"windup_heavy": ["windup"], "windup_cast": ["cast"], "fall": ["jump"], "dead": ["hurt"],
				"recover": ["idle"], "attack_heavy": ["attack"],
			}
			var _c = chain.get("idle", []))
	res["proposto_chain_const"] = _bench("proposto: const CHAIN", func():
		for i in n:
			var _c = CHAIN_CONST.get("idle", []))
	# --- PaintedLibrary.region: chave file + str(rect) (gibs/props)
	res["hoje_region_str_rect"] = _bench("hoje: PaintedLibrary.region (file+str(rect))", func():
		for i in n:
			var _t := PaintedLibrary.region(sheet, rect))
	# --- uniforms: 11 set_shader_parameter por personagem por quadro
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/painted_flex.gdshader")
	res["hoje_11_uniforms"] = _bench("hoje: 11 set_shader_parameter", func():
		for i in n:
			mat.set_shader_parameter("body_h", 60.0)
			mat.set_shader_parameter("bend", 0.0)
			mat.set_shader_parameter("wind_time", float(i))
			mat.set_shader_parameter("use_flex", false)
			mat.set_shader_parameter("hair_amp", 0.0)
			mat.set_shader_parameter("cloth_amp", 0.0)
			mat.set_shader_parameter("texel", Vector2(0.001, 0.001))
			mat.set_shader_parameter("hem_wave", 0.0)
			mat.set_shader_parameter("dissolve", 0.0)
			mat.set_shader_parameter("glow_color", Color.WHITE))
	# --- draw_grid: cópia + transform da malha e array de cores (inevitável hoje)
	var ci := RenderingServer.canvas_item_create()
	var grid: Dictionary = CharacterArt.grid_mesh("%s:%s@%s:%s" % [sheet, rect, anchor, flip], rect, anchor, sz, flip)
	res["hoje_draw_grid"] = _bench("hoje: draw_grid (malha + cores + RS)", func():
		for i in n:
			CharacterArt.draw_grid(ci, grid, Transform2D(0.0, Vector2(0.2, 0.2), 0.0, Vector2.ZERO), tex, Color.WHITE)
			RenderingServer.canvas_item_clear(ci))
	RenderingServer.free_rid(ci)
	res["n"] = n
	print("ALLOCJSON ", JSON.stringify(res))
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(res, "\t"))
			f.close()
	get_tree().quit()
