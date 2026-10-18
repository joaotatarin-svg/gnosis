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
- A renda é a do BOT (mata tudo, não morre de verdade — a morte custa 20% das faíscas). Um
  humano deve ganhar um pouco menos; se o playtest achar a loja seca, o ajuste é UMA linha
  (`WEAPON_COSTS`, `HP_BASE_COST`…) — `econ_sim.py` recalcula a curva.
- O bot (`_auto_shop`) não compra relíquias nem usa os tetos novos de vida; a curva de
  compra é SIMULADA (Python) sobre a renda medida, não jogada.
- O presente de arma do Soter (`npc_encounter.gd`) ainda pula o selo até a narrativa6 trocar
  para `gift_weapon_level()` (pedido feito).
- `tools/ui_menus/menu_probe.gd` tem os preços antigos fixos (não está no validate.ps1).
- Sem HUD da relíquia em uso nem aviso "selo aberto" (pedido ao ui5).
