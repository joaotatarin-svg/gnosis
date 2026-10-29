# PERIGOS7 — perigos de fase com arte pintada (Onda 7)

Branch `dir7/perigos7` (base `origin/integracao/onda1`; com merge de `origin/dir7/audio7` 6df9411).
Pedido: trocar o desenho por código dos perigos de fase pelas folhas pintadas do GPT (FILA 11: hz_1..hz_7).
A LÓGICA (dano, áreas, tempos, ritmos) NÃO mudou: só o visual e, a pedido do chefe, os nomes dos sons.

## 1. O que mudou
- **Recorte** — `tools/hazards7/cut_hazards.py` (+ `hz_common.py`): lê `artes/gpt/hazards/hz_*_a.png` (cópias das
  originais). Usa a chave magenta do `clean_sheets.key_array`; a hz_1 tem alfa real, e o halo escuro de alfa baixo é cortado.
  A grade fina é apagada: ±4 px nas divisórias, e na hz_1 a divisória horizontal fica em y≈442, não em 512. Cada componente
  conectado vai para a célula do seu CENTRO, porque o totem da hz_4 passa de 512 e as correntes da hz_7 sobem acima.
  Também: tela comum para os estados de um mesmo perigo (âncora única), troca do rosa vazado por dourado em brilho
  translúcido e silhueta branca (`_sil`) de cada peça para o contorno de aviso.
  A saída fica em `assets/painted/hazards/`: 25 peças e 67 PNG, ~2,5 texels por pixel de mundo, **mipmaps ligados nos
  `.import`** e catálogo `hazards_data.gd` (`const DATA`; um .json não entraria no export).
- **Catálogo** — `scripts/fx/hazard_art.gd` (`HazardArt`): `has/tex/sil/size/anchor/point`, `draw` (âncora, rotação,
  escala), `draw_part` (recorte de faixa), `draw_chain` (elos ladrilhados), `draw_outline` / `draw_wash` (aviso pela
  silhueta), `pulse` (2 Hz), `flash_k` ("Reduzir flashes"), `back_layer` (camada atrás dos lutadores), `force_code`
  (prancha "antes"). Filtro `LINEAR_WITH_MIPMAPS`, como o resto da arte pintada.
- **Perigos** (`scripts/entities/hazards/*.gd`): cada `_draw` virou `_draw_art()` (pintura) ou `_draw_code()` (o antigo,
  sem mudança), conforme `HazardArt.has(...)`. **Fallback**: sem textura, volta o desenho antigo.

| Perigo (Éon) | Folha | Estados no jogo |
|---|---|---|
| Pêndulo (Corrente) | hz_1 meio | suporte fixo + corrente ladrilhada + lâmina GIRANDO pelo ponto de pendurar (o mesmo ângulo da lógica); luz de contorno |
| Badalo mudo (Silêncio) | hz_3 c0 | suporte de parede + sino girando (mesma mecânica) |
| Guilhotina (Coroa) | hz_1 linha 2 | moldura ATRÁS da Sophia (`back_layer`); lâmina + haste na frente, descendo pelos trilhos no tempo da lógica (curso pintado mapeado em proporção) |
| Lanças (Silêncio/Coroa) | hz_2 linha 1 | laje embutida no chão; no aviso as fendas acendem e as pontas espiam; as lanças pintadas SAEM da fenda (recorte da textura, pontas primeiro) |
| Correntes do chão (Corrente) | hz_7 linha 2 | rachada (aviso) → saindo → estendidas |
| Boca (Fome) | hz_2 linha 2 | fechada → aviso (treme, fenda acende) → ABRE na 2ª metade do aviso (dentes = forma) → morde → fecha |
| Casulo (Praga) | hz_3 linha 2 | fechado (respira) → inchando (aviso) → estourado durante a nuvem → volta a crescer; morto = casca escura. A nuvem continua por código |
| Totem (objetivo) | hz_4 linha 1 | aceso → pulsando (invocação perto; contorno violeta 2 Hz) → quebrado; golpe = véu claro; rachas = vida |
| Pedra do sono (Torpor) | hz_4 linha 2 | inteira → rachada (Sophia parada) → afundando → some/volta com fade |
| Plataforma do reflexo (Espelho) | hz_6 c1 | firme = pintura; aviso = pisca a 2 Hz + contorno de vidro; REFLEXO = a mesma pintura translúcida, azulada e tremendo (por código: a folha do fantasma saiu rosada, decisão do chefe) |
| Cacos (Centro) | hz_6 linha 2 | sombra + anel no chão (código); caco pendurado tremendo e acendendo → cai (3 tamanhos); brilho/rastro por efeito (o pintado era rosado) |
| Maré escura (fuga) | hz_7 linha 1 | parede de breu (código) um pouco recuada + ONDA pintada (3 quadros em vaivém) com a crista exatamente na frente do dano |
| Porta da sala secreta | hz_5 linha 1 | selada → o selo reage (com pulo duplo) → aberta (baús secretos da tela abertos), com `hz_secret_open` |
| Altar (santuário) | hz_5 c3/c4 | aceso enquanto oferece a cura → dorme depois |
| Luz do Adormecido | hz_5 c5 / hz_6 c0 | forte (> 50%) / frágil / apagada (escura); brilho e barra por código |
| SEM folha | — | névoa, feixe do espelho, campo de silêncio, marca do pulo duplo: seguem por código (com o reforço de contraste abaixo) |

