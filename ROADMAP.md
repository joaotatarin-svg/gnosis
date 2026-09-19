# ROADMAP — GNOSIS

> **PLANO-MESTRE ATUAL (17/09/2026): `docs/PLANO_FINAL.md`** — rumo à versão
> 1.0 em ondas de agentes (comprimento + Gnose · cinema/UX/áudio/visual ·
> fechamento). Este arquivo guarda o histórico; o estado vivo está lá.

## Sessão 18/09/2026 — rumo à 1.1.0 (detalhe em BIBLIA.md §6)

- [x] Branches órfãs integradas: 68 telas com travessias, ganchos de áudio, poses da Sophia.
- [x] UX de versão final: menu, pausa, Golpes & Controles, Opções completas, HUD por papel, save v2, fim de jogo.
- [x] Gnose: 18 Estelas, legendas de caminhada, prólogo, card de chefe, epílogo, Crônicas.
- [x] Balance r5 (densidade por Éon, cura 25%). [ ] Nova medição do bot e ajuste fino.
- [x] Áudio + VFX de packs CC0/CC-BY (66 SFX, 14 músicas, VfxLibrary; `assets/LICENSES.md`).
- [x] Build 1.1.0 (`builds/GNOSIS.exe` + `installer/Output/GNOSIS-Setup-1.1.0.exe`).
- [ ] Playtest humano e ajuste fino do balance (r6 em medição).

## Edição isolada Codex — 2026-09-17

O histórico abaixo é do projeto de origem. Esta sessão só altera Gnosis-Codex.
Guia: docs/CODEX_ENTREGA.md; prompts: docs/ARTE_PROMPTS.md.

- [x] Cópia com Git, saves e lançadores independentes.
- [x] Menu, ateliê e desafio com três encontros e sete opções de chefe.
- [x] Sophia com seis poses ilustradas; chefes, criaturas, NPCs e Demiurgo novos.
- [x] Nove pinturas de ambientes, objetos, plataformas e camadas de profundidade.
- [x] Câmera, HUD, menus, loja com rolagem, efeitos e fragmentação ilustrada.
- [x] QA de fluxo e isolamento; partida vencida por inputs; capturas reais.
- [x] Nove chefes articulados, golpes ligados ao combate, patas/asas/tecidos.
- [x] Ateliê com ciclo de combate e inspeção das articulações; pausa validada.
- [x] Cenário variado por tela (props pintados sorteados por tela) — Claude 17/09.
- [x] Movimento procedural das criaturas comuns (passo, preparar, golpe, dano) — Claude 17/09.
- [ ] Fundos individuais por Éon em 1536×1024 (usuário gera no Astra; hook
  `assets/backgrounds/eon_<i>.png` já existe — a IA divide em camadas de parallax).
- [ ] Animação exclusiva mais extensa das criaturas e refinamento das bordas.
- [ ] Playtest humano do desafio e das 54 telas (feel dos golpes, parry, Anéis).
- [ ] Limpar código morto da geração vetorial antiga em `scenery.gd`.
- [ ] Áudio final e exportação independente.

> **Plano mestre rumo à versão final (escrito em 2026-09-09 após diagnóstico
> com capturas de tela reais — ver §"Diagnóstico").** As fases são executadas em
> ordem pela IA; cada fase termina com validação headless + capturas
> (`tools/shot.gd`) + atualização de `BIBLIA.md §6`. Marque `[x]` ao concluir.

## Diagnóstico (2026-09-09) — verdade sem hype

O jogo é um **protótipo completo em largura e raso em profundidade**: ~4.5k
linhas de GDScript, todos os sistemas existem em "versão 1", nenhum está no
nível de um jogo final. Visto rodando (capturas em janela real):

- **BUG visível em toda tela:** o fundo não cobre o viewport desde o zoom-out
  da câmera (0.75) → faixa cinza à direita e embaixo.
- **Herói = PNG de manto longo** (`assets/characters/sophia/full.png`), que o
  usuário já tinha rejeitado; fotorrealista, colide com o mundo vetorial.
- Inimigos = silhuetas minúsculas e genéricas; chefes = inimigo maior com o
  mesmo moveset (4 estilos) + 1 tweak.
- HUD no tema padrão do Godot (barras cinzas sem leitura). Codex com textos
  sobrepostos.
- **Progressão oca:** todos os combos têm `required_weapon_level = 1` → subir a
  arma só dá +3 de dano. `launcher` existe e nunca é usado. Só 2 magias.
- **Arco canônico NÃO implementado:** o fim é 1 chefe normal + texto. Sem
  Anéis, sem o Rei (Ato 1), sem roubo (Ato 3), sem batalha dupla (Ato 5). O
  texto `final_lines` fala de "duas formas" que não existem.
