# BALANCE — Onda 2 (17/10/2026), relatório do agente

Branch `dir2/balance`. Só ferramentas e documentos: nenhum número do jogo foi editado.
Rodadas brutas (txt/csv/log): `/home/user/caps/balance/runs/` (as de tempo antigo em `runs/legado/`).

## 1. Commits (16 + este)
`8046be8` semente/fontes/csv · `8b08a98` run.sh, compare.py, loja=gasta · `91e988e` ia=2 · `c68e52a` loja=teto ·
**`e47f535` bot no passo de física** · `4a17681` run.sh vel 1 · `cacffba` aviso r1–r7 · `aa7fe42` --papeis ·
`79317f5` sim=poca · `8495102` TRAVA + repro · `5ef134a` sim=poca3 · `73cae96`/`fc5362e` pedidos ·
`c24e6c3`/`1c20411` este relatório · `99fdaf9` docs/BALANCE.md r8.

## 2. O que mudou (arquivos)
- `tools/balance_bot.gd` — o bot:
  - **Conserto principal (o bot estava quebrado):** no Godot 4 `Engine.time_scale` só escala o delta, não
    aumenta os passos de física. Em vel 8 (r4–r8) cada passo de física era **0,13 s de jogo** (física a
    7,5 Hz), o bot reagia nesse ritmo e segurava botões 0,4 s de jogo (timer em tempo real). Agora o bot
    joga e mede no `_physics_process`, sobe `physics_ticks_per_second` para 60×vel (passo = 1/60 s de jogo
    em qualquer velocidade) e solta botões em tempo de jogo. `tempo=legado` reproduz o antigo.
  - semente re-semeada **por tela** (`seed=N`); dano por **fonte** (inimigo que bateu, `id(tiro)` para
    projétil com o atirador, `zona` para poça); faíscas ganhas, vida máx., maior golpe por tela; saída
    `out=<base>` → `.txt` + `.csv`.
  - modos de medição: `ia=2` (sai de poça, esquiva projétil), `loja=gasta` (gasta tudo em +vida),
    `loja=teto` (simula P1), `sim=poca` / `sim=poca3` (simulam P3), detecção de **TRAVA** (inimigo com
    vida 0 que não morre → encerra e marca a tela).
- `tools/balance/run.sh` — uma rodada em um comando (`--fixed-fps 60`, vel 1, `BG=1` para segundo plano).
- `tools/balance/compare.py` — compara duas rodadas (totais, por trecho, `--telas`, `--papeis`, fontes,
  teste de identidade); com um CSV só, faz o resumo.
- `tools/balance/repro_revive.gd` — prova mínima do bug da batalha final (rodar com `-s`).
- `docs/BALANCE.md` (como rodar + aviso r1–r7 infladas + r8), `docs/pedidos/onda2_balance.md`.

## 3. Determinismo (item 2 do brief)
- Com `--fixed-fps 60` + semente por tela: **67 de 68 telas idênticas** entre duas rodadas iguais
  (`r8` × `r8b`; também na versão antiga `r8_s1a` × `r8_s1b`). Uma rodada SEM semente também bateu nas
  67 telas: o jogo quase não sorteia nada de jogo.
- A exceção é a **tela 68**: `final_battle.gd:100` usa `randi()` global, que o `Audio` também consome
  em quantidade dependente do relógio real (`gib.gd:105`, `audio_manager.gd:227`). 440 × 590 × 971 ×
  1255 de dano na mesma tela. Pedido à Encenação (RNG próprio).
- Sem `--fixed-fps` o delta segue o relógio real: não use para comparar.
- **Sensibilidade do bot:** pequenas mudanças de política (ia=2) mexem até 2–3× numa tela isolada; os
  agregados por Éon variam ~10–30%. Leia tela a tela só o que se repete entre modos.

## 4. r8 — linha de base (bot corrigido, vel 1, Normal, loja clássica: só arma e magias)
Total **30,3 min de jogo · 6 880 de dano · 70 quase-mortes (vida < 45%) · 0 timeouts**.
(Antes do conserto, a mesma build dava 68,7 min · 17 527 · 214 · 4 timeouts.)

| Éon | trav. (mediana) | campeão | antessala | Arconte | dano/min |
|---|---|---|---|---|---|
| Rei (tela 1) | — | — | — | 72 | — |
| Torpor | 22 | 43 | 27 | 37 | 103 |
| Fome | 16 | 32 | 19 | 62 | 71 |
| Corrente | 54 | 65 | 105 | 93 | 156 |
| Silêncio | 62 | 119 | 34 | 97 | 153 |
| Espelho | 81 | 70 | 114 | 169 | 220 |
| Praga | 134 | 210 | 96 | **639** | 300 |
| Coroa | 158 | 139 | **358** | 432 | 342 |
| Centro (3) / Mente | — | — | — | 197 / 440 | — |

Leitura: Torpor e Fome são fáceis (Fome fica **abaixo** do Torpor); a subida real começa na Corrente e
dobra na Praga. As maiores fontes de dano no run: `zona` (poças de Belias) 607, `arauto(tiro)` 584,
Armupiel 432, `alado(tiro)` 410, `bruto` 382, `invocador(tiro)` 368. Todo o calor de "r4–r7 HOT em
quase todas as telas" era artefato da física grossa.

**Economia:** o run dá **12 809 faíscas**; arma (500) + magias gastam ~1 300; **sobram 11 469**.
`r8_gasta` (gasta a sobra em +20 de vida, 60 cada, sem limite): vida máx. **2 680** na tela 64,
quase-mortes **70 → 2**. A loja hoje desliga a dificuldade para quem compra vida.

## 5. Propostas numéricas (com dados; nenhuma aplicada)
Sem truques de recompensa: tudo fixo e determinístico, nada sorteado (NEURO §3).

