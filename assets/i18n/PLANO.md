# GNOSIS — Plano técnico da localização (pt-BR → en)

> Agente de Localização, Onda 2 (17/10/2026). **Nada disto está ligado no jogo
> ainda**: `assets/i18n/` tem `.gdignore` (o Godot não importa) e nenhum arquivo do
> jogo foi tocado. Este documento diz o que fazer para ligar, arquivo por arquivo.

## 1. O que existe hoje (pronto)

| Arquivo | O que é |
|---|---|
| `tools/i18n/extract.py` (+ `rules.py`) | varre `scripts/**/*.gd` e `scenes/**/*.tscn`, acha toda string visível e gera `assets/i18n/strings.csv` (id estável, pt, en, tipo, falante, limite, onde, nota). O descartado vai para `_descartadas.txt` (auditável). |
| `assets/i18n/en/*.tsv` | **a tradução** (fonte única do inglês), 8 lotes por arquivo de origem: `id<TAB>inglês`. |
| `tools/i18n/build.py` | junta os lotes no CSV, confere (`%d/%s` iguais, quebras de linha, BBCode, glossário, nomes proibidos, CAIXA ALTA, tique "Climb.", limites em caracteres) e gera `assets/i18n/godot/en.po` e `gnosis_text.csv`. `--strict` sai com erro se faltar algo. |
| `tools/i18n/EnFit.tscn` | mede o inglês **com as fontes e larguras reais** (DialogueBox, CaptionBar, StelaPanel, cards do Cinematic, card de chefe, toast, botões de escolha) e compara a largura da UI pt×en. Com janela salva capturas de amostra. |
| `assets/i18n/GLOSSARIO.md` | glossário inglês e guia de voz. |

Hoje: **1024 textos visíveis, 1024 traduzidos** (≈47,6 mil caracteres pt → ≈49,9 mil en).

Fluxo quando o português mudar: `python3 tools/i18n/extract.py` (o CSV ganha/perde
linhas; traduções de texto alterado aparecem como "id do lote não existe" no build)
→ traduzir as faltantes num lote → `python3 tools/i18n/build.py --strict` →
`godot --headless --audio-driver Dummy --path . res://tools/i18n/EnFit.tscn`.

## 2. Decisão: a chave é o próprio texto em português (estilo gettext)

`msgid` = o texto pt exato; `msgstr` = o inglês. Por quê:

1. **Rótulos e botões com texto literal traduzem sozinhos.** No Godot 4, `Label`,
   `Button`, `RichTextLabel` etc. com `auto_translate_mode` herdado (padrão) mostram
   `atr(text)`: se o texto bate com uma chave, aparece o inglês. As cenas `.tscn` e
   todo `x.text = "Literal"` funcionam sem mudar uma linha.
2. **Fallback natural**: texto sem tradução continua em português (a chave é o pt).
3. **A propriedade `text` continua guardando o pt** (a tradução é só na exibição) —
   a lógica que compara texto (`codex_style.wire_buttons` usa
   `b.text.begins_with("Voltar")`) não quebra.
4. Nada de ids mágicos no código; o id do CSV (`narrative.temptation.4cf745`) serve
   só para revisão e para os lotes.

Formato: usar o **`.po`** (gettext) — o Godot 4 importa `.po` direto como
`Translation`, aceita `msgctxt` (para homônimos com traduções diferentes, se um dia
aparecer) e plurais. O `gnosis_text.csv` (`keys,en`) é gerado também, como
alternativa; com chaves longas com vírgulas e quebras de linha o `.po` é mais seguro.

## 3. Ligar no jogo — passos (Técnico + donos dos arquivos)

1. **Pasta importável**: copiar `assets/i18n/godot/en.po` para `res://locale/en.po`
   (pasta nova, sem `.gdignore`) — ou fazer o `build.py` gravar lá.
2. **project.godot** (dono: Técnico):
   `internationalization/locale/translations=PackedStringArray("res://locale/en.po")`.
   Para testar: `internationalization/locale/test="en"`.
3. **Idioma inicial**: no boot (`GameManager._ready`), `TranslationServer.set_locale(...)`
   com `settings["locale"]` se existir; senão `OS.get_locale_language()` (`"pt"` →
   `"pt_BR"`, qualquer outro → `"en"`). Sem lib externa não dá para ler o idioma
   escolhido no cliente Steam (isso exigiria o GodotSteam); o idioma do SO + a opção
   no menu bastam.
4. **Opção "Idioma / Language"** no `options_menu.gd` (linha nova em "Vídeo & jogo",
   ciclo Português ↔ English, como a de Legendas), salva em `GameManager.settings["locale"]`
   pelo SaveManager. Os rótulos com texto literal trocam na hora (o Godot reenvia
   `NOTIFICATION_TRANSLATION_CHANGED`); telas com texto montado por código devem
   refazer o texto ao receber essa notificação (ou simplesmente na próxima abertura).
