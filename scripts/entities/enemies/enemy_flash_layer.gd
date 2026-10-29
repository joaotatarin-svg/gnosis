extends Node2D
class_name EnemyFlashLayer
## FLASH ADITIVO dos inimigos (Onda 6 — QA2 #8): o golpe na criatura não pinta
## mais o corpo inteiro de branco (modulate 3×3×3 virava silhueta chapada).
## Como o da Sophia (Player.FlashLayer): redesenha a malha que o CharacterArt
## acabou de desenhar com o shader de SOMA na matiz do flash. A pintura por baixo
## continua legível e só "acende" — ≤ FLASH_TIME s reais.

const FLASH_TIME := 0.10         # o flash inteiro (s REAIS)
const FLASH_HOLD := 0.035        # cheio nos primeiros 35 ms, depois apaga

## Polimento 7 (R10/R18): a soma é igual em toda a pintura — num atlas CLARO
## (Astaphaios, Rei, Reflexo) o pico estoura o corpo grande em branco (R10); num
## ESCURO (conjurador, cornudo) quase não aparece (R1). Fator por atlas =
## clamp((1 − L) / (1 − 0,35), 0,55, 1,25), L = luminância média do corpo.
## Tabela gerada OFFLINE por `python -I tools/combate/flash_luma.py` (sem custo
## em jogo); atlas fora da tabela = 1,0.
const LUMA_K := {
	"bot_carcereiro_frames.png": 0.99,   # L 0.354
	"bot_esporos_frames.png": 0.93,   # L 0.397
	"bot_glutao_frames.png": 0.97,   # L 0.371
	"bot_mudo_frames.png": 0.93,   # L 0.392
	"bot_pretoriano_frames.png": 1.07,   # L 0.306
	"bot_reflexo_frames.png": 0.64,   # L 0.582
	"bot_sonambulo_frames.png": 1.11,   # L 0.275
	"bruto_frames.png": 1.15,   # L 0.253
	"cao_frames.png": 1.12,   # L 0.274
	"champ_carcereiro_frames.png": 0.99,   # L 0.354
	"champ_esporos_frames.png": 0.93,   # L 0.398
	"champ_glutao_frames.png": 1.00,   # L 0.347
	"champ_mudo_frames.png": 0.87,   # L 0.432
	"champ_pretoriano_frames.png": 1.06,   # L 0.310
	"champ_reflexo_frames.png": 0.65,   # L 0.578
	"champ_sonambulo_frames.png": 1.11,   # L 0.277
	"conjurador_frames.png": 1.24,   # L 0.192
	"en_acolito_frames.png": 0.97,   # L 0.369
	"en_alado_frames.png": 0.86,   # L 0.444
	"en_cornudo_frames.png": 1.25,   # L 0.183
	"en_espectro_frames.png": 1.06,   # L 0.310
	"en_fantasma_frames.png": 1.17,   # L 0.237
	"escudeiro_frames.png": 1.15,   # L 0.255
	"espadachim_frames.png": 1.16,   # L 0.246
	"larva_frames.png": 1.09,   # L 0.288
	"sleeper_frames.png": 0.93,   # L 0.394
	"soter_frames.png": 0.56,   # L 0.634
	"velkar_frames.png": 1.06,   # L 0.308
	"armupiel_frames.png": 1.05,   # L 0.315
	"astaphaios_frames.png": 0.57,   # L 0.631
	"athoth_frames.png": 1.16,   # L 0.247
	"belias_frames.png": 0.93,   # L 0.394
	"colosso_frames.png": 1.06,   # L 0.313
	"galila_frames.png": 0.98,   # L 0.360
	"harmas_frames.png": 1.06,   # L 0.314
	"rei_frames.png": 0.73,   # L 0.526
	"yabel_frames.png": 1.04,   # L 0.324
	"cego_pequeno_frames.png": 0.83,   # L 0.463
}


## Fator de brilho do atlas que o Visual desenha agora (1,0 se desconhecido).
func luma_k() -> float:
	if not usable():
		return 1.0
	var p: String = art._body_tex.resource_path
	if p == "":
		return 1.0
	return float(LUMA_K.get(p.get_file(), 1.0))

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
