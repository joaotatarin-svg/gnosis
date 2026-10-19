extends CanvasLayer
## HUD do GNOSIS — tudo desenhado por código (sem texturas de interface):
##   · medalhão da Sophia (retrato pintado num anel de ouro; pulsa em brasa com vida baixa)
##   · barras de Vida e Éter com moldura e BARRA FANTASMA (o dano some devagar)
##   · faíscas com ícone (contagem sobe animada) e nível da arma (cajado + 5 losangos)
##   · os 7 ANÉIS como gemas na cor de cada Arconte: vazio (encaixe apagado),
##     equipado (gema acesa + halo), roubado (encaixe rachado, cinza)
##   · progresso do Éon (canto direito): 9 marcos ligados por um fio
##   · respiro (R21): faíscas/arma recuam a α 0,6 fora de combate; vinheta de
##     vida baixa (R22) abaixo de 25 %, no máximo 8 s por dano
##   · barra do CHEFE na base: nome em versalete, marcador de fase em 50 %,
##     medalhão I/II à esquerda; até DUAS barras lado a lado (batalha final:
##     Rei e Colosso, cada uma com a vida e a FASE do seu chefe; quem cai e vai
##     se refazer mostra "refazendo-se" com a barra cinza enchendo)
## Fala com o jogo pelo grupo "hud": show_boss(e), boss_phase(n[, chefe]),
## toast(msg), boss_area_top() (a legenda usa para ficar acima da barra),
## boss_bars() -> [{node, ratio, phase, down, name}] (contrato de QA).
## API da encenação (Onda 2): ring_dot_global_pos(i), ring_dot_world_pos(i),
## detach_ring(i, alvo) — a gema salta do encaixe e voa (sinal ring_detach_finished);
## restore_ring(i, origem) — o inverso: a gema volta voando e o encaixe reacende
## (sinal ring_restore_finished).
## Combate: spark_orb_arrived() — cada orbe que CHEGA sobe o contador em 1 (pop
## 1,0→1,15→1,0 em 120 ms); sem chamadas, o contador corre sozinho como antes.
## Dicas de controle (QA-UX A7): telas 1–3 e 1ª vez de cada mecânica, no topo
## central, com as teclas do dispositivo em uso (último InputEvent); somem sozinhas
## e nunca pausam. show_hint(segmentos) para outros usarem.
## Glifos (Onda 2b, #33): com o `InputGlyphs` do ui-menus presente, as teclas das
## dicas viram ÍCONES do dispositivo em uso (tecla, Xbox, PlayStation, Switch,
## Deck); sem ele, o rótulo de texto antigo (teclado/controle genérico).

signal ring_detach_finished(index: int)
signal ring_restore_finished(index: int)

const PORTRAIT := "res://assets/ui/portraits/sophia.png"

# Geometria (base 640×360)
const MEDAL_C := Vector2(30, 31)
const MEDAL_R := 21.0
const HP_RECT := Rect2(56, 14, 150, 8)
const MP_RECT := Rect2(56, 26, 118, 5)
const RING_Y := 62.0
const RING_X0 := 14.0
const RING_DX := 15.0
const BOSS_W := 320.0
const BOSS_BAR_Y := 334.0        # topo da barra do chefe
const EON_RIGHT := 626.0
## Toast numa faixa SÓ DELE (QA-UX M2): abaixo da fileira de Anéis (y 62) e do
## nome do Anel, à esquerda do contador de golpes (x ≥ 520), acima das cabeças.
const TOAST_RECT := Rect2(120, 88, 400, 30)
const HINT_Y := 46.0              # centro vertical da faixa de dicas (topo central)
const HINT_TIME := 4.2            # s visível (tempo de jogo, para na pausa)
const HINT_NOW_TIME := 6.0        # s das dicas de ensino (show_hint_now)
## "Siga em frente" (zona limpa) não é aviso de centro de tela: vira uma SETA na
## borda direita, no sentido do caminho — o centro já tem legenda, dica e o
## convite da Estela empilhados (QA7 #30).
const GO_TOAST := "Siga em frente  →"
const GO_TIME := 3.2              # s de jogo com a seta na borda
const TOAST_GAP := 0.35           # s entre um toast e o próximo (e depois de uma cena)
const SPARK_POP := 0.12           # s do pop do contador (1,0→1,15→1,0)
## R21 (respiro): faíscas e arma recuam para α 0,6 após 4 s sem combate e
## voltam a 1,0 em 150 ms. Vida e Éter ficam sempre inteiras.
const CALM_AFTER := 4.0
const CALM_ALPHA := 0.6
const COMBAT_RANGE := 380.0
## R22 (vida baixa): abaixo de 25 % uma vinheta vermelho-escura (α 0,12–0,18)
## pulsa a ~0,9 Hz por no máximo 8 s; só volta se ela tomar dano de novo.
const LOW_HP := 0.25
const LOW_HP_MAX_TIME := 8.0
## O Combate já chama spark_orb_arrived()? (vale para o resto da sessão)
static var orb_mode: bool = false
## Ações que a jogadora já usou nesta sessão (dicas aprendidas não voltam — QA2 #10).
static var _used_actions: Dictionary = {}
const HINT_ACTIONS := ["jump", "attack_light", "attack_heavy", "dodge", "block", "skill1", "skill2", "ring_prev", "ring_next", "pause"]
const HINT_ICON_H := 13.0         # altura do ícone de tecla/botão nas dicas

var _canvas: _HudCanvas
var _counters: _HudCanvas            # faíscas + arma numa camada própria (recuam fora de combate)
var _combo_label: Label
var _toast: Control
var _toast_holder: Control           # desloca o toast para baixo da legenda (CaptionBar no topo)
var _caption_bottom: float = -1.0    # base da faixa de legenda (-1 = sem legenda)
var _toast_label: Label
var _toast_tween: Tween
var _recede: float = 0.0             # 0..1: HUD recolhido (card de chefe da Cinemática)
var _go_t: float = 0.0               # s restantes da seta "Siga em frente" (0 = fora)
var _scene_k: float = 0.0            # 0..1: cena/diálogo no ar (some o HUD de combate não essencial)

# estado das barras
var hp: float = 1.0
var hp_max: float = 1.0
var hp_ghost: float = 1.0          # fração exibida pela fantasma
var hp_shown: float = 1.0          # fração exibida pela barra viva (suaviza curas)
var _hp_hold: float = 0.0          # segura a fantasma antes de drenar
var _hp_flash: float = 0.0
var mp: float = 1.0
var mp_max: float = 1.0
var mp_shown: float = 1.0

# faíscas e arma
var sparks: int = 0
var sparks_shown: float = 0.0
var _spark_pulse: float = 0.0
var _spark_pop: float = 0.0          # s restantes do pop (spark_orb_arrived)
var _spark_hold: float = 0.0         # segura a contagem automática esperando os orbes
var weapon: int = 1
var _weapon_flash: float = 0.0

# anéis
var ring_skills: Array = []         # SkillData na ordem dos Arcontes
var _ring_pop: Array[float] = []    # animação de ganho por anel
var _detached: Dictionary = {}      # índice -> true enquanto a gema está fora
var _incoming: Dictionary = {}      # índice -> true enquanto a gema VOLTA (restore_ring)

# dicas de controle
var hints: Array = []               # fila de dicas: cada uma = Array de segmentos
var _hint: Array = []               # dica atual
var _hint_t: float = 0.0            # tempo da dica atual
var _hint_gap: float = 1.2          # respiro antes da próxima
var _hint_done: Dictionary = {}     # ações da dica atual já usadas
var _hint_dur: float = HINT_TIME    # duração da dica atual (as "agora" ficam mais)
var _hint_forced: bool = false      # dica atual veio de show_hint_now (ensino: não encurta)
var use_pad: bool = false           # último InputEvent veio do controle?

# chefes (até 2 barras; ver _BossBar)
var bosses: Array = []               # [_BossBar] na ordem em que nasceram
var boss: Node = null                # o 1º chefe vivo (compatibilidade)

var _t: float = 0.0
var _portrait: Texture2D
var _calm: float = 0.0               # s sem combate
var _calm_a: float = 1.0             # alpha atual das faíscas/arma
var _combat_check: float = 0.0
var _low_t: float = -1.0             # s de vinheta de vida baixa (-1 = desligada)
var _low_fade: float = 0.0           # 0..1 intensidade (entra/sai suave)
var _low_beat: int = -1              # último pulso da vinheta que já bateu o coração (Audio)
var _toast_queue: Array[String] = [] # avisos esperando a vez (conquista + Crônica juntas)
var _toast_wait: float = 0.0         # respiro antes do próximo toast (fila / fim de cena)
var _toast_ms: int = 0               # relógio real do último quadro (o respiro ignora câmera lenta)
## Aviso "Selo aberto" esperando a vez: sobrevive à troca de tela (o Arconte cai
## no fim da tela dele e o aviso sai na próxima, se não deu tempo nesta).
static var _seal_pending: String = ""
var _tier_seen: int = -1             # grau (Arcontes vencidos) já anunciado
var _relic_pulse: float = 0.0        # 0..1 a relíquia agiu (faísca curou / deu Éter / trocou)
var _obj_kind: String = ""           # objetivo da zona no ar ("totem", "proteger", "mare")
var _obj_k: float = 0.0              # 0..1 entrada/saída do ícone do objetivo


func _ready() -> void:
	add_to_group("hud")
	# Roda com a árvore pausada SÓ para recolher durante o card de chefe (M4);
	# o estado do jogo (barras, faíscas) continua congelado na pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_portrait = load(PORTRAIT) if ResourceLoader.exists(PORTRAIT) else null
	_canvas = _HudCanvas.new()
	_canvas.hud = self
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_counters = _HudCanvas.new()
	_counters.hud = self
	_counters.only_counters = true
	_counters.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_counters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_counters)
	_build_combo()

	var ch: CharacterData = GameManager.selected_character
	if ch == null and GameContent.characters.size() > 0:
		ch = GameContent.characters[0]
	ring_skills = GameContent.ring_skills(ch) if ch != null else []
	for i in ring_skills.size():
		_ring_pop.append(0.0)
	Progression.rings_changed.connect(_on_rings_changed)

	var player := get_tree().get_first_node_in_group("player")
	if player:
		if player.health:
			player.health.health_changed.connect(_on_hp)
			_on_hp(player.health.current_health, player.health.max_health)
			hp_ghost = hp_shown
		player.mana_changed.connect(_on_mp)
		_on_mp(int(player.mana), player.max_mana_total)
		mp_shown = mp / maxf(1.0, mp_max)
		player.combo_changed.connect(_on_combo)
	Progression.orbs_changed.connect(_on_sparks)
	Progression.weapon_level_changed.connect(_on_weapon)
	sparks = Progression.orbs
	sparks_shown = float(sparks)
	weapon = Progression.weapon_level
	RunManager.screen_changed.connect(func(_s): _canvas.queue_redraw())
	var g = DialogueBox.glyphs()
	use_pad = bool(g.is_pad()) if g != null else Input.get_connected_joypads().size() > 0
	_queue_screen_hints()
	_check_ring_hints()
	# Selos da loja (progressao6): o grau atual já é conhecido; só anuncia subida.
	_tier_seen = _progress_tier()
	if _seal_pending != "":
		toast(_seal_pending)
	if Progression.has_signal("relics_changed"):
		Progression.connect("relics_changed", _on_relics_changed)
	# Conquista liberada → toast (Achievements é autoload leve; compila sem ele).
	var ach := get_node_or_null("/root/Achievements")
	if ach != null and ach.has_signal("unlocked"):
		ach.connect("unlocked", _on_achievement)


