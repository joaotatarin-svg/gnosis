# ENCENAÇÃO — relatório da Onda 2 (dir2/encenacao, 17/10/2026)

Continuação do agente derrubado pelo reinício das 06:05 UTC. O anterior deixou
2 commits (REVISAO #1 e PauseStack no Cinematic) e um diff solto em `level.gd`,
`final_battle.gd`, `sleeper.gd` (os ganchos do ROTEIRO §5) que chamava um
`_stage()` inexistente (não compilava). Aproveitei o diff inteiro e escrevi a
`Staging` que ele pedia.

## 1. Commits (dir2/encenacao, sobre integracao/onda1; merge da base em 483b6f0 autorizado pelo chefe)
3954b34 desfecho único (REVISAO #1) · e58a1a4 Cinematic/PauseStack · c0a8e55 ganchos §5 + Staging ·
3d94dd4 M2/M3 + CenaShot · 2df815a Rei de cena · 7d16895 M9 + pedidos · d246452/636da55/bf5b59f WIP de ajuste
pelas capturas · 42ec8b0 achados do revisor (zoom relativo, música é do Áudio) · e1bfb10 · 0d671f0 ·
ca6dcdf Áudio dono único do som · bf35023 recuo 0,9.

## 2. O que mudou
- `scripts/levels/level.gd` — desfecho único por tela (REVISAO #1, commit do
  anterior); `reset_mercy()` ao trancar zona; todas as falas encenadas abrem por
  `stage().play(falas, escolhas, "cena")`; santuário antes da loja; eco do Centro
  (legenda + slow-mo 0,3/0,6; a música `centro` por caco é do Áudio); fala de cada final;
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
  - **santuário**: `Audio.voice_theme("santuario")` e `voice_theme("")` no fim; `music_stop` (Coroa) = 1 s de silêncio antes da loja.
  - **tentação (M2)**: "(Como ele sabe da janela?)" derruba a música −10 dB. **Soter (M3)**: música a −14 dB.
  - **Som**: dono único = Áudio. Cada cue vai a `Audio.cue()`; gemas por `ring_note`/HUD; palmas `clap`.
    Ficam na Staging só: corte seco do "Sete.", sussurro dos Anéis, passos do Rei, `duck_music` de Soter/tentação.
  - Câmera: zoom RELATIVO ao zoom de jogo salvo (a câmera nova do Combate usa 1,2); deslocamentos pelo
    `base_offset` (entra no alvo da câmera — com a câmera nova o lateral fica limitado pela margem segura).
  - Avançar antes do fim de um efeito salta o efeito para o estado final (nada fica pela metade).
- `scripts/levels/final_battle.gd` — comentário 54→68; toast "juntas"; 1ª queda: slow-mo 0,2/1,2,
  legendas `seventh_ring()` e o Anel da Coroa voando da órbita para a Sophia (M9); `release_rings()`.
- `scripts/entities/sleeper.gd` — legenda do Adormecido ao acordar.
- `scripts/entities/npc_encounter.gd` — Soter abre pela Staging (cena "soter").
- `tools/encenacao/CenaShot.tscn` + `cena_shot.gd` (NOVO) — filma uma cena avançando as falas.
- `docs/pedidos/onda2_encenacao.md` — pedidos.

## 3. Capturas (`/home/user/caps/encenacao/`, 640×360, CenaShot avançando as falas)
- ANTES: `antes_t1_dialog.png` (só a caixa sobre o cenário, sem Rei nem névoa).
- Tela 1: `cmp_t1_a.png` (silhueta na névoa → o Rei acende), `cmp_t1_final.png` (card do duelo com o Rei de
  cena segurando o lugar; rachadura e afundar), quadros `t1_*.png`.
- Tela 64 (roubo): `cmp_t64_c.png` (gemas no HUD viram ◇ cinza e chegam à mão dele; máscara cai e o olho cego
  fica no lugar do elmo; "Uma voz nos Anéis"; o motor de 3 anéis afundando), quadros `t64_*.png`.
- Tela 65 (descida): `cmp_t65_a.png`, `cmp_t65_b.png` (preto → câmera desce → caixa "(Silêncio...)").
- Tela 68 (anagnórise): `cmp_t68_c.png`, `cmp_t68_d.png`, `cmp_t68_e.png` (recuo com as formas, gemas voltando,
  aura, o Colosso encolhendo até o pé dela, o pequeno cego, reclaim, escolha), quadros `t68_*.png`.
- REVISAO #1: `sonda/antes_*.log` × `sonda/final_*.log` — telas 10 a/b, 1 a, 64 a/b: nenhuma volta ao
  checkpoint com o Anel (10→11, 1→2, 64→65), 0 SCRIPT ERROR.
- As capturas de 64/68 foram tiradas ANTES do merge da base e da troca do som para o Áudio (a imagem não
  mudou nessas trocas; não refilmei depois — CPU disputada).

## 4. Validação (`TIMEOUT=900 tools/validate.sh`, depois do merge da base)
```
Scripts OK · ScriptCheck OK · AudioQA OK (45) · GnoseQA OK (18) · SaveQA OK (13) · PuppetQA OK · HeroQA OK · WaveQA OK
CodexQA FALHOU (32 pass) — só "diretório de save independente" (falso conhecido do override.cfg)
```
Compilação limpa (editor headless sem SCRIPT ERROR) depois do último commit (bf35023).

## 5. O que NÃO ficou bom / não deu tempo
- A pintura do Rei não tem máscara separada: a máscara que cai e o olho cego são desenhos por cima
  (oval pálido + elipse preta). Lê, mas é "colado". O rosto foi medido na captura (HEAD = −188 px).
- `lock_advance` e `wait_2s` ainda não estão na base: sem eles, se o jogador avançar durante o voo dos
  Anéis, as gemas que faltam chegam todas de uma vez (funciona, perde o ritmo).
- A tinta dourada→violeta da descida usa CanvasModulate: o fundo pintado (camada própria) quase não muda.
- Cena D: o "pequeno" é um desenho procedural escuro (lê pouco num fundo escuro); a câmera nem sempre
  centra a Sophia (limites da arena). Não testei com a câmera nova do Combate (não está na base).
- M4 (hit_stop no espelho) e gancho #2 (fase 2 dos Arcontes) são do `enemy.gd` — fora dos meus arquivos.
- Não joguei de verdade: tudo visto por captura; feel/tempo das cenas precisa do João.

## 6. Pedidos
`docs/pedidos/onda2_encenacao.md` (UI: lock_advance, wait_2s, restore_ring; Áudio: Centro sem música até o
1º caco; Combate/arte: chefe invisível durante o card de chefe).
