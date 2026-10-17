# CENÁRIO — Onda 2 (nuvem, 17/10/2026)

Continuação do agente derrubado às 06:05. Ele tinha deixado `tools/scenery/caps.sh`
(versão Linux), `seams.py` e `sheet.py` sem commit: revisei, validei e commitei (0c739d6).

## 1. Commits (branch dir2/cenario)
- 0c739d6 WIP: caps.sh para Linux/xvfb, detector de emendas (seams.py) e prancha (sheet.py)
- 8460f3e M5: cada camada pintada vira UM quad com repetição em espelho; o fallback também espelha
- 4287262 P2: véu de luz nas paredes da zona trancada + pilar e escuro nas paredes fixas; CleanShot x=/zone=/face=
- 7723f2e P2: faixa de baixo com vida (manchas de luz + brilho nas rachaduras); pedido da câmera
- b0ceb7d VFX falta 3: arena de chefe acende quando a zona tranca; obeliscos/braseiros na borda da arena
- f2e1ddd VFX falta 2: limpeza da faixa near (near_cleanup.py) + pipeline chama a limpeza
- 22df901 VFX falta 4: poeira longe (paralaxe 0,15) e perto (rente ao chão); bench.sh no Linux
- c6c89d0 VFX falta 6: README dos fundos
- 0296357 chão só faz as 4 amostras extras onde a onda de brilho passa; VFX.md atualizado
- f011763 brilho das rachaduras por Éon (Espelho 0,4, Coroa 0,7)

## 2. O que mudou
- `scripts/levels/scenery.gd`: `_mirror_strip` (M5); `ArenaBounds` + `VeilStrip` + `_build_end_walls`
  + `_hquad` (P2); `ArenaSet` (arena de chefe); `_far_motes` e poeira perto no `Foreground`;
  `crack_amt` por Éon.
- `scripts/fx/scenery_library.gd`: chave opcional `crack` no LOOK.
- `assets/shaders/scenery_floor.gdshader` (vida na faixa de baixo), `scenery_veil.gdshader` (novo).
- `assets/backgrounds/eon_*_near.png` (limpos), `assets/backgrounds/README.txt`.
- `tools/scenery/`: `near_cleanup.py` (novo), `build_backgrounds.py` (chama a limpeza),
  `clean_shot.gd` (nó que sobrevive à troca de cena; `x=`, `zone=`, `face=`; `CLEAN_DEBUG=1`),
  `caps.sh`, `bench.sh` (Linux), `seams.py`, `sheet.py`.
- `docs/VFX.md` (estado), `docs/pedidos/onda2_cenario.md` (pedido ao Combate).

**M5 — causa:** o QA-UX testou a v2 do cenário, que desenhava o chão em ladrilhos de 512 px
recortados da pintura SEM espelhar e repetia o fundo a cada 768 px sem espelhar — a borda
esquerda da pintura colava na direita = linha vertical dura no chão e no fundo. A v3 (Onda 1)
já trocou isso por ladrilho+ladrilho invertido; agora cada camada é um quad só (não existe
junção na tela, nem fresta de posição fracionária) e o fallback também espelha.

**P2 — achado extra:** a antecipação da câmera (`offset` ±90 px em `camera_shake.gd`) ignora
os limites da câmera; virada para a parede, a tela mostra até 90 px de chão ALÉM da parede
(medido: Sophia em x=-690 → borda da tela em -810, parede em -720). É a "parede invisível".
O cenário agora escurece 160 px além de cada parede fixa e põe um pilar no plano da luta;
o conserto de verdade é na câmera (pedido ao Combate).

## 3. Capturas (em /home/user/caps/cenario/)
- Por Éon, antes × depois: `pares_a.png` (telas 1, 3, 12, 22, 30) e `pares_b.png` (40, 50, 60, 65, 68);
  avulsas `antes_<t>.png` / `depois_<t>.png`. A câmera não cai no mesmo ponto em cada execução
  (o jogo roda a 5–18 qps no software), então o enquadramento varia entre antes e depois.
- M5: `v2/m5_{3,50,65}.png`; `seams.py` acusa 0 emendas no chão em todas as capturas novas;
  o detector pega uma linha 25% mais escura de 1–2 px (teste sintético).
- P2 parede fixa: `v2/antes_pwall.png` × `v2/depois_pwall.png` (pilar + escuro além da parede).
- P2 zona trancada: `v2/depois_pzone.png` (Torpor) e `v2/depois_pzone50.png` (Praga) — véu fino com runas.
- P2 faixa de baixo: `v2/fl_3.png` (rachaduras com brilho onde a onda passa), `depois_40.png` (Espelho, mais fraco).
- Arena de chefe: `v2/antes_boss10_f15/f150.png` × `v2/depois_boss10_f15/f150/mid.png`.
- Near limpa: `v2/near_pairs.png` (telas 30, 65, 22).

## 4. Validação (tools/validate.sh, última rodada)
```
Scripts        OK         7s  pass=0  code=0
ScriptCheck    OK         4s  pass=0  code=0
CodexQA        FALHOU    18s  pass=32  code=1   | QA FAIL: diretório de save independente (conhecido, override.cfg)
AudioQA        FALHOU     5s  pass=23  code=1   | QA FAIL: duck() (conhecido, Áudio)
GnoseQA        OK        18s  pass=18  code=0
SaveQA         OK         1s  pass=13  code=0
PuppetQA       OK         2s  pass=0  code=0
HeroQA         OK         2s  pass=0  code=0
WaveQA         OK         2s  pass=0  code=0
```
Igual à base (as mesmas 2 falhas conhecidas). 0 SCRIPT ERROR.

**Desempenho:** `bench.sh` A/B intercalado (base = integracao/onda1 numa cópia, novo = este branch),
OpenGL por SOFTWARE e máquina dividida com outros agentes (carga 5–16 em 4 núcleos):
1ª rodada o novo saiu 4–37% mais lento (o chão fazia 4 amostras extras em toda a faixa de baixo);
depois de restringir essas amostras à onda de brilho: tela 68 82,4→77,4 e 77,8→75,8 ms;
tela 3 52,6→54,9 e 64,3→61,6 ms; a 3ª rodada pegou um pico de carga (ambos 87–119 ms) e não vale.
Leitura honesta: dentro do ruído no software; **custo em GPU real NÃO medido**.

## 5. O que NÃO ficou bom / não deu tempo
- Véu da zona é discreto (fio fino + runas). Lê bem parado; não vi em movimento nem com combate
  cheio. Se o João achar fraco: subir `core`/`glow` em `scenery_veil.gdshader`.
- O pilar da parede fixa é a mesma pintura dos pilares do fundo — funciona, mas não é uma peça
  própria de "fim de sala".
- As manchas de luz e o brilho nas rachaduras só aparecem bem em movimento (onda que viaja);
  na foto parada parecem fracos. Sem playtest humano.
- Near: sobra um pedacinho escuro solto no Torpor; Fome/Espelho/Coroa não passaram pela regra
  da névoa (de propósito: lá o claro é entulho de verdade).
- R18 (contraste 3:1 personagem × fundo) não medido nesta passada.
- Silhuetas pretas de entulho no primeiro plano (fg_rubble) ainda parecem borrões de tinta; não mexi.

## 6. Pedidos
- **Combate** (`camera_shake.gd`): limitar a antecipação ao espaço até o limite da câmera
  (detalhe e sugestão em `docs/pedidos/onda2_cenario.md`).
