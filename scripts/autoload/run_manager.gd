extends Node
## Estrutura do "run" — o ARCO DOS ANÉIS em 54 telas:
##   1        = O Rei (chefe-tutorial; a Voz o apresenta como amigo)
##   2..50    = os 7 Éons (7 telas cada); o Arconte fecha o Éon em 8,15,22,29,36,43,50
##   50       = ao cair o 7º Arconte, o Rei rouba os 7 Anéis e a Voz se revela (cutscene)
##   51..53   = o Centro: ecos rápidos dos Arcontes devolvem os cacos de memória
##   54       = a Mente: batalha dupla (Rei + Colosso) — as duas formas caem juntas
## O HP do herói é carregado entre telas. Autoload acessível como `RunManager`.

signal screen_changed(screen: int)

const MAX_SCREEN := 54
const KING_SCREEN := 1
const EON_LEN := 7            # telas por Éon
const FIRST_EON_SCREEN := 2
const LAST_ARCHON_SCREEN := 50
const CENTER_FIRST := 51
const CENTER_LAST := 53

const EON_NAMES := ["Torpor", "Fome", "Corrente", "Silêncio", "Espelho", "Praga", "Coroa"]

var run_active: bool = false
var current_screen: int = 1
var carry_health: int = -1        # HP levado pra próxima tela (-1 = cheio)
var best_screen: int = 1
var pending_advance: bool = false # loja pós-chefe deve avançar ao fechar
var endings_seen: Array = []      # finais já alcançados ("ascensao"/"ruptura"/"semente")
var deaths_this_run: int = 0      # quedas (a Voz te recompõe — checkpoint)
var saved_run: Dictionary = {}    # run salvo em disco (menu "Continuar")


func begin() -> void:
	run_active = true
	current_screen = 1
	carry_health = -1
	pending_advance = false
	deaths_this_run = 0
	saved_run = {}                 # run novo substitui o "Continuar" antigo
	GameManager.current_screen = 1
	Narrative.reset()
	screen_changed.emit(current_screen)


func end_run() -> void:
	run_active = false


# --- checkpoints / continuar -------------------------------------------------

## Onde a morte te devolve: início do trecho atual. Limiar → 1 · Éon → primeira
## tela do Éon (2, 9, ..., 44) · Centro → 51 · Mente → 54.
func checkpoint_for(screen: int) -> int:
	if screen <= KING_SCREEN:
		return KING_SCREEN
	if screen >= MAX_SCREEN:
		return MAX_SCREEN
	if screen >= CENTER_FIRST:
		return CENTER_FIRST
	return FIRST_EON_SCREEN + eon_index(screen) * EON_LEN


## Morte com run ativo: volta pro checkpoint com a progressão intacta.
func respawn_at_checkpoint() -> void:
	current_screen = checkpoint_for(current_screen)
	GameManager.current_screen = current_screen
	carry_health = -1              # recomposta inteira
	pending_advance = false
	screen_changed.emit(current_screen)
	SceneManager.change_scene("res://scenes/levels/Level01.tscn")


## Foto do run pro save (a retomada é sempre do checkpoint, nunca do meio da tela).
func run_snapshot() -> Dictionary:
	if not run_active:
		return saved_run           # preserva o que estava no disco
	return {
		"screen": checkpoint_for(current_screen),
		"deaths": deaths_this_run,
		"difficulty": GameManager.difficulty,
		"orbs": Progression.orbs,
		"weapon_level": Progression.weapon_level,
		"skill_levels": Progression.skill_levels,
		"bonus_hp": Progression.bonus_max_health,
		"bonus_mp": Progression.bonus_max_mana,
		"items": Progression.items,
		"sleepers": Progression.sleepers_freed,
		"unlocked": Progression.unlocked_skills,
		"rings": Progression.rings,
		"rings_stolen": Progression.rings_stolen,
		"restored": Progression.restored_rings,
		"selected_ring": Progression.selected_ring,
		"seen": Narrative.seen.keys(),
	}


func has_saved_run() -> bool:
	return int(saved_run.get("screen", 0)) >= 1


## Menu "Continuar": restaura a progressão salva e retoma do checkpoint.
func continue_run() -> void:
	var d := saved_run
	GameManager.selected_character = GameContent.characters[0]
	GameManager.difficulty = clampi(int(d.get("difficulty", 0)), 0, 3) as GameManager.Difficulty
	Progression.reset_run()
	Progression.orbs = int(d.get("orbs", 0))
	Progression.weapon_level = clampi(int(d.get("weapon_level", 1)), 1, Progression.MAX_WEAPON_LEVEL)
	Progression.bonus_max_health = int(d.get("bonus_hp", 0))
	Progression.bonus_max_mana = int(d.get("bonus_mp", 0))
	Progression.sleepers_freed = int(d.get("sleepers", 0))
	Progression.rings_stolen = bool(d.get("rings_stolen", false))
	Progression.selected_ring = int(d.get("selected_ring", 0))
	Progression.items.assign(d.get("items", []))
	Progression.unlocked_skills.assign(d.get("unlocked", ["m_s1"]))
	Progression.rings.assign(d.get("rings", []))
	Progression.restored_rings.assign(d.get("restored", []))
	Progression.skill_levels.clear()
	var sl: Dictionary = d.get("skill_levels", {})
	for k in sl:
		Progression.skill_levels[String(k)] = int(sl[k])
	Narrative.reset()
	for s in d.get("seen", []):
		Narrative.seen[String(s)] = true
	run_active = true
	deaths_this_run = int(d.get("deaths", 0))
	current_screen = clampi(int(d.get("screen", 1)), 1, MAX_SCREEN)
	carry_health = -1
	pending_advance = false
	GameManager.current_screen = current_screen
	Progression.rings_changed.emit()
	Progression.orbs_changed.emit(Progression.orbs)
	Progression.weapon_level_changed.emit(Progression.weapon_level)
	Progression.stats_changed.emit()
	screen_changed.emit(current_screen)
	SceneManager.change_scene("res://scenes/levels/Level01.tscn")


