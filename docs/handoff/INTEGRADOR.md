# BILHETE DO INTEGRADOR-CHEFE (Onda 6) — atualizado a cada integração

Worktree `C:\gnosis-wt\integ` (branch local `integracao/onda1`; `override.cfg` nunca vai pro git).
Ritual: checkout/clean → merge --no-ff → (i18n gerado: --ours + normalizar strings.csv/_orfas.csv/
godot/gnosis_text.csv para LF + extract + build --strict = 0 faltando) → reimporte 2× →
`tools/validate.ps1 -Repeat 2` TUDO VERDE → push `origin HEAD:integracao/onda1`.
Atenção: `core.autocrlf=true` faz o strings.csv voltar em CRLF e o extract perder traduções com quebra
de linha (viram órfãs) — sempre normalizar para LF antes do extract.

## Integrado (18/10/2026) — todos verdes 2/2
| Branch | Merge | Notas |
|---|---|---|
| (base) Ondas 1–5, i18n, arte, mapa6, loja v3, progressao6 | d3be8db | |
| dir2/arte-gpt (morte de chefe com peso, head_point) | ce2e35e | |
| dir6/level6 | f9bd7c5 | i18n regerado |
| dir5/encenacao5 (narrativa 6) | cc41056 | pedidos onda6_narrativa6 juntados |
| dir6/combate6 (1ª entrega) | 0bcf102 | |
| dir6/chefes6 | fc83d8a + 19540e4 | 19540e4: classe interna `Pendulum` do boss_galila → `GalilaPendulum` (colidia com a global do level6); lote i18n 15_chefes6_interno |
| dir6/inimigos6 | 8ae2e69 | conflito em enemy.gd (_begin_strike/_process_strike): brain (chefes6) antes de _mv (inimigos6) |
| dir6/ui6 | f7cf6ce | |
| dir6/combate6 d2f3e74 (+ arte-gpt b618400: S17/S18, frame_geometry) | ec64161 | |
| dir2/arte-gpt 7163c12 (Fila 9 blocos 2+3: voadores, acólito/cornudo/fantasma, 7 Campeões) | a727e5d | sem conflito; entrou ANTES do chefes6 (já estava validado quando chegou a ordem "chefes6 primeiro") |
| dir7/vfx7 e44be25 | 74af54a | lote i18n 16_vfx7_interno (ProjectileFX) |
| dir2/arte-gpt 60a8cf7 (cor real da pintura) | a2ea6c2 | autorizado antes da regra do Guardião; auditoria depois |

## REGRA NOVA (18/10): Guardião da Satisfação
Só integrar branch com veredito APROVADO / APROVADO COM RESSALVAS do Guardião (dir7/guardiao, docs/onda2/GUARDIAO.md,
seção do branch). Sem veredito → avisar o chefe. A prévia 3.1 também precisa de auditoria antes do build.
Versões internas: preview/<versão> + `_build\preview<versão>`, SEM atalho no Desktop.

## Fila aguardando veredito do Guardião
- dir2/arte-gpt 62f3ed0 (Fila 9 bloco 4: Soter abençoando + poses de cena; inclui 60a8cf7)
- dir5/encenacao5 (cena do Soter, quando a Narrativa ligar)
- dir6/chefes6 (recalibração; topo era 50a89eb WIP)
- dir7/polimento7 661a1a0 (FLASH_ADD 0,42; hurtbox pelo frame_geometry; POLIMENTO7.md)
- Onda 7 ainda sem entrega final: dir7/audio7, dir7/qa7, dir7/dublagem (WIP).

## Instabilidade observada
- 18/10, merge a2ea6c2, máquina sob carga (tempos 2×): PuppetQA crashou 1× no arranque (exit -1066598273, log só com
  o banner). Repetido 3/3 verde e validate completo 2/2 verde. Se repetir → chefe passa ao técnico.
- Reimporte: o 1º `--editor --quit` às vezes sai com -1073741819 (conhecido); o 2º passa.

## Prévia 3 — FEITA
`preview/3` = ec64161 + cherry-pick e065c85 (save GNOSIS-Previa) → 65b2860 (push feito).
Build: `C:\gnosis-wt\_build\preview3\GNOSIS.exe` (+ .pck, LEIA-ME.txt). Atalho Desktop "GNOSIS - prévia 3.lnk".
Exportado do worktree `C:\gnosis-wt\preview` (preset "Windows Desktop", `--export-release`). Abertura headless sem erro.

