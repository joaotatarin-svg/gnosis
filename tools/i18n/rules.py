"""Regras do extrator (tools/i18n/extract.py): o que é texto, que tipo de lugar
ocupa e qual o limite de caracteres. Limites de docs/ESTILO_TEXTO.md §5."""
from __future__ import annotations

import re

# Funções cujo argumento string (1º, ou o que estiver aberto) é id/chave, não texto.
ID_FUNCS = {
	"play_sfx", "play_sfx_pitched", "play_music", "play_ui", "play", "load", "preload",
	"get_node", "get_node_or_null", "has_node", "find_child", "has", "has_method", "has_signal",
	"call", "call_deferred", "connect", "emit_signal", "disconnect", "is_connected",
	"set_meta", "get_meta", "has_meta", "is_action_pressed", "is_action_just_pressed",
	"is_action_just_released", "is_action_released", "get_action_strength", "get_axis", "get_vector",
	"action_add_event", "action_erase_events", "has_action", "add_action", "events_get",
	"add_theme_color_override", "add_theme_font_size_override", "add_theme_constant_override",
	"add_theme_stylebox_override", "add_theme_font_override", "add_theme_icon_override",
	"get_theme_color", "get_theme_font", "get_theme_stylebox", "get_theme_constant",
	"set", "get", "erase", "unlock", "is_unlocked", "once", "get_type", "get_character",
	"tween_property", "tween_method", "set_value", "get_value", "has_section_key", "get_setting",
	"set_setting", "has_setting", "get_texture", "get_frame", "piece", "sheet", "region",
	"sprite", "tex", "rect", "is_in_group", "add_to_group", "get_nodes_in_group",
	"get_first_node_in_group", "call_group", "_move", "_skill", "_c_cue", "push_warning",
	"push_error", "print", "printerr", "print_debug", "assert", "boss_card_id", "change_scene",
	"goto", "go", "go_to", "change_scene_to_file", "file_exists", "open", "dir_exists",
	"entry", "stela_for", "is_boss_id", "eon_bot", "_tex", "_piece", "_sheet", "_png",
	"split", "begins_with", "ends_with", "contains", "find", "replace", "trim_prefix", "trim_suffix",
	"join", "get_slice", "set_shader_parameter", "get_shader_parameter", "OS", "has_feature",
	"get_cmdline_args", "start", "stop", "seek", "travel", "has_animation", "animation_play",
}

# Índices de argumento que são id (o padrão das funções acima é só o 1º).
ID_ARGS = {
	"call_group": {0, 1}, "_move": {0}, "_skill": {0, 6}, "tween_property": {0, 1},
	"connect": {0, 1}, "set": {0}, "get": {0}, "call": {0}, "set_meta": {0}, "emit_signal": {0},
	"replace": {0, 1, 2}, "split": {0, 1}, "join": {0}, "has": {0, 1},
	"add_theme_color_override": {0}, "add_theme_font_size_override": {0},
	"add_theme_constant_override": {0}, "add_theme_stylebox_override": {0},
	"add_theme_font_override": {0}, "add_theme_icon_override": {0},
}


def is_id_arg(fn: str, idx: int) -> bool:
	if fn not in ID_FUNCS:
		return False
	return idx in ID_ARGS.get(fn, {0})


# Strings visíveis só para o desenvolvedor (avisos, nomes técnicos).
NOT_TEXT = {
	"Master", "Music", "SFX", "UI", "Voice", "Ambience", "Reverb", "LowPass",
	"Godot", "GNOSIS-WT", "Windows", "Linux", "macOS", "Web", "Mac OS X", "platform:",
	"Collision", "FinalBattle", "ArenaSet", "Label", "Button", "Panel", "HSlider", "HSeparator",
	"Value", "Back", "Menu", "Title",
}

_DIALOG_FUNCS = ("_l(", "_c(", "line(", "_say(")


def forced(l):
	"""True/False força a decisão; None deixa a heurística decidir."""
	f = l.file
	b = l.before
	# ordinais da Narrative entram no texto ("o sétimo Anel").
	if l.scope == "ORDINAIS":
		return True
	# o código de dev/QA e avisos de console nunca chegam ao jogador
	if re.search(r"\b(push_warning|push_error|printerr|print|print_debug|assert)\s*\(", b):
		return False
	# caminhos de arte e de cena
	if "res://" in l.text:
		return False
	# fontes de texto: argumento 2 de _l/_c é sempre texto; argumento 3 de _c é cue
	if re.search(r"\b_c\([^()]*,[^()]*,\s*$", b):
		return False
	if f.endswith("audio_manager.gd") or f.endswith("fps_overlay.gd") or f.endswith("scene_manager.gd"):
		return False
	if f.endswith("painted_library.gd") or f.endswith("scenery_library.gd") or f.endswith("vfx_library.gd"):
		return False
	if f.endswith("boss_puppet.gd") or f.endswith("character_art.gd") or f.endswith("art_profile.gd"):
		return False
	return None


def _dict_key(l):
	m = re.search(r'"(\w+)"\s*:\s*\[?\s*$', l.before)
	if m:
		return m.group(1)
	return ""


def classify(l):
	"""(kind, speaker, limite)."""
	f = l.file
	b = l.before
	sp = ""
	m = re.search(r"\b_[lc]\(\s*([A-Z_]+|\"[^\"]*\")\s*,\s*$", b)
	if m:
		tok = m.group(1)
		sp = {"VOZ": "A Voz", "REI": "O Rei", "YAL": "Yaldabaoth", "SOPHIA": "Sophia",
			"NARRADOR": "(narrador)"}.get(tok, tok.strip('"'))
	key = _dict_key(l)
	if f.endswith("gnosis.gd"):
		if l.scope == "STELAS":
			if key == "title":
				return "estela_titulo", "", 60
			if key == "source":
				return "estela_fonte", "", 170
			if key == "hint":
				return "estela_dica", "", 90
			if key == "eon":
				return "eon_nome", "", 18
			return "estela", "", 170
		if l.scope == "BOSS_TITLES" or l.scope == "boss_card":
			if key == "name" or "CAMPE" in l.text:
				return "card_chefe_nome", "", 18
			return "card_chefe_titulo", "", 52
	if f.endswith("narrative.gd"):
		if l.scope == "ORDINAIS":
			return "ordinal", "", 0
		if "walk" in l.scope or "caption" in l.scope:
			return "legenda", sp, 95
		if "card" in l.scope or "epilogue" in l.scope or "prologue" in l.scope:
			return "card_cinema", sp, 240
		if sp:
			return "dialogo", sp, 115
		return "narrativa", sp, 115
	if f.endswith("cinematic.gd"):
		return "card_cinema", sp, 240
	if f.endswith("stela.gd"):
		return "ui_estela", "", 0
	if f.endswith("bestiary.gd"):
		if key in ("name", "display_name"):
			return "nome", "", 24
		return "bestiario", "", 0
	if f.endswith("game_content.gd"):
		return "golpe_magia", "", 0
	if "toast" in b or "toast" in l.scope:
		return "toast", sp, 60
	if sp:
		return "dialogo", sp, 115
	if f.startswith("scenes/"):
		return "ui_cena", "", 0
	return "ui", "", 0


def note_for(text: str) -> str:
	notes = []
	if re.search(r"%[-+0-9.]*[dsfv]", text):
		notes.append("format string: manter os %")
	if "{" in text and "}" in text:
		notes.append("placeholder {}: manter")
	if "[" in text and "]" in text and re.search(r"\[/?\w+", text):
		notes.append("BBCode: manter as tags")
	return "; ".join(notes)
