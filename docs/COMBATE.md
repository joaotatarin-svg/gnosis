# COMBATE — sensação de golpe, câmera e juice (Diretor de Game Design & Combate)

Branch `dir/combate` (base `integracao/onda1`). Base científica:
`C:\gnosis-wt\_caps\neuro\NEURO_SATISFACAO.md` (R1–R22). Números abaixo vêm de lá
e ficam em **constantes nomeadas no topo de cada arquivo** (ajuste fino no playtest do João).

---

## ESTADO (17/10/2026, Onda 2 na nuvem — branch `dir2/combate`)

**Feito e commitado (Fase A + Fase B):**
1. Câmera §2 aplicada (`camera_shake.gd`): look-ahead/enquadramento no alvo, trava
   `SAFE_MARGIN`, zoom 1,2, pés a 76 %, tremor por ruído contínuo, chute direcional, limites
   novos entram deslizando (`LIMIT_GLIDE`), `snap()`. Segue o corpo no `_physics_process`.
   Sonda telas 3/8/10/22/50: **antes** `fora=1 borda=16 minx=-1` (10: 0/0) → **depois**
   `fora=0 borda=0 minx=38` em todas.
2. Juice §3 (R2/R3/R8/R10): hitstop por peso que estende (não descarta), `hitstop_active()`,
   `hitstop_left()`, `kick()`, `slow_mo` com rampa e `slowmo_changed`, `flash_strength()`,
   `reduce_flashes`.
3. Hitbox §3.4: um impacto por golpe (hitstop/chute/tremor/som 1× por quadro), um VFX por alvo
   no ponto de contato (`ImpactBurst.spawn(..., heavy)`).
4. Misericórdia §4 + `reset_mercy()`; REVISAO #11 (heal não revive, dano negativo não cura).
5. Orbes §5: chegadas em fila (55 ms), `spark` + `hud.spark_orb_arrived()` na chegada; sem
   órbita e todo orbe entrega (sonda `res://tools/combate/OrbProbe.tscn`: 9/9).
6. `reset_physics_interpolation()` nos teleportes do player/enemy (§6).
7. Fase B §7 em player/enemy (R1 flash instantâneo em tempo real + vibração da vítima; R5
   telegrafo 45 % com pulso 2 Hz + brilho 180 ms com FORMA redonda/losango, e o flash volta
   para o telegrafo; R4 som/VFX únicos e voz de dor ≤ 1/250 ms; R8 slow-mo racionado; R10;
   A4 morta cai até o chão e toca "dead"; gancho de legenda da fase 2; `attack_impact`,
   `impact_at`, `hurt_power`).
8. `VfxLibrary.prewarm(parent)` (sonda `res://tools/combate/PrewarmProbe.tscn`).

**Pendente (fora dos arquivos do Combate):** ver `docs/pedidos/onda2_combate.md` — `reset_mercy`
ao trancar zona, chamar `prewarm`, `physics_interpolation` no project.godot, sons `tell_*`,
`spark_orb_arrived` no HUD, opção "Reduzir flashes", `snap()` na Provação.

**Atenção:** `override.cfg` e `.import` reescritos no worktree — NÃO commitar (`git add` por arquivo).

---

## 1. Diagnóstico medido (antes)

| Item | Onde | Medido | Leitura |
|---|---|---|---|
| Sophia sai do quadro | `camera_shake.gd:31-35` | sonda telas 3/8/22/50: **fora=1, borda=16**, minx = −1 px; tela 10 (chefe, sem trava de zona) ok | Ver §2 |
| Hitstop fixo | `hitbox.gd:32` | 50 ms todo acerto; `juice.gd:28-29` descarta pedido novo | R2 |
| Tremor soma por alvo | `hitbox.gd:33` | 0,18+dano×0,006 **por inimigo** → satura | R3 |
| Ruído do tremor | `camera_shake.gd:38-41` | `randf()` por quadro (`noise_speed` não usado) | "chia" |
| Slow-mo volta seco | `juice.gd:49-51` | degrau 0,22→1,0 | R8 |
| Sophia pequena | captura tela 22 | ~68 px de 720 (≈ 1/10 da altura); pés a ~70 % da tela | §2.3 |
| Faixa de baixo | capturas | 30 % da tela abaixo dos pés = chão escuro + caixa de fala/legenda + barra do chefe | §2.3 |