## Problema conhecido (devolvido ao chefes6 pelo chefe)
BossProbe (telas=all vel=3) em ec64161: lutas ~2× mais longas que o r4 do CHEFES6.md; TIMEOUT 420 s no
Armupiel (64) e na batalha final (68). 91× "Function blocked during in/out signal (set_deferred monitoring)".
Log: `C:\gnosis-wt\_caps\integ\bossprobe_ec64161.log`.

## Onda 7 - Prévia 3.1 FEITA (28/10/2026)
- Ferramenta nova: `tools/integrar.ps1 "branch sha" ... [-Repeat N] [-Push]` (merge --no-ff em lote; conflito só de i18n
  = --ours + LF + extract + build --strict + commit; reimport 2x; validate; imprime só VERDE/VERMELHO; log em
  `_caps\integ\integrar_*.log`). Roda em BelowNormal, Godot headless + Dummy.
- Lote 3.1 (validate -Repeat 2, VERDE): vfx7 a63c40b -> 6d0cf90; chefes6 b0b52f0 -> 52699d2; polimento7 2d54867 -> 65f8ed4
  (Guardião aprovou 2d54867; ressalvas menores vão em commit novo do Polimento7 na 3.2). Push: origin/integracao/onda1 = 65f8ed4.
- BossProbe (telas=all vel=3, `_caps/integ/bossprobe_65f8ed4.log`, UTF-16): todas as lutas terminam [ok], sem TIMEOUT.
  Tempos: Rei 83 s, Athoth 196 s, Harmas 81, Galila 135, Yabel 160, Astaphaios 171, Belias 115, Armupiel 100, Rei+Colosso 186
  (antes, ec64161: Armupiel e final estouravam 420 s). Athoth (196 s, 2 quase-mortes) é o mais longo: candidato a ajuste.
- Build: `C:\gnosis-wt\_build\preview3_1\GNOSIS.exe` + LEIA-ME.txt; branch `preview/3.1` (= 65f8ed4 + cherry-pick do save
  GNOSIS-Previa) f9e3557, push feito. SEM atalho no Desktop. Abertura headless sem erro (só "2 resources still in use at exit").
- Fila 3.2 (aprovados): arte-gpt de546f8 (+50f807a, auditar), mapa7 8e8afc3, encenacao5 0561f28+9e1d21a, ui7 12c6643, perigos7 04afd65;
  depois cenario7 e progressão. **Conferir ao entrar encenacao5 0561f28+9e1d21a: `champion_enter` e o cue da encenação não tocam
  dobrado na aparição do Campeão.** Commit novo do Polimento7 (ressalvas do Guardião) entra junto.
- Armadilha: `git checkout -- .` descarta o ruído .import antes de merge (o script já faz).

## Onda 7 - Lote 3.2 montado (28-29/10/2026) - SEM prévia/build ainda
- Ordem (todas VERDE -Repeat 1 por passo; final -Repeat 2 VERDE em bc4b171): arte-gpt de546f8+50f807a -> 54e84ce;
  mapa7 8e8afc3 -> def1728 (conflito só em scripts/i18n/en_table.gd, gerado pelo build.py: agora o integrar.ps1 trata);
  encenacao5 0561f28+9e1d21a -> b247e07; ui7 12c6643 -> 7ab9a71; perigos7 04afd65 -> 1faa330;
  chefes6 8d00636 -> 1586c99; polimento7 2854fc0 -> bc4b171 (conflito de código em scripts/fx/projectile.gd: as duas
  versões faziam a mesma coisa - proj_fire só no tiro da Sophia - e só o comentário diferia; ficou o do HEAD/VFX7).
  Push: origin/integracao/onda1 = bc4b171. Não integrar mapa7 4e4b9cc nem chefes6 42d4804 sem ordem.
- Sondas em bc4b171 (logs UTF-16 em `_caps/integ/`): ReiProbe (`rei_bc4b171.txt`): BodyBox cobre 96-98 % do desenho,
  "atravessa"=0, "apelão"=0, golpes a ≤70 px acertam. BossProbe: todas [ok], sem TIMEOUT; Rei 74 s, Athoth 165, Harmas 125,
  Galila 148 (4 quase-mortes), Yabel 95, Astaphaios 104, Belias 106, Armupiel 92, Rei+Colosso 38 s (era 186 s na 3.1:
  provável efeito da BodyBox maior, conferir se não ficou curta demais). BossHurtProbe (`hurtprobe_bc4b171.log`,
  `hurt_bc4b171/`): Arcontes/Colosso cobre 50-89 %, vazio <=29 %; Rei/Rei-final só 32-46 % - a sonda mede a Hurtbox
  genérica e o Rei usa a BodyBox (pulada no _fit_hurtbox, como o POLIMENTO7.md manda), então vale o ReiProbe.
