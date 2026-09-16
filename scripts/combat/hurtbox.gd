extends Area2D
class_name Hurtbox
## Área que RECEBE dano. Repassa ao dono, incluindo se o golpe é imparável
## (não dá parry) e quem foi o atacante (pra atordoar em caso de parry).

signal hit_received(damage: int, source_position: Vector2, knockback: float, unblockable: bool, attacker: Node)

@export var team: String = "enemy"      # "player" ou "enemy"


func receive_hit(damage: int, source_position: Vector2, knockback: float, unblockable: bool = false, attacker: Node = null) -> void:
	hit_received.emit(damage, source_position, knockback, unblockable, attacker)
