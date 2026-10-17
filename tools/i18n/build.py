#!/usr/bin/env python3
"""GNOSIS — junta as traduções e confere tudo (i18n).

Fonte da tradução: os lotes `assets/i18n/en/*.tsv`, uma linha por texto:
    <id do strings.csv><TAB><inglês>
(linhas começando com `#` são comentário; `\\n` vira quebra de linha; espaços no começo/fim
do texto não precisam ser escritos: são herdados do pt, como em "Eco de " → "Echo of ").

O que faz:
  1. preenche a coluna `en` de `assets/i18n/strings.csv` (o resto do CSV é do extract.py);
  2. confere cada tradução (limite de caracteres, %d/%s, \\n, BBCode, glossário, termos proibidos);
  3. gera os arquivos prontos para o Godot (ainda NÃO ligados ao jogo — a pasta tem .gdignore):
       assets/i18n/godot/gnosis_text.csv   (formato de tradução CSV do Godot: keys,en; key = texto pt)
       assets/i18n/godot/en.po              (gettext, msgid = texto pt; alternativa com msgctxt)
  4. imprime o relatório (traduzidas / faltando / alertas) e grava assets/i18n/_relatorio.txt.

Uso:  python3 tools/i18n/build.py          (a partir da raiz do projeto)
      python3 tools/i18n/build.py --strict (sai com código 1 se houver alerta ou falta)
"""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
I18N = ROOT / "assets" / "i18n"
CSV_PATH = I18N / "strings.csv"
LOTES = I18N / "en"
OUT = I18N / "godot"

# Termos que NÃO podem aparecer no inglês (glossário: grafia errada ou nome proibido).
FORBIDDEN = [
	(r"\bSofia\b", "Sophia, nunca Sofia"),
	(r"\bSabaoth\b|\bAdonai|\bAdonaios\b|\bEloaios\b|\bIao\b", "nome sagrado de fé viva como vilão"),
	(r"\bEons?\b|\bÆons?\b", "Aeon/Aeons (glossário)"),
	(r"\bArchont\b|\barchons?\b(?! [a-z]+ (said|say))", "Archon com maiúscula"),
	(r"\bspark(le)?ling\b", ""),
	(r"…", "reticências = três pontos ..."),
	(r"--", "travessão = — (em dash)"),
	(r"\bkenoma\b|\bpleroma\b", "Kenoma/Pleroma com maiúscula"),
	(r"\bStela\b|\bStelas\b", "Stele / Stelae (glossário)"),
	(r"\bGnose\b", "gnosis (minúscula), Gnosis só em título"),
	(r"\bCentre\b", "Center (inglês americano)"),
]
# Alertas leves (não bloqueiam): palavra "Climb." solta é tique exclusivo da Voz.
VOICE_TIC = re.compile(r"(^|[.!?…] )Climb\.")


def load_rows() -> list[dict]:
	with CSV_PATH.open(encoding="utf-8", newline="") as f:
		return list(csv.DictReader(f))


def load_lotes() -> tuple[dict[str, str], list[str], dict[str, str]]:
	"""(id → inglês, problemas, compostos). Linha `=<texto pt>	<inglês>` é um texto
	COMPOSTO pelo código (não existe literal no fonte: "Campeão " + "da Fome",
	"Arconte  ·  " + nome...): entra direto na tabela do jogo, chave = o pt."""
	tr: dict[str, str] = {}
	extra: dict[str, str] = {}
	problems: list[str] = []
	for p in sorted(LOTES.glob("*.tsv")):
		for no, ln in enumerate(p.read_text(encoding="utf-8").split("\n"), 1):
			if not ln.strip() or ln.lstrip().startswith("#"):
				continue
			if "\t" not in ln:
				problems.append(f"{p.name}:{no}: sem TAB")
				continue
			k, v = ln.split("\t", 1)
			v = v.replace("\\n", "\n").rstrip("\r")   # espaços nas pontas são significativos
			if k.startswith("="):
				pt = k[1:].replace("\\n", "\n")
				if pt in extra:
					problems.append(f"{p.name}:{no}: composto repetido {pt!r}")
				if _fmt_seq(pt) != _fmt_seq(v):
					problems.append(f"{p.name}:{no}: formato {_fmt_seq(pt)} != {_fmt_seq(v)} em {pt!r}")
				extra[pt] = v
				continue
			k = k.strip()
			if k in tr:
				problems.append(f"{p.name}:{no}: id repetido {k}")
			tr[k] = v
	return tr, problems, extra


