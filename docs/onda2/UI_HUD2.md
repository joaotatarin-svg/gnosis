# UI-HUD2 — relatório da Onda 2b (dir2/ui-hud2)

## 1. Commits (sobre integracao/onda1 @ b04f413)
- 96ea7dd rubrica sem caixa (modo narration), velocidade do texto, legenda de chegada não fala por cima do chefe (#21), glifos via InputGlyphs opcional; sonda
- 0c08d8d rubrica escura só na abertura sem cue visual (anagnórise fica visível); sonda confere
- 78bff6f pedidos (formato do text_speed, #21 descarta a chegada, rubricas, dano)
- (este relatório)

## 2. O que mudou
- `scripts/ui/dialogue_box.gd`
  - **Rubrica (#22)**: fala sem falante com texto todo entre parênteses (ou `mode: "narration"`) não usa a caixa:
    texto em itálico, centralizado, sem os parênteses, sem blip. Escura (véu α 0,97) só na 1ª fala da caixa com cue
    vazio/`heartbeat`/`wait_2s` (abertura do jogo, Centro); nas outras, véu leve na base com a cena visível (roubo,
    anagnórise, finais). Campo `dark` da fala força. Troca caixa ↔ rubrica com fade cruzado de 0,45 s.
    API nova: `DialogueBox.is_narration(l)`, `narration_dark(l, i)`, `narration_text(t)`.
  - **Velocidade do texto**: `DialogueBox.text_speed()` lê `settings["text_speed"]` (0,5/1/2; 0, ≥10 ou "instant…" =
    instantâneo); multiplica letras/s e encurta as pausas de pontuação; instantâneo = fala já nasce inteira.
  - **Rodapé "continuar"** com o ícone do botão de avançar (Espaço / A / ✕…) via InputGlyphs; sem ele, como antes.
- `scripts/ui/caption_bar.gd`
  - **#21**: na 1ª barra de chefe/Campeão da tela, a legenda no ar sai e a fila de antes (chegada) é descartada;
    falas que nascem durante a luta passam. `in_boss_fight()` para QA. Velocidade do texto também vale aqui.
- `scripts/ui/hud.gd`
  - **Glifos (#33)**: com `InputGlyphs` presente (carregado por `load()`, compila sem ele), as dicas desenham o ÍCONE
    do dispositivo (tecla, Xbox, PlayStation, Switch, Deck) e o rótulo vem dele; o "usado" vira filete dourado sob o
    ícone. Sem o arquivo, o rótulo de texto antigo. `use_pad` segue coerente (a sonda/QA ainda podem forçar).
- `tools/ui_hud/hud_probe.gd`: cenários `rubrica`, `speed`, `bosscap`.
- `docs/pedidos/onda2_ui-hud2.md`.

## 3. Capturas (/home/user/caps/ui-hud2/)
- `cmp_rubrica.png` — antes (`antes/s01_dialog.png`: rubrica numa caixa comum) × depois
  (`depois/sem_glyphs/rubrica_0_escuro.png`: tela escura, itálico centralizado, sem caixa).
- `depois/sem_glyphs/rubrica_1_caixa.png` — a fala seguinte ("A Voz") volta à caixa (sonda: box_a 1,00, narr_a 0,00).
- `depois/sem_glyphs/rubrica_2_leve.png` — rubrica do roubo: véu leve na base, cena e Rei visíveis.
- `cmp_bosscap.png` — tela 1, Sophia andando até o Rei: antes a chegada "Anda: a névoa não espera ninguém" fica
  sobre a luta (sonda: showing=true 2 s depois da barra); depois some ao fim do card (showing=false, fila=0) e a
  fala nascida na luta aparece (`bosscap_1_fase2.png`).
- `depois/com_glyphs/glyphs_montage.png` — com a cópia do InputGlyphs: teclas "A D"/"Espaço" em keycap, Xbox
  X/Y em círculo colorido, rodapé "Espaço continuar". (Arquivo copiado só para o teste e removido; não commitado.)
- Sonda `speed`: letras visíveis após 0,55 s com 0,5×/1×/2×/0/"instant" = 13 / 28 / 52 / inteira / inteira.

## 4. Validação
`TIMEOUT=900 tools/validate.sh`:
```
Scripts        OK        14s  pass=0  code=0
ScriptCheck    OK         5s  pass=0  code=0
CodexQA        OK        16s  pass=53  code=0
AudioQA        OK        18s  pass=46  code=0
GnoseQA        OK        17s  pass=18  code=0
SaveQA         OK         4s  pass=41  code=0
PuppetQA       OK         2s  pass=0  code=0
HeroQA         OK         1s  pass=0  code=0
WaveQA         OK         2s  pass=0  code=0
TUDO VERDE
```
`tools/regressao/run_all.sh`: PASS 10/10 (B1 A1 A2 A3 A4 A5 A6 R1 R3 R10).
Com o InputGlyphs presente rodei só a sonda (`hints`, `rubrica`), não o validate completo.

## 5. O que NÃO ficou bom / não testado
- #21 descarta as falas de chegada das telas de chefe (não adia). Se alguma for importante, a Encenação precisa
  re-enfileirar depois da queda (pedido feito).
- Rubrica: o "som de coração" é do cue `heartbeat` (Encenação/Áudio); não verifiquei se toca. Na rubrica escura o
  HUD e a dica de controle ainda aparecem muito apagados atrás do véu (α 0,97).
- Rubrica longa no tamanho de legenda G pode passar de 2 linhas no véu leve (não medi todas; a caixa de 64 px cresce para baixo, até ~y 340).
- `text_speed`: o formato real da Opção do UI-MENUS2 ainda não existia quando terminei; assumi multiplicador (pedido).
- Números de dano não são desenhados pela UI (são do Combate: `scripts/fx/damage_number.gd`).
- Feel (tempo de fade, posição da rubrica leve) não testado por humano.

## 6. Pedidos
Em `docs/pedidos/onda2_ui-hud2.md`: UI-MENUS2 (formato do text_speed, assinaturas do InputGlyphs), ENCENACAO2
(chegada descartada nas telas de chefe, campos `dark`/`mode` da rubrica, usar `show_hint` para "apare/esquive"),
COMBATE2 (damage_numbers é dele).
