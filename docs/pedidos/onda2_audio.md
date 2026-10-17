# Pedidos do Áudio (Onda 2, 17/10/2026) a outros agentes

> API nova em `scripts/autoload/audio_manager.gd` (detalhe em `docs/AUDIO.md` §Tema da Voz e API das cenas).
> Chame de forma que compile sem ela: `if Audio.has_method("voice_theme"): Audio.call("voice_theme", "santuario")`.

## Encenação (`scripts/levels/staging.gd`, `scripts/levels/level.gd`)

Li a Staging no worktree `encenacao` (sem editar). Ajustei os sons do `Audio.cue()` para baterem com as
escolhas de lá (chime, mask_cracks, sink, reclaim, pitch 0,85 do tema sozinho). O que falta do lado de lá:

1. **BUG — roubo em loop.** `_b_mask_falls` termina com `Audio.play_music("roubo")` (loop = true). `roubo.ogg`
   NÃO tem ponto de loop (degrau de 32 dB na volta — ver AUDIO.md). Se a cena durar mais que a faixa, ela
   recomeça do nada. Troque o bloco inteiro (tema a 0,75 + tween de 3 s + corte) por
   `Audio.voice_theme("roubo")` — faz o mesmo por relógio REAL (o tween de 3 s pode disparar cedo sob carga)
   e chama `play_music("roubo", false, 1.0, 0.0)`. No mínimo: `Audio.play_music("roubo", false)`.
2. **Coração da intro dobrado.** `_beat()` toca `heartbeat` duas vezes (0 e 0,28 s). O arquivo `heartbeat`
   (novo, síntese) JÁ tem as duas batidas lub-dub (1,9 s). Com `heartbeat`, chame UMA vez a 0 dB; mantenha
   o par só para o fallback `boss_step`.
3. **Centro: pode apagar** `level.gd` `_restore_echo` linhas `Audio.play_music("centro")` +
   `set_music_layer_volume(0.35 + …)`. O Audio já faz isso sozinho no sinal de caco — e agora com a MESMA
   curva (0,35 + 0,65·k/6), então manter também não briga (só é redundante).
4. **Santuário mais audível (sugestão).** Hoje: `play_music("theme")` + camada 0,45 (−9,9 dB) + ducking do
   diálogo (−9) = −19 dB: com música em 0,6 no slider, quase some. `Audio.voice_theme("santuario")` dá −3 dB
   (+ ducking = −12) e `Audio.voice_theme("")` no fim volta à faixa da tela.
5. **Tema sozinho:** `Audio.voice_theme("sozinha")` (0,85, entra em 4 s, ducking de diálogo só −3 dB) no
   lugar de `play_music("theme", true, 0.85)` + camada 0,7.
6. **Gemas:** no roubo `Audio.ring_note(i)` (sobe 1 semitom por gema, como o ROTEIRO pede) no lugar de
   `play_sfx("ring_steal")`; na volta `Audio.ring_note(i, true)` (desce 1 semitom) no lugar de
   `play_sfx("shard", 0, -2)`. Bônus: por 1,5 s depois de um `ring_note` o sinal de Anel do Progression não
   toca som próprio (o `steal_rings()` final não vira a 8ª gema).
7. **Sons ★ novos (síntese, existem):** `clap` (2 palmas secas e lentas, sala de pedra) para `_b_applause`;
   `child_breath` (respiração pequena) para `colossus_shrinks` (hoje `whisper` −6).

## UI-HUD (`scripts/ui/hud.gd`, `scripts/ui/dialogue_box.gd`)

- `hud.gd` `detach_ring` toca `play_sfx("ring_steal")` — use `Audio.ring_note(i)` (tom sobe por gema) se
  existir. Se a Staging também tocar, fica dobrado: combinem um dos dois (sugiro o HUD, que sabe o índice).
- `dialogue_box.gd` toca o blip com `Audio.play_sfx(_blip)`. `Audio.play_blip(falante)` usa o bus Voice
  monofônico (a sílaba nova corta a anterior, como boca) e o mapa falante→voz — prefira-o.

## Técnico (`save_manager.gd`) — repetido da Onda 1
- Fallback de volume sem a chave no save: 0,7 (Master) e 0,6 (Música), não 0,9/0,7.
