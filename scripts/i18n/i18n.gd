class_name I18n
extends RefCounted
## Idioma do jogo (Onda 4 — Localização). Português (original) ou English.
##
## Opção salva em `GameManager.settings["locale"]`:
##   ""      → automático: idioma do sistema (pt* → Português; qualquer outro → English)
##   "pt_BR" → Português   ·   "en" → English
## `GameManager.apply_settings()` chama `apply()` no boot, no load do save e ao
## mudar a opção. Variável de ambiente `GNOSIS_LANG=en|pt` força o idioma (QA,
## capturas) sem tocar no save.
##
## O texto do jogo continua em português nos dados; a tradução é só na
## exibição (`GnosisTranslation`). Onde o código desenha texto à mão
## (`draw_string`) ou precisa medir o texto traduzido, use `I18n.t(texto)`.

const PT := "pt_BR"
const EN := "en"
const CODES := [PT, EN]
const NAMES := {PT: "Português", EN: "English"}

static var _tr: GnosisTranslation = null
static var _current: String = ""


## Código efetivo para uma opção salva ("" = sistema; env GNOSIS_LANG manda).
static func resolve(setting: String) -> String:
	var env := OS.get_environment("GNOSIS_LANG").strip_edges().to_lower()
	if env.begins_with("en"):
		return EN
	if env.begins_with("pt"):
		return PT
	if setting == PT or setting == EN:
		return setting
	return detect_system()


## Idioma do sistema: português → pt_BR; qualquer outro → en.
static func detect_system() -> String:
	return PT if OS.get_locale_language().to_lower() == "pt" else EN


## Aplica o idioma (registra a tradução na 1ª vez). Seguro de chamar sempre.
static func apply(setting: String) -> void:
	var code := resolve(setting)
	if _tr == null:
		_tr = GnosisTranslation.new()
		TranslationServer.add_translation(_tr)
	_tr.active = code == EN
	_current = code
	if TranslationServer.get_locale() != code:
		TranslationServer.set_locale(code)


## Idioma efetivo agora ("pt_BR" ou "en").
static func current() -> String:
	return _current if _current != "" else PT


static func is_en() -> bool:
	return current() == EN


## Traduz um texto (para `draw_string`, medidas e funções `static`).
static func t(text: String) -> String:
	if text.is_empty() or not is_en():
		return text
	return String(TranslationServer.translate(text))


## Nome do idioma para a opção ("Português" / "English").
static func name_of(code: String) -> String:
	return String(NAMES.get(code, code))
