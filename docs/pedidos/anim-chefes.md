# Pedidos do diretor Animação-Chefes (17/10/2026)

Nada aqui bloqueia a entrega; o boneco funciona com o que existe hoje.

## Para Animação-Sophia (dono de `scripts/entities/enemy.gd` e `character_art.gd`)

1. **Instante do impacto**: hoje o golpe usa o progresso de `STRIKE`. Se o
   Enemy expuser quando o dano realmente sai (ex.: `visual.impact_at` 0..1 ou
   um sinal), o estalo do boneco cai exatamente no acerto.
2. **Intensidade do dano**: em `HURT/STAGGER`, um `visual.hurt_power` (0..1,
   ex.: dano/vida máx. ou knockback) deixaria o tranco proporcional ao golpe.
3. **CodexQA "troca de perfil libera o boneco anterior"**: o teste exige
   `art.get_child_count() == 1` com chefe. No meu worktree passa (0 falhas);
   se o seu `character_art.gd` adicionar outro filho ao CharacterArt, o teste
   precisa contar só o `BossPuppet` (o boneco é liberado em `set_profile`).

## Para quem fizer os quadros pintados dos chefes (fila do ChatGPT)

- Use `assets/painted/derived/puppets/<nome>_body.png` como referência de
  tamanho e enquadramento: a mesma área, a arma FORA do corpo, os pés na
  mesma linha. Entregue por estado (idle, preparação, golpe, dano) e ligue com
  `BossPuppet.set_state_texture(estado, textura)`.
- A arma continua peça separada (`<nome>_parts.png`).
