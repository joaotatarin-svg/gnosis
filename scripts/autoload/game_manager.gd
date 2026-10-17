extends Node
## Estado global do jogo: personagem escolhido, dificuldade, fluxo e input.
## Autoload (singleton) acessível de qualquer lugar como `GameManager`.

signal state_changed(new_state: int)

enum State { BOOT, MENU, PLAYING, PAUSED, UPGRADE, GAME_OVER }
enum Difficulty { NORMAL, HARD, VERY_HARD, CHAMPION }

var state: State = State.BOOT
var difficulty: Difficulty = Difficulty.NORMAL
var selected_character: CharacterData = null
var current_screen: int = 1              # tela/fase atual (balanceamento)
var end_title: String = ""               # texto da tela de fim (game over/vitória)
var end_subtitle: String = ""

## OPÇÕES do jogador (salvas pelo SaveManager, aplicadas no boot por
## `apply_settings`). Quem consome cada uma:
##   fullscreen / vsync → aqui (DisplayServer)
##   shake (0.0–1.0)    → tremor de câmera (Juice/camera_shake leem daqui)
##   rumble (bool)      → vibração do controle (Juice.rumble lê daqui)
##   caption_size (0=P, 1=M, 2=G) → legendas/diálogos (DialogueBox lê daqui)
const SETTINGS_DEFAULT := {
	"fullscreen": false,
	"vsync": true,
	"shake": 1.0,
	"rumble": true,
	"caption_size": 1,
	# Acessibilidade: corta clarões/flashes de tela cheia (fotossensibilidade).
	# Quem desenha flash lê `Juice.reduce_flashes` (espelhado em apply_settings).
	"reduce_flashes": false,
}
var settings: Dictionary = SETTINGS_DEFAULT.duplicate()


func _ready() -> void:
	_load_patches()
	_load_gamepad_db()
	_register_inputs()
	apply_settings()
	set_state(State.MENU)


## Aplica as opções de vídeo (o resto é lido por quem usa). Seguro em headless.
func apply_settings() -> void:
	# Chave ausente ou com tipo errado (save editado, menu com bug) → padrão.
	for k in SETTINGS_DEFAULT:
		var v = SaveCoerce.match_type(settings.get(k), SETTINGS_DEFAULT[k]) if settings.has(k) else null
		settings[k] = SETTINGS_DEFAULT[k] if typeof(v) == TYPE_NIL else v
	settings["shake"] = clampf(float(settings["shake"]), 0.0, 1.0)
	settings["caption_size"] = clampi(int(settings["caption_size"]), 0, 2)
	# Espelha tremor/vibração no Juice (campos da branch principal), se ele já
	# existir — no boot o GameManager nasce antes do Juice; o SaveManager
	# chama de novo depois.
	var juice := get_node_or_null("/root/Juice")
	if juice != null:
		if "shake_mult" in juice:
			juice.set("shake_mult", shake_multiplier())
		if "rumble_enabled" in juice:
			juice.set("rumble_enabled", rumble_enabled())
		if "reduce_flashes" in juice:
			juice.set("reduce_flashes", reduce_flashes())
	if DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(settings["vsync"]) else DisplayServer.VSYNC_DISABLED)


## Multiplicador do tremor de câmera (0..1) — pra quem gera o tremor.
func shake_multiplier() -> float:
	return clampf(SaveCoerce.as_float(settings.get("shake", 1.0), 1.0), 0.0, 1.0)


## Vibração do controle ligada?
func rumble_enabled() -> bool:
	return SaveCoerce.as_bool(settings.get("rumble", true), true)


## Reduzir clarões (acessibilidade) ligado?
func reduce_flashes() -> bool:
	return SaveCoerce.as_bool(settings.get("reduce_flashes", false), false)


## Tamanho de fonte das legendas conforme a opção (P/M/G).
func caption_font_size() -> int:
	return [11, 13, 16][clampi(SaveCoerce.as_int(settings.get("caption_size", 1), 1), 0, 2)]


## Nome LEGÍVEL da tela pelo papel no arco (HUD, pausa, menu "Continuar"):
## "Limiar — O Rei" · "Torpor · Chegada" · "Torpor · Travessia II" ·
## "Torpor · O Desafio" · "Torpor · Antessala" · "Torpor · O Arconte" ·
## "O Centro I" · "A Mente".
func screen_title(screen: int) -> String:
	var role := RunManager.screen_role(screen)
	var eon := RunManager.eon_name(screen)
	match role:
		"king": return "Limiar — O Rei"
		"final": return "A Mente"
		"center": return "O Centro %s" % _roman(screen - RunManager.CENTER_FIRST + 1)
		"arrival": return "%s · Chegada" % eon
		"trial": return "%s · O Desafio" % eon
		"antechamber": return "%s · Antessala" % eon
		"archon": return "%s · O Arconte" % eon
	# Travessia: numera só as travessias (offsets 1,2,3 → I,II,III; 5,6 → IV,V).
	var off := RunManager.eon_offset(screen)
	var n := off if off <= 3 else off - 1
	return "%s · Travessia %s" % [eon, _roman(n)]


