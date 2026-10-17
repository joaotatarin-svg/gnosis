# Sistema visual da interface — GNOSIS

Dono: diretor de UI/UX. Código em `scripts/ui/`, fontes em `assets/fonts/`,
retratos em `assets/ui/portraits/`. Tudo desenhado por código (sem texturas de
moldura); legível na base 640×360 (a janela 1280×720 desenha em 2×).

## 1. Direção

Um códice gnóstico iluminado: **azul-noite** de fundo, **marfim** para ler,
**ouro velho** para estrutura e a **luz da faísca** para o que é vivo (foco,
moeda, gema acesa). Cantos chanfrados (pedra talhada), filetes duplos,
cantoneiras e losangos. Nada de caixa reta cinza.

## 2. Paleta (`CodexStyle`)

| Constante | Cor | Uso |
|---|---|---|
| `INK` / `INK_DEEP` | `#0a151c` / `#060d12` | fundos, sombras, contorno de texto |
| `NIGHT` | `#12252e` | topo do degradê de painéis/botões |
| `PAPER` | `#eee4cd` | texto principal |
| `GOLD` / `GOLD_HI` / `GOLD_LO` | `#c5a56a` / `#ecd498` / `#6f5a35` | molduras, títulos, foco, filetes |
| `MUTED` | `#8caaa9` | texto secundário (verdete) |
| `SPARK` | `#fff0bf` | faíscas, marco atual, barra fantasma |
| `EMBER` | `#e0743a` | perigo, fase II, vida baixa |
| `LIFE` / `LIFE_HI` | `#c9475b` / `#f08a8f` | barra de vida |
| `ETHER` / `ETHER_HI` | `#4f9ad0` / `#a6e1f5` | barra de Éter |

## 3. Tipografia (OFL, `assets/fonts/*/OFL.txt`)

| Papel | Fonte | Função |
|---|---|---|
| Títulos, botões, nomes, chefe | **Cinzel** (variável, peso 600/800; 500 acima de 30 px) | `CodexStyle.display()`, `display_bold()`, `display_font_for(size)` |
| Logotipo GNOSIS | **Cinzel Decorative Bold** | `CodexStyle.logo()` |
| Texto corrido, falas, números | **Alegreya** (peso 500/750, algarismos alinhados `lnum`) | `CodexStyle.body()`, `body_bold()` |
| Dicas, legendas de efeito, citações | **Alegreya Italic** | `CodexStyle.italic()` |

- `CodexStyle.serif()` continua existindo (cinemáticas, Estelas) e devolve a Alegreya.
- O Cinzel é versalete por natureza: escreva em caixa normal ("Athoth") que ele
  vira versalete; não precisa `to_upper()`.
- Tamanhos-base: corpo 11–12, dicas 10, títulos de seção 8–9 (Cinzel), títulos
  de tela 18–22, logotipo 40–50. A Alegreya tem olho menor que a fonte antiga:
  diálogos usam `caption_font_size() + 1`.
- Glifos que a Alegreya NÃO tem: `▸ ✦ ✕ ○` (caem na fonte do sistema). Prefira
  desenhar (losango/faísca) ou usar `·`/`—`.

## 4. Tema global

`SceneManager._ready()` chama `CodexStyle.install_global(tree)`: mescla o tema no
tema padrão do motor e no `root`, então todo `Control` do jogo já nasce com
fonte, botão, painel, slider e barra de rolagem do Códex — sem tocar no
`project.godot`. `CodexStyle.release()` solta os caches ao sair.

## 5. Componentes

- **`CodexFrame`** (`codex_frame.gd`, StyleBox com `_draw`): chanfro, degradê,
  filete, filete interno, `marks` = `SIDES` (losangos laterais = foco) ou
  `CORNERS` (cantoneiras de painel), halo e sombra.
- **Botão**: `CodexStyle.button(parent, texto, pos, largura, ação, primário, sfx)`
  ou `style_button(b)` em botões de cena. Estados: normal (filete 38 %),
  hover (80 %), pressionado, desativado, **foco** = contorno aceso + losangos +
  halo (desenhado por cima). Primário = ouro com texto azul-noite.
  O mouse que passa por cima toma o foco (mouse e controle mostram a mesma coisa).