- SOM DOBRADO NO CAMPEÃO (aberto, quem corrige: Encenação5/Áudio7): ao nascer o Campeão toca `champion_enter`
  (enemy.gd _boss_intro_fx, Áudio7 R9) e ~0,6-2 s depois o card do Campeão (level.gd _champion_card_when_visible ->
  Cinematic.boss_card -> scripts/fx/cinematic.gd `_run_boss`) toca `boss_appear` de novo (e solta a música de chefe).
  Correção sugerida: `boss_card(..., silencioso)` para o card do Campeão não tocar `boss_appear` (o stinger do Campeão é
  o champion_enter; a música de chefe precisa de outro gatilho se for o caso).

## Onda 7 - Lote 3.2 parte 2 (29/10/2026) - SEM prévia/build ainda
- VERDE -Repeat 1 por passo e -Repeat 2 no fim: mapa7 4e4b9cc -> 0e41397; progressao6 3d13bbd -> 3c88daa;
  chefes6 82454b2 -> 6c4a528; polimento7 28d8df7 -> 3203a9a; cenario7 1b1c69f -> 9cda737. Push: origin/integracao/onda1 = 9cda737.
- Sondas em 9cda737 (`_caps/integ/*_9cda737*`): ReiProbe atravessa=0, apelao=0 (BodyBox cobre 96 %); BossHurtProbe Arcontes 70-91 %,
  Rei/Rei-final 32-46 % (hurtbox genérica; vale a BodyBox); BossProbe todas [ok], sem TIMEOUT: Rei+Colosso 94 s (38 s em ba91602, 186 s
  na 3.1), Corrente 179 s (4 quase-mortes), Silêncio 183 s (3), Coroa 121 s, final 4 quase-mortes: cenário mais duro que em ba91602.
- Áudio do Campeão (BalanceBot tela 15, GNOSIS_AUDIO_LOG, `audio_t15_9cda737.json`): champion_enter=1, champion_fury=1,
  boss_appear AUSENTE: o som dobrado foi corrigido (polimento7 222dc38, sting=false no card).

## Onda 7 - Lote 3.2 parte 3 (29/10/2026) - SEM prévia/build ainda
- VERDE (-Repeat 1 por passo, -Repeat 2 no fim): chefes6 61645f7 -> c396629; progressao6 54141ed -> e6235c4;
  arte-gpt 118cb99 (fio de contorno da Sophia) -> 59ecfc9. Push: origin/integracao/onda1 = 59ecfc9 (+ commit do bilhete).
- Sondas em e6235c4 (`_caps/integ/*_e6235c4*`): ProgQA todos QA PASS; BossProbe todas [ok], sem TIMEOUT: Rei 74 s, Athoth 97,
  Harmas 83, Galila 179 (4 quase-mortes), Yabel 183 (3), Astaphaios 79, Belias 98 (3), Armupiel 125 (3), Rei+Colosso 120 s (4).

## Prévia 3.2 FEITA (29/10/2026)
- Última peça: chefes6 213d292 -> 944ec41 (VERDE -Repeat 2, push). Docs BIBLIA §6/ROADMAP em c75c41f (commit separado).
- `preview/3.2` = c75c41f + cherry-pick do save GNOSIS-Previa (c950dd8), push -f feito. Build: `C:\gnosis-wt\_build\preview3_2\GNOSIS.exe`
  (+ .pck, LEIA-ME.txt), SEM atalho, jogo não aberto (só abertura headless: "2 resources still in use at exit").
- BossProbe 944ec41: Rei 74 s, Athoth 97, Harmas 83, Galila 123, Yabel 158, Astaphaios 91, Belias 149, Coroa 192 (4 quase-mortes),
  Rei+Colosso 140 (6 quase-mortes); sem TIMEOUT. ReiProbe atravessa=0, apelão=0.

## Próximo
- Prévia 3.1: chefes6 aprovado → integrar → BossProbe → auditoria do Guardião → `preview/3.1` + `_build\preview3_1` (sem atalho).
- Prévia 4: quando chefes6 + narrativa fecharem de vez.
