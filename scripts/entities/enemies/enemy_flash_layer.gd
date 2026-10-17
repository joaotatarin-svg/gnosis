extends Node2D
class_name EnemyFlashLayer
## FLASH ADITIVO dos inimigos (Onda 6 — QA2 #8): o golpe na criatura não pinta
## mais o corpo inteiro de branco (modulate 3×3×3 virava silhueta chapada).
## Como o da Sophia (Player.FlashLayer): redesenha a malha que o CharacterArt
## acabou de desenhar com o shader de SOMA na matiz do flash. A pintura por baixo
## continua legível e só "acende" — ≤ FLASH_TIME s reais.

const FLASH_TIME := 0.10         # o flash inteiro (s REAIS)
const FLASH_HOLD := 0.035        # cheio nos primeiros 35 ms, depois apaga

var art: CharacterArt
var hue: Color = Color.WHITE
var peak: float = 0.0
var t: float = -1.0              # s REAIS desde o disparo (<0 = apagado)
var _mat: ShaderMaterial
var _hold_frames: int = 0        # o quadro do golpe ainda tem a pose velha


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = VfxLibrary.flash_add_shader()
	material = _mat
	visible = false


## Há malha pintada para redesenhar? (procedural/boneco antigo: não)
func usable() -> bool:
	return art != null and is_instance_valid(art) and not art._body_mesh.is_empty() and art._body_tex != null


func fire(p_hue: Color, amount: float) -> void:
	hue = p_hue
	peak = maxf(amount, peak if t >= 0.0 and t < FLASH_HOLD else 0.0)
	t = 0.0
	_hold_frames = 1
	_sync()


func tick(real_dt: float) -> void:
	if t < 0.0:
		return
	t += real_dt
	_hold_frames -= 1
	if t >= FLASH_TIME or art == null or not is_instance_valid(art):
		t = -1.0
		visible = false
		return
	_sync()


func _sync() -> void:
	var a: float = peak
	if t > FLASH_HOLD:
		a = peak * (1.0 - (t - FLASH_HOLD) / (FLASH_TIME - FLASH_HOLD))
	visible = _hold_frames <= 0
	transform = art.transform
	z_index = art.z_index
	texture_filter = art.texture_filter
	_mat.set_shader_parameter("flash", Color(hue.r, hue.g, hue.b, clampf(a, 0.0, 1.0) * art.modulate.a))
	var src := art.material as ShaderMaterial
	if src != null:
		_mat.set_shader_parameter("bend", src.get_shader_parameter("bend"))
		_mat.set_shader_parameter("body_h", src.get_shader_parameter("body_h"))
	queue_redraw()


func _draw() -> void:
	if not usable() or not art.visible:
		return
	CharacterArt.draw_grid(get_canvas_item(), art._body_mesh, art._body_xform, art._body_tex, Color.WHITE)
