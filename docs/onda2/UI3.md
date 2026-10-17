# UI3 — relatório do diretor de UI (Onda 3, branch `dir3/ui3`)

Base: `origin/integracao/onda1` @ `ab250ea`. Sessão local (RX 7600), todo Godot com `--audio-driver Dummy`
e janela em `--position 4000,4000`. Capturas (fora do git): `C:\gnosis-wt\_caps\ui3\` (`antes\`, `depois\`).

## 1. Commits
- `7c369fa` Retratos por emoção na DialogueBox: campo `mood` (16 retratos) + pedidos à encenação
- `1be5e12` M1 legenda no topo · C2 dicas/combo/faíscas somem com cena · H2 faíscas atrás da loja · P3 Provação com ícones · UxShots com conferências
- `5ad51e3` Estelas ilustradas (18 afrescos) no painel e nas Crônicas; texto longo cabe no painel das Crônicas
- `e0b74da` Menu principal com a ilustração `menu_bg_a`
- `9254a03` Acabamento: barra do chefe, FASE II, medalhão I/II, toast de conquista, `low_health_pulse`, painel da Estela ≤ 330 px
- (este relatório)

## 2. O que mudou
- **M1 — legenda de caminhada** (`caption_bar.gd`): saiu da base (ficava nas canelas da Sophia com o zoom 1,2 e cobria
  telegrafos de chão) e foi para o **topo central**, logo abaixo da faixa de dicas (y 66 na base 640×360, 420 px de
  largura, véu α 0,5 — mais discreta). Altura pelo texto real (1–3 linhas). Posição FIXA (o chefe não a empurra mais).
  O HUD sabe onde ela está (`hud.set_caption_band`) e o toast nasce logo abaixo dela. `CaptionBar.band_rect()` p/ QA.
- **C2 — HUD em cena** (`hud.gd`): com `DialogueBox` aberta, `Cinematic` na raiz ou `Staging.is_active()` (se a
  encenação expuser), somem as dicas de controle, o combo e as faíscas/arma (fade 0,17 s). Medalhão, barras e Anéis
  ficam (a cena B usa as gemas do HUD). A dica escondida não "queima": o relógio dela espera a cena acabar.
- **H2 — faíscas atrás da loja**: com a árvore pausada o contador mostra o total real (antes congelava o valor velho).
- **P3 — Provação** (`codex_trial.gd`): a faixa de dicas virou `InputGlyphs.Hint` (ícones desenhados: tecla, Xbox,
  PlayStation, Switch, Deck) sobre uma placa escura; troca sozinha com o último dispositivo. `hint_label` continua
  (invisível) com o mesmo texto — contrato da sonda de menus.
- **Estelas ilustradas**: `assets/stelae/<id>.png` (18, ordem de `Gnosis.STELAS`, lado maior 320 px) recortadas por
  `assets/stelae/build_stelae.py` (acha as margens pretas entre os painéis). `Stela.art_for(id)` + `Stela.ArtFrame`
  (moldura de ouro com cantoneiras; trancada = pedra escura sem spoiler). Painel de leitura: afresco 132×126 à
  esquerda, texto à direita (painel 600 px; cabe em ≤ 330 px de altura nas 18 — GnoseQA). Crônicas: miniatura 42×40
  ao lado do Éon/título; o corpo encolhe 12→11→10 px até caber (o painel não vaza mais da tela; medido nas 18).
- **Menu**: `assets/menu/menu_bg.jpg` (de `menu_bg_a.png`, JPEG q92, 402 KB) em tela cheia, deriva lenta de 16 px em
  18 s, poeira de luz na metade direita, sombra em degradê atrás da coluna de botões e no pé da tela. A Sophia desenhada
  e o rótulo "SOPHIA" saíram (a ilustração já tem a Sophia). Sem o arquivo, volta o fundo antigo.
- **Retratos por emoção**: `assets/ui/portraits/{sophia,rei,soter,velkar}_<mood>.png` (128×128, máscara circular,
  despill do magenta) por `assets/ui/build_mood_portraits.py`. `DialogueBox.portrait_for(falante, mood="")`,
  `speaker_id()`, `mood_for()`; campo `mood` na fala (formato em `docs/pedidos/ui3.md`); sem mood = neutro
  (Sophia `neutra`, Rei `regio`, Soter `sereno`, Velkar `elmo`). A legenda também lê o `mood`.
- **Barra do chefe**: placa α 0,84 (era 0,62), barra 8 px, ouro vivo `e3aa48→fff2c6` na fase I e carmim-brasa
  `c43a2e→ffb27a` na fase II; "FASE II" na mesma linha do subtítulo (antes descia para y 362 e saía cortado);
  medalhão I/II com raio 8,5 e algarismo de 7 px centrado.
- **Toast de conquista**: `Achievements.unlocked(id)` → "Conquista · <título>". Toasts agora fazem FILA (Crônica +
  conquista juntas aparecem uma depois da outra).
- **Vida baixa**: a vinheta chama `Audio.low_health_pulse()` uma vez por pulso (0,9 Hz, no pico); o Áudio decide
  volume e intervalo mínimo.
- `tools/ux_shots.gd`: novas capturas (`dialogo_mood_*`, `cronicas_longa/trancada`, `estela_*`, `hud_arconte_legenda`,
  `legenda_toast`, `toast_conquista`, `hud_vida_baixa`, `hud_provacao_pad`, `hud_arconte_fase2b`) e conferências
  `UX CHECK` (C2, H2, M1, P3, moods, afrescos, conquista, batimento).

## 3. Capturas (antes × depois) — `C:\gnosis-wt\_caps\ui3\depois\`
- `cmp_M1_legenda.png` — antes: legenda na base (sem chefe já colada ao chão; com chefe subia às canelas). Depois:
  legenda no topo durante a luta do Athoth (fase II), longe dos pés e do telegrafo.
- `cmp_C2_dica_no_dialogo.png` e `cmp_retrato_mood.png` — antes: "U · usar o Anel" atrás da rubrica e da escolha
  do Yaldabaoth. Depois: sem dica; retrato `rei_revelado`.
- `cmp_P3_provacao.png` — depois: botões Xbox desenhados (Analógico, A, X/Y, B, LB, RB, RT).
- `cmp_menu.png` — fundo novo com Sophia/cidade/Anéis; botões legíveis sobre a metade escura.
- `cmp_cronicas.png`, `ux_cronicas_longa.png`, `ux_cronicas_trancada.png`, `ux_estela_monada.png`,
  `ux_estela_nag_hammadi.png` — afrescos no painel e miniatura nas Crônicas; a mais longa cabe.
- `cmp_barra_chefe.png` (antes / depois fase I / depois fase II) — FASE II visível; `ux_toast_conquista.png`,
  `ux_legenda_toast.png` (toast abaixo da legenda), `legenda_640.png` (legível reduzido a 640×360).

## 4. Validação
`tools/validate.ps1 -Path C:\gnosis-wt\ui3` → **TUDO VERDE (10 etapas)**: Scripts, ScriptCheck, CodexQA 53,
AudioQA 54, GnoseQA 18, SaveQA 41, Puppet/Hero/Wave, TecnicoQA 36.
UxShots: `UX NAV: 9 ok, 0 falha(s)` · `UX CHECK: 13 ok, 0 falha(s)`.
MenuProbe (`tools/ui_menus`): `UIM RESULT: 112 ok, 0 falha(s)`. HudProbe: t1, pause, t68boss, toast, hints, pad,
death, bosscap, card rodaram sem `SCRIPT ERROR`.
Obs.: o commit `5ad51e3` sozinho deixava o GnoseQA vermelho (painel da Estela 337 px); corrigido em `9254a03`.

## 5. O que NÃO ficou bom / não testado
- Ninguém OUVIU o `low_health_pulse` (silêncio obrigatório); só conferi que o HUD chama.
- C2 depende de caixa/Cinemática. Encenação sem caixa aberta precisa do `Staging.is_active()` (pedido).
- Os retratos do Rei vêm mais FRONTAIS que 3/4 (defeito da folha do GPT, já no manifesto); a Sophia tem uma franja
  rosada fina no cabelo em 2–3 retratos (só perceptível ampliando).
- Nenhuma fala usa `mood` ainda: quem anota é a Encenação (narrative.gd). Até lá, todos mostram o neutro — e o
  neutro da Sophia/Rei/Soter/Velkar já é o retrato NOVO (mudança visível em todo diálogo).
- Crônicas: Estelas longas descem a 10 px de corpo (legível a 1280×720; em 640×360 nativo fica pequeno).
- Os Anéis do menu saem cortados no topo (a pintura é 3:2; a tela 16:9). Feel da deriva não visto por humano.
- O número de dano congelado na cena (C1) é do Combate (pedido).
- Captura com controle físico: não testei com controle real; o modo controle foi forçado por `InputGlyphs.set_device`.

## 6. Pedidos
`docs/pedidos/ui3.md`: Encenação3 (formato `mood` — publicado no 1º commit; `Staging.is_active()`), Combate3 (C1
número de dano congelado), Técnico3 (nota sobre a legenda no topo).
