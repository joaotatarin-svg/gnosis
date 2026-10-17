# Pedidos da ENCENAÇÃO (Onda 2, 17/10/2026)

A encenação das cenas A–D mora em `scripts/levels/staging.gd` (o Level abre as
falas por `stage().play(falas, escolhas, "cena")`). Tudo abaixo já é chamado de
forma que compila sem a API; quando ela existir, passa a valer sozinha.

## UI (`scripts/ui/dialogue_box.gd`, `scripts/ui/hud.gd`)
1. `DialogueBox.lock_advance(on: bool)` — a Staging trava o avanço enquanto os 7
   Anéis voam no roubo (≈6 s) e destrava ao chegar a 7ª gema. Sem isso, se o
   jogador avançar, as gemas que faltam chegam todas de uma vez (funciona, mas
   perde o ritmo "um a um").
2. `cue == "wait_2s"` (2 s sem aceitar avanço) — Centro, santuário do Silêncio, Soter 2.
3. `hud.restore_ring(i)` — chamado na anagnórise quando cada Anel chega ao peito
   da Sophia (o inverso do `detach_ring`).
4. O HUD roda com o mundo pausado só durante o roubo (a Staging põe
   `process_mode = ALWAYS` e devolve no fim); se o HUD passar a fazer isso
   sozinho, nada quebra.

## Áudio (`scripts/autoload/audio_manager.gd`)
1. Centro (tela 65) SEM música até o 1º caco (M7/M8): a Staging para a música na
   descida, mas `_on_state_changed(PLAYING)` (ex.: voltar do menu de pausa) e
   `track_for_screen()` religam `centro`. Sugestão: `track_for_screen` devolver
   `""` (silêncio) no Centro enquanto `Progression.restored_rings` estiver vazio.
2. SFX ★ que não existem e a Staging troca por um substituto: `heartbeat` (M1;
   hoje `boss_step` duas vezes — se `heartbeat` existir, é usado), palmas do Rei
   (hoje `parry` baixo), respiração de criança (hoje `whisper`).

## Combate / chefes (`scripts/entities/enemy.gd` ou `scripts/fx/character_art.gd`)
1. O chefe que nasce junto com o CARD DE CHEFE não aparece durante o card: o
   card pausa o mundo no quadro em que ele nasce e o `CharacterArt` só desenha
   no `_process`. Na tela 1 o Rei de cena (Staging) segura o lugar até o card
   acabar. Visto na captura da tela 1 (`t1_015..018_livre*.png`); não conferi
   as outras telas de chefe, mas o mecanismo é o mesmo. Sugestão: um
   `queue_redraw()`/pose inicial no `_ready` do visual.
