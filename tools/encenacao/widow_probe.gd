extends Node
## FERRAMENTA (não faz parte do jogo): mede as "viúvas" (palavra sozinha na última
## linha) dos cards de epílogo em PT e EN, na largura cheia (antes) e na largura
## EQUILIBRADA que a Cinemática usa agora (depois). Headless:
##   godot --headless --path . res://tools/encenacao/WidowProbe.tscn

const W := 470.0
const FS := 13


func _ready() -> void:
	var font: Font = CodexStyle.serif()
	var total_before := 0
	var total_after := 0
	for which in ["ascensao", "ruptura", "semente"]:
		for pt in Narrative.epilogue_cards(which):
			for lang in ["pt", "en"]:
				var t: String = String(pt) if lang == "pt" else I18n_en(String(pt))
				var b := _last_words(font, t, W)
				var w := _balanced(font, t)
				var a := _last_words(font, t, w)
				if b <= 1:
					total_before += 1
				if a <= 1:
					total_after += 1
				print("VIUVA|%s|%s|antes=%d palavra(s)|depois=%d (larg %d)|%s" % [which, lang, b, a, int(w), t.left(40)])
	print("VIUVA|RESULT|antes=%d viúvas|depois=%d viúvas" % [total_before, total_after])
	get_tree().quit()


func I18n_en(pt: String) -> String:
	var tbl = load("res://scripts/i18n/en_table.gd")
	var d: Dictionary = tbl.EXACT if tbl != null else {}
	return String(d.get(pt, pt))


func _para(font: Font, t: String, width: float) -> TextParagraph:
	var p := TextParagraph.new()
	p.add_string(t, font, FS)
	p.width = width
	p.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	return p


func _lines(font: Font, t: String, width: float) -> int:
	return _para(font, t, width).get_line_count()


func _last_words(font: Font, t: String, width: float) -> int:
	var p := _para(font, t, width)
	var r: Vector2i = p.get_line_range(p.get_line_count() - 1)
	return t.substr(r.x, r.y - r.x).strip_edges().split(" ", false).size()


## A mesma conta da cinematic._balance_text (via TextParagraph).
func _balanced(font: Font, t: String) -> float:
	var n := _lines(font, t, W)
	if n < 2:
		return W
	var lo := W * 0.45
	var hi := W
	for _k in 10:
		var mid := (lo + hi) * 0.5
		if _lines(font, t, mid) <= n:
			hi = mid
		else:
			lo = mid
	return minf(W, hi + 8.0)
