# PROGRESSÃO 6 — economia, selos por Arconte, relíquias e pulo duplo (Onda 6)

Branch `dir6/progressao6` (base 37ea6f5 + merges de `origin/dir6/mapa6` e `origin/integracao/onda1`).
Queixa do João: *"antes do 2º chefe já tinha upgrades no nível máximo"*.

## 1. Diagnóstico medido (bot, antes)
Rodada `antes` (BalanceBot, vel 4, seed 1, `--fixed-fps 60`, telas 1–68, código da base):
o run dá **13 763 faíscas** (11 100 até o Centro; a Mente sozinha dá 2 663). A loja inteira
custava **5 120** (arma 500, magias 960, vida 3 300, Éter 60 sem teto) e abria **a qualquer
hora pela pausa**. Até o 2º Arconte (tela 19) o run já deu **1 431**: arma (500) + Esfera e
Névoa no máximo (240) cabem com folga. Simulado com a renda medida
(`tools/progressao6/econ_sim.py`): jogador focado na arma chega ao **Nv.5 na tela 10**
(1º Arconte!); comprando o mais barato, arma no topo na tela 21 e Éter na tela 10.
Confirmado também pelo bot do mapa6 ("arma Nv.5 na tela 19").

## 2. O redesenho (tudo em `scripts/autoload/progression_manager.gd`, constantes no topo)
**Grau** = Arcontes vencidos NESTE run (`Progression.progress_tier()`, 0..7; o roubo não
tira; fora do run — Provação/testes — é 7 e nada é selado). Cada trilha tem o nível máximo
SELADO pelo grau; o resto é preço.

| Trilha | ANTES | DEPOIS |
|---|---|---|
| Arma Nv.2/3/4/5 | 50/100/150/200 (500), sem selo | **200/450/900/1500** (3 050); Nv.3 (aéreos) após **Athoth**, Nv.4 após **Galila**, Nv.5 após **Astaphaios** |
| Magias Nv.2/Nv.3 | 40/80 cada (960 no total) | Nv.2 **150+40·k**, Nv.3 **400+80·k** (k = nº do Anel; Esfera k=0) (7 760); Nv.2 sai com o Anel, Nv.3 pede **2 Arcontes depois** |
| +20 vida máx. | 60×(n+1), 10 compras (3 300), sem selo | **90×(n+1)**, 10 compras (4 950); **teto 3 + grau** (a 10ª só após o 7º Arconte) |
| +15 Éter máx. | 60 fixo, **sem teto** | **80×(n+1)**, 6 compras (1 680); **teto 1 + grau** |
| Restauração | 50 | **50 + 15×grau** (50…155); continua só no santuário/pós-chefe |
| Relíquias | — | Brasa Viva 350 (grau 1) · Lâmpada de Óleo 350 (grau 2) · Pérola do Hino 500 (grau 3) |
| **Tudo** | **5 120** (+ Éter infinito) | **18 640** — o run dá ~13,8 mil: não dá para comprar tudo |

Loja (`upgrade_menu.gd`, visual igual): a linha selada aparece apagada com o preço e
"selado · vença <Arconte>"; no foco a faixa diz "Selado · vença Galila para abrir".
O 1º item continua a arma (Nv.2 aberta desde o início, 200).

### Curva ganhas × gastas (simulada sobre a renda MEDIDA do bot com o mapa, rota 1)
Perfil FOCADO na arma (junta faísca para o próximo nível aberto; vida em 2º):