**P1 — +20 de vida máx. com preço crescente e teto** (Técnico/UI-menus)
`scripts/ui/upgrade_menu.gd:102` `_add("+20 de vida máx.", "", 60, ...)` e `:169` `buy_max_health(20, 60)`:
hoje 60 fixo e sem limite → proposto **60 × (n+1)** (60, 120, 180…) e **no máximo 10 compras** (+200,
vida máx. 320). Precisa de um contador `Progression.hp_buys` (salvo no run; zera em `reset_run`).
Simulado (`r8_teto`): vida 120 → 220 (tela 28) → 320 (tela 46); quase-mortes **70 → 21**, concentradas
onde devem (Belias 3, antessala da Coroa 2, Armupiel 2, Mente 2); o resto do run fica com 0–1 por tela.
Ainda sobram 8 174 faíscas → ver P2.

**P2 — Restauração não é vendida no meio da luta** (UI-menus)
`upgrade_menu.gd:106` (cura cheia por 50) aparece também pela pausa (`pause_menu.gd:74`) com a zona
travada. Com 8–11 mil faíscas sobrando, isso é cura infinita. Proposto: só oferecer Restauração quando
`RunManager.pending_advance` (santuário e pós-chefe) ou com a zona destravada; no meio da luta a linha
aparece trancada com "fora de combate". Preço 50 mantido. (Não simulado: o bot não compra cura.)

**P3 — Belias: poças mais curtas** (Combate)
`scripts/entities/enemy.gd:599` `HazardZone.spawn(..., "poison", r, 5.0, ...)` duração **5,0 → 3,0 s**;
`enemy.gd:598` raio fase 2 **48 → 40** (fase 1 fica 34).
Dados: tela 55 = 639 de dano (376 de poça) contra 432 do Armupiel, o Arconte seguinte; é o pico do run em
TODOS os modos do bot (clássico 639 · ia=2, que foge das poças, 1 137 + timeout · legado 749). Poças que
não somam (`sim=poca`) só tiram ~13% (639 → 559) — o problema é a cobertura do chão, não a soma.
Resultado simulado (`sim=poca3`): ver §5a abaixo.

**P4 — antessala da Coroa: o Elite não pode ser o Invocador** (Encenação)
`scripts/levels/level.gd:369-372`: o Elite é sempre o último da última wave. Na tela 63 a escolha
modular (`run_manager.gd` `zone_plan`, antessala) monta escudeiro, alado, bruto, arauto, fantasma e um
**Invocador Elite** (×2,2 de vida, recua, chama larvas). Dano 358 (3–10× as outras antessalas: 19–114) e
quase o do Arconte (432). Proposto: se o último da wave for `invocador` (ou estilo `ranged`), o Elite passa
para o último corpo a corpo da wave. Muda 4 telas: 63 (Invocador Elite), 43 (Arauto Elite), 34 e 41
(Alado Elite). Versão mínima: só o Invocador (muda só a 63).
Efeito esperado: parcial (o tiro de alado/arauto continua) — confirmar com o bot depois.

**Observação (sem número):** Fome mais fácil que Torpor (71 × 103 de dano/min). Não proponho mexer antes do
playtest: os inimigos de longe (sonâmbulo) pesam mais para o bot do que para um humano.

### 5a. Simulação de P3 (`r8_poca3`)
Tela 55 (Belias): **639 → 528** de dano (poça 376 → 232, −38%), 51,9 → 47,7 s, quase-mortes 8 → 7.
Belias continua o pico dos Arcontes (Armupiel 432), mas o salto Espelho → Praga fica menor.
Cuidado ao ler o total do run (6 880 → 6 259): a simulação também encolheu a poça que o Portador de
Esporos deixa ao morrer (`enemy.gd:869`, a P3 não mexe nela) e, a partir da tela 47, as lutas divergem
em cascata (vida carregada entre telas); a queda de −32% na Coroa é efeito dessa cascata, não da P3.
Se quiser Belias no nível do Armupiel, um passo a mais seria o tique da poça hostil 0,7 → 1,0 s
(`hazard_zone.gd:64`) — não simulado.

## 5b. Validação (`TIMEOUT=900 tools/validate.sh`, completo menos CodexPlaytest)
```
Scripts OK · ScriptCheck OK · GnoseQA OK (18) · SaveQA OK (13) · PuppetQA OK · HeroQA OK · WaveQA OK
CodexQA FALHOU (32 pass) — "diretório de save independente" (falso conhecido do override.cfg)
AudioQA FALHOU (23 pass) — duck() (bug conhecido do Áudio)
```
Mesmo estado da base: nada piorou (só mexi em ferramentas/documentos).

## 6. Como comparar r8 × r9 depois do Combate (item 4 do brief)
```
tools/balance/run.sh r9            # uma rodada por vez (fila de CPU); ~35 min de relógio com a máquina cheia
python3 tools/balance/compare.py /home/user/caps/balance/runs/r8.csv /home/user/caps/balance/runs/r9.csv --papeis
```
A misericórdia oculta do Combate não muda o medidor (o bot cura a 45%). Hitstop/slow-mo novos mudam o
tempo de jogo por tela, não o dano. Lembre: a tela 68 varia sozinha até a Encenação usar RNG próprio.

## 7. O que NÃO ficou bom / limites
- O bot não bloqueia nem faz parry; o dano dele é teto, não média humana. Não medi um humano.
- Projétil é atribuído ao inimigo mais perto no nascimento (pode errar em grupo).
- `sim=poca3` e `loja=teto` são simulações dentro da ferramenta, não o jogo alterado.
- P2 e P4 não foram simuladas.
- Achado fora do balance, mas grave: **soft-lock na batalha final** (pedido 1, BLOQUEANTE para o Combate).
