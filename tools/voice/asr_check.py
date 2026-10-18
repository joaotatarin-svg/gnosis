"""QA de inteligibilidade: transcreve cada áudio com Whisper (faster-whisper, MIT)
e compara com o texto esperado (CER = taxa de erro por caractere).

Como ninguém da IA OUVE o áudio, este é o "ouvido" do pipeline: pega falas
truncadas, alucinadas, em outro idioma ou com repetição. CER > 0,25 = refazer.

Uso:
  python tools/voice/asr_check.py <pasta_ou_manifest.json> [--model small]
Com uma pasta: espera <nome>.wav/.ogg + <nome>.txt (texto esperado) lado a lado,
ou um arquivo _textos.json {arquivo: {"text":..., "lang": "pt"|"en"}}.
"""
from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path


def norm(s: str) -> str:
	s = unicodedata.normalize("NFKD", s.lower())
	s = "".join(c for c in s if not unicodedata.combining(c))
	s = re.sub(r"[^a-z0-9 ]+", " ", s)
	return re.sub(r"\s+", " ", s).strip()


def cer(ref: str, hyp: str) -> float:
	r, h = norm(ref), norm(hyp)
	if not r:
		return 0.0 if not h else 1.0
	prev = list(range(len(h) + 1))
	for i, rc in enumerate(r, 1):
		cur = [i] + [0] * len(h)
		for j, hc in enumerate(h, 1):
			cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (rc != hc))
		prev = cur
	return prev[-1] / len(r)


_model = None


def transcribe(path: str, lang: str, model_size: str = "small") -> str:
	global _model
	if _model is None:
		from faster_whisper import WhisperModel
		_model = WhisperModel(model_size, device="cpu", compute_type="int8")
	# Decodifica aqui (librosa) — o av 19 quebrou o decode_audio do faster-whisper.
	import librosa
	audio, _sr = librosa.load(path, sr=16000, mono=True)
	segs, _ = _model.transcribe(audio, language=lang, beam_size=5, vad_filter=False)
	return " ".join(s.text.strip() for s in segs)


def main() -> int:
	sys.stdout.reconfigure(encoding="utf-8")
	src = Path(sys.argv[1])
	size = sys.argv[sys.argv.index("--model") + 1] if "--model" in sys.argv else "small"
	items: list[tuple[str, str, str]] = []
	if src.is_dir():
		tj = src / "_textos.json"
		if tj.exists():
			for f, d in json.loads(tj.read_text(encoding="utf-8")).items():
				items.append((str(src / f), d["text"], d["lang"]))
	else:
		for ln in json.loads(src.read_text(encoding="utf-8"))["lines"]:
			for lang in ("pt", "en"):
				f = ln.get("file_" + lang)
				if f:
					items.append((str(src.parent / f), ln["said_" + lang], lang))
	res = []
	for path, text, lang in items:
		hyp = transcribe(path, lang, size)
		c = cer(text, hyp)
		res.append({"file": Path(path).name, "cer": round(c, 3), "ref": text, "asr": hyp})
		print("%s %.3f  %s\n      ASR: %s" % ("OK " if c <= 0.25 else "RUIM", c, Path(path).name, hyp))
	out = (src if src.is_dir() else src.parent) / "_asr.json"
	out.write_text(json.dumps(res, ensure_ascii=False, indent=1), encoding="utf-8")
	ruins = sum(1 for r in res if r["cer"] > 0.25)
	print("total %d · ruins %d · CER médio %.3f" % (len(res), ruins, sum(r["cer"] for r in res) / max(1, len(res))))
	return 0


if __name__ == "__main__":
	sys.exit(main())