| Éon (fim) | tela | ganhas | ANTES: arma / vida / mag.máx | DEPOIS: arma / vida / mag.máx |
|---|---|---|---|---|
| Torpor | 10 | 572 | **5** / 1 / 0 | 2 / 1 / 0 |
| Fome | 19 | 1 563 | 5 / 5 / 0 | 3 / 4 / 0 |
| Corrente | 28 | 2 548 | 5 / 7 / 0 | 3 / 5 / 0 |
| Silêncio | 37 | 4 317 | 5 / **10** / 3 | 4 / 6 / 0 |
| Espelho | 46 | 6 341 | 5 / 10 / 6 (e Éter 6/6) | 4 / 7 / 1 |
| Praga | 55 | 8 256 | — | **5** (tela 49) / 8 / 1 |
| Coroa | 64 | 11 529 | — | 5 / 9 / 4 |
| Centro | 67 | 12 098 | — | 5 / **10** (tela 67) / 4 |

Perfil "compra o mais barato" (o que maximiza ícones cheios cedo): ANTES arma no topo na
tela 20, vida 40, Éter 10, magias 64; DEPOIS arma Nv.3 no fim, vida 9/10, Éter 6/6 na tela
48, magias 7/8 — **nenhuma trilha principal no topo antes da tela 64**. Saída completa:
`python tools/progressao6/econ_sim.py C:/gnosis-wt/_caps/progressao6/runs/depois_mapa.csv --perfil arma`.

## 3. Escolhas reais
- **Não cabe tudo**: 18,6 mil de loja × ~13,8 mil de renda (≈ 70%). Quem foca arma termina com
  4–5 magias no máximo; quem foca magias fica com a arma no Nv.3–4.
- **Relíquias** (`GameContent.relics`): UMA em uso; comprar já equipa; trocar entre as
  compradas é de graça em qualquer loja. Efeito de estilo, não só número:
  - **Brasa Viva** (350, após Athoth): cada faísca que te ALCANÇA cura 2 (3–9 faíscas por
    inimigo) — recompensa lutar perto e ir buscar a faísca.
  - **Lâmpada de Óleo** (350, após Harmas): cada faísca devolve 3 de Éter — para quem vive
    de Anéis.
  - **Pérola do Hino** (500, após Galila): +25% de toda faísca ganha (perdas não) — a aposta
    da ganância: abre mão da cura/Éter. Simulado: paga-se e rende ~+2 000 no run.
  Efeitos: Brasa/Lâmpada em `spark_orb.gd` (na chegada do orbe; nunca em corpo caído);
  Pérola em `Progression.add_orbs`.

## 4. Mapa (merge do mapa6)
`EonMap.REWARDS` dá faíscas, vida/Éter e cura por nó vencido. Medido (bot rota 1): renda
**13 804** contra 13 763 sem mapa (+0,3%; as telas do mapa são lutas menores e a recompensa
compensa) e **+54 de vida máx.** de graça no run. O teto teórico era ~210 de vida grátis
(rota só perigo/Arena/segredo — mais que a trilha da loja inteira, +200). Cortei SÓ a vida/
Éter: perigo 5→**4** vida, escalada 5→**4** Éter, Arena 8→**6** vida, segredo 10/10→**8/8**.
Faíscas e cura iguais. Presentes (mapa, Soter) não gastam compras da loja: os contadores
`#vida`/`#eter` nascem zerados no `reset_run`.

## 5. Pulo duplo (contrato da onda)
`Progression.has_double_jump()` / `grant_double_jump()` (idempotente, sinal
`double_jump_granted`). **Por run** (o Soter concede numa cena; run novo começa sem).
`RunManager.has_double_jump()` (mapa6) já delega para cá.

### Persistência sem tocar no run_manager
Pulo duplo, contadores da loja e relíquias vão DENTRO de `Progression.items` como
`"#chave=valor"` (`#pulo_duplo=1`, `#vida=3`, `#eter=1`, `#reliquias=brasa,perola`,
`#reliquia_ativa=perola`). `items` já é salvo/restaurado pelo `run_snapshot`/`continue_run`
com o conversor tolerante. `item_features()` filtra o `#` (a arte só vê roupa).
Save antigo (sem as entradas) = sem pulo duplo, sem relíquia, compras deduzidas do bônus
(fórmula antiga exata: 20·n + 25·k do Soter). `items` quebrado no save → padrão.

