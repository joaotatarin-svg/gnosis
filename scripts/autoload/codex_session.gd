extends Node
## Sandbox de combate: snapshot em memória, nenhuma escrita no save da campanha.

var active: bool = false
var stage: int = 0
var boss_index: int = 0
var elapsed: float = 0.0
var best_combo: int = 0
var previous_persist: bool = true
var previous_save: Dictionary = {}
var previous_difficulty: int = 0

func start_demo(boss: int = 0) -> void:
	if not active:
		previous_persist = SaveManager.persist_enabled
		previous_save = RunManager.saved_run.duplicate(true)
		previous_difficulty = GameManager.difficulty
	active = true
	stage = 0
	boss_index = clampi(boss, 0, 6)
	elapsed = 0.0
	best_combo = 0
	SaveManager.persist_enabled = false
	GameManager.selected_character = GameContent.characters[0]
	GameManager.difficulty = GameManager.Difficulty.NORMAL
	Progression.reset_run()
	Progression.weapon_level = 3
	for sk in GameContent.ring_skills(GameContent.characters[0]):
		if sk.ring == Bestiary.bosses[boss_index].id:
			Progression.add_ring(sk.ring, sk.id)
			Progression.selected_ring = boss_index
	RunManager.begin()
	_load_stage()

func _load_stage() -> void:
	RunManager.current_screen = 2 + boss_index * 7
	GameManager.current_screen = RunManager.current_screen
	RunManager.carry_health = -1
	SceneManager.change_scene("res://scenes/levels/CodexTrial.tscn")

func next_stage() -> void:
	stage += 1
	_load_stage()

func leave_demo() -> void:
	if not active:
		return
	active = false
	RunManager.end_run()
	RunManager.saved_run = previous_save.duplicate(true)
	SaveManager.persist_enabled = previous_persist
	GameManager.difficulty = previous_difficulty