## Vitória: o run acabou de verdade — o "Continuar" some.
func clear_saved_run() -> void:
	run_active = false
	saved_run = {}
	SaveManager.save_game()


# --- mapa do run ------------------------------------------------------------

func is_king_screen(screen: int) -> bool:
	return screen == KING_SCREEN


## Tela do Arconte de um Éon (8, 15, ..., 50).
func is_archon_screen(screen: int) -> bool:
	return screen >= FIRST_EON_SCREEN and screen <= LAST_ARCHON_SCREEN and (screen - 1) % EON_LEN == 0


func is_theft_screen(screen: int) -> bool:
	return screen == LAST_ARCHON_SCREEN


func is_center(screen: int) -> bool:
	return screen >= CENTER_FIRST and screen <= CENTER_LAST


func is_final(screen: int) -> bool:
	return screen >= MAX_SCREEN


## Qualquer tela com chefe (Rei, Arcontes, batalha final).
func is_boss_screen(screen: int) -> bool:
	return is_king_screen(screen) or is_archon_screen(screen) or is_final(screen)


## Índice do Éon: 0..6 nos Éons; a tela 1 usa 0 (prólogo); 7 = Centro; 8 = Mente.
func eon_index(screen: int) -> int:
	if screen >= MAX_SCREEN:
		return 8
	if screen >= CENTER_FIRST:
		return 7
	if screen < FIRST_EON_SCREEN:
		return 0
	return clampi((screen - FIRST_EON_SCREEN) / EON_LEN, 0, 6)


## Número do Arconte (1..7) de uma tela de Arconte; 0 se não for.
func archon_number(screen: int) -> int:
	if not is_archon_screen(screen):
		return 0
	return (screen - 1) / EON_LEN


func eon_name(screen: int) -> String:
	if screen >= MAX_SCREEN:
		return "A Mente"
	if is_center(screen):
		return "O Centro"
	if is_king_screen(screen):
		return "O Limiar"
	return EON_NAMES[eon_index(screen)]


## Primeira tela de um Éon (pra tocar a introdução narrada).
func is_eon_start(screen: int) -> bool:
	return screen >= FIRST_EON_SCREEN and screen <= LAST_ARCHON_SCREEN and (screen - FIRST_EON_SCREEN) % EON_LEN == 0


func boss_id_for(screen: int) -> String:
	if is_king_screen(screen):
		return "rei"
	if is_final(screen):
		return "demiurgo"
	var n := archon_number(screen)
	if n <= 0 or Bestiary.bosses.is_empty():
		return "servo"
	return Bestiary.bosses[clampi(n - 1, 0, Bestiary.bosses.size() - 1)].id


## Plano de waves da tela: array de waves; cada wave = array de type_ids.
func wave_plan(screen: int) -> Array:
	if is_final(screen):
		return []                       # a batalha final tem controlador próprio
	if is_boss_screen(screen):
		return [[boss_id_for(screen)]]
	if is_center(screen):
		# Ecos rápidos dos Arcontes (2 por tela) + larvas de interferência.
		var k := (screen - CENTER_FIRST) * 2
		var a: String = "eco_" + Bestiary.bosses[mini(k, Bestiary.bosses.size() - 1)].id
		var b: String = "eco_" + Bestiary.bosses[mini(k + 1, Bestiary.bosses.size() - 1)].id
		return [["larva", a, "larva"], ["larva_ardente", b, "larva"]]
	var ids: Array = Bestiary.types_for_screen(screen)
	if ids.is_empty():
		ids = ["servo"]
	var waves: Array = []
	# r2: teto de 4 waves (5 waves de 3 + elite virava pântano no fim do run).
	var wave_count := clampi(2 + int(screen / 14), 2, 4)
	for w in wave_count:
		var wave: Array = []
		for i in 3:
			wave.append(ids[(w * 3 + i + screen) % ids.size()])
		waves.append(wave)
	return waves


## Guarda o HP com uma cura leve entre telas (+15% do máximo).
func store_health(hp: int, max_hp: int) -> void:
	carry_health = mini(max_hp, hp + int(max_hp * 0.15))


func advance_and_reload() -> void:
	best_screen = maxi(best_screen, current_screen)
	current_screen += 1
	GameManager.current_screen = current_screen
	SaveManager.save_game()        # o "Continuar" acompanha o checkpoint
	screen_changed.emit(current_screen)
	SceneManager.change_scene("res://scenes/levels/Level01.tscn")