Obs. das capturas ANTES: em `seq\demo_sheet.png` a Sophia fica na borda esquerda nos quadros
000–028 com a legenda "A Voz" na tela — é o mesmo efeito da §2 (zona recém-trancada, look-ahead
apontando pra direita), não troca de câmera (não há `make_current` no projeto).

## 2. Câmera (`scripts/fx/camera_shake.gd`)

### 2.1 Causa raiz (confirmada pela sonda, `antes/probe3.csv`)
No Godot 4 o `Camera2D.offset` é somado **depois** do clamp de `limit_*`. Hoje o look-ahead
(±90 px) e o enquadramento (−62 px) vão em `offset`, então **escapam dos limites**. Ao trancar
a zona (`level.gd:304`, limites 150..1090) com a Sophia em x≈182 (32 px da parede) e olhando
pra direita, a vista é empurrada 90 px pra direita além do limite → ela fica em x de tela ≈ 0–20.
Na sonda: t=25 trava a zona → x de tela cai de 258 para 61 em 20 quadros e para 2,9 na esquiva.
O smoothing (velocidade 5, ~76 px de atraso a 380 px/s de esquiva) piora; o giro lento do
look-ahead (180 px/s) também.

### 2.2 Correção (código pronto para colar)
Look-ahead e enquadramento vão no **alvo** (respeitam limites); `offset` fica só pro tremor/chute.
Suavização própria (o Camera2D não suaviza em dobro) + **trava de segurança**: a Sophia nunca
fica a menos de `SAFE_MARGIN` px da borda, nem durante o atraso.

