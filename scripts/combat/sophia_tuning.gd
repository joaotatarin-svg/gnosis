extends RefCounted
class_name SophiaTuning
## Combate 6 (playtest do João, 17/10/2026): "dano da Sophia forte demais",
## "pular + triângulo roubado", "ataques frenéticos demais", "movimento travado".
## TODOS os números de dano, ritmo e movimento da Sophia ficam AQUI (o ComboData
## e a tabela de golpes do GameContent continuam sendo a base; isto é a régua).
## Relatório e tabelas: docs/onda2/COMBATE6.md.

# --- DANO --------------------------------------------------------------------
## Fator sobre o dano-base da tabela de golpes (GameContent). Antes: 1,0.
const DMG_SCALE := 0.65
## Cada nível de arma acima do 1 soma +17 % (multiplicativo; nv.5 = ×1,68).
## Antes: +6 FIXOS por nível (nv.5 = leve 12 → 36, ×3 — o que derretia chefe).
const WEAPON_STEP := 0.17
## Queda Estelar (pulo + forte): o contato no mergulho dá pouco; a onda do
## pouso é o golpe. Antes: contato 100 % + onda 100 % (dano DOBRADO, em área).
const DIVE_CONTACT := 0.35
const DIVE_NOVA := 0.8

# --- RITMO (preparo, cancelamento, recuperação) --------------------------------
const WINDUP_LIGHT := 0.06           # antes 0,04
const WINDUP_LIGHT_FINISHER := 0.10  # 3º leve em diante (antes 0,04)
const WINDUP_LAUNCHER := 0.12        # lançadores (antes 0,17 pelo "pesado")
const WINDUP_HEAVY := 0.22           # antes 0,17
const WINDUP_HEAVY_FINISHER := 0.28  # HHH, LLLH, HHL (antes 0,17)
const WINDUP_AIR_LIGHT := 0.05       # antes 0,03
const WINDUP_AIR_HEAVY := 0.24       # Queda Estelar: paira e carrega (antes 0,03)
## Fração do golpe (depois do preparo) a partir da qual o próximo da string
## pode sair. Antes: 0,5 para tudo.
const CHAIN_AT_LIGHT := 0.55
const CHAIN_AT_HEAVY := 0.68
## Recuperação ao terminar um golpe sem encadear (s): ninguém reataca nela.
const RECOVERY_LIGHT := 0.20          # antes 0,16
const RECOVERY_HEAVY := 0.42          # antes 0,34
const RECOVERY_PER_STEP := 0.06       # por botão a mais na string (antes 0,05)
const RECOVERY_FINISHER := 0.12       # string de 3+ (o final compromete)
const RECOVERY_AOE := 0.20
const RECOVERY_AIR_LIGHT := 0.22
## Queda Estelar: presa no chão depois da onda, depois a recuperação comum,
## e só pode sair de novo depois de AIR_HEAVY_CD (contado do pouso) — e no
## máximo 1 por pulo (o pulo duplo NÃO devolve).
const DIVE_LAND_LOCK := 0.40
const DIVE_RECOVERY := 0.25
const AIR_HEAVY_CD := 1.0
const AIR_LIGHTS_PER_JUMP := 2       # Giro Celeste: 2 por pulo (só o 1º paira)
## Cancelamento do golpe em esquiva/defesa: só em JANELAS.
const HEAVY_FEINT := 0.4             # pesado: cancela nos primeiros 40 % do preparo
const DIVE_CANCEL_AFTER := 0.22      # Queda: esquiva só depois de 0,22 s presa no chão

# --- BUFFERS --------------------------------------------------------------------
const ATTACK_BUFFER := 0.18          # ataque apertado na recuperação sai assim que der
const JUMP_BUFFER := 0.12            # antes 0,10 e só valia parado/andando

# --- MOVIMENTO ------------------------------------------------------------------
## Tempo (s) da curva até a velocidade-alvo. A curva é rápida no começo e
## assenta no fim (ease-out): responde já no 1º quadro, sem tranco seco.
const ACCEL_TIME := 0.10
const DECEL_TIME := 0.08
const TURN_TIME := 0.09              # virar: freia e acelera do outro lado
const AIR_ACCEL_TIME := 0.16
const AIR_DECEL_TIME := 0.22
const CURVE_START := 1.45            # ritmo no começo da curva (× a média)
const CURVE_END := 0.55              # ritmo no fim

# --- PULO DUPLO -----------------------------------------------------------------
const DOUBLE_JUMP_MULT := 0.82       # ×velocidade do pulo (altura ≈ 0,67×)
const DOUBLE_JUMP_SPIN := 0.34       # s da pirueta


## Dano de um golpe no nível de arma `lvl`.
static func move_damage(base: int, lvl: int) -> int:
	return maxi(1, roundi(float(base) * DMG_SCALE * (1.0 + WEAPON_STEP * float(maxi(1, lvl) - 1))))


## Preparo (s) antes do golpe conectar.
static func windup(move: ComboData) -> float:
	if move.air:
		return WINDUP_AIR_HEAVY if move.is_heavy() else WINDUP_AIR_LIGHT
	if move.launcher:
		return WINDUP_LAUNCHER
	var finisher: bool = move.sequence.size() >= 3
	if move.is_heavy():
		return WINDUP_HEAVY_FINISHER if finisher else WINDUP_HEAVY
	return WINDUP_LIGHT_FINISHER if finisher else WINDUP_LIGHT


## Fração do golpe depois da qual a janela de encadear abre.
static func chain_at(move: ComboData) -> float:
	return CHAIN_AT_HEAVY if move.is_heavy() else CHAIN_AT_LIGHT


## Recuperação ao fim do golpe (sem encadear).
static func recovery(move: ComboData) -> float:
	if move.air:
		return DIVE_RECOVERY if move.is_heavy() else RECOVERY_AIR_LIGHT
	var r: float = RECOVERY_HEAVY if move.is_heavy() else RECOVERY_LIGHT
	r += float(move.sequence.size() - 1) * RECOVERY_PER_STEP
	if move.sequence.size() >= 3:
		r += RECOVERY_FINISHER
	if move.aoe_radius > 0.0:
		r += RECOVERY_AOE
	return r


## Um passo da curva de velocidade horizontal (ease-out).
static func approach(v: float, target: float, top_speed: float, time: float, delta: float) -> float:
	var diff: float = absf(target - v)
	if diff <= 0.0001:
		return target
	var frac: float = clampf(diff / maxf(top_speed, 1.0), 0.0, 1.0)
	var rate: float = top_speed / maxf(time, 0.001) * lerpf(CURVE_END, CURVE_START, frac)
	return move_toward(v, target, rate * delta)
