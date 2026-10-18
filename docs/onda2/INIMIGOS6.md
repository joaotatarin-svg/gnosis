# INIMIGOS6 — Onda 6 (variedade, voadores, campeões) · relatório técnico

Branch `dir6/inimigos6` (worktree `C:\gnosis-wt\inimigos6`). Arquivos meus: `enemy.gd` (menos
`_kit_*`/`_boss_*`/`_enter_phase*`), `bestiary.gd`, `projectile.gd`, `hazard_zone.gd`,
`scripts/entities/enemies/**`, `tools/inimigos6/**`.

## 1. O que mudou

### Repertório por tipo (`scripts/entities/enemies/enemy_moves.gd`)
Cada comum tem **2–4 golpes de tipos diferentes** (antes: 1 ataque por `style`). Tipos de golpe:
`swing` (com avanço/alcance), `combo` (2–3 golpes, cada um aparável), `rush` (investida com linha de
aviso), `leap` (bote em arco; o da Aberração bate no chão), `slam` (pancada + ondas rasteiras),
`nova` (área imparável — repulsa/brado), `shot` (único/leque/teleguiado lento), `burst` (rajada em
sequência, cada seta re-mirada), `lob` (arco que deixa zona de veneno/sono), `pillar` (anel de
aviso no chão → coluna de luz), `fissure` (lâmina rasteira — pula-se), `grab` (agarrão AMARELO:
aparável; se pega, prende 0,7 s e arremessa; esquivar solta), `dive`/`glide` (voadores), `blink`
(aparece atrás e golpeia), `summon`, `explode`, `retreat` (salto de fuga do atirador).
Seleção: **intenção** (decide o golpe e anda até a distância dele), peso + recarga por golpe,
o último golpe pesa 1/3 (não repete), sorteio de semente fixa por inimigo (tela + tipo + x).

### Voadores (Tarefa 1)
- **Espectro Mergulhador** (novo, tier 2 = Éons 1–2): paira ~70 px, linha tracejada de aviso,
  **mergulha na diagonal**, pousa 1 s (castigo por terra), rasante na altura dela, uivo teleguiado lento.
- **Vigia Alado** (tier 3): orbita por cima e troca de lado, **leque mirado de cima**, coluna de luz
  sob a Sophia, rasante.
- **Fantasma**: flutua baixo (~24 px), aparece atrás e agarra.
- Atingido no ar (aéreo/magia/aparo) = **derrubado**: cai com gravidade e fica vulnerável (juggle).
  Antes da arma nv. 3 a Sophia não tem golpe aéreo: por isso todo voador DESCE (mergulho/rasante/pouso).
- Asas de luz por código (`EnemyOverlay`), sombra presa ao chão por raio. `is_flyer()` p/ o level6.

### Grupo e dificuldade (Tarefas 2–3)
- **Fila de agressão** (`EnemyAggro`): no máximo **2 comuns** em telegrafo/golpe ao mesmo tempo e
  ≥0,35 s entre inícios; quem espera fica numa roda a ~80 px balançando (Campeão fura a fila).
- **Papéis**: tank cola na frente · melee · skirm flanqueia pelo lado livre · shooter fica a
  120–240 px e **foge** (salto de recuo) · flyer orbita por cima.
- **Reflexos**: guarda (leve pela frente passa 15 %, PESADO quebra e atordoa, magia ignora; depois
  contra-ataca) e esquiva pra trás — chance por tipo, recarga 1,5 s.
- **Elites**: modificador fixo por tela+tipo e VISÍVEL — escudo (bolha que racha; ao estourar,
  atordoa), fúria (brasas; +25 % velocidade, −40 % espera, telegrafo −15 %), regeneração
  (fagulhas verdes; 3 %/s após 1,5 s sem apanhar).
- **Vida dos comuns ≈ ×1,7** e dano +~10 % (tabela no `bestiary.gd`). Conta: golpe leve da Sophia
  ≈ 12 + 3/nível (contrato pedido ao combate6) → 4–8 golpes nos comuns, 8–10 nos tanques
  (Bruto 120, Pretoriano 130). Se o combate6 mantiver +6/nível: 4–6 golpes.
- **Sem dano de contato** (playtest 2): `ContactHitbox` desligada em todos (inclusive chefes).
- **Hurtbox = corpo desenhado** (playtest 2): a cada quadro, do topo ao pé do quadro pintado
  (`top/foot_y/pelvis_x` do JSON), ~½ da largura do recorte, seguindo a mola/vira-lado/voo.

