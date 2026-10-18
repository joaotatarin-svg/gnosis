# Pedidos da ENCENAÇÃO 5 (branch `dir5/encenacao5`, 17/10/2026)

## 1. UI (ui5) — retratos novos da arte (`assets/painted/derived/portraits/`)
- **"...mãe?" (cena D, tela 68)**: o falante agora é `Narrative.CEGO` = **"O Cego"** com `mood: "olhando"`
  (antes era Yaldabaoth/quebrado = retrato do Rei de máscara rachada, QA2 #6). Hoje a caixa mostra SEM
  retrato (speaker_id não conhece "cego"). Pedido em `DialogueBox`:
  - `speaker_id`: `"cego"` → id `cego` (antes do teste de "rei");
  - `MOODS["cego"] = ["olhando", "assustado", "sereno", "aninhado"]`, padrão `olhando`;
  - caminho: `res://assets/painted/derived/portraits/cego_pequeno_<mood>.png`.
- **Rei revelado**: o mood `revelado` (falas do roubo depois da máscara e `final_pre`) pode usar o busto novo
  `res://assets/painted/derived/portraits/rei_revelado.png` (sem máscara, olho âmbar) no lugar de
  `assets/ui/portraits/rei_revelado.png` (máscara rachada) — combina com o Rei pintado na cena.
- **Toasts e barras de chefe na cena D (QA2 #5)**: vi que o `dir5/ui5` (5c19d00) já segura os toasts em fila
  durante card/cena e esconde as barras na rubrica. Do meu lado o contrato continua: `Staging.is_active()`
  (cena dirigida, descida do Centro ou ilustração na tela). Não testei os dois juntos (branches separados).

## 2. PRODUÇÃO / ARTE — decalque da fenda do chão (roubo, tela 64)
A fenda já abre por código (`Staging._FloorCrack`). Se vier a sequência pintada, ela toca no lugar sozinha:
`res://assets/cinematic/fx_floor_crack_a.png` (ou `res://assets/painted/fx/fx_floor_crack_a.png`), **quadros
quadrados lado a lado numa linha**, fundo transparente, vista de cima já achatada OU frontal (o código achata
0,35 na vertical), a fenda saindo do CENTRO de cada quadro. Nº de quadros = largura/altura.

## 3. CENÁRIO — Estela na frente da Sophia (telas 64 e 68)
Nas capturas das cenas (64 roubo, 68 anagnórise) a Estela-obelisco do descanso fica NA FRENTE da Sophia
(ela fala "atrás" da pedra). É do posicionamento da Estela/descanso, não da câmera. Sugestão: Estela a
≥ 90 px do ponto onde a Sophia para nas cenas, ou atrás dos personagens (z). Prova:
`C:\gnosis-wt\_caps\encenacao5\depois2\t64_sheet.jpg`. (O pilar sobre o Soter na 17 segue — pedido 6 da Onda 3.)

## 4. ESTABILIDADE (estab5)
A `GnoseQA` da base 37ea6f5 falha por tempo (a caixa da tentação da tela 10 abre depois do `skip_all`):
"card de chefe congela/liberou" FAIL também SEM as minhas mudanças. Com a `tools/gnose_qa.gd` do
`dir5/estab5` (e6e8b98) passa 20/20 no meu branch. (Numa 2ª rodada o validate passou verde aqui — é intermitente.)

## 5. I18N
"O Cego" → "The Blind One" entrou pelo `tools/i18n` (lote `assets/i18n/en/11_encenacao5.tsv`, linha nova no
`strings.csv`, `en_table.gd`, `gnosis_text.csv`, `en.po`). LangQA verde. Revisem o termo.
