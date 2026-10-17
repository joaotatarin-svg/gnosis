class_name GnosisTranslation
extends Translation
## Tradução inglesa do GNOSIS (Onda 4 — Localização).
##
## A chave é o PRÓPRIO texto em português (estilo gettext — ver
## `assets/i18n/PLANO.md` §2): o dado do jogo continua em pt (a lógica que
## compara texto não quebra) e só a exibição troca. Por isso Label/Button/
## RichTextLabel com texto literal traduzem sozinhos (tradução automática do
## Godot), sem mudar uma linha nas telas.
##
## O que esta classe acrescenta ao `Translation` comum (para o texto MONTADO
## por código, que nunca bate com uma chave exata):
##   1. FORMATOS: cada chave com `%s/%d` vira um padrão. "Fome · Chegada" casa
##      com "%s · Chegada" → os pedaços %s são traduzidos (recursivo) e entram
##      no formato inglês "%s · Arrival" → "Hunger · Arrival".
##   2. CAIXA ALTA: "ESTELA  ·  FOME" (código faz `to_upper()` depois de montar)
##      acha a chave pela forma maiúscula e devolve o inglês em maiúsculas.
##   3. Espaços nas pontas e textos de várias linhas ("a\nb" → cada linha).
##
## Tabela gerada por `tools/i18n/build.py` em `scripts/i18n/en_table.gd`
## (fonte: `assets/i18n/en/*.tsv`). Só responde com o inglês ATIVO
## (`active`): o Godot cai no idioma de reserva ("en") quando o pt não tem
## tradução, e sem esta trava o jogo em português sairia em inglês.

const TABLE := preload("res://scripts/i18n/en_table.gd")
const MAX_DEPTH := 3
const CACHE_MAX := 6000

## Liga/desliga a resposta (o I18n liga ao escolher English).
var active: bool = false

var _exact: Dictionary = {}       # pt → en
var _upper: Dictionary = {}       # PT MAIÚSCULO → EN MAIÚSCULO
var _patterns: Array = []         # [{re, en, kinds, key, letters}]
var _cache: Dictionary = {}


func _init() -> void:
	set_locale("en")
	_exact = TABLE.EXACT
	for k in _exact:
		var ks := String(k)
		var up := ks.to_upper()
		if up != ks and not _upper.has(up):
			_upper[up] = String(_exact[k]).to_upper()
	for k in _exact:
		var ks := String(k)
		if ks.contains("%"):
			_add_pattern(ks, String(_exact[k]), false)
			if ks.to_upper() != ks:
				_add_pattern(ks, String(_exact[k]), true)
	# Mais específico primeiro (mais letras fixas).
	_patterns.sort_custom(func(a, b): return int(a.letters) > int(b.letters))


## Chamado pelo TranslationServer para cada texto exibido.
func _get_message(src_message: StringName, _context: StringName) -> StringName:
	if not active:
		return &""
	var s := String(src_message)
	if s.is_empty():
		return &""
	if _cache.has(s):
		return StringName(_cache[s])
	var out := lookup(s, 0)
	if _cache.size() > CACHE_MAX:
		_cache.clear()
	_cache[s] = out
	return StringName(out)


## Tradução de `s` ou "" se não houver (o Godot então mostra o pt).
func lookup(s: String, depth: int) -> String:
	if _exact.has(s):
		return String(_exact[s])
	if depth > MAX_DEPTH:
		return ""
	# espaços nas pontas: traduz o miolo
	var core := s.strip_edges()
	if core.is_empty():
		return ""
	if core != s:
		var c := lookup(core, depth + 1)
		if c != "":
			var lead := s.substr(0, s.find(core))
			return lead + c + s.substr(lead.length() + core.length())
		return ""
	if s == s.to_upper() and _upper.has(s):
		return String(_upper[s])
	var p := _match_pattern(s, depth)
	if p != "":
		return p
	# lista "a, b, c" (nomes de golpes juntados pelo código): TODOS precisam traduzir
	if s.contains(", "):
		var items := s.split(", ")
		var ok := true
		for i in items.size():
			var t := lookup(items[i], depth + 1)
			if t == "":
				ok = false
				break
			items[i] = t
		if ok:
			return ", ".join(items)
	# várias linhas: cada linha por si (pelo menos uma precisa traduzir)
	if s.contains("\n"):
		var parts := s.split("\n")
		var any := false
		for i in parts.size():
			var t := lookup(parts[i], depth + 1) if parts[i].strip_edges() != "" else ""
			if t != "":
				parts[i] = t
				any = true
		if any:
			return "\n".join(parts)
	return ""


