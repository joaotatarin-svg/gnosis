extends Node
class_name HealthComponent
## Componente reutilizável de vida. Player e Arcontes usam o mesmo.

signal health_changed(current: int, maximum: int)
signal died()

@export var max_health: int = 100
var current_health: int = 100


func _ready() -> void:
	current_health = max_health


func setup(new_max: int) -> void:
	max_health = new_max
	current_health = new_max
	health_changed.emit(current_health, max_health)


func take_damage(amount: int) -> void:
	if current_health <= 0:
		return
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit()


func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return current_health <= 0
