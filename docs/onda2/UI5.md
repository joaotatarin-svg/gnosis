# UI5 — relatório do diretor de UI (Onda 5, branch `dir5/ui5`)

Base `origin/integracao/onda1` @ `37ea6f5` (inglês ligado). Todo Godot com `--audio-driver Dummy`.
Capturas (fora do git): `C:\gnosis-wt\_caps\ui5\` — `antes\`, `depois\`, `depois_en\`, `antes_en\`.

## Commits
- `5c19d00` toasts em fila durante card/cena, barras de chefe somem na rubrica, topo das travessias
  mais leve, rodapé da Estela com glifos, placa do aviso do menu, i18n lote 12, sonda UxShots5
- `938b566` Estela/Crônicas: corpo traduzido linha a linha (no inglês saía em PORTUGUÊS — achado
  novo), dica da Estela trancada com a tecla do dispositivo
- (este relatório + `docs/pedidos/ui5.md`)

## O que mudou (QA2)
- **#4 card × legenda/aviso (68)**: o que cobria "YALDABAOTH" era o TOAST "As duas formas precisam
  cair juntas." (chamado 1 quadro antes do card) — o toast continuava correndo atrás do card e
  sumia antes do fim. Agora `hud.toast_held()` (pausa, PauseStack, Cinemática/card, `scene_active()`)
  segura a fila; o toast que estava no ar volta pra frente e reaparece INTEIRO depois do card (respiro
  0,35 s em tempo real; tween ignora câmera lenta). A legenda (CaptionBar) também some e congela com
  cena no ar sem pausa (Staging/Cinemática).
- **#5**: conquista no meio da cena → mesma fila (sai 0,3 s depois da cena). Barras dos chefes
  recolhem com cena no ar (`_scene_k`), voltam depois; `hud.boss_bar_alpha()` p/ QA.
- **#10 topo**: legenda um passo menor (sem o `+1`: 13 px no M; P 11, G 16) e, se passa de 1 linha
  por pouco, desce 1 px para caber em 1 (mín. 11 px). Faixa curta 38→36 px, longa 55→51 px.
  Dica cujas teclas ela já usou na sessão não aparece (exceto dicas de leitura/sequência — com
  "·", texto sem tecla ou tecla repetida). Dicas já somem sozinhas em 4,2 s.
- **#13**: Estela "fechar" com o ícone do dispositivo (`InputGlyphs.Hint`, troca ao vivo: Esc / B);
  Crônicas trancadas "aperte J/X" fixo → tecla do dispositivo. Cards da Cinemática: API pronta
  `InputGlyphs.card_hint()` — o arquivo é da narrativa6 (pedido 1).
- **Menu**: placa escura atrás do aviso "progresso de versão anterior descartado" (QA2 §3).
- **Achado novo**: no inglês o CORPO da Estela (painel e Crônicas) saía em português (o bloco
  "linhas\nlinhas" não casa com a tabela). `Stela.body_text()` traduz linha a linha.

## Capturas (antes → depois)
- `ux5_cena_barras_toast.png`: antes "CONQUISTA · ACORDADA" sobre o Colosso durante a fala; depois sem toast.
- `ux5_topo_travessia.png` / `ux5_topo_legenda_longa.png` (+ `_640.png` reduzida a 640×360, legível).
- `ux5_estela_xbox.png`: antes "Esc fechar"; depois ícone B + "fechar". `depois_en\ux5_estela_xbox.png`:
  corpo em inglês + "close" (antes, `antes_en\ux5_estela_teclado.png`, corpo em português).
- `ux5_card68_*`: card limpo; `card68_depois` com o aviso das duas formas depois do card.
- `ux5_card_prologo_xbox.png`: ainda "qualquer tecla avança · Esc pula" (pedido à narrativa6).

## Validação
- `tools/UxShots5` (com janela): `UX5 RESULT: 15 ok, 0 falha(s)` (antes: 9 ok, 5 falhas);
  headless pt/en: Estela com corpo no idioma certo (2 ok cada).
- i18n: `build.py --strict` 1317/1317, 0 alertas, 0 problemas; `LangQA: 12 ok, 0 falha(s)`;
  EnFit `EN RESUMO: 0 falha(s), 58 aviso(s)` (os mesmos de antes).
- Editor headless: 0 `SCRIPT ERROR`.
- `validate.ps1`: 9 de 10 VERDE (Scripts, ScriptCheck, CodexQA 53, AudioQA 54, SaveQA 49, Puppet,
  Hero, Wave, TecnicoQA 43). **GnoseQA VERMELHO por instabilidade** "card de chefe" (tela 10): a caixa
  da tentação abre 0,9–1,6 s depois do `change_scene` em headless e o `skip_all` de 0,5 s passa antes —
  falha também na base `37ea6f5` (2 de 3). Com janela passou 2/2; com espera robusta passou 4/4
  (base e ui5). Pedido 3 ao dono da ferramenta.

## Não ficou bom / não testado
- Rodapé dos cards da Cinemática segue só-teclado até a narrativa6 aplicar o `card_hint()`.
- Não testei com controle físico (dispositivo forçado por `InputGlyphs.set_device`).
- A hierarquia do topo melhorou mas dica + legenda ainda podem aparecer juntas na chegada.
- #6 (retrato do Cego pequeno) é de encenação/arte (pedido 4).
- As capturas "antes" do card 68 não pegaram a colisão (ela dura ~0,2 s, no fade do card) — a
  prova é pela conferência (toast segurado + reaparece) e pela imagem [14] do QA2.