- Sem git (OneDrive é o único backup). Sem export templates instalados.
- Duração real ≈ 1–1,5 h. A meta de 10 h do LORE é irreal com este escopo;
  meta realista da versão final: **2–3 h com o arco completo**.

## PLANO DE EXECUÇÃO — sessão Fable 5.1 (2026-09-09, tarde)

> Ordem escolhida por impacto/hora. Cada bloco = validar headless + captura +
> commit. Os blocos que não couberem nesta sessão ficam marcados `[ ]`.

- [x] **A1 — Motor de arte v2 + CORTES DE MEMBROS** (feito; depois o usuário decidiu: Sophia volta ao PNG via rig cutout, procedural = waves/fallback).** Herói com rosto/cabelo/
  túnica e cajado NA MÃO (o golpe vira leitura: varredura leve, overhead pesado).
  Inimigos com silhueta por corpo (besta quadrúpede de verdade, wraith com
  farrapos, brutos largos). **Desmembramento:** morte por golpe pesado/finisher
  arranca cabeça/braços/pernas que voam com física e quicam no chão; morte comum
  = corpo cai. Chefes explodem em cacos.
- [x] **A2 — Cenário por Éon v2** (feito: scenery.gd).** 6 camadas procedurais (céu com astro próprio,
  skyline longe, props meio, props perto, névoa animada, primeiro plano) + chão
  com relevo + vinheta. Paleta e astro por Éon (lua pálida → sol vermelho → sol
  engaiolado → vazio → luas gêmeas → bruma verde → sol negro coroado → olho).
- [x] **B — Combate com profundidade** (feito; validado com tools/CombatTest.tscn).** 12 golpes desbloqueados por nível de
  arma (5 tiers), `launcher` + juggle + 2 golpes aéreos, finisher em câmera
  lenta no último inimigo (com desmembramento), esquiva perfeita (slow-mo +
  recompensa), Juice.slow_mo.
- [x] **C — Roster** (feito 2026-09-11). 7 bots novos, um por Éon, com mecânica própria
  (Sonâmbulo/tiro que lenta, Glutão/sanguessuga, Carcereiro/corrente, Mudo/aura de
  silêncio, Reflexo/esquiva o teu golpe, Esporos/poça ao morrer, Pretoriano/broquel
  frontal — só pesado fere pela frente). Chefes novos: **O Rei** (tela 1, tutorial,
  PNG do Demiurgo + orbe), **Rei enfraquecido** e **Colosso Oco** (batalha final),
  **ecos** translúcidos dos Arcontes no Centro (30% da vida).
- [x] **D — Arco dos Anéis** (feito 2026-09-11; testado ponta a ponta com
  `tools/shot.gd -- <tela> ... clear`). Run de 54 telas: Rei (1, a Voz o apresenta
  como amigo; ao "cair" o selo racha) · 7 Éons (2–50, Arconte em 8,15,…,50; cada
  Arconte morto dropa seu ANEL = magia nova, equipada na hora) · roubo (50: o Rei
  reaparece, leva os 7 Anéis, a Voz se revela Yaldabaoth) · Centro (51–53, ecos
  quebrados devolvem os cacos de memória = poder dos Anéis) · batalha dupla (54,
  `final_battle.gd`: Rei + Colosso, ressurreição em 14 s se não caírem juntos,
  7 Anéis girando no céu spawnando larvas; 1ª queda devolve o 7º Anel). 7 Anéis =
  7 magias com identidade própria (névoa lenta, sucção, corrente que prende, grito
  que atordoa, reflexo de dano, canteiro de veneno, nova enorme) + Esfera Solar
  inata. HUD dos Anéis (◆ coloridos, seleção 1–7 / Q/E / L2, cinza = roubado).
- [x] **E — Bot headless de balance** (F4) ✅ 2026-09-11: 3 rodadas medidas e
  aplicadas (histórico completo em `docs/BALANCE.md`). r3: bot vence o run
  inteiro, dano -43%, timeouts 18→3 (os 3 são limitação do bot). Também rendeu
  2 fixes críticos: paredes da arena (dava pra cair pra fora do mundo) e cura
  estrutural. **Resta só o playtest humano** (feel/parry/Anéis) antes de mexer
  de novo em número. · [ ] áudio (F5, usuário) · [ ] build (F6, precisa OK).

## As fases (ordem de execução)