- **Painel**: `CodexStyle.panel_frame()` (tema de `Panel`/`PanelContainer`).
- **Filete**: `CodexStyle.rule(parent, pos, largura)` / `CodexStyle.Rule`.
- **Ícones desenhados**: `draw_diamond`, `draw_spark`.
- **Fundo vivo**: `CodexStyle.Motes` (poeira de luz determinística).
- **Animação**: `pop_in(nó)` (overlay abre: fade + escala, som `ui_open`),
  `stagger_in(nós)` (entrada escalonada; dentro de Container só faz fade).
- **Confirmação**: `CodexStyle.confirm(...)` (Esc/B = Voltar).

## 6. Sons de interface

| Som | Quando |
|---|---|
| `ui_move` | foco mudou (global, `SceneManager`; silencioso no 1º foco de tela nova) |
| `ui_confirm` | botão apertado (padrão de `CodexStyle.button`/`wire_buttons`) |
| `ui_back` | Voltar, Esc/B |
| `ui_open` | overlay/painel abriu (`pop_in`) |
| `blip_voz`, `blip_rei`, `blip_sophia`, `blip_estela`, `blip_npc` | máquina de escrever (a cada 2 letras) |

Sem arquivo, o `Audio` fica mudo — nada quebra.

## 7. HUD (`hud.gd`, um `Control` desenhado)

Medalhão da Sophia (retrato, anel de ouro, brasa com vida < 30 %) · barra de
Vida (cunha, marcas a 25 %, **fantasma** que segura 0,45 s e drena; clarão no
golpe) · Éter · faíscas (ícone + número que corre) · arma (cajado + 5 losangos) ·
**7 Anéis** = gemas facetadas na cor de cada Arconte: *vazio* (contorno tênue),
*aceso* (gema), *equipado* (halo + seta), *roubado* (encaixe rachado, cinza) ·
progresso do Éon no canto direito (9 marcos num fio; Desafio = losango,
Arconte = losango coroado) · barra do chefe na base (nome em versalete,
subtítulo, fantasma, marcador de fase em 50 % que vira brasa na fase II).

API (grupo `"hud"`): `show_boss(e)`, `boss_phase(n)`, `toast(msg)`,
`ring_dot_global_pos(i)` (tela), `ring_dot_world_pos(i)` (mundo),
`detach_ring(i, alvo_tela)` → duração; sinal `ring_detach_finished(i)`.

## 8. Diálogo e legendas

`DialogueBox`: painel com cantoneiras, placa do nome, retrato em medalhão
(`DialogueBox.portrait_for(falante)`; A Voz/Estela sem retrato), máquina de
escrever 46 letras/s com respiro na pontuação, 1º aperto completa / 2º avança,
losango "continuar" respirando, escolhas como botões. Sinais: `finished`,
`choice_made(i)`, `line_shown(i, fala)` (campo `cue` da fala é do Level).
`CaptionBar`: faixa que se dissolve nas pontas, nome em versalete, retrato
pequeno, máquina de escrever com blip baixo, tamanho das Opções, some na pausa.

Retratos: `python -I assets/ui/build_portraits.py` regera `assets/ui/portraits/`
a partir das folhas pintadas (recorte, chave do magenta, máscara circular).

## 9. Telas

Menu (pintura com deriva + poeira, logotipo, entrada escalonada, grade com
vizinhos de foco explícitos) · Pré-jogo · Opções (nome à esquerda, valor em
ouro à direita, amostra da legenda) · Pausa · Golpes & Controles · Loja
(preço com faísca, foco preservado após compra, Esc fecha) · Crônicas (linhas
focáveis) · Ateliê · Bestiário (Esc/B e Voltar levam ao Ateliê) · Fim de jogo
(Créditos na vitória) · **Créditos** (`scenes/ui/Credits.tscn`, lê
`assets/LICENSES.md`; texto de atribuição embutido como reserva).

## 10. Verificação

`godot --audio-driver Dummy --path . --resolution 1280x720 --position 4000,4000 res://tools/UxShots.tscn -- <pasta>`
salva `ux_*.png` de todas as telas e testa a navegação (D-pad do controle vai,
seta do teclado volta) em menu, confirmação, pré-jogo, opções, Ateliê, fim,
escolha de diálogo, pausa e loja: imprime `UX NAV: N ok, M falha(s)`.
