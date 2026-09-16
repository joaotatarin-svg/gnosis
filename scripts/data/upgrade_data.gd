extends Resource
class_name UpgradeData
## Entrada de loja (Santuário de Ascensão). Usada quando migrarmos a loja
## pra dados editáveis; por ora a loja monta as opções em código.

enum Kind { WEAPON_LEVEL, SKILL_LEVEL, MAX_HEALTH, MAX_MANA }

@export var id: String = ""
@export var display_name: String = ""
@export var kind: Kind = Kind.WEAPON_LEVEL
@export var cost: int = 50
@export var target_id: String = ""       # id da magia, quando aplicável
@export_multiline var description: String = ""