### [x] F0 — Rede de segurança  ✅ FEITO 2026-09-09
- [x] `git init` + commit inicial. [x] Docs atualizados (CLAUDE/AGENTS/BIBLIA/GUIA_IA/README/GDD/PIPELINE_ARTE/BUILD) (README, cabeçalhos
  "chefe a cada 5", contradição "sem assets" vs rota híbrida) e código morto
  (`a_s1` removido; [ ] scaffolding de rig em `character_art.gd` ainda a tirar).
- [x] Ferramenta de captura `tools/shot.gd` — **a IA agora VÊ o jogo.**

### [~] F1 — Visual base (2–3 sessões, IA; usuário aprova capturas)
- [x] Corrigir a faixa cinza (fundo cobre o viewport com zoom).
- [x] Herói voltou ao procedural (PNG de manto aposentado). [ ] Motor sobe de nível e o motor sobe de nível: proporções, cabeça com
  rosto/cabelo, cajado com peso, poses de ataque legíveis. Inimigos maiores e
  com silhueta própria por tipo.
- Cenário por Éon com 4–5 camadas de parallax, chão com relevo, luz/vinheta.
- [x] HUD: barras de vida/Éter coloridas + **barra do chefe** (nome, vida, fase) na base. [ ] Anéis. [ ] Codex sem sobreposição.
- Demiurgo PNG recebe shader de posterização + contorno pra casar com o vetor.
- **Decisão de arte proposta:** procedural é a base do jogo; PNG só pro
  Rei/Demiurgo (o "de fora"). Rig ilustrado da Sophia fica aposentado.

### [~] F2 — Combate com profundidade (3 sessões, IA)
- [ ] Combos desbloqueiam por nível de arma (tabela de 5 tiers), `launcher` +
  juggle + ataque aéreo, finisher em câmera lenta no último inimigo, esquiva
  perfeita com recompensa.
- [x] 4 comportamentos novos (2026-09-09): Escudeiro do Selo (escudo — só pesado/magia
  ferem), Fantasma do Vazio (teleporta pra trás), Larva Ardente (corre e explode,
  imparável), Invocador de Larvas (atira + chama larvas). IA de grupo (separação).
- [x] Chefes com 2 fases (fúria a 50%) e mecânica única por Arconte (2026-09-09): Torpor (gás inverte
  controles se parar), Fome (come faíscas do chão), Corrente (prende no lugar),
  Silêncio (cala magias), Espelho (clone da Sophia), Praga (chão venenoso),
  Coroa (invoca servos do trono). Cada Arconte tem também uma ASSINATURA VISUAL
  própria (pálpebra, boca, correntes, boca costurada, cacos, gavinhas, coroa alta).
  Ver capturas: `tools/Showcase.tscn` + telas 7/14/21/28/35/42/49.

### [ ] F3 — Arco canônico (4–5 sessões, IA; usuário decide finais)
- **Anéis:** 7, um por Arconte, cada um = habilidade nova (hoje só há 2 magias
  → criar 7). HUD dos Anéis.
- Ato 1: o Rei como chefe-tutorial na tela 1 (silhueta saindo da névoa; usa o
  PNG do Demiurgo). Ato 3: cutscene do roubo na tela 49 (Anéis arrancados do
  HUD, máscara cai — texto já existe). Ato 4: 3 telas do Centro com ecos rápidos
  dos Arcontes. Ato 5: **batalha dupla** Rei + Colosso com timer de
  ressurreição e Anéis girando spawnando bichos; ao caírem juntos → reclamar.
- Sistema de cutscene simples (câmera + silhuetas + texto). Codex de lore.
- Finais: recomendo **manter os 3** como epílogo pós-reclamar (já funcionam).

### [ ] F4 — Balance por dados + playtest (2 sessões)
- Bot headless que joga as 50 telas e mede tempo/mortes por tela → curva de
  dificuldade calibrada antes do usuário jogar. Depois: playtest do usuário.

### [ ] F5 — Áudio (1–2 sessões, usuário gera; IA liga)
- Lista em `docs/AUDIO.md`; depois trilha por Éon e tema de chefe.

### [ ] F6 — Build + instalador (1 sessão)
- Export templates (download ~600 MB — precisa de OK do usuário), export
  `builds/GNOSIS.exe`, Inno Setup, página no itch.io.

**Total estimado: 15–18 sessões.**

---
# Histórico (passos anteriores a 2026-09-09)


> Ordem pensada pra maximizar impacto e deixar o balance/polish visual (que
> dependem do usuário jogar) pro fim. A IA valida tudo headless; **não vê o
> jogo** — feel/estética são confirmados pelo usuário. Marque `[x]` ao concluir
> e atualize `BIBLIA.md §6`.

## [x] Passo 1 — Combos padronizados  ✅ FEITO (e depois consolidado)
Formato leve 3x + forte 3x (2 iguais + finalizador, wind-up/cooldown). NOTA: o
roster foi depois **reduzido a 1 personagem — a Sophia** (protagonista única);
os antigos jogáveis foram removidos do código e docs.

