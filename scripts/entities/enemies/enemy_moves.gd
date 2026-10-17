extends RefCounted
class_name EnemyMoves
## REPERTÓRIO dos inimigos comuns (Onda 6, inimigos6). Cada tipo tem 2–3
## golpes de TIPOS diferentes — não só "anda e bate". O Enemy escolhe entre os
## golpes que cabem na distância atual (peso + tempo de recarga próprio), com
## sorteio de semente FIXA por inimigo (determinístico por tela).
##
## Campos de um golpe (todos opcionais menos id/kind):
##   id      nome do golpe (a sonda confere que cada um sai)
##   kind    swing · combo · rush · leap · slam · nova · shot · lob · pillar ·
##           grab · dive · glide · blink · summon · explode
##   rmin/rmax  faixa de distância horizontal até a Sophia em que o golpe serve
##   wind    telegrafo (s) — a pose/a cor/o brilho avisam
##   dmg     multiplicador do dano base do tipo
##   w       peso no sorteio · cd  recarga própria (s)
##   hits    combo: nº de golpes · reach  swing: alcance extra da caixa (×)
##   lunge   avanço (px/s) no golpe · count/spread/speed  tiro
##   status  "slow"/"root" no tiro · zone  lob: zona que fica no chão
##   unb     imparável (vermelho) — senão é aparável (amarelo)
##   air     só sai voando (voadores)
##
## Papéis (role): tank (vai na frente) · melee · skirm (flanqueia) ·
## shooter (fica atrás) · flyer (por cima). A IA de grupo usa o papel para a
## distância preferida e para a ordem na fila de agressão (EnemyAggro).


static func _m(id: String, kind: String, rmin: float, rmax: float, wind: float, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "kind": kind, "rmin": rmin, "rmax": rmax, "wind": wind,
		"dmg": 1.0, "w": 1.0, "cd": 0.0, "hits": 1, "reach": 1.0, "lunge": 0.0,
		"count": 1, "spread": 0.0, "speed": 300.0, "status": "", "zone": "", "unb": false, "air": false}
	d.merge(extra, true)
	return d


