# UI7 — UI e idiomas (Onda 7, versão 3.0.1)

Branch `dir7/ui7` (base `origin/integracao/onda1` 0a77007, com merge de `origin/dir7/audio7` 6df9411).
Fonte dos bugs: `qa7/docs/onda2/QA7.md`. Capturas: `C:\gnosis-wt\_caps\ui7\` (`antes\`, `depois\`,
`pranchas\<caso>.png` = ANTES/DEPOIS × PT/EN).

## Como reproduzir
`bash tools/ui7/run_probe.sh <pasta> [casos]`: roda `tools/ui7/UI7Probe.tscn` em PT e em EN (`GNOSIS_LANG`).
Casos: `gallery, moves, shop, credits, dialog, seal, stela, card, hud, numbers`. A janela tem 320×180 e fica fora
do monitor; a raiz renderiza em 640×360 (modo viewport), e a foto sai na resolução base. "Antes" = os mesmos
arquivos em 0a77007 (checkout temporário dos arquivos, sonda igual).
Resultado: antes **PT 5 falhas, EN 9**; depois **PT 0, EN 0**.

## O que mudou (por bug)
| # | Correção | Arquivo |
|---|---|---|
| 4 | Lore do bestiário traduzido **linha a linha** (a tabela tem as linhas soltas) | `scripts/ui/gallery.gd` |
| 6 | Placa dos Selos: 2 literais (cada linha é uma chave). Tradutor: um bloco de várias linhas em que TODAS as linhas têm tradução agora é traduzido linha a linha, e um padrão que devolve o português intacto não conta mais (o genérico `%s %s` trancava a placa) | `scripts/entities/seal_puzzle.gd` (só a linha do texto), `scripts/i18n/gnosis_translation.gd` |
| 7 | Golpes & Controles: cada glifo é traduzido sozinho e a linha montada não passa de novo pela tradução automática (ela casava pedaços: "Square Square Quadrado Quadrado"). "Telégrafo" com acento | `scripts/ui/moves_screen.gd` |
| 14 | A caixa de diálogo guarda a cena que a abriu; se a cena trocar (Crônicas, Galeria, Abandonar…), ela solta a pausa, emite `finished` e some | `scripts/ui/dialogue_box.gd` |
| 16 | Loja: nomes dos golpes do "abre:" traduzidos um a um. Créditos: a linha do `LICENSES.md` é traduzida inteira se houver chave; senão o rótulo ("Efeitos CC0:") e os trechos conhecidos (anônimo, multi-licença, feitas para GNOSIS…) | `scripts/ui/upgrade_menu.gd` (só texto), `scripts/ui/credits.gd` |
| 17/23 | Card de chefe: faixa escura macia (elipse) atrás do nome e do subtítulo + subtítulo com contorno 5 e quebra de linha. Lê sobre o Colosso e sobre plataformas. O card repetido é da narrativa (já resolvido lá) | `scripts/fx/cinematic.gd` (só `_build_boss`/`_run_boss`) |
| 24 | HUD na **CanvasLayer 20** (antes 1, a mesma da vinheta do cenário, e abaixo do clarão de tela, 5). Pausa e Loja passam a 45; Golpes 50, legenda 60, caixa 90 e cinemática 95 seguem por cima. Mais uma sombra de leitura (elipse) atrás do medalhão/barras e do nome do Éon, mais forte com chefe na arena | `scripts/ui/hud.gd`, `pause_menu.gd`, `upgrade_menu.gd` |
| 27 | "telégrafo amarelo:" com acento. Botão View do Xbox = **"Exibir"** (nome oficial da Microsoft no Brasil; EN "View"). **"Create"/"Options" do PlayStation ficam**: é o nome que a própria Sony usa no manual em português. Não é um texto esquecido em inglês | `scripts/ui/hud.gd`, `scripts/ui/input_glyphs.gd` |
| 30 | "Siga em frente" deixou de ser toast no centro: virou uma **seta na borda direita** (chevrons correndo para a direita, 3,2 s de jogo, congela na pausa/cena). O centro fica com a legenda e o convite da Estela. O painel da Estela **já pausava pelo PauseStack** (pedido da narrativa6 atendido). A sonda confirma: árvore pausada, Sophia parada com velocidade forçada e despausa ao fechar. Não mexi em `stela.gd` | `scripts/ui/hud.gd` |
| R16 (Guardião) | Números de dano: acertos no mesmo alvo (mesma cor, ≤36 px, ≤0,3 s) **somam** no número que está na tela, que dá pop de novo. Teto de **6** números vivos (some o mais velho). Entrada **1,35 → 1,0 em 80 ms** (ease-out-back, relógio real: o hitstop não estica o pop). A opção "Números de dano" já existia e vem ligada | `scripts/fx/damage_number.gd` |
| Áudio7 | `_equip_relic` sem `shop_buy` (o `relic_equip` toca pelo sinal). Os sons do mapa ficaram em pedido ao mapa7 (`docs/pedidos/ui7.md`) | `scripts/ui/upgrade_menu.gd` |

i18n: lote `assets/i18n/en/17_ui7.tsv` (17 textos). Tirei 3 ids velhos de `08_ui.tsv` e `10_onda4.tsv`.
`strings.csv` foi normalizado para LF antes do extract. `build.py --strict` deu **1434/1434, 0 alertas, 0 problemas**.

## Capturas (o que provam)
- `pranchas\gallery.png`: no EN, o lore do Rei sai em inglês nas duas linhas.
- `pranchas\moves.png`: no EN, só aparece Square/Triangle, sem "Quadrado".
- `pranchas\shop.png`: "opens: Arcane Rift, Arcane Ascent".
- `pranchas\credits_330.png`, `credits_560.png`: no EN, o bloco de som e a lista de packs sem trechos em PT.
- `pranchas\dialog_cronicas.png`, `dialog_galeria.png`: antes a caixa "A Voz" ficava por cima das Crônicas e da Galeria. Depois ela some.
- `pranchas\seal_depois_pt_en.png`: a placa em PT e em EN ("THE THREE SEALS / strike them in the order they glow").
- `pranchas\stela_pilha.png`: antes, a legenda e o "SIGA EM FRENTE →" ficavam empilhados no centro. Depois a seta fica na borda direita.
- `pranchas\stela_painel.png`: o painel aberto. Nesta captura a pausa é medida pela sonda, não pela imagem.
- `pranchas\card_68.png` e `zoom_card68_en.png`: a faixa escurece o fundo atrás do subtítulo (luminância média da faixa 82 → 51).
- `pranchas\hud_68.png`: HUD com sombra de leitura na luta dupla.
- `pranchas\hud_dica_ps.png`, `hud_dica_xbox.png`: "Create / L2" no PS e "Exibir"/"View" no Xbox.
- `pranchas\numeros_soma.png`: 5 acertos de 12 viram um "60" só.

## Validação
- Sonda UI7 (depois): **PT 0 falhas, EN 0 falhas**, 0 SCRIPT ERROR.
- `tools/validate.ps1 -Repeat 2`: **TUDO VERDE (11 etapas)**, 2/2 em todas (CodexQA 53, AudioQA 66, GnoseQA 20, SaveQA 49, TecnicoQA 43, LangQA).
- EnFit: **0 falha(s), 68 aviso(s) de UI**. São avisos de largura (+20–46%) em textos que cabem; os novos dos Créditos ("anonymous") também cabem.
- `--editor --quit`: 0 SCRIPT ERROR / Parse Error.

## O que NÃO ficou bom / não verificado
- **#24**: o HUD já estava acima do mundo (CanvasLayer 1 contra 0). O que "passava por cima" era a vinheta do cenário e o clarão de tela, que dividiam ou superavam a camada. Os anéis do Rei continuam passando ATRÁS do medalhão: agora com sombra, mas ainda passam. O ideal seria o chefe não pôr orbe em y < 70 na faixa x < 230 (pedido registrado; o chefes6 fechou).
- **#30**: na captura da sonda, a Sophia e a Estela da tela 3 ficaram fora do quadro (o layout do level6 mudou a posição). A prova do empilhamento é a ausência do toast no centro e a seta na borda, medidas pela sonda.
- A soma dos números de dano é por PROXIMIDADE (36 px, mesma cor), não pelo alvo, porque o `spawn()` não recebe o alvo e os chamadores (`enemy.gd`, `player.gd`) não são meus. Dois inimigos colados atingidos pela mesma área podem somar num número só.
- "Create"/"Options" do PS continuam em inglês no PT, de propósito (ver #27). Se o João preferir "Criar"/"Opções", é 1 linha em `input_glyphs.gd` + lote.
- Feel do pop (80 ms) e da seta: só o João jogando confirma.

## CHECAGEM DE SATISFAÇÃO
| Decisão | R atendidas | R violadas / justificativa | §4 conferido |
|---|---|---|---|
| Números de dano somados, teto 6, pop 80 ms, opção ligada por padrão | **R16** (exatamente o recomendado: 300 ms, 6 vivos, 1,35→1,0 em 80 ms ease-out-back); princípio 3 (dose média: menos "chuva") | Falta o "+2 px no pesado": o tamanho já cresce com o valor (11/13/16 px) | §4.3 (não empilhar feedback): menos números = menos ruído |
| Faixa escura atrás do card de chefe | **R18** (legibilidade: texto essencial com contraste sobre a arte) | — | §4.4 (sem clarão): a faixa escurece, não pisca |
| HUD em camada própria acima do mundo + sombra de leitura | **R18** (o HUD "salta" do fundo), **R21** (o recuo fora de combate continua: a sombra fica sob o mesmo HUD) | — | — |
| Seta "Siga em frente" na borda | **R21** (respiro: o centro fica livre para a legenda), **R18** | — | Não é recompensa nem urgência artificial: some em 3,2 s e congela na pausa |
| Painel da Estela pausa (PauseStack) | **R21** (ler sem apanhar) | — | Sem FOMO: ler é opcional e sem tempo |
| Caixa de diálogo fecha na troca de cena | **R18** (nada tapando botões) | — | — |
| Traduções (bestiário, glifos, loja, créditos, Selos) | **R5** indireto: a placa dos Selos ENSINA a regra em EN também | — | — |
§4 (todos): nenhuma recompensa aleatória, escassez ou quase-acerto foi criada. Sem tremor, flash ou som novo.

## BILHETE PARA O SUCESSOR
Estado: todos os bugs do briefing (#4 #6 #7 #14 #16 #17-UI #23 #24-UI #27 #30-UI + Estela pausada), R16 do
Guardião e o item do Áudio7 no `upgrade_menu` foram feitos. Sons do `world_map.gd` ficaram em pedido ao mapa7.
Último commit: ver `git log dir7/ui7`.
Armadilhas:
- os `.gd` estão em CRLF no disco (autocrlf); edite pelo Edit ou com Python preservando `\r\n`. `sed -i` funciona;
- normalize `assets/i18n/strings.csv` para LF ANTES do `extract.py`;
- o tradutor (`gnosis_translation.gd`) tem padrões genéricos (`%s %s`): texto montado pode casar errado → traduza as peças com `I18n.t` e desligue `auto_translate_mode` do Label;
- a sonda usa `content_scale_mode = VIEWPORT` para fotografar em 640×360 numa janela de 320×180.
Arquivos-chave: `tools/ui7/*`, `scripts/ui/hud.gd` (`GO_TOAST`, `HUD_LAYER`, `_draw_scrim`), `scripts/fx/damage_number.gd`.
