#!/usr/bin/env python3
"""GNOSIS — extrator de textos visíveis (i18n).

Varre `scripts/**/*.gd` e `scenes/**/*.tscn`, acha toda string literal que o
jogador pode ler e gera `assets/i18n/strings.csv`, preservando as traduções que
já estão lá (a coluna `en` NUNCA é apagada por uma nova extração).

Uso:  python3 tools/i18n/extract.py            (a partir da raiz do projeto)
      python3 tools/i18n/extract.py --report   (só mostra contagens, não grava)

Colunas do CSV (UTF-8, separador vírgula, aspas padrão do csv do Python):
  id       chave estável para revisão: <arquivo>.<escopo>.<hash6 do texto pt>
           (o escopo é a função ou a constante onde o texto mora; muda só se o
           texto mudar ou mudar de função).
  pt       o texto original, exato (é o msgid em tempo de execução — ver PLANO.md).
  en       a tradução.
  kind     tipo de lugar (dialogo, legenda, estela, card_chefe, card_cinema,
           toast, ui, nome, ...): decide o limite.
  speaker  quem fala (quando a string está numa chamada _l/_c com falante).
  limit    máximo de caracteres recomendado para o inglês (ver ESTILO_TEXTO §5).
  where    arquivo:linha de cada ocorrência (separadas por espaço).
  note     observação para o tradutor/revisor (format strings, gênero...).

O filtro é heurístico (string com cara de texto) + listas em `rules.py`. Toda
string descartada vai para `assets/i18n/_descartadas.txt`, para revisão humana.
"""
from __future__ import annotations

import csv
import hashlib
import re
import sys
sys.dont_write_bytecode = True
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
import rules  # noqa: E402

OUT_CSV = ROOT / "assets" / "i18n" / "strings.csv"
OUT_DROP = ROOT / "assets" / "i18n" / "_descartadas.txt"
FIELDS = ["id", "pt", "en", "kind", "speaker", "limit", "where", "note"]


# --- tokenização de GDScript ---------------------------------------------------

class Lit:
	"""Uma string literal achada no código."""

	def __init__(self, text: str, file: str, line: int, scope: str, before: str, after: str, line_src: str):
		self.text = text
		self.file = file
		self.line = line
		self.scope = scope
		self.before = before      # código da mesma linha antes do literal
		self.after = after        # código da mesma linha depois do literal
		self.line_src = line_src


_ESC = {"n": "\n", "t": "\t", '"': '"', "'": "'", "\\": "\\", "r": "\r"}


def _unescape(s: str) -> str:
	out = []
	i = 0
	while i < len(s):
		c = s[i]
		if c == "\\" and i + 1 < len(s):
			n = s[i + 1]
			if n == "u" and i + 5 < len(s) + 1:
				try:
					out.append(chr(int(s[i + 2:i + 6], 16)))
					i += 6
					continue
				except ValueError:
					pass
			out.append(_ESC.get(n, "\\" + n))
			i += 2
			continue
		out.append(c)
		i += 1
	return "".join(out)


def scan_gd(path: Path) -> list[Lit]:
	src = path.read_text(encoding="utf-8")
	rel = path.relative_to(ROOT).as_posix()
	lines = src.split("\n")
	lits: list[Lit] = []
	scope = "_top"
	i = 0
	n = len(src)
	line_no = 1
	line_start = 0
	while i < n:
		c = src[i]
		if c == "\n":
			line_no += 1
			line_start = i + 1
			# escopo: func / const / var no começo da linha
			rest = src[line_start:line_start + 200]
			m = re.match(r"\s*(?:static\s+)?func\s+(\w+)", rest)   # inclui funções de classe interna
			if m:
				scope = m.group(1)
			else:
				m = re.match(r"(?:const|var)\s+(\w+)", rest)
				if m:
					scope = m.group(1)
			i += 1
			continue
		if c == "#":
			j = src.find("\n", i)
			i = n if j < 0 else j
			continue
		if c in "\"'":
			prefix = src[i - 1] if i > 0 else ""
			triple = src.startswith(c * 3, i)
			q = c * 3 if triple else c
			j = i + len(q)
			buf_start = j
			while j < n:
				if src[j] == "\\":
					j += 2
					continue
				if src.startswith(q, j):
					break
				if not triple and src[j] == "\n":
					break
				j += 1
			raw = src[buf_start:j]
			end = j + len(q)
			lo = line_no
			lsrc = lines[lo - 1] if lo - 1 < len(lines) else ""
			before = src[line_start:i]
			eol = src.find("\n", end)
			after = src[end:(n if eol < 0 else eol)]
			if prefix not in "&^":   # &"StringName" e ^"NodePath" nunca são texto
				lits.append(Lit(_unescape(raw), rel, lo, scope, before, after, lsrc))
			# conta quebras de linha dentro de string tripla
			nl = src.count("\n", i, end)
			if nl:
				line_no += nl
				line_start = src.rfind("\n", i, end) + 1
			i = end
			continue
		i += 1
	return lits