### Campeões e famílias (Tarefa 4)
- Achado: **todo bot de Éon é pintado como família do Arconte** (sonâmbulo≈Athoth,
  glutão≈Harmas, carcereiro≈Galila, mudo≈Yabel, esporos≈Belias, pretoriano≈Armupiel) — e o Campeão
  era o bot ×1,25. Prova: `C:\gnosis-wt\_caps\inimigos6\arcontes_vs_bots.png`.
- Correção sem arte nova: **graduação de cor** no shader do contorno (`enemy_grade.gdshader`):
  bots **cinzentos** (sat 0,38); **Campeão com a cor oposta à do Arconte** do Éon + escala 1,35 +
  diadema e aura + repertório do bot **+ brado (nova imparável) e onda dupla** + 2º fôlego a 50 %
  (fúria). Prova: `C:\gnosis-wt\_caps\inimigos6\lineup_sheet.png` (Arconte × bot × Campeão, 7 Éons).
- alado/fantasma/cornudo **não usam mais a pintura do Arconte** (`Bestiary._art_as`): alado =
  pintura do sonâmbulo graduada p/ âmbar, fantasma = do mudo em verde-espectro translúcido,
  cornudo = espadachim rubro. Interino — arte própria pedida.

### Flash (Tarefa 5 — QA2 #8)
`EnemyFlashLayer`: flash claro = camada ADITIVA ≤100 ms por cima da malha pintada (como a Sophia);
sem malha (procedural) clareia 30 %. Vale para chefes também.

### Projéteis
`projectile.gd`: `aim` (mirado), `arc_gravity`+`ground_y`+`land_kind` (arco que vira zona),
`homing` (teleguiado lento), `look` (bolt/wisp/seed/spike/page — formas por código) e **gancho do
VFX7**: se `VfxLibrary.projectile_look(proj, look, color)` existir, ele desenha. Tiros da Sophia
inalterados (`look` vazio). `hazard_zone.gd`: `HazardZone.pillar()`.

## 2. Validação
- `tools/validate.ps1 -Repeat 2`: **TUDO VERDE (11 etapas, 2/2)**.
- Sonda `res://tools/inimigos6/EnemyProbe.tscn` (headless, `--fixed-fps 60`, ~1,5 min): 25 casos
  (23 tipos + Campeão + Elite) usam TODOS os golpes; voadores voam; Elite tem modificador; Campeão
  usa brado e onda dupla; Hurtbox segue o desenho; sem contato; **fila: pico 2 atacando**; telas
  13/40/58 → `erros=0` (a escolha é sorteada: raramente 1 golpe de recarga longa fica de fora em 40 s).
  Modos: `only=`, `screen=`, `out=` (quadros 960×540 por SubViewport, janela 320×180 fora da tela),
  `boxes` (desenha hurtbox verde / golpe vermelho), `lineup`.
- GIFs: `C:\gnosis-wt\_caps\inimigos6\gif\*.gif` (14, com caixas desenhadas); folhas `sheet_*.png`.

## 3. O que NÃO ficou bom
- A arte ainda é REUSO: espectro = pintura da larva; acólito/arauto/invocador = conjurador;
  bots/campeões só mudam de COR. Pedido de arte nova em `docs/pedidos/onda6_inimigos6.md`.
- Feel não testado por humano: tempo de telegrafo, a roda de espera e o dano somado podem pedir ajuste.
- Caixa do GOLPE dos inimigos ainda é posicionada por código (não pela arma desenhada).
- BalanceBot não pula: contra voadores ele depende do mergulho/rasante — rodar r9 depois.
- Bestiário (lore) sem texto para Espectro e Acólito (arquivo de outro dono).

## BILHETE PARA O SUCESSOR
Estado: tudo commitado e no `origin/dir6/inimigos6`; validate -Repeat 2 verde; sonda verde.
Rodar sonda: `godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/inimigos6/EnemyProbe.tscn -- screen=40`.
Onde mexer: golpes/papéis → `enemy_moves.gd`; IA → bloco "ONDA 6" no fim do `enemy.gd`
(`_chase_moves`, `_pick_move`, `_strike_move`, `_strike_tick`); números → `bestiary.gd`.
Próximos passos: (1) integrar a API do VFX7 quando sair (já há o gancho; confira a assinatura);
(2) trocar `_fit_hurtbox` pela `body_rect()` oficial se a Arte publicar; (3) quando chegar arte
nova dos bots/voadores, tirar `_art_as`/`_grade` do tipo correspondente; (4) balance com o r9.
