class_name PauseStack
extends RefCounted
## Pilha de pausa (REVISAO.md #10): cada tela que pausa o mundo (diálogo, loja,
## pausa, Estela, cinemática, escolha) "empilha" um dono; o mundo só despausa
## quando o ÚLTIMO dono sair. Ninguém mais escreve `get_tree().paused` direto.
## Uso:  PauseStack.push(self)  ...  PauseStack.pop(self)
## O mesmo dono empilhado duas vezes conta uma vez só (idempotente).

static var _owners: Array[int] = []


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Pausa o mundo em nome de `owner`.
static func push(owner: Object) -> void:
	_prune()
	var id: int = owner.get_instance_id()
	if not _owners.has(id):
		_owners.append(id)
	var t: SceneTree = _tree()
	if t != null:
		t.paused = true


## `owner` larga a pausa; despausa se ninguém mais segura.
static func pop(owner: Object) -> void:
	_owners.erase(owner.get_instance_id())
	_prune()
	var t: SceneTree = _tree()
	if t != null and _owners.is_empty():
		t.paused = false


## Alguém (ainda vivo) segura a pausa?
static func is_held() -> bool:
	_prune()
	return not _owners.is_empty()


## Quem segura (para depuração/QA).
static func count() -> int:
	_prune()
	return _owners.size()


## Troca de cena / volta ao menu: zera tudo e despausa.
static func clear() -> void:
	_owners.clear()
	var t: SceneTree = _tree()
	if t != null:
		t.paused = false


## Donos liberados sem `pop` (nó apagado com a cena) não seguram a pausa para sempre.
static func _prune() -> void:
	for i in range(_owners.size() - 1, -1, -1):
		if not is_instance_id_valid(_owners[i]):
			_owners.remove_at(i)
