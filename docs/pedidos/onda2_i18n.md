# Pedidos do agente de Localização (i18n), Onda 2 — 17/10/2026

Nada disto foi editado por mim (arquivos de outros donos). Em ordem de importância.

1. **QA / dono do `tools/gnose_qa.gd` — a checagem (a) "todas as falas cabem na caixa" não mede nada.**
   A DialogueBox "digita" com `_text.visible_characters = 0`, e o Label só molda os
   caracteres visíveis (`VC_CHARS_BEFORE_SHAPING`): `get_line_count()` dá sempre 1.
   Prova no próprio log: `autoteste 13 px: 200 caracteres = 1 linhas` (deveria ser ≥ 3).
   Correção: `d._text.visible_characters = -1` depois de cada `d._text.text = ...`
   (e no autoteste), e falhar se o autoteste der < 3. Conferi com o mesmo truque em
   `tools/i18n/en_fit.gd`: hoje **nenhuma** fala do português passa de 2 linhas a 13 px
   nem de 3 a 16 px — o resultado era verdadeiro, mas por acaso.

2. **Narrativa (`scripts/autoload/narrative.gd`, `death_revive`)**: com 1 faísca perdida a
   fala sai "(A luz te costura de volta. uma faísca escorre da tua mão aberta.)" —
   minúscula depois do ponto. Trocar `"uma faísca escorre"` por `"Uma faísca escorre"`
   e `"%d faíscas escorrem"` fica como está.

3. **Técnico + donos de UI — ligar o inglês**: tudo em `assets/i18n/PLANO.md` §3–4
   (projeto: `internationalization/locale/translations`; opção de idioma nas Opções;
   `tr()` nas 55 strings com `%`; refatorar os pedaços com gênero "do "/"da " do
   Campeão em `gnosis.gd`/`enemy.gd`; DialogueBox/CaptionBar com
   `AUTO_TRANSLATE_MODE_DISABLED` + `tr()` para a digitação não desalinhar).

4. **UI (`credits.gd`)**: `_read_licenses()` procura a seção `## texto de atribuição`
   no `assets/LICENSES.md`, que não existe mais (a seção hoje é `## CRÉDITOS ...`) —
   a tela cai sempre no `FALLBACK_ATTRIBUTION`. Pode ser intencional; se não for, alinhar.

5. **Roteiro (`docs/ESTILO_TEXTO.md` × `gnosis.gd`)**: o glossário diz "Arconte —
   maiúscula sempre, inclusive nas Estelas", mas as linhas das Estelas usam "arcontes"
   minúsculo (ex.: "Os arcontes geraram o Destino"). No inglês segui o glossário (*Archons*).