- **Aviso por cima da pintura** (base `LevelHazard`): `warn_outline()` faz uma borda TRIPLA pela silhueta. Por fora vem a
  escura (INK, 2,8 px), depois a vermelha (1,6 px) e no meio um fio quente claro (0,8 px). O alfa pulsa a 2 Hz.
  `warn_line()` desenha linha de aviso com sublinhado escuro e fio claro.
  Sombra, anel, linha do chão, tremor e som (`tell_unblock` etc.) continuam. Luz de contorno clara (`RIM_COL`) nas
  peças que ferem e estão sempre em movimento (pêndulo, sino, lâmina).
- **QA7 #25** (aviso quase invisível no Silêncio, tela 34 e3.5a): o símbolo do campo de silêncio ganhou sublinhado escuro,
  traço mais grosso e mais claro. O feixe do espelho trocou o fio de 1 px piscando a ~6 Hz pelo aviso de 2 Hz com
  sublinhado e brilho nos cacos. A névoa e todas as linhas de aviso ganharam sublinhado. O contraste foi medido:
  `tools/hazards7/contrast.py` dá **pior bloco 3,51:1** nas 9 capturas de Éon e nos fundos HD novos do cenario7
  (`eon_{0,1,2,4}_far/mid_a`). Sem o fio claro dava 2,48:1 em fundo de luminância média, por isso ele entrou.
- **Sons** (pedido do audio7, merge de 6df9411): trocados na fonte, no mesmo instante do aviso e do golpe:
  - lâminas e quedas: `hz_tide_wake`, `hz_guillotine`, `hz_maw_bite`, `hz_maw_warn` (junto do `tell_unblock`),
    `hz_chain_swing`/`hz_bell_toll`, `hz_spears`/`hz_shackles`;
  - Éter: `hz_ether_drain` (badalo e campo), `hz_silence_in`;
  - casulo, pedra e cacos: `hz_spore_burst`/`hz_spore_pop` (o `enemy_hurt` só nos golpes que não matam),
    `hz_sink_gone`, `hz_shard_impact`;
  - totem, luz e altar: `hz_totem_summon`/`hit`/`break`, `hz_ward_out`/`saved`, `hz_altar`;
  - porta: `hz_secret_open`.

  **Sem som duplo**: o observador do audio7 toca, na guilhotina, só o `hz_winch` (subida) e, na maré, só o
  `hz_tide_tick` (corrosão). São eventos diferentes dos que a fonte toca (`hz_guillotine` = impacto, `hz_tide_wake` =
  acordar). Conferido em `audio_manager.gd` 1915-1925.

## 2. Ferramentas
- `python tools/hazards7/cut_hazards.py` regera as peças. Depois rode `godot --headless --editor --quit`. PNG de NOME NOVO
  nasce com `mipmaps/generate=false`: troque para `true` no `.import` e reimporte.
- `tools/hazards7/HzBoard.tscn`:
  - `probe` (headless) diz em que tela e nó está cada perigo (`_caps/perigos7/hz_probe.txt`);
  - `shots` monta a TELA REAL num SubViewport 1280x720 (janela 320x180 fora da vista) e fotografa cada estado;
  - `seq` grava quadros seguidos.
- `bash tools/hazards7/boards.sh [code|paint|both]` faz as capturas e `python tools/hazards7/prancha.py` monta as
  pranchas ANTES × DEPOIS.
- `python tools/hazards7/contrast.py <imagens>` mede o contraste do aviso por bloco.

Telas usadas: pêndulo/correntes 21 e2.1a · sino/lanças 34 e3.5a · guilhotina 56 e6.0b · boca 13 e1.2a ·
casulo 48 e5.1a · totem 3 e0.1b · pedra 4 e0.2a · reflexo 40 e4.2a · cacos 65 · maré 4 e0.2b · porta 8 e0.6a ·
altar/luz 3 e0.1c.