def scan_tscn(path: Path) -> list[Lit]:
	rel = path.relative_to(ROOT).as_posix()
	lits: list[Lit] = []
	node = "_top"
	for no, ln in enumerate(path.read_text(encoding="utf-8").split("\n"), 1):
		m = re.match(r'\[node name="([^"]+)"', ln)
		if m:
			node = m.group(1)
			continue
		m = re.match(r'(text|tooltip_text|placeholder_text|title)\s*=\s*"((?:[^"\\]|\\.)*)"', ln)
		if m:
			lits.append(Lit(_unescape(m.group(2)), rel, no, node, m.group(1) + " = ", "", ln))
	return lits


# --- filtro -------------------------------------------------------------------

def _hash(text: str) -> str:
	return hashlib.sha1(text.encode("utf-8")).hexdigest()[:6]


def open_call(before: str) -> tuple[str, int]:
	"""(função cuja chamada está aberta antes do literal, índice do argumento)."""
	depth = 0
	commas = 0
	for k in range(len(before) - 1, -1, -1):
		ch = before[k]
		if ch in ")]}":
			depth += 1
		elif ch in "[{":
			if depth == 0:
				return "", -1   # dentro de array/dicionário: não é argumento direto
			depth -= 1
		elif ch == "(":
			if depth == 0:
				m = re.search(r"([A-Za-z_][\w.]*)\s*$", before[:k])
				return (m.group(1).split(".")[-1] if m else "", commas)
			depth -= 1
		elif ch == "," and depth == 0:
			commas += 1
	return "", -1


def visible(l: Lit) -> tuple[bool, str]:
	"""(é texto visível?, motivo)."""
	t = l.text
	forced = rules.forced(l)
	if forced is not None:
		return forced, "regra"
	if not re.search(r"[A-Za-zÀ-ÿ]", t):
		return False, "sem letras"
	if l.file.endswith(".tscn"):
		return True, ""   # propriedade text/title de nó: sempre visível
	if t.startswith(("res://", "user://", "uid://")) or re.search(r"\.(png|tscn|gd|ogg|wav|json|tres|svg|import)$", t):
		return False, "caminho"
	# chave de dicionário:  "nome": valor
	if re.match(r"\s*:", l.after) and not re.match(r"\s*:\s*$", l.after):
		return False, "chave de dicionário"
	# primeiro argumento de função que recebe id, não texto
	fn, idx = open_call(l.before)
	if fn and rules.is_id_arg(fn, idx):
		return False, f"argumento-id de {fn} (#{idx})"
	# comparação / match com id
	if re.search(r"(==|!=|\bin\b)\s*$", l.before) or re.match(r"\s*(==|!=)", l.after):
		return False, "comparação"
	if re.match(r"\s*:\s*$", l.after) and re.match(r"\s*$", l.before):
		return False, "padrão de match"
	# identificador puro ASCII (ids, ações de input, nomes de nó, chaves)
	if re.fullmatch(r"[a-z0-9_\-./%]+", t):
		return False, "identificador"
	if re.fullmatch(r"[A-Za-z]+(_[A-Za-z0-9]+)+", t) or re.fullmatch(r"[a-z]+[A-Z]\w*", t):
		return False, "identificador"
	if re.fullmatch(r"[A-Z][A-Za-z0-9]*(Container|Label|Button|Panel|Box|Rect|Bar|Node2D|Node)\d*", t):
		return False, "nome de nó"
	if re.fullmatch(r"[A-Z][A-Za-z0-9]+(/[A-Z][A-Za-z0-9]+)+", t):
		return False, "caminho de nó"
	if t in rules.NOT_TEXT:
		return False, "lista NOT_TEXT"
	if re.fullmatch(r"%[-+0-9.]*[dsf]", t.strip()):
		return False, "só formato"
	return True, ""


