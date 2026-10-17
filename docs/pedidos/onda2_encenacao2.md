# Pedidos da ENCENAÇÃO 2 (Onda 2b, 17/10/2026)

A Encenação 2 mexeu na abertura (tela 1), na tentação dos Arcontes, no card do
Campeão e nas dicas do duelo. Detalhe em `docs/onda2/ENCENACAO2.md`.

## UI-HUD2 (`scripts/ui/hud.gd`)
1. **Dica "agora"**: `show_hint_now(segs)` — põe a dica na frente da fila e
   encurta a que estiver na tela. O Level (`_tutor_hint`) já chama se existir;
   sem ela, faz `hints.push_front(segs)` (a dica espera a atual acabar, ~1 dica).
   Usado no 1º telegrafo aparável de um chefe ("brilho amarelo: [bloquear] apare
   no tempo", com 0,3 s de câmera lenta) e no 1º imparável do run ("brilho
   vermelho não se apara: [esquiva] esquive").
2. **Registro da UI** (ESTILO §1, "você" na UI): a dica da tela 3 diz
   "telegrafo amarelo: [K] **apara**" — imperativo de *tu*. Na UI: "apare".
3. Legenda × luta de chefe (#21): do lado da Encenação as falas de CHEGADA não
   tocam mais em tela de chefe (Rei: a Cena A esvazia a fila; Arcontes: a fala
   vai para a caixa da tentação; Mente: vai para a caixa do `final_pre`). As
   legendas de fase 2 dos Arcontes e o 7º Anel continuam, de propósito, durante
   a luta (são da luta). Se a UI decidir silenciar TODA legenda com chefe vivo,
   essas duas somem — combinar com o chefe antes.

## Combate2 (`scripts/entities/enemy.gd`)
- O Campeão agora tem card com o nome do bot ("O GLUTÃO · Guardião do santuário
  da Fome"), mas a barra do chefe ainda mostra `display_name = "Campeão da Fome"`.
  Sugestão: "Glutão, guardião do santuário" (ou o nome do Bestiário) — o card e
  a barra falando a mesma coisa. A dificuldade também se chama "Campeão".
- Tentação em cena (#18): o Arconte nasce ANTES da conversa com
  `process_mode = DISABLED` (sem IA) e é "acordado" no gatilho da zona. Se o
  Enemy ganhar animação de entrada/"spawn", ela deveria tocar quando ele acorda
  (`process_mode` volta a INHERIT), não no `_ready`.

## Técnico2
- `final_battle.gd` já chama `RunManager.screen_rng(68)` se existir (senão usa um
  RNG próprio semeado por `hash("final_68")`). Quando o `screen_rng` entrar, o
  sorteio passa a ser o dele sem mudar nada aqui.

## Dono do `tools/gnose_qa.gd` (Roteiro)
- As falas da intro que viraram legenda estão em `Narrative.walk_arrival(1)` (o
  GnoseQA já mede como legenda: cabem e não repetem). Nada a fazer; só ciência.

## Áudio2
- Centro sem música até o 1º caco: conferido — `Audio._update_center_music()` já
  segura a faixa até o 1º caco; a Staging (`descend`) só dá `stop_music(0)` e o
  `level._restore_echo` não toca música. Nada pendente do lado da Encenação.
