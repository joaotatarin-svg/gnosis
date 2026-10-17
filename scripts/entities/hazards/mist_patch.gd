extends LevelHazard
class_name MistPatch
## TORPOR — poça de névoa do sono rente ao chão. A névoa RESPIRA (período 6 s):
## quando incha, quem está dentro anda devagar (Sophia a 45 %; inimigos também);
## quando recua, dá pra passar livre. Ler a respiração é a jogada; pular por cima
## da névoa (ou ir pelas plataformas) também vale. Não fere.

const PERIOD := 6.0
const THICK := 0.5          # densidade a partir da qual lentifica

var width: float = 220.0
var _blobs: Array = []      # [dx, dy, raio, velocidade]


func _ready() -> void:
	hazard_kind = "névoa"
	z_index = 7             # por cima dos pés (como a névoa rasteira)
	var r := RandomNumberGenerator.new()
	r.seed = hash("mist/%d/%d" % [GameManager.current_screen, int(global_position.x)])
	for i in 9:
		_blobs.append([r.randf_range(-width * 0.5, width * 0.5), r.randf_range(-26.0, -4.0), r.randf_range(26.0, 46.0), r.randf_range(0.2, 0.6)])


## 0..1: quanto a névoa está cheia agora.
func density() -> float:
	return 0.5 + 0.5 * sin(_cycle(PERIOD) / PERIOD * TAU)


func _tick(_delta: float) -> void:
	if not _live() or density() < THICK:
		return
	var area := Rect2(global_position.x - width * 0.5, global_position.y - 70.0, width, 80.0)
	var p := _player()
	if area.has_point(p.global_position):
		p.status_slow = maxf(p.status_slow, 0.15)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and is_instance_valid(e) and area.has_point((e as Node2D).global_position):
			e.apply_slow(0.2)


func _draw() -> void:
	var d := density()
	var col := Color(0.55, 0.5, 0.85)
	for b in _blobs:
		var drift: float = sin(_t * float(b[3]) + float(b[0])) * 10.0
		var c := Vector2(float(b[0]) + drift, float(b[1]))
		var rad: float = float(b[2]) * (0.75 + 0.35 * d)
		draw_circle(c, rad, Color(col, 0.07 + 0.13 * d))
		draw_circle(c, rad * 0.6, Color(col.lightened(0.2), 0.05 + 0.10 * d))
	# Borda: linha baixa que acende quando a névoa está cheia (é quando pega).
	if d >= THICK:
		draw_line(Vector2(-width * 0.5, 0), Vector2(width * 0.5, 0), Color(0.75, 0.7, 1.0, 0.35 * d), 2.0, true)
