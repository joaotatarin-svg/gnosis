class_name AchievementData
extends RefCounted
## LISTA das conquistas do GNOSIS (backlog #49). Só dados — quem desbloqueia é
## o autoload `Achievements` (scripts/autoload/achievements.gd).
##
## Regras (NEURO §3 / backlog #49): nada de sorte e nada de "volte amanhã" —
## toda conquista sai de algo que o jogador FEZ. Texto no registro de SISTEMA
## (imperativo de "você", "para"; ver docs/ESTILO_TEXTO.md).
##
## Campos: id (estável — vira o "API name" da Steam em maiúsculas) · title ·
## desc · hidden (spoiler: a Steam mostra "Conquista oculta" até liberar).
## NÃO mude um id depois de publicado na Steam (o progresso dos jogadores se
## perde); para aposentar, deixe de liberar.

const LIST: Array = [
	{"id": "rei", "title": "O primeiro grilhão", "desc": "Vença o Rei no Limiar.", "hidden": false},
	{"id": "athoth", "title": "Acordada", "desc": "Vença Athoth, o Arconte do Torpor.", "hidden": false},
	{"id": "harmas", "title": "Sem fome", "desc": "Vença Harmas, o Arconte da Fome.", "hidden": false},
	{"id": "galila", "title": "Elo partido", "desc": "Vença Galila, o Arconte da Corrente.", "hidden": false},
	{"id": "yabel", "title": "A palavra de volta", "desc": "Vença Yabel, o Arconte do Silêncio.", "hidden": false},
	{"id": "astaphaios", "title": "Sem reflexo", "desc": "Vença Astaphaios, o Arconte do Espelho.", "hidden": false},
	{"id": "belias", "title": "Febre vencida", "desc": "Vença Belias, o Arconte da Praga.", "hidden": false},
	{"id": "armupiel", "title": "Coroa no chão", "desc": "Vença Armupiel, o Arconte da Coroa.", "hidden": false},
	{"id": "passo_firme", "title": "Passo firme", "desc": "Vença Athoth sem cair nenhuma vez na jornada.", "hidden": false},
	{"id": "intocada", "title": "Intocada", "desc": "Vença um Arconte sem levar dano na tela dele.", "hidden": false},
	{"id": "arma_maxima", "title": "Lâmina inteira", "desc": "Leve a arma ao nível máximo.", "hidden": false},
	{"id": "adormecidos", "title": "Quatro despertos", "desc": "Desperte 4 Adormecidos numa mesma jornada.", "hidden": false},
	{"id": "primeira_estela", "title": "A pedra fala", "desc": "Leia a primeira Estela.", "hidden": false},
	{"id": "cronicas", "title": "Crônicas completas", "desc": "Leia as 18 Estelas.", "hidden": false},
	{"id": "bestiario", "title": "Todos os nomes", "desc": "Encontre todas as criaturas do caminho.", "hidden": false},
	{"id": "memoria", "title": "Memória inteira", "desc": "Recupere os 7 cacos de memória no Centro.", "hidden": true},
	{"id": "ascensao", "title": "Ascensão", "desc": "Chegue ao final Ascensão.", "hidden": true},
	{"id": "ruptura", "title": "Ruptura", "desc": "Chegue ao final Ruptura.", "hidden": true},
	{"id": "semente", "title": "Semente", "desc": "Chegue ao final Semente.", "hidden": true},
	{"id": "tres_portas", "title": "Três portas", "desc": "Veja os 3 finais.", "hidden": true},
	{"id": "caminho_estreito", "title": "Caminho estreito", "desc": "Termine a jornada no Difícil ou acima.", "hidden": true},
]

## Arconte (id no Bestiary) → conquista.
const BOSS_TO_ACH := {
	"rei": "rei",
	"arconte_sono": "athoth",
	"arconte_fome": "harmas",
	"arconte_corrente": "galila",
	"arconte_silencio": "yabel",
	"arconte_espelho": "astaphaios",
	"arconte_praga": "belias",
	"arconte_coroa": "armupiel",
}

## Final (RunManager.endings_seen) → conquista.
const ENDINGS := ["ascensao", "ruptura", "semente"]

## Adormecidos que liberam o Semente (Narrative.final_choices) = a conquista.
const SLEEPERS_GOAL := 4


static func ids() -> Array[String]:
	var out: Array[String] = []
	for a in LIST:
		out.append(String(a.id))
	return out


static func find(id: String) -> Dictionary:
	for a in LIST:
		if String(a.id) == id:
			return a
	return {}


## Nome de API para a Steam (quando houver integração): "ACH_" + id maiúsculo.
static func steam_api_name(id: String) -> String:
	return "ACH_" + id.to_upper()
