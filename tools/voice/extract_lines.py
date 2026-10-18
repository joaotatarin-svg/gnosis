"""Extrai TODAS as falas dubláveis do jogo para um roteiro de dublagem (JSON).

Fontes (somente leitura):
  - scripts/autoload/narrative.gd  → _l(...) / _c(...) / _m(_l(...), M_X) e epilogue_cards
  - scripts/fx/cinematic.gd        → cards do prólogo (Narrador)
  - scripts/autoload/gnosis.gd     → linhas das Estelas
  - scripts/i18n/en_table.gd       → tradução EN (chave = texto PT exato)

Cada fala ganha um ID ESTÁVEL = sha1("falante|texto_pt")[:12]. O jogo calcula o
mesmo id em GDScript: (speaker + "|" + text).sha1_text().left(12) — assim a
DialogueBox acha o áudio sem tabela extra (ver docs/onda2/DUBLAGEM.md §7).

Uso:
  python tools/voice/extract_lines.py [--root <worktree>] [--out <roteiro.json>]
Sem --out, grava em tools/voice/out/roteiro.json (fora do git).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

# Constantes de falante usadas em narrative.gd (const VOZ := "A Voz" ...).
STR = r'"((?:[^"\\]|\\.)*)"'
RE_CONST = re.compile(r'^const\s+([A-Z_]+)\s*:?=\s*' + STR, re.M)
RE_FUNC = re.compile(r'^(?:static\s+)?func\s+(\w+)', re.M)
# _l(SPK, "texto") ou _c(SPK, "texto", "cue"); SPK = constante ou string.
RE_LINE = re.compile(
	r'_(l|c)\(\s*(?:([A-Z_]+)|' + STR + r')\s*,\s*' + STR + r'(?:\s*,\s*' + STR + r')?\s*\)'
	r'(?:\s*,\s*(M_[A-Z_]+)\s*\))?'
)
RE_KV = re.compile(r'^\s*' + STR + r'\s*:\s*' + STR + r'\s*,?\s*$', re.M)

NARRADOR = "Narrador"


def unescape(s: str) -> str:
	return s.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8") if "\\" in s else s


def line_id(speaker: str, text: str) -> str:
	return hashlib.sha1((speaker + "|" + text).encode("utf-8")).hexdigest()[:12]


def func_at(src: str, pos: int) -> str:
	name = ""
	for m in RE_FUNC.finditer(src):
		if m.start() > pos:
			break
		name = m.group(1)
	return name


# --- preparação do texto para a fala -----------------------------------------
RE_LEAD_RUBRIC = re.compile(r'^\(([^)]*)\)\s*(.*)$', re.S)
RE_CAPS = re.compile(r'\b([A-ZÁÉÍÓÚÂÊÔÃÕÇ]{2,})\b')


def speech_text(speaker: str, text: str) -> tuple[str, str]:
	"""Devolve (texto_falado, modo). modo: fala | pensamento | narracao | rubrica.

	- "(rubrica) fala"     → só a fala (a rubrica é ação visível, não se diz)
	- "(Pensamento.)" da Sophia (maiúscula, frase inteira) → pensamento
	- rubrica inteira do Narrador ("") → narração do conteúdo
	- rubrica inteira de outro falante (Yabel mudo) → rubrica (NÃO dublar)
	"""
	t = text.replace("\n", " ").strip()
	modo = "fala"
	m = RE_LEAD_RUBRIC.match(t)
	if m:
		inner, rest = m.group(1).strip(), m.group(2).strip()
		if rest:
			t = rest
		elif speaker == NARRADOR:
			t, modo = inner, "narracao"
		elif speaker == "Sophia" and inner[:1].isupper():
			t, modo = inner, "pensamento"
		else:
			return "", "rubrica"
	elif speaker in (NARRADOR, "Estela"):
		modo = "narracao"
	# Aspas curvas e travessão: o TTS lê melhor com vírgula/pausa.
	t = t.replace("“", "").replace("”", "").replace("‘", "").replace("’", "'")
	t = t.replace(" — ", ", ")
	# CAIXA ALTA (grito): vira palavra normal; a ênfase vai pelo mood "grito".
	if RE_CAPS.search(t):
		t = RE_CAPS.sub(lambda mm: mm.group(1).capitalize(), t)
	return t.strip(), modo


def load_en(root: Path) -> dict:
	src = (root / "scripts/i18n/en_table.gd").read_text(encoding="utf-8")
	return {unescape(k): unescape(v) for k, v in RE_KV.findall(src)}


def extract(root: Path) -> list[dict]:
	out: list[dict] = []
	seen: set[str] = set()

	def add(speaker: str, text: str, mood: str, source: str, cue: str = ""):
		lid = line_id(speaker, text)
		if lid in seen:
			return
		seen.add(lid)
		dyn = "%" in text
		said, modo = speech_text(speaker, text)
		out.append({
			"id": lid, "speaker": speaker, "mood": mood, "cue": cue,
			"source": source, "text_pt": text, "said_pt": said, "mode": modo,
			"dynamic": dyn,
		})

	# 1) narrative.gd
	p = root / "scripts/autoload/narrative.gd"
	src = p.read_text(encoding="utf-8")
	consts = {k: unescape(v) for k, v in RE_CONST.findall(src)}
	for m in RE_LINE.finditer(src):
		kind, spk_const, spk_lit, text, cue, mood_const = m.groups()
		speaker = consts.get(spk_const, spk_const) if spk_const else unescape(spk_lit)
		if speaker == "":
			speaker = NARRADOR
		mood = consts.get(mood_const, "") if mood_const else ""
		add(speaker, unescape(text), mood, "narrative.%s" % func_at(src, m.start()), unescape(cue or ""))
	# epilogue_cards: strings soltas dentro da função
	ep = src[src.find("func epilogue_cards"):]
	for s in re.findall(r'^\s*(?:var r := \[\s*)?' + STR + r'\s*,?\s*$', ep, re.M):
		add(NARRADOR, unescape(s), "", "narrative.epilogue_cards")
	for s in re.findall(r'r\.append\(' + STR + r'\)', ep):
		add(NARRADOR, unescape(s), "", "narrative.epilogue_cards")

	# 2) prólogo (cinematic.gd)
	c = (root / "scripts/fx/cinematic.gd").read_text(encoding="utf-8")
	pro = c[c.find("static func prologue"):c.find("static func boss_card")]
	for s in re.findall(r'"text"\s*:\s*' + STR, pro):
		add(NARRADOR, unescape(s), "", "cinematic.prologue")

	# 3) Estelas (gnosis.gd)
	g = (root / "scripts/autoload/gnosis.gd").read_text(encoding="utf-8")
	blk = g[g.find("const STELAS"):]
	for sm in re.finditer(r'\{"id"\s*:\s*' + STR + r'.*?"lines"\s*:\s*\[(.*?)\]', blk, re.S):
		sid = sm.group(1)
		for s in re.findall(STR, sm.group(2)):
			add("Estela", unescape(s), "", "gnosis.stela.%s" % sid)

	# Tradução EN
	en = load_en(root)
	for ln in out:
		ten = en.get(ln["text_pt"], "")
		ln["text_en"] = ten
		ln["said_en"] = speech_text(ln["speaker"], ten)[0] if ten else ""
	return out


def main() -> int:
	sys.stdout.reconfigure(encoding="utf-8")
	ap = argparse.ArgumentParser()
	ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
	ap.add_argument("--out", default="")
	a = ap.parse_args()
	root = Path(a.root)
	lines = extract(root)
	out = Path(a.out) if a.out else Path(__file__).resolve().parent / "out" / "roteiro.json"
	out.parent.mkdir(parents=True, exist_ok=True)
	out.write_text(json.dumps(lines, ensure_ascii=False, indent=1), encoding="utf-8")
	# Resumo por falante
	from collections import Counter
	cnt = Counter(l["speaker"] for l in lines if l["mode"] != "rubrica" and not l["dynamic"])
	sem_en = sum(1 for l in lines if not l["text_en"])
	print("falas: %d (dubláveis %d; dinâmicas %d; rubricas %d; sem EN %d) → %s" % (
		len(lines), sum(cnt.values()), sum(l["dynamic"] for l in lines),
		sum(l["mode"] == "rubrica" for l in lines), sem_en, out))
	for k, v in cnt.most_common():
		print("  %-20s %d" % (k, v))
	return 0


if __name__ == "__main__":
	sys.exit(main())
