class_name InputRebind
extends RefCounted
## REMAPEAMENTO de teclas e botões (backlog #34). Formato gravado em
## `GameManager.settings["bindings"]` (JSON do save):
##   { "attack_light": [ {"k": 74}, {"b": 2} ], "skill2": [ {"k": 79}, {"a": 5, "v": 1.0} ] }
##   k = tecla física (physical_keycode) · b = botão do controle (JoyButton)
##   a/v = eixo do controle e sentido (gatilhos) · m = botão do mouse
## Cada ação presente substitui TODOS os eventos dela; ação ausente = padrão de
## fábrica (o que o GameManager registrou no boot). Dicionário vazio = fábrica.
##
## O Técnico chama no load: `InputRebind.new().apply_bindings(dict)` (via
## `GameManager._apply_bindings`, se este arquivo existir). A tela "Controles"
## (`ControlsMenu`) usa `rebind()` / `reset()`.

## Ações remapeáveis, na ordem da tela: [id, nome, teclado?, controle?].
## Andar no controle fica no analógico + D-pad (fixo). A pausa (Esc/P/Start) e
## os atalhos 1–7 dos Anéis ficam fixos: são a saída de emergência.
const ACTIONS := [
	["attack_light", "Golpe leve", true, true],
	["attack_heavy", "Golpe forte", true, true],
	["jump", "Saltar", true, true],
	["dodge", "Esquiva", true, true],
	["block", "Aparar / bloquear", true, true],
	["skill1", "Anel (magia)", true, true],
	["skill2", "Esfera Solar", true, true],
	["ring_next", "Próximo Anel", true, true],
	["ring_prev", "Anel anterior", true, true],
	["move_left", "Andar para a esquerda", true, false],
	["move_right", "Andar para a direita", true, false],
	["move_up", "Andar para o fundo", true, false],
	["move_down", "Andar para a frente", true, false],
]
## Ações que NÃO se remapeiam: os eventos delas são reservados.
const FIXED := ["pause", "ring_1", "ring_2", "ring_3", "ring_4", "ring_5", "ring_6", "ring_7"]

## ação → eventos de fábrica JÁ SERIALIZADOS (dicionários: nada de Resource
## preso em variável estática até o fim do programa).
static var _factory: Dictionary = {}


## Chamado pelo GameManager (instância). Aplica o dicionário gravado.
func apply_bindings(bindings: Dictionary) -> void:
	InputRebind.apply(bindings)


## Guarda o layout de FÁBRICA (uma vez, antes de qualquer troca).
static func capture_factory() -> void:
	if not _factory.is_empty():
		return
	for a in ACTIONS:
		var id: String = a[0]
		if not InputMap.has_action(id):
			continue
		_factory[id] = serialize_action(id)


## Aplica `bindings` sobre o padrão de fábrica (ação ausente volta ao padrão).
static func apply(bindings: Dictionary) -> void:
	capture_factory()
	for a in ACTIONS:
		var id: String = a[0]
		if not InputMap.has_action(id):
			continue
		var evs: Array = []
		if bindings.has(id) and typeof(bindings[id]) == TYPE_ARRAY:
			for d in bindings[id]:
				var ev := deserialize(d)
				if ev != null:
					evs.append(ev)
		if evs.is_empty():
			for d in _factory.get(id, []):
				var fe := deserialize(d)
				if fe != null:
					evs.append(fe)
		InputMap.action_erase_events(id)
		for ev in evs:
			InputMap.action_add_event(id, ev.duplicate())


## Volta tudo ao padrão de fábrica. Devolve o dicionário vazio para gravar.
static func reset() -> Dictionary:
	apply({})
	return {}


# --- troca de uma tecla/botão ------------------------------------------------------