func _process(delta: float) -> void:
	_update_recede(delta)
	_process_toasts()
	if get_tree().paused:
		# Estado congelado, mas o desenho segue (no roubo a caixa pausa o mundo e
		# o encaixe da gema precisa apagar/acender na hora).
		# Faíscas: atrás da loja/pausa o número mostra o total REAL (QA H2: ficava
		# o valor velho congelado enquanto a loja mostrava o novo).
		if sparks_shown != float(sparks):
			sparks_shown = float(sparks)
			_spark_hold = 0.0
		_canvas.queue_redraw()
		_counters.queue_redraw()
		return
	_t += delta
	if _go_t > 0.0 and _scene_k < 0.5:
		_go_t = maxf(0.0, _go_t - delta)
	# Vida: a barra viva sobe suave (cura) e desce na hora (dano); a fantasma
	# segura 0,45 s e drena.
	var hp_target := hp / maxf(1.0, hp_max)
	if hp_target < hp_shown:
		hp_shown = hp_target
	else:
		hp_shown = move_toward(hp_shown, hp_target, delta * 0.9)
	if _hp_hold > 0.0:
		_hp_hold -= delta
	elif hp_ghost > hp_shown:
		hp_ghost = move_toward(hp_ghost, hp_shown, delta * (0.25 + (hp_ghost - hp_shown) * 1.6))
	if hp_ghost < hp_shown:
		hp_ghost = hp_shown
	_hp_flash = maxf(0.0, _hp_flash - delta * 6.0)
	mp_shown = move_toward(mp_shown, mp / maxf(1.0, mp_max), delta * 1.6)
	# Faíscas: o número corre até o total (gasto desce na hora). Com os orbes
	# do Combate (spark_orb_arrived), a subida espera as chegadas e só corre o
	# resto quando elas param.
	if float(sparks) < sparks_shown:
		sparks_shown = float(sparks)
	elif _spark_hold > 0.0:
		_spark_hold -= delta
	elif sparks_shown != float(sparks):
		var step := maxf(1.0, absf(float(sparks) - sparks_shown) * delta * 6.0)
		sparks_shown = move_toward(sparks_shown, float(sparks), step)
	_spark_pulse = maxf(0.0, _spark_pulse - delta * 2.5)
	_spark_pop = maxf(0.0, _spark_pop - delta)
	if _scene_k <= 0.0:
		_process_hints(delta)      # durante cena a dica espera (não "queima" escondida)
	_weapon_flash = maxf(0.0, _weapon_flash - delta * 0.6)
	for i in _ring_pop.size():
		_ring_pop[i] = maxf(0.0, _ring_pop[i] - delta * 1.8)
	_process_bosses(delta)
	_process_objective(delta)
	_relic_pulse = maxf(0.0, _relic_pulse - delta * 1.8)
	_process_calm(delta)
	_process_low_hp(delta)
	_canvas.queue_redraw()
	_counters.queue_redraw()


# --- sinais do jogo ------------------------------------------------------------

func _on_hp(current: int, maximum: int) -> void:
	var before := hp
	hp = float(current)
	hp_max = float(maxi(1, maximum))
	if hp < before:
		_hp_hold = 0.45
		_hp_flash = 1.0
		_calm = 0.0
		# R22: dano abaixo de 25 % (re)acende a vinheta por até 8 s.
		if hp > 0.0 and hp / hp_max < LOW_HP:
			_low_t = 0.0


func _on_mp(current: int, maximum: int) -> void:
	mp = float(current)
	mp_max = float(maxi(1, maximum))


func _on_sparks(total: int) -> void:
	if total > sparks:
		_spark_pulse = 1.0
		if orb_mode:
			_spark_hold = 1.2      # os orbes ainda estão voando
	sparks = total


func _on_weapon(level: int) -> void:
	if level > weapon:
		_weapon_flash = 1.6        # acende os losangos e mostra "Arma Nv. N"
		# 1ª vez de cada mecânica que a arma destrava (ver GameContent combos)
		if RunManager.run_active and not CodexSession.active:
			if level >= 2 and Narrative.once("dica_arma_2"):
				show_hint([{"keys": ["attack_light", "attack_light", "attack_heavy"], "text": "lança o inimigo para o alto"}])
			if level >= 3 and Narrative.once("dica_arma_3"):
				show_hint([{"keys": ["jump", "attack_light"], "text": "golpe no ar"}, {"keys": ["jump", "attack_heavy"], "text": "queda"}])
	weapon = level


func _on_rings_changed() -> void:
	for i in ring_skills.size():
		var sk: SkillData = ring_skills[i]
		if Progression.ring_usable(sk.ring) and not bool(_canvas.last_usable.get(i, false)) and not _incoming.has(i):
			_ring_pop[i] = 1.0
	_detached.clear()
	_check_ring_hints()
	_check_seal()


func _on_relics_changed() -> void:
	_relic_pulse = 1.0
	_calm = 0.0


