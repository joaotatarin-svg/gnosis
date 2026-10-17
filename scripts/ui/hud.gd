extends CanvasLayer
## HUD do GNOSIS — tudo desenhado por código (sem texturas de interface):
##   · medalhão da Sophia (retrato pintado num anel de ouro; pulsa em brasa com vida baixa)
##   · barras de Vida e Éter com moldura e BARRA FANTASMA (o dano some devagar)
##   · faíscas com ícone (contagem sobe animada) e nível da arma (cajado + 5 losangos)
##   · os 7 ANÉIS como gemas na cor de cada Arconte: vazio (encaixe apagado),
##     equipado (gema acesa + halo), roubado (encaixe rachado, cinza)
##   · progresso do Éon (canto direito): 9 marcos ligados por um fio
##   · barra do CHEFE na base: nome em versalete, marcador de fase em 50 %,
##     medalhão I/II à esquerda; até DUAS barras lado a lado (batalha final:
##     Rei e Colosso, cada uma com a vida e a FASE do seu chefe; quem cai e vai
##     se refazer mostra "refazendo-se" com a barra cinza enchendo)
## Fala com o jogo pelo grupo "hud": show_boss(e), boss_phase(n[, chefe]),
## toast(msg), boss_area_top() (a legenda usa para ficar acima da barra).
## API da encenação (Onda 2): ring_dot_global_pos(i), ring_dot_world_pos(i),
## detach_ring(i, alvo) — a gema salta do encaixe e voa (sinal ring_detach_finished).

signal ring_detach_finished(index: int)

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

var _canvas: _HudCanvas
var _combo_label: Label
var _toast: Control
var _toast_label: Label
var _toast_tween: Tween
var _recede: float = 0.0             # 0..1: HUD recolhido (card de chefe da Cinemática)

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
var weapon: int = 1
var _weapon_flash: float = 0.0

# anéis
var ring_skills: Array = []         # SkillData na ordem dos Arcontes
var _ring_pop: Array[float] = []    # animação de ganho por anel
var _detached: Dictionary = {}      # índice -> true enquanto a gema está fora

# chefes (até 2 barras; ver _BossBar)
var bosses: Array = []               # [_BossBar] na ordem em que nasceram
var boss: Node = null                # o 1º chefe vivo (compatibilidade)

var _t: float = 0.0
var _portrait: Texture2D


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


func _process(delta: float) -> void:
	_update_recede(delta)
	if get_tree().paused:
		return
	_t += delta
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
	# Faíscas: o número corre até o total.
	if sparks_shown != float(sparks):
		var step := maxf(1.0, absf(float(sparks) - sparks_shown) * delta * 6.0)
		sparks_shown = move_toward(sparks_shown, float(sparks), step)
	_spark_pulse = maxf(0.0, _spark_pulse - delta * 2.5)
	_weapon_flash = maxf(0.0, _weapon_flash - delta * 1.5)
	for i in _ring_pop.size():
		_ring_pop[i] = maxf(0.0, _ring_pop[i] - delta * 1.8)
	_process_bosses(delta)
	_canvas.queue_redraw()


# --- sinais do jogo ------------------------------------------------------------

func _on_hp(current: int, maximum: int) -> void:
	var before := hp
	hp = float(current)
	hp_max = float(maxi(1, maximum))
	if hp < before:
		_hp_hold = 0.45
		_hp_flash = 1.0


func _on_mp(current: int, maximum: int) -> void:
	mp = float(current)
	mp_max = float(maxi(1, maximum))


func _on_sparks(total: int) -> void:
	if total > sparks:
		_spark_pulse = 1.0
	sparks = total


func _on_weapon(level: int) -> void:
	if level > weapon:
		_weapon_flash = 1.0
	weapon = level


func _on_rings_changed() -> void:
	for i in ring_skills.size():
		var sk: SkillData = ring_skills[i]
		if Progression.ring_usable(sk.ring) and not bool(_canvas.last_usable.get(i, false)):
			_ring_pop[i] = 1.0
	_detached.clear()


