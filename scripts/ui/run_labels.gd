class_name RunLabels
## Rótulos do run que o HUD e a pausa mostram iguais (Onda 6, UI):
##   · role_title(tela): "Fome · Arena" — o TIPO do nó do mapa (mapa6) quando a
##     tela não é uma Travessia comum; senão o título de sempre do GameManager.
##   · relic_name()/relic_color(): a relíquia em uso (progressao6).
##   · objective_text(tipo): o objetivo da zona (level6) em poucas palavras.
## Tudo devolve texto JÁ no idioma ativo quando monta frases (I18n.t por peça).

## Tipos de nó que ganham nome próprio no título (o resto segue GameManager).
const NODE_KINDS := ["hazard", "platform", "sanctuary", "challenge", "secret", "hidden"]   # "hidden": mapa7


## Título da tela: "Torpor · Escalada", "Fome · Travessia II", "Limiar — O Rei".
static func role_title(screen: int) -> String:
	if CodexSession.active:
		return "Provação"
	var kind := ""
	if RunManager.has_method("node_kind"):
		kind = String(RunManager.call("node_kind", screen))
	if kind in NODE_KINDS and RunManager.has_method("node_title"):
		var eon := RunManager.eon_name(screen)
		var nt := String(RunManager.call("node_title", screen))
		if eon != "" and nt != "":
			return "%s · %s" % [I18n.t(eon), I18n.t(nt)]
	return GameManager.screen_title(screen)


## Id da relíquia em uso ("" = nenhuma ou loja sem relíquias).
static func relic_id() -> String:
	if not Progression.has_method("equipped_relic"):
		return ""
	return String(Progression.call("equipped_relic"))


static func relic_data(id: String) -> Dictionary:
	if id == "" or not Progression.has_method("relic_data"):
		return {}
	return Progression.call("relic_data", id)


## Linha da pausa: "Relíquia em uso · Brasa Viva" ("" sem relíquia).
static func relic_line() -> String:
	var r := relic_data(relic_id())
	if r.is_empty():
		return ""
	return "%s · %s" % [I18n.t("Relíquia em uso"), I18n.t(String(r.get("name", "")))]


## Objetivo da zona em poucas palavras ("" = só ondas / nenhum).
static func objective_text(kind: String) -> String:
	match kind:
		"totem":
			return "quebre o totem"
		"proteger":
			return "proteja a luz"
		"mare", "maré", "fuga", "fugir":
			return "fuja da maré"
	return ""
