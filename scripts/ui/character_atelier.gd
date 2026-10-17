extends Control
## Ateliê usa os MESMOS perfis e animador do jogo. Alterações são só prévia.

const POSES := ["idle", "walk", "attack", "attack_heavy", "cast", "block", "dodge", "windup", "hurt", "sequence"]
const POSE_NAMES := ["Repouso", "Caminhar", "Golpe leve", "Golpe forte", "Conjurar", "Aparar", "Esquiva", "Preparar golpe", "Receber impacto", "Ciclo de combate"]
const NOTES := [
	"A memória da luz tomou forma.\nSeis poses ilustradas, túnica bipartida\ne bracelete da Mônada.",
	"O guardião que ensina a dormir.\nPálpebra selada, corpo espectral\ne névoa que rouba movimento.",
	"A fome que nunca se reconhece.\nBoca no torso, massa colossal\ne sucção antes do impacto.",
	"Toda lei deseja uma corrente.\nElos pendentes, ombros de ferro\ne investida que aprisiona.",
	"Palavras enterradas no vazio.\nAsas rasgadas, boca costurada\ne uma aura que silencia os Anéis.",
	"O reflexo deseja o seu lugar.\nPrata, cacos em órbita\ne uma sombra na segunda fase.",
	"A vida que se esqueceu de morrer.\nQuatro patas, gavinhas\ne rastros de veneno.",
	"Um trono feito de obediência.\nCoroa alta, massa e hierarquia.\nServos sustentam sua armadura."
]
var selected: int = 0
var gear: int = 3
var palette: int = 0
var pose: int = 0
var clock: float = 0.0
var frozen: bool = false
var art: CharacterArt
var name_label: Label
var type_label: Label
var description: Label
var recipe: Label
var pose_label: Label
var gear_label: Label
var roster: Array[Button] = []
var gear_button: Button
var joints_button: Button
var show_joints: bool = false

