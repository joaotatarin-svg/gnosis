# UI6 — relatório do diretor de UI (Onda 6, branch `dir6/ui6`)

Base `origin/integracao/onda1` @ `ce2e35e` (já tem progressao6 e mapa6; chefes6, level6 e
narrativa6/encenacao5 AINDA NÃO — tudo deles é lido por `has_method`/`get`).
Todo Godot com `--audio-driver Dummy`; capturas em janela 640×360 fora da tela (4000,4000).
Capturas (fora do git): `C:\gnosis-wt\_caps\ui6\antes\` e `depois\`.

## O que mudou (pedidos acumulados dos diretores)
1. **Barra de chefe com 3 fases (chefes6)** — `hud.gd`: um marcador por item de `phase_marks`
   (padrão `[0.5]` = chefe antigo); o j-ésimo vira brasa quando a fase j+2 chega e só ELE pisca.
   Fase III: barra sangue-escuro com miolo em brasa pulsando, "FASE III" e medalhão "III".
   Identidade vermelha preservada (fase I ouro, II carmim, III sangue). `boss_bars()` devolve `marks`.
2. **Retratos novos (encenação/narrativa)** — `assets/ui/build_derived_portraits.py` (novo) recorta os
   bustos de `assets/painted/derived/portraits/` em medalhões 128×128: `cego_{olhando,assustado,
   sereno,aninhado}.png` e `rei_revelado.png` (substitui o de máscara rachada pelo busto sem máscara,
   olho âmbar). `DialogueBox`: falante com "cego"/"blind" → id `cego` (antes do teste do Rei),
   `MOODS.cego`, padrão `olhando`; o nome exato do humor vence o sinônimo global.
3. **`hud.show_hint_now(segs)` / `(texto, teclas)` (narrativa)** — fura a fila, 6 s, não encurta
   ao apertar a tecla (ensino é sequência), a dica interrompida volta para a fila. `hint_state()` p/ QA.
4. **Relíquia e selo (progressao6)** — emblema da relíquia (brasa/lâmpada/pérola desenhados) ao lado
   dos losangos da arma; acende quando troca e quando a Brasa/Lâmpada age numa faísca. Pausa:
   "Relíquia em uso · Brasa Viva". Toast **"Selo aberto · Arma Nv. N na loja"** (ou relíquia, ou
   "mais Vida e Éter") quando `progress_tier()` sobe; `static var` segura o aviso até a próxima tela.
5. **Objetivo da zona (level6)** — ícone + 3 palavras sob o progresso do Éon enquanto a zona trancada
   tem objetivo: totem (pilar, brasa), proteger (luz com raios), maré (ondas). Lê
   `Level.zone_objective(zone_index)`; "ondas" = nada. Nesta base o Level não tem a função: a
   captura FORÇA o ícone (não testei integrado).
6. **Tipo do nó (mapa6)** — `scripts/ui/run_labels.gd` (novo, `RunLabels`): "Fome · Arena",
   "Torpor · Escalada"… no HUD e na pausa (Travessia comum segue "Travessia II").
   **Botão "Mapa" na pausa** (só dentro dos Éons de um run): abre o `WorldMap` em modo leitura —
   setas passeiam pelas saídas, confirmar NÃO escolhe (a pausa engole `ui_accept`), mouse desligado no
   grafo, Esc/B/Start fecham e o foco volta ao botão. Separação da pausa 8→6 px (cabe com relíquia +
   aviso de combate).
7. **`tools/ui_menus/menu_probe.gd`** — loja confere contra a Progression (90×(n+1), teto 3 + grau,
   soma dos preços), não contra números fixos. `UIM RESULT: 112 ok, 0 falha(s)`.
8. **i18n** — lote `assets/i18n/en/15_ui6.tsv` (15 textos). Obs.: com `core.autocrlf=true` o
   `strings.csv` vem em CRLF e o `extract.py` perde as traduções multilinha (18 órfãs) — normalizei
   para LF antes de extrair (mesmo achado da narrativa6).

## Sonda
`tools/UxShots6.tscn` (headless = só conferências; com janela = fotos `ux6_*.png`). Casos: titulo,
chefe3 (chefe falso com `phase_marks` [0.66, 0.33]), dica, reliquia, objetivo, selo, mapa (inclui
navegação D-pad/teclado da pausa), retratos. Depois: `UX6 RESULT: 29 ok, 0 falha(s)`.
Antes (arquivos da base): `3 ok, 9 falha(s)`.

## Não ficou bom / não testado
- Objetivo e 3 fases não foram vistos com o código REAL do level6/chefes6 (branches fora da base).
- O mapa em leitura mostra as SAÍDAS da camada atual (é o que o WorldMap sabe mostrar); destacar o
  nó atual é pedido ao mapa6 (`read_only`).
- Não testei com controle físico (eventos simulados).

## BILHETE PARA O SUCESSOR
- Estado: todos os 7 pedidos feitos; último commit = o desta seção (ver `git log dir6/ui6`).
- Próximo passo: quando chefes6/level6/narrativa6 entrarem na integração, rodar
  `UxShots6` com janela e olhar `ux6_chefe_fase3` / `ux6_objetivo_*` com o código real.
- Armadilhas: `hud._HudCanvas` usa `hud` sem tipo → variáveis com `:=` a partir de `hud.x` não
  compilam (use `: float`); o `--editor --quit` NÃO pega esse erro, a sonda/ScriptCheck pega.
  Normalize `assets/i18n/strings.csv` para LF antes do `extract.py`.
- Arquivos-chave: `scripts/ui/hud.gd`, `scripts/ui/run_labels.gd`, `scripts/ui/pause_menu.gd`,
  `scripts/ui/dialogue_box.gd`, `assets/ui/build_derived_portraits.py`, `tools/ux_shots6.gd`.

## Validação final
- `validate.ps1 -Repeat 2`: **TUDO VERDE (11 etapas)** (Scripts, ScriptCheck, CodexQA 53, AudioQA 54,
  GnoseQA 20, SaveQA 49, Puppet, Hero, Wave, TecnicoQA 43, LangQA) — 2/2 verdes cada.
- i18n: `build.py --strict` 1380/1380, 0 alertas; EnFit `0 falha(s), 67 aviso(s)` (os da UI6 são
  avisos de largura: "Weapon Lv. %d in the shop", "%s in the shop", "more Life and Aether in the shop",
  "protect the light" — todos cabem: toast encolhe a fonte, objetivo alinha à direita).
- `UxShots6` headless pt: 29 ok, 0 falha; en: textos saem em inglês ("Seal opened · Oil Lamp in the shop").
