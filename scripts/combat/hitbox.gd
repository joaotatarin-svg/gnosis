extends Area2D
class_name Hitbox
## Área que CAUSA dano. Só acerta Hurtboxes de time diferente.
## `unblockable` = golpe vermelho estilo GoW (não pode ser aparado, só desviado).

@export var damage: int = 10
@export var knockback: float = 140.0
@export var team: String = "player"      # "player" ou "enemy"
@export var unblockable: bool = false
@export var active_by_default: bool = false


func _ready() -> void:
	monitoring = active_by_default
	area_entered.connect(_on_area_entered)


func activate(new_damage: int = -1) -> void:
	if new_damage >= 0:
		damage = new_damage
	monitoring = true


func deactivate() -> void:
	monitoring = false


func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox and area.team != team:
		area.receive_hit(damage, global_position, knockback, unblockable, owner)
		# Peso do impacto (escala levemente com o dano) + fagulhas.
		Juice.hit_stop(0.05)
		Juice.shake(0.18 + minf(damage, 40) * 0.006)
		Audio.play_sfx("hit")
		if team == "player" and owner != null and owner.has_method("register_hit"):
			owner.register_hit()
		if owner != null and owner.has_method("on_hit_landed"):
			owner.on_hit_landed(damage)
		if owner != null and owner.get_parent() != null:
			var col := Color(1.0, 0.92, 0.7) if team == "player" else Color(1.0, 0.45, 0.35)
			ImpactBurst.spawn(owner.get_parent(), area.global_position, col)
