extends Resource
class_name EnemyData
## "Molde" de um Arconte (inimigo).

@export var id: String = ""
@export var display_name: String = "Arconte"
@export var max_health: int = 30
@export var move_speed: float = 60.0
@export var contact_damage: int = 8
@export var spark_reward: int = 5              # faíscas soltas ao ser derrotado
@export var sprite_color: Color = Color(0.8, 0.3, 0.3)
