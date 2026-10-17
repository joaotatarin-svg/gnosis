# Pedidos do UI-HUD (Onda 2) a outros agentes

## Combate / dono de `scripts/fx/spark_orb.gd`
- Na CHEGADA de cada orbe (antes do `queue_free`):
  `get_tree().call_group("hud", "spark_orb_arrived")`. O HUD já sobe o contador
  1 a 1 com pop (1,0→1,15→1,0 em 120 ms); sem a chamada, o contador corre sozinho
  como antes (nada quebra).

## Dono de `scripts/entities/enemy.gd`
- Opcional: `get_tree().call_group("hud", "boss_phase", 2, self)` em `_enter_phase2`.
  Hoje o HUD já acha o chefe certo pela propriedade `phase` (=2 antes da chamada),
  mas passar `self` deixa o contrato explícito.

## Encenação (cenas B e D)
- `hud.detach_ring(i, alvo)` e `hud.restore_ring(i, origem)` já TOCAM a nota da
  gema (`Audio.ring_note(i)` / `ring_note(i, true)`): não toquem outra por cima.
  `restore_ring` emite `ring_restore_finished(i)`; o encaixe só reacende quando a
  gema assenta, mesmo que `Progression.restore_ring` já tenha sido chamado.
- `DialogueBox`: `line_shown(index, line)` no início de cada fala; `lock_advance(true/false)`
  para segurar a caixa enquanto as gemas voam; `cue == "wait_2s"` já é tratado na caixa.

## Áudio
- R22 (vida baixa): falta um som `heartbeat` (batida grave, 60–80 Hz, curto) no
  CATALOG. Quando existir, o HUD toca 1 batida por pulso a −18 dB enquanto a
  vinheta estiver ativa (no máximo 8 s). Não liguei a chamada para o AudioQA não
  reprovar nome fora do catálogo.

## Técnico / dono de `scripts/levels/final_battle.gd`
- Texto do toast "As duas formas precisam cair JUNTAS." → "juntas" (pedido já
  feito pelo Roteiro; continua em caixa alta na base).
