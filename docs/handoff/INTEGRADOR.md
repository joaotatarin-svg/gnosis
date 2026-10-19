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

## Próximo
- Prévia 3.1: chefes6 aprovado → integrar → BossProbe → auditoria do Guardião → `preview/3.1` + `_build\preview3_1` (sem atalho).
- Prévia 4: quando chefes6 + narrativa fecharem de vez.