func _roman(n: int) -> String:
	var r := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"]
	return r[clampi(n - 1, 0, r.size() - 1)]


## Updates leves: carrega patch_<versão>_*.pck da pasta do executável por cima
## do jogo base (só no build exportado). Ordem alfabética = patch mais novo por
## último. REVISAO #7: só entra patch da MESMA `config/version` do projeto — um
## patch velho esquecido na pasta não reverte as correções da versão nova; o
## resto é ignorado com aviso. Limite conhecido: isto roda no _ready do 2º
## autoload, então um patch NÃO consegue trocar scripts de autoload (já
## carregados) — para isso, instalador/depot novo.
func _load_patches() -> void:
	if not OS.has_feature("standalone"):
		return
	var dir := DirAccess.open(OS.get_executable_path().get_base_dir())
	if dir == null:
		return
	var version := String(ProjectSettings.get_setting("application/config/version", ""))
	for p in patch_files_for(dir.get_files(), version):
		if not ProjectSettings.load_resource_pack(dir.get_current_dir().path_join(p)):
			push_warning("GameManager: patch %s não pôde ser montado." % p)


## Filtra (e ordena) os nomes de arquivo que são patch válido para a versão:
## `patch_<versão>_<algo>.pck`. Qualquer outro `patch_*.pck` é ignorado com print.
## Função pura (sem disco) para o CodexQA testar.
static func patch_files_for(files: PackedStringArray, version: String) -> Array[String]:
	var out: Array[String] = []
	var prefix := "patch_%s_" % version
	for f in files:
		if not (f.begins_with("patch_") and f.get_extension().to_lower() == "pck"):
			continue
		if version != "" and f.begins_with(prefix) and f.length() > prefix.length() + 4:
			out.append(f)
		else:
			print("GameManager: patch ignorado (não é da versão %s): %s" % [version, f])
	out.sort()
	return out


func set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(state)


## Multiplicador aplicado a HP/dano/recompensa dos inimigos.
func difficulty_multiplier() -> float:
	match difficulty:
		Difficulty.NORMAL: return 1.0
		Difficulty.HARD: return 1.5
		Difficulty.VERY_HARD: return 2.2
		Difficulty.CHAMPION: return 3.5
	return 1.0


func difficulty_name() -> String:
	match difficulty:
		Difficulty.NORMAL: return "Normal"
		Difficulty.HARD: return "Difícil"
		Difficulty.VERY_HARD: return "Muito Difícil"
		Difficulty.CHAMPION: return "Campeão"
	return "Normal"