## Repertório + papel + reflexos (guarda/esquiva) de cada tipo.
## {} = tipo sem repertório próprio (chefes, ecos, Sombra da Sophia: o antigo).
static func for_type(id: String) -> Dictionary:
	match id:
		# --- Tier 1 -----------------------------------------------------------
		"larva":
			return _kit("melee", 0.0, 0.0, [
				_m("mordida", "swing", 0, 46, 0.5),
				_m("bote", "leap", 70, 150, 0.55, {"cd": 2.5, "dmg": 1.2}),
			])
		"sombra":
			return _kit("skirm", 0.0, 0.25, [
				_m("garras", "combo", 0, 50, 0.42, {"hits": 2, "dmg": 0.8}),
				_m("rasante", "rush", 80, 170, 0.5, {"cd": 2.2, "speed": 300.0}),
			])
		"servo":
			return _kit("melee", 0.15, 0.0, [
				_m("corte", "swing", 0, 50, 0.48),
				_m("tres_cortes", "combo", 0, 50, 0.5, {"hits": 3, "dmg": 0.75, "w": 1.3, "cd": 2.0}),
				_m("estocada", "swing", 55, 105, 0.6, {"lunge": 260.0, "reach": 1.3, "dmg": 1.2, "cd": 2.5}),
			])
		"larva_ardente":
			return _kit("melee", 0.0, 0.0, [
				_m("rolar", "rush", 80, 220, 0.45, {"speed": 260.0, "dmg": 0.5, "cd": 2.0, "w": 3.0}),
				_m("estouro", "explode", 0, 46, 0.7, {"unb": true}),
			])
		# --- Tier 2 -----------------------------------------------------------
		"espinho":
			return _kit("tank", 0.2, 0.0, [
				_m("pancada", "slam", 0, 64, 0.7),
				_m("espinhos", "slam", 0, 140, 0.8, {"waves": true, "dmg": 0.7, "cd": 3.0}),
				_m("ombrada", "rush", 70, 150, 0.6, {"speed": 280.0, "cd": 2.5}),
			])
		"canino":
			return _kit("skirm", 0.0, 0.3, [
				_m("investida", "rush", 90, 180, 0.6),
				_m("mordidas", "combo", 0, 48, 0.4, {"hits": 2, "dmg": 0.75}),
				_m("bote", "leap", 60, 160, 0.5, {"cd": 2.6, "dmg": 1.1}),
			])
		"cornudo":
			return _kit("melee", 0.2, 0.1, [
				_m("ceifa", "swing", 0, 64, 0.62, {"reach": 1.6, "dmg": 1.15}),
				_m("tres_cortes", "combo", 0, 52, 0.5, {"hits": 3, "dmg": 0.7, "cd": 2.2}),
				_m("agarrao", "grab", 0, 70, 0.58, {"cd": 4.0, "dmg": 0.6}),
			])
		"escudeiro":
			return _kit("tank", 0.45, 0.0, [
				_m("escudada", "swing", 0, 48, 0.5, {"dmg": 0.9}),
				_m("lanca", "swing", 50, 115, 0.62, {"lunge": 240.0, "reach": 1.5, "cd": 2.2}),
			])
		"espectro":
			return _kit("flyer", 0.0, 0.2, [
				_m("mergulho", "dive", 40, 210, 0.75, {"dmg": 1.2, "w": 1.4, "cd": 2.2, "air": true}),
				_m("rasante", "glide", 60, 230, 0.6, {"cd": 3.0, "w": 1.3, "air": true}),
				_m("uivo", "shot", 60, 300, 0.55, {"speed": 200.0, "dmg": 0.7, "cd": 2.5, "air": true}),
			], 70.0)
		# --- Tier 3 -----------------------------------------------------------
		"alado":
			return _kit("flyer", 0.0, 0.25, [
				_m("rajada", "shot", 40, 300, 0.6, {"count": 3, "spread": 0.26, "speed": 250.0, "dmg": 0.6, "w": 1.3, "air": true}),
				_m("lanca_de_luz", "pillar", 0, 320, 0.5, {"cd": 3.2, "dmg": 1.1, "air": true}),
				_m("rasante", "glide", 60, 220, 0.6, {"cd": 3.5, "air": true}),
			], 64.0)
		"bruto":
			return _kit("tank", 0.25, 0.0, [
				_m("terremoto", "slam", 0, 70, 0.75, {"waves": true}),
				_m("socos", "combo", 0, 54, 0.6, {"hits": 2, "dmg": 0.8}),
				_m("agarrao", "grab", 0, 70, 0.62, {"cd": 4.0, "dmg": 0.7}),
			])
		"arauto":
			return _kit("shooter", 0.0, 0.15, [
				_m("orbe", "shot", 90, 260, 0.5),
				_m("pilar", "pillar", 0, 280, 0.6, {"cd": 3.0, "count": 2, "dmg": 1.0}),
				_m("repulsa", "nova", 0, 60, 0.55, {"unb": true, "cd": 3.5, "dmg": 0.8}),
			])
		"fantasma":
			return _kit("skirm", 0.0, 0.2, [
				_m("garra", "swing", 0, 50, 0.45),
				_m("aparicao", "blink", 110, 320, 0.25, {"cd": 3.0}),
				_m("abraco", "grab", 0, 60, 0.55, {"cd": 4.0, "dmg": 0.6}),
			], 24.0)
		"invocador":
			return _kit("shooter", 0.0, 0.0, [
				_m("orbe", "shot", 90, 260, 0.55),
				_m("chamado", "summon", 0, 320, 0.6, {"cd": 6.0}),
				_m("semente", "lob", 60, 240, 0.6, {"zone": "poison", "cd": 3.5, "dmg": 0.6}),
			])
		# --- Tier 4 -----------------------------------------------------------
		"aberracao":
			return _kit("skirm", 0.1, 0.2, [
				_m("investida", "rush", 90, 190, 0.55),
				_m("garras", "combo", 0, 52, 0.45, {"hits": 3, "dmg": 0.7}),
				_m("queda", "leap", 70, 170, 0.6, {"slam": true, "cd": 3.0, "dmg": 1.2}),
			])
		# --- Bots dos Éons (a cara de cada ato) ------------------------------
		"sonambulo":
			return _kit("shooter", 0.0, 0.0, [
				_m("bocejo", "shot", 90, 260, 0.5, {"status": "slow", "speed": 220.0}),
				_m("nevoa", "lob", 70, 240, 0.6, {"zone": "sleep", "cd": 3.5, "dmg": 0.4}),
				_m("empurrao", "swing", 0, 64, 0.4, {"dmg": 0.8, "reach": 1.4}),
			])
		"glutao":
			return _kit("tank", 0.1, 0.0, [
				_m("mordida", "swing", 0, 54, 0.55),
				_m("engolir", "grab", 0, 66, 0.6, {"cd": 3.5, "dmg": 0.7}),
				_m("rolar", "rush", 80, 170, 0.6, {"speed": 290.0, "cd": 3.0}),
			])
		"carcereiro":
			return _kit("shooter", 0.2, 0.0, [
				_m("corrente", "shot", 90, 210, 0.55, {"status": "root", "speed": 260.0}),
				_m("chicote", "swing", 0, 90, 0.55, {"reach": 1.9, "dmg": 0.9}),
				_m("arrastar", "rush", 60, 150, 0.6, {"cd": 3.0, "speed": 260.0}),
			])
		"mudo":
			return _kit("melee", 0.15, 0.1, [
				_m("paginas", "shot", 80, 240, 0.5, {"count": 3, "spread": 0.22, "dmg": 0.55}),
				_m("golpes", "combo", 0, 50, 0.45, {"hits": 2, "dmg": 0.8}),
				_m("selo", "pillar", 0, 260, 0.55, {"cd": 3.2}),
			])
		"reflexo":
			return _kit("skirm", 0.0, 0.45, [
				_m("tres_cortes", "combo", 0, 52, 0.4, {"hits": 3, "dmg": 0.7}),
				_m("estocada", "swing", 55, 110, 0.5, {"lunge": 280.0, "reach": 1.3, "cd": 2.0}),
				_m("espelhar", "blink", 100, 300, 0.25, {"cd": 3.0}),
			])
		"esporos":
			return _kit("melee", 0.0, 0.1, [
				_m("investida", "rush", 80, 180, 0.6),
				_m("garras", "combo", 0, 50, 0.45, {"hits": 2, "dmg": 0.8}),
				_m("nuvem", "lob", 70, 230, 0.6, {"zone": "poison", "cd": 3.5, "dmg": 0.5}),
			])
		"pretoriano":
			return _kit("tank", 0.5, 0.0, [
				_m("lanca", "swing", 45, 115, 0.6, {"lunge": 240.0, "reach": 1.5}),
				_m("escudada", "swing", 0, 50, 0.5, {"dmg": 0.9}),
				_m("falange", "slam", 0, 80, 0.75, {"waves": true, "cd": 3.5}),
			])
	return {}


static func _kit(role: String, guard: float, evade: float, moves: Array, fly: float = 0.0) -> Dictionary:
	return {"role": role, "guard": guard, "evade": evade, "moves": moves, "fly": fly}


## Golpes extras do CAMPEÃO (o bot do Éon como mini-chefe): uma explosão em
## área imparável e uma onda dupla pelo chão — leitura de chefe, cara de bot.
static func champion_extras() -> Array:
	return [
		_m("brado", "nova", 0, 90, 0.7, {"unb": true, "cd": 5.0, "dmg": 1.1, "radius": 95.0}),
		_m("onda_dupla", "slam", 0, 200, 0.8, {"waves": true, "cd": 4.0, "dmg": 0.8}),
	]