```gdscript
extends Camera2D
## Câmera da Sophia: enquadramento, antecipação (look-ahead), tremor por trauma
## (ruído contínuo) e "chute" direcional dos golpes. Escuta o autoload Juice.
## O look-ahead e o enquadramento vão no ALVO da câmera (respeitam limit_*);
## o `offset` (que o Godot soma DEPOIS dos limites) fica só pro tremor/chute.

const ZOOM := 1.2                 # presença da Sophia (1.0 = antigo). Testar 1.15–1.25.
const LOOK_AHEAD := 64.0          # px de mundo à frente de onde ela olha
const LOOK_SPEED := 160.0         # px/s mudando o look-ahead na mesma direção
const LOOK_TURN_SPEED := 480.0    # px/s quando ela VIRA (volta rápido pro lado certo)
const FOLLOW_SPEED := 7.0         # suavização exponencial (1/s); maior = mais colado
const SAFE_MARGIN := 72.0         # px de MUNDO: distância mínima da Sophia à borda da vista
const FEET_SCREEN := 0.76         # pés a 76 % da altura da tela (antes ~70 %)
const NOISE_HZ := 15.0            # R3: frequência do ruído do tremor (12–18 Hz)
const KICK_RETURN := 0.11         # R3: chute direcional volta em 110 ms

@export var max_offset := Vector2(9, 7)
@export var decay := 1.4
## Enquadramento vertical relativo ao corpo (px de mundo). Telas que fixam a vista
## (Provação) zeram isto; o padrão é calculado de FEET_SCREEN e ZOOM no _ready.
@export var base_offset := Vector2(0, -66)

var trauma := 0.0
var _look_ahead: float = 0.0
var _cam_pos: Vector2 = Vector2.ZERO
var _smooth: bool = true
var _noise := FastNoiseLite.new()
var _noise_t: float = 0.0
var _kick: Vector2 = Vector2.ZERO
var _frame_trauma: float = 0.0     # R3: maior pedido NESTE quadro (não soma)


func _ready() -> void:
	Juice.shake_requested.connect(_add_trauma)
	if Juice.has_signal("kick_requested"):
		Juice.kick_requested.connect(_add_kick)
	zoom = Vector2(ZOOM, ZOOM)
	# Pés (≈ +12 px da origem) a FEET_SCREEN da altura visível.
	var view_h: float = 360.0 / ZOOM
	base_offset.y = 12.0 - (FEET_SCREEN - 0.5) * view_h
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	# A suavização é nossa; a do Camera2D somaria atraso em dobro.
	_smooth = position_smoothing_enabled
	position_smoothing_enabled = false
	top_level = true                 # posição global própria (segue por código)
	_cam_pos = _target()
	global_position = _cam_pos


func _add_trauma(amount: float) -> void:
	_frame_trauma = maxf(_frame_trauma, amount)


func _add_kick(dir: Vector2) -> void:
	_kick = dir


func _body() -> Node2D:
	return get_parent() as Node2D


func _target() -> Vector2:
	var b := _body()
	if b == null:
		return global_position
	var t: Vector2 = b.global_position + base_offset + Vector2(_look_ahead, 0.0)
	return _clamp_to_limits(t)


func _half_view() -> Vector2:
	return get_viewport_rect().size * 0.5 / zoom


func _clamp_to_limits(p: Vector2) -> Vector2:
	var h := _half_view()
	var lo := Vector2(limit_left + h.x, limit_top + h.y)
	var hi := Vector2(limit_right - h.x, limit_bottom - h.y)
	if lo.x <= hi.x:
		p.x = clampf(p.x, lo.x, hi.x)
	if lo.y <= hi.y:
		p.y = clampf(p.y, lo.y, hi.y)
	return p


func _process(delta: float) -> void:
	var b := _body()
	if b == null:
		return
	# 1) Look-ahead: vira rápido, anda devagar. Provação (vista fixa) não usa.
	var aim: float = 0.0
	if not CodexSession.active and b is Player:
		aim = float(b.facing) * LOOK_AHEAD
	var turning: bool = signf(aim) != signf(_look_ahead) and absf(_look_ahead) > 1.0
	_look_ahead = move_toward(_look_ahead, aim, delta * (LOOK_TURN_SPEED if turning else LOOK_SPEED))
	# 2) Segue o alvo (suave), com trava: a Sophia nunca sai da faixa segura.
	var tgt := _target()
	if _smooth:
		_cam_pos = _cam_pos.lerp(tgt, 1.0 - exp(-FOLLOW_SPEED * delta))
	else:
		_cam_pos = tgt
	var h := _half_view()
	var reach: float = maxf(0.0, h.x - SAFE_MARGIN)
	_cam_pos.x = clampf(_cam_pos.x, b.global_position.x - reach, b.global_position.x + reach)
	global_position = _cam_pos
	# 3) Tremor (trauma², ruído contínuo) + chute direcional; congelado no hitstop.
	if _frame_trauma > 0.0:
		trauma = clampf(trauma + _frame_trauma, 0.0, 1.0)
		_frame_trauma = 0.0
	var real_dt: float = delta / maxf(Engine.time_scale, 0.001)
	var frozen: bool = Juice.has_method("hitstop_active") and Juice.hitstop_active()
	if not frozen:
		trauma = maxf(trauma - decay * real_dt, 0.0)
		_noise_t += real_dt * NOISE_HZ
		_kick = _kick.move_toward(Vector2.ZERO, _kick.length() * real_dt / KICK_RETURN + 0.5 * real_dt)
	var amount := trauma * trauma
	var shake := Vector2(
		max_offset.x * amount * _noise.get_noise_2d(_noise_t, 0.0),
		max_offset.y * amount * _noise.get_noise_2d(0.0, _noise_t + 100.0))
	offset = shake + _kick


## Teleporte do corpo (renascer, resgate do vazio): a câmera pula junto.
func snap() -> void:
	_look_ahead = 0.0
	_cam_pos = _target()
	global_position = _cam_pos
	reset_physics_interpolation()
```

**Riscos a conferir ao aplicar:**
- `top_level = true`: `codex_trial.gd:19-25` e `level.gd:112-117` só mexem em limites,
  `base_offset` e `position_smoothing_enabled` — continuam funcionando (o `_ready` da câmera roda
  antes do da fase; `_smooth` é lido no `_ready`, então a Provação continua **suavizada**; se
  quiser vista sem suavização lá, ela pode setar `cam._smooth = false` — pedido de 1 linha em
  `codex_trial.gd:20`).
- Provação: `base_offset = ZERO` + `limit_top 50 / limit_bottom 410` (360 de altura). Com zoom
  1,2 a vista tem 300 de altura e passa a correr dentro desse intervalo — conferir captura.
- Fundo PNG (`scenery.gd:58-66`): `ParallaxBackground` escala junto com o zoom (não ignora zoom);
  o sprite cobre 853×480 a partir de (0,0) → zoom > 1 só recorta. Conferir captura nas telas 3/8/22/50.