## [x] Passo 2 — Variedade de cenário por Éon  ✅ FEITO
`level.gd` (`_build_eon_scenery`/`_make_eon_prop`) gera props próprios por Éon na
camada Mid do fundo, conforme `RunManager.eon_index`. Falta o usuário VER e dizer
se ficou bom (a IA não renderiza).

## [x] Passo 3 — Plataformas (foco jogabilidade)  ✅ FEITO
Plataformas one-way (sobe por baixo, pousa em cima) determinísticas por tela em
`level.gd` (`_build_platforms`). Player usa; inimigos ignoram (ficam no chão).
Telas de chefe ficam limpas. Também: FPS counter (F3) e hook de fundo PNG
(`assets/backgrounds/eon_<i>.png` — se existir, usa a arte do usuário).

## [x] Passo 4 — Mecânicas de chefe  ✅ FEITO (v1)
Chefes (`Bestiary.is_boss_id`) ganham versão assinatura do ataque: atiradores
soltam **salva de 3** projéteis; slams fazem **onda muito maior + golpe mais
largo**; charges são **mais rápidos + deixam rastro de choque**; melee tem
**alcance maior**. Próximo nível (opcional): ataques 100% únicos por Arconte.

## Passo 5 — Passe de balance (COM o usuário)
Calibrar números (vida, dano, cooldowns, velocidade dos inimigos, custos da loja)
com base no playtest do usuário. Curva de dificuldade ao longo dos 7 Éons.

## Passo 6 — Polish visual/feel (COM o usuário)
Ajustes finos que só o olho humano pega: proporções de criaturas, timing de
animação, cores por Éon, telas de diálogo, hitstop. Iterar pelo report do usuário.

## Passo 7 — ÁUDIO (a última etapa, decisão do usuário)
Usuário gera SFX/música por IA (ElevenLabs/Stable Audio — ver `docs/AUDIO.md`),
solta em `assets/audio/`, a IA liga a mixagem. Depois a trilha por Éon.

## Passo 8 — Build final + instalador
Baixar export templates 1x no Godot (Manage Export Templates), exportar
`GNOSIS.exe`, compilar o instalador (`installer/gnosis.iss`). Ver `docs/BUILD.md`.

---
## ARCO CANÔNICO — sistemas grandes a construir (ver docs/LORE.md ★)
Depois do polish/balance base, a campanha narrativa exige estes sistemas novos:
- [ ] **Boss "O Rei" (Ato 1)** — tutorial disfarçado de duelo; usa o VISUAL que o
  usuário desenhou (sacerdote branco mascarado + orbe-olho). [x] Hook de textura
  estendido pros chefes (`enemy._apply_illustrated_art`, `<id>.png` + `<id>_orb.png`).
  [x] Arte do `demiurgo` recortada e integrada (corpo + orbe flutuante com tell).
  Falta: usuário VER/ajustar tamanho e posição do orbe + estados de boss próprios do Rei.
- [ ] **Mecânica dos Anéis** — matar cada Arconte dropa 1 Anel = 1 habilidade nova.
  7 Anéis = corpo do Demiurgo + cacos da memória da Sophia (o loop temático).
- [ ] **Ato 3 (o roubo + máscara cai)** — cutscene: o Rei rouba os 7 Anéis, a Voz
  se revela o Demiurgo (texto já pronto em `narrative.demiurge_pre`).
- [ ] **Batalha final (Ato 5)** — encontro especial na tela 50: **DUAS formas do
  Demiurgo enfraquecidas** (Rei + Colosso) que devem cair num **intervalo
  semelhante** (a que morre sozinha se refaz); os **7 Anéis giram e spawnam bichos
  fracos** sem parar; ao derrubar as duas juntas → QUEBRA. Depois: `final_lines`
  (reclamar) + escolha de final.
- [x] **Voz = Demiurgo (reconciliação)** — feito em `narrative.gd`.
- [ ] **Finais** — decidir: os 3 antigos (Ascensão/Ruptura/Semente) viram a escolha
  do destino do mundo PÓS-reclamar, ou aposentar. (Hoje ainda existem no código.)

### Extras / ideias (quando fizer sentido)
- Mirror dos combos: sistema de desbloqueio de combos maiores por nível de arma
  (o formato antigo tinha isso; reintroduzir de forma legível depois do Passo 1).
- New Game+ diegético (final "Ruptura").
- Codex/lore desbloqueável integrado à Galeria.
- Rebind de controles nas Opções.
- Missões secundárias por Éon além dos Adormecidos.
