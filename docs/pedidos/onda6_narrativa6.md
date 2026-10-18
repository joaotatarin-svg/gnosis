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
