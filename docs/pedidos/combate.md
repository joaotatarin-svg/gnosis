# Pedidos do Combate a outros diretores (17/10/2026)

Detalhe e código em `docs/COMBATE.md` §5–§7.

## Áudio (`scripts/autoload/audio_manager.gd`)
1. `play_sfx_pitched(name: String, pitch: float, volume_db: float)` — tom EXATO (sem aleatório),
   para o arpejo pentatônico das faíscas (R6).
2. Tirar o `play_sfx("spark")` do crédito (`audio_manager.gd:286-290`); o som passa a tocar na
   CHEGADA de cada orbe (`spark_orb.gd`). O anti-spam de 40 ms (`SPAM_MS`) não pode engolir o
   arpejo (chegadas espaçadas 40–70 ms): isentar "spark" ou baixar para 25 ms nele.
3. Escutar `Juice.slowmo_changed(active, scale)` (novo sinal): passa-baixas 20 kHz→1,5 kHz em
   60 ms, volta em 250 ms; música −4 dB; na esquiva perfeita (scale ≈ 0,3) corte em 2,5 kHz (R8).

## UI (`scripts/ui/hud.gd`, `scripts/ui/options_menu.gd`)
1. `hud.spark_orb_arrived()` (grupo "hud"): contador de faíscas sobe 1 a 1 na chegada de cada
   orbe, pop 1,0→1,15→1,0 em 120 ms (R6).
2. Opção "Reduzir flashes" (padrão desligada) → `Juice.reduce_flashes` + persistir no
   GameManager (R10): `screen_flash` α × 0,35 (Cenário/VFX), flash de sprite × 0,5 (Juice já aplica).

## Técnico/Cenário (`scripts/levels/level.gd`, `codex_trial.gd`, `tools/shot.gd`)
1. Ao trancar zona (`level.gd:300-304`): `player.health.reset_mercy()` (misericórdia oculta, §4).
2. Teleportes: `reset_physics_interpolation()` (§6) e, para a Sophia, `$Camera2D.snap()`.
3. `ComboData`: campo `hitstop: float` (0 = automático pelo peso) para afinar golpe a golpe (R2).
