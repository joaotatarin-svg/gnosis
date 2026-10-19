"""Renderiza UMA fala com o elenco: referência → Chatterbox → corte de cauda e
QA por ASR (até N tentativas) → pós-processamento → −18 LUFS → .ogg.

Usado por samples.py (amostras do elenco) e dub_all.py (o jogo inteiro).
"""
from __future__ import annotations

import os
import re
import time
import unicodedata
from pathlib import Path

import numpy as np

import voicelib as V
from asr_check import cer, norm

MAX_TRIES = 3
CER_OK = 0.2

_asr = None


def asr_words(x: np.ndarray, lang: str):
	"""Transcreve (Whisper small int8, CPU) com tempos por palavra."""
	global _asr
	import librosa
	from faster_whisper import WhisperModel
	if _asr is None:
		_asr = WhisperModel("small", device="cpu", compute_type="int8", cpu_threads=int(os.environ.get("VOICE_ASR_THREADS", "2")))
	a16 = librosa.resample(x, orig_sr=V.SR, target_sr=16000)
	segs, _ = _asr.transcribe(a16, language=lang, beam_size=5, word_timestamps=True, vad_filter=False)
	words = []
	for s in segs:
		for w in (s.words or []):
			words.append((w.word.strip(), w.start, w.end))
	return words


def cut_tail(x: np.ndarray, words: list, expected: str) -> tuple[np.ndarray, str]:
	"""O Chatterbox às vezes inventa um 'Ah!' ou repete depois do texto. Acha a
	última palavra esperada no ASR e corta logo depois dela."""
	ref = norm(expected).split()
	if not ref or not words:
		return x, " ".join(w for w, _, _ in words)
	last = ref[-1]
	end = None
	for i in range(len(words) - 1, -1, -1):
		w = norm(words[i][0])
		if w and (w == last or (len(last) > 3 and (w.startswith(last[:4]) or last.startswith(w[:4])))):
			end = i
			break
	if end is None or end == len(words) - 1:
		return x, " ".join(w for w, _, _ in words)
	t = words[end][2] + 0.18
	t2 = words[end + 1][1]
	cut = int(min(t, max(words[end][2] + 0.05, t2 - 0.02)) * V.SR)
	return x[:cut], " ".join(w for w, _, _ in words[: end + 1])


def render(cb: "V.Chatterbox", char: str, mood: str, mode: str, text_pt: str, said: str,
		lang: str, refs: Path, out_ogg: Path, seed0: int = 1, log=print) -> dict:
	ref = str(V.make_ref(char, lang, refs))
	p = V.params_for(char, mood, text_pt, lang)
	best = None
	t0 = time.time()
	for k in range(MAX_TRIES):
		seed = seed0 + 97 * k
		raw = V.trim(cb.gen(said, ref, p["ex"], p["cfg"], p["temp"], seed))
		cand = check(raw, said, lang, seed)
		if best is None or cand["score"] < best["score"]:
			best = cand
		if cand["ok"]:
			break
	return finish(best, char, lang, mood, mode, said, p, out_ogg, k + 1, time.time() - t0, log)


def check(raw: np.ndarray, said: str, lang: str, seed: int) -> dict:
	"""QA de uma geração (CPU): ASR, corte de cauda, CER e ritmo plausível."""
	words = asr_words(raw, lang)
	cutx, heard = cut_tail(raw, words, said)
	c = cer(said, heard)
	# duração plausível: 5–24 caracteres por segundo
	cps = len(said) / max(0.3, len(cutx) / V.SR)
	bad_rate = cps < 5 or cps > 24
	score = c + (0.3 if bad_rate else 0)
	return {"x": cutx, "cer": c, "heard": heard, "seed": seed, "score": score, "cps": cps,
		"ok": c <= CER_OK and not bad_rate}


def finish(best: dict, char: str, lang: str, mood: str, mode: str, said: str, p: dict,
		out_ogg: Path, tries: int, gen_s: float, log=print) -> dict:
	"""Pós-processamento do personagem + loudness + .ogg (CPU). Guarda o áudio
	CRU (antes dos efeitos) em out/raw — mexer no pós de um papel vira só
	`refx.py`, sem regerar na GPU — e mede a inteligibilidade DEPOIS do pós
	(cer_pos): efeito que embola a fala aparece aqui."""
	raw = V.trim(best["x"])
	raw_dir = V.HERE / "out" / "raw" / lang
	raw_dir.mkdir(parents=True, exist_ok=True)
	import soundfile as sf
	sf.write(str(raw_dir / (out_ogg.stem + ".wav")), raw, V.SR)
	x, tp, cer_pos, heard_pos = post(raw, char, mode, said, lang, out_ogg)
	info = {"tp": round(tp, 2), "file": out_ogg.name, "char": char, "lang": lang, "mood": mood, "mode": mode,
		"said": said, "asr": best["heard"], "cer": round(best["cer"], 3), "seed": best["seed"],
		"cer_pos": round(cer_pos, 3), "asr_pos": heard_pos,
		"tries": tries, "dur": round(len(x) / V.SR, 2), "gen_s": round(gen_s, 1),
		"params": p}
	ruim = info["cer"] > CER_OK or info["cer_pos"] > CER_POS_OK
	log("%s cer=%.3f pos=%.3f tries=%d dur=%.1fs gen=%.0fs tp=%.1f %s" % (out_ogg.name, info["cer"], info["cer_pos"], info["tries"], info["dur"], info["gen_s"], tp, "<<< REVER" if ruim else ""), flush=True)
	return info


CER_POS_OK = 0.25


def post(raw: np.ndarray, char: str, mode: str, said: str, lang: str, out_ogg: Path):
	"""Efeitos do personagem → loudness/true peak → ogg → ASR do resultado."""
	x = V.apply_fx(raw, V.fx_for(char, mode))
	x = V.finalize(V.trim(x, thr_db=-55, pad_ms=40))
	tp = V.write_ogg(x, out_ogg)
	heard = " ".join(w for w, _, _ in asr_words(x, lang))
	return x, tp, cer(said, heard), heard
