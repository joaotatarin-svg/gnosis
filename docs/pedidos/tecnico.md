# Pedidos do Diretor Técnico a outras áreas (Onda 1)

Detalhes e evidências em `docs/QA_BASELINE.md`.

## Animação-Sophia
1. Golpes L / LL / LLL usam a MESMA pose (quadro 4 da folha) — cada golpe precisa de
   pose própria + quadros de entrada/saída; ATTACK→IDLE estala sem intermediário.
   Prova: `C:\gnosis-wt\_caps\tecnico\baseline\seq_sophia_combo_sheet.png`.
2. Andar = 2 quadros a 9 qps (`character_art.gd:1297`).
3. Folhas com fundo MAGENTA recortado por shader: gerar PNG com ALFA real
   (rembg isnet-anime) para poder ligar mipmaps (`mipmaps/generate=true`) sem halo rosa
   — prova em `baseline\mipmaps_comparacao.png`. Depois disso eu troco o filtro padrão
   do projeto para linear_mipmap.
4. Use `tools/Shot.tscn ... seq=150 every=2 act=demo solo` + `tools/seq_to_media.py
   --follow player` para mostrar ANTES/DEPOIS em movimento.

## Animação-Chefes
1. WINDUP pinta o chefe inteiro de amarelo sólido por ~0,7 s (Galila, tela 28) — lê como
   bug. Sugiro brilho de borda/pulso, não tinta chapada. Prova: `baseline\seq_chefe28_sheet.png`.
2. Mesma pose em CHASE/WINDUP/STRIKE — o golpe é só VFX.

## Cenário/VFX
1. Fundo = recorte 512×341 esticado 2,5× → mole. (já no ROADMAP)
2. Pré-aquecer VFX/gibs/materiais no load da fase: picos de até 193 ms no 1º golpe
   (tela 50, `tools/PerfProbe.tscn -- tela=50 n=12`).
3. Plataformas flutuantes sem sombra de contato; telas 3 e 8 com fundo idêntico.

## UI
1. "Faíscas: 0 / Arma Nv. 1" em texto cru; terço inferior da tela é faixa escura + legenda.

## Dono da câmera (`scripts/fx/camera_shake.gd`, Sophia/jogabilidade)
1. A Sophia sai do quadro por ~16 quadros ao virar + esquivar na arena trancada
   (look-ahead 90 px girando a 180 px/s + smoothing + limite). Sugestão: look-ahead
   mais rápido ao virar e/ou `drag` horizontal, e clamp que garanta a Sophia visível.

## Todos (física)
- Física 60 Hz num monitor 144 Hz sem interpolação → judder. Proposta pra Onda 2:
  `physics/common/physics_interpolation=true` + `reset_physics_interpolation()` em
  todo teleporte. Eu mexo no `project.godot`; quem tem teleporte no seu código precisa
  chamar o reset.