## 6. Outras APIs
`gift_weapon_level()` (presente do Soter respeitando o selo) · `weapon_sealed()`,
`weapon_next_tier()` · `skill_sealed(id)`, `skill_next_tier(id)`, `skill_ring_index(id)` ·
`hp_buys()`, `hp_buy_cap()`, `buy_health_upgrade()` · `mp_buys()`, `mp_buy_cap()`,
`buy_mana_upgrade()` · `heal_cost()` · `relic_data/owned_relics/has_relic/equipped_relic/
relic_sealed/buy_relic/equip_relic` · `tier_gate_name(n)` ("Athoth"…). `buy_max_health(n,
custo)`/`buy_max_mana` continuam (presentes e bot).

## 7. Validação
- `tools/progressao6/ProgQA.tscn` (novo, headless): **43 PASS / 0 falhas** — selos, preços,
  tetos, presentes ≠ compra, relíquias (+25% só no ganho), linha selada na loja e a faixa
  "vença Athoth", pulo duplo pelo save do run (JSON + `continue_run`), save antigo, `items`
  quebrado.
- MapQA 22 PASS · SaveQA 0 falhas · LangQA 12 ok · EnFit 0 falhas · i18n
  `build.py --strict` 1361/1361 (lote `12_progressao6.tsv`).
- `validate.ps1 -Repeat 2` (após merge de `origin/integracao/onda1`, 18/10): **TUDO VERDE, 11 etapas, 2/2**
  (Scripts, ScriptCheck, CodexQA 53, AudioQA 54, GnoseQA 20, SaveQA 49, PuppetQA, HeroQA, WaveQA,
  TecnicoQA 43, LangQA). Obs.: numa rodada anterior com o PC carregado e prioridade baixa,
  GnoseQA/AudioQA falharam por tempo (card de chefe); em prioridade normal passaram.
- `econ_sim.py --checa`: as constantes do simulador batem com o `.gd`.
- Capturas (fora do git): `C:\gnosis-wt\_caps\progressao6\loja_antes_grau1_arma3.png` ×
  `loja_depois_grau1_arma3.png` (mesmo estado: após Athoth, 900 faíscas, arma Nv.3 — antes
  a arma Nv.4 custava 150 e estava aberta; depois custa 900 e está selada até Galila),
  `loja_*_grau1.png`, `loja_depois_grau0.png`. Ferramenta: `tools/progressao6/ShopShot.tscn`.

## 8. Limites honestos
- A renda é a do BOT (mata tudo, não morre de verdade — a morte custa as faíscas ganhas na tela, §12). Um
  humano deve ganhar um pouco menos; se o playtest achar a loja seca, o ajuste é UMA linha
  (`WEAPON_COSTS`, `HP_BASE_COST`…) — `econ_sim.py` recalcula a curva.
- O bot (`_auto_shop`) não compra relíquias nem usa os tetos novos de vida; a curva de
  compra é SIMULADA (Python) sobre a renda medida, não jogada.
- O presente de arma do Soter (`npc_encounter.gd`) ainda pula o selo até a narrativa6 trocar
  para `gift_weapon_level()` (pedido feito).
- `tools/ui_menus/menu_probe.gd` tem os preços antigos fixos (não está no validate.ps1).
- Sem HUD da relíquia em uso nem aviso "selo aberto" (pedido ao ui5).

## 9. Onda 7 — a CURVA (iteração 2) e a renda igual em todas as dificuldades
Sucessor do diretor de Progressão, 28/10. Base: merge de `origin/integracao/onda1` = **4dad743 (3.1)**
neste branch (8757da6). A 3.1 trouxe a renda de faíscas **igual** em todas as dificuldades (antes o
Difícil rendia 1,5× e o Muito Difícil 2,2× — o BALANCE r7 foi medido assim).

