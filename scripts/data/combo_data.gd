extends Resource
class_name ComboData
## Um golpe dentro de uma string de combo (estilo God of War).
## O combo é reconhecido pela SEQUÊNCIA de botões (leve/forte).

@export var id: String = ""
@export var display_name: String = ""
## Sequência de botões que ativa este golpe. Ex: ["light", "light", "heavy"].
@export var sequence: Array[String] = ["light"]
@export var damage: int = 12
@export var required_weapon_level: int = 1
@export var duration: float = 0.26          # duração do golpe
@export var chain_time: float = 0.34        # janela extra pra continuar o combo
@export var lunge: float = 90.0             # avanço pra frente no golpe
@export var knockback: float = 140.0
@export var launcher: bool = false          # lança o inimigo pro alto (juggle)
@export var air: bool = false               # golpe AÉREO (só sai no ar)
@export var hits: int = 1                   # multi-hit: a hitbox religa N vezes
@export var aoe_radius: float = 0.0         # >0: nova de área ao conectar
@export_multiline var description: String = ""


## Golpe pesado = a sequência termina em "heavy". Ganha wind-up, peso e uma
## animação de carregar-e-descer distinta do leve.
func is_heavy() -> bool:
	return sequence.size() > 0 and sequence[sequence.size() - 1] == "heavy"


## Tempo de "carregar" antes do golpe conectar (leve é quase imediato).
func windup_time() -> float:
	if air:
		return 0.03
	return 0.17 if is_heavy() else 0.04


## Recuperação após o golpe: você fica comprometido e não pode reatacar por esse
## tempo (o inimigo tem uma janela). Forte recupera bem mais; combos maiores idem.
func recovery_time() -> float:
	var base := 0.34 if is_heavy() else 0.16
	base += float(sequence.size() - 1) * 0.05
	if aoe_radius > 0.0:
		base += 0.2
	return base
