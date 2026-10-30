extends Node
## FERRAMENTA (não faz parte do jogo): prova o GANCHO das falas do duelo do Rei
## (Narrative.rei_duel*) sem o jogo rodando: um Rei falso recebe os eventos que
## o Chefes6 vai emitir (ou o polling) e a sonda confere condições, intervalo de
## 12 s, orçamento de 6 falas e as variantes da queda. Headless:
##   godot --headless --audio-driver Dummy --path . res://tools/encenacao/ReiDuelProbe.tscn
## Sai com 0 (verde) ou 1.

var fails: int = 0


class FakeRei extends Node:
	var estate: int = 0
	var brain = null
	var type_id: String = "rei"
	var is_boss_enemy: bool = true


func check(ok: bool, what: String) -> void:
	if ok:
		print("REI PASS: ", what)
	else:
		fails += 1
		push_error("REI FAIL: " + what)


func _said(id: String) -> bool:
	return Narrative.seen.has("rei_" + id)


func _at(t: float) -> void:
	Narrative.set("_rei_clock", t)


func _ready() -> void:
	Narrative.reset()
	var rei := FakeRei.new()
	add_child(rei)
	Narrative.rei_duel_attach(rei)
	check(Narrative.rei_duel_active(), "duelo liga ao Rei")

	# C1: depois do 1º Leque, só se ela não aparou nada.
	_at(3.0)
	Narrative.rei_duel("recovered", {"id": "leque"})
	check(_said("C1") and Narrative.rei_duel_spent() == 1, "C1 na recuperação do 1º Leque")
	# C2 cedo demais (intervalo < 12 s): fica para a próxima vez.
	_at(8.0)
	Narrative.rei_duel("recovered", {"id": "raio"})
	check(not _said("C2"), "C2 espera o intervalo de 12 s")
	_at(15.5)
	Narrative.rei_duel("recovered", {"id": "raio"})
	check(_said("C2"), "C2 na recuperação do Raio seguinte")
	# C3 pelo sinal com antecedência: < 1 s não fala; ≥ 1 s fala.
	_at(28.0)
	Narrative.rei_duel("will_start", {"id": "mao", "lead": 0.6})
	check(not _said("C3"), "C3 não fala com < 1 s antes da preparação")
	Narrative.rei_duel("will_start", {"id": "mao", "lead": 1.2})
	check(_said("C3"), "C3 com ≥ 1 s antes da preparação")
	# Degrau 2: 1º ajoelhar não; 2º ajoelhar (com intervalo) sim.
	_at(30.0)
	Narrative.rei_duel("knelt")
	check(not _said("C6a"), "C6a não no 1º ajoelhar")
	_at(41.0)
	Narrative.rei_duel("knelt")
	check(_said("C6a"), "C6a (pergunta) no 2º ajoelhar sem desmentido")
	# Desmentido depois da dica: sem fala (o carimbo/HUD do Chefes6 basta).
	_at(42.0)
	Narrative.rei_duel("lie_exposed")
	check(Narrative.rei_exposed and not _said("C6b"), "Desmentido marca a mentira; C6b muda porque a C6a já tocou")
	# Fases: fixas, esperam o intervalo e entram no orçamento.
	_at(44.0)
	Narrative.archon_phase2("rei")
	check(_said("C4") and Narrative.rei_duel_spent() == 5, "C4 (fase 2) reservada mesmo dentro do intervalo")
	_at(47.0)
	Narrative.archon_phase3("rei")
	check(_said("C5") and Narrative.rei_duel_spent() == 6, "C5 (fase 3) reservada; orçamento = 6")
	Narrative.rei_duel("recovered", {"id": "leque"})
	check(Narrative.rei_duel_spent() == 6, "orçamento fechado em 6 falas")
	check(Narrative.archon_phase2("rei").is_empty(), "a fase do Rei não vai para a legenda genérica")

	# Queda: variantes pela mentira.
	var fa: Array = Narrative.king_fall()
	check(String(fa[0].text) == "Aquela reverência de antes? Foi proposital.", "queda com a mentira exposta (F1a)")
	var fb: Array = Narrative.king_fall(0)
	check(String(fb[0].text) == "Nós não estamos ajoelhados. Estamos... descansando.", "queda sem desmentido (F1b)")
	check(fa.size() == 11 and fb.size() == 11, "queda com 11 falas por partida (≤ 12, marco)")

	# Sem aparar: um novo run com aparo ANTES do 1º Leque não fala C1.
	Narrative.reset()
	Narrative.rei_duel_attach(rei)
	_at(2.0)
	Narrative.rei_duel("parried")
	Narrative.rei_duel("recovered", {"id": "leque"})
	check(not _said("C1"), "C1 calada se ela já aparou")
	# O desmentido sem a dica antes: C6b fala.
	_at(20.0)
	Narrative.rei_duel("lie_exposed")
	check(_said("C6b"), "C6b (a acusação) quando a dica não tocou")

	# Textos de cena (contagem da amostra).
	check(Narrative.king_intro().size() == 10, "Cena A: 10 falas (névoa + Rei)")
	check(Narrative.walk_arrival(1).size() == 4, "caminhada do Limiar: 4 legendas")
	check(Narrative.eon_intro(0).size() == 4, "Torpor: 4 legendas")
	Narrative.rei_duel_detach()
	Narrative.reset()
	print("REI PROBE: %d falhas" % fails)
	get_tree().quit(1 if fails > 0 else 0)
