"""DUBLAGEM DO JOGO INTEIRO (pronto, mas só rodar DEPOIS de o João aprovar o elenco).

roteiro (extract_lines) → elenco (cast.json) → Chatterbox + QA ASR → pós →
−18 LUFS → assets/audio/voice/<pt|en>/<id>.ogg + assets/audio/voice/manifest.json

Incremental: cada fala guarda uma `chave` (texto falado + parâmetros do elenco);
se nada mudou e o .ogg existe, pula. Mudou o texto no narrative.gd → só aquela
fala é refeita. Fala que sumiu do roteiro sai do manifesto (o .ogg órfão é
listado para apagar à mão).

Uso:
  python tools/voice/dub_all.py --dry-run                 # conta falas e estima tempo
  python tools/voice/dub_all.py --lang pt --speaker Sophia --limit 10
  python tools/voice/dub_all.py --lang pt,en              # tudo (horas na CPU)
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import voicelib as V  # noqa: E402
from extract_lines import extract  # noqa: E402

ROOT = HERE.parents[1]
VOICE_DIR = ROOT / "assets" / "audio" / "voice"
MANIFEST = VOICE_DIR / "manifest.json"
RTF_CPU = 8.0      # medido: ~6–12× o tempo do áudio na CPU (Ryzen 5 5600G)
CPS = 14.0         # caracteres por segundo de fala (média medida nas amostras)


def key_of(line: dict, lang: str) -> str:
	c = V.CAST["characters"][line["speaker"]]
	blob = json.dumps([line["said_" + lang], line["mood"], line["mode"], c, V.CAST["_moods"]], ensure_ascii=False, sort_keys=True)
	return hashlib.sha1(blob.encode("utf-8")).hexdigest()[:10]


def main() -> int:
	sys.stdout.reconfigure(encoding="utf-8")
	ap = argparse.ArgumentParser()
	ap.add_argument("--lang", default="pt,en")
	ap.add_argument("--speaker", default="")
	ap.add_argument("--limit", type=int, default=0)
	ap.add_argument("--device", default="cpu")
	ap.add_argument("--dry-run", action="store_true")
	a = ap.parse_args()

	lines = [l for l in extract(ROOT) if l["mode"] != "rubrica" and not l["dynamic"]]
	lines = [l for l in lines if l["speaker"] in V.CAST["characters"]]
	if a.speaker:
		keep = set(a.speaker.split(","))
		lines = [l for l in lines if l["speaker"] in keep]
	man = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {"version": 1, "lufs": V.TARGET_LUFS, "lines": {}}
	todo = []
	for lang in a.lang.split(","):
		for l in lines:
			if not l["said_" + lang]:
				continue
			ent = man["lines"].get(l["id"], {}).get(lang)
			f = VOICE_DIR / lang / (l["id"] + ".ogg")
			if ent and ent.get("key") == key_of(l, lang) and f.exists():
				continue
			todo.append((lang, l))
	if a.limit:
		todo = todo[: a.limit]
	chars = sum(len(l["said_" + lang]) for lang, l in todo)
	est_h = chars / CPS * RTF_CPU / 3600
	print("falas a gerar: %d (%d caracteres) · estimativa CPU ~%.1f h" % (len(todo), chars, est_h))
	if a.dry_run or not todo:
		return 0

	from render import render
	refs = HERE / "out" / "refs"
	ids_vivos = {l["id"] for l in lines}
	for lang in a.lang.split(","):
		batch = [l for lg, l in todo if lg == lang]
		if not batch:
			continue
		cb = V.Chatterbox(lang, a.device)
		for i, l in enumerate(batch):
			f = VOICE_DIR / lang / (l["id"] + ".ogg")
			info = render(cb, l["speaker"], l["mood"], l["mode"], l["text_pt"], l["said_" + lang], lang, refs, f)
			ent = man["lines"].setdefault(l["id"], {"speaker": l["speaker"], "mood": l["mood"], "source": l["source"]})
			ent[lang] = {"file": "res://assets/audio/voice/%s/%s.ogg" % (lang, l["id"]), "dur": info["dur"],
				"cer": info["cer"], "key": key_of(l, lang)}
			if (i + 1) % 5 == 0 or i + 1 == len(batch):
				MANIFEST.write_text(json.dumps(man, ensure_ascii=False, indent=1), encoding="utf-8")
				print("  %s %d/%d" % (lang, i + 1, len(batch)), flush=True)
		cb.close()
	# limpa do manifesto falas que saíram do roteiro (só quando rodou sem filtro)
	if not a.speaker and not a.limit:
		mortos = [k for k in man["lines"] if k not in ids_vivos]
		for k in mortos:
			del man["lines"][k]
		if mortos:
			print("saíram do roteiro (apague os .ogg à mão):", ", ".join(mortos))
	MANIFEST.write_text(json.dumps(man, ensure_ascii=False, indent=1), encoding="utf-8")
	ruins = [(k, lg) for k, e in man["lines"].items() for lg in ("pt", "en") if lg in e and e[lg]["cer"] > 0.2]
	print("manifesto: %d falas · %d com CER > 0,2 (ouvir/refazer): %s" % (len(man["lines"]), len(ruins), ruins[:20]))
	return 0


if __name__ == "__main__":
	sys.exit(main())
