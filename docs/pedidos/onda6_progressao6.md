# Pedidos do diretor de PROGRESSÃO (Onda 6) — dir6/progressao6

Detalhes em `docs/onda2/PROGRESSAO6.md`. Todos os números moram em
`scripts/autoload/progression_manager.gd` (constantes no topo).

## → narrativa6 (cena do Soter / npc_encounter.gd)
1. **Pulo duplo:** chamar `Progression.grant_double_jump()` na cena do Soter (idempotente;
   emite `Progression.double_jump_granted`; vai no save do run). Ler com
   `Progression.has_double_jump()`. É POR RUN (run novo começa sem).
2. **Presente de arma (escolha 1 do Soter):** hoje `npc_encounter.gd:91` faz
   `Progression.weapon_level += 1` direto e PULA o selo por Arconte. Trocar por:
   ```gdscript
   if not Progression.gift_weapon_level():
       Progression.add_orbs(120)     # arma no máximo ou selada: faíscas no lugar
   ```
   (`gift_weapon_level()` sobe 1 nível de graça só se o grau permitir e já emite o sinal.)
3. Dom de vida (+25, escolha 2) pode continuar mexendo em `bonus_max_health`: os presentes
   não contam como compra da loja (contador próprio no run).

## → combate6 (player.gd)
1. Pulo duplo: `Progression.has_double_jump()` (bool) e o sinal
   `Progression.double_jump_granted()` (para ligar sem recarregar a cena).
2. Nada mais é obrigatório. As relíquias de faísca já funcionam sem tocar no player:
   `spark_orb.gd` cura (`health.heal(2)`) ou soma Éter (`player.mana` + emite
   `mana_changed`) na CHEGADA de cada faísca. Se mudarem o nome de `mana`,
   `max_mana_total` ou do sinal `mana_changed`, me avisem (ou ajustem `_relic_touch`).
3. O dano por nível de arma (+6/nível em `player.gd:399`) e por nível de magia (+12/nível,
   `player.gd:691`) continuam lá; com a arma chegando ao Nv.5 só por volta da tela 50, o
   combate pode reavaliar esses ganhos se quiser.

## → mapa6
1. Editei SÓ a tabela `EonMap.REWARDS` (motivo e números em PROGRESSAO6.md §4): vida/Éter
   grátis do mapa cortados ~25% (perigo +4 vida, escalada +4 Éter, Arena +6 vida, segredo
   +8/+8). Faíscas e cura iguais.
2. **Mudança mínima no SEU QA** (`tools/map6/map_qa.gd`, caso "recompensa do perigo"): o
   teste tinha +5 fixo; agora lê `EonMap.REWARDS["hazard"].hp`. MapQA 22 PASS.
3. `buy_max_health(n, 0)` / `buy_max_mana(n, 0)` continuam sendo o jeito certo de dar
   presente: não gastam compras da loja (o contador da loja é separado desde esta onda).

## → ui5 / estab5 (QA de menus)
1. `tools/ui_menus/menu_probe.gd` (`_shop`) tem os números antigos da loja (60/120/…/600,
   10 compras seguidas na tela 2, total 3300). Agora: vida 90×(n+1), teto 3 + Arcontes
   vencidos (10 no total). Sugestão: ler `Progression.hp_cost_for(n)` /
   `Progression.hp_buy_cap()` em vez de números fixos. (`reg_a1` continua valendo: o 1º
   item da loja na tela 2 é a arma Nv.2 por 200 e está aberta.)
2. Incluir `res://tools/progressao6/ProgQA.tscn` no `validate.ps1` (headless, ~15 s).
3. HUD/pausa (opcional): mostrar a relíquia em uso (`Progression.equipped_relic()` +
   `Progression.relic_data(id)`) e um aviso "Selo aberto" quando um Arconte cai
   (`Progression.rings_changed`) — hoje o jogador descobre olhando a loja.

## → level6
1. Segredos/caminhos com pulo duplo: `Progression.has_double_jump()` (ou
   `RunManager.has_double_jump()`, do mapa6, que delega para cá).

## → balance (quem cuidar do bot)
1. `_auto_shop` do bot usa `upgrade_weapon/upgrade_skill` (já respeitam o selo) e
   `buy_max_health(20, preço)` direto (ignora o teto novo). Para medir a loja nova, usar
   `Progression.buy_health_upgrade()` / `buy_mana_upgrade()` / `buy_relic(id)`.