## 3. Provas
- Pranchas `C:\gnosis-wt\_caps\perigos7\prancha_<perigo>.png` (15): linha de cima ANTES (código), de baixo DEPOIS
  (pintura), um estado por coluna, na tela real, com a Sophia ao lado como escala.
- GIFs `C:\gnosis-wt\_caps\perigos7\gif_guillotine.gif`, `gif_spears.gif`, `gif_maw.gif`, `gif_pendulum.gif` (30 qps,
  `--fixed-fps 60`).
- Contato das peças: `C:\gnosis-wt\_caps\perigos7\pieces.png`.
- Validação: `LayoutQA` QA PASS 1252/129 telas; `tools/validate.ps1 -Repeat 2` (resultado no relatório final).

## 4. Limites honestos
- O pêndulo e o sino GIRAM por código (uma pintura só); os quadros esquerda/direita da hz_1 e hz_3 não são usados (girar é
  mais liso que trocar 3 quadros). Os arcos de "vuush" pintados no sino ficaram de fora.
- O curso da lâmina pintada da guilhotina é ~64% do curso da lógica (mapeado em proporção). O topo da lâmina parada fica
  mais baixo que no desenho antigo; a queda dura 0,1 s, então não se nota.
- A nuvem do casulo estourado ainda tem um resto verde-claro pintado (some na escala do jogo); a nuvem que conta é a
  por código.
- Ninguém jogou: o feel é de captura e GIF. Escala: guilhotina ~3,3× a Sophia (o desenho antigo tinha a mesma altura) e
  pedra do sono com estalactites de ~60 px.
- `hz_altar_hum` (opcional no pedido do audio7) não foi ligado.

## 5. CHECAGEM DE SATISFAÇÃO (NEURO_SATISFACAO.md)
| Decisão | R atendidas | R violadas / justificativa | §4 conferido |
|---|---|---|---|
| Pintura no lugar do código, lógica intacta | R18 (perigo salta do fundo: pintura com contraste próprio + luz de contorno) | nenhuma | nenhum dano novo, nenhum tempo mudado |
| Aviso por cima da pintura (borda tripla pulsante + sombra/anel + tremor + som) | R5 (forma + cor + som: dentes que abrem, pontas que espiam, sombra que cresce; som do aviso no início do aviso), R18 (≥ 3,51:1 em todos os fundos medidos) | nenhuma | §4.11 (cor não é o único aviso: forma e som também), §4 "morte injusta": nenhum dano sem aviso ≥ 0,45 s (tempos inalterados) |
| Pulso do aviso a 2 Hz; feixe deixou de piscar a ~6 Hz; reflexo pisca a 2 Hz | R10 (≤ 3 flashes/s) | nenhuma | §4.4 sem clarão de tela |
| "Reduzir flashes" | R10 (brilhos decorativos × 0,5 via `HazardArt.flash_k`) | o contorno de aviso NÃO reduz (é informação, como o glint da R5) | — |
| Moldura da guilhotina atrás da Sophia, lâmina na frente | R18 (a Sophia não some atrás da moldura no momento do perigo) | nenhuma | — |
| Maré: crista pintada exatamente na frente do dano | R5/R18 (o que se vê = onde fere) | nenhuma | §4 injusta: a frente visível coincide com `_front` |
| Fantasma do reflexo translúcido + contorno | R18 (lê "não pise" sem sumir) | nenhuma | — |
| Sons do audio7 na fonte | R5 (som distinto no aviso e no golpe), R11 (sem duplicar com o observador) | nenhuma | §4.3 um evento, um som |
| Recompensas (totem, luz, porta aberta) | §3 (prêmio fixo e previsível; a porta aberta é só um reconhecimento visual) | nenhuma | §4.12 sem aleatoriedade manipulativa |

## BILHETE PARA O SUCESSOR
Estado: tudo commitado e com push em `dir7/perigos7`. Próximos passos possíveis:
- arcos pintados do sino como FX;
- `hz_altar_hum`;
- se o Cenário7 trouxer fundo novo muito claro, rodar `contrast.py` nas capturas.

Armadilhas:
- `.import` de PNG novo nasce sem mipmaps;
- o `--editor --quit` reescreve ~400 `.import` alheios (ruído de LF/CRLF): NÃO commitar, use `git checkout -- <arquivos>`;
- o `HzBoard` esconde só CanvasLayers com `layer > 0` (HUD/cinemática), porque o fundo também é CanvasLayer.
