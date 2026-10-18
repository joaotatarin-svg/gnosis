# ENCENAÇÃO 5 — relatório (dir5/encenacao5, 17/10/2026)

Base `origin/integracao/onda1` @ 37ea6f5 + merge de `origin/dir2/arte-gpt` (e2fc799, Rei revelado e retratos).
Capturas (fora do git): `C:\gnosis-wt\_caps\encenacao5\` — `antes\`, `depois\`, `depois2\`, `depois3\`.

## O que mudou
- **QA2 #1 — quadro de diálogo geral** (`staging.gd`): a Staging nasce com a tela (`level._ready`) e vigia
  TODA `DialogueBox` (sinal `node_added`), da cena ou direta. Ao abrir: câmera desce até os pés da Sophia
  ficarem em y 226 da base 360 (198 quando a caixa cresce para as escolhas), centrada entre ela e o
  interlocutor mais perto (Rei-figurante, NPC ou chefe visível a ≤ 420 px). Os `_cam_to` das cenas respeitam
  a mesma altura. Ao fechar, solta 2 quadros depois — se outra caixa abriu, só reenquadra (sem sobe-desce).
  Cenas A/B abrem para `KING_ZOOM` 0,8: o Rei inteiro cabe com os pés dela acima da caixa.
- **QA2 #9 — Sophia parada na conversa**: com caixa aberta e ela em pé no chão (não morta/ferida), o
  `Visual` vai para `idle` e respira (process ALWAYS só no Visual; player.gd intocado).
- **QA2 #6 — "...mãe?"**: falante `Narrative.CEGO` = "O Cego", mood `olhando` (retrato pedido à UI).
- **QA2 #2 — roubo (64)**: o Rei usa os quadros pintados da arte: `mask_crack` → `revealed` (máscara cai),
  `triumph` (o nome), `dominion` ("os sete eram meus filhos"), `sinking` (motor). Espelhados para olhar para
  a Sophia. Nada desenhado por cima da cabeça (feedback do João: "máscara não colada"); na tela 1 a rachadura
  também é o quadro `mask_crack`. Sem os quadros, cai no recorte provisório do retrato
  (`assets/cinematic/rei_mascara_rachada.png`, `tools/encenacao/rei_mascara_rachada.py`).
- **Feedback do João — rachaduras e afundar**: os riscos pretos (Line2D) viraram `_FloorCrack` (ramos no
  plano do piso, largura variável, borda escura suave, núcleo âmbar aditivo, faíscas, poeira e tremor em 4
  pulsos). O Rei afunda RECORTADO pela linha do chão (`_Clip`, `clip_children`) com a borda acesa — não
  achata mais. Gancho para o decalque pintado `fx_floor_crack_a.png`.

## Capturas (antes → depois)
- Tela 64: `antes\t64_sheet.jpg` (disco preto, cabeça cortada, Sophia atrás da caixa) →
  `depois2\t64_sheet.jpg` (Rei pintado revelado/triunfo/domínio, Sophia acima da caixa).
- Afundar: `sink_antes_depois.png` (riscos pretos, Rei achatado → fendas de luz, Rei entrando no piso) e
  `sink_zoom.png`; a fenda isolada abrindo: `crack_seq.png`.
- Tela 1: `depois\t1_sheet.jpg` (Sophia e Rei inteiros acima da caixa). Tela 68: `depois\t68_sheet.jpg`
  (chegada da Mente com a Sophia no quadro; "O Cego" sem retrato do Rei). NPC: `npc17_antes_depois.png`
  (correndo → parada). Diálogo comum (tela 11): `depois\t11_sheet.jpg`.
- Desde o pedido do João (está jogando), capturas em janela 320×180 fora da tela.

## Validação
`tools/validate.ps1`: TUDO VERDE (10 etapas; GnoseQA 18). LangQA verde com "The Blind One".
Obs.: a GnoseQA da base falha às vezes por tempo (ver pedidos §4).

## Limites honestos
- Sondas teleportam a Sophia: nas cenas 64/68 ela fica junto da Estela, que fica NA FRENTE dela (pedido ao
  cenário). Com caminhada real não filmei.
- Retratos novos (Cego pequeno, Rei revelado) dependem da UI.
- O quadro de diálogo mexe na câmera em TODA caixa (morte, Anel ganho, Éon): sensação a confirmar jogando.
- As poses espelhadas do Rei revelado: conferir se a arte já vinha virada de propósito.
