extends Node
## FERRAMENTA (não faz parte do jogo): BOT DE BALANCE. Joga o run inteiro
## sozinho (IA simples: persegue, bate, esquiva telegrafos, usa magias, compra
## na loja) e mede POR TELA: tempo, dano tomado e "quase-mortes" (vida < 45% →
## conta 1 morte e cura cheia, pra run nunca parar). No fim imprime a tabela
## com a curva de dificuldade e avisos (HOT = dano demais, COLD = de menos).
## Com as TRAVESSIAS (r4): sem inimigo vivo e tela ainda não limpa, o bot ANDA
## pra direita até o gatilho da próxima zona; o timeout é por ZONA parada.
## Uso: godot --headless --audio-driver Dummy --fixed-fps 60 --path . \
##          res://tools/BalanceBot.tscn -- [tela_ini] [tela_fim] [vel] [seed=N] [out=/caminho/base]
##   vel  = multiplicador de velocidade (padrão 3; Juice.speed_mult). O bot sobe
##          physics_ticks_per_second para 60×vel: o passo de física continua
##          sendo 1/60 s de jogo, e o resultado não depende de vel.
##   seed = semente do sorteio global (padrão 1). É re-semeada a CADA tela
##          (hash de seed+tela): uma mudança na tela 10 não muda o sorteio da 11.
##   loja=gasta = na loja pós-chefe, depois de arma e magias, gasta o resto em
##          +20 de vida máx. (guarda 100). Padrão (loja=classica) = só arma e
##          magias, igual às rodadas r1–r8 (comparável com o histórico).
##   loja=teto  = SIMULA a proposta P1 do docs/onda2/BALANCE.md: +20 de vida
##          máx. com preço crescente 60×(n+1) e no máximo 10 compras.
##   ia=2 = bot "v2" (Onda 2): além do clássico, SAI de poça hostil (veneno de
##          Belias) e ESQUIVA de projétil que vem na direção dele. Ainda não
##          bloqueia nem faz parry. Padrão ia=1 = clássico (r1–r8).
##   sim=poca = SIMULA a proposta P3: poças hostis não somam — no máximo 1 tique
##          de "zona" a cada 0,7 s (o bot devolve a vida do tique extra e não conta).
##   tempo=legado = reproduz o tempo das r1–r8 (bot no _process, botão solto
##          em tempo real, física com passo de vel/60 s). NÃO use para medir:
##          em vel 8 a física roda a 7,5 Hz e o dano sai ~2,4x maior (r8, 17/10).
##   out  = base dos arquivos de saída (gera <base>.txt e <base>.csv); padrão
##          user://balance. O .csv tem uma linha por tela e o dano por FONTE.
## DETERMINISMO (Onda 2): rode SEMPRE com --fixed-fps 60 — sem isso o delta
## segue o relógio real e duas rodadas na mesma máquina divergem.
## Comparar rodadas: tools/balance/run.sh e tools/balance/compare.py.

func _ready() -> void:
	var w := BalanceWorker.new()
	w.last_screen = RunManager.MAX_SCREEN
	var pos: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			w.base_seed = int(a.substr(5))
		elif a.begins_with("loja="):
			w.shop_mode = a.substr(5)
		elif a == "sim=poca":
			w.sim_pool = true
		elif a == "tempo=legado":
			w.legacy_timing = true
		elif a.begins_with("ia="):
			w.ai_level = int(a.substr(3))
		elif a.begins_with("out="):
			w.out_base = a.substr(4)
		else:
			pos.append(a)
	if pos.size() >= 1:
		w.first_screen = int(pos[0])
	if pos.size() >= 2:
		w.last_screen = int(pos[1])
	if pos.size() >= 3:
		w.speed = float(pos[2])
	get_tree().root.add_child.call_deferred(w)