func _on_combo(count: int) -> void:
	if count < 2:
		_combo_label.text = ""
		return
	_combo_label.text = str(count)
	_combo_label.scale = Vector2(1.25, 1.25)
	var t := create_tween()
	t.tween_property(_combo_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- API pública ------------------------------------------------------------------

## Aviso curto (cacos de memória, Crônicas, quedas na batalha final) numa
## faixa própria (TOAST_RECT). Texto longo encolhe a fonte para caber.
func toast(msg: String) -> void:
	if _toast == null:
		_toast = Control.new()
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast.position = TOAST_RECT.position
		_toast.size = TOAST_RECT.size
		add_child(_toast)
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
	while fs > 9 and font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > TOAST_RECT.size.x - 8.0:
		fs -= 1
	_toast_label.add_theme_font_size_override("font_size", fs)
	_toast_label.text = msg
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate = Color(1, 1, 1, 0)
	_toast.position.y = TOAST_RECT.position.y + 6.0
	_toast_tween = create_tween().set_parallel(true)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.22)
	_toast_tween.tween_property(_toast, "position:y", TOAST_RECT.position.y, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(2.2)
	_toast_tween.chain().tween_property(_toast, "modulate:a", 0.0, 0.5)


## Card de chefe / cards da Cinemática na tela: o HUD inteiro recua (some em
## 0,2 s) para a tarja não cortar a barra de vida ao meio (QA-UX M4).
func _update_recede(delta: float) -> void:
	var want := 0.0
	for c in get_tree().root.get_children():
		if c is Cinematic and not c.is_queued_for_deletion():
			want = 1.0
			break
	_recede = move_toward(_recede, want, delta * 5.0)
	var a := 1.0 - _recede
	_canvas.modulate.a = a
	_combo_label.modulate.a = a
	if _toast != null:
		_toast.visible = _recede < 0.99


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
	Audio.play_sfx("ring_steal")
	return dur


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


## Rótulo do papel da tela ("Fome · Travessia I") ou da Provação.
func screen_title() -> String:
	if CodexSession.active:
		return "Provação"
	return GameManager.screen_title(RunManager.current_screen)


# =====================================================================================
## A tela de desenho do HUD (um único Control; tudo em _draw).
class _HudCanvas extends Control:
	var hud
	var last_usable: Dictionary = {}

	func _draw() -> void:
		_draw_medal()
		_draw_bars()
		_draw_counters()
		_draw_rings()
		_draw_eon()
		_draw_boss()
		_draw_combo_tag()

	# --- texto com contorno -----------------------------------------------------------
	func _txt(pos: Vector2, s: String, font: Font, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, outline: int = 4) -> void:
		if outline > 0:
			draw_string_outline(font, pos, s, align, width, size, outline, Color(0.01, 0.03, 0.04, 0.85 * col.a))
		draw_string(font, pos, s, align, width, size, col)

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
		_txt(Vector2(71, y + 4.0), str(int(round(hud.sparks_shown))), CodexStyle.body_bold(), 12, CodexStyle.SPARK.lerp(Color.WHITE, p))
		# arma: um cajado com gema + 5 losangos de nível
		var x0 := 118.0
		var wf: float = hud._weapon_flash
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
			var usable: bool = Progression.ring_usable(sk.ring) and not hud._detached.has(i)
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
		var a: float = bb.show
		var x0 := cx - w * 0.5
		var y: float = BOSS_BAR_Y + (1.0 - a) * 8.0
		var rect := Rect2(x0, y, w, 7)
		var name_full: String = String(bb.node.get("display_name")) if is_instance_valid(bb.node) else bb.last_name
		bb.last_name = name_full
		var parts := name_full.split(",", false, 1)
		var main_name := parts[0].strip_edges() if parts.size() > 0 else name_full
		var sub := parts[1].strip_edges() if parts.size() > 1 else ""
		var phase2: bool = bb.phase >= 2
		var pf: float = bb.flash
		var down: bool = bb.down
		# placa escura atrás de nome + barra (contraste sobre qualquer cenário)
		var plate := Rect2(x0 - 26.0, y - 17.0, w + 44.0, 41.0)
		var steps := 12
		for i in steps:
			var t0 := float(i) / steps
			var t1 := float(i + 1) / steps
			var k0 := sin(t0 * PI)
			var k1 := sin(t1 * PI)
			var px0 := plate.position.x + plate.size.x * t0
			var px1 := plate.position.x + plate.size.x * t1
			draw_polygon(PackedVector2Array([Vector2(px0, plate.position.y), Vector2(px1, plate.position.y), Vector2(px1, plate.end.y), Vector2(px0, plate.end.y)]),
				PackedColorArray([Color(0.01, 0.025, 0.035, 0.62 * k0 * a), Color(0.01, 0.025, 0.035, 0.62 * k1 * a), Color(0.01, 0.025, 0.035, 0.62 * k1 * a), Color(0.01, 0.025, 0.035, 0.62 * k0 * a)]))
		var name_col := Color(0.62, 0.6, 0.68, a) if down else Color(CodexStyle.GOLD_HI.lerp(Color.WHITE, pf * 0.6), a)
		_txt(Vector2(x0, y - 5.0), main_name, CodexStyle.display_bold(), 12 if solo else 10, name_col, HORIZONTAL_ALIGNMENT_CENTER, w, 5)
		if down:
			# caída: barra cinza-violeta enchendo até se refazer
			_bar(rect, bb.revive_k, bb.revive_k, Color(0.3, 0.28, 0.38), Color(0.62, 0.58, 0.74), 0.0)
			var pl := 0.6 + 0.4 * sin(hud._t * 4.0)
			_txt(Vector2(x0, y + 18.0), "refazendo-se", CodexStyle.italic(), 9, Color(0.82, 0.78, 0.92, a * pl), HORIZONTAL_ALIGNMENT_CENTER, w, 3)
		else:
			var lo := CodexStyle.EMBER.darkened(0.3) if phase2 else Color("9a7a3c")
			var hi := Color("ffb070") if phase2 else Color("f2d690")
			_bar(rect, bb.ratio, bb.ghost, lo, hi, pf * 0.5)
			# marcador de fase em 50 %
			var mx := rect.position.x + w * 0.5
			var mcol := CodexStyle.EMBER.lerp(Color.WHITE, pf) if phase2 else CodexStyle.GOLD_HI
			draw_line(Vector2(mx, rect.position.y - 1), Vector2(mx, rect.end.y + 1), Color(0.01, 0.03, 0.04, 0.9), 1.4)
			draw_line(Vector2(mx, rect.position.y - 1), Vector2(mx, rect.end.y + 1), mcol, 0.6)
			CodexStyle.draw_diamond(self, Vector2(mx, rect.position.y - 4.0), 2.4 + pf * 1.5, mcol, Color(0, 0, 0, 0.7))
			# linha de baixo: subtítulo (só com um chefe) e "FASE II" do lado de dentro
			if solo and sub != "":
				_txt(Vector2(x0, y + 18.0), sub, CodexStyle.display(), 8, Color(CodexStyle.PAPER, 0.75 * a), HORIZONTAL_ALIGNMENT_CENTER, w, 3)
			if phase2:
				var fx := (x0 + w - 74.0) if solo else (x0 + w * 0.5 - 37.0)
				var fy := y + (28.0 if solo and sub != "" else 18.0)
				_txt(Vector2(fx, fy), "FASE II", CodexStyle.display_bold(), 8, Color(Color("ffb070").lerp(Color.WHITE, pf), a), HORIZONTAL_ALIGNMENT_RIGHT if solo else HORIZONTAL_ALIGNMENT_CENTER, 74.0, 3)
		# medalhão da fase à ESQUERDA da barra (longe da borda e do terminal)
		var mc := Vector2(rect.position.x - 15.0, rect.position.y + 3.5)
		draw_circle(mc, 7.0, Color(0.01, 0.03, 0.04, 0.92 * a))
		var ring_col := Color(0.6, 0.58, 0.7, a) if down else (Color(CodexStyle.EMBER.lerp(Color.WHITE, pf), a) if phase2 else Color(CodexStyle.GOLD, a))
		draw_arc(mc, 7.0, 0.0, TAU, 20, ring_col, 1.0, true)
		_txt(mc + Vector2(-10.0, 3.2), "II" if phase2 and not down else "I", CodexStyle.display_bold(), 8, ring_col, HORIZONTAL_ALIGNMENT_CENTER, 20.0, 2)

	func _draw_combo_tag() -> void:
		if hud._combo_label.text == "":
			return
		_txt(Vector2(500, 90), "golpes", CodexStyle.display(), 8, Color(CodexStyle.PAPER, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, 120, 3)


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
	var flash: float = 0.0
	var show: float = 0.0           # 0..1 (entrada/saída)
	var down: bool = false          # caiu e vai se refazer (batalha final)
	var revive_k: float = 0.0       # 0..1 até refazer-se
	var leaving: bool = false
