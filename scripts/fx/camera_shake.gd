extends Camera2D
## Trepidação de câmera baseada em "trauma" que decai. Só deslocamento
## (sem rotação, pra não borrar o pixel art). Escuta o autoload Juice.

@export var max_offset := Vector2(9, 7)
@export var decay := 1.4          # quão rápido o tremor some
@export var noise_speed := 30.0
## Enquadramento: câmera olha um pouco pra cima (mais céu/cenário, menos chão).
@export var base_offset := Vector2(0, -62)

var trauma := 0.0
var _time := 0.0


func _ready() -> void:
	Juice.shake_requested.connect(_add_trauma)
	offset = base_offset


func _add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if trauma <= 0.0:
		offset = base_offset
		return
	_time += delta * noise_speed
	trauma = maxf(trauma - decay * delta, 0.0)
	var amount := trauma * trauma      # curva quadrática = mais natural
	offset = base_offset + Vector2(
		max_offset.x * amount * randf_range(-1.0, 1.0),
		max_offset.y * amount * randf_range(-1.0, 1.0)
	)
