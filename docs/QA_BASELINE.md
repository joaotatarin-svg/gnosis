# QA — Linha de base visual, desempenho e config (Onda 1, Diretor Técnico)

Data: 17/10/2026 · branch `dir/tecnico` (base `codex/despertar` d291db0) · Godot 4.7.1,
`gl_compatibility`, RX 7600, monitor ~144 Hz.

Capturas: `C:\gnosis-wt\_caps\tecnico\baseline\` (fora do git). Visão geral das telas
paradas: `_overview_stills.png`. Sequências: `seq_*.gif|.mp4|_sheet.png` (+ `_meta.json`).
Script que regenera tudo: `C:\gnosis-wt\_caps\tecnico\baseline_run.sh`.

## 0. SOM — regra para TODA ferramenta (pedido do dono)

- Toda execução do Godot por IA usa **`--audio-driver Dummy`** (Shot, QAs, cenas, bots).
- `tools/shot.gd`, `tools/perf_probe.gd` e `tools/script_check.gd` também **mutam o bus
  Master** no `_ready` (`AudioServer.set_bus_mute(0, true)`) — cinto e suspensório.
- `tools/validate.ps1` já passa `--audio-driver Dummy` em todas as etapas.

## 1. Ferramentas novas (como usar)

### Filmar movimento — `Shot` em modo sequência
```
godot --path <wt> --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 --position 4000,4000 ^
      res://tools/Shot.tscn -- <tela|res://cena.tscn> <saida.png> <frames_antes> seq=N every=K [act=..] [solo|freeze|hold] [hurt|wave|...]