- Teleportes da Sophia precisam chamar `$Camera2D.snap()` (lista na §6/§7).
- Meta da sonda: `fora=0 borda=0` nas telas 3/8/22/50/10. Se `borda>0`, subir `SAFE_MARGIN`.

### 2.3 Presença (zoom/enquadramento) — proposta
Hoje: Sophia ≈ 68 px num quadro de 360 (zoom 1), pés a ~70 %, 30 % de baixo é chão + UI.
Proposta: **zoom 1,2** (Sophia ≈ 82 px, +20 %) e pés a **76 %** (a faixa de baixo cai de ~106 para
~72 px de mundo). Custo: vê-se 533 px de largura em vez de 640 (zona tem 940) — o look-ahead de
64 px compensa à frente. A caixa de fala/legenda e a barra de chefe ocupam essa faixa de baixo
(UI) — por isso NÃO desci os pés além de 76 %. Validar em captura e no playtest (risco: inimigo
atirando de fora da vista).

## 3. Juice (`scripts/autoload/juice.gd`) — código pronto

```gdscript
extends Node
## "Juice" = feedback que dá peso ao combate: hitstop, tremor, chute de câmera,
## câmera lenta e limite de flashes. Autoload `Juice`. Números: NEURO_SATISFACAO.md.

signal shake_requested(trauma: float)
signal kick_requested(dir: Vector2)          ## R3: empurrão direcional da câmera
signal hitstop_started(duration: float)      ## Fase B: flash/vibração da vítima em tempo real
signal hitstop_ended()
signal slowmo_changed(active: bool, scale: float)   ## Áudio: abafar (passa-baixas) durante a lentidão

# --- R2: hitstop por peso (segundos REAIS) ---
const HITSTOP_SCALE := 0.05
const HS_LIGHT := 0.050          # leve 1º/2º da string
const HS_FINISHER := 0.090       # leve final da string / lançador (83–100 ms)
const HS_HEAVY := 0.108          # pesado (100–117 ms)
const HS_KILL_BONUS := 0.033     # golpe que mata (+2 quadros)
const HS_CROWD_BONUS := 0.017    # pegou 3+ alvos (+1 quadro, uma vez)
const HS_MULTI_TICK := 0.025     # ticks intermediários do multi-hit
const HS_PLAYER_HURT := 0.075    # Sophia tomando dano
const HS_MAX := 0.200            # teto absoluto
# --- R3: tremor/chute ---
const KICK_LIGHT := 2.0          # px no sentido do golpe
const KICK_HEAVY := 4.0
const TRAUMA_HEAVY := 0.30       # leve = 0 (só chute)
# --- R8: câmera lenta ---
const SLOWMO_RAMP := 0.18        # volta em rampa (150–200 ms reais), não degrau
# --- R10: fotossensibilidade ---
const FLASH_MIN_INTERVAL := 0.333   # ≤ 3 flashes cheios/s por alvo
const FLASH_HALF := 0.47            # força relativa do flash "do meio" (1,4 de 3,0)
const FLASH_BOSS_CAP := 2.0         # chefe: flash cheio 2,0 (não 3,0)

var _hitstop_until_ms: int = 0
var _hitstop_running := false
var _base_scale := 1.0
var _slow_token := 0
var _ramp_tween: Tween
var _flash_ms: Dictionary = {}      # instance_id -> último flash cheio (ms)

var shake_mult := 1.0
var rumble_enabled := true
## R10: "Reduzir flashes" (Opções). UI grava aqui (pedido em docs/pedidos/combate.md).
var reduce_flashes := false

var speed_mult := 1.0:
	set(v):
		speed_mult = v
		_base_scale = v
		Engine.time_scale = v


func hitstop_active() -> bool:
	return _hitstop_running


## R2: congela em tempo REAL. Sobreposição: vale o MAIOR fim (estende), nunca descarta.
func hit_stop(duration: float = HS_LIGHT) -> void:
	duration = clampf(duration, 0.0, HS_MAX)
	var now := Time.get_ticks_msec()
	var until := now + int(duration * 1000.0)
	if _hitstop_running:
		_hitstop_until_ms = maxi(_hitstop_until_ms, mini(until, now + int(HS_MAX * 1000.0)))
		return
	_hitstop_until_ms = until
	_hitstop_running = true
	Engine.time_scale = HITSTOP_SCALE
	hitstop_started.emit(duration)
	while Time.get_ticks_msec() < _hitstop_until_ms:
		var left := float(_hitstop_until_ms - Time.get_ticks_msec()) / 1000.0
		await get_tree().create_timer(maxf(left, 0.001), true, false, true).timeout
	_hitstop_running = false
	Engine.time_scale = _base_scale
	hitstop_ended.emit()


## R2: duração por peso (o Hitbox chama; ComboData pode sobrescrever na Fase B).
func hitstop_for(heavy: bool, finisher: bool, kills: bool, targets: int) -> float:
	var d := HS_HEAVY if heavy else (HS_FINISHER if finisher else HS_LIGHT)
	if kills:
		d += HS_KILL_BONUS
	if targets >= 3:
		d += HS_CROWD_BONUS
	return minf(d, HS_MAX)


## R8: câmera lenta por `duration` s REAIS; sai em rampa (ease-in) de SLOWMO_RAMP.
func slow_mo(scale: float = 0.25, duration: float = 0.6) -> void:
	_slow_token += 1
	var my := _slow_token
	if _ramp_tween != null and _ramp_tween.is_valid():
		_ramp_tween.kill()
	_base_scale = scale * speed_mult
	if not _hitstop_running:
		Engine.time_scale = _base_scale
	slowmo_changed.emit(true, scale)
	await get_tree().create_timer(duration, true, false, true).timeout
	if my != _slow_token:
		return
	_ramp_tween = create_tween().set_ignore_time_scale(true)
	_ramp_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_ramp_tween.tween_method(_set_base_scale, _base_scale, speed_mult, SLOWMO_RAMP)
	await _ramp_tween.finished
	if my == _slow_token:
		slowmo_changed.emit(false, 1.0)


func _set_base_scale(v: float) -> void:
	_base_scale = v
	if not _hitstop_running:
		Engine.time_scale = v


func slowmo_active() -> bool:
	return _base_scale < speed_mult * 0.99


## R3: tremor por trauma (a câmera fica com o MAIOR pedido do quadro).
func shake(trauma: float = 0.4) -> void:
	if shake_mult <= 0.001:
		return
	shake_requested.emit(trauma * shake_mult)


## R3: empurrão direcional da câmera (golpe da Sophia). dir.x = lado do golpe.
func kick(dir_x: float, heavy: bool) -> void:
	if shake_mult <= 0.001:
		return
	var px := (KICK_HEAVY if heavy else KICK_LIGHT) * shake_mult
	kick_requested.emit(Vector2(signf(dir_x) * px, 0.0))


## R10: força do flash permitida agora para `target` (0..1 sobre a cor cheia).
## Cheio no máximo a cada 333 ms por alvo; no meio, meia força. Chefe: teto 2,0.
## Uso (Fase B): var k := Juice.flash_strength(self, is_boss_enemy)
##               modulate = Color(1,1,1).lerp(Color(3,3,3), k)
func flash_strength(target: Object, is_big: bool = false) -> float:
	var id := target.get_instance_id()
	var now := Time.get_ticks_msec()
	var k := 1.0
	if now - int(_flash_ms.get(id, -100000)) < int(FLASH_MIN_INTERVAL * 1000.0):
		k = FLASH_HALF
	else:
		_flash_ms[id] = now
	if is_big:
		k *= (FLASH_BOSS_CAP - 1.0) / 2.0        # 3,0 → 2,0
	if reduce_flashes:
		k *= 0.5
	return k


func rumble(weak: float, strong: float, dur: float) -> void:
	if not rumble_enabled:
		return
	for dev in Input.get_connected_joypads():
		Input.start_joy_vibration(dev, weak, strong, dur)
```
Notas: `_flash_ms` deve ser podado (apagar ids com `is_instance_id_valid` falso) a cada ~5 s.
`slow_mo` agora multiplica por `speed_mult` (o bot de balance roda a 3×) — conferir `balance_bot.gd`.