def _fmt(s: str) -> list[str]:
	return sorted(re.findall(r"%[-+0-9.]*[dsfv%]", s))


def _fmt_seq(s: str) -> list[str]:
	"""Tipos dos % NA ORDEM (o jogo casa o padrão pt e preenche o en na mesma ordem)."""
	return [m[-1] for m in re.findall(r"%[-+0-9.]*[dsfv]", s.replace("%%", ""))]


def check(r: dict, en: str) -> list[str]:
	pt = r["pt"]
	out = []
	if _fmt(pt) != _fmt(en):
		out.append(f"formato {_fmt(pt)} ≠ {_fmt(en)}")
	elif _fmt_seq(pt) != _fmt_seq(en):
		out.append(f"ordem dos % diferente: {_fmt_seq(pt)} ≠ {_fmt_seq(en)}")
	if pt.count("\n") != en.count("\n") and r["kind"] not in ("ui",):
		out.append(f"quebras de linha pt={pt.count(chr(10))} en={en.count(chr(10))}")
	if (pt[:1].isspace(), pt[-1:].isspace()) != (en[:1].isspace(), en[-1:].isspace()):
		out.append("espaço no começo/fim diferente do pt (pedaço concatenado)")
	if re.findall(r"\[/?\w+[^\]]*\]", pt) != re.findall(r"\[/?\w+[^\]]*\]", en):
		out.append("tags BBCode diferentes")
	lim = int(r["limit"]) if r.get("limit") else 0
	if lim and r["kind"] != "card_cinema":
		# limite em caracteres (ESTILO_TEXTO §5) — aproximação rápida; quem decide se
		# CABE é tools/i18n/EnFit.tscn, que mede em pixels com as fontes do jogo.
		if len(en) > max(lim, len(pt)):
			out.append(f"{len(en)} car. > limite {lim}")
		elif len(en) > lim:
			out.append(f"{len(en)} car. > limite {lim} (o pt também passa: {len(pt)})")
	for pat, why in FORBIDDEN:
		if why and re.search(pat, en):
			out.append(f"glossário: {why}")
	if r["speaker"] and "A Voz" not in r["speaker"] and VOICE_TIC.search(en):
		out.append("“Climb.” solto é tique só da Voz")
	caps = [w for w in re.findall(r"\b[A-Z]{3,}\b", en) if w not in ("GNOSIS", "II", "III", "IV", "VI", "VII", "VIII", "IX", "XI", "XII", "NHC", "BG", "CC0", "MIT", "SIL", "OFL", "FPS", "DB", "VSYNC")]
	if r["kind"] in ("dialogo", "legenda", "narrativa") and len(caps) > 1:
		out.append(f"CAIXA ALTA em {len(caps)} palavras (máx. 1)")
	return out


TABLE = ROOT / "scripts" / "i18n" / "en_table.gd"


def gd_str(s: str) -> str:
	"""Literal de string GDScript (aspas duplas, escapes padrão)."""
	return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t").replace("\r", "") + '"'


def write_table(done: list[dict], extra: dict[str, str]) -> None:
	"""Tabela que o JOGO lê (GnosisTranslation): pt → en. Gerada — não edite à mão."""
	table: dict[str, str] = {}
	# igual nos dois idiomas não precisa entrar — exceto FORMATOS ("%s — %s"):
	# viram padrão no jogo e traduzem os pedaços (o nome, a descrição...).
	for r in done:
		if r["pt"] != r["en"] or "%" in r["pt"]:
			table[r["pt"]] = r["en"]
	for k, v in extra.items():
		if k != v or "%" in k:
			table[k] = v
	out = ["extends RefCounted",
		"## GERADO por tools/i18n/build.py a partir de assets/i18n/en/*.tsv — NÃO EDITE.",
		"## Chave = texto em português exato; valor = inglês. Lido por GnosisTranslation.",
		"", "const EXACT := {"]
	for k in sorted(table):
		out.append("\t" + gd_str(k) + ": " + gd_str(table[k]) + ",")
	out.append("}")
	TABLE.write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")
	print(f"tabela do jogo: {len(table)} entradas -> {TABLE.relative_to(ROOT).as_posix()}")


