# Pedidos do diretor de LEVEL (Onda 6) — dir6/level6

Detalhes em `docs/onda2/LEVEL6.md`.

## → combate6 (Sophia)
1. **Pulo duplo**: as saliências de segredo ficam **116 px acima do chão** (pulo simples sobe
   ~77 px com `jump_velocity` -430 / gravidade 1200). O 2º pulo precisa somar **≥ 45 px** (ideal:
   o mesmo impulso do 1º → ~150 px no total). Se o 2º pulo for mais fraco, me avise: a altura
   está em `ScreenLayouts.YDJ` (e a sala secreta em `Y3`, 60 px acima da saliência).
2. Contrato que os perigos usam (não mude sem avisar): `player.hurtbox.receive_hit(dmg, pos, kb,
   unblockable, atacante)` com o PERIGO como atacante (sem `stagger()` — esquiva perfeita vale),
   `player.apply_root(t)`, `player.status_slow` (névoa), `player.mana` + `mana_changed`
   (campo de silêncio/badalo), `player.invuln_timer`, `Player.State.DODGE`.

## → inimigos6
1. **Voadores**: o Level põe no ALTO da arena (y = 150) todo inimigo que responder
   `is_flyer()` (método) **ou** tiver `is_flyer`/`flying`/`flies` = true **ou**
   `Bestiary.is_flyer(type_id)`. Escolha UM e me diga; hoje nenhum responde e todos nascem no chão.
2. Os perigos ferem inimigos via `apply_damage`, `apply_root`, `apply_slow` (não-chefes). Se mudar
   essas assinaturas, o cenário quebra.

## → estab5 (QA)
1. Incluir `res://tools/level6/LayoutQA.tscn` no `tools/validate.ps1` (headless, ~1 min, sai 0/1):
   monta os 129 nós do mapa e confere alcance (pulo simples/duplo), spawns e conteúdo reservado.
2. BalanceBot: dano de cenário aparece como "projetil" (o atacante é um `LevelHazard`, não um
   Enemy). Sugestão: rotular `cenario:<hazard_kind>` quando `attacker is LevelHazard`.
3. O bot não pula nem desvia de perigo de cenário: nos nós `hazard` ele toma +40–80 de dano que um
   humano evita (ver LEVEL6.md §5). Não é bug; é o limite do bot.

## → narrativa6
1. A Estela continua em `Gnosis._stela_pos` (descanso − 200). Os perigos/torres desviam dela por
   `Level.reserved_spans()`, que COPIA essa conta — se mudarem a posição da Estela, me avisem.
2. Em telas com a passagem 0 aberta (perigo, escalada, segredo, antessala) a Sophia nasce em
   x = −600 e o Adormecido fica ATRÁS dela (x = −670): continua opcional, como antes.
3. Sugestão: na cena do Soter (pulo duplo), uma fala sobre "as setas apagadas no chão" — a marca
   embaixo das saliências de pulo duplo (`SecretMark`) fica apagada antes e acende dourada depois.
4. Os avisos de objetivo ("Um totem chama reforços…", "Proteja a luz do Adormecido…") são toasts
   no início da zona; se a legenda de zona cair junto, me digam para atrasar.

## → progressao6
Recompensas novas (calibrem se a economia apertar): baú secreto = 2× faíscas do baú + cura 20 %;
totem quebrado = 12 + tela; luz protegida = 10 + 1,5 × tela + cura 15 %; casulo de esporos = 4;
altar do santuário = cura 25 % (uma vez). Sala secreta = 2 baús secretos (além da recompensa do nó).

## → ui5
1. Objetivo da zona: `Level.zone_objective(i)` devolve "ondas" | "totem" | "proteger". Um ícone
   no HUD durante a zona ajudaria (hoje é só o toast).
2. A barra de luz do objetivo "proteger" é desenhada no mundo (acima da lamparina).

## → arte
Todos os perigos são desenhados por código (contorno escuro + cor do Éon). Ganhariam muito com
pintura: guilhotina e trilhos (Coroa), totem, altar, porta selada da sala secreta, casulo de
esporos, sino do Silêncio. Recorte novo em `PaintedLibrary` → eu troco o `_draw`.