func _match_pattern(s: String, depth: int) -> String:
	var is_up := s == s.to_upper()
	for p in _patterns:
		if bool(p.upper) and not is_up:
			continue
		if String(p.key) != "" and not s.contains(String(p.key)):
			continue
		var m: RegExMatch = (p.re as RegEx).search(s)
		if m == null:
			continue
		var kinds: Array = p.kinds
		var args: Array = []
		var changed := false
		for i in kinds.size():
			var raw := m.get_string(i + 1)
			match String(kinds[i]):
				"d":
					args.append(int(raw))
				"f":
					args.append(float(raw))
				_:
					var t := lookup(raw, depth + 1)
					if t != "":
						changed = true
						args.append(t)
					else:
						args.append(raw)
		# padrão sem letras fixas ("%s  ·  %s") só vale se traduziu algum pedaço
		if int(p.letters) == 0 and not changed:
			continue
		var en := String(p.en)
		var out := en % args if not args.is_empty() else en
		return out.to_upper() if bool(p.upper) else out
	return ""


## Converte "Crônica %d/%d" em regex ancorada e guarda os tipos dos %.
func _add_pattern(pt: String, en: String, upper: bool) -> void:
	var src := pt.to_upper() if upper else pt
	var rx := "^"
	var kinds: Array = []
	var literal := ""
	var longest := ""
	var i := 0
	while i < src.length():
		var ch := src[i]
		if ch == "%" and i + 1 < src.length():
			if src[i + 1] == "%":
				rx += "%"
				literal += "%"
				i += 2
				continue
			# %[-+0-9.]*[sdfSDF]
			var j := i + 1
			while j < src.length() and "-+0123456789.".contains(src[j]):
				j += 1
			if j < src.length():
				var k := src[j].to_lower()
				if k in ["s", "d", "f"]:
					if literal.length() > longest.length():
						longest = literal
					literal = ""
					kinds.append(k)
					match k:
						"d":
							rx += "([-+]?\\d+)"
						"f":
							rx += "([-+]?[0-9.]+)"
						_:
							rx += "(.+?)"
					i = j + 1
					continue
		rx += _rx_escape(ch)
		literal += ch
		i += 1
	if literal.length() > longest.length():
		longest = literal
	rx += "$"
	if kinds.is_empty():
		return
	var re := RegEx.new()
	if re.compile("(?s)" + rx) != OK:
		return
	var letters := 0
	for c in src:
		if c.to_lower() != c.to_upper():
			letters += 1
	# padrão só de separadores de espaço ("%s %s") é genérico demais
	# ("%02d  %s" vale: o número ancora; o pedaço %s ainda precisa traduzir)
	if letters == 0 and longest.strip_edges() == "" and not kinds.has("d"):
		return
	var en_up := en
	if upper:
		en_up = _upper_keep_specs(en)
	_patterns.append({"re": re, "en": en_up, "kinds": kinds, "key": longest.strip_edges(), "letters": letters, "upper": upper})


static func _rx_escape(ch: String) -> String:
	if "\\^$.|?*+()[]{}".contains(ch):
		return "\\" + ch
	return ch


## Maiúsculas no texto, mas os especificadores (%s, %d) continuam minúsculos.
static func _upper_keep_specs(s: String) -> String:
	var out := ""
	var i := 0
	while i < s.length():
		if s[i] == "%" and i + 1 < s.length():
			if s[i + 1] == "%":
				out += "%%"
				i += 2
				continue
			var j := i + 1
			while j < s.length() and "-+0123456789.".contains(s[j]):
				j += 1
			out += s.substr(i, j - i + 1)
			i = j + 1
			continue
		out += s[i].to_upper()
		i += 1
	return out
