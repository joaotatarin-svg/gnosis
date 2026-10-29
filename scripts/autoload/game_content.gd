extends Node
## O roster do jogo (personagens, movesets de combo, magias) montado em código.
## Depois dá pra migrar isso pra arquivos .tres editáveis no editor do Godot.
## Autoload acessível como `GameContent`.

var characters: Array[CharacterData] = []
## RELÍQUIAS (Onda 6): uma em uso por vez — a troca é de graça em qualquer loja,
## então a escolha é de estilo (lutar perto, conjurar, ou juntar faísca), não
## só +número. Selo = Arcontes vencidos no run (Progression.progress_tier).
## Efeitos: brasa/lampada em spark_orb.gd (na CHEGADA de cada faísca);
## perola em Progression.add_orbs.
var relics: Array[Dictionary] = []


func _ready() -> void:
	_build_characters()
	_build_relics()


func _build_relics() -> void:
	relics = [
		{"id": "brasa", "name": "Brasa Viva", "cost": 350, "tier": 1, "color": Color(1.0, 0.55, 0.35),
			"desc": "Cada faísca que te alcança cura 2 de vida."},
		{"id": "lampada", "name": "Lâmpada de Óleo", "cost": 350, "tier": 2, "color": Color(0.55, 0.85, 1.0),
			"desc": "Cada faísca que te alcança devolve 3 de Éter."},
		{"id": "perola", "name": "Pérola do Hino", "cost": 500, "tier": 3, "color": Color(0.95, 0.92, 0.8),
			"desc": "Toda faísca ganha rende um quarto a mais."},
		# Onda 7: relíquia de fim de run — premia derrubar inimigos AGRUPADOS.
		{"id": "coro", "name": "Coro das Faíscas", "cost": 700, "tier": 5, "color": Color(1.0, 0.85, 0.55),
			"desc": "Quando todas as faíscas de um inimigo te alcançam, a luz fere quem está perto."},
	]


func get_character(id: String) -> CharacterData:
	for c in characters:
		if c.id == id:
			return c
	return characters[0] if characters.size() > 0 else null


func _move(id: String, name: String, seq: Array[String], dmg: int, req: int,
		duration: float, knockback: float, launcher: bool = false, air: bool = false,
		hits: int = 1, aoe: float = 0.0) -> ComboData:
	var c := ComboData.new()
	c.id = id
	c.display_name = name
	c.sequence = seq
	c.damage = dmg
	c.required_weapon_level = req
	c.duration = duration
	c.knockback = knockback
	c.launcher = launcher
	c.air = air
	c.hits = hits
	c.aoe_radius = aoe
	return c


func _skill(id: String, name: String, type: SkillData.SkillType, mana: int, dmg: int, desc: String,
		ring: String = "", cooldown: float = 6.0, color: Color = Color(1.0, 0.95, 0.7)) -> SkillData:
	var s := SkillData.new()
	s.id = id
	s.display_name = name
	s.type = type
	s.mana_cost = mana
	s.base_damage = dmg
	s.description = desc
	s.ring = ring
	s.cooldown = cooldown
	s.color = color
	return s