python tools/seq_to_media.py <saida>                       # GIF + MP4 + folha numerada (tela inteira)
python tools/seq_to_media.py <saida> --follow player --suffix _follow   # recorte que acompanha a Sophia
python tools/seq_to_media.py <saida> --follow boss --box 640x560        # idem, chefe
```
- `seq=N every=K`: N quadros, um a cada K frames (K=2 → 30 qps). Saem `<saida>_000.png…`.
- `act=` Input simulado (igual a um jogador): `walk` (direita/para/esquerda), `light`
  (combo leve), `heavy`, `dodge`, `magic` (Esfera Solar + Anel), `jump` (+ golpe aéreo),
  `combo` (L,L,L,H + aéreo), `demo` (anda, para, Lx3, H, esquiva, magia, pulo — use
  `seq=150 every=2`), `idle`.
- `solo` esconde e desliga os inimigos (filmar só a Sophia); `freeze` congela; `hold`
  impede o "anda até a próxima zona" durante a filmagem.
- `<saida>_meta.json`: por quadro, posição da Sophia e dos chefes em pixels da imagem,
  estado/golpe da Sophia (`ATTACK:m_LL`), estado/fase do chefe. A folha imprime isso
  em cada célula — dá pra ver QUANDO o estado muda e se a pose acompanhou.
- **Sempre `--fixed-fps 60`**: o PNG é salvo numa thread, mas mesmo assim o jogo cai
  pra ~100 qps reais; com fixed-fps o tempo de jogo entre quadros fica exato.
- 150 quadros levam ~25 s; `seq_to_media` ~10 s.

### Validar tudo — `tools/validate.ps1`
```
powershell -ExecutionPolicy Bypass -File tools\validate.ps1 [-Path C:\gnosis-wt\<cargo>] [-Only X,Y] [-Skip X] [-Full]
```
Etapas (≈55 s no total): `Scripts` (editor headless), `ScriptCheck` (compila TODO .gd),
`CodexQA`, `AudioQA`, `GnoseQA`, `SaveQA`, `PuppetQA`, `HeroQA`, `WaveQA`. `-Full` soma o
`CodexPlaytest` (bot por inputs, até 3 min). Reprova por exit≠0, tempo esgotado ou
linha com `SCRIPT ERROR|Parse Error|Failed to load script|QA FAIL|...`. Sai 0/1.

**Achado importante:** o `--editor --quit` que a BIBLIA manda usar **não pega erro em
.gd solto** (sem cena/class_name que o use). Testei com um script quebrado de propósito:
editor deu verde. Por isso criei `tools/ScriptCheck.tscn` (carrega cada .gd e checa
`can_instantiate()`) — ele pegou o erro. Use o `validate.ps1`, não só o editor.

Resultado na base atual: **TUDO VERDE (9 etapas)** — CodexQA 33 PASS, AudioQA 9,
GnoseQA 11, SaveQA 13; PuppetQA/HeroQA/WaveQA saem 0 (não imprimem "PASS").

### Desempenho — `tools/PerfProbe.tscn`
```
godot --path . --audio-driver Dummy --resolution 1280x720 --position 4000,4000 res://tools/PerfProbe.tscn -- tela=19 n=12 seg=10 [vsync=1] [ataque=0] [out=x.json]
```
Enche a arena com N criaturas comuns (repõe as mortas), Sophia imortal atacando sem
parar (gera golpes/faíscas/gibs), mede 10 s de frames reais. NÃO usar `--fixed-fps`.

## 2. Números de desempenho (RX 7600 + Ryzen 5 5600G, janela 1280×720, sem vsync)

| Cenário | qps médio | 1% low | mín | ms p99 | ms máx | vivos | draw calls |
|---|---|---|---|---|---|---|---|
| Tela 19 (Harmas) sem extras | 476 | 184 | 21 | 3,6 | 46,9 | 1 | 160 |
| Tela 19 + 12 criaturas | 208 | 81 | 40 | 10,5 | 24,8 | 13 | 392 |
| Tela 19 + 24 criaturas | 160 | 60 | 49 | 14,7 | 20,3 | 25 | 512 |
| Tela 22 + 12 | 222 | 86 | 23 | 8,5 | 43,7 | 12 | 401 |
| Tela 50 + 12 | 238 | **30** | **5** | 9,3 | **192,8** | 13 | 387 |
| Tela 64 (Armupiel) + 12 | 242 | 97 | 56 | 8,0 | 18,0 | 13 | 405 |
| Tela 50 + 24, sem ataque | 198 | 92 | 69 | 9,7 | 14,5 | 28 | 352 |
| Tela 19 + 12, **vsync on** | 140 (=monitor) | 78 | 46 | 11,1 | 21,7 | 13 | 358 |

Leitura honesta:
- **Média sobra** nesta máquina (≥140 qps com 25 inimigos). Não é gargalo hoje.
- **Engasgos (hitches) existem**: picos de 20–190 ms. O de 193 ms na tela 50 só aparece
  COM ataque (com 24 criaturas e sem ataque o máx. foi 14,5 ms) → é custo de
  **primeira vez** (compilar shader/criar material/carregar textura de VFX/gib no meio
  da luta). Um engasgo de 190 ms é visível pro jogador ("travadinha" no golpe).
  Recomendo pré-aquecer (instanciar 1x fora da tela cada VFX/gib/material no load da
  fase). Pedido registrado.
- **~20 draw calls por criatura** (392−160)/12 — partes do boneco/sombras/VFX sem lote.
  Em GPU integrada (o PC "fraco" que o projeto mira) isso pesa; não medi em iGPU.
- O `fps=` que o Shot imprime NÃO serve como medida (várias janelas em paralelo, saving).

## 3. Parecer crítico da linha de base (o que eu vejo)

Arquivos: `_overview_stills.png`, `seq_sophia_combo_sheet.png`, `seq_sophia_demo_sheet.png`,
`seq_chefe28_sheet.png`, `mipmaps_comparacao.png`.

**Parece final / bom:**
- **Menu**: composição, tipografia serifada, Sophia grande e nítida — é a tela mais "vendável".
- **Fundos pintados** têm atmosfera forte e paleta por Éon distinta (Torpor azul, Praga
  verde, Coroa dourada, Mente roxa/magenta). O Rei e Yaldabaoth têm presença.
- Barra de chefe dourada + nome ("Harmas, Arconte da Fome — FASE II") lê bem.

**Parece amador (em ordem de dano à percepção):**
1. **Animação da Sophia = troca de 6 fotos.** Na folha `seq_sophia_combo_sheet.png`, os
   golpes L, LL e LLL usam **a mesma pose** (estocada com o cajado); só o arco de VFX
   muda. O pesado é "ergue o cajado" → a mesma estocada. De ATTACK pra IDLE a pose
   **estala** sem quadro intermediário (quadros 042→044). O andar alterna 2 quadros a
   9 qps (`character_art.gd:1297`). É exatamente a queixa do João.
2. **Chefe parado + tinta chapada**: Galila (tela 28) passa CHASE→WINDUP→STRIKE com o
   **mesmo desenho**; o WINDUP pinta o sprite inteiro de **amarelo sólido** por ~0,7 s
   (quadros 028–044 e 108–116) — lê como bug de shader, não como "carregar golpe". O
   golpe em si é só um anel de VFX.
3. **Escala e enquadramento**: Sophia ocupa ~1/8 da altura da tela nas travessias; o
   **terço de baixo** da tela é uma faixa escura de chão + caixa de legenda — área
   morta. Criaturas comuns ficam minúsculas e somem no fundo escuro (telas 3, 8, 50).
4. **Fundo esticado**: o fundo é um recorte de **512×341** da folha `eons.png` esticado
   para 1280×720 (2,5× de ampliação) → visivelmente mole perto da Sophia/HUD nítidos.
   (Já está no ROADMAP como "fundos em resolução cheia".)
5. **Câmera deixa a Sophia sair do quadro**: no `demo` (tela 3, arena trancada), após
   correr pra direita e esquivar pra esquerda, a Sophia fica **fora da tela por ~16
   quadros** (meta: x<0 nos quadros 104–116 de `test/demo`). Causa provável: o
   look-ahead de 90 px de `camera_shake.gd` muda de lado devagar (180 px/s) somado ao
   smoothing do Camera2D e ao limite da arena. Pedido registrado.
6. **HUD com cara de debug**: "Faíscas: 0 / Arma Nv. 1" em texto cru, ícones pequenos;
   as falas ("A VOZ") ficam por cima da ação em toda captura.
7. **Plataformas flutuantes** (pedra roxa) parecem coladas, sem sombra/contato.
8. Telas 3 e 8 têm **o mesmo fundo** — repetição perceptível dentro do Éon.
9. **Recorte por chroma-key magenta** (`painted_key.gdshader`): com filtro linear a
   borda mistura magenta; com mipmaps vira **halo rosa** (ver `mipmaps_comparacao.png`).

Não revisei em detalhe: `seq_chefe10_f2` (gerado, não inspecionado), áudio, UI de menus internos.

## 4. Config (`project.godot`) e import — recomendações

Estado: `gl_compatibility`, viewport 640×360 → janela 1280×720, stretch `canvas_items`
+ `keep`, filtro padrão **linear** (1), sem mipmaps nas folhas pintadas
(`assets/painted/*.import`: `mipmaps/generate=false`, `compress/mode=0` lossless),
vsync padrão (ligado), física 60 Hz, sem MSAA. **Não mudei `project.godot`.**

- **Stretch `canvas_items`**: correto para arte pintada reduzida (desenha na resolução da
  janela, não num buffer de 640×360). Manter.
- **Filtro linear sem mipmaps**: a Sophia é desenhada ~2,8× menor que o PNG (512 px →
  ~180 px na janela) → serrilhado/"cintilar" das bordas ao andar. **Mipmaps ajudariam,
  MAS só depois que as folhas tiverem alfa de verdade** (hoje o fundo é magenta e o
  shader recorta; mipmap mistura o magenta → halo rosa, comprovado em
  `mipmaps_comparacao.png`). Ordem certa: (1) Animação gera PNG com alfa real
  (rembg `isnet-anime`) → (2) `.import` com `mipmaps/generate=true` → (3) filtro
  `linear_mipmap` (3) no projeto ou por nó. Pedido ao diretor de Animação.
- **Vsync**: manter ligado (monitor 144 Hz; com vsync rodou a 140 qps estáveis).
- **Física 60 Hz em monitor 144 Hz SEM interpolação** → movimento com "judder" (o corpo
  anda em degraus de 60 Hz desenhados a 144 Hz: repete 2 ou 3 quadros alternados).
  Isso contribui para o "movimento duro". Recomendo testar
  `physics/common/physics_interpolation=true` (Godot ≥4.3 tem 2D) **na Onda 2**, com
  `reset_physics_interpolation()` nos teletransportes (spawn, checkpoint, zona, Shot).
  NÃO liguei agora: não é "claramente seguro" sem tratar os teleportes.
- **MSAA 2D**: desnecessário para sprites; só valeria para Polygon2D/_draw do fallback.
  Manter desligado.
- `config/features` diz "4.3" mas o projeto roda em 4.7.1 — inofensivo; o editor
  atualiza quando salvar o projeto.
- **Export** (`export_presets.cfg`, alterado): `exclude_filter="tools/*, artes/*,
  shots/*, docs/*"` — o build não leva mais as ferramentas de QA nem as artes brutas
  (`artes/` 1,8 MB). Nenhum script do jogo referencia esses caminhos (verificado).

## 5. Código morto / sobras (só listado — NÃO apaguei)

Sem nenhuma referência (cena, script, class_name ou uid):
- `scripts/ui/main_menu.gd` — o `MainMenu.tscn` usa `scripts/ui/codex_menu.gd`.
- `scripts/data/enemy_data.gd` (`class_name EnemyData`) — nunca usado.
- `scripts/data/upgrade_data.gd` (`class_name UpgradeData`) — nunca usado.

Ferramentas soltas em `tools/` sem cena (scripts de uso único, `-s`): `analyze_silhueta.gd`,
`cut_art.gd`, `cut_sophia.gd`, `preview_alpha.gd`, `probe2.gd`, `slice_sophia.gd`; e as
imagens `tools/_assembled.png`, `tools/_preview.png`. `artes/` (brutos: `arconte
final.png`, `sophia_raw.png`) — só pipeline. Ficam fora do build pelo filtro acima.

## 6. Ruído conhecido nos logs (não é falha)
- `WARNING: N ObjectDB instances were leaked at exit` / `ERROR: N resources still in use
  at exit` em todas as QAs: as QAs chamam `quit()` com nós vivos. Inofensivo.
- SaveQA imprime `ERROR: Parse JSON failed` — é o teste de JSON quebrado, de propósito.
- Rodar o editor headless no worktree reescreve fins de linha de ~120 `.import`
  (só CRLF/LF, sem mudança real) — **não commitar** esses arquivos.
