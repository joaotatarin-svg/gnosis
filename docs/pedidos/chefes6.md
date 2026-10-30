# Pedidos do Chefes6 (28/10)

## Para o Polimento7 (hurtbox genérica por frame_geometry)
- O Rei (e o Rei-Mentira da final) agora têm uma caixa PRÓPRIA do corpo desenhado: `BossBodyBox`
  (`scripts/entities/bosses/boss_body_box.gd`, nó filho `BodyBox` do Enemy, 6 faixas por quadro). Quando ela liga,
  ela DESLIGA a `Hurtbox/HurtShape` genérica (`disabled = true`) para não contar 2 acertos por golpe (R4).
- Pedido: no `_fit_hurtbox`/frame_geometry genérico, **pule inimigos com filho `BodyBox`** (ou, se a sua versão
  cobrir o manto por faixas/polígono com o mesmo resultado, me avise que eu removo a BodyBox e volto para a genérica).
  Não religue a HurtShape desses inimigos.
- A tabela de faixas sai de `tools/chefes6/body_slabs.py <char> <saida.gd>` e pode servir a qualquer chefe por quadros.
- Medida/prova: `tools/chefes6/body_cover.py` (todos os quadros, sem Godot) e `tools/chefes6/ReiProbe.tscn`.

## Para a Progressão (curva de melhorias) — 28/10
- A vida dos chefes sai de `BossTuning.boss_health` = golpes-alvo × dano médio da arma ESPERADA na tela
  (`EXPECTED_WL`: 1@1, 2@10, 3@28, 4@46, 5@64). No re-teste 3.1 (QA7) o run chegou com arma 3 na 10–15, 4 na 28 e
  5 na 46 — um nível ACIMA — e com 5–7 mil faíscas sobrando. Se a sua curva nova mudar quando cada nível chega,
  publique `Progression.expected_weapon_level(tela)` (o BossTuning já usa se existir) — aí a vida acompanha sozinha.
- O que fiz do meu lado (pelo padrão, não pela vida): "guarda alta" nos chefes do fim (golpe no neutro/no golpe dele
  vale menos; as janelas de punição seguem iguais). Não mexi na economia.

## Para o dono do tools/shot.gd (Estab/Técnico) — 28/10
- `hurt` (tira 55 % dos chefes na metade dos quadros) acerta o Arconte ENCENADO antes do gatilho (zona inativa).
  Agora o chefe encenado é intocável (Chefes6), então nesses casos o `hurt` não força a fase 2. Pedido: aplicar o
  `hurt` só quando `ativa=true` (zona trancada), ou andar a Sophia até o gatilho antes.

## Para o Áudio (Áudio7 ou sucessor) — 29/10
- Juízo da Coroa (Armupiel): a postura começa com `mask_light` emprestado (luz da coroa). Pedido: um som PRÓPRIO
  `stance_crown` (espadão cravando no chão + coro curto de luz, ~0,5 s) — R11: evento novo, som novo. Chamo via
  `BossBrain.sfx` (só toca se estiver no CATALOG; trocar o nome numa linha de `boss_armupiel.gd`).
- Pústulas (Belias): hoje mudas. Pedido: `pus_grow` (bolha brotando, curto, grave baixo, máx. 1 a cada 0,25 s) e
  `pus_burst` (estouro úmido) — o Estouro hoje soa só pelo `tell_unblock` do contorno.

## A MENTIRA DO REI (29/10) — o que o chefes6 expõe e o que falta de cada um
Sinais (em `scripts/entities/bosses/boss_rei.gd` / `boss_brain.gd`; o cérebro está no grupo `"boss_brain"`):
`king_kneel_start` / `king_kneel_end` (cada ajoelhar), `lie_exposed(id)` ("rei"; 1×/luta), `lie_hint_step(n)`
(1 e 3 no início da luta; 2 durante um ajoelhar se ≥ 45 s de luta ou 2 ajoelhares sem o Desmentido, 1×, só se
`GameManager.lie_hints` não existir ou for true). Estado: `brain.lie_was_exposed` e `enemy.get_meta("lie_exposed")`.
- **Narrativa:** C6a "Ele se curvou? Jamais, né?" no `lie_hint_step(2)`; C6b "Jamais, né?" no `lie_exposed` (sem voz se a
  C6a já tocou); `king_fall(exposed)` lê `lie_was_exposed`/a meta (se false, a mentira cai na queda: F1b/F2b).
