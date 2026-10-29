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
PIPE_VER = 2       # sobe quando o pós/loudness muda (2 = limitador true peak) → refaz tudo


def key_of(line: dict, lang: str) -> str:
	c = V.CAST["characters"][line["speaker"]]
	blob = json.dumps([PIPE_VER, line["said_" + lang], line["mood"], line["mode"], c, V.CAST["_moods"]], ensure_ascii=False, sort_keys=True)
	return hashlib.sha1(blob.encode("utf-8")).hexdigest()[:10]


def pipeline(cb, batch: list, lang: str, refs: Path, man: dict, duty: float) -> None:
	"""GPU e CPU em paralelo: a thread principal só GERA (Chatterbox na GPU) e
	joga o áudio cru numa fila; uma thread de QA (CPU: Whisper, corte de cauda,
	pós, loudness, ogg) consome a fila. Reprovada no QA → volta para a fila de
	geração com outra semente (até render.MAX_TRIES). Assim a GPU não espera o ASR."""
	import queue
	import threading
	import render as R
	gen_q: "queue.Queue" = queue.Queue()
	qa_q: "queue.Queue" = queue.Queue(maxsize=3)
	lock = threading.Lock()
	state: dict = {}          # id -> {"best", "tries", "t"}
	done = {"n": 0}
	for l in batch:
		gen_q.put((l, 0))
	total = len(batch)

	def qa_worker():
		while True:
			item = qa_q.get()
			if item is None:
				return
			l, k, raw, seed, p, gen_s = item
			try:
				said = l["said_" + lang]
				cand = R.check(raw, said, lang, seed)
				st = state.setdefault(l["id"], {"best": None, "gen_s": 0.0})
				st["gen_s"] += gen_s
				if st["best"] is None or cand["score"] < st["best"]["score"]:
					st["best"] = cand
				if not cand["ok"] and k + 1 < R.MAX_TRIES:
					gen_q.put((l, k + 1))
					continue
				f = VOICE_DIR / lang / (l["id"] + ".ogg")
				info = R.finish(st["best"], l["speaker"], lang, l["mood"], l["mode"], said, p, f, k + 1, st["gen_s"])
				with lock:
					ent = man["lines"].setdefault(l["id"], {"speaker": l["speaker"], "mood": l["mood"], "source": l["source"]})
					ent[lang] = {"file": "res://assets/audio/voice/%s/%s.ogg" % (lang, l["id"]), "dur": info["dur"],
						"cer": info["cer"], "cer_pos": info["cer_pos"], "tp": info["tp"], "key": key_of(l, lang), "asr": info["asr"], "seed": info["seed"]}
					# salva a CADA fala: se cair, retoma de onde parou (pula o que já tem chave)
					MANIFEST.write_text(json.dumps(man, ensure_ascii=False, indent=1), encoding="utf-8")
					done["n"] += 1
					if done["n"] % 10 == 0 or done["n"] == total:
						print("  %s %d/%d" % (lang, done["n"], total), flush=True)
			except Exception as e:  # uma fala ruim não derruba o lote
				print("!! QA falhou em %s: %r" % (l["id"], e), flush=True)
				with lock:
					done["n"] += 1
			finally:
				qa_q.task_done()

	th = threading.Thread(target=qa_worker, daemon=True)
	th.start()
	while done["n"] < total:
		try:
			l, k = gen_q.get(timeout=1.0)
		except queue.Empty:
			continue
		try:
			ref = str(V.make_ref(l["speaker"], lang, refs))
			p = V.params_for(l["speaker"], l["mood"], l["text_pt"], lang)
			seed = 1 + 97 * k
			t0 = time.time()
			raw = V.trim(cb.gen(l["said_" + lang], ref, p["ex"], p["cfg"], p["temp"], seed))
			gs = time.time() - t0
		except Exception as e:
			print("!! geração falhou em %s: %r" % (l["id"], e), flush=True)
			with lock:
				done["n"] += 1
			continue
		qa_q.put((l, k, raw, seed, p, gs))
		if duty < 1.0:
			time.sleep(gs * (1.0 / max(0.05, duty) - 1.0))
	qa_q.put(None)
	th.join()


def main() -> int:
	sys.stdout.reconfigure(encoding="utf-8")
	V.low_priority()
	ap = argparse.ArgumentParser()
	ap.add_argument("--lang", default="pt,en")
	ap.add_argument("--speaker", default="")
	ap.add_argument("--limit", type=int, default=0)
	ap.add_argument("--device", default="cpu")
	ap.add_argument("--dry-run", action="store_true")
	ap.add_argument("--duty", type=float, default=1.0, help="fração do tempo gerando (0,5 = descansa o mesmo tempo que gerou) — regra da GPU ≤25% médio")
	ap.add_argument("--out", default="", help="pasta de saída (padrão: assets/audio/voice; rascunho: _caps)")
	a = ap.parse_args()
	global VOICE_DIR, MANIFEST
	if a.out:
		VOICE_DIR = Path(a.out)
		MANIFEST = VOICE_DIR / "manifest.json"
	VOICE_DIR.mkdir(parents=True, exist_ok=True)

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

	refs = HERE / "out" / "refs"
	ids_vivos = {l["id"] for l in lines}
	for lang in a.lang.split(","):
		batch = [l for lg, l in todo if lg == lang]
		if not batch:
			continue
		cb = V.Chatterbox(lang, a.device)
		pipeline(cb, batch, lang, refs, man, a.duty)
		cb.close()
	# limpa do manifesto falas que saíram do roteiro (só quando rodou sem filtro)
	if not a.speaker and not a.limit:
		mortos = [k for k in man["lines"] if k not in ids_vivos]
		for k in mortos:
			del man["lines"][k]
		if mortos:
			print("saíram do roteiro (apague os .ogg à mão):", ", ".join(mortos))
	MANIFEST.write_text(json.dumps(man, ensure_ascii=False, indent=1), encoding="utf-8")
	ruins = [(k, lg) for k, e in man["lines"].items() for lg in ("pt", "en") if lg in e and (e[lg]["cer"] > 0.2 or e[lg].get("cer_pos", 0) > 0.25)]
	print("manifesto: %d falas · %d com CER > 0,2 (ouvir/refazer): %s" % (len(man["lines"]), len(ruins), ruins[:20]))
	return 0


if __name__ == "__main__":
	sys.exit(main())
