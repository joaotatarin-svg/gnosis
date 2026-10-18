# LEVEL6 — cada tela com forma própria (Onda 6, diretor de level design)

Branch `dir6/level6`. Queixa do João: *"linear, vai pra frente e bate nos bichinhos"*,
*"sempre a mesma coisa"*. O mapa6 deu a ESCOLHA de caminho; o level6 dá a FORMA de cada tela.

## 1. Arquitetura
- `scripts/levels/layouts/screen_layouts.gd` (`ScreenLayouts`) — a TABELA: tipo de layout por
  `RunManager.node_kind()`, comprimento de cada passagem, plataformas das arenas (6 arenas-modelo,
  2–4 alturas), itens das passagens, guarda das arenas, objetivo de cada zona, saída no alto,
  nascimento antecipado. Sorteio por NÓ (`RunManager.node_rng`): trilhas da mesma camada diferem.
- `scripts/levels/layouts/layout_builder.gd` (`LayoutBuilder`) — monta o plano no Level.
- `scripts/entities/hazards/**` — perigos (base `LevelHazard`) e objetos de objetivo/segredo.
- `level.gd` (só layout): zonas com passagens de comprimento variável (`zone_center`,
  `passage_start`), descansos no meio das passagens, spawns fora de baixo de degraus, voadores
  no alto (`_is_flyer`), objetivos ligados à zona (`_arm_objective`/`_close_objective`), fenda no
  alto, `reserved_spans()` (Estela/baú/Adormecido/Selos/encontro), `fg_forbidden` (CENARIO5).
- `chest.gd`: baú SECRETO (`secret = true`): brilho dourado, 2× faíscas, cura 20 %.

Alturas (centro da plataforma): Y1 252 · Y2 196 · Y3 140 · Y4 84 (cada degrau sobe 56; o pulo
simples sobe ~77). Saliência de pulo duplo YDJ 200 = 116 px acima do chão, isolada.
**Rota no chão sempre existe** (o bot não pula): nada de buraco que exija pulo.

## 2. Tipos de tela (por tipo de nó do mapa)
| nó do mapa | layout | o que tem |
|---|---|---|
| arrival | chegada | arena baixa → passagem com 1 perigo do Éon + saliência de pulo duplo (baú) → arena alta |
| combat | travessia / fuga / segredo (pela camada) | travessia: passagens longas com 2 perigos, **totem** na 2ª zona · fuga: a **maré escura** persegue · segredo: começa antes, torre com baú, pulo duplo |
| hazard | perigo | passagem 0 aberta + passagem longa com 3 perigos do Éon em ritmo; guarda do Éon na arena final |
| platform | escalada | torre no começo, **escalada** sobre chão perigoso (pedras vivas do Éon), arenas altas, **fenda no topo** |
| sanctuary | santuário | calmo, nada fere: **altar** (cura 25 %), torre de luz, **proteger a luz do Adormecido** |
| challenge | arena | fechada e pesada, sem perigo de cenário, totem na 2ª zona |
| secret | sala secreta | **câmara em Y3 só com pulo duplo** (saliência ao lado), 2 baús secretos, porta selada embaixo |
| trial / antechamber / center | desafio / antessala / centro | duelo limpo · corredor denso de perigos + guarda · cacos caindo |
| king / archon / final | chefe | limpo (dos chefes) |
Tela com Soter/Velkar: passagem do encontro ≥ 1000 px, Estela (−200) · NPC · Selos (+300)
separados; na escalada, a subida vai pra passagem 0 e o encontro fica calmo.

## 3. Perigos por Éon (todos avisam ≥ 0,5 s; esquiva vale perfeita; ferem inimigos também)
| Éon | passagem | chão da escalada / guarda da arena |
|---|---|---|
| Torpor | névoa que RESPIRA (lentifica quando cheia) | pedras do sono (afundam se ficar parada) |
| Fome | boca no chão (morde em ritmo) | boca |
| Corrente | pêndulo de lâmina (prende) | correntes que brotam do chão (prendem) |
| Silêncio | badalo mudo (apaga o Éter) | lanças; **campo de silêncio** em toda arena (magia/projéteis morrem) |
| Espelho | feixe rente ao chão (pule) | plataformas do REFLEXO (alternam a cada 2,4 s) |
| Praga | casulo de esporos (estoura com 2 golpes) | casulo |
| Coroa | guilhotina | lanças da guarda |
| Centro | cacos caindo (sombra 0,8 s) | cacos |
Dano base `4 + tela/10` (guarda de arena × 0,7). Objetivos: **totem** (invoca até 3 reforços;
quebrar dá faíscas), **luz do Adormecido** (inimigos perto drenam; acesa no fim = faíscas + cura).

## 4. Validação
- `tools/level6/LayoutQA.tscn` (headless, ~1 min): monta os **129 nós** (7 Éons × camadas ×
  trilhas + Centro) e confere alcance com pulo simples/duplo (baú de torre e fenda no alto: simples;
  saliência/sala secreta: SÓ duplo), spawns fora de degraus, perigos fora de Estela/baú/Selos e a
  folga Estela/NPC/Selos. **QA PASS 1252 verificações.**
- `tools/validate.ps1 -Repeat 2`: **TUDO VERDE (11 etapas, 2/2)**. MapQA (mapa6): PASS.
- FgAudit (cenário, 68 telas): `hits=0 fight=0 cover_max=0,083`. Colunas de primeiro plano caíram
  de 57 para 35 (mais coisa protegida na tela).
- i18n: lote `14_level6.tsv`, `build --strict` 1362/1362, LangQA e EnFit verdes.

## 5. Bot de balance (seed 1, vel 4, telas 2–37)
| rodada | tempo | dano | quase-mortes |
|---|---|---|---|
| antes (mapa6), trilha do meio (rota=0) | 15,5 min | 2187 | 14 |
| level6, trilha do meio | 17,3 min | 2134 | 14 |
| antes (mapa6), rota sorteada (rota=1) | 13,1 min | 1741 | 8 |
| level6, rota sorteada | 15,2 min | 1975 | 12 |
Telas mais longas (+12–16 % de tempo: passagens maiores, subidas). Dano igual na trilha do meio;
+13 % na rota sorteada — quase todo nos nós `hazard` (o bot não pula nem desvia de cenário: tela 21
39→60, 25 13→56). Um humano evita boa parte; e o João achou o jogo fácil. Nenhum timeout, trava
nem avanço forçado em nenhuma rodada.

## 6. Limites honestos
- Sem playtest humano: ritmo dos perigos, alturas e o "feel" da escalada são de cálculo + prancha.
- O bot não exercita plataformas nem segredos (só o LayoutQA mede alcance — pela geometria, não
  jogando). A sala secreta depende do pulo duplo do combate6 somar ≥ 45 px.
- Voadores: o gancho existe (`_is_flyer`), mas nenhum inimigo responde ainda (pedido ao inimigos6).
- Perigos desenhados por código (sem pintura); legíveis, mas abaixo do nível da arte ilustrada.
- `scenery.gd` e `tools/scenery/fg_audit.gd` calculam zonas com `ZONE_STEP` fixo; o level6 cobre
  isso com `fg_forbidden` nas zonas reais (pedido ao cenário para usar `Level.zone_center`).
- Pranchas: `C:\gnosis-wt\_caps\level6\prancha_ANTES.png` e `prancha_DEPOIS_A/B/C.png`
  (ferramenta `tools/level6/Board.tscn` + `prancha.py`; janela 320×180 fora da vista).
