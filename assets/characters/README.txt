ARTE ILUSTRADA POR PERSONAGEM (rota híbrida — chefes)
=====================================================

Se existir um PNG com o id do chefe aqui, o jogo usa a arte ilustrada no lugar
do desenho procedural. Sem o PNG, cai no procedural (fallback, sem erro).

Arquivos reconhecidos (por id do Bestiary):
  <id>.png        -> corpo do chefe (PNG TRANSPARENTE, de frente). Ex.: demiurgo.png
  <id>_orb.png    -> (opcional) orbe-olho que flutua acima e brilha no ataque.

Ids dos chefes (ver scripts/autoload/bestiary.gd):
  demiurgo            (Yaldabaoth / O Rei — Demiurgo Fase 1)
  arconte_sono, arconte_fome, arconte_corrente, arconte_silencio,
  arconte_espelho, arconte_praga, arconte_coroa

Requisitos do PNG:
  - Fundo TRANSPARENTE (alpha), figura de frente, centralizada.
  - O sprite é ancorado pelos pés (base). Altura de exibição é controlada em
    código (enemy.gd: `disp`); dá pra ajustar depois de ver no jogo.
  - O orbe (se separado) é posicionado por ORB_HOME em enemy.gd.

Fiação: scripts/entities/enemy.gd -> _apply_illustrated_art().

HEROI (decisao do usuario, 2026-09-09 tarde): a Sophia e ILUSTRADA, via RIG
CUTOUT: sophia/rig.json + sophia/parts/{cabeca,corpo,saia,cajado}.png, animado
por codigo (scripts/fx/character_art.gd -> set_rig/_draw_rig). Pra trocar a
arte da Sophia: substitua as 4 partes (mesmo recorte) ou gere um rig.json novo
com tools/slice_sophia.gd. O full.png e so referencia.
Regra: personagens principais sao ilustrados; procedural e o fallback.
