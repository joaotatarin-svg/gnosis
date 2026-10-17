# Pedidos do diretor anim-sophia

1. **Áudio** (`dir/audio`): catálogo precisa de `step_heavy` e `cloth` (o branch de áudio já tem). O passo da Sophia agora sai do CharacterArt no quadro de apoio; o timer de passo do `player.gd` foi removido (evita passo duplo).
2. **Técnico** (`project.godot`): considerar `rendering/textures/canvas_textures/default_texture_filter=3` (linear com mipmaps) — props, baús e gibs desenham as folhas derivadas (já com mipmaps) mas o filtro do nó deles é linear sem mipmap; o CharacterArt já força o seu.
3. **Animação-Chefes**: as folhas derivadas (`assets/painted/derived/archons.png`, `yaldabaoth.png`) têm as MESMAS coordenadas; `PaintedLibrary.sheet()` e `material()` já as entregam ao BossPuppet. O BossPuppet herda o filtro com mipmaps por ser filho do CharacterArt. Nada a mudar do lado de vocês.
4. **Produção GPT** (regeneração opcional): `s9_a.die_0` troca o cajado de lado em relação a `s8.hurt_0`; um quadro de transição de pé→joelho para a morte seria bem-vindo. Corrida: um par de quadros de cruzamento de pernas (entre run_3/run_4 e run_7/run_0) eliminaria o borrão dos meios do RIFE.