class BalanceWorker extends Node:
	var first_screen: int = 1
	var last_screen: int = 68
	var speed: float = 3.0
	var base_seed: int = 1
	var out_base: String = "user://balance"
	var ai_level: int = 1                # 1 = clássico (r1–r8); 2 = sai de poça e esquiva tiro
	var legacy_timing: bool = false      # tempo=legado: física grossa das r1–r8 (vel 8 = passo de 0,13 s)
	var sim_pool: bool = false           # sim=poca (proposta P3)
	var _zone_tick_t: float = -9.0
	var _run_t: float = 0.0              # tempo de jogo total (s)       # último tique de poça contado (sim=poca)
	var _blocked: bool = false           # diálogo/loja abertos neste quadro
	var shop_mode: String = "classica"   # "classica" (r1–r8) ou "gasta" (+vida máx.)

	const ZONE_TIMEOUT := 100.0        # s de jogo numa zona sem limpar = travada
	const LOW_HP := 0.45               # abaixo disso: conta morte e cura cheia
	                                   # (alto o bastante pra um golpe não matar
	                                   # o medidor antes da cura — morte real ainda
	                                   # encerra o run e aparece no relatório)
	var _idle_clear: float = 0.0       # s com a tela limpa sem conseguir avançar
	var _zone_t: float = 0.0           # s na zona atual (timeout por zona)
	var _zone_cur: int = -2            # zona em andamento (detecta troca)
	var _zones: int = 1                # zonas da tela atual (pro relatório)

	var _cur: int = -1
	var _rows: Array = []              # {screen, time, dmg, deaths, timeout}
	var _t: float = 0.0
	var _dmg: int = 0
	var _deaths: int = 0
	var _timeout: bool = false
	var _last_hp: int = -1
	var _atk_t: float = 0.0
	var _atk_i: int = 0
	var _dodge_cd: float = 0.0
	var _cast_t: float = 0.0
	var _done: bool = false
	var _beat: float = 0.0             # heartbeat de progresso no stdout
	# Dano por FONTE (quem bateu): type_id do inimigo, "projetil" (tiro sem
	# dono) ou "zona" (dano sem golpe: poça/veneno de Arconte).
	var _src: Dictionary = {}          # fonte -> dano na tela atual
	var _src_total: Dictionary = {}    # fonte -> dano no run inteiro
	var _hit_label: String = ""        # quem acertou neste quadro
	var _pend: int = 0                 # dano visto neste quadro (atribui no _process)
	var _hp_seen: int = -1
	var _watched_id: int = 0           # instance_id do player com sinais ligados
	var _boss: String = ""             # chefe/campeão visto na tela (relatório)
	var _hits: int = 0                 # golpes que tiraram vida na tela
	var _maxhit: int = 0               # maior golpe único na tela
	var _mhp: int = 0                  # vida máxima ao entrar na tela
	var _hp_buys: int = 0              # compras de +vida (loja=teto)
	var _earned: int = 0               # faíscas ganhas na tela
	var _orbs_seen: int = 0
	var _zones_hz: Array = []          # poças/zonas vivas (IA v2 sai de cima)
	var _projs: Array = []             # projéteis hostis vivos, marcados com quem atirou
	# padrão de golpes do bot: mistura strings reais (LLL, LLH, HH, LLLH)
	const PATTERN := ["light", "light", "light", "heavy", "light", "light", "heavy", "heavy", "heavy"]

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false   # ferramenta não suja o save real
		Juice.speed_mult = speed
		if not legacy_timing:
			# Acelerar SEM engrossar a física: o Godot 4 não aumenta os passos de
			# física com time_scale (só o delta). Então sobe os passos por segundo
			# junto: cada passo continua sendo 1/60 s de jogo (igual ao jogo real).
			Engine.physics_ticks_per_second = int(round(60.0 * speed))
			Engine.max_physics_steps_per_frame = maxi(8, int(ceil(speed)) + 1)
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")      # ferramenta pula o prólogo em cards
		Gnosis.persist_enabled = false   # e não grava Crônicas no disco
		RunManager.current_screen = first_screen
		GameManager.current_screen = first_screen
		# Sorteio determinístico POR TELA (o jogo usa randf/randi globais).
		_reseed(first_screen)
		RunManager.screen_changed.connect(_reseed)
		get_tree().node_added.connect(_on_node_added)
		_orbs_seen = Progression.orbs
		Progression.orbs_changed.connect(_on_orbs)
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func _process(delta: float) -> void:
		if _done:
			return
		# heartbeat: prova de vida no stdout a cada ~5 s reais
		_beat += delta / maxf(0.1, Engine.time_scale)
		if _beat > 5.0:
			_beat = 0.0
			var php := -1
			var pn := get_tree().get_first_node_in_group("player")
			if pn != null and pn.health != null:
				php = pn.health.current_health
			print("BAT tela=%d t=%.0fs dmg=%d hp=%d cena=%s" % [RunManager.current_screen, _t, _dmg, php, str(get_tree().current_scene)])
		# 1) pula diálogos (escolha padrão = Recusar / 1º final)
		var had_dialog := false
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()
				had_dialog = true
		_blocked = had_dialog
		if had_dialog:
			return
		# 2) loja pós-chefe: compra o que der (emula progressão real) e fecha
		var cs := get_tree().current_scene
		if cs == null:
			return
		for c in cs.get_children():
			if c is CanvasLayer and c.has_method("_close"):
				_blocked = true
				_auto_shop()
				c._close()
				return
		_blocked = false
		# 3) fim do run (vitória ou passou da última tela pedida)
		if not RunManager.run_active or RunManager.current_screen > last_screen:
			_finish("fim do run (tela %d)" % RunManager.current_screen)
			return
		if legacy_timing:
			_tick(delta)

	## Física: o bot joga e mede a cada passo de física (1/60 s de JOGO em
	## qualquer velocidade). No modo legado (r1–r8) isso rodava no _process.
	func _physics_process(delta: float) -> void:
		if _done or _blocked or legacy_timing:
			return
		if not RunManager.run_active or RunManager.current_screen > last_screen:
			return
		_tick(delta)

	func _tick(delta: float) -> void:
		var pl: Player = get_tree().get_first_node_in_group("player")
		if pl == null or pl.health == null:
			return
		_watch(pl)
		_attribute()
		# 4) troca de tela: fecha a linha anterior
		if RunManager.current_screen != _cur:
			_flush_row()
			_cur = RunManager.current_screen
			_mhp = pl.health.max_health
			_last_hp = pl.health.current_health
			_zone_cur = -2
			_zone_t = 0.0
		_t += delta
		_run_t += delta
		var lv0 := get_tree().current_scene
		if lv0 is Level:
			_zones = maxi(1, lv0.zones.size())
			if lv0.zone_index != _zone_cur:
				_zone_cur = lv0.zone_index
				_zone_t = 0.0
		_zone_t += delta
		# 5) medição de dano/quase-morte
		var hp := pl.health.current_health
		if hp < _last_hp:
			_dmg += _last_hp - hp
		_last_hp = hp
		if pl.state != Player.State.DEAD and hp < int(pl.health.max_health * LOW_HP):
			_deaths += 1
			pl.health.heal(pl.health.max_health)
			_last_hp = pl.health.current_health
		# 6) timeout da ZONA: mata o que está vivo (uma vez) pra seguir medindo
		# as outras zonas/telas. (SEM return: o bot ainda precisa andar depois.)
		if _zone_t > ZONE_TIMEOUT:
			_zone_t = 0.0
			_timeout = true
			print("BAT TIMEOUT na tela %d zona %d — matando a zona" % [_cur, _zone_cur])
			# Diagnóstico: quem estava vivo e onde (pra achar stalls determinísticos).
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e) and e.estate != Enemy.EState.DEAD:
					print("BAT   vivo: %s hp=%d pos=(%.0f,%.0f) estado=%s range=%.0f cd=%.2f" % [e.type_id, e.health.current_health, e.global_position.x, e.global_position.y, Enemy.EState.keys()[e.estate], e.attack_range, e.cooldown_timer])
					e._on_hit_received(e.health.max_health + 9999, pl.global_position, 10.0, false, null)
			print("BAT   player: pos=(%.0f,%.0f) estado=%s cd=%.2f chao=%s" % [pl.global_position.x, pl.global_position.y, Player.State.keys()[pl.state], pl.attack_cd, str(pl.is_on_floor())])
		_drive(pl, delta)

	## A "mão" do bot: anda até o inimigo mais perto, bate, esquiva, conjura.
	func _drive(pl: Player, delta: float) -> void:
		_dodge_cd = maxf(0.0, _dodge_cd - delta)
		_cast_t += delta
		var target: Enemy = null
		var best := INF
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or not e is Enemy or e.estate == Enemy.EState.DEAD:
				continue
			var d: float = absf(e.global_position.x - pl.global_position.x)
			if d < best:
				best = d
				target = e
		if target == null:
			Input.action_release("move_left")
			Input.action_release("move_right")
			var lv := get_tree().current_scene
			# Tela limpa: anda até a fenda (se existir, o bot "entra" nela).
			for c in lv.get_children():
				if c is ExitPortal:
					pl.global_position = c.global_position + Vector2(0, -20)
			# Travessia: ainda há zonas à frente → ANDA pra direita até o gatilho.
			var zones_left: bool = lv is Level and not lv.zone_active and lv.zone_index + 1 < lv.zones.size()
			if zones_left:
				Input.action_press("move_right")
			_idle_clear += delta
			if zones_left and _idle_clear > 25.0:
				# Rede de segurança: preso no caminho → salta pro gatilho da zona.
				print("BAT zona forcada (tela %d, bot preso em x=%.0f)" % [_cur, pl.global_position.x])
				_idle_clear = 0.0
				pl.global_position = Vector2(lv.zone_center(lv.zone_index + 1) - Level.ZONE_TRIGGER + 8.0, 250.0)
			elif not zones_left and _idle_clear > 14.0 and lv is Level and lv.has_method("_advance_via_exit"):
				# Rede de segurança: limpa há tempo demais sem avançar → força a saída.
				print("BAT avanco forcado (tela %d presa limpa)" % _cur)
				_idle_clear = 0.0
				lv._advance_via_exit()
			return
		_idle_clear = 0.0
		if ai_level >= 2 and _evade(pl):
			return
		var dx := target.global_position.x - pl.global_position.x
		# esquiva quando o golpe está armado perto (telegrafo)
		if _dodge_cd <= 0.0 and target.estate == Enemy.EState.WINDUP and absf(dx) < 150.0:
			Input.action_press("dodge")
			_release_later("dodge")
			_dodge_cd = 1.4
			return
		# aproxima
		if absf(dx) > 60.0:
			Input.action_release("move_left" if dx > 0 else "move_right")
			Input.action_press("move_right" if dx > 0 else "move_left")
		else:
			Input.action_release("move_left")
			Input.action_release("move_right")
			# vira pro alvo com um toquinho de direção
			if signf(dx) != float(pl.facing) and dx != 0.0:
				var a := "move_right" if dx > 0 else "move_left"
				Input.action_press(a)
				_release_later(a)
		# magias: Esfera Solar quando sobra Éter; o Anel equipado de vez em quando
		if _cast_t > 3.0 and pl.mana >= 24.0:
			_cast_t = 0.0
			Input.action_press("skill2")
			_release_later("skill2")
		# golpes em cadência
		_atk_t += delta
		if absf(dx) < 90.0 and _atk_t > 0.30:
			_atk_t = 0.0
			var btn: String = PATTERN[_atk_i % PATTERN.size()]
			_atk_i += 1
			var act := "attack_light" if btn == "light" else "attack_heavy"
			Input.action_press(act)
			_release_later(act)

	func _on_orbs(total: int) -> void:
		if total > _orbs_seen:
			_earned += total - _orbs_seen
		_orbs_seen = total

	## Re-semeia o sorteio global a cada tela nova (chamado pelo screen_changed,
	## antes da cena da tela nascer).
	func _reseed(screen: int) -> void:
		seed(hash("gnosis-balance-%d-%d" % [base_seed, screen]))

	## Liga os sinais do player desta tela (cada tela recria o player).
	func _watch(pl: Player) -> void:
		if _watched_id == pl.get_instance_id():
			return
		_watched_id = pl.get_instance_id()
		_hp_seen = pl.health.current_health
		_hit_label = ""
		_pend = 0
		pl.hurtbox.hit_received.connect(_on_player_hit)
		pl.health.health_changed.connect(_on_player_hp)

	func _on_player_hit(_dmg: int, pos: Vector2, _kb: float, _unbl: bool, attacker: Node) -> void:
		if attacker != null and is_instance_valid(attacker) and attacker is Enemy:
			_hit_label = str(attacker.type_id)
			return
		# Sem dono: projétil. Acha o tiro nessa posição e quem o disparou.
		_hit_label = "projetil"
		var best := 40.0
		for pj in _projs:
			if is_instance_valid(pj) and pj.has_meta("bal_src"):
				var d: float = pj.global_position.distance_to(pos)
				if d < best:
					best = d
					_hit_label = "%s(tiro)" % str(pj.get_meta("bal_src"))

	## Todo projétil hostil que nasce é marcado (no quadro seguinte, quando já
	## tem posição) com o inimigo mais perto — quem atirou.
	func _on_node_added(n: Node) -> void:
		if n is Projectile:
			_tag_projectile.call_deferred(n)
		elif n is HazardZone:
			_zones_hz.append(n)

	func _tag_projectile(pj: Projectile) -> void:
		if not is_instance_valid(pj) or pj.target_team != "player":
			return
		var best := INF
		var who := "?"
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and e is Enemy:
				var d: float = e.global_position.distance_to(pj.global_position)
				if d < best:
					best = d
					who = str(e.type_id)
		pj.set_meta("bal_src", who)
		_projs = _projs.filter(func(x): return is_instance_valid(x))
		_projs.append(pj)

	func _on_player_hp(cur: int, _mx: int) -> void:
		if _hp_seen >= 0 and cur < _hp_seen:
			_pend += _hp_seen - cur
			_hits += 1
			_maxhit = maxi(_maxhit, _hp_seen - cur)
		_hp_seen = cur

	## Fecha o quadro: o dano visto vai para quem acertou (ou "zona").
	func _attribute() -> void:
		if _pend > 0 and sim_pool and _hit_label == "":
			# P3 simulada: tique de poça a menos de 0,7 s do anterior não fere.
			if _run_t - _zone_tick_t < 0.65:
				var pl := get_tree().get_first_node_in_group("player")
				if pl != null and pl.health != null:
					pl.health.heal(_pend)
					_last_hp = pl.health.current_health
					_hp_seen = _last_hp
				_pend = 0                  # nunca entrou no _dmg (medido depois)
			else:
				_zone_tick_t = _run_t
		if _pend > 0:
			var k: String = _hit_label if _hit_label != "" else "zona"
			_src[k] = int(_src.get(k, 0)) + _pend
			_src_total[k] = int(_src_total.get(k, 0)) + _pend
		_pend = 0
		_hit_label = ""
		if _boss == "":
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e) and e is Enemy and (e.is_boss_enemy or e.is_champion):
					_boss = str(e.type_id)
					break

	## IA v2: o que um humano faz sem pensar. Retorna true se usou o quadro.
	func _evade(pl: Player) -> bool:
		# 1) Projétil hostil vindo na minha direção, perto → rola (i-frames).
		if _dodge_cd <= 0.0:
			for pj in _projs:
				if not is_instance_valid(pj):
					continue
				var rel: Vector2 = pl.global_position - pj.global_position
				if absf(rel.x) < 85.0 and absf(rel.y) < 50.0 and signf(rel.x) == signf(float(pj.direction)):
					Input.action_press("dodge")
					_release_later("dodge")
					_dodge_cd = 1.0
					return true
		# 2) Em cima de poça hostil (dano contínuo) → anda para fora.
		_zones_hz = _zones_hz.filter(func(x): return is_instance_valid(x))
		var px: float = pl.global_position.x
		if not _in_pool(px, pl.global_position.y):
			return false
		# Procura o chão livre mais perto (as poças da Praga fazem rastro e se
		# sobrepõem): varre para os dois lados e anda para o lado mais curto.
		var go := ""
		for step in range(1, 80):
			var d := float(step) * 10.0
			if not _in_pool(px + d, pl.global_position.y):
				go = "move_right"
				break
			if not _in_pool(px - d, pl.global_position.y):
				go = "move_left"
				break
		if go == "":
			return false                 # chão todo tomado: segue lutando
		Input.action_release("move_left" if go == "move_right" else "move_right")
		Input.action_press(go)
		return true

	func _in_pool(x: float, y: float) -> bool:
		for hz in _zones_hz:
			if not is_instance_valid(hz) or hz.hostile_to != "player" or hz.kind == "sleep":
				continue
			if absf(x - hz.global_position.x) <= hz.radius + 12.0 and absf(y - hz.global_position.y) < 60.0:
				return true
		return false

	func _release_later(a: String) -> void:
		if legacy_timing:
			await get_tree().create_timer(0.05, true, false, true).timeout   # 0,05 s REAIS
		else:
			await get_tree().create_timer(0.05, true, true, false).timeout   # 0,05 s de JOGO
		Input.action_release(a)

	func _auto_shop() -> void:
		if Progression.can_upgrade_weapon():
			Progression.upgrade_weapon()
		var ch: CharacterData = GameManager.selected_character
		if ch != null:
			for sk in ch.skills:
				if Progression.is_skill_unlocked(sk.id) and Progression.skill_level(sk.id) < sk.max_level \
						and Progression.orbs >= Progression.skill_upgrade_cost(sk.id) + 150:
					Progression.upgrade_skill(sk)
		if shop_mode == "teto":
			# Proposta P1 (simulada só no bot): preço sobe a cada compra, teto 10.
			while _hp_buys < 10 and Progression.orbs >= 60 * (_hp_buys + 1) + 100:
				if not Progression.buy_max_health(20, 60 * (_hp_buys + 1)):
					break
				_hp_buys += 1
		if shop_mode == "gasta":
			# Jogador "gastador": converte a sobra em vida máxima (preço fixo 60).
			while Progression.orbs >= 60 + 100:
				if not Progression.buy_max_health(20, 60):
					break

	func _flush_row() -> void:
		if _cur > 0:
			_rows.append({"screen": _cur, "time": _t, "dmg": _dmg, "deaths": _deaths, "timeout": _timeout, "zones": _zones,
				"src": _src.duplicate(), "boss": _boss, "hits": _hits, "maxhit": _maxhit,
				"earned": _earned, "orbs": Progression.orbs, "maxhp": _mhp})
		_earned = 0
		_src = {}
		_boss = ""
		_hits = 0
		_maxhit = 0
		_t = 0.0
		_dmg = 0
		_deaths = 0
		_timeout = false
		_zones = 1

	func _finish(reason: String) -> void:
		_done = true
		_flush_row()
		var lines: Array[String] = []
		lines.append("BALANCE — %s | arma final nv.%d | faíscas sobrando %d" % [reason, Progression.weapon_level, Progression.orbs])
		lines.append("tela | zonas | tempo(s) | dano | mortes | avisos")
		var tot_t := 0.0
		var tot_d := 0
		var tot_m := 0
		for r in _rows:
			var warn := ""
			if r.timeout: warn += " TIMEOUT"
			if r.dmg >= 70: warn += " HOT"
			elif r.dmg <= 3 and r.screen > 3: warn += " COLD"
			if r.time > 45.0 + 60.0 * float(r.zones) and not r.timeout: warn += " SLOW"
			lines.append("%4d | %5d | %8.1f | %4d | %6d |%s" % [r.screen, r.zones, r.time, r.dmg, r.deaths, warn])
			tot_t += r.time
			tot_d += int(r.dmg)
			tot_m += int(r.deaths)
		lines.append("TOTAL: %.1f min de jogo | %d de dano | %d mortes" % [tot_t / 60.0, tot_d, tot_m])
		# Dano por fonte no run inteiro (maiores primeiro).
		var keys: Array = _src_total.keys()
		keys.sort_custom(func(a, b): return int(_src_total[a]) > int(_src_total[b]))
		var parts: Array[String] = []
		for k in keys:
			parts.append("%s=%d" % [k, int(_src_total[k])])
		lines.append("FONTES: " + ", ".join(parts))
		lines.append("seed=%d vel=%.1f telas %d-%d loja=%s ia=%d tempo=%s" % [base_seed, speed, first_screen, last_screen, shop_mode, ai_level, "legado" if legacy_timing else "fisica"])
		var f := FileAccess.open(out_base + ".txt", FileAccess.WRITE)
		for l in lines:
			print("BAL ", l)
			if f:
				f.store_line(l)
		if f:
			f.close()
		_write_csv()
		get_tree().quit()

	## CSV por tela (para tools/balance/compare.py): fontes como "id:dano;id:dano".
	func _write_csv() -> void:
		var f := FileAccess.open(out_base + ".csv", FileAccess.WRITE)
		if f == null:
			print("BAL (sem CSV: não abriu %s.csv)" % out_base)
			return
		f.store_line("screen,zones,time,dmg,deaths,timeout,hits,maxhit,boss,earned,orbs,maxhp,sources")
		for r in _rows:
			var src: Dictionary = r.src
			var ks: Array = src.keys()
			ks.sort_custom(func(a, b): return int(src[a]) > int(src[b]))
			var parts: Array[String] = []
			for k in ks:
				parts.append("%s:%d" % [k, int(src[k])])
			f.store_line("%d,%d,%.1f,%d,%d,%d,%d,%d,%s,%d,%d,%d,%s" % [r.screen, r.zones, r.time, r.dmg, r.deaths,
				1 if r.timeout else 0, r.hits, r.maxhit, r.boss, r.earned, r.orbs, r.maxhp, ";".join(parts)])
		f.close()
