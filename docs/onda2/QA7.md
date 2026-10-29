# QA7 — QA do jogo inteiro (Onda 7, versão 3.0.1)

Branch `dir7/qa7`, com merge de `origin/integracao/onda1` cae45f6 (já com voadores e Campeões de arte própria).
Worktree `C:\gnosis-wt\qa7`. Capturas e logs ficam fora do git, em `C:\gnosis-wt\_caps\qa7\`
(`bot2\` = run final, `visual\`, `ui\`, `bugs\`). Não alterei nenhum código do jogo; as sondas estão só em `tools/qa7/**`.
Régua usada: playtests do João (`_ONDA6.md`) e `docs/handoff/NEURO_SATISFACAO.md` (R1–R22, §4, checklist §5).

## Como foi testado
- **Bot no run inteiro**: `tools/qa7/QA7Bot.tscn` (cópia do BalanceBot com métricas extras) rodou as 68 telas em 3 sementes,
  com `vel 4 ia=3 --fixed-fps 60`. A rota do mapa sai da semente: foram 13 perigos, 15 escaladas, 13 santuários, 13 Arenas e 9 segredos.
  Para analisar: `python tools/qa7/analisa_bot.py C:/gnosis-wt/_caps/qa7/bot2 s1 s2 s3` (resultado em `bot2\analise.md`).
  O bot cura ao cair abaixo de 45% de vida e conta isso como "quase-morte". Ele não bloqueia nem apara, e pula quando o alvo está acima.
  Por isso joga pior que um humano bom: os números servem para ler a FORMA da curva, não o valor absoluto.
- **Passada visual**: 94 capturas de gameplay (telas-chave, todos os Arcontes nas fases 1 e 2, os 6 tipos de nó em vários Éons,
  Campeões, Soter e pulo duplo), mais menus, HUD e cenas em PT e EN. Pranchas em `visual\p01–p15` e `ui\p01–p25`.
- **Sondas existentes**: EnemyProbe, HitboxProbe, FeelProbe, RuleProbe, DeathProbe, LayoutQA, MapQA, CodexQA, SaveQA, MiscProbe,
  RunProbe, BossProbe (telas 1, 10, 19), validate (8 etapas), LangQA, EnFit, UiProbe e MenuProbe.
- **Sondas novas** (só ferramentas): `tools/qa7/visual/` (NodeShot força um nó do mapa; EnemyDump; SoterProbe) e
  `tools/qa7/ui/` (LangWrap força o idioma; CineShot; pranchas).

## Resultado das sondas
VERDE: LayoutQA (1252 verificações / 129 telas), MapQA (22 PASS), HitboxProbe (o golpe atravessa sem acertar em 1% dos casos;
alcance exagerado em 8%), FeelProbe, RuleProbe, DeathProbe, CodexQA, SaveQA, MiscProbe, RunProbe, validate 8/8, LangQA 12/12,
EnFit (1419/1419 com inglês), Soter (0 falhas em PT e em EN).
VERMELHO: EnemyProbe (o arauto nunca usa a "repulsa") e MenuProbe (bestiário sem lore em 2 fichas).
Nenhum `SCRIPT ERROR` em execução nenhuma. Nenhum magenta em 94 capturas. **0 travas reais e 0 mortes reais** nas 3 sementes, que chegaram todas à tela 68.
(A primeira rodada acusou "TRAVOU na 55". Era falso positivo da sonda: a morte de chefe passa ~0,9 s reais em STAGGER com vida 0.
A sonda foi corrigida e a semente chegou ao fim.)

## Erros de console (3 sementes do bot + sondas, agrupados)
| nº | erro | origem |
|---|---|---|
| 62 (bot) + 24 (BossProbe) | `Function blocked during in/out signal. Use set_deferred("monitoring")` | hitbox.gd:47 `deactivate()` ← enemy.gd `stagger()` ← player.gd `_parry` (ver bug 1) |
| 6 | `Tween (bound to Staging): started with no Tweeners` | staging.gd:1243 `_flush` ← `_on_finished` :463 (ao fechar fala) |
| 3+ | `Camera2D overridden to physics process mode` | inofensivo |
| 7 | `Lambda capture at index 0 was freed` | tools/gnose_qa.gd:43 (a própria sonda) |

## BUGS — priorizados (R = regra do NEURO_SATISFACAO que é ferida)
Nenhum bug é **Bloqueante**: não houve trava, NPC inalcançável nem tela sem saída.

### Alta
1. **A hitbox do inimigo continua viva depois do aparo** · combate + inimigos · fere **R5**.
   Em `hitbox.gd:43-45`, `deactivate()` faz `monitoring=false` direto, dentro do sinal de área, e o Godot BLOQUEIA a mudança (62× no log).
   `_on_area_entered` não confere `_active`. Resultado: o inimigo aparado ainda fere quem entra para castigar, que é a queixa
   "tomo dano ao acertar" (PLAYTEST 2 nº 2). Correção sugerida: `set_deferred("monitoring", false)` e checar `_active` no acerto.
   Reproduzir: `BossProbe -- telas=1,10,19 vel=3` (grep "Function blocked") ou o bot.
2. **Todos os Arcontes passam de 100 s, não só os 3 em recalibração** · chefes6 · fere **R21** (respiro) e o §4 (fadiga).
   Chefes que o bot NÃO matou em 100 s de zona: Athoth (10) 3/3 sementes, Galila 3/3, Yabel 3/3, Astaphaios 3/3, Belias 3/3,
   Armupiel 3/3 (vida 672–847 sobrando), final 3/3 (114–159 s). Só Harmas (19) fechou em ~100 s.
   BossProbe: Rei 123 s, Athoth 288 s, Harmas 255 s. Fica registrado, sem investigar, porque já está em recalibração.
   Aviso: o 1º Arconte já é longo, e o João jogou a prévia com chefes de "5–6 porradas" → agora está no extremo oposto.
3. **Tela 68: a Sophia some atrás do manto do Rei, e o Rei fica cortado na borda esquerda** · chefes6/técnico (z-order/y-sort) · fere **R18**.
   Captura `_caps\qa7\visual\z_c68_left.png`, `raw\c68_f2.png`, `ui\p06`. Reproduzir: `Shot 68 420 hurt`.
4. **Bestiário em EN mostra o lore em português** · ui/i18n. `gallery.gd:182` junta as linhas com `"\n".join(...)` e procura
   a string inteira na tabela, onde só existem as linhas soltas. Prancha `ui\p03`.
5. **Fichas "acolito" e "espectro" do bestiário sem lore e sem dica** (PT e EN) · narrativa. MenuProbe: "UIM FALHA".
   Prancha `ui\p24`. Os voadores são novos e ficaram sem texto.
6. **A placa dos Selos ("golpeie na ordem em que brilham") não traduz** · ui. `seal_puzzle.gd:34` usa uma string de 2 linhas
   que não está na tabela. Captura `ui\soter_en\soter_10_no_degrau.png`.
7. **"Golpes & Controles" em EN mistura glifos** ("Square Square Quadrado Quadrado") · ui/i18n. Pranchas `ui\p19`, `p22`.

### Média
8. **Poça de veneno fere no mesmo quadro em que nasce** (morte do Portador de Esporos, `enemy.gd:1332`; rastro de Belias,
   `enemy.gd:896`). Em `hazard_zone.gd` o `_tick` começa em 0. É dano sem aviso para quem está colado no inimigo · inimigos · fere **R5**.
   O bot mostra que poças e pilares são fonte grande: `poca(pillar)` = 2003 de dano, 3,2% do total.
9. **Teleporte por trás com só 0,25 s de aviso** (0,21 s com Elite fúria): "aparicao" do fantasma e "espelhar" do reflexo
   (`enemy_moves.gd:124/170`, `enemy.gd:1779`). O golpe nasce fora do campo de visão · inimigos · fere **R5**.
10. **Inimigo de longe foge para a borda e a Arena não fecha** · inimigos/level. Arauto, aberração e acólito ficam em x≈2100–2400,
    e o escudeiro em x=4252 na tela 14. Deu timeout de 140–167 s em 43 (2/3 sementes), 49, 32 e 14. Fere **R21**.
11. **Galila (28) fase 2 sai da tela pela direita e fica invisível** · chefes6. `visual\raw\b28_f2.png`, `p10`.
12. **O Campeão nasce fora da tela (x=888, no ar) e leva mais de 4 s para entrar, mas o letreiro "CAMPEÃO" já aparece** ·
    inimigos/level (telas 6, 33 e 60). `visual\p02`, `p09`, `raw\dump06.log`.
13. **Economia sem sumidouro no fim do run** · progressão · §3 (recompensa sem sentido). A arma chega ao nv. 5 na tela 46
    (Arma 2 na 6, 3 na 10–15, 4 na 28). Depois disso as faíscas sobem de ~250 para **6,4–7,4 mil sobrando** na tela 68
    (o bot compra arma e magias). Isso contraria a queixa nº 8 só pela metade: agora o máximo chega no Éon 5, mas a partir daí juntar faísca perde o sentido.
14. **DialogueBox sobrevive à troca de cena** e fica por cima de Crônicas, Galeria e da Pausa da Provação, tapando botões · técnico/ui.
    Foi reproduzido com a troca de cena direta da UiProbe. Pranchas `ui\p21`, `p22`.
15. **Arauto nunca usa a "repulsa"** (EnemyProbe: orbe=10, pilar=6, repulsa=0): tem 2 golpes e nenhuma resposta de perto · inimigos.
16. **Loja em EN: "opens: Fenda Arcana, …"** (`upgrade_menu.gd:110`) e **Créditos com trechos em PT** · ui. `ui\p02`, `p16`, `p23`.
17. **Card "YALDABAOTH" aparece 2× na luta final, e o subtítulo EN invade o Colosso** · narrativa/ui. `ui\p14`.
18. **Pés de Belias, Armupiel, Harmas e Astaphaios 40–55 px acima do chão da Sophia** (a confirmar: pode ser o ponto de apoio do PNG) · chefes6/arte. `visual\p03`, `p04`.

### Baixa
19. Elite "fúria" baixa golpes de 0,40–0,45 s para 0,34–0,38 s de aviso (`enemy.gd:1760`) · inimigos · R5.
20. Áreas de chefe que nascem com 0,05–0,35 s de aviso próprio (depois de um telegrafo de ≥0,8 s): Belias `_pool_at`
    (boss_belias.gd:119), muro de Athoth (boss_athoth.gd:144), serras do Rei (boss_rei.gd:178) · chefes6 · R5.
21. Hurtbox com metade da largura do desenho (servo 28×56, canino 25×52, larva 21×39): em 4% dos toques o golpe encosta no desenho e não fere · inimigos.
22. "Coluna de luz" sob as plataformas aparece como retângulo translúcido de borda dura, um fantasma (`scenery.gd _integrate_platforms`) · arte/level · R18. `visual\z_plat_shadow.png`.
23. O subtítulo do Campeão cai sobre uma plataforma e fica ilegível · ui. `visual\z_k15_title.png`.
24. Anéis/orbes de chefe desenhados por cima do HUD (Rei na 68, gaiolas da Galila) · chefes6/ui.
25. Aviso de perigo de chão quase invisível no Silêncio (tela 34, nó e3.5a) · level/arte · R5. `visual\raw\n_haz_e3_34.png`.
26. As salas secretas e0.6a e e4.3a usam o mesmo molde · level.
27. Dica do HUD "Create (L2)" em inglês na versão PT; "telegrafo" sem acento · ui/narrativa.
28. Tween vazio no Staging (6×) · narrativa (staging.gd:1243).
29. A câmera mostra 53 px além da parede esquerda · level/técnico. Três quadros da corrida duram menos de 1 frame · arte/combate.
30. A tela da Estela empilha legenda + "Siga em frente →" + prompt no centro · ui. Viúvas em cards EN de epílogo · narrativa.

### A verificar / design
- Nós secretos aparecem antes do Soter (e0.6a, e1.3a) e, num run sem volta, ficam fechados na 1ª jogada (MapQA garante que é opcional). Precisa de decisão de design.
- Tela 65: a descida ao Centro dura ~8–10 s sem controle, incluindo um quadro todo preto no frame 240. Não é trava, mas é longa.
- UiProbe "checkpoint_errado (morreu na 4, voltou na 4)": provavelmente a sonda está desatualizada depois do mapa.
- O painel da Estela abre sem pausar (`paused=false`): a Sophia pode apanhar enquanto lê?
- LayoutQA usa pulo simples de 66 px e npc_encounter.gd diz 81 px: as duas sondas divergem.

## Curva de dificuldade por Éon (bot, média de 3 sementes, run completo)
| Éon | telas | tempo (min) | dano | quase-mortes | timeouts | faíscas ganhas | arma máx. | vida máx. | menor vida |
|---|---|---|---|---|---|---|---|---|---|
| Rei (1) | 1 | 1,4 | 134 | 1,3 | 0 | 68 | 1 | 120 | 42% |
| 1 Torpor (2-10) | 9 | 9,6 | 1491 | 16,7 | 1,0 | 594 | 3 | 130 | 27% |
| 2 Fome (11-19) | 9 | 12,2 | 2568 | 29,0 | 0,7 | 1017 | 3 | 134 | 24% |
| 3 Corrente (20-28) | 9 | 10,9 | 3001 | 33,0 | 1,0 | 1196 | 4 | 142 | 27% |
| 4 Silêncio (29-37) | 9 | 13,9 | 3427 | 34,0 | 1,3 | 1745 | 4 | 156 | 27% |
| 5 Espelho (38-46) | 9 | 14,0 | 3861 | 37,7 | 2,3 | 2112 | 5 | 170 | 24% |
| 6 Praga (47-55) | 9 | 11,6 | **2672** | **22,7** | 1,3 | 2173 | 5 | 178 | 25% |
| 7 Coroa (56-64) | 9 | 11,9 | 3024 | 25,3 | 1,3 | 2848 | 5 | 198 | 27% |
| Centro+Final (65-68) | 4 | 4,2 | 1141 | 9,0 | 1,0 | 2878 | 5 | 198 | 35% |
Totais: 88,6–90,8 min de jogo, 198–220 quase-mortes por run, 0 mortes reais, arma nv. 5 na tela 46.

Por tipo de nó (dano ÷ vida máx., média): Desafio/Campeão **3,65** · final 4,27 · Arena 2,88 · Arconte 2,64 · chegada 2,22 ·
travessia 2,23 · segredo 1,75 · perigo 1,63 · antessala 1,52 · escalada 1,20 · santuário 1,16 · Centro 0,63.

**Leitura:**
1. A curva SOBE bem de Torpor a Espelho (Éons 1–5) e depois **cai na Praga (Éon 6), ~30% abaixo do Espelho**. A Coroa
   não volta ao pico. O fim do run está mais fácil que o meio. Pedido ao balance: Praga e Coroa precisam de pelo menos +20% de pressão.
2. O pico do Éon 5 coincide com a arma no nv. 5. O jogador fica mais forte antes do trecho mais duro e depois sobra (bug 13).
3. **Os Campeões (Desafio) são o nó mais duro do jogo, mais que os Arcontes** (3,65 × 2,64). Para o bot, isso vem de "glutao", "reflexo" e "pretoriano" (golpe máximo de 38 = 24% da vida).
4. Escalada e santuário custam metade de uma travessia, o que está certo (respiro, R21). O "perigo" (1,63) está no ponto.
5. O Centro (65–67) é o trecho mais leve do jogo (0,63). Se a intenção é um clímax, está fraco.
6. A mudança em relação à queixa "fácil demais" é real: o bot (sem parry) termina cada Éon com a vida mínima entre 24% e 27%.
   Mas os chefes passaram do ponto para o lado da fadiga (bug 2).

## Checklist §5 (NEURO_SATISFACAO) — o que a automação mede e o que fica para humano
| item | medido? | leitura |
|---|---|---|
| 3 Responsividade | parcial | FeelProbe verde; hitstop/entrada sem perda |
| 5 Parry legível | parcial | o aviso existe, mas o bug 1 (hitbox viva após aparo) e os avisos curtos (bugs 9, 19 e 20) ferem a R5 |
| 6 Telegrafo coberto | parcial | anéis de chefe sobre o HUD (24); veneno sem aviso (8) |
| 8 Finalização | parcial | a morte do chefe tem sequência (0,35+0,55+0,95+0,6 s reais) |
| 10 Momento grande | parcial | card duplicado na final (17) |
| 1, 2, 4, 7, 9 (peso, "entra", cansaço, faíscas, ouvido) | não | precisa de humano/áudio. Indício de cansaço: 100 s ou mais por Arconte (bug 2) |

## Re-teste (3.1 / 3.2)
`tools/qa7/QA7Bot.tscn -- 1 68 4 seed=N ia=3 out=...` para N=1,2,3 em paralelo (~50 min reais), depois
`analisa_bot.py`. Para a visual, `tools/qa7/visual/run_caps.sh` + `tools/qa7/ui/run_ui.sh` / `run_cenas.sh`.
Atenção: `_real_wait` (morte de chefe, staging) roda em tempo REAL, então duas rodadas da mesma semente variam ~5–10% no dano.

## RE-TESTE 3.1 (origin/integracao/onda1 4dad743 = lote vfx7 + chefes6 + polimento7)
Rodado em `dir7/qa7` com merge exato do 4dad743 (1876106; o jogo fora de `tools/qa7`, `docs` e `tools/qa_visual` é idêntico).
Saídas em `C:\gnosis-wt\_caps\qa7ot31\` (bot, 3 sementes, BelowNormal) e `...\p31\` (sondas, capturas, áudio).
Validação do projeto: zero `SCRIPT ERROR`. Bot: 68 telas nas 3 sementes, 0 mortes reais, 0 travas, 79–85 min de jogo (antes 89–91).

### Sondas (3.1)
VERDE: EnemyProbe (a repulsa do arauto agora sai; era vermelho), MenuProbe 112 ok/0 falha (era vermelho: lore do acólito/espectro),
LangQA 12/12, EnFit 0 falha, HitboxProbe (atravessa 0%, apelão 10%; corpo desenhado: sem dano 0,0%), FeelProbe, RuleProbe, LayoutQA
(1252 verificações/129 telas), MapQA, CodexQA, SaveQA, DeathProbe. BossSizeProbe não roda headless (precisa de renderer): não medi o manto do Rei.
Erros de console do bot: de 62+6 (hitbox bloqueada e Tween vazio) para **0**. Restam só os avisos de saída (Camera2D, ObjectDB).

### Corrigido (medido)
1. #1 hitbox viva após o aparo: 62 `Function blocked` -> 0 nas 3 sementes.
2. #2 duração dos Arcontes: de 91–159 s (21 de 24 estouravam 100 s) para 35–102 s; só 1 timeout em 24 (Galila, semente 3). Ver "novo" N2: passou para o outro lado.
3. #5 fichas do acólito/espectro: MenuProbe verde.
4. #15 repulsa do arauto: EnemyProbe verde.
5. #21 hurtbox do corpo desenhado: EnemyProbe "Hurtbox segue o corpo" e HitboxProbe com 0% sem dano.
6. #28 Tween vazio no Staging: 0 ocorrências.
7. #3 (parcial) tela 68: a Sophia agora é desenhada NA FRENTE do Rei (`_caps\qa7\p31\c68_31.png`). O Colosso continua cortado na borda esquerda.

### Corrigido só pelo que o commit diz (não medi em execução)
#8 poças armam 0,5 s antes de ferir (9d9d353) · #9 aparição com 0,6 s de aviso (9d9d353) · #17 card de chefe sem repetir em 8 s (ab957ac) ·
#19 aviso da fúria >= 0,4 s (4b022a8) · #30 viúvas nos cards EN (WidowProbe não rodei) · descida ao Centro ~8 s -> ~5 s (ab957ac).

### Continua
- **#4** Bestiário em EN com o lore em português (`gallery.gd:182` igual; captura `p31\en_Gallery.png`, a dica já sai em inglês e o lore não).
- **#16** Loja em EN: "opens: Fenda Arcana, Arcane Ascent" (nome de combo sem tradução; `p31\en_UpgradeMenu.png`).
- **#6** placa dos Selos: a string de 2 linhas (`seal_puzzle.gd:34`) segue sem entrada na tabela EN (por leitura do código).
- **#10** inimigo de longe: a coleira `EnemyAggro.leash_x` agora é chamada (enemy.gd:1718-1724), mas ainda há 18 timeouts (antes 30):
  arauto@2000–2500 (tela 43, 34), aberração@2100 (49), reflexo@2800 (39), esporos@2500 (49), mudo@1800 (32). Atenuou, não resolveu (R21).
- **#12** Campeão (tela 6): nasce em x=888 no ar e só desce a ~x=786 no quadro 600 (EnemyDump idêntico ao antigo) com o card já na tela.
- **#11** Galila fase 2: no Shot 28 `hurt` (400 quadros) só aparecem as gaiolas e a barra; a Galila não está no quadro (`p3128_f2_31.png`).
- **#18** pés da Belias bem acima da Sophia (`p3155_f2_31.png`; pode ser o apoio do PNG ou uma plataforma).
- **#24** anéis de chefe sobre o HUD (tela 68, canto superior; `c68_31.png`).
- **#13** economia: 5,5–7,5 mil faíscas sobrando na 68 (s1 7183, s2 7498, s3 5529; antes 6,4–7,4 mil).
Não reverifiquei: #7, #14, #20, #22, #23, #25, #26, #27, #29.

### NOVO (regressões e efeitos colaterais)
- **N1 Campeão toca DOIS stingers na aparição.** Log de áudio (`GNOSIS_AUDIO_LOG`) na tela 15: `boss_appear`=1 **e** `champion_enter`=1 no mesmo instante.
  Origem: `level.gd:777-780` abre o card (`Cinematic._run_boss`, cinematic.gd:546, toca `boss_appear`) e `enemy.gd:339` toca `champion_enter`.
  O comentário do `enemy.gd` diz que o stinger de chefe não toca para Campeão (R9), mas o card toca. Efeito extra: `boss_appear` solta a música de chefe
  (`audio_manager.gd:1231`). Arconte (tela 10) e Rei final (68) tocam `boss_appear` 1x (o anti-spam por nome protege). Dono: Áudio7/Polimento7 (card sem som no Campeão, ou `_run_boss` com flag).
- **N2 Final e Éons altos agora leves demais; Galila fica de fora.** Arcontes: 35–55 s e 0–1 quase-morte nos Éons 2, 4, 6, 7 e na 68 (final: 35–48 s, dano 86–128, antes 668–954);
  Galila (28) 83–102 s e 3–5 quase-mortes; Athoth (10) 54–72 s. Curva por Éon (quase-mortes, média 3 sementes): Torpor 11,7 · Fome 20,0 · Corrente 31,0 · Silêncio 36,3 ·
  **Espelho 40,3** · Praga 22,0 · Coroa 27,0 · **Centro+Final 2,3** (antes 9,0). O pico do Éon 5 segue, a queda na Praga segue e o clímax enfraqueceu (o bot não aparo, humano pode sentir diferente).
  Dono: Chefes6 (vida/dano da 68 e da Galila) + Progressão (Praga/Coroa).
- N3 O Rei da tela 1 cai em 39 s com 20 de dano (antes 79–85 s, 124–149): tutorial ok, mas é só 1 golpe de aviso. Observação, não bug.

### Rei / Demiurgo (só o estado; correções em curso no Chefes6/Polimento7)
- Manto: no 3.1 o Rei da tela 68 segue largo (o corpo cobre ~120 px do quadro 640 e fica colado à borda esquerda com o Colosso). Não medi a hurtbox (BossSizeProbe pede renderer).
- "Quadrado" visível: os candidatos, por leitura de `boss_hazard.gd:_draw`, são `shape=="column"` (a "mão" do Rei: `draw_rect` de 68 px x 428 px, translúcido com miolo branco, linhas 262/265)
  e `"band"` (o "raio": `draw_rect` retangular de borda dura em toda a arena, linha 254). Os dois são retângulos chapados sem máscara/gradiente; é onde eu procuraria. Não capturei o instante do poder.
- Verificar com o João qual poder foi (mão ou raio) antes de mexer.

## BILHETE PARA O SUCESSOR
Estado: re-teste da 3.1 (4dad743) feito, seção acima. Branch dir7/qa7 já tem o merge 1876106. Resultados em `_caps\qa7ot31\` e `p31\`.
Próximo: re-teste da 3.2 (quando o chefe avisar): `git merge <sha>` no qa7 (antes `git stash` nos `.import` que o Godot reescreve), importar, rodar
`powershell -File tools/qa7/reteste.ps1 -Out C:\gnosis-wt\_caps\qa7ot32` e comparar com `bot31nalise.md`. Leva ~10 min reais (não 50).
Armadilhas: chamar o reteste.ps1 pelo PowerShell (via bash o `\` do -Out some e o bot grava em lugar errado); o bot cura a 45% e não apara; "TRAVOU" precisa de confirmação;
descida da 65 dispara "zona forçada" (cinemática); `_real_wait` roda em tempo real (variação 5–10%); BossSizeProbe/Shot precisam de renderer (320x180 fora da tela).
Pendências para checar na 3.2: N1 (stinger dobrado do Campeão), N2 (final leve, Galila), #4/#6/#16 (EN), #10/#12/#11/#24.