## Motivo para recusar `ev` como novo atalho ("" = aceito).
static func refusal(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var code := _key_code(ev as InputEventKey)
		if code == KEY_ESCAPE:
			return "Esc é reservado para pausar e voltar."
	elif ev is InputEventJoypadButton:
		if (ev as InputEventJoypadButton).button_index == JOY_BUTTON_START:
			return "%s é reservado para pausar." % InputGlyphs.pad_button_name(JOY_BUTTON_START, InputGlyphs.pad_kind())
	elif ev is InputEventJoypadMotion:
		var ax := (ev as InputEventJoypadMotion).axis
		if ax != JOY_AXIS_TRIGGER_LEFT and ax != JOY_AXIS_TRIGGER_RIGHT:
			return "O analógico fica para andar."
	else:
		return "Use uma tecla ou um botão do controle."
	for f in FIXED:
		if InputMap.has_action(f):
			for e in InputMap.action_get_events(f):
				if same(e, ev):
					return "%s é atalho fixo (%s)." % [InputGlyphs.event_label(ev), "pausa" if f == "pause" else "Anel " + f.substr(5)]
	return ""


## O evento que ocupa a "vaga" de `action` no teclado (pad=false) ou no
## controle (pad=true): a 1ª tecla, ou o 1º botão/gatilho.
static func slot_event(action: String, pad: bool) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for e in InputMap.action_get_events(action):
		if pad and _is_pad_slot(e):
			return e
		if not pad and e is InputEventKey:
			return e
	return null


## Troca a vaga de `action` (teclado ou controle, conforme `ev`) por `ev`.
## Se outra ação remapeável já usa `ev`, as duas TROCAM (a outra fica com o
## atalho antigo desta). Aplica no InputMap e devolve o novo dicionário
## (cópia de `bindings` com as ações mexidas). Recusado → `bindings` intacto.
static func rebind(bindings: Dictionary, action: String, ev: InputEvent) -> Dictionary:
	capture_factory()
	if refusal(ev) != "" or not InputMap.has_action(action):
		return bindings
	var pad := _is_pad_slot(ev)
	var clean := _clean(ev)
	var old := slot_event(action, pad)
	if old != null and same(old, clean):
		return bindings
	var out := bindings.duplicate(true)
	for a in ACTIONS:
		var other: String = a[0]
		if other == action or not InputMap.has_action(other):
			continue
		for e in InputMap.action_get_events(other):
			if same(e, clean):
				InputMap.action_erase_event(other, e)
				if old != null:
					InputMap.action_add_event(other, old.duplicate())
				out[other] = serialize_action(other)
				break
	if old != null:
		InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, clean)
	out[action] = serialize_action(action)
	return out


## Mesmo atalho? (tecla física · botão · eixo e sentido · mouse)
static func same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return _key_code(a) == _key_code(b)
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return (a as InputEventJoypadMotion).axis == (b as InputEventJoypadMotion).axis \
			and signf((a as InputEventJoypadMotion).axis_value) == signf((b as InputEventJoypadMotion).axis_value)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


static func _is_pad_slot(e: InputEvent) -> bool:
	if e is InputEventJoypadButton:
		return true
	if e is InputEventJoypadMotion:
		var ax := (e as InputEventJoypadMotion).axis
		return ax == JOY_AXIS_TRIGGER_LEFT or ax == JOY_AXIS_TRIGGER_RIGHT
	return false


static func _key_code(k: InputEventKey) -> Key:
	return k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode


## Cópia "limpa" do evento capturado (sem estado de pressionado/dispositivo).
static func _clean(ev: InputEvent) -> InputEvent:
	return deserialize(serialize(ev))


# --- JSON ---------------------------------------------------------------------------

static func serialize_action(action: String) -> Array:
	var out: Array = []
	for e in InputMap.action_get_events(action):
		var d := serialize(e)
		if not d.is_empty():
			out.append(d)
	return out


static func serialize(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"k": int(_key_code(ev as InputEventKey))}
	if ev is InputEventJoypadButton:
		return {"b": int((ev as InputEventJoypadButton).button_index)}
	if ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		return {"a": int(m.axis), "v": 1.0 if m.axis_value >= 0.0 else -1.0}
	if ev is InputEventMouseButton:
		return {"m": int((ev as InputEventMouseButton).button_index)}
	return {}


## Dicionário do save → evento (null se inválido: o save pode ter sido editado).
static func deserialize(d) -> InputEvent:
	if typeof(d) != TYPE_DICTIONARY:
		return null
	var dd: Dictionary = d
	if dd.has("k"):
		var code := int(dd["k"])
		if code <= 0:
			return null
		var k := InputEventKey.new()
		k.physical_keycode = code as Key
		return k
	if dd.has("b"):
		var b := int(dd["b"])
		if b < 0 or b >= JOY_BUTTON_MAX:
			return null
		var jb := InputEventJoypadButton.new()
		jb.button_index = b as JoyButton
		return jb
	if dd.has("a"):
		var ax := int(dd["a"])
		if ax < 0 or ax >= JOY_AXIS_MAX:
			return null
		var jm := InputEventJoypadMotion.new()
		jm.axis = ax as JoyAxis
		jm.axis_value = 1.0 if float(dd.get("v", 1.0)) >= 0.0 else -1.0
		return jm
	if dd.has("m"):
		var mb := InputEventMouseButton.new()
		mb.button_index = int(dd["m"]) as MouseButton
		return mb
	return null
