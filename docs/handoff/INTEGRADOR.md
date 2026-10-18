# BILHETE DO INTEGRADOR-CHEFE (Onda 6) — atualizado a cada integração

Worktree `C:\gnosis-wt\integ` (branch local `integracao/onda1`; `override.cfg` nunca vai pro git).
Ritual: checkout/clean → merge --no-ff → (i18n gerado: --ours + extract + build --strict) → reimporte 2× →
`tools/validate.ps1 -Repeat 2` TUDO VERDE → push `origin HEAD:integracao/onda1`.

## Integrado (18/10/2026)
| Branch | Commit de merge | Validação |
|---|---|---|
| (base) Ondas 1–5, i18n, arte, mapa6, loja v3, progressao6 | d3be8db | verde 2/2 |
| dir2/arte-gpt (morte de chefe com peso, head_point) | ce2e35e | verde 2/2 |
| dir6/level6 (layouts por node_kind, perigos, segredos, contrato do cenário) | f9bd7c5 | verde 2/2 |

## Falta
- dir5/encenacao5 (narrativa 6 — FECHADO, próximo), dir6/chefes6 (FECHADO, depois da narrativa).
- dir6/combate6 (relatório ainda não cobre o playtest 2 — aguardando fechar), dir6/inimigos6 (sem relatório ainda).
- dir2/arte-gpt: commits novos (frame_geometry, bilhete) — reintegrar quando fechar.
- dir7/vfx7 (WIP), dir7/dublagem (sem branch).

## Prévia 3
Não gerada. Gatilho: combate6 + inimigos6 + level6 + arte-gpt integrados e verdes.
Receita: branch `preview/3` da integração + cherry-pick de e065c85 (save GNOSIS-Previa) → export →
`C:\gnosis-wt\_build\preview3\GNOSIS.exe` → teste headless → atalho Desktop "GNOSIS - prévia 3.lnk" + LEIA-ME.txt.