### 9.1 O que já vinha da Onda 7 (antecessor, 941e8a0 / eea11d9)
- Arma espalhada até a reta final: custos **200/500/1100/1800**, Nv.3 após Athoth, **Nv.4 após Yabel**
  (tela 37), **Nv.5 após Belias** (tela 55).
- Segundo engaste (2 relíquias em uso, 1 500, após Astaphaios) e **Coro das Faíscas** (700, após
  Astaphaios) como destino das faíscas do fim — preço fixo, sem sorteio.
- `Progression.claim_once(chave)`: baú, Selos, Adormecido e a recompensa de cada camada do mapa pagam
  **uma vez por run** (morrer e voltar não paga de novo). Respiro entre ondas 0,8 → 2,0 s.

### 9.2 Ferramenta nova: o ProgBot joga a LOJA REAL
`tools/progressao6/ProgBot.tscn` (cópia do QA7Bot, que não está no repo) + `dif=0|1|2` e `loja=real`:
compra pela API da `Progression` (selos, tetos e preços de verdade) ao fim de TODA tela (a pausa abre a
loja a qualquer hora) com o perfil `arma` (focado: arma > vida > magias > Éter, junta para o 1º item
aberto) ou `guloso` (sempre o mais barato — o pior caso para "tudo no máximo cedo"). Lote:
`tools/progressao6/run_bots.ps1` (BelowNormal, 4 CPUs, headless, `--audio-driver Dummy`). Leitura:
`python tools/progressao6/curva.py <csv...>` (por Éon: ganhas/gastas, arma, vida, Éter, magias Nv.3,
compras, maior jejum sem compra, quase-mortes, mortes reais, timeouts, maior golpe em % da vida).
O `econ_sim.py` (Python) bate com o bot: mesma renda → mesma curva nas duas ferramentas.

### 9.3 Mudança desta iteração (uma só)
- **A 6ª compra de Éter só depois de Belias** (`MP_LAST_TIER = 6`; antes 1 + grau abria a 6ª no grau 5).
  Motivo medido: o perfil guloso enchia o Éter na **tela 48** — a única trilha no topo antes da Praga.
  Agora nenhuma trilha fecha antes da tela 55, igual à 10ª vida (que já esperava o 7º Arconte).
  A loja mostra o Arconte certo na linha selada (`hp_buy_tier(n)` / `mp_buy_tier(n)` na Progression).
- ProgQA: **58 PASS / 0** (novos: selo da última compra de Éter/vida; grau 5 para em 5/6; grau 6 abre).
  O caso de `claim_once` passou para o fim: o `continue_run()` dele troca de cena (adiada) e tirava o QA
  da árvore no meio do teste da loja (`process_frame` em null e o processo não fechava).

### 9.4 A curva medida (ProgBot, loja real, Normal, sementes 1 e 2 — run de 68 telas)
Perfil FOCADO (arma > vida > magias > Éter):

| Éon (fim) | tela | ganhas | gastas | arma | vida | Éter | magias Nv.3 | compras no Éon |
|---|---|---|---|---|---|---|---|---|
| Torpor | 10 | 621–640 | 470 | 2 | 2/10 | 0/6 | 0 | 3 |
| Fome (2º Arconte) | 19 | 1 624–1 773 | 1 600 | 3 | 4/10 | 0/6 | 0 | 3 |
| Corrente | 28 | ~2 830 | 2 620 | 3 | 5/10 | 0/6 | 0 | 4 |
| Silêncio | 37 | ~4 600 | ~4 350 | 3 | 6/10 | 0–1/6 | 2 | 4–5 |
| Espelho | 46 | ~6 800 | ~6 200 | 4 | 7/10 | 0–1/6 | 2 | 2–3 |
| Praga | 55 | ~9 100 | ~8 600 | 4 | 8/10 | 1–3/6 | 3–4 | 4–7 |
| Coroa | 64 | ~12 400 | ~11 900 | **5 (tela 59)** | 9/10 | 1–3/6 | 4 | 3–4 |
| Centro | 67 | ~13 000 | ~12 800 | 5 | **10/10 (tela 66–67)** | 1–3/6 | 4 | 1 |

