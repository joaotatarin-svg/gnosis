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

## Prévia 3 — FEITA
`preview/3` = ec64161 + cherry-pick e065c85 (save GNOSIS-Previa) → 65b2860 (push feito).
Build: `C:\gnosis-wt\_build\preview3\GNOSIS.exe` (+ .pck, LEIA-ME.txt). Atalho Desktop "GNOSIS - prévia 3.lnk".
Exportado do worktree `C:\gnosis-wt\preview` (preset "Windows Desktop", `--export-release`). Abertura headless sem erro.

## Problema conhecido (devolvido ao chefes6 pelo chefe)
BossProbe (telas=all vel=3) em ec64161: lutas ~2× mais longas que o r4 do CHEFES6.md; TIMEOUT 420 s no
Armupiel (64) e na batalha final (68). 91× "Function blocked during in/out signal (set_deferred monitoring)".
Log: `C:\gnosis-wt\_caps\integ\bossprobe_ec64161.log`.

## Falta
- Prévia 3.1: quando chefes6 recalibrar → integrar, BossProbe, gerar `preview/3.1` (mesma receita, pasta `_build\preview3_1`).
- dir7/vfx7 (WIP), dir7/dublagem (WIP, só scripts/docs), dir2/arte-gpt (blocos seguintes da Fila 9).
- Prévia 4: quando chefes6 + narrativa fecharem de vez (+ vfx7 se pronto).