func _build_characters() -> void:
	# --- Sophia (PROTAGONISTA ÚNICA): o caco do aeon, canaliza a luz da Mônada.
	var sophia := CharacterData.new()
	sophia.id = "sophia"
	sophia.display_name = "Sophia"
	sophia.description = "Uma faísca sem memória, desperta nas cinzas do Kenoma. Luta com o cajado e com a luz que ainda lembra."
	sophia.max_health = 120   # balance 2026-09-11 (bot): 90 morria demais sem cura
	sophia.max_mana = 100
	sophia.move_speed = 185.0
	sophia.jump_velocity = -430.0
	sophia.sprite_color = Color(0.6, 0.5, 0.85)
	# TABELA DE GOLPES por nível de arma (a progressão de verdade — cada nível
	# abre strings novas; ver Progression.unlocked_combos).
	sophia.combos = [
		# --- Nv.1: o básico. Leve 3x, forte 1x.
		_move("m_L",    "Golpe de Cajado",     ["light"],                            12, 1, 0.30, 120.0),
		_move("m_LL",   "Cajado Duplo",        ["light", "light"],                   12, 1, 0.30, 140.0),
		_move("m_LLL",  "Sopro Arcano",        ["light", "light", "light"],          20, 1, 0.36, 220.0),
		_move("m_H",    "Impacto Arcano",      ["heavy"],                            24, 1, 0.48, 240.0),
		# --- Nv.2: forte encadeia; LANÇADOR (L-L-H joga o inimigo pro alto).
		_move("m_HH",   "Fenda Arcana",        ["heavy", "heavy"],                   26, 2, 0.48, 270.0),
		_move("m_LLH",  "Ascensão Arcana",     ["light", "light", "heavy"],          22, 2, 0.40, 120.0, true),
		# --- Nv.3: finalizador forte, lançador rápido e os golpes AÉREOS.
		_move("m_HHH",  "Explosão Arcana",     ["heavy", "heavy", "heavy"],          44, 3, 0.56, 360.0),
		_move("m_LH",   "Corte Ascendente",    ["light", "heavy"],                   18, 3, 0.34, 100.0, true),
		_move("a_L",    "Giro Celeste",        ["light"],                            13, 3, 0.36, 90.0, false, true, 2),
		_move("a_H",    "Queda Estelar",       ["heavy"],                            30, 3, 0.60, 260.0, false, true, 1, 95.0),
		# --- Nv.4: multi-hit.
		_move("m_LLLL", "Tempestade de Cajado", ["light", "light", "light", "light"], 9, 4, 0.54, 90.0, false, false, 4),
		_move("m_HL",   "Rasgo Duplo",         ["heavy", "light"],                   19, 4, 0.40, 180.0, false, false, 2),
		# --- Nv.5: os finalizadores da Mônada (área).
		_move("m_LLLH", "Fúria da Mônada",     ["light", "light", "light", "heavy"], 40, 5, 0.58, 330.0, false, false, 1, 120.0),
		_move("m_HHL",  "Colapso Arcano",      ["heavy", "heavy", "light"],          30, 5, 0.44, 150.0, true, false, 1, 80.0),
	]
	# MAGIAS: a Esfera Solar é inata (slot O / Y). Os 7 ANÉIS (slot U / X, o Anel
	# selecionado com 1–7, Q/E ou L2) chegam um por Arconte vencido — cada um é a
	# paixão do Arconte virada contra o Kenoma.
	sophia.skills = [
		_skill("m_s1", "Esfera Solar", SkillData.SkillType.PROJECTILE, 20, 26, "Explode ao acertar.", "", 6.0, Color(1.0, 0.85, 0.5)),
		_skill("r_torpor", "Névoa do Sono", SkillData.SkillType.AOE, 22, 12, "Nuvem que adormece: inimigos dentro ficam lentos.", "arconte_sono", 9.0, Color(0.72, 0.78, 1.0)),
		_skill("r_fome", "Boca Voraz", SkillData.SkillType.AOE, 24, 22, "Suga os inimigos para perto e morde.", "arconte_fome", 9.0, Color(1.0, 0.55, 0.3)),
		_skill("r_corrente", "Corrente da Lei", SkillData.SkillType.PROJECTILE, 18, 18, "Corrente que prende o alvo no lugar.", "arconte_corrente", 7.0, Color(0.85, 0.85, 0.95)),
		_skill("r_silencio", "Grito Mudo", SkillData.SkillType.AOE, 20, 10, "Cala todo golpe em preparo ao redor (atordoa).", "arconte_silencio", 10.0, Color(0.7, 0.8, 1.0)),
		_skill("r_espelho", "Reflexo", SkillData.SkillType.BUFF, 26, 0, "Por 5 s, todo golpe recebido volta para quem o deu.", "arconte_espelho", 14.0, Color(0.9, 0.95, 1.0)),
		_skill("r_praga", "Flor Podre", SkillData.SkillType.AOE, 22, 6, "Planta um canteiro de veneno que fere quem pisa.", "arconte_praga", 9.0, Color(0.75, 1.0, 0.55)),
		_skill("r_coroa", "Coroa Partida", SkillData.SkillType.AOE, 40, 48, "A coroa do Arconte se parte em luz: dano enorme em área.", "arconte_coroa", 16.0, Color(1.0, 0.9, 0.5)),
	]
	characters.append(sophia)


## As magias de Anel (na ordem dos Arcontes) de um personagem.
func ring_skills(character: CharacterData) -> Array:
	var out: Array = []
	for s in character.skills:
		if s.ring != "":
			out.append(s)
	return out


func innate_skill(character: CharacterData) -> SkillData:
	for s in character.skills:
		if s.ring == "":
			return s
	return null
