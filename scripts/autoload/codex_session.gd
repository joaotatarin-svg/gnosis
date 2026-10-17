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
		previous_persist = SaveManager.persist_run
		previous_save = RunManager.saved_run.duplicate(true)
		previous_difficulty = GameManager.difficulty
	active = true
	stage = 0
	boss_index = clampi(boss, 0, 6)
	elapsed = 0.0
	best_combo = 0
	# Só o run fica fora do disco; opções mudadas aqui gravam (REVISAO #13).
	SaveManager.persist_run = false
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

## Desbloqueio da Provação (backlog #26): só os Arcontes JÁ VENCIDOS na
## campanha (`Progression.bosses_beaten`). A UI lista só os liberados.
func is_unlocked(boss: int) -> bool:
	if boss < 0 or boss >= Bestiary.bosses.size():
		return false
	return Progression.is_boss_beaten(String(Bestiary.bosses[boss].id))


## Índices (0..6) dos Arcontes liberados para a Provação.
func unlocked_bosses() -> Array[int]:
	var out: Array[int] = []
	for i in Bestiary.bosses.size():
		if is_unlocked(i):
			out.append(i)
	return out


## Tela "de mentira" do encontro (REVISAO #8): a mesma fórmula do
## `codex_trial.gd` — 1ª tela do Éon do Arconte escolhido nos encontros 1–2 e a
## tela do Arconte (última do Éon) no 3º. Era `2 + boss*7` (mapa antigo de 7
## telas), e a música/cenário saíam do Éon errado.
static func screen_for(boss: int, stage_index: int) -> int:
	var s: int = RunManager.FIRST_EON_SCREEN + clampi(boss, 0, 6) * RunManager.EON_LEN
	if stage_index >= 2:
		s += RunManager.EON_LEN - 1
	return s


func _load_stage() -> void:
	RunManager.current_screen = screen_for(boss_index, stage)
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
	SaveManager.persist_run = previous_persist
	GameManager.difficulty = previous_difficulty