**Em uma frase:** ~15 mil faíscas no run, **26–31 compras** (uma a cada 2–3 telas, 2–7 por Éon, maior
jejum 3–6 telas), **nenhuma trilha no topo antes da tela 56** (arma 59, vida 66–67, Éter 56 só no perfil
guloso, magias todas nunca) e antes do 2º Arconte a Sophia tem arma Nv.3/5 e vida 4/10.
Guloso (só compra o mais barato): Éter no topo na tela 56 (era 48 antes desta iteração), arma presa no
Nv.3 — ver limite abaixo. A loja inteira custa ~21,4 mil (relíquias e engaste inclusos): escolha real.
Sobra no fim: ~0,1–0,7 mil no Centro; a tela 68 (Mente) rende ~2,5 mil que não têm onde ser gastas (fim).

## 10. CHECAGEM DE SATISFAÇÃO (NEURO_SATISFACAO.md §2–§4) — Onda 7
| Decisão | R / § atendidas | Violadas? | §4 conferido |
|---|---|---|---|
| Arma Nv.4 após Yabel, Nv.5 após Belias; 10ª vida após Armupiel; **6ª compra de Éter após Belias** | §3 competência (cada Arconte vencido abre algo que se vê na loja — a recompensa vem de ter ido bem, não de sorte); a queixa do João ("máximo antes do 2º chefe") fechada com medida | Nenhuma. Selo ≠ escassez artificial: o preço e o selo são FIXOS, mostrados na loja ("vença Belias"), sem prazo nem sorteio | 12 (sem recompensa variável), 13 (uma mudança só nesta iteração, medida antes/depois) |
| Renda IGUAL em todas as dificuldades (3.1) | §3 "dificuldade vem do combate"; a loja anda igual nas três (selos) | Nenhuma; Muito Difícil fica duro (golpe de 37–42% no Torpor) — anotado para quem cuida do combate | 12 |
| Não dá para comprar tudo (~15 mil × ~21,4 mil) | SDT: autonomia — escolha entre arma, vida, magias, relíquias | Nenhuma: nada some com o tempo, nada se perde por não comprar (sem FOMO) | 12 |
| `claim_once` (baú/Selo/Adormecido/camada pagam 1×) | §3: quantidade fixa e determinística | Nenhuma: tira a "farmagem" de morrer e voltar | — |
| Respiro de 2 s entre ondas | R21 | Nenhuma | 5 (sem slow-mo) |
| **Morte leva SÓ as faíscas ganhas NA TELA atual** (era 20% da carteira) — §12 | §3: sem aversão à perda como motor; a perda é a da própria tela que recomeça (coerente com o checkpoint), nunca o que já era seu | Nenhuma | 12 |
| Recompensa já paga **avisa** ("Recompensa já recolhida neste run") em vez de pagar 0 calado; baú secreto com chave própria — §12 | §3 quantidade fixa e TRANSPARENTE; R21 (aviso curto, no toast do HUD, sem clarão) | Nenhuma | 12 |

## 12. Ressalvas do Guardião + decisão do chefe (29/10) — DELEGAÇÕES REGISTRADAS
- **Baú secreto pagava 0 calado**: baú comum e secreto da mesma tela usavam `bau:<tela>`. Agora o secreto é
  `bau:<tela>:s` (`chest.gd`). Novo `Progression.claim_once_or_notice(chave)`: se já foi pago, avisa no HUD
  "Recompensa já recolhida neste run" (`notice_claimed()`; tenta de novo por ~6 s se a cena ainda não montou
  o HUD — caso da recompensa do mapa, `run_manager._grant_reward`). Usado em baú, Selos e Adormecido.