- **UI:** (a) a barrinha de 8 s junto do aviso (hoje só o toast "Mentira exposta · o Rei fica 8 s sem guarda", que pus
  por delegação); (b) Opções → "Dicas" = `GameManager.lie_hints` (padrão true); (c) Bestiário "O que ele diz" + degrau 3
  ("Repare nele depois da Mão.") e Crônicas "Mentiras desvendadas N/8".
- **Arte:** estado `"kneel"` na receita do Rei (o `d_kneel` antigo ou uma pose HD de joelho): o cérebro já pede
  `set_anim("kneel")` enquanto ele está ajoelhado SE o estado existir. Hoje a curva lê pelo olho que desce 132 px + o
  "dong"; o corpo HD fica de pé (ver `_caps\chefes6\mentira2\s1_ajoelha_sheet.png`). Carimbo sobre o `mask_crack`.
- **Áudio:** `king_kneel` (joelho na pedra, grave; hoje uso `king_step`) e `mask_crack` (máscara rachando; hoje
  `mask_light`).
- **Por delegação (registro):** título do card do Rei em `scripts/autoload/gnosis.gd` → "“Um rei jamais se curva.”";
  linha órfã do título antigo tirada de `assets/i18n/en/06_estelas_b.tsv`; lote novo `assets/i18n/en/17_chefes6_mentira.tsv`.

## REI AJOELHADO (Arte, 29/10) — estados `kneel` e `kneel_cracked` publicados (atlas `rei_frames`)
- **Já funciona sem mexer em nada:** o `boss_rei.gd` pede `set_anim("kneel")` quando está `_low` e o estado existe → agora existe
  (12 quadros, laço a 5 qps, respiração/manto/capuz em camadas; a pintura vem **SEM o orbe-olho**, que é o sprite do jogo).
- **Pedido 1 — a máscara rachada (1 linha em `boss_rei.gd`, na linha do `_lie_t > 0.0`):**
  `e.visual.set_anim("kneel_cracked" if _has_state("kneel_cracked") else "mask_crack")`
  (hoje toca o `mask_crack` DE PÉ durante os 8 s; o `kneel_cracked` é a pose ajoelhada com a fenda dourada pulsando.
  O `mask_crack` de pé segue para a cena da queda/Staging.) Provado com esse remendo local (não commitado por ser seu arquivo).
- **Pedido 2 — o orbe-olho na mão:** na pintura a mão fica aberta, sem orbe; o orbe do jogo deve pairar onde a mão o seguraria.
  Ponto em px do ATLAS relativo à âncora do quadro (x para a DIREITA da pose desenhada, y para CIMA da âncora do pé):
  `kneel` (+100,9 ; −64,5 acima) · `kneel_cracked` (+101,1 ; −64,9). Em mundo: multiplique por `k = hw·body_frac/body_px`
  (a mesma escala do corpo; o Rei de pé usa o mesmo `k`) e espelhe em x se o visual estiver `flip`. Hoje `ORB_LOW` deixa o orbe ~50 px
  acima/à direita desse ponto (ver `_caps\arte\rei_kneel\rei_kneel_antes_depois.png`); o `_eye_box` deve ir junto.
- **Pedido 3 — BodyBox dos quadros novos:** `docs/pedidos/rei_body_kneel.gd.txt` (24 linhas `kneel_a00..11` e `crack_a00..11`,
  16 faixas, fill 0,30, geradas por `body_slabs` do repo) para colar em `rei_body_data.gd` (ou regenerar o arquivo todo com o
  comando do cabeçalho do .txt). A Arte NÃO mexeu em `rei_body_data.gd`.
- Âncora: pela estola (faixa dourada da frente) no mesmo x do Rei de pé; o chão da rachada (~32 px mais alto na pintura) sai pelo pé.
