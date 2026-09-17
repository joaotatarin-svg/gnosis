extends Node
## GNOSE — o sistema que ENSINA o gnosticismo ao jogador (estilo God of War /
## Mímir): Estelas de lore espalhadas pelas telas, conversa de caminhada
## (legendas sem pausar o jogo) e o caderno "Crônicas" (entradas desbloqueadas,
## persistem entre runs). Autoload `Gnosis`.
##
## CONTRATO com o Level (scripts/levels/level.gd chama estes três métodos):
##  - setup_screen(level, screen, rest_points): no fim do _ready do Level, antes
##    das waves. `rest_points` = posições no mundo (pés no chão, y ≈ 298) dos
##    descansos entre zonas de combate, da esquerda pra direita. Aqui entram as
##    Estelas e gatilhos da tela.
##  - zone_started(screen, zone, total): waves de uma zona nasceram.
##  - zone_cleared(screen, zone, total): a zona foi limpa (zone == total-1 =
##    tela limpa). Hora da conversa de caminhada.
## (Esqueleto: o conteúdo é preenchido pela sessão de narrativa.)


func setup_screen(_level: Node2D, _screen: int, _rest_points: Array) -> void:
	pass


func zone_started(_screen: int, _zone: int, _total: int) -> void:
	pass


func zone_cleared(_screen: int, _zone: int, _total: int) -> void:
	pass