### 3.4 `scripts/combat/hitbox.gd` — um evento por golpe (R2/R3)
Trocar `hitbox.gd:30-35` (hitstop/tremor/som por alvo) por agregação **por quadro**:
```gdscript
var _frame_hits: int = 0
var _frame_kill: bool = false
var _flush_queued: bool = false

func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox and area.team != team:
		area.receive_hit(damage, global_position, knockback, unblockable, owner)
		var victim := area.owner if area.owner != null else area.get_parent()
		var hc = victim.get("health") if victim != null else null
		if hc != null and hc.has_method("is_dead") and hc.is_dead():
			_frame_kill = true
		_frame_hits += 1
		if not _flush_queued:
			_flush_queued = true
			_flush_impact.call_deferred()
		# (register_hit / on_hit_landed / ImpactBurst como hoje — ImpactBurst sai na Fase B, R4)

## Um impacto por golpe, não por alvo: hitstop pelo peso, chute/tremor uma vez.
func _flush_impact() -> void:
	_flush_queued = false
	var mv = owner.get("current_move") if owner != null else null
	var heavy: bool = mv != null and mv.is_heavy()
	var finisher: bool = mv != null and (mv.launcher or mv.sequence.size() >= 3)
	if team == "player":
		Juice.hit_stop(Juice.hitstop_for(heavy, finisher, _frame_kill, _frame_hits))
		Juice.kick(float(owner.get("facing")) if owner != null else 1.0, heavy)
		if heavy:
			Juice.shake(Juice.TRAUMA_HEAVY)
	else:
		Juice.hit_stop(Juice.HS_PLAYER_HURT)
		Juice.shake(0.35)
	if not (team == "player" and heavy):
		Audio.play_sfx("hit")         # o pesado toca "hit_heavy" no register_hit (R4: no lugar, não por cima)
	_frame_hits = 0
	_frame_kill = false
```
Obs.: `finisher` por tamanho de sequência é aproximação; o certo é um campo `hitstop` no
`ComboData` (arquivo do Técnico/dados) — pedido.

