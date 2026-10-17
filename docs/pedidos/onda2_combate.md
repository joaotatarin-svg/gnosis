# Pedidos do Combate (Onda 2, 17/10/2026)

Tudo do lado do Combate já está no branch `dir2/combate` e funciona sem estes pedidos
(chamadas protegidas por `has_method`/`has_signal`). Detalhe em `docs/COMBATE.md` §2–§7.

## Técnico / Cenário (`scripts/levels/level.gd`, `codex_trial.gd`, `project.godot`, `tools/shot.gd`)
1. **Misericórdia**: ao trancar zona (onde chama `_set_camera_limits(c - ZONE_HALF, ...)`):
   `if player and player.health: player.health.reset_mercy()`. Sem isto ela vale 1× por TELA
   (o componente nasce de novo a cada tela), não 1× por luta.
2. **Pré-aquecimento**: no `_ready` da fase (depois do cenário montado), uma vez:
   `VfxLibrary.prewarm(self)` — cria cada efeito de combate quase transparente no centro da
   vista e some em 0,4 s (sonda: `res://tools/combate/PrewarmProbe.tscn`, ~12 ms, sem tremor).
3. **Teleportes** (§6): `reset_physics_interpolation()` depois de posicionar inimigos/NPCs/props
   (`level.gd` posicionamento na zona) e, para a Sophia, `player.get_node("Camera2D").snap()`:
   `codex_trial.gd` depois de `player.position = Vector2(160, 270)`; `tools/shot.gd` onde
   teleporta a Sophia.
4. **Interpolação de física** (monitores 144 Hz): `[physics] common/physics_interpolation=true`
   no `project.godot`. A câmera já roda no `_physics_process` e chama `reset_physics_interpolation()`
   no `snap()`; os teleportes do Combate já resetam. NÃO testado com ela ligada (é do Técnico ligar).
5. **ComboData**: campo opcional `hitstop: float` (0 = automático pelo peso). O Hitbox já lê
   (`"hitstop" in mv`).
6. `tools/codex_qa.gd` "resultado e pausa do encontro N" espera só 0,65 s depois da limpeza; com
   câmera lenta de finalização o resultado demora mais. Hoje passa (magia/QA com `attacker=null`
   não dispara slow-mo), mas é frágil: sugiro esperar o `result_layer` com um laço de até ~3 s.

## Áudio (`scripts/autoload/audio_manager.gd`, catálogo)
1. Sons do **brilho de aviso** (R5): `tell_parry` (redondo, agudo, curto) e `tell_unblock`
   (áspero, grave). Ponha no CATÁLOGO + `docs/AUDIO.md`; o Combate liga em `enemy._tell_glint()`
   (hoje mudo — o AudioQA reprova nome fora do catálogo).
2. `spark`: o orbe já toca `Audio.play_sfx("spark")` na CHEGADA (espaçado ~55 ms). Tirar o "spark"
   do crédito (`_on_orbs`) para não tocar em dobro; o anti-spam de 40 ms não pode engolir o arpejo.
   Opcional: `play_sfx_pitched(name, pitch, db)` para a escala pentatônica exata.
3. Escutar `Juice.slowmo_changed(active: bool, scale: float)` (novo): passa-baixas/música −4 dB.

## UI (`scripts/ui/hud.gd`, `scripts/ui/options_menu.gd`)
1. `hud.spark_orb_arrived()` (grupo "hud"): o contador sobe 1 a 1 a cada orbe que chega (o orbe
   já chama; todos os orbes agora entregam — nenhum some no caminho).
2. Opção "Reduzir flashes" → `Juice.reduce_flashes = true/false` (+ salvar). Já aplicado: flash de
   sprite × 0,5 e `VfxLibrary.screen_flash` α × 0,35.

## Animação-Chefes (`boss_puppet.gd`)
- `Enemy.attack_impact` (sinal novo): emitido no instante em que o dano sai (começo do STRIKE).
- `visual.get_meta("impact_at")` (0 = começo do STRIKE) e `visual.get_meta("hurt_power")` (0..1,
  força do último dano) para dosar o tranco do boneco.
