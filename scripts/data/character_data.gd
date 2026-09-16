extends Resource
class_name CharacterData
## "Molde" de um personagem jogável. Dados puros (sem lógica de jogo).

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var max_health: int = 100
@export var max_mana: int = 50
@export var move_speed: float = 190.0
@export var jump_velocity: float = -430.0
@export var sprite_color: Color = Color.WHITE       # placeholder até ter sprite
@export var combos: Array[ComboData] = []
@export var skills: Array[SkillData] = []