## Registramos os inputs por código (mais confiável do que serializar no
## project.godot na mão). Editável aqui num lugar só.
#
# LAYOUT DE CONTROLE (Xbox · DualShock/DualSense · genéricos via SDL DB) —
# pensado pela ERGONOMIA de um beat-em-up 2D, não copiado do GoW 3D (lá os
# ataques vivem nos ombros porque o polegar direito segura a câmera; aqui não
# há câmera, então a ação mais repetida do jogo — atacar — fica no polegar):
#   POLEGAR DIREITO (ritmo): X/□ leve · Y/△ forte (vizinhos: combos L/H fluem
#     num rolar de polegar) · A/✕ pulo · B/○ esquiva (convenção do gênero).
#   INDICADOR ESQUERDO: L1 = bloqueio/parry (segurável SEM tirar o polegar dos
#     ataques — é a graça do parry) · L2 = trocar Anel (raro, fora do combate).
#   INDICADOR DIREITO: R1 = Anel equipado (magia frequente, clique rápido) ·
#     R2 = Esfera Solar (é um PROJÉTIL: gatilho = disparo, mapeamento mental).
#   Start = pausa · Back/Share = Anel anterior.
#   Movimento: analógico esq. (deadzone 0.25, resposta rápida) + D-pad.
# Teclado: A/D setas · Espaço · J/K · L/Shift · I · U/O · Q/E · 1–7 · Esc.
func _register_inputs() -> void:
	_add_action("move_left",    [KEY_A, KEY_LEFT],  [JOY_BUTTON_DPAD_LEFT],  [[JOY_AXIS_LEFT_X, -1.0]], 0.25)
	_add_action("move_right",   [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]], 0.25)
	_add_action("move_up",      [KEY_W, KEY_UP],    [JOY_BUTTON_DPAD_UP],    [[JOY_AXIS_LEFT_Y, -1.0]], 0.25)
	_add_action("move_down",    [KEY_S, KEY_DOWN],  [JOY_BUTTON_DPAD_DOWN],  [[JOY_AXIS_LEFT_Y, 1.0]], 0.25)
	_add_action("jump",         [KEY_SPACE],        [JOY_BUTTON_A])
	_add_action("attack_light", [KEY_J],            [JOY_BUTTON_X])
	_add_action("attack_heavy", [KEY_K],            [JOY_BUTTON_Y])
	_add_action("dodge",        [KEY_L, KEY_SHIFT], [JOY_BUTTON_B])
	_add_action("block",        [KEY_I],            [JOY_BUTTON_LEFT_SHOULDER])
	_add_action("skill1",       [KEY_U],            [JOY_BUTTON_RIGHT_SHOULDER])   # Anel equipado
	_add_action("skill2",       [KEY_O],            [],                      [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])   # Esfera Solar
	_add_action("ring_next",    [KEY_E],            [],                      [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_add_action("ring_prev",    [KEY_Q],            [JOY_BUTTON_BACK])
	var num_keys := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7]
	for i in 7:
		_add_action("ring_%d" % (i + 1), [num_keys[i]])
	_add_action("pause",        [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_register_ui_pad()


## Navegação de MENUS com controle (QA_UX B1): o Godot 4.7 só traz teclado em
## `ui_accept`/`ui_cancel` — sem isto, quem joga só de controle não confirma
## nem volta em nenhuma tela (softlock na 1ª tentação). A = confirmar, B =
## voltar (convenção Xbox/Steam Deck; no DualSense é ✕/○ pela posição). As
## teclas de fábrica ficam; só ACRESCENTAMOS os botões. As setas de UI já vêm
## com D-pad + analógico esquerdo no motor, mas garantimos aqui (idempotente)
## para não depender do padrão de uma versão futura.
## Conflito? Não: A/B também são pulo/esquiva, mas a UI só recebe `ui_*` quando
## um Control tem foco (menus, diálogos com o mundo pausado).
func _register_ui_pad() -> void:
	_ensure_pad("ui_accept", [JOY_BUTTON_A])
	_ensure_pad("ui_cancel", [JOY_BUTTON_B])
	_ensure_pad("ui_up",    [JOY_BUTTON_DPAD_UP],    [[JOY_AXIS_LEFT_Y, -1.0]])
	_ensure_pad("ui_down",  [JOY_BUTTON_DPAD_DOWN],  [[JOY_AXIS_LEFT_Y, 1.0]])
	_ensure_pad("ui_left",  [JOY_BUTTON_DPAD_LEFT],  [[JOY_AXIS_LEFT_X, -1.0]])
	_ensure_pad("ui_right", [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])


## Acrescenta botões/eixos de controle a uma ação SEM duplicar o que já existe
## (o motor compara botão/eixo e sentido) e sem tocar nas teclas.
func _ensure_pad(action: String, buttons: Array, motions: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for b in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)
	for m in motions:
		var ev := InputEventJoypadMotion.new()
		ev.axis = m[0]
		ev.axis_value = m[1]
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)


## Ação tem pelo menos um botão de controle? (QA: B1 não pode voltar.)
func action_has_pad_button(action: String, button: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == button:
			return true
	return false


## SDL_GameControllerDB (github.com/mdqinc/SDL_GameControllerDB, licença zlib):
## o melhor banco open source de mapeamentos de gamepad — o mesmo que a SDL e a
## Steam usam. O Godot já traz um DB embutido; este ATUALIZA e amplia (DualShock,
## DualSense, Xbox de todas as gerações e centenas de controles genéricos).
func _load_gamepad_db() -> void:
	var path := "res://assets/input/gamecontrollerdb.txt"
	if not FileAccess.file_exists(path):
		return
	var os_name := OS.get_name()
	var tag := "platform:" + ("Mac OS X" if os_name == "macOS" else os_name)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var n := 0
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#") or not tag in line:
			continue
		Input.add_joy_mapping(line, true)   # true = atualiza controles já ligados
		n += 1
	print("Gamepad DB: %d mapeamentos carregados (%s)" % [n, os_name])


func _add_action(action: String, keys: Array, buttons: Array = [], motions: Array = [], deadzone: float = 0.5) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)
	for m in motions:            # m = [eixo, valor]  (analógico e gatilhos)
		var ev := InputEventJoypadMotion.new()
		ev.axis = m[0]
		ev.axis_value = m[1]
		InputMap.action_add_event(action, ev)