## 4. Misericórdia oculta (APROVADA pelo dono) — `scripts/components/health_component.gd`
Regra: a Sophia, com vida > 10 % do máximo, recebe um golpe que a mataria → fica com 1, **uma vez
por luta** (reseta por tela — o Player e o HealthComponent nascem de novo a cada tela — e ao
trancar zona nova; fase 2 do chefe NÃO reseta). Invisível: só hitstop um pouco maior.
Não vale contra insta-kill (`take_damage(>= 9999)`: ferramentas e roteiro) nem queda no vazio
(o vazio não mata — `player.gd:118-121` resgata).
```gdscript
signal mercy_spared()               ## Fase B: flash discreto/pose, se quiser

const MERCY_MIN_RATIO := 0.10       # só se tinha mais de 10 % da vida antes do golpe
const INSTA_KILL := 9999            # dano >= isto ignora a misericórdia (roteiro/ferramentas)
const MERCY_HITSTOP := 0.12         # um pouco maior que o dano comum (75 ms)

## Liga sozinho quando o dono é a Sophia (Player); inimigos nunca.
var mercy_enabled: bool = false
var _mercy_used: bool = false

func _ready() -> void:
	current_health = max_health
	if get_parent() is Player:
		mercy_enabled = true

## Nova luta (zona trancada / encontro novo). A fase 2 do chefe NÃO chama isto.
func reset_mercy() -> void:
	_mercy_used = false

func take_damage(amount: int) -> void:
	if current_health <= 0:
		return
	if mercy_enabled and not _mercy_used and amount < INSTA_KILL \
			and amount >= current_health \
			and current_health > maxi(1, int(ceil(max_health * MERCY_MIN_RATIO))):
		_mercy_used = true
		current_health = 1
		health_changed.emit(current_health, max_health)
		Juice.hit_stop(MERCY_HITSTOP)
		mercy_spared.emit()
		return
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit()
```
Fase B: `level.gd` (dono: Técnico/Cenário) chama `player.health.reset_mercy()` onde a zona tranca
(`level.gd:300-304`, junto do `_set_camera_limits(c - ZONE_HALF, ...)`). Conferir
`tools/codex_qa.gd:86`, `tools/shot.gd:178` (usam 99999 → continuam matando) e
`tools/ux_shots.gd:200` (35 % → não afetado). O bot de balance vai morrer menos — rodar e anotar.

## 5. Orbes de faísca R6 — `scripts/fx/spark_orb.gd`
- No `burst`: cada orbe recebe `index` (0..n−1) e `count`; força de atração variada por índice
  pra chegadas espaçadas **40–70 ms** (ex.: `_homing_rate = 3.2 + index * 0.35`, aferir no GIF).
