FUNDOS DOS ÉONS — camadas de paralaxe geradas + opção de PNG único

1) O QUE O JOGO USA HOJE (Cenário v3)
Por Éon (0 Torpor, 1 Fome, 2 Corrente, 3 Silêncio, 4 Espelho, 5 Praga, 6 Coroa,
7 Centro, 8 Mente) existem 5 camadas, todas GERADAS a partir de
assets/painted/eons.png pelo pipeline:

  eon_<i>_far.png    a pintura inteira (distância; anda 3% da câmera)
  eon_<i>_mid.png    as "asas" (pilares/estantes das bordas), com alfa (14%)
  eon_<i>_near.png   a faixa de entulho logo acima do chão, com alfa (32%)
  eon_<i>_floor.png  o chão pintado (o shader faz a perspectiva e o reflexo)
  eon_<i>_fgcol.png  coluna escura de primeiro plano (nos descansos)
  fg_rubble.png / fg_pillar.png   silhuetas de primeiro plano (todos os Éons)

Quem monta: scripts/levels/scenery.gd. Catálogo/tamanhos: scripts/fx/scenery_library.gd
(o bloco "# >>> GERADO" é reescrito pelo pipeline — não editar à mão).
Cada camada é UM quad com repetição em espelho (sem emenda na tela).

Regerar (só se eons.png mudar):
  python tools/scenery/build_backgrounds.py [--no-ai] [--only 0,3]
  (a limpeza da near — tools/scenery/near_cleanup.py — roda no fim sozinha)
Conferir: tools/scenery/caps.sh <prefixo> [telas]  e  tools/scenery/bench.sh [telas]

2) PNG ÚNICO DO USUÁRIO (opcional, substitui tudo)
Se existir eon_<i>.png (nome EXATO, sem sufixo), o jogo usa SÓ essa imagem como
fundo daquele Éon e ignora as camadas (sem paralaxe em profundidade, sem chão 2.5D).
- Tela base 640x360 (16:9). Faça em 1920x1080 ou 2560x1440, mantendo 16:9.
- Para ter profundidade de verdade, prefira trocar a folha eons.png e rodar o
  pipeline: ele separa as camadas sozinho.
