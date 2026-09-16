extends Resource
class_name SkillData
## Uma magia/skill. Consome Éter (MP) e sobe de nível na loja.
## `ring` = id do Arconte cujo Anel dá esta magia ("" = magia inata).

enum SkillType { MELEE, PROJECTILE, AOE, BUFF }

@export var id: String = ""
@export var display_name: String = ""
@export var type: SkillType = SkillType.MELEE
@export var mana_cost: int = 10
@export var base_damage: int = 25
@export var max_level: int = 3
@export var cooldown: float = 2.0
@export var ring: String = ""
@export var color: Color = Color(1.0, 0.95, 0.7)
@export_multiline var description: String = ""