- Na chegada (`spark_orb.gd:33-36`): tique com pitch pentatônico, sem aleatório:
```gdscript
const PENTA := [0, 2, 4, 7, 9, 12, 14, 16, 19]
const TICK_DB := -12.0
func _arrive() -> void:
	var semi: int = PENTA[mini(index, PENTA.size() - 1)]
	var pitch := pow(2.0, semi / 12.0)
	if Audio.has_method("play_sfx_pitched"):
		Audio.play_sfx_pitched("spark", pitch, TICK_DB)
	else:
		Audio.play_sfx("spark", 0.0, TICK_DB)
	for h in get_tree().get_nodes_in_group("hud"):
		if h.has_method("spark_orb_arrived"):
			h.spark_orb_arrived()
```
- Dependências (pedidos): Áudio `play_sfx_pitched(name, pitch, db)` + tirar o "spark" do crédito
  (`audio_manager.gd:286-290`) + anti-spam de "spark" < 40 ms (`SPAM_MS`) não pode engolir o arpejo;
  UI `hud.spark_orb_arrived()` (conta 1 a 1, pop 1,0→1,15→1,0 em 120 ms).

## 6. Interpolação de física (monitores 144 Hz)
- `project.godot`: `[physics] common/physics_interpolation=true` (liberado só pra isto).
- Godot 4.7 tem `Node.reset_physics_interpolation()` (conferido via ClassDB); não há
  `get_global_transform_interpolated` em 2D → a câmera roda em `_process` lendo
  `global_position` (física). **Testar**: com interpolação ligada o corpo é desenhado interpolado
  e a câmera pode "tremer" 1 px relativo a ele. Se tremer, usar `process_callback = PHYSICS` na
  Camera2D (o Godot interpola a câmera no modo física) — medir com captura a `--fixed-fps 144`.
- Teleportes que precisam `reset_physics_interpolation()` (+ `$Camera2D.snap()` se for a Sophia):
  - `player.gd:120` resgate do vazio (Sophia → `snap()`)
  - `enemy.gd:261` anti-softlock (volta pro meio)
  - `enemy.gd:427` `_blink_to` (teleporte do Silêncio)
  - `enemy.gd:635` servos invocados (nascem já posicionados — reset logo após)
  - `player.gd:607` Boca Voraz puxa inimigos (`e.global_position.x -= ...`) — puxão de até 150 px: reset
  - `level.gd:378`, `level.gd:381` posicionamento de inimigos na zona; `level.gd:244-272` NPCs/props
  - `codex_trial.gd:18` `player.position = Vector2(160, 270)` (Sophia → `snap()`)
  - `tools/shot.gd:408,413` (ferramenta, teleporta a Sophia) — Técnico

## 7. FASE B — mudanças em arquivos de outros (executar quando liberado)

### player.gd
| Linha | Hoje | Proposto | Rec. |
|---|---|---|---|
| 120 | `global_position = Vector2(...)` (resgate) | depois: `reset_physics_interpolation(); $Camera2D.snap()` | §6 |
| 378 | `Juice.shake(0.4)` no FIM do wind-up do pesado | remover (o tremor do pesado sai do Hitbox SÓ se acertar, R3) | R3 |
| 393-394 | queda: `shake(0.7)` + `hit_stop(0.08)` | `Juice.shake(0.5)`; `Juice.hit_stop(0.100)` | R2/R3 |
| 445-449 | `register_hit`: `play_sfx("hit_heavy"/"hit")` + `VfxLibrary.hit` pesado no corpo dela | manter só `if heavy: Audio.play_sfx("hit_heavy")` (o leve vem do Hitbox); **apagar** o `VfxLibrary.hit` (L449) — o VFX único fica no ponto de contato (Cenário/VFX) | R4 |
| 500-502 | parry `hit_stop(0.12)` `shake(0.6)` | `hit_stop(0.12)` (manter), `shake(0.35)` | R3 |
| 517 | bloqueio `shake(0.15)` | manter | — |
| 642-643 | Coroa: `slow_mo(0.35,0.4)` `shake(0.8)` | manter slow-mo (magia final); `shake(0.6)` | R3/R8 |
| 690 | `health.take_damage(damage)` | igual (misericórdia é interna); antes: `Juice.hit_stop(Juice.HS_PLAYER_HURT)` se não for o Hitbox | R2 |
| 705 | `_flash(Color(4, 1, 1, 1))` dano | `_flash(Color(2.2, 0.9, 0.9, 1))` (menos vermelho saturado) | R10 |
| 719-720 | esquiva perfeita `slow_mo(0.3,0.35)` `shake(0.25)` | manter slow-mo; trocar shake por `Juice.kick(dodge_dir, false)` | R3 |
| 792-803 | `_squash` | (Animação) | R20 |
| 805-810 | `_flash` com tween em tempo de jogo | flash **instantâneo** + volta em 110 ms REAIS: ```t.set_ignore_time_scale(true); visual.modulate = color; t.tween_interval(0.0); t.tween_property(visual,"modulate",Color(1,1,1,1),0.11)``` e `Juice.flash_strength(self)` pra limitar | R1/R10 |
| novo | — | `health.mercy_spared.connect(func(): _flash(Color(1.6,1.6,2.0,1)))` (opcional, discreto) | §4 |

