# Pedidos da NARRATIVA 6 (branch `dir5/encenacao5`, 18/10/2026)

## progressao6 — o pulo duplo
- O Soter (1º encontro, tela 17) chama `Progression.grant_double_jump()` na fala "(As mãos dele pousam...)" e
  confere `Progression.has_double_jump()`. Sem o método, cai na propriedade `double_jump` (que o player.gd do
  combate6 também lê); sem nenhum dos dois, só um `push_warning` (nesta base ainda não existe — por isso a
  SoterProbe passa "sem API"). Precisa persistir no save do run e voltar no checkpoint.

## combate6 — contra-ataque
- O ensino do contra-ataque (Staging._tutor_riposte) lê `player._riposte_t` (> 0 = janela aberta). Por favor
  exponham algo público (`riposte_open() -> bool` ou um sinal `parried(attacker)`) para eu não ler campo
  privado. Hoje funciona com o player do `dir6/combate6`; sem o campo, a dica só não aparece.

## level6 — o degrau de luz do Soter
- No descanso do Soter (telas 17/35/53 = Éons 1/3/5, offset 6, `mid` dos rest_points) eu crio um DEGRAU DE
  LUZ (plataforma de mão única, 72 px de largura, topo a 116 px do chão) a ±130 px dele (para o lado com chão).
  Mantenham esse trecho livre de plataformas/perigos/props de primeiro plano (≈ x Soter−200 … +200). Se quiserem
  um mini-desafio maior (2 degraus, um baú no alto), o gancho é `NpcEncounter._spawn_ledge()` — me peçam.

## ui5 — dicas "agora"
- `Staging.hint_now(segs)` usa `hud.show_hint_now(segs)` se existir; senão mexe na fila (`hints`, `_hint`,
  `_hint_gap`) como o level._tutor_hint. Um `show_hint_now` público no HUD seria o certo.
- (Onda 5, segue) retratos: "O Cego" → `cego_pequeno_<mood>`; Rei `revelado` → busto novo.

## chefes6
- `Narrative.archon_phase3(boss_id)` existe (1 linha, `urgent`). As de fase 2 também ficaram `urgent` e curtas.

## mapa6
- Beats seguem por número de tela (nada mudou). `Gnosis.setup_screen` toca `Narrative.node_arrival(node_kind)`
  (santuário, Arena, segredo, perigo, escalada) uma vez por tela, na calma.

## i18n
- Lote `assets/i18n/en/14_narrativa6.tsv` (30 textos). Tirei dos lotes 01/02/07 quatro ids que mudaram de texto.
  Obs. de ambiente: com `core.autocrlf=true` o `strings.csv` volta do checkout em CRLF e o `extract.py` perde
  as traduções de textos com quebra de linha (viram "órfãs"); normalizar para LF antes de extrair resolve.

## Pedidos para narrativa6 (de: arte / dir2/arte-gpt)

## Máscara/rachadura/olho do Rei presos ao quadro ("a máscara não parece colada")
`staging.gd` `_King._draw_over()` desenha a rachadura, o rosto preto com olho (o "disco preto") e a máscara
caindo em `Staging.HEAD` FIXO, enquanto o Rei agora troca de quadro desenhado (anda, respira) — o desenho
desliza em relação ao corpo. Duas opções (preferida a 1):
1. Usar os ESTADOS PINTADOS do atlas do Rei: `art.set_anim("mask_crack")` → `"revealed"` (sem desenhar o
   bloco `_blind`), `"dominion"` no roubo, `"triumph"`, `"sinking"` no colapso (detalhes em
   docs/onda2/ARTE_GPT.md, Pedido 8).
2. Se mantiver algum desenho por cima: prender na cabeça DO QUADRO com
   `var hp: Vector2 = art.head_point()` (coordenadas locais do `art`; `Vector2.INF` se faltar) →
   `over` em coordenadas de `_King`: `art.position + hp * art.scale` (respeitando `body.scale.x`).
Retrato do "…mãe?": `res://assets/painted/derived/portraits/cego_pequeno_olhando.png`.

## Cena da LEVEZA (Soter concede o pulo duplo) com quadros desenhados — de: arte (Fila 9, 18/10/2026, dir2/arte-gpt)
Folha `npc_soter_blessing_a` integrada (as células com a coluna de luz pintada ficaram FORA: a luz se mistura ao
corpo; a coluna agora é FX). Em `npc_encounter.gd`:
- **Soter** (`_art.set_anim`): `lift` (mãos erguidas, laço lento) na fala 0 e enquanto a luz desce; `offer` (estende a
  mão) na fala 4 ("Vê aquela luz no alto?"); `rest` (mãos juntas, em paz) antes do `fade`. `bless`/`talk`/`fade` iguais.
- **Sophia** (`player.visual`, um `CharacterArt`): `play_action("soter_look")` (olha pra ele, cajado em pé) na fala 0;
  `play_action("soter_land")` na fala 1 depois da subida (o tween de `position:y` de vocês continua); `play_action("soter_bow")`
  (agradece) na última fala. São poses `hold`: ficam até `visual.stop_action()` ou ela se mexer. A pose troca mesmo com o
  mundo pausado (o `play_action` redesenha na hora).
- **Coluna de luz**: `player.visual.bless_light(true)` (feixe aditivo macio que pulsa; anima pausado) no lugar do
  `_glow_sprite("glow", ...)` da fala 0, e `bless_light(false)` quando ela fica leve / no `_clear_glow()`.
Tudo protegido com `has_method` se quiserem (`has_action`, `bless_light`). Prova: `C:\gnosis-wt\_caps\arte-gpt\fila9\soter_board_crop.png`
(AnimQA `-- soter_board`).

## UI7 — painel da Estela PAUSA o jogo (decisão do chefe, QA7)
- Do lado da narrativa nada muda: a `CaptionBar` já some e congela com a árvore pausada (ou `PauseStack`), e
  a Crônica é desbloqueada no `open()`. Peço só que o painel use `PauseStack.push(self)`/`pop(self)` (como a
  descida do Centro) em vez de `get_tree().paused` direto, para não brigar com caixa de diálogo/card que
  também pausam. Se a Estela abrir com legenda no ar, a legenda volta depois (a fila espera).

## UI — card "YALDABAOTH" (QA7 #17)
- O card repetido saiu do meu lado (`Gnosis.boss_card` não repete o mesmo id na mesma tela por 8 s). O
  subtítulo EN que invade o Colosso é layout do card (Cinematic.boss_card) — se precisarem, encurto o
  título em `Gnosis.BOSS_TITLES["demiurgo"]`.
