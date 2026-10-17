extends "res://tools/perf_probe.gd"
## SONDA QA-VISUAL (não faz parte do jogo): roda a PerfProbe do Técnico SEM
## mudar nada nela e acrescenta um "espião" que mede TODOS os frames desde o
## carregamento (inclusive o aquecimento e o 1º golpe) e imprime cada engasgo:
##   SPIKE|t=<s desde o início>|frame=<n>|ms=<duração>|fase=<carga|aquece|mede>
## No fim: SPIKES|total=<n>|>50ms=<n>|>100ms=<n>|pior=<ms>@<s>
## Uso: igual à PerfProbe, trocando a cena por res://tools/qa_visual/PerfTimeline.tscn

const LIMIAR_MS := 33.4   # acima de 2 quadros a 60 qps


func _ready() -> void:
	super()
	get_tree().root.add_child.call_deferred(Spy.new())


class Spy extends Node:
	var _t0: int = 0
	var _last: int = 0
	var _n: int = 0
	var _count: int = 0
	var _c50: int = 0
	var _c100: int = 0
	var _worst: float = 0.0
	var _worst_t: float = 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_t0 = Time.get_ticks_usec()
		_last = _t0

	func _fase() -> String:
		for c in get_tree().root.get_children():
			if c.get_script() != null and "_measuring" in c:
				if bool(c.get("_measuring")):
					return "mede"
				return "aquece" if int(c.get("_frame")) > 0 else "carga"
		return "?"

	func _process(_delta: float) -> void:
		var now := Time.get_ticks_usec()
		var dt := float(now - _last) / 1000.0
		_last = now
		_n += 1
		if _n > 3 and dt > LIMIAR_MS:
			var t := float(now - _t0) / 1000000.0
			_count += 1
			if dt > 50.0:
				_c50 += 1
			if dt > 100.0:
				_c100 += 1
			if dt > _worst:
				_worst = dt
				_worst_t = t
			print("SPIKE|t=%.2f|frame=%d|ms=%.1f|fase=%s" % [t, _n, dt, _fase()])

	func _exit_tree() -> void:
		print("SPIKES|total=%d|>50ms=%d|>100ms=%d|pior=%.1fms@%.2fs" % [_count, _c50, _c100, _worst, _worst_t])