func _ready() -> void:
	GameManager.set_state(GameManager.State.MENU)
	var bg = load("res://scripts/fx/codex_sanctum.gd").new()
	bg.menu = true
	bg.modulate = Color(0.8, 0.8, 0.8)
	add_child(bg)
	add_child(CodexStyle.Motes.new())
	CodexStyle.label(self, "Ateliê", Vector2(22, 9), 18, CodexStyle.GOLD_HI, 200, true)
	CodexStyle.label(self, "ILUSTRAÇÃO · POSES · PERFIL · COMBATE", Vector2(22, 35), 7, CodexStyle.MUTED, 300, true)
	CodexStyle.button(self, "Voltar", Vector2(543, 15), 75, func(): SceneManager.change_scene("res://scenes/ui/MainMenu.tscn"), false, "ui_back")
	CodexStyle.button(self, "Bestiário", Vector2(446, 15), 88, func(): SceneManager.change_scene("res://scenes/ui/Gallery.tscn"))
	for i in 8:
		var title: String = "Sophia" if i == 0 else String(Bestiary.bosses[i - 1].name).split(",")[0]
		var b := CodexStyle.button(self, "%02d  %s" % [i, title], Vector2(22, 65 + i * 31), 126, _select.bind(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		roster.append(b)
	art = CharacterArt.new()
	add_child(art)
	name_label = CodexStyle.label(self, "", Vector2(390, 76), 26, CodexStyle.PAPER, 230, true)
	type_label = CodexStyle.label(self, "", Vector2(391, 114), 8, CodexStyle.GOLD, 230, true)
	CodexStyle.rule(self, Vector2(391, 132), 200, Color(CodexStyle.GOLD, 0.6))
	description = CodexStyle.label(self, "", Vector2(391, 140), 10, CodexStyle.MUTED, 230)
	description.add_theme_font_override("font", CodexStyle.italic())
	CodexStyle.label(self, "RECEITA VISUAL", Vector2(391, 212), 7, CodexStyle.GOLD, 200, true)
	recipe = CodexStyle.label(self, "", Vector2(391, 225), 10, CodexStyle.MUTED, 218)
	recipe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	joints_button = CodexStyle.button(self, "Ver articulações", Vector2(391, 249), 220, func():
		show_joints = not show_joints
		joints_button.text = "Ocultar articulações" if show_joints else "Ver articulações"
		if art.boss_puppet != null:
			art.boss_puppet.debug_bones = show_joints
			art.boss_puppet.debug_layer.visible = show_joints
			art.boss_puppet.debug_layer.queue_redraw())
	CodexStyle.button(self, "Testar em combate →", Vector2(391, 280), 220, func(): CodexSession.start_demo(maxi(0, selected - 1)), true)
	CodexStyle.button(self, "‹", Vector2(169, 277), 28, func(): _set_pose(-1))
	pose_label = CodexStyle.label(self, "Repouso", Vector2(201, 281), 9, CodexStyle.PAPER, 136, true)
	pose_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CodexStyle.button(self, "›", Vector2(343, 277), 28, func(): _set_pose(1))
	CodexStyle.button(self, "Pausar / animar", Vector2(169, 313), 109, func():
		frozen = not frozen
		art.set_process(not frozen))
	CodexStyle.button(self, "Paleta", Vector2(286, 313), 85, func():
		palette = (palette + 1) % 3
		_refresh())
	gear_label = CodexStyle.label(self, "", Vector2(180, 53), 7, CodexStyle.GOLD, 185, true)
	gear_button = CodexStyle.button(self, "Arma +", Vector2(391, 313), 105, func():
		gear = gear % 5 + 1
		_refresh())
	CodexStyle.button(self, "Espelhar", Vector2(504, 313), 107, func(): art.scale.x *= -1)
	_select(0)
	roster[0].grab_focus()
	CodexStyle.stagger_in(roster, -10.0, 0.03, 0.05)
	if "--boss-motion" in OS.get_cmdline_user_args():
		_select(2)
		roster[2].grab_focus()
		pose = POSES.size()-2
		_set_pose(1)
	if "--show-joints" in OS.get_cmdline_user_args(): joints_button.pressed.emit()

func _select(index: int) -> void:
	selected = index
	palette = 0
	for i in roster.size():
		roster[i].modulate = Color.WHITE if i == selected else Color(0.68, 0.78, 0.78)
	_refresh()

func _refresh() -> void:
	var p: ArtProfile = Bestiary.player_profile(GameContent.characters[0], gear, []) if selected == 0 else Bestiary.bosses[selected - 1].profile.duplicate(true)
	if palette == 1:
		p.primary = Color("3c656c")
		p.secondary = Color("d7b97c")
		p.eye = Color("adf8e2")
	elif palette == 2:
		p.primary = Color("684c62")
		p.secondary = Color("d4a391")
		p.eye = Color("ffbf89")
	art.set_profile(p)
	if art.boss_puppet != null:
		art.boss_puppet.debug_bones = show_joints
		art.boss_puppet.debug_layer.visible = show_joints
		art.boss_puppet.debug_layer.queue_redraw()
	joints_button.disabled = selected == 0
	art.modulate = [Color.WHITE,Color("a7e0d8"),Color("e2b5c4")][palette]
	var sc: float = 116.0 / p.height
	art.scale = Vector2.ONE * sc
	art.position = Vector2(265, 246 - 24.0 * p.height / 44.0 * sc)
	name_label.text = "Sophia" if selected == 0 else String(Bestiary.bosses[selected - 1].name).split(",")[0]
	type_label.text = "A FAÍSCA  /  PROTAGONISTA" if selected == 0 else "ARCONTE  /  " + RunManager.EON_NAMES[selected - 1].to_upper()
	description.text = NOTES[selected]
	var names := {"staff": "cajado", "hair": "cabelo", "pauldrons": "ombreiras", "helmet": "diadema", "hero": "faísca", "bracers": "braceletes", "crown": "coroa", "aura": "aura", "eyelid": "pálpebra", "maw": "boca", "horns": "chifres", "spikes": "espinhos", "blade": "lâmina", "chains": "correntes", "wings": "asas", "sewn": "boca costurada", "mirror": "espelhos", "rot": "gavinhas", "claws": "garras", "tail": "cauda", "bigcrown": "grande coroa"}
	var parts := PackedStringArray()
	for feature in p.features:
		parts.append(names.get(feature, feature))
	recipe.text = "Conceito → ilustração → " + ("poses" if selected == 0 else "articulações")
	gear_label.text = ("ARMA %d / 5" % gear if selected == 0 else "ARCONTE") + "   ·   PALETA %d / 3" % (palette + 1)
	gear_button.disabled = selected != 0

func _set_pose(direction: int) -> void:
	pose = posmod(pose + direction, POSES.size())
	art.set_anim(POSES[pose])
	art.anim_time = 0.0
	pose_label.text = POSE_NAMES[pose]
	clock = 0.0

func _process(delta: float) -> void:
	if art == null or frozen:
		return
	clock += delta
	if POSES[pose] == "sequence":
		var t: float = fmod(clock,3.0)
		var state: String = "walk" if t < 1.2 else ("windup_heavy" if t < 1.9 else ("attack_heavy" if t < 2.15 else "recover"))
		art.set_anim(state)
		art.pose_progress = -1.0 if t < 1.2 else ((t-1.2)/0.7 if t < 1.9 else ((t-1.9)/0.25 if t < 2.15 else (t-2.15)/0.85))
		return
	art.pose_progress = -1.0
	if clock > 1.3 and pose > 1:
		clock = 0.0
		art.anim_time = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Audio.play_sfx("ui_back")
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")
