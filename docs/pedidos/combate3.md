# Pedidos do COMBATE (Onda 3, branch `dir3/combate3`) para outros donos

Nada aqui é bloqueante: o combate funciona sem eles.

## Arte (`scripts/fx/character_art.gd`)
1. **Getter público do corpo desenhado.** O flash aditivo da Sophia (`Player.FlashLayer`, F1) lê
   `visual._body_mesh`, `visual._body_xform` e `visual._body_tex` (os mesmos que o `spawn_afterimage`
   usa). Funciona, mas são nomes "privados": se mudarem, o flash some sem erro. Pedido: um
   `func body_draw_data() -> Dictionary` (`{mesh, xform, tex}`) ou manter esses três nomes estáveis.
2. **Código morto:** `_tick_action()` ainda "adivinha" o aparo por `modulate.b > 3.5` com o estado
   `block`. O `player.gd` agora chama `visual.play_action("parry")` direto e o flash claro não mexe
   mais no `modulate` → essa detecção nunca dispara. Pode sair.
3. **Telegrafo:** o `Enemy` agora escreve `visual.telegraph_color` direto nos chefes por quadros
   (Pedido 2 atendido) e zera o alfa no golpe. A conversão "modulate == _TELEGRAPH_TINTS → contorno"
   em `_tick_boss` ficou sem uso (o modulate do Enemy é 45 % de tingimento, nunca igual à cor cheia).
4. **Gibs depois da pose de morte:** o chefe agora segura `dead` 0,4 s antes de `gib_parts()`. Os
   pedaços saem do quadro de morte (`_boss_shown`). A dissolução corre em tempo de JOGO: com o
   slow-mo da morte do chefe (0,15×) ela quase não anda nesses 0,4 s; sem slow-mo (morte por magia/
   sonda) chega a ~35 % e os gibs aparecem inteiros por cima. Se ficar estranho no olho do João,
   `dissolve_max` menor só no chefe ou a dissolução começar depois de 0,4 s.

## Encenação (`staging.gd` / `cinematic.gd`)
5. **C1 resolvido sem mexer nos seus arquivos:** o número de dano some sozinho quando a árvore pausa
   (a caixa de diálogo pausa pela PauseStack). Se alguma cena rodar SEM pausar o mundo, chame
   `DamageNumber.clear_all()` no começo dela.
6. Chefe que morre por desmembramento fica 0,4 s REAIS na pose de morte (ignora pausa) antes de se
   partir; se a cena já estiver com o mundo pausado nessa hora, o corpo só some (sem gibs). Na tela 1
   (`rei_queda`) e no roubo (tela 64), confira no olho se o corpo do chefe em pose de morte por 0,4 s
   sob a caixa não briga com o `fall_at()`.

## Shader (`assets/shaders/painted_flex.gdshader`, Pedido 1 da Arte, ainda pendente)
7. O flash novo não depende da correção da cor ao quadrado, mas quando ela entrar a Sophia fica mais
   clara e o flash (`Player.FLASH_ADD = 0.6`) pode precisar baixar para ~0,45. Avisar o Combate.

## UI / Técnico
8. "Reduzir flashes" já chega no `Juice.reduce_flashes` (GameManager). O flash da Sophia respeita
   (× 0,5) e o limite de 3 flashes cheios por segundo.
9. **Contra-ataque** novo: depois de um APARO perfeito, apertar ataque em até 0,4 s dispara um golpe
   forte (pesado ×1,5) com os quadros "riposte". Falta entrar na tela de Golpes / dicas (UI) — sugestão
   de texto: "Aparar → Ataque: Contra-ataque".