func _on_combo(count: int) -> void:
	_calm = 0.0
	if count < 2:
		_combo_label.text = ""
		return
	_combo_label.text = str(count)
	_combo_label.scale = Vector2(1.25, 1.25)
	var t := create_tween()
	t.tween_property(_combo_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- API pública ------------------------------------------------------------------

## Aviso curto (cacos de memória, Crônicas, conquistas, quedas na batalha final)
## numa faixa própria (TOAST_RECT). Texto longo encolhe a fonte para caber.
## Dois avisos juntos (Crônica + conquista) fazem fila: um de cada vez.
func toast(msg: String) -> void:
	if msg == "":
		return
	if msg == GO_TOAST:
		go_cue()
		return
	# Toast no ar, ou cena/card/pausa na tela (QA2 #4/#5): entra na FILA e só
	# aparece quando o jogo voltar (ver _process_toasts) — nunca por cima de
	# card de chefe, rubrica ou caixa de diálogo, e nunca "queima" escondido.
	if _toast_busy() or toast_held() or _toast_wait > 0.0:
		if _toast_queue.size() < 6 and not _toast_queue.has(msg) and not (_toast_busy() and _toast_label.text == msg):
			_toast_queue.append(msg)
		return
	_show_toast(msg)


## Seta "Siga em frente →" na borda direita (tempo de jogo: congela na pausa/cena).
func go_cue() -> void:
	_go_t = GO_TIME


## Alpha da seta agora (0 = fora) — QA.
func go_alpha() -> float:
	if _go_t <= 0.0:
		return 0.0
	var k := clampf(minf((GO_TIME - _go_t) / 0.3, _go_t / 0.6), 0.0, 1.0)
	return k * (1.0 - _scene_k) * (1.0 - _recede)


func _show_toast(msg: String) -> void:
	if _toast == null:
		_toast_holder = Control.new()
		_toast_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_toast_holder)
		_toast = Control.new()
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast.position = TOAST_RECT.position
		_toast.size = TOAST_RECT.size
		_toast_holder.add_child(_toast)
		_place_toast()
		_toast_label = Label.new()
		_toast_label.size = Vector2(TOAST_RECT.size.x, 20)
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.add_theme_font_override("font", CodexStyle.display())
		_toast_label.add_theme_color_override("font_color", CodexStyle.GOLD_HI)
		_toast_label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.04, 0.92))
		_toast_label.add_theme_constant_override("outline_size", 5)
		_toast_label.clip_text = true
		_toast.add_child(_toast_label)
		CodexStyle.rule(_toast, Vector2(TOAST_RECT.size.x * 0.5 - 100.0, 22), 200, Color(CodexStyle.GOLD, 0.9))
	var fs := 13
	var font: Font = CodexStyle.display()
	while fs > 9 and font.get_string_size(I18n.t(msg), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > TOAST_RECT.size.x - 8.0:
		fs -= 1
	_toast_label.add_theme_font_size_override("font_size", fs)
	_toast_label.text = msg
	if msg == _seal_pending:
		_seal_pending = ""
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate = Color(1, 1, 1, 0)
	_toast.position.y = TOAST_RECT.position.y + 6.0
	_toast_tween = create_tween().set_parallel(true)
	_toast_tween.set_ignore_time_scale(true)      # o aviso dura o mesmo na câmera lenta
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.22)
	_toast_tween.tween_property(_toast, "position:y", TOAST_RECT.position.y, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(2.2)
	_toast_tween.chain().tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.chain().tween_callback(_next_toast)


func _next_toast() -> void:
	_toast_tween = null              # (o callback roda DENTRO do tween, que ainda conta como rodando)
	_toast_wait = TOAST_GAP          # o próximo da fila sai em _process_toasts


## Há um toast na tela agora (entrando, parado ou saindo)?
func _toast_busy() -> bool:
	return _toast != null and _toast_tween != null and _toast_tween.is_valid() and _toast_tween.is_running()


## Toasts seguram (QA2 #4/#5): card de chefe / Cinemática, cena dirigida
## (caixa de diálogo, rubrica, ilustração — scene_active) ou mundo pausado
## (pausa, loja, Estela). Avisos esperam na fila e saem quando o jogo volta.
func toast_held() -> bool:
	return get_tree().paused or PauseStack.is_held() or _recede > 0.0 or scene_active()


## Roda todo quadro (inclusive com a árvore pausada): segura o toast que
## estiver na tela quando uma cena começa (volta pra FRENTE da fila e reaparece
## inteiro depois) e solta a fila quando o jogo volta, com um respiro.
func _process_toasts() -> void:
	var held := toast_held()
	var now := Time.get_ticks_msec()
	var dt_real := 0.0 if _toast_ms == 0 else float(now - _toast_ms) / 1000.0
	_toast_ms = now
	if held:
		_toast_wait = TOAST_GAP
		if _toast_busy():
			var cur := _toast_label.text
			_toast_tween.kill()
			_toast_tween = null
			_toast.modulate.a = 0.0
			if cur != "" and not _toast_queue.has(cur):
				_toast_queue.push_front(cur)
		return
	if _toast_wait > 0.0:
		# tempo REAL: câmera lenta/hitstop não seguram o aviso
		_toast_wait -= minf(dt_real, 0.5)
		return
	if not _toast_busy() and not _toast_queue.is_empty():
		_show_toast(_toast_queue.pop_front())


## Toast visível agora? [texto, alpha efetivo] — QA/sonda.
func toast_state() -> Array:
	if _toast == null:
		return ["", 0.0]
	return [_toast_label.text, _toast.modulate.a if _toast.is_visible_in_tree() else 0.0]


## Conquista liberada (sinal Achievements.unlocked): aviso com o título dela.
func _on_achievement(id: String) -> void:
	var a: Dictionary = AchievementData.find(id)
	var title := String(a.get("title", ""))
	if title != "":
		toast("Conquista  ·  %s" % title)


## A legenda de caminhada (CaptionBar, no topo) informa a base da faixa dela a
## cada quadro; -1 = nenhuma legenda na tela.
func set_caption_band(bottom: float) -> void:
	_caption_bottom = bottom
	_place_toast()


## O toast fica na faixa dele (TOAST_RECT) ou logo abaixo da legenda, se ela
## estiver no ar.
func _place_toast() -> void:
	if _toast_holder == null:
		return
	var want := 0.0
	if _caption_bottom > 0.0:
		want = maxf(0.0, _caption_bottom + 4.0 - TOAST_RECT.position.y)
	_toast_holder.position.y = want


## R21: fora de combate (nenhum inimigo vivo perto, sem dano/golpe por 4 s) as
## faíscas e a arma recuam; qualquer sinal de luta as traz de volta em 150 ms.
func _process_calm(delta: float) -> void:
	_combat_check -= delta
	if _combat_check <= 0.0:
		_combat_check = 0.25
		if _enemy_near() or boss != null:
			_calm = 0.0
	_calm += delta
	# Faíscas subindo / arma nova: mostra inteiro.
	if _spark_pulse > 0.0 or _spark_pop > 0.0 or _weapon_flash > 0.0 or _relic_pulse > 0.5:
		_calm = 0.0
	var target := CALM_ALPHA if _calm >= CALM_AFTER else 1.0
	var rate := (1.0 - CALM_ALPHA) / (0.15 if target > _calm_a else 0.6)
	_calm_a = move_toward(_calm_a, target, delta * rate)
	_counters.modulate.a = _calm_a * (1.0 - _recede) * (1.0 - _scene_k)


func _enemy_near() -> bool:
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl == null:
		return false
	for e in get_tree().get_nodes_in_group("enemy"):
		var n := e as Node2D
		if n == null or not is_instance_valid(n):
			continue
		if n is Enemy and (n as Enemy).estate == Enemy.EState.DEAD:
			continue
		if n.global_position.distance_to(pl.global_position) <= COMBAT_RANGE:
			return true
	return false


func _process_low_hp(delta: float) -> void:
	var frac := hp / maxf(1.0, hp_max)
	if _low_t >= 0.0:
		_low_t += delta
		if _low_t >= LOW_HP_MAX_TIME or frac >= LOW_HP or hp <= 0.0:
			_low_t = -1.0
	var want := 1.0 if _low_t >= 0.0 and _low_t < LOW_HP_MAX_TIME - 0.6 else 0.0
	_low_fade = move_toward(_low_fade, want, delta * (2.5 if want > _low_fade else 1.6))
	# Um batimento por pulso da vinheta (0,9 Hz), no pico; o Áudio decide o volume
	# e segura o intervalo mínimo (Audio.low_health_pulse, se existir).
	if _low_fade > 0.5:
		var beat := int(floor(_t * 0.9 + 0.75))   # vira no pico do seno (fase 0,25)
		if beat != _low_beat:
			_low_beat = beat
			if Audio.has_method("low_health_pulse"):
				Audio.call("low_health_pulse")
	else:
		_low_beat = -1


## Intensidade da vinheta agora (α 0,12–0,18 pulsando a 0,9 Hz; 0 = nada).
func low_hp_alpha() -> float:
	if _low_fade <= 0.0:
		return 0.0
	var pulse := 0.5 + 0.5 * sin(_t * TAU * 0.9)
	return _low_fade * lerpf(0.12, 0.18, pulse)


## Card de chefe / cards da Cinemática na tela: o HUD inteiro recua (some em
## 0,2 s) para a tarja não cortar a barra de vida ao meio (QA-UX M4).
func _update_recede(delta: float) -> void:
	var want := 0.0
	for c in get_tree().root.get_children():
		if c is Cinematic and not c.is_queued_for_deletion():
			want = 1.0
			break
	_recede = move_toward(_recede, want, delta * 5.0)
	# Cena/diálogo no ar (QA C2): dicas de controle, combo e faíscas/arma somem;
	# medalhão, barras e Anéis ficam (a cena B usa as gemas do HUD).
	_scene_k = move_toward(_scene_k, 1.0 if scene_active() else 0.0, delta * 6.0)
	var a := 1.0 - _recede
	_canvas.modulate.a = a
	_counters.modulate.a = a * _calm_a * (1.0 - _scene_k)
	_combo_label.modulate.a = a * (1.0 - _scene_k)
	if _toast != null:
		_toast.visible = _recede < 0.99


## Há cena no ar? Caixa de diálogo aberta, Cinemática (card/ilustração) ou a
## Encenação dirigindo uma cena (Staging.is_active(), se existir — pedido à
## encenação; sem ele vale só a caixa/Cinemática, que cobrem as cenas 64/68).
func scene_active() -> bool:
	for c in get_tree().root.get_children():
		if (c is DialogueBox or c is Cinematic) and not c.is_queued_for_deletion():
			return true
	var lv := get_tree().current_scene
	if lv != null:
		for c in lv.get_children():
			if c is Staging and c.has_method("is_active") and bool(c.call("is_active")):
				return true
	return false


## Alpha das barras de chefe agora (0 = escondidas: sem chefe, card ou cena) — QA.
func boss_bar_alpha() -> float:
	var m := 0.0
	for o in bosses:
		m = maxf(m, float(o.show))
	return m * (1.0 - _scene_k) * (1.0 - _recede)


## Chamado (via grupo "hud") pelo chefe ao nascer — e de novo quando uma forma
## da batalha final se refaz (aí a barra dela volta a encher, fase I).
func show_boss(e: Node) -> void:
	if e == null or not is_instance_valid(e) or not ("health" in e) or e.get("health") == null:
		return
	var bb := _bar_of(e)
	if bb == null:
		bb = _BossBar.new()
		bb.node = e
		bosses.append(bb)
		var hc := _on_boss_hp.bind(e)
		if not e.health.health_changed.is_connected(hc):
			e.health.health_changed.connect(hc)
		var dc := _on_boss_died.bind(e)
		if not e.health.died.is_connected(dc):
			e.health.died.connect(dc)
	bb.phase = int(e.get("phase")) if e.get("phase") != null else 1
	bb.ratio = float(e.health.current_health) / maxf(1.0, float(e.health.max_health))
	bb.ghost = bb.ratio
	bb.down = false
	bb.leaving = false
	bb.revive_k = 0.0
	_refresh_main_boss()


func _on_boss_hp(c: int, m: int, e: Node) -> void:
	var bb := _bar_of(e)
	if bb == null:
		return
	var r := clampf(float(c) / maxf(1.0, float(m)), 0.0, 1.0)
	if r < bb.ratio:
		bb.hold = 0.5
	bb.ratio = r
	if r > 0.0 and bb.down:
		bb.down = false
		bb.ghost = r


func _on_boss_died(e: Node) -> void:
	var bb := _bar_of(e)
	if bb == null:
		return
	bb.ratio = 0.0
	# Batalha final: a forma que cai vai se refazer enquanto a outra viver.
	var other_alive := false
	for o in bosses:
		var ob: _BossBar = o
		if ob != bb and not ob.down and not ob.leaving and is_instance_valid(ob.node):
			other_alive = true
	if bool(e.get("revivable")) and other_alive:
		bb.down = true
		bb.revive_k = 0.0
	else:
		bb.leaving = true
		# Caiu a última: as que esperavam refazer-se também saem.
		for o in bosses:
			var ob: _BossBar = o
			if ob.down:
				ob.leaving = true
	_refresh_main_boss()


## Chamado pelo chefe ao entrar na fase 2. `who` diz QUAL chefe; sem ele
## (contrato antigo do enemy.gd: boss_phase(2)), vale o chefe cuja propriedade
## `phase` já chegou a `n` — com dois chefes, a fase vai para o certo.
func boss_phase(n: int, who: Node = null) -> void:
	var hit := false
	for o in bosses:
		var bb: _BossBar = o
		if not is_instance_valid(bb.node) or bb.leaving:
			continue
		var matches := false
		if who != null:
			matches = bb.node == who
		else:
			var p = bb.node.get("phase")
			matches = p != null and int(p) >= n and bb.phase < n
		if matches:
			bb.phase = n
			bb.flash = 1.0
			hit = true
	if not hit and who == null:
		# Sem `phase` legível: com um só chefe, é dele.
		var live := _live_bars()
		if live.size() == 1:
			(live[0] as _BossBar).phase = n
			(live[0] as _BossBar).flash = 1.0


## Contrato para QA (regressão A3): uma entrada por barra viva, na ordem em
## que os chefes nasceram: {node, ratio (0..1), phase (1/2), down (refazendo-se), name}.
func boss_bars() -> Array:
	var out: Array = []
	for o in bosses:
		var bb: _BossBar = o
		if bb.leaving or not is_instance_valid(bb.node):
			continue
		out.append({"node": bb.node, "ratio": bb.ratio, "phase": bb.phase, "down": bb.down,
			"name": String(bb.node.get("display_name")), "marks": bb.marks.duplicate()})
	return out


## Topo da área da(s) barra(s) de chefe na base (360 = nenhuma). A legenda
## (CaptionBar) termina acima disto.
func boss_area_top() -> float:
	for o in bosses:
		if (o as _BossBar).show > 0.05:
			return BOSS_BAR_Y - 18.0
	return 360.0


func _bar_of(e: Node) -> _BossBar:
	for o in bosses:
		if (o as _BossBar).node == e:
			return o
	return null


func _live_bars() -> Array:
	return bosses.filter(func(o): return not (o as _BossBar).leaving and is_instance_valid((o as _BossBar).node))


func _refresh_main_boss() -> void:
	boss = null
	for o in bosses:
		var bb: _BossBar = o
		if not bb.leaving and not bb.down and is_instance_valid(bb.node):
			boss = bb.node
			return


func _process_bosses(delta: float) -> void:
	var revive_src: Node = null
	for i in range(bosses.size() - 1, -1, -1):
		var bb: _BossBar = bosses[i]
		if not is_instance_valid(bb.node):
			bb.leaving = true
		if bb.leaving:
			bb.show = maxf(0.0, bb.show - delta * 2.0)
			if bb.show <= 0.0:
				_disconnect_boss(bb)
				bosses.remove_at(i)
			continue
		bb.show = minf(1.0, bb.show + delta * 3.0)
		if bb.hold > 0.0:
			bb.hold -= delta
		elif bb.ghost > bb.ratio:
			bb.ghost = move_toward(bb.ghost, bb.ratio, delta * (0.15 + (bb.ghost - bb.ratio) * 1.4))
		if bb.ghost < bb.ratio:
			bb.ghost = bb.ratio
		bb.flash = maxf(0.0, bb.flash - delta * 1.2)
		if bb.down:
			# Quanto falta para refazer-se: lido do FinalBattle (se existir).
			if revive_src == null:
				revive_src = _find_revive_source(bb.node)
			var k := bb.revive_k + delta / 14.0
			if revive_src != null:
				var ds = revive_src.get("down_since")
				var lim = revive_src.get("REVIVE_AFTER")
				if ds is Dictionary and ds.has(bb.node):
					k = float(ds[bb.node]) / maxf(0.1, float(lim) if lim != null else 14.0)
			bb.revive_k = clampf(k, 0.0, 1.0)


func _disconnect_boss(bb: _BossBar) -> void:
	if not is_instance_valid(bb.node) or bb.node.get("health") == null:
		return
	var h = bb.node.health
	var hc := _on_boss_hp.bind(bb.node)
	if h.health_changed.is_connected(hc):
		h.health_changed.disconnect(hc)
	var dc := _on_boss_died.bind(bb.node)
	if h.died.is_connected(dc):
		h.died.disconnect(dc)


## O nó que conta o tempo de "refazer" (FinalBattle.down_since), sem depender da classe.
func _find_revive_source(e: Node) -> Node:
	var scope: Array = []
	if is_instance_valid(e) and e.get_parent() != null:
		scope.append(e.get_parent())
	if get_tree().current_scene != null:
		scope.append(get_tree().current_scene)
	for sc in scope:
		for c in (sc as Node).get_children():
			if "down_since" in c:
				return c
	return null


## Centro da gema do Anel `i` em coordenadas de TELA (viewport base 640×360).
func ring_dot_global_pos(i: int) -> Vector2:
	return Vector2(RING_X0 + RING_DX * float(clampi(i, 0, 6)), RING_Y)


## O mesmo ponto convertido pro MUNDO (onde a câmera está agora) — pra soltar
## um efeito 2D do jogo exatamente em cima da gema.
func ring_dot_world_pos(i: int) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * ring_dot_global_pos(i)


## Anima a gema `i` saltando do encaixe e voando até `to` (coordenadas de TELA;
## padrão = o centro da tela, onde o Rei está na cena do roubo). O encaixe fica
## vazio até o próximo `rings_changed`. Devolve a duração (s).
func detach_ring(i: int, to: Vector2 = Vector2(320, 170)) -> float:
	if i < 0 or i >= ring_skills.size():
		return 0.0
	_detached[i] = true
	var sk: SkillData = ring_skills[i]
	var gem := _FlyingGem.new()
	gem.color = sk.color
	gem.position = ring_dot_global_pos(i)
	_canvas.add_child(gem)
	var start := gem.position
	var peak := start + Vector2(10, -22)
	var dur := 1.1
	var t := gem.create_tween()
	t.tween_property(gem, "lift", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(gem, "position", peak, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_method(func(k: float):
		gem.position = peak.lerp(to, k) + Vector2(0, -sin(k * PI) * 40.0)
		gem.spin = k, 0.0, 1.0, dur - 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(gem, "modulate:a", 0.0, 0.2)
	t.tween_callback(func():
		gem.queue_free()
		ring_detach_finished.emit(i))
	# Nota por gema: sobe 1 semitom a cada Anel arrancado (Audio.ring_note).
	if Audio.has_method("ring_note"):
		Audio.call("ring_note", i, false)
	else:
		Audio.play_sfx("ring_steal")
	return dur


## Anima a gema `i` VOLTANDO: nasce em `from` (coordenadas de TELA; padrão = o
## centro, onde a Sophia recebe os Anéis na cena D), desce em arco e assenta no
## encaixe, que reacende com o pop. O encaixe fica apagado durante o voo mesmo
## que o Progression já tenha devolvido o Anel. Devolve a duração (s).
func restore_ring(i: int, from: Vector2 = Vector2(320, 190)) -> float:
	if i < 0 or i >= ring_skills.size():
		return 0.0
	_incoming[i] = true
	_detached.erase(i)
	var sk: SkillData = ring_skills[i]
	var gem := _FlyingGem.new()
	gem.color = sk.color
	gem.position = from
	gem.lift = 1.0
	gem.modulate.a = 0.0
	_canvas.add_child(gem)
	var to := ring_dot_global_pos(i)
	var dur := 0.7
	var t := gem.create_tween()
	t.tween_property(gem, "modulate:a", 1.0, 0.12)
	t.tween_method(func(k: float):
		gem.position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 30.0)
		gem.spin = 1.0 - k, 0.0, 1.0, dur - 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(gem, "lift", 0.0, 0.1)
	t.tween_callback(func():
		gem.queue_free()
		_incoming.erase(i)
		if i < _ring_pop.size():
			_ring_pop[i] = 1.0
		ring_restore_finished.emit(i))
	# O som da gema que VOLTA é do HUD (decisão do chefe): nota descendente por
	# Anel quando o Áudio tiver ring_note; senão o ring_gain simples.
	if Audio.has_method("ring_note"):
		Audio.call("ring_note", i, true)
	else:
		Audio.play_sfx("ring_gain")
	return dur


## Um orbe de faísca CHEGOU na Sophia: o contador sobe 1 (até o total já
## creditado) com um pop curto. Chamado pelo spark_orb.gd (grupo "hud").
func spark_orb_arrived(amount: int = 1) -> void:
	orb_mode = true
	if sparks_shown < float(sparks):
		sparks_shown = minf(float(sparks), floorf(sparks_shown) + float(maxi(1, amount)))
	_spark_pop = SPARK_POP
	_spark_hold = 0.4               # mais orbes podem vir; o resto corre depois
	# Brasa (cura) e Lâmpada (Éter) agem a cada faísca que chega: a relíquia acende.
	var rid := RunLabels.relic_id()
	if rid == "brasa" or rid == "lampada":
		_relic_pulse = 1.0


# --- selos, relíquia e objetivo (Onda 6) ---------------------------------------------

## Grau atual (Arcontes vencidos) — Progression.progress_tier() da progressao6.
func _progress_tier() -> int:
	if not Progression.has_method("progress_tier"):
		return 0
	return int(Progression.call("progress_tier"))


## Um Arconte caiu e o grau subiu: "Selo aberto · Arma Nv. 3 na loja" (o mais
## notável que destravou). Fora do run/Provação nada (lá tudo já está aberto).
func _check_seal() -> void:
	var t := _progress_tier()
	if not RunManager.run_active or CodexSession.active:
		_tier_seen = t
		return
	if _tier_seen >= 0 and t > _tier_seen:
		var msg := seal_text(t)
		if msg != "":
			_seal_pending = msg
			toast(msg)
	_tier_seen = t


## Texto do aviso do selo do grau `t` (já no idioma ativo).
static func seal_text(t: int) -> String:
	var what := ""
	var wt = Progression.get("WEAPON_TIER")
	if wt is Array:
		for lv in range(Progression.weapon_level + 1, (wt as Array).size()):
			if int(wt[lv]) == t:
				what = I18n.t("Arma Nv. %d na loja") % lv
				break
	var rel = GameContent.get("relics")
	if what == "" and rel is Array and Progression.has_method("has_relic"):
		for r in rel:
			if int(r.get("tier", 0)) == t and not bool(Progression.call("has_relic", String(r.get("id", "")))):
				what = I18n.t("%s na loja") % I18n.t(String(r.get("name", "")))
				break
	if what == "":
		what = I18n.t("mais Vida e Éter na loja")
	return "%s  ·  %s" % [I18n.t("Selo aberto"), what]


## Objetivo da zona trancada agora ("" = só ondas/nenhuma) — Level.zone_objective (level6).
func zone_objective_now() -> String:
	var lv := get_tree().current_scene
	if lv == null or not lv.has_method("zone_objective") or not ("zone_active" in lv):
		return ""
	if not bool(lv.get("zone_active")):
		return ""
	var zi = lv.get("zone_index")
	if zi == null or int(zi) < 0:
		return ""
	var o := String(lv.call("zone_objective", int(zi)))
	return o if RunLabels.objective_text(o) != "" else ""


func _process_objective(delta: float) -> void:
	var o := zone_objective_now()
	if o != "":
		_obj_kind = o
	_obj_k = move_toward(_obj_k, 1.0 if o != "" else 0.0, delta * (4.0 if o != "" else 2.0))


## Ícone do objetivo no ar? [tipo, alpha] — QA/sonda.
func objective_state() -> Array:
	return [_obj_kind if _obj_k > 0.0 else "", _obj_k * (1.0 - _scene_k) * (1.0 - _recede)]


# --- dicas de controle -----------------------------------------------------------------

## Enfileira uma dica. `segs` = [{keys: ["jump"], text: "pular"}, ...]; as teclas
## saem do InputMap no formato do dispositivo em uso.
func show_hint(segs: Array) -> void:
	if CodexSession.active or segs.is_empty():
		return
	hints.append(segs)


## Dica de ENSINO que entra JÁ (narrativa: contra-ataque, pulo duplo): fura a
## fila, ignora o "já aprendeu" e não encurta quando a jogadora aperta a tecla
## (o ensino é a sequência/o momento, não a tecla). A dica que estava no ar volta
## para a frente da fila. Aceita os segmentos ([{keys, text}]) ou (texto, teclas).
func show_hint_now(segs_or_text: Variant, keys: Array = []) -> void:
	if CodexSession.active:
		return
	var segs: Array = []
	if segs_or_text is Array:
		segs = segs_or_text
	else:
		segs = [{"keys": keys, "text": String(segs_or_text)}]
	if segs.is_empty():
		return
	if not _hint.is_empty() and not _hint_forced and _hint_t < _hint_dur - 0.8:
		hints.push_front(_hint)
	_hint = segs
	_hint_t = 0.0
	_hint_done.clear()
	_hint_forced = true
	_hint_dur = HINT_NOW_TIME
	_hint_gap = 0.0


## Dica no ar agora (QA): {segs, forced, t, dur}; {} sem dica.
func hint_state() -> Dictionary:
	if _hint.is_empty():
		return {}
	return {"segs": _hint, "forced": _hint_forced, "t": _hint_t, "dur": _hint_dur}


func _queue_screen_hints() -> void:
	if CodexSession.active or not RunManager.run_active:
		return
	var sc := RunManager.current_screen
	if sc < 1 or sc > 3 or not Narrative.once("dica_tela_%d" % sc):
		return
	match sc:
		1:
			show_hint([{"keys": ["@move"], "text": "mover"}, {"keys": ["jump"], "text": "pular"}])
			show_hint([{"keys": ["attack_light"], "text": "golpe leve"}, {"keys": ["attack_heavy"], "text": "golpe forte"}])
			show_hint([{"keys": ["dodge"], "text": "esquiva"}, {"keys": ["block"], "text": "bloquear · no tempo, apara"}])
		2:
			show_hint([{"keys": ["attack_light", "attack_light", "attack_light"], "text": "sequência do cajado"}])
			show_hint([{"keys": ["skill2"], "text": "Esfera Solar (gasta Éter)"}])
		3:
			show_hint([{"keys": [], "text": "telégrafo amarelo:"}, {"keys": ["block"], "text": "apara"}, {"keys": [], "text": "vermelho:"}, {"keys": ["dodge"], "text": "esquiva"}])
			show_hint([{"keys": ["pause"], "text": "pausa · Golpes & Controles"}])


## 1ª vez com um Anel (e com dois, para trocar).
func _check_ring_hints() -> void:
	if CodexSession.active or not RunManager.run_active:
		return
	var usable := 0
	for sk in ring_skills:
		if Progression.ring_usable((sk as SkillData).ring):
			usable += 1
	if usable >= 1 and Narrative.once("dica_anel"):
		show_hint([{"keys": ["skill1"], "text": "usar o Anel equipado (gasta Éter)"}])
	if usable >= 2 and Narrative.once("dica_trocar_anel"):
		show_hint([{"keys": ["ring_prev", "ring_next"], "text": "trocar de Anel"}])


func _process_hints(delta: float) -> void:
	if _hint.is_empty():
		if hints.is_empty():
			return
		_hint_gap -= delta
		if _hint_gap > 0.0:
			return
		var nxt: Array = hints.pop_front()
		if _hint_learned(nxt):
			return                   # já sabe (usou tudo o que ela ensina): não ocupa o topo
		_hint = nxt
		_hint_t = 0.0
		_hint_done.clear()
		_hint_forced = false
		_hint_dur = HINT_TIME
		return
	_hint_t += delta
	# Usou tudo o que a dica pede: encurta (a dica já cumpriu o papel).
	var need := 0
	for seg in _hint:
		need += (seg.get("keys", []) as Array).size()
	if not _hint_forced and need > 0 and _hint_done.size() >= _distinct_actions(_hint) and _hint_t < _hint_dur - 0.8:
		_hint_t = _hint_dur - 0.8
	if _hint_t >= _hint_dur:
		_hint = []
		_hint_forced = false
		_hint_gap = 0.5


## A dica só ENSINA teclas (todo segmento tem tecla) e a jogadora já usou todas
## nesta sessão? Então não aparece (QA2 #10: o topo não repete o que ela já sabe).
## Sempre saem: dicas com texto sem tecla ("telégrafo amarelo:") ou com um
## complemento depois de "·" ("bloquear · no tempo, apara") — ensinam leitura, não
## só a tecla — e as de SEQUÊNCIA (a mesma tecla repetida: "sequência do cajado").
func _hint_learned(h: Array) -> bool:
	if h.is_empty():
		return true
	for seg in h:
		var ks: Array = seg.get("keys", [])
		if ks.is_empty() or String(seg.get("text", "")).contains("·"):
			return false
		var seen := {}
		for a in ks:
			if seen.has(a) or not _used_actions.has(String(a)):
				return false
			seen[a] = true
	return true


## Ação usada nesta sessão? (QA/sonda)
func action_used(a: String) -> bool:
	return _used_actions.has(a)


func _distinct_actions(h: Array) -> int:
	var d := {}
	for seg in h:
		for a in seg.get("keys", []):
			d[a] = true
	return d.size()


## Alpha da dica atual (entra 0,25 s, sai 0,4 s; some durante cena/diálogo).
func hint_alpha() -> float:
	if _hint.is_empty():
		return 0.0
	return clampf(minf(_hint_t / 0.25, (_hint_dur - _hint_t) / 0.4), 0.0, 1.0) * (1.0 - _scene_k)


func _input(event: InputEvent) -> void:
	# Dispositivo em uso = o do último InputEvent relevante (com o InputGlyphs,
	# ele decide — e sabe se é Xbox, PlayStation, Switch ou Deck).
	var g = DialogueBox.glyphs()
	if g != null:
		g.note_event(event)
		use_pad = bool(g.is_pad())
	elif event is InputEventKey or event is InputEventMouseButton:
		use_pad = false
	elif event is InputEventJoypadButton:
		use_pad = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		use_pad = true
	# Memória do que ela já usou (vale pela sessão; dicas aprendidas não voltam).
	if event.is_pressed() and not event.is_echo() and not get_tree().paused:
		if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
			_used_actions["@move"] = true
		for a in HINT_ACTIONS:
			if InputMap.has_action(a) and event.is_action_pressed(a):
				_used_actions[a] = true
	if not _hint.is_empty() and not get_tree().paused:
		for seg in _hint:
			for a in seg.get("keys", []):
				if a == "@move":
					if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
						_hint_done[a] = true
				elif InputMap.has_action(a) and event.is_action_pressed(a):
					_hint_done[a] = true


## Rótulo curto da tecla/botão de `action` para o dispositivo em uso.
func key_label(action: String) -> String:
	var g = DialogueBox.glyphs()
	if g != null:
		return String(g.label(action, _glyph_dev(g)))
	if action == "@move":
		return "Analógico" if use_pad else "%s  %s" % [key_label("move_left"), key_label("move_right")]
	if not InputMap.has_action(action):
		return "?"
	var evs := InputMap.action_get_events(action)
	if use_pad:
		for e in evs:
			if e is InputEventJoypadButton:
				return _pad_button_name((e as InputEventJoypadButton).button_index)
		for e in evs:
			if e is InputEventJoypadMotion:
				return _pad_axis_name((e as InputEventJoypadMotion).axis, (e as InputEventJoypadMotion).axis_value)
	for e in evs:
		if e is InputEventKey:
			var k := e as InputEventKey
			var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
			return _key_name(code)
	return "?"


## Dispositivo para o InputGlyphs: o dele, mas coerente com `use_pad` (sonda/QA
## podem forçar use_pad; aí vale o tipo de controle que ele já conhece).
func _glyph_dev(g) -> int:
	var d: int = int(g.device())
	if use_pad == (d != 0):
		return d
	return 1 if use_pad else 0        # Device.XBOX / Device.KEYBOARD


## Largura do ícone da ação nas dicas (InputGlyphs) ou -1 sem ele.
func glyph_width(action: String, h: float) -> float:
	var g = DialogueBox.glyphs()
	if g == null:
		return -1.0
	return float(g.icon_width(action, h, null, _glyph_dev(g)))


## Desenha o ícone da ação em `ci` (dentro do _draw dele) — só com o InputGlyphs.
func draw_glyph(ci: CanvasItem, center: Vector2, action: String, h: float, alpha: float) -> void:
	var g = DialogueBox.glyphs()
	if g != null:
		g.draw_icon(ci, center, action, h, null, _glyph_dev(g), alpha)


static func _key_name(code: Key) -> String:
	match code:
		KEY_SPACE: return "Espaço"
		KEY_ESCAPE: return "Esc"
		KEY_SHIFT: return "Shift"
		KEY_ENTER: return "Enter"
		KEY_LEFT: return "Esq."
		KEY_RIGHT: return "Dir."
		KEY_UP: return "Cima"
		KEY_DOWN: return "Baixo"
	return OS.get_keycode_string(code)


static func _pad_button_name(b: JoyButton) -> String:
	match b:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_BACK: return "Back"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_DPAD_LEFT: return "D-pad Esq."
		JOY_BUTTON_DPAD_RIGHT: return "D-pad Dir."
		JOY_BUTTON_DPAD_UP: return "D-pad Cima"
		JOY_BUTTON_DPAD_DOWN: return "D-pad Baixo"
	return "Botão %d" % int(b)


static func _pad_axis_name(axis: JoyAxis, _v: float) -> String:
	match axis:
		JOY_AXIS_TRIGGER_LEFT: return "LT"
		JOY_AXIS_TRIGGER_RIGHT: return "RT"
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y: return "Analógico"
	return "Eixo %d" % int(axis)


# --- montagem ------------------------------------------------------------------------

func _build_combo() -> void:
	_combo_label = Label.new()
	_combo_label.position = Vector2(520, 52)
	_combo_label.size = Vector2(100, 30)
	_combo_label.pivot_offset = Vector2(100, 15)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_label.add_theme_font_override("font", CodexStyle.display_bold())
	_combo_label.add_theme_font_size_override("font_size", 24)
	_combo_label.add_theme_color_override("font_color", CodexStyle.GOLD_HI)
	_combo_label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.04, 0.9))
	_combo_label.add_theme_constant_override("outline_size", 6)
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_combo_label)


## Rótulo do papel da tela ("Fome · Travessia I", "Fome · Arena") ou da Provação.
func screen_title() -> String:
	return RunLabels.role_title(RunManager.current_screen)


# =====================================================================================
## A tela de desenho do HUD (um único Control; tudo em _draw).
class _HudCanvas extends Control:
	var hud
	var last_usable: Dictionary = {}
	var only_counters: bool = false

	func _draw() -> void:
		if only_counters:
			_draw_counters()
			return
		_draw_low_hp()
		_draw_scrim()
		_draw_medal()
		_draw_bars()
		_draw_rings()
		_draw_eon()
		_draw_objective()
		_draw_boss()
		_draw_combo_tag()
		_draw_hint()
		_draw_go()

	# --- texto com contorno -----------------------------------------------------------
	func _txt(pos: Vector2, s: String, font: Font, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, outline: int = 4) -> void:
		s = I18n.t(s)        # i18n (Onda 4): o HUD desenha à mão — sem tradução automática
		if outline > 0:
			draw_string_outline(font, pos, s, align, width, size, outline, Color(0.01, 0.03, 0.04, 0.85 * col.a))
		draw_string(font, pos, s, align, width, size, col)

	# --- vinheta de vida baixa (R22) ----------------------------------------------------
	func _draw_low_hp() -> void:
		var a: float = hud.low_hp_alpha()
		if a <= 0.0:
			return
		var edge := Color(0.32, 0.02, 0.03, a)
		var clear := Color(0.32, 0.02, 0.03, 0.0)
		var o := Rect2(0, 0, 640, 360)
		var i := Rect2(70, 50, 500, 260)
		var quads := [
			[o.position, Vector2(o.end.x, 0), Vector2(i.end.x, i.position.y), i.position],
			[Vector2(o.end.x, 0), o.end, i.end, Vector2(i.end.x, i.position.y)],
			[o.end, Vector2(0, o.end.y), Vector2(i.position.x, i.end.y), i.end],
			[Vector2(0, o.end.y), o.position, i.position, Vector2(i.position.x, i.end.y)],
		]
		for q in quads:
			draw_polygon(PackedVector2Array(q), PackedColorArray([edge, edge, clear, clear]))

	# --- seta "Siga em frente" (borda direita) ---------------------------------------
	func _draw_go() -> void:
		var a: float = hud.go_alpha()
		if a <= 0.0:
			return
		var y := 172.0
		var x := 628.0
		_soft_ellipse(Vector2(x - 70, y), Vector2(96, 20), 0.4 * a)
		var slide := fmod(hud._t * 1.6, 1.0)          # chevrons correndo para a direita
		for i in 3:
			var ph := fmod(float(i) / 3.0 + slide, 1.0)
			var cx := x - 22.0 + ph * 16.0
			var ca := a * sin(ph * PI)
			var col := Color(CodexStyle.GOLD_HI, ca)
			draw_polyline(PackedVector2Array([Vector2(cx - 4, y - 7), Vector2(cx + 3, y), Vector2(cx - 4, y + 7)]), Color(0.01, 0.03, 0.04, ca * 0.8), 4.0, true)
			draw_polyline(PackedVector2Array([Vector2(cx - 4, y - 7), Vector2(cx + 3, y), Vector2(cx - 4, y + 7)]), col, 2.0, true)
		_txt(Vector2(x - 330, y + 4), "Siga em frente", CodexStyle.display(), 11, Color(CodexStyle.GOLD_HI, a), HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 5)

	# --- sombra de leitura (QA7 #24) ----------------------------------------------------
	# O HUD já fica numa CanvasLayer acima do mundo; o problema era LEITURA: anéis,
	# orbes e mantos dos chefes passando atrás do medalhão/barras. Uma sombra macia
	# (elipse que esfuma) separa o HUD do mundo; mais forte com chefe na arena.
	func _draw_scrim() -> void:
		var busy: bool = hud.boss != null or not (hud.bosses as Array).is_empty()
		var a := 0.5 if busy else 0.32
		_soft_ellipse(Vector2(92, 36), Vector2(132, 58), a)
		_soft_ellipse(Vector2(EON_RIGHT - 52, 18), Vector2(110, 28), a * 0.85)

	func _soft_ellipse(c: Vector2, r: Vector2, a: float) -> void:
		var ink := Color(0.0, 0.015, 0.025, a)
		var mid := Color(ink, a * 0.55)
		var clear := Color(ink, 0.0)
		var n := 28
		for i in n:
			var t0 := TAU * float(i) / float(n)
			var t1 := TAU * float(i + 1) / float(n)
			var d0 := Vector2(cos(t0), sin(t0))
			var d1 := Vector2(cos(t1), sin(t1))
			var m0 := c + d0 * r * 0.55
			var m1 := c + d1 * r * 0.55
			draw_primitive(PackedVector2Array([c, m0, m1]), PackedColorArray([ink, mid, mid]), PackedVector2Array())
			draw_primitive(PackedVector2Array([m0, c + d0 * r, c + d1 * r, m1]), PackedColorArray([mid, clear, clear, mid]), PackedVector2Array())

	# --- medalhão ----------------------------------------------------------------------
	func _draw_medal() -> void:
		var c: Vector2 = MEDAL_C
		var r: float = MEDAL_R
		var low: bool = hud.hp_shown < 0.3
		var pulse := 0.5 + 0.5 * sin(hud._t * 6.0)
		draw_circle(c + Vector2(0, 1.5), r + 3.5, Color(0, 0, 0, 0.45))
		draw_circle(c, r + 2.5, CodexStyle.INK_DEEP)
		if hud._portrait != null:
			draw_texture_rect(hud._portrait, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
		else:
			CodexStyle.draw_spark(self, c, r * 0.6)
		if low:
			draw_circle(c, r, Color(CodexStyle.EMBER, 0.18 * pulse))
		var ring_col := CodexStyle.GOLD.lerp(CodexStyle.EMBER, pulse * 0.8) if low else CodexStyle.GOLD
		draw_arc(c, r + 0.8, 0.0, TAU, 48, ring_col, 1.6, true)
		draw_arc(c, r + 2.6, 0.0, TAU, 48, Color(CodexStyle.GOLD_LO, 0.9), 0.6, true)
		draw_arc(c, r - 0.9, 0.0, TAU, 48, Color(CodexStyle.GOLD_HI, 0.35), 0.5, true)
		# quatro cravos nos pontos cardeais
		for k in 4:
			var a := k * PI * 0.5
			CodexStyle.draw_diamond(self, c + Vector2(cos(a), sin(a)) * (r + 2.6), 1.8, CodexStyle.GOLD_HI)
		# ponte do medalhão até as barras
		draw_line(c + Vector2(r + 3.0, -13), Vector2(HP_RECT.position.x - 2, HP_RECT.position.y + 4), Color(CodexStyle.GOLD, 0.55), 0.6, true)

	# --- barras ------------------------------------------------------------------------
	func _bar(rect: Rect2, frac: float, ghost: float, c_lo: Color, c_hi: Color, flash: float) -> void:
		var s := rect.size.y * 0.5      # chanfro = meia altura (pontas em cunha)
		var outer := rect.grow(1.5)
		draw_colored_polygon(_wedge(outer, s + 1.5), Color(0.01, 0.03, 0.04, 0.8))
		draw_colored_polygon(_wedge(rect, s), Color("1a1418") if c_lo.r > c_lo.b else Color("0f1a24"))
		# (fantasma estreita demais vira polígono degenerado: só a partir de 2 chanfros)
		if ghost > frac and rect.size.x * ghost >= s * 2.0 + 0.5:
			var g := Rect2(rect.position, Vector2(rect.size.x * ghost, rect.size.y))
			draw_colored_polygon(_wedge(g, s), Color(CodexStyle.SPARK, 0.75))
		if frac > 0.0:
			var f := Rect2(rect.position, Vector2(maxf(s * 2.0, rect.size.x * frac), rect.size.y))
			var pts := _wedge(f, s)
			var cols := PackedColorArray()
			for p in pts:
				var k := (p.y - f.position.y) / f.size.y
				cols.append(c_hi.lerp(c_lo, clampf(k * 1.4, 0.0, 1.0)).lerp(Color.WHITE, flash * 0.6))
			draw_polygon(pts, cols)
			# brilho na quina de cima
			draw_line(f.position + Vector2(s, 0.6), Vector2(f.end.x - s, f.position.y + 0.6), Color(1, 1, 1, 0.35), 0.5, true)
		var loop := _wedge(rect.grow(1.0), s + 1.0)
		loop.append(loop[0])
		draw_polyline(loop, Color(CodexStyle.GOLD, 0.85), 0.8, true)
		# terminal ornamental na ponta direita
		CodexStyle.draw_diamond(self, Vector2(rect.end.x + s + 3.5, rect.position.y + rect.size.y * 0.5), 2.2, CodexStyle.GOLD, Color(0, 0, 0, 0.6))

	func _wedge(r: Rect2, s: float) -> PackedVector2Array:
		var m := r.position.y + r.size.y * 0.5
		return PackedVector2Array([
			Vector2(r.position.x, m), Vector2(r.position.x + s, r.position.y), Vector2(r.end.x - s, r.position.y),
			Vector2(r.end.x, m), Vector2(r.end.x - s, r.end.y), Vector2(r.position.x + s, r.end.y)])

	func _draw_bars() -> void:
		_bar(HP_RECT, hud.hp_shown, hud.hp_ghost, CodexStyle.LIFE.darkened(0.25), CodexStyle.LIFE_HI, hud._hp_flash)
		_bar(MP_RECT, hud.mp_shown, hud.mp_shown, CodexStyle.ETHER.darkened(0.2), CodexStyle.ETHER_HI, 0.0)
		# marcas a cada 25 % na barra de vida (leitura rápida)
		for k in [0.25, 0.5, 0.75]:
			var x: float = HP_RECT.position.x + HP_RECT.size.x * k
			draw_line(Vector2(x, HP_RECT.position.y + 1), Vector2(x, HP_RECT.end.y - 1), Color(0, 0, 0, 0.35), 0.6)

	# --- faíscas e arma ------------------------------------------------------------------
	func _draw_counters() -> void:
		var y := 43.0
		var p: float = hud._spark_pulse
		CodexStyle.draw_spark(self, Vector2(63, y), 4.6 + p * 1.6)
		# pop do orbe: 1,0 → 1,15 → 1,0 em SPARK_POP (escala em volta do número)
		var pk: float = 1.0 - hud._spark_pop / SPARK_POP if hud._spark_pop > 0.0 else 1.0
		var sc := 1.0 + 0.15 * sin(pk * PI)
		var piv := Vector2(71, y)
		draw_set_transform(piv - piv * sc, 0.0, Vector2(sc, sc))
		_txt(Vector2(71, y + 4.0), str(int(round(hud.sparks_shown))), CodexStyle.body_bold(), 12, CodexStyle.SPARK.lerp(Color.WHITE, maxf(p, 0.6 * sin(pk * PI))))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# arma: um cajado com gema + 5 losangos de nível
		var x0 := 118.0
		var wf: float = minf(1.0, hud._weapon_flash)
		draw_line(Vector2(x0 - 3, y + 5), Vector2(x0 + 3, y - 5), CodexStyle.GOLD, 1.1, true)
		draw_circle(Vector2(x0 + 3.6, y - 5.8), 1.9, Color("63e2d2").lerp(Color.WHITE, wf))
		draw_arc(Vector2(x0 + 3.6, y - 5.8), 2.6, 0.0, TAU, 12, CodexStyle.GOLD, 0.6, true)
		for i in Progression.MAX_WEAPON_LEVEL:
			var on: bool = i < hud.weapon
			var c := Vector2(x0 + 11.0 + i * 8.5, y)
			if on:
				CodexStyle.draw_diamond(self, c, 3.4, CodexStyle.GOLD_HI.lerp(Color.WHITE, wf * 0.8), Color(0, 0, 0, 0.7))
			else:
				CodexStyle.draw_diamond(self, c, 3.0, Color(0.02, 0.05, 0.07, 0.75), Color(CodexStyle.GOLD, 0.5))
		# relíquia em uso (progressao6): pequeno emblema depois dos losangos
		var rid := RunLabels.relic_id()
		var rx := x0 + 11.0 + Progression.MAX_WEAPON_LEVEL * 8.5 + 6.0
		if rid != "":
			var rd := RunLabels.relic_data(rid)
			_draw_relic(Vector2(rx, y), rid, rd.get("color", CodexStyle.GOLD_HI), hud._relic_pulse)
			rx += 9.0
		# arma subiu: o rótulo aparece ao lado dos losangos e se apaga
		if wf > 0.0:
			var tx := rx
			_txt(Vector2(tx, y + 3.5), "Arma Nv. %d" % hud.weapon, CodexStyle.display(), 8, Color(CodexStyle.GOLD_HI, clampf(wf, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)

	## Emblema da relíquia: brasa (chama), lâmpada (candeia) ou pérola, num
	## encaixe escuro com filete de ouro; acende quando ela age.
	func _draw_relic(c: Vector2, id: String, col: Color, pulse: float) -> void:
		if pulse > 0.0:
			draw_circle(c, 6.0 + pulse * 3.0, Color(col, 0.28 * pulse))
		draw_circle(c, 5.6, Color(0.01, 0.03, 0.04, 0.85))
		draw_arc(c, 5.6, 0.0, TAU, 20, Color(CodexStyle.GOLD, 0.85), 0.7, true)
		var lit := col.lerp(Color.WHITE, pulse * 0.6)
		match id:
			"brasa":
				var fl := PackedVector2Array([c + Vector2(0, -4.2), c + Vector2(1.6, -1.6), c + Vector2(2.6, 0.6),
					c + Vector2(1.8, 2.6), c + Vector2(0, 3.3), c + Vector2(-1.8, 2.6), c + Vector2(-2.6, 0.6), c + Vector2(-1.2, -1.2)])
				draw_colored_polygon(fl, lit)
				draw_circle(c + Vector2(0, 1.4), 1.2, Color(1, 0.95, 0.75, 0.9))
			"lampada":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-3.4, 1.0), c + Vector2(3.4, 1.0), c + Vector2(2.0, 3.0), c + Vector2(-2.0, 3.0)]), CodexStyle.GOLD)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3.6), c + Vector2(1.3, -0.8), c + Vector2(0, 0.6), c + Vector2(-1.3, -0.8)]), lit)
			"perola":
				draw_circle(c, 3.0, lit)
				draw_circle(c + Vector2(-0.9, -1.0), 0.9, Color(1, 1, 1, 0.9))
			_:
				CodexStyle.draw_diamond(self, c, 3.0, lit)

	# --- objetivo da zona (level6): ícone + 3 palavras sob o progresso do Éon ---------------
	func _draw_objective() -> void:
		var a: float = hud._obj_k * (1.0 - hud._scene_k)
		if a <= 0.01 or CodexSession.active:
			return
		var kind: String = hud._obj_kind
		var tx := RunLabels.objective_text(kind)
		if tx == "":
			return
		var col := CodexStyle.ETHER_HI
		if kind == "totem":
			col = CodexStyle.EMBER
		elif kind == "proteger":
			col = CodexStyle.SPARK
		var font: Font = CodexStyle.italic()
		var fs := 10
		var tw := font.get_string_size(I18n.t(tx), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y := 42.0
		var right: float = EON_RIGHT
		var ic := Vector2(right - tw - 10.0, y - 3.0)
		var pl := 0.5 + 0.5 * sin(hud._t * 3.0)
		# placa que se dissolve à esquerda (lê sobre cenário claro)
		var pw := tw + 28.0
		var px := right + 4.0 - pw
		var c0 := Color(0.01, 0.025, 0.035, 0.0)
		var c1 := Color(0.01, 0.025, 0.035, 0.7 * a)
		draw_polygon(PackedVector2Array([Vector2(px, y - 10.0), Vector2(right + 4.0, y - 10.0), Vector2(right + 4.0, y + 4.0), Vector2(px, y + 4.0)]),
			PackedColorArray([c0, c1, c1, c0]))
		draw_circle(ic, 6.2, Color(0.01, 0.03, 0.04, 0.9 * a))
		draw_arc(ic, 6.2, 0.0, TAU, 20, Color(col, (0.6 + 0.4 * pl) * a), 0.8, true)
		var c2 := Color(col, a)
		if kind == "totem":
			# pilar com o olho que chama reforços
			draw_rect(Rect2(ic + Vector2(-2.0, -4.2), Vector2(4.0, 8.4)), c2)
			draw_line(ic + Vector2(-3.4, -4.2), ic + Vector2(3.4, -4.2), c2, 1.0)
			draw_circle(ic + Vector2(0, -1.0), 1.1, Color(0.01, 0.03, 0.04, a))
		elif kind == "proteger":
			# a luz: chama pequena com raios
			for k in 6:
				var ang: float = k * TAU / 6.0 + hud._t * 0.6
				draw_line(ic + Vector2(cos(ang), sin(ang)) * 3.4, ic + Vector2(cos(ang), sin(ang)) * 4.9, Color(col, 0.7 * a), 0.6, true)
			draw_circle(ic, 2.4, c2)
			draw_circle(ic, 1.1, Color(1, 1, 1, 0.9 * a))
		else:
			# a maré: duas ondas
			for row in 2:
				var pts := PackedVector2Array()
				for i in 9:
					var xx := -4.5 + i * 1.125
					pts.append(ic + Vector2(xx, -1.5 + row * 3.2 + sin(xx * 1.4 + hud._t * 3.0) * 1.0))
				draw_polyline(pts, c2, 0.9, true)
		_txt(Vector2(right - tw, y + 0.5), tx, font, fs, Color(CodexStyle.PAPER.lerp(col, 0.35), a), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)

	# --- os 7 Anéis -----------------------------------------------------------------------
	func _draw_rings() -> void:
		var n: int = hud.ring_skills.size()
		if n == 0:
			return
		var sel := clampi(Progression.selected_ring, 0, n - 1)
		# trilho que une os encaixes
		draw_line(Vector2(RING_X0 - 6, RING_Y), Vector2(RING_X0 + RING_DX * (n - 1) + 6, RING_Y), Color(CodexStyle.GOLD_LO, 0.8), 0.8, true)
		for i in n:
			var sk: SkillData = hud.ring_skills[i]
			var c := Vector2(RING_X0 + RING_DX * i, RING_Y)
			var owned: bool = Progression.rings.has(sk.ring)
			var usable: bool = Progression.ring_usable(sk.ring) and not hud._detached.has(i) and not hud._incoming.has(i)
			last_usable[i] = usable
			var selected: bool = i == sel and usable
			# encaixe (sempre)
			draw_circle(c, 6.2, Color(0.01, 0.03, 0.04, 0.85))
			draw_arc(c, 6.2, 0.0, TAU, 20, CodexStyle.GOLD if owned else Color(CodexStyle.GOLD_LO, 0.9), 0.8, true)
			if usable:
				var pop: float = hud._ring_pop[i]
				_gem(c, 4.6 * (1.0 + pop * 0.6), sk.color, selected)
			elif owned:
				# roubado: encaixe rachado, eco cinza da gema
				_gem_outline(c, 4.2, Color(0.55, 0.52, 0.6, 0.7))
				draw_polyline(PackedVector2Array([c + Vector2(-3.5, -3.2), c + Vector2(-0.6, -0.4), c + Vector2(0.8, -1.6), c + Vector2(3.4, 3.4)]), Color(0.75, 0.7, 0.78, 0.9), 0.7, true)
			else:
				# ainda não conquistado: só o contorno apagado, tingido do Arconte
				_gem_outline(c, 3.6, Color(sk.color.lerp(CodexStyle.GOLD, 0.3), 0.42))
			if selected:
				var pl := 0.5 + 0.5 * sin(hud._t * 3.0)
				draw_arc(c, 8.0, 0.0, TAU, 24, Color(CodexStyle.GOLD_HI, 0.55 + 0.35 * pl), 1.0, true)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-2.2, 10.0), c + Vector2(2.2, 10.0), c + Vector2(0, 7.8)]), CodexStyle.GOLD_HI)
		# nome do Anel equipado (ou o aviso de roubo)
		var sk_sel: SkillData = hud.ring_skills[sel]
		var tx: float = RING_X0 + RING_DX * (n - 1) + 12.0
		if Progression.ring_usable(sk_sel.ring):
			_txt(Vector2(tx, RING_Y + 4.0), sk_sel.display_name, CodexStyle.italic(), 11, sk_sel.color.lerp(CodexStyle.PAPER, 0.45))
		elif Progression.rings_stolen and Progression.rings.size() > 0:
			_txt(Vector2(tx, RING_Y + 4.0), "roubados", CodexStyle.italic(), 11, Color(0.72, 0.68, 0.76))

	## Gema facetada: losango alongado com faceta clara, faceta escura e brilho.
	func _gem(c: Vector2, s: float, col: Color, lit: bool) -> void:
		if lit:
			draw_circle(c, s * 1.7, Color(col, 0.22))
		var top := c + Vector2(0, -s)
		var right := c + Vector2(s * 0.85, 0)
		var bottom := c + Vector2(0, s)
		var left := c + Vector2(-s * 0.85, 0)
		draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), col.darkened(0.15))
		draw_colored_polygon(PackedVector2Array([top, right, c]), col.lightened(0.35))
		draw_colored_polygon(PackedVector2Array([left, top, c]), col.lightened(0.1))
		draw_colored_polygon(PackedVector2Array([left, c, bottom]), col.darkened(0.45))
		draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color(CodexStyle.GOLD_HI, 0.9), 0.6, true)
		draw_circle(c + Vector2(-s * 0.25, -s * 0.45), s * 0.16, Color(1, 1, 1, 0.9))

	func _gem_outline(c: Vector2, s: float, col: Color) -> void:
		draw_polyline(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.85, 0), c + Vector2(0, s), c + Vector2(-s * 0.85, 0), c + Vector2(0, -s)]), col, 0.7, true)

	# --- progresso do Éon (canto superior direito) -----------------------------------------
	func _draw_eon() -> void:
		# A Provação tem placar próprio no mesmo canto (codex_trial): não duplica.
		if CodexSession.active:
			return
		var title: String = hud.screen_title()
		var right: float = EON_RIGHT
		_txt(Vector2(right - 300, 15), title, CodexStyle.display(), 10, CodexStyle.PAPER, HORIZONTAL_ALIGNMENT_RIGHT, 300)
		var count := 0
		var cur := 0
		if CodexSession.active:
			count = 3
			cur = CodexSession.stage
		else:
			var off := RunManager.eon_offset(RunManager.current_screen)
			if off < 0:
				return
			count = RunManager.EON_LEN
			cur = off
		var dx := 11.0
		var y := 25.0
		var x0 := right - 3.0 - dx * (count - 1)
		# fio que liga os marcos
		for i in count - 1:
			var a := Vector2(x0 + dx * i, y)
			var b := Vector2(x0 + dx * (i + 1), y)
			draw_line(a, b, Color(CodexStyle.GOLD, 0.8) if i < cur else Color(CodexStyle.GOLD_LO, 0.55), 0.7, true)
		for i in count:
			var c := Vector2(x0 + dx * i, y)
			var boss_node := (i == count - 1)
			var trial := (not CodexSession.active and i == 4)
			var r := 3.6 if boss_node else (2.9 if trial else 2.1)
			var col: Color
			if i < cur:
				col = CodexStyle.GOLD
			elif i == cur:
				col = CodexStyle.SPARK
				var pl := 0.5 + 0.5 * sin(hud._t * 4.0)
				draw_circle(c, r + 2.5 + pl, Color(CodexStyle.GOLD_HI, 0.18))
			else:
				col = Color(0.02, 0.05, 0.07, 0.9)
			if boss_node or trial:
				CodexStyle.draw_diamond(self, c, r, col, Color(CodexStyle.GOLD_HI if i <= cur else CodexStyle.GOLD, 0.9 if i <= cur else 0.5))
				if boss_node:
					# coroinha do Arconte: três pontas acima do losango
					for k in [-1.8, 0.0, 1.8]:
						draw_line(c + Vector2(k, -r - 0.6), c + Vector2(k, -r - (2.4 if k == 0.0 else 1.6)), Color(CodexStyle.GOLD, 0.85), 0.6, true)
			else:
				draw_circle(c, r, col)
				draw_arc(c, r, 0.0, TAU, 12, Color(CodexStyle.GOLD, 0.8 if i <= cur else 0.45), 0.6, true)

	# --- chefe(s) --------------------------------------------------------------------------
	func _draw_boss() -> void:
		var vis: Array = []
		for o in hud.bosses:
			if o.show > 0.0:
				vis.append(o)
		if vis.is_empty():
			return
		vis = vis.slice(0, 2)
		if vis.size() == 1:
			_draw_one_boss(vis[0], 320.0, BOSS_W, true)
		else:
			_draw_one_boss(vis[0], 186.0, 216.0, false)
			_draw_one_boss(vis[1], 454.0, 216.0, false)

	func _draw_one_boss(bb, cx: float, w: float, solo: bool) -> void:
		# Cena no ar (rubrica/caixa/ilustração — QA2 #5): as barras recolhem junto
		# com dicas e combo; voltam quando a cena acaba.
		var a: float = bb.show * (1.0 - hud._scene_k)
		if a <= 0.01:
			return
		var x0 := cx - w * 0.5
		var y: float = BOSS_BAR_Y + (1.0 - a) * 8.0
		var rect := Rect2(x0, y, w, 8)
		var name_full: String = String(bb.node.get("display_name")) if is_instance_valid(bb.node) else bb.last_name
		bb.last_name = name_full
		var parts := I18n.t(name_full).split(",", false, 1)   # i18n: traduz o nome inteiro antes de partir
		var main_name := parts[0].strip_edges() if parts.size() > 0 else name_full
		var sub := parts[1].strip_edges() if parts.size() > 1 else ""
		var phase2: bool = bb.phase >= 2
		var phase3: bool = bb.phase >= 3
		var pf: float = bb.flash
		# Limiares de fase do chefe (chefes6: `phase_marks`, ex. [0.66, 0.33]);
		# sem a propriedade, o marcador antigo em 50 %.
		if is_instance_valid(bb.node):
			var pm = bb.node.get("phase_marks")
			if pm is Array and not (pm as Array).is_empty():
				bb.marks = (pm as Array).duplicate()
		var down: bool = bb.down
		# placa escura atrás de nome + barra (contraste sobre qualquer cenário;
		# Onda 3: mais densa — sobre chão claro/flash a barra sumia)
		var plate := Rect2(x0 - 30.0, y - 18.0, w + 52.0, 42.0)
		var steps := 12
		for i in steps:
			var t0 := float(i) / steps
			var t1 := float(i + 1) / steps
			var k0 := sin(t0 * PI)
			var k1 := sin(t1 * PI)
			var px0 := plate.position.x + plate.size.x * t0
			var px1 := plate.position.x + plate.size.x * t1
			draw_polygon(PackedVector2Array([Vector2(px0, plate.position.y), Vector2(px1, plate.position.y), Vector2(px1, plate.end.y), Vector2(px0, plate.end.y)]),
				PackedColorArray([Color(0.01, 0.025, 0.035, 0.84 * k0 * a), Color(0.01, 0.025, 0.035, 0.84 * k1 * a), Color(0.01, 0.025, 0.035, 0.84 * k1 * a), Color(0.01, 0.025, 0.035, 0.84 * k0 * a)]))
		var name_col := Color(0.62, 0.6, 0.68, a) if down else Color(CodexStyle.GOLD_HI.lerp(Color.WHITE, pf * 0.6), a)
		_txt(Vector2(x0, y - 5.0), main_name, CodexStyle.display_bold(), 12 if solo else 10, name_col, HORIZONTAL_ALIGNMENT_CENTER, w, 5)
		if down:
			# caída: barra cinza-violeta enchendo até se refazer
			_bar(rect, bb.revive_k, bb.revive_k, Color(0.3, 0.28, 0.38), Color(0.62, 0.58, 0.74), 0.0)
			var pl := 0.6 + 0.4 * sin(hud._t * 4.0)
			_txt(Vector2(x0, y + 18.0), "refazendo-se", CodexStyle.italic(), 9, Color(0.82, 0.78, 0.92, a * pl), HORIZONTAL_ALIGNMENT_CENTER, w, 3)
		else:
			# Fase I ouro vivo; fase II carmim-brasa (a identidade vermelha do HUD);
			# fase III sangue escuro com o miolo em brasa, pulsando devagar.
			var lo := Color("e3aa48")
			var hi := Color("fff2c6")
			if phase3:
				var beat := 0.5 + 0.5 * sin(hud._t * 5.0)
				lo = Color("8e1424")
				hi = Color("ff5a48").lerp(Color("ff9a6a"), beat * 0.5)
			elif phase2:
				lo = Color("c43a2e")
				hi = Color("ffb27a")
			_bar(rect, bb.ratio, bb.ghost, lo, hi, pf * 0.5)
			# trilho vazio com contorno interno escuro: o fim da vida lê de longe
			var empty_x := rect.position.x + rect.size.x * clampf(bb.ghost, 0.0, 1.0)
			if empty_x < rect.end.x - 6.0:
				draw_line(Vector2(empty_x, rect.position.y + 1.5), Vector2(rect.end.x - 5.0, rect.position.y + 1.5), Color(1, 1, 1, 0.06 * a), 1.0)
			# um marcador por limiar de fase: o j-ésimo vira brasa quando a fase j+2 chega
			for j in bb.marks.size():
				var mk := clampf(float(bb.marks[j]), 0.02, 0.98)
				var mx := rect.position.x + w * mk
				var crossed: bool = bb.phase >= j + 2
				var just: bool = bb.phase == j + 2
				var mcol := CodexStyle.EMBER.lerp(Color.WHITE, pf if just else 0.0) if crossed else CodexStyle.GOLD_HI
				draw_line(Vector2(mx, rect.position.y - 1), Vector2(mx, rect.end.y + 1), Color(0.01, 0.03, 0.04, 0.9), 1.4)
				draw_line(Vector2(mx, rect.position.y - 1), Vector2(mx, rect.end.y + 1), mcol, 0.6)
				CodexStyle.draw_diamond(self, Vector2(mx, rect.position.y - 4.0), 2.4 + (pf * 1.5 if just else 0.0), mcol, Color(0, 0, 0, 0.7))
			# linha de baixo (y+18, a 8 px da borda da tela): subtítulo centrado e
			# "FASE II" na MESMA linha, alinhado à ponta direita da barra (antes
			# descia para y+28 e saía cortado na base da tela).
			if solo and sub != "":
				_txt(Vector2(x0, y + 18.0), sub, CodexStyle.display(), 8, Color(CodexStyle.PAPER, 0.8 * a), HORIZONTAL_ALIGNMENT_CENTER, w, 3)
			if phase2:
				var fx := (x0 + w - 74.0) if solo else (x0 + w * 0.5 - 37.0)
				var ftxt := "FASE III" if phase3 else "FASE II"
				var fcol := Color("ff7a5c") if phase3 else Color("ffb070")
				_txt(Vector2(fx, y + 18.0), ftxt, CodexStyle.display_bold(), 8, Color(fcol.lerp(Color.WHITE, pf), a), HORIZONTAL_ALIGNMENT_RIGHT if solo else HORIZONTAL_ALIGNMENT_CENTER, 74.0, 3)
		# medalhão da fase à ESQUERDA da barra (longe da borda e do terminal)
		# (r 8,5 e algarismo de 7 px: o "II" respira dentro do anel, sem tocar a borda)
		var mc := Vector2(rect.position.x - 17.0, rect.position.y + 4.0)
		draw_circle(mc, 8.5, Color(0.01, 0.03, 0.04, 0.95 * a))
		var ring_col := Color(0.6, 0.58, 0.7, a) if down else (Color(CodexStyle.EMBER.lerp(Color.WHITE, pf), a) if phase2 else Color(CodexStyle.GOLD, a))
		if not down and phase3:
			ring_col = Color(Color("ff5a48").lerp(Color.WHITE, pf), a)
		draw_arc(mc, 8.5, 0.0, TAU, 24, ring_col, 1.0, true)
		draw_arc(mc, 6.6, 0.0, TAU, 24, Color(ring_col, 0.3 * a), 0.5, true)
		var mfont: Font = CodexStyle.display_bold()
		var mtxt := "I"
		if not down and phase2:
			mtxt = "III" if phase3 else "II"
		var asc := mfont.get_ascent(7) - mfont.get_descent(7)
		_txt(mc + Vector2(-10.0, asc * 0.5 - 0.5), mtxt, mfont, 7, ring_col, HORIZONTAL_ALIGNMENT_CENTER, 20.0, 2)

	# --- dica de controle (topo central) -----------------------------------------------
	func _draw_hint() -> void:
		var a: float = hud.hint_alpha()
		if a <= 0.0:
			return
		var font: Font = CodexStyle.display()
		var tfont: Font = CodexStyle.italic()
		var ks := 8
		var ts := 10
		# mede
		var items: Array = []        # [tipo, texto, largura]
		var first := true
		for seg in hud._hint:
			if not first:
				items.append(["sep", "·", 10.0])
			first = false
			for act in seg.get("keys", []):
				var used: bool = hud._hint_done.has(act)
				var gw: float = hud.glyph_width(act, HINT_ICON_H)
				if gw > 0.0:
					items.append(["icon", act, gw, used])
					continue
				var lab: String = I18n.t(hud.key_label(act))
				items.append(["key", lab, font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, ks).x + 8.0, used])
			var tx := I18n.t(String(seg.get("text", "")))
			if tx != "":
				items.append(["txt", tx, tfont.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x + 4.0])
		var total := 0.0
		for it in items:
			total += float(it[2]) + 3.0
		var x := 320.0 - total * 0.5
		var y: float = HINT_Y
		# placa que se dissolve nas pontas
		var pw := total + 40.0
		var px := 320.0 - pw * 0.5
		var steps := 10
		for i in steps:
			var t0 := float(i) / steps
			var t1 := float(i + 1) / steps
			var k0 := sin(t0 * PI)
			var k1 := sin(t1 * PI)
			var c0 := Color(0.01, 0.025, 0.035, 0.7 * k0 * a)
			var c1 := Color(0.01, 0.025, 0.035, 0.7 * k1 * a)
			draw_polygon(PackedVector2Array([Vector2(px + pw * t0, y - 9.0), Vector2(px + pw * t1, y - 9.0), Vector2(px + pw * t1, y + 9.0), Vector2(px + pw * t0, y + 9.0)]),
				PackedColorArray([c0, c1, c1, c0]))
		for it in items:
			var w: float = it[2]
			match String(it[0]):
				"key":
					var used: bool = it[3]
					var r := Rect2(x, y - 6.5, w, 13.0)
					draw_rect(r, Color(0.02, 0.05, 0.07, 0.95 * a))
					draw_rect(r, Color(CodexStyle.GOLD_HI if used else CodexStyle.GOLD, a), false, 0.8)
					_txt(Vector2(x, y + 3.0), String(it[1]), font, ks, Color(CodexStyle.GOLD_HI if used else CodexStyle.PAPER, a), HORIZONTAL_ALIGNMENT_CENTER, w, 0)
				"icon":
					var used2: bool = it[3]
					hud.draw_glyph(self, Vector2(x + w * 0.5, y), String(it[1]), HINT_ICON_H, a)
					if used2:
						# usado: filete dourado por baixo (o ícone fica com as cores dele)
						draw_line(Vector2(x + 1.0, y + 8.5), Vector2(x + w - 1.0, y + 8.5), Color(CodexStyle.GOLD_HI, a), 1.2)
				"txt":
					_txt(Vector2(x + 2.0, y + 3.5), String(it[1]), tfont, ts, Color(CodexStyle.PAPER, 0.92 * a), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)
				"sep":
					_txt(Vector2(x, y + 3.5), "·", tfont, ts, Color(CodexStyle.GOLD, a), HORIZONTAL_ALIGNMENT_CENTER, w, 0)
			x += w + 3.0

	func _draw_combo_tag() -> void:
		if hud._combo_label.text == "":
			return
		_txt(Vector2(500, 90), "golpes", CodexStyle.display(), 8, Color(CodexStyle.PAPER, 0.8 * (1.0 - hud._scene_k)), HORIZONTAL_ALIGNMENT_RIGHT, 120, 3)


