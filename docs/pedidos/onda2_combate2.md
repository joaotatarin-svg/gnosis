# Pedidos do Combate2 (Onda 2b, 17/10/2026)

Tudo do lado do Combate2 já está no branch `dir2/combate2` e funciona sem estes pedidos
(chamadas protegidas). Detalhe em `docs/onda2/COMBATE2.md`.

## Técnico2 / UI-Menus2 (`game_manager.gd` SETTINGS_DEFAULT, tela de Opções)
1. **Números de dano**: chave `settings["damage_numbers"]` (bool, padrão `true`) no
   `SETTINGS_DEFAULT` e um liga/desliga nas Opções. O `DamageNumber.spawn` já lê
   (`GameManager.settings.get("damage_numbers", true)`; valor ausente ou de tipo errado = ligado).
2. (Opcional) Se preferirem a escala dos chefes no Bestiary, troquem o `BOSS_PRESENCE`
   do `enemy.gd` (Belias ×1,15, Athoth ×1,08) por `height` maior no perfil — e apaguem a tabela.

## Áudio2 (`audio_manager.gd` CATALOG)
1. `tell_parry` / `tell_unblock`: o `enemy._tell_glint()` já chama `Audio.play_sfx_at(nome, pos)`
   assim que o nome estiver em `CATALOG["sfx"]` (sem o nome, segue mudo e o AudioQA não reprova).
2. Correntes da travessia da Corrente (tela 25): hoje usam `rooted` (aviso) e `swing_heavy`
   (varredura). Um `chain_rattle` (chocalho de ferro, 0,6 s) e um `chain_swing` (zunido grave)
   ficariam melhores; se criarem, me avisem o nome (ou troquem em `scripts/combat/eon_rule.gd`).
3. Névoa do Torpor (tela 7): sugestão de abafar a música/ambiência enquanto a regra vale
   (o nó é `EonRule` com `kind == "torpor"`, filho da fase).

## Encenação2 (`level.gd`, `narrative.gd`)
1. As telas de regra (7 e 25) anunciam a regra com um `toast` do HUD (texto de sistema).
   Uma fala da Voz na chegada dessas telas ajudaria (ex.: Torpor: "Aqui a névoa fecha os olhos
   de quem anda. Escuta os passos."; Corrente: "As correntes não escolhem quem prendem.").
2. Se algum dia a fase trocar de tela SEM trocar de cena, chame `Gib.clear_all()` na troca
   (hoje não precisa: os destroços são filhos da fase e morrem com ela).

## Balance
1. **Achado:** o tiro de corrente da Galila e do Carcereiro (`Projectile.root_time`) NUNCA prendia
   a Sophia: o dano ligava os i-frames (0,6 s) antes, e o `apply_root` recusava. Consertado
   (status antes do dano). A tela 28 (Galila) e as telas com Carcereiro ficam um pouco mais
   difíceis — ver os números do bot em `docs/onda2/COMBATE2.md` §4.
2. **Achado, NÃO mexido:** o tiro de sono do Sonâmbulo (`slow_time`) também não faz nada na
   Sophia — o `player.gd` não tem `apply_slow`. Ligar é uma linha (`status_slow = maxf(...)`),
   mas deixa o Torpor (o Éon da demo, já o mais difícil por minuto) mais duro. Decidam com o
   playtest; eu não liguei.
3. As regras de travessia (telas 7 e 25) mudam o dano dessas telas; o bot não "vê" a névoa
   (lê posições), então o número dele na tela 7 não mede a dificuldade real.

## Sessão local (CharacterArt / shader da pintura)
1. O contorno de leitura (R18) está num `CanvasGroup` em volta do `Visual` (uma cópia de buffer
   por inimigo). No llvmpipe custou ~5–20 % de tempo de quadro com 12 inimigos; numa GPU de
   verdade deve ser pequeno, mas se pesar, o mesmo contorno cabe no shader da pintura
   (amostra o alfa em 8 vizinhos, cor do Éon, α 0,5) e o CanvasGroup sai (`RIM_ENABLED = false`).
2. `CharacterArt` monta a pose só no `_process`: contornei no `Enemy._ready` (chama
   `visual._process(0.0)` uma vez). Se quiserem, um `_compute_pose()`/`queue_redraw()` no
   `set_profile` resolve na fonte e eu tiro o contorno.