### enemy.gd
| Linha | Hoje | Proposto | Rec. |
|---|---|---|---|
| 261 | anti-softlock teleporta | `reset_physics_interpolation()` depois | §6 |
| 427 | `_blink_to` | `reset_physics_interpolation()` depois de `global_position.x = x` | §6 |
| 447 | `visual.modulate = TELEGRAPH_*` (multiplica 100 %) | `visual.modulate = Color(1,1,1).lerp(TELEGRAPH_*, 0.45)` + guardar `_tint_base` = essa cor; glint em `strike−0.18 s` (VFX/Áudio) | R5 |
| 512 | `shake(0.75 boss / 0.5)` golpe de chão | `shake(0.5 if boss else 0.35)` | R3 |
| 584 | exploder `shake(0.6)` | `shake(0.45)` | R3 |
| 660-661 | fase 2 `shake(0.9)` `hit_stop(0.15)` | `shake(0.7)`; manter 0.15 | R3 |
| 768-775 | finisher: slow-mo em TODO último inimigo | racionar: só se `RunManager`/Level disser que é o fim da **tela** (última zona/onda) **ou** golpe pesado/aéreo/magia; senão nada (o +33 ms de morte vem do Hitbox). `Juice.shake(0.5)` → remover | R8 |
| 778 | `_flash(Color(3,3,3,1))` | `_flash(Color(1,1,1).lerp(Color(3,3,3), Juice.flash_strength(self, is_boss_enemy)))` | R10 |
| 779 | `enemy_hurt` em todo acerto | só se `Time.get_ticks_msec() - _last_hurt_voice_ms >= 250` | R4 |
| 780-782 | `VfxLibrary.hit` pesado no corpo | remover (VFX único no contato, R4); manter só pra magia (`attacker == null`) | R4 |
| 838 | stagger `_flash(3,3,3)` | idem L778 | R10 |
| 897-898 | morte de chefe `shake(1.0)` `hit_stop(0.12)` | `shake(0.9)`, `hit_stop(0.18)` | R2/R3 |
| 915-920 | `_flash` acaba em branco (apaga o telegrafo — BUG) | instantâneo, tempo real, volta pra `_tint_base` se `estate == WINDUP`, senão branco: ```var back := _tint_base if estate == EState.WINDUP else Color(1,1,1,1)``` + vibração da vítima: `visual.position.x` ±1,5/±3 px alternando a cada 33 ms reais durante `Juice.hitstop_active()` | R1/R5 |
| 635 | servos | `m.reset_physics_interpolation()` | §6 |

### Outros
- `level.gd:300-304` (trancar zona): `player.health.reset_mercy()`. `level.gd:378/381`: reset interp.
- `codex_trial.gd:18`: depois de posicionar, `player.get_node("Camera2D").snap()`.
- `final_battle.gd:55-56`: manter slow-mo (final); `shake(1.0)` ok (ápice raro).
- `projectile.gd:69-70`: `hit_stop(0.04)` ok; `shake(0.25)` → `0.2`.
- `vfx_library.gd:301` `Juice.shake(1.4)` → 1.0 (trauma satura em 1 de qualquer jeito).
- `options_menu.gd` (UI): opção "Reduzir flashes" → `Juice.reduce_flashes` + `GameManager` salvar.
- `audio_manager.gd` (Áudio): escutar `Juice.slowmo_changed` (passa-baixas 1,5 kHz / 2,5 kHz na
  esquiva perfeita; música −4 dB); `play_sfx_pitched`; tirar "spark" do crédito.