def po_escape(s: str) -> str:
	return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def main() -> int:
	rows = load_rows()
	tr, problems, extra = load_lotes()
	ids = {r["id"] for r in rows}
	for k in tr:
		if k not in ids:
			problems.append(f"id do lote não existe mais no CSV: {k}")
	alerts: list[str] = []
	missing: list[str] = []
	for r in rows:
		r["en"] = tr.get(r["id"], "")   # os lotes são a única fonte do inglês
		if r["en"]:
			# espaço nas pontas (pedaço concatenado no código, ex.: "Eco de "): herda do pt,
			# porque editores costumam apagar espaço no fim da linha do .tsv.
			pt = r["pt"]
			lead = pt[:len(pt) - len(pt.lstrip())]
			trail = pt[len(pt.rstrip()):]
			r["en"] = lead + r["en"].strip(" ") + trail
		if not r["en"]:
			missing.append(r["id"])
			continue
		for a in check(r, r["en"]):
			alerts.append(f"{r['id']}: {a}  | {r['en'][:70]!r}")

	with CSV_PATH.open("w", encoding="utf-8", newline="") as f:
		w = csv.DictWriter(f, fieldnames=list(rows[0].keys()), lineterminator="\n")
		w.writeheader()
		w.writerows(rows)

	OUT.mkdir(parents=True, exist_ok=True)
	done = [r for r in rows if r["en"]]
	with (OUT / "gnosis_text.csv").open("w", encoding="utf-8", newline="") as f:
		w = csv.writer(f, lineterminator="\n")
		w.writerow(["keys", "en"])
		for r in done:
			w.writerow([r["pt"], r["en"]])
	po = ['msgid ""', 'msgstr ""', '"Language: en\\n"', '"MIME-Version: 1.0\\n"',
		'"Content-Type: text/plain; charset=UTF-8\\n"', '"Content-Transfer-Encoding: 8bit\\n"', ""]
	for r in done:
		po.append(f"#. {r['id']}  [{r['kind']}{(' · ' + r['speaker']) if r['speaker'] else ''}]")
		po.append(f"#: {r['where'].split(' ')[0]}")
		po.append(f'msgid "{po_escape(r["pt"])}"')
		po.append(f'msgstr "{po_escape(r["en"])}"')
		po.append("")
	for k, v in extra.items():
		po.append("#. composto (montado pelo código)")
		po.append(f'msgid "{po_escape(k)}"')
		po.append(f'msgstr "{po_escape(v)}"')
		po.append("")
	(OUT / "en.po").write_text("\n".join(po), encoding="utf-8")
	write_table(done, extra)

	lines = [
		f"strings: {len(rows)}   traduzidas: {len(done)}   faltando: {len(missing)}",
		f"caracteres pt: {sum(len(r['pt']) for r in rows)}   en: {sum(len(r['en']) for r in done)}",
		f"alertas: {len(alerts)}   problemas nos lotes: {len(problems)}",
	]
	report = lines + ["", "## problemas nos lotes"] + problems + ["", "## alertas"] + alerts + ["", "## faltando"] + missing
	(I18N / "_relatorio.txt").write_text("\n".join(report) + "\n", encoding="utf-8")
	print("\n".join(lines))
	for p in problems[:20]:
		print("  LOTE:", p)
	for a in alerts[:40]:
		print("  ALERTA:", a)
	if len(alerts) > 40:
		print(f"  ... (+{len(alerts) - 40} alertas em assets/i18n/_relatorio.txt)")
	if "--strict" in sys.argv and (alerts or missing or problems):
		return 1
	return 0


if __name__ == "__main__":
	sys.exit(main())
