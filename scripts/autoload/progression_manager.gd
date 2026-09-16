extends Node
## O CORAÇÃO do loop estilo God of War: orbs (moeda), upgrade de arma
## (desbloqueia combos), níveis de magia, e bônus de HP/MP máximo.
## Autoload acessível como `Progression`.

signal orbs_changed(total: int)
signal weapon_level_changed(level: int)
signal skill_upgraded(skill_id: String, level: int)
signal stats_changed()

const MAX_WEAPON_LEVEL := 5

var orbs: int = 0
var weapon_level: int = 1
var skill_levels: Dictionary = {}      # skill_id -> int
var bonus_max_health: int = 0
var bonus_max_mana: int = 0
var items: Array[String] = []          # peças de gear adquiridas (aparência)
var sleepers_freed: int = 0            # Adormecidos despertados (final "Semente")
var unlocked_skills: Array[String] = [] # magias adquiridas ao longo do jogo
# --- Os 7 Anéis ---
signal rings_changed()
var rings: Array[String] = []          # ids dos Arcontes vencidos (Anéis reunidos)
var rings_stolen: bool = false         # o Rei roubou os Anéis (tela 50)
var restored_rings: Array[String] = [] # cacos de memória devolvidos no Centro
var selected_ring: int = 0             # índice (0..6) do Anel equipado


func unlock_skill(id: String) -> void:
	if not unlocked_skills.has(id):
		unlocked_skills.append(id)


func is_skill_unlocked(id: String) -> bool:
	return unlocked_skills.has(id)


## Ganha o Anel de um Arconte (e a magia dele).
func add_ring(boss_id: String, skill_id: String) -> void:
	if not rings.has(boss_id):
		rings.append(boss_id)
	unlock_skill(skill_id)
	rings_changed.emit()


## O roubo: todos os Anéis vão pro Rei. As magias de Anel somem.
func steal_rings() -> void:
	rings_stolen = true
	restored_rings.clear()
	rings_changed.emit()


## Um caco de memória devolve o PODER de um Anel (não o Anel).
func restore_ring(boss_id: String) -> void:
	if not restored_rings.has(boss_id):
		restored_rings.append(boss_id)
	rings_changed.emit()


## O Anel de `boss_id` está utilizável agora?
func ring_usable(boss_id: String) -> bool:
	if not rings.has(boss_id):
		return false
	if rings_stolen:
		return restored_rings.has(boss_id)
	return true


func next_stolen_ring() -> String:
	for r in rings:
		if not restored_rings.has(r):
			return r
	return ""


## Features de gear que o herói veste (usado pela arte procedural).
func item_features() -> Array:
	return items


## Zera a progressão para uma nova run (chamado ao entrar no menu / começar).
func reset_run() -> void:
	orbs = 0
	weapon_level = 1
	skill_levels.clear()
	bonus_max_health = 0
	bonus_max_mana = 0
	items.clear()
	sleepers_freed = 0
	unlocked_skills.clear()
	unlocked_skills.append("m_s1")   # a Esfera Solar é inata; os Anéis vêm dos Arcontes
	rings.clear()
	rings_stolen = false
	restored_rings.clear()
	selected_ring = 0
	rings_changed.emit()
	orbs_changed.emit(orbs)
	weapon_level_changed.emit(weapon_level)
	stats_changed.emit()


# --- Orbs ---------------------------------------------------------------

func add_orbs(amount: int) -> void:
	orbs += amount
	orbs_changed.emit(orbs)


func spend_orbs(amount: int) -> bool:
	if orbs < amount:
		return false
	orbs -= amount
	orbs_changed.emit(orbs)
	return true


# --- Arma (desbloqueia combos) -----------------------------------------

func weapon_upgrade_cost() -> int:
	return weapon_level * 50


func can_upgrade_weapon() -> bool:
	return weapon_level < MAX_WEAPON_LEVEL and orbs >= weapon_upgrade_cost()


func upgrade_weapon() -> bool:
	if not can_upgrade_weapon():
		return false
	if spend_orbs(weapon_upgrade_cost()):
		weapon_level += 1
		weapon_level_changed.emit(weapon_level)
		return true
	return false


## Combos liberados dependem do nível da arma (o gancho principal).
func unlocked_combos(character: CharacterData) -> Array:
	var result: Array = []
	if character == null:
		return result
	for combo in character.combos:
		if combo.required_weapon_level <= weapon_level:
			result.append(combo)
	return result


# --- Magias ------------------------------------------------------------

func skill_level(skill_id: String) -> int:
	return skill_levels.get(skill_id, 1)


func skill_upgrade_cost(skill_id: String) -> int:
	return skill_level(skill_id) * 40


func upgrade_skill(skill: SkillData) -> bool:
	var cur := skill_level(skill.id)
	if cur >= skill.max_level:
		return false
	if spend_orbs(skill_upgrade_cost(skill.id)):
		skill_levels[skill.id] = cur + 1
		skill_upgraded.emit(skill.id, cur + 1)
		return true
	return false


# --- HP / MP máximo (Gorgon Eyes / Phoenix Feathers) -------------------

func buy_max_health(amount: int, cost: int) -> bool:
	if spend_orbs(cost):
		bonus_max_health += amount
		stats_changed.emit()
		return true
	return false


func buy_max_mana(amount: int, cost: int) -> bool:
	if spend_orbs(cost):
		bonus_max_mana += amount
		stats_changed.emit()
		return true
	return false