def classify(l: Lit) -> tuple[str, str, int]:
	"""(kind, speaker, limite)."""
	return rules.classify(l)


# --- saída --------------------------------------------------------------------

def load_existing() -> dict[str, dict]:
	if not OUT_CSV.exists():
		return {}
	with OUT_CSV.open(encoding="utf-8", newline="") as f:
		return {r["pt"]: r for r in csv.DictReader(f)}


def main() -> int:
	report_only = "--report" in sys.argv
	lits: list[Lit] = []
	for p in sorted((ROOT / "scripts").rglob("*.gd")):
		if p.parent.name == "i18n":
			continue   # a própria tabela gerada (en_table.gd) e o tradutor
		lits += scan_gd(p)
	for p in sorted((ROOT / "scenes").rglob("*.tscn")):
		lits += scan_tscn(p)

	kept: dict[str, dict] = {}
	order: list[str] = []
	dropped: list[str] = []
	for l in lits:
		ok, why = visible(l)
		if not ok:
			dropped.append(f"{l.file}:{l.line}\t[{why}]\t{l.text!r}")
			continue
		kind, speaker, limit = classify(l)
		where = f"{l.file}:{l.line}"
		if l.text in kept:
			r = kept[l.text]
			r["where"] += " " + where
			if speaker and speaker not in r["speaker"].split("|"):
				r["speaker"] = (r["speaker"] + "|" + speaker).strip("|")
			if limit and (not r["limit"] or limit < int(r["limit"])):
				r["limit"] = str(limit)
			continue
		stem = Path(l.file).stem
		kept[l.text] = {
			"id": f"{stem}.{l.scope}.{_hash(l.text)}",
			"pt": l.text, "en": "", "kind": kind, "speaker": speaker,
			"limit": str(limit) if limit else "", "where": where,
			"note": rules.note_for(l.text),
		}
		order.append(l.text)

	old = load_existing()
	orphans = [k for k in old if k not in kept and old[k].get("en")]
	for k, r in kept.items():
		if k in old:
			r["en"] = old[k].get("en", "")
			if old[k].get("note") and not r["note"]:
				r["note"] = old[k]["note"]

	total = len(kept)
	done = sum(1 for r in kept.values() if r["en"])
	chars = sum(len(k) for k in kept)
	print(f"strings visíveis: {total}  (traduzidas: {done})  caracteres pt: {chars}")
	print(f"descartadas: {len(dropped)}   traduções órfãs (texto pt mudou): {len(orphans)}")
	if report_only:
		return 0
	OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
	with OUT_CSV.open("w", encoding="utf-8", newline="") as f:
		w = csv.DictWriter(f, fieldnames=FIELDS, lineterminator="\n")
		w.writeheader()
		for k in order:
			w.writerow(kept[k])
	OUT_DROP.write_text("\n".join(dropped) + "\n", encoding="utf-8")
	if orphans:
		orf = ROOT / "assets" / "i18n" / "_orfas.csv"
		with orf.open("w", encoding="utf-8", newline="") as f:
			w = csv.DictWriter(f, fieldnames=FIELDS, lineterminator="\n")
			w.writeheader()
			for k in orphans:
				w.writerow(old[k])
		print(f"  órfãs gravadas em {orf.relative_to(ROOT)} (revise e reaproveite)")
	return 0


if __name__ == "__main__":
	sys.exit(main())