## Gema solta (detach_ring): brilha, gira de leve e voa.
class _FlyingGem extends Node2D:
	var color: Color = Color.WHITE
	var lift: float = 0.0
	var spin: float = 0.0
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var s := 4.6 * (1.0 + lift * 0.9)
		draw_circle(Vector2.ZERO, s * 2.4, Color(color, 0.18 * lift))
		draw_circle(Vector2.ZERO, s * 1.4, Color(1, 1, 1, 0.25 * lift))
		var k := cos(spin * TAU * 1.5)
		var w := s * 0.85 * maxf(0.25, absf(k))
		var pts := PackedVector2Array([Vector2(0, -s), Vector2(w, 0), Vector2(0, s), Vector2(-w, 0)])
		draw_colored_polygon(pts, color.lightened(0.15))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -s), Vector2(w, 0), Vector2.ZERO]), color.lightened(0.5))
		pts.append(pts[0])
		draw_polyline(pts, Color("ecd498"), 0.7, true)


## Estado de UMA barra de chefe.
class _BossBar extends RefCounted:
	var node: Node
	var last_name: String = ""
	var ratio: float = 1.0
	var ghost: float = 1.0
	var hold: float = 0.0
	var phase: int = 1
	var marks: Array = [0.5]        # limiares de fase (fração da vida) — `phase_marks` do chefe
	var flash: float = 0.0
	var show: float = 0.0           # 0..1 (entrada/saída)
	var down: bool = false          # caiu e vai se refazer (batalha final)
	var revive_k: float = 0.0       # 0..1 até refazer-se
	var leaving: bool = false