- **Morte (decisão do chefe)**: perde só `Progression.screen_gain` (faíscas GANHAS nesta tela; zera em todo
  `RunManager.screen_changed`; nunca mais que a carteira — `Progression.death_loss()`).
  **Delegação do chefe:** edição mínima em `scripts/levels/level.gd` (`_commit_death`, a linha do `lost`).
  Também, por ser o mesmo pedido ("diga isso na fala da morte"): **uma linha** de `narrative.gd`
  (`death_revive`, a fala do narrador: "A tela recomeça, e as faíscas dela também. N faíscas escorrem…") e a
  tradução dela no lote `01_narrative_a.tsv` (narrativa6), e o teste `morte_custa_20pct_faiscas` do
  `tools/tecnico/tecnico_qa.gd` (técnico) virou `morte_custa_faiscas_da_tela` (100 na carteira, 30 da tela → 70).
- Validação: ProgQA **62/0** (novos: chave do secreto + aviso; perda = ganho da tela; teto da carteira; tela
  nova zera), validate.ps1 **TUDO VERDE (14)**, i18n strict 1456/1456.

## 11. BILHETE PARA O SUCESSOR (29/10)
- **Estado (29/10, encerrado):** curva fechada (§9.4), Difícil/Muito Difícil conferidos com renda igual
  (BALANCE.md §8), base = integração ba91602 (merge 3d13bbd), ressalvas do Guardião e morte nova (§12)
  APROVADAS (68bcaea) + limpeza de comentários. validate.ps1 **TUDO VERDE (14 etapas)**; ProgQA 62/0;
  `econ_sim.py --checa` ok; i18n strict 1456/1456.
- **Decisão do chefe (29/10):** a morte não tem custo econômico real (só as faíscas da tela, que a tela
  devolve ao ser refeita) — o custo é TEMPO; morrer rende menos que seguir. O playtest dirá; não reabrir
  sem dado de playtest.
- **Combinado com o chefes6:** a economia NÃO baixa a força do fim; os chefes calibram contra a tabela de
  potência em `docs/pedidos/progressao7.md` (arma Nv.5 + ~380 de vida no final).
- **Arquivos-chave:** `scripts/autoload/progression_manager.gd` (constantes no topo: `WEAPON_COSTS/TIER`,
  `HP_*`, `MP_*`, `MP_LAST_TIER`, `SKILL_*`, relíquias), `scripts/ui/upgrade_menu.gd` (linha selada usa
  `hp_buy_tier`/`mp_buy_tier`), `tools/progressao6/{ProgBot.tscn, prog_bot.gd, run_bots.ps1, curva.py,
  econ_sim.py, prog_qa.gd}`.
- **Medir de novo:** `powershell -File tools/progressao6/run_bots.ps1 -Out C:\gnosis-wt\_caps\progressao7\rN
  -Jobs "dif=0 perfil=arma seed=1;dif=1 perfil=arma seed=1;dif=2 perfil=arma seed=1;dif=0 perfil=guloso seed=1"`
  (~15–25 min) e `python tools/progressao6/curva.py <csv>`. Mudou constante → mude `econ_sim.py` e rode `--checa`.
- **Armadilhas:** o `*_console.exe` do Godot abre o Godot de verdade como FILHO — a prioridade/afinidade
  tem que ir no filho (o run_bots.ps1 já faz). O CSV do bot tem vírgulas no campo `left` (curva.py trata).
  No ProgQA, caso que chama `continue_run()` tem que ser o ÚLTIMO (troca de cena adiada mata o QA).
  `tools/qa7/` é cópia não versionada do QA7 — não commitar.
- **Próximo passo (se pedirem):** (1) o perfil guloso nunca junta para a arma Nv.4 (1 100) — se o
  playtest mostrar jogador "preso" no Nv.3, a resposta é a loja mostrar "faltam X" na arma (pedido ao ui),
  não baratear; (2) acertar com o chefes6 a força do fim (pedido em `docs/pedidos/progressao7.md`).
