# ENCENAÇÃO — relatório da Onda 2 (dir2/encenacao, 17/10/2026)

Continuação do agente derrubado pelo reinício das 06:05 UTC. O anterior deixou
2 commits (REVISAO #1 e PauseStack no Cinematic) e um diff solto em `level.gd`,
`final_battle.gd`, `sleeper.gd` (os ganchos do ROTEIRO §5) que chamava um
`_stage()` inexistente (não compilava). Aproveitei o diff inteiro e escrevi a
`Staging` que ele pedia.

## 1. Commits
(ver `git log --oneline integracao/onda1..dir2/encenacao`)

## 2. O que mudou
- `scripts/levels/level.gd` — desfecho único por tela (REVISAO #1, commit do
  anterior); `reset_mercy()` ao trancar zona; todas as falas encenadas abrem por
  `stage().play(falas, escolhas, "cena")`; santuário antes da loja; eco do Centro
  (legenda + música `centro` por caco + slow-mo 0,3/0,6); fala de cada final;
  posição do chefe caído (queda do Rei); `stage()` público (o `NpcEncounter` usa).
- `scripts/levels/staging.gd` (NOVO) — a encenação por `cue` (via `line_shown`):
  - **intro (M1)**: preto 1,5 s sem música, batimento, a luz volta; `rei` baixa só depois da 1ª fala da Voz.
  - **Cena A (tela 1)**: câmera trava e desliza (zoom 1→1,08→1,15), 3 bancos de névoa,
    silhueta do Rei (pintura do chefe tingida de preto, orbe pulsando 0,8 Hz) anda
    2 passos `king_step`, a cor volta em `king_emerges`, clarão na máscara em `mask_lights`.
    No fim ele vai ao lugar do duelo e segura até o card de chefe acabar.
  - **Queda do Rei**: o figurante volta onde o chefe caiu; rachadura em 3 segmentos; afunda 60 px na névoa.
  - **Cena B (64)**: música do chefe corta seco; o Rei sai da névoa do lado com espaço;
    `voice_merge` pisca a placa do nome; 2 palmas; `rings_fly`: 7 gemas, uma a cada 0,8 s,
    pelo `hud.detach_ring(i, mão do Rei)` (HUD roda pausado só nesta cena), avanço travado
    por `lock_advance` se a UI tiver; `mask_falls`: máscara cai girando 20°, olho cego,
    o Rei esfria, flash 0,08 s, `theme` a 0,75 por 3 s → corta → `roubo`; as gemas orbitam
    a cabeça; "Uma voz nos Anéis" = gemas pulsam fora de ritmo + `whisper`; "mais baixo" = −14 dB
    e câmera aproxima; `sink`: manto colapsa, 3 anéis em volta de um núcleo negro, chão racha,
    afunda 120 px, preto em 0,8 s.
  - **Cena C (65)**: `descend()` antes da caixa — preto 1 s, câmera desce (120 px), tinta
    dourada → violeta, a Sophia "cai de joelhos" (squash + `land`), sem música.
  - **Cena D (68)**: os 7 Anéis param (FinalBattle.release_rings) e descem em espiral até o
    peito dela, 0,35 s cada (`hud.restore_ring(i)` se existir); clarão + aura; o Colosso
    encolhe a 0,25 (alpha 0,4), o Rei vira névoa e entra nele; "alguém pequeno" (cego,
    respirando) aparece ao pé dela; `theme` volta sozinha a 0,85; `reclaim`: ele vira luz e entra na mão dela.
  - **santuário**: `theme` baixo durante a conversa; `music_stop` (Coroa) = silêncio 1 s antes da loja.
  - **tentação (M2)**: "(Como ele sabe da janela?)" derruba a música −10 dB. **Soter (M3)**: música a −14 dB.
  - Avançar antes do fim de um efeito salta o efeito para o estado final (nada fica pela metade).
- `scripts/levels/final_battle.gd` — comentário 54→68; toast "juntas"; 1ª queda: slow-mo 0,2/1,2,
  legendas `seventh_ring()` e o Anel da Coroa voando da órbita para a Sophia (M9); `release_rings()`.
- `scripts/entities/sleeper.gd` — legenda do Adormecido ao acordar.
- `scripts/entities/npc_encounter.gd` — Soter abre pela Staging (cena "soter").
- `tools/encenacao/CenaShot.tscn` + `cena_shot.gd` (NOVO) — filma uma cena avançando as falas.
- `docs/pedidos/onda2_encenacao.md` — pedidos.
