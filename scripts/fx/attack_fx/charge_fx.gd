extends Node2D
class_name ChargeFX
## ANTECIPAÇÃO DE ATAQUE (VFX7): a luz se junta antes do disparo. Filho de quem
## vai atacar (segue o corpo), cresce durante `duration` (0,2–0,9 s) e termina
## num "estalo" no instante do disparo. Partículas convergem para o ponto,
## um círculo (runas na luz da Sophia, coroa de espinhos na luz corrompida)
## gira e fecha, o núcleo incha e clareia; som curto no início.
##
## Uso:  VfxLibrary.charge_up(self, Vector2(16 * dir, -20), cor, wind_up, "dark")
## Devolve o nó: `cancel()` apaga sem estalo (golpe interrompido/parry).

var color: Color = Color(1.0, 0.9, 0.55)
var duration: float = 0.3
var style: String = "light"          # "light" (Sophia) · "dark" (Arcontes) · "king"
var silent: bool = false             # sem som (pré-aquecimento)
var _t: float = 0.0
var _core: Sprite2D
var _glow: Sprite2D
var _circle: Sprite2D
var _motes: CPUParticles2D
var _gone: bool = false

## Sons opcionais (só tocam se existirem no CATÁLOGO do Áudio — pedido em
## docs/pedidos/vfx7.md); sem eles, um "proj_fire" grave e baixo faz as vezes.
const SND_LIGHT := "charge_light"
const SND_DARK := "charge_dark"
const SND_FALLBACK := "proj_fire"


func _ready() -> void:
	z_index = 3
	var light := style == "light"
	var big := style == "king"
	_glow = Sprite2D.new()
	_glow.texture = VfxLibrary.tex("glow")
	_glow.material = VfxLibrary._additive()
	_glow.modulate = Color(color.r, color.g, color.b, 0.0)
	add_child(_glow)
	_circle = Sprite2D.new()
	_circle.texture = VfxLibrary.tex("symbol" if light else "star")
	_circle.material = VfxLibrary._additive()
	_circle.modulate = Color(color.r, color.g, color.b, 0.0)
	add_child(_circle)
	_motes = CPUParticles2D.new()
	_motes.texture = VfxLibrary.tex("spark2" if light else "spark")
	_motes.material = VfxLibrary._additive()
	_motes.amount = 14 if big else 10
	_motes.lifetime = 0.3
	_motes.local_coords = true
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	_motes.emission_sphere_radius = 30.0 if big else 20.0
	_motes.gravity = Vector2.ZERO
	_motes.radial_accel_min = -420.0 if big else -300.0
	_motes.radial_accel_max = -260.0 if big else -200.0
	_motes.initial_velocity_min = 0.0
	_motes.initial_velocity_max = 10.0
	_motes.scale_amount_min = 0.03
	_motes.scale_amount_max = 0.07
	_motes.scale_amount_curve = VfxLibrary._grow_curve()
	_motes.color_ramp = VfxLibrary._ramp(Color(color.r, color.g, color.b, 0.0), Color(1, 1, 1, 1))
	add_child(_motes)
	_motes.emitting = true
	_core = Sprite2D.new()
	_core.texture = VfxLibrary.tex("circle")
	_core.material = AttackStyle.orb_material("king" if big else ("light" if light else "dark"))
	_core.modulate = Color(color.r, color.g, color.b, 0.0)
	_core.scale = Vector2.ONE * 0.02
	add_child(_core)
	_sound()


func _sound() -> void:
	if silent:
		return
	var cat = Audio.get("CATALOG")
	var sfx: Array = cat.get("sfx", []) if cat is Dictionary else []
	var want := SND_LIGHT if style == "light" else SND_DARK
	if sfx.has(want):
		Audio.play_sfx_at(want, global_position)
	elif sfx.has(SND_FALLBACK):
		Audio.play_sfx_pitched(SND_FALLBACK, 0.55 if style != "light" else 0.75, -9.0, global_position)


func _process(delta: float) -> void:
	if _gone:
		return
	_t += delta
	var k := clampf(_t / maxf(duration, 0.01), 0.0, 1.0)
	var e := k * k                          # brilho cresce acelerando
	var big := style == "king"
	var core_s := (0.16 if big else 0.1) * (0.2 + 0.8 * e)
	_core.scale = Vector2.ONE * core_s * (1.0 + sin(_t * 40.0) * 0.06 * k)
	_core.modulate.a = minf(1.0, 0.3 + k)
	_glow.scale = Vector2.ONE * (0.18 + 0.32 * e) * (1.6 if big else 1.0)
	_glow.modulate.a = 0.15 + 0.5 * e
	# o círculo fecha sobre o ponto e gira cada vez mais rápido
	_circle.scale = Vector2.ONE * lerpf(0.42, 0.16, k) * (1.5 if big else 1.0)
	_circle.rotation += delta * (2.0 + 10.0 * k) * (1.0 if style == "light" else -1.0)
	_circle.modulate.a = 0.75 * sin(k * PI * 0.5 + 0.2)
	if k >= 1.0:
		release()


## Disparo: estalo curto e some. Chamado sozinho ao fim de `duration`.
func release() -> void:
	if _gone:
		return
	_gone = true
	var par := get_parent()
	if par != null and is_instance_valid(par) and par.get_parent() != null:
		var at := global_position
		var world := par.get_parent()
		VfxLibrary._flash_sprite(world, at, "light", Color(color.r, color.g, color.b, 0.9), 0.1, 0.45 if style == "king" else 0.3, 0.12)
		VfxLibrary.shock_ring(world, at, 26.0 if style == "king" else 16.0, color, 0.2, style != "light")
	queue_free()


## Interrompido (parry, atordoado, morreu): apaga sem estalo.
func cancel() -> void:
	if _gone:
		return
	_gone = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.1)
	tw.tween_callback(queue_free)