5. **Código** — onde a tradução automática NÃO alcança (lista exata na §4):
   - texto **formatado** (`"Continuar · %s, tela %d" % [...]`): o resultado não bate
     com chave nenhuma → `tr("Continuar  ·  %s, tela %d") % [...]`. São **55** strings
     com `%` (coluna `note` do CSV diz "format string"). Em função `static`, usar
     `TranslationServer.translate(...)`.
   - texto **concatenado** ou **com gênero** (pedaços "do "/"da ", "Eco de " + nome):
     reescrever como frase inteira (§4).
   - **`to_upper()` antes de atribuir** (`options_menu`, `credits`, `chronicles`,
     `stela`, `character_atelier`): traduzir primeiro, depois `to_upper()`.
   - **`draw_string`** (o "continuar" da DialogueBox): não tem tradução automática → `tr()`.
   - **DialogueBox e CaptionBar**: a digitação usa `_text.text[i]` (o pt) para as
     pausas na pontuação, mas `get_total_character_count()` (o texto exibido) para o fim.
     Com tradução automática os índices desalinham (pausas no lugar errado). Correção:
     `_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED` e
     `_text.text = tr(String(l.text))`. O **falante** (`speaker`) continua em pt nos
     dados — `portrait_for`, `blip_for` e o `SPEAKER_BLIPS` do áudio usam o nome pt
     como chave —, e só a placa mostra `tr(who)`.
   - **Narrative**: as falas com `%` (`ring_gained`, `death_revive`, `echo_shard`,
     `final_form_fell`, `final_revive`) passam a fazer `tr(fmt) % [tr(arg), ...]`
     (o ordinal e o nome da magia também traduzidos). As demais falas literais
     funcionam pela caixa (item acima).
   - **Dados em constantes** (`Gnosis.STELAS`, `BOSS_TITLES`, nomes do Bestiário,
     golpes e magias do `GameContent`) ficam em pt; quem exibe traduz. Onde o nome
     entra num formato (`"%s (Elite)"`, `"Arma Nv. %d → %d"`, `"abre: " + nomes`),
     traduzir o nome antes.

## 4. Pontos que precisam de refatoração (não dá para traduzir só com `tr`)

| Onde | Hoje | Proposta (pt e en) |
|---|---|---|
| `gnosis.gd` `boss_card("campeao")` | `"Guardião do santuário %s %s" % ["da"/"do", n]` | tabela de 7 títulos inteiros: *Guardião do santuário do Torpor* → **Guardian of the Shrine of Torpor**; Fome → *of Hunger*; Corrente → *of the Chain*; Silêncio → *of Silence*; Espelho → *of the Mirror*; Praga → *of Blight*; Coroa → *of the Crown* |
| `enemy.gd` `_eon_title` | `"Campeão %s" % ("da "/"do " + n)` | 7 nomes inteiros: **Champion of Torpor / of Hunger / of the Chain / of Silence / of the Mirror / of Blight / of the Crown** (hoje o lote traduz "do "/"da " como "of ", o que dá *Champion of Chain* — sem artigo) |
| `bestiary.gd` ecos | `"Eco de " + nome` | `tr("Eco de %s") % tr(nome)` → *Echo of Athoth* |
| `narrative.gd` `death_revive` | `"(A luz te costura de volta. %s da tua mão aberta.)" % _faiscas(n)` | ok com `tr`; **bug do pt**: com 1 faísca sai "…de volta. uma faísca escorre…" (minúscula depois do ponto) — o en já usa *One spark drains* |
| `moves_screen.gd` `_archon_name` | `"o Arconte de %s" % EON_NAMES[i]` | `tr("o Arconte de %s") % tr(nome)` (en: *the Archon of %s* → "the Archon of Chain" sem artigo: preferir a tabela de títulos acima) |
| `upgrade_menu.gd` | `"abre: " + ", ".join(nomes)` | `tr("abre: ") + ", ".join(nomes traduzidos)` |
| `character_atelier.gd` | `"ARCONTE  /  " + EON_NAMES[i].to_upper()`; dicionário de partes | `tr("ARCONTE  /  ") + tr(nome).to_upper()`; `tr(names[feature])` |
| `stela.gd` | `"ESTELA  ·  %s" % eon.to_upper()`, `"Fonte: %s"`, rodapé | `tr(...) % tr(eon).to_upper()` etc. (as capturas do EnFit mostram estes três ainda em pt) |
| `credits.gd` | lê pedaços do `assets/LICENSES.md` (pt) | o bloco "texto de atribuição" não existe mais no LICENSES.md, então a tela usa o `FALLBACK_ATTRIBUTION` (traduzido); a tabela de packs é nome próprio/licença (fica igual) |

## 5. Fontes

Cinzel, Cinzel Decorative e Alegreya cobrem todo o inglês (inclusive `“ ” ‘ ’ — …`
que o pt já usa). Nada novo a embarcar. Conferido nas capturas do EnFit
(`/home/user/caps/i18n/en_*.png`).

## 6. Validação antes de anunciar inglês na Steam

1. `python3 tools/i18n/build.py --strict` → 0 faltando, 0 alertas.
2. `EnFit.tscn` → 0 falhas (hoje: 0 falhas, ~23 avisos de UI que crescem > 15% —
   lista no relatório; revisar cada um na tela real depois de ligar).
3. Depois de ligar: capturas de TODAS as telas em inglês (menu, opções, pausa,
   ateliê, crônicas, golpes, loja, fim, créditos, Provação, uma tela de cada Éon,
   Estela, card de chefe, final) com `tools/Shot.tscn` e locale `en`.
4. **Revisão humana por falante nativo** (recomendado antes de vender): a tradução é
   literária e coerente com o glossário, mas foi feita por IA.
5. Na página da Steam: marcar inglês (interface + legendas), sem áudio de voz.
