"""Biblioteca do pipeline de dublagem de GNOSIS (ferramenta OFFLINE — nada disto
vai no jogo; o jogo recebe só os .ogg).

Motores (licença comercial conferida — ver docs/onda2/DUBLAGEM.md §1):
  - Kokoro-82M (Apache-2.0): gera as REFERÊNCIAS de timbre (vozes sintéticas)
    e serve de fallback estável.
  - Chatterbox Multilingual (MIT): a atuação (emoção via `exaggeration`),
    clonando o timbre da referência. PT-BR usa o finetune dedicado pt-br (MIT).
Pós-processamento: numpy/scipy + ffmpeg (rubberband) — reverbs sintéticos,
dobra, oitava, distorção, sussurro, espelho. Loudness final: −18 LUFS.

Ambiente: venv em C:\\Users\\jmtat\\gnosis-tools\\voice\\venv, HF_HOME =
C:\\Users\\jmtat\\gnosis-tools\\voice\\hf, HF_HUB_OFFLINE=1.
"""
from __future__ import annotations

import gc
import json
import os
import re
import subprocess
import tempfile
import time
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

SR = 24000
HERE = Path(__file__).resolve().parent
CAST = json.loads((HERE / "cast.json").read_text(encoding="utf-8"))
TARGET_LUFS = -18.0


# --- utilidades de áudio -------------------------------------------------------
def ffmpeg_af(x: np.ndarray, af: str, sr: int = SR) -> np.ndarray:
	"""Passa o áudio por um filtro do ffmpeg (ex.: rubberband)."""
	with tempfile.TemporaryDirectory() as td:
		a, b = os.path.join(td, "a.wav"), os.path.join(td, "b.wav")
		sf.write(a, x.astype(np.float32), sr, subtype="FLOAT")
		subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", a, "-af", af, "-ar", str(sr), "-ac", "1", "-c:a", "pcm_f32le", b], check=True)
		y, _ = sf.read(b, dtype="float32")
	return y


def pitch_shift(x: np.ndarray, semis: float, formant: str = "preserved") -> np.ndarray:
	if abs(semis) < 1e-3:
		return x
	return ffmpeg_af(x, "rubberband=pitch=%.6f:formant=%s:pitchq=quality" % (2 ** (semis / 12.0), formant))


def time_stretch(x: np.ndarray, factor: float) -> np.ndarray:
	"""factor < 1 = mais lento (rubberband tempo)."""
	if abs(factor - 1) < 1e-3:
		return x
	return ffmpeg_af(x, "rubberband=tempo=%.4f" % factor)


def _butter(x, kind, f, order=2):
	sos = signal.butter(order, f, btype=kind, fs=SR, output="sos")
	return signal.sosfilt(sos, x).astype(np.float32)


def _shelf_low(x, f, db):
	# shelving simples: soma do passa-baixas com ganho
	lp = _butter(x, "low", f)
	return (x + lp * (10 ** (db / 20) - 1)).astype(np.float32)


_IR_CACHE: dict = {}


def make_ir(kind: str) -> np.ndarray:
	"""Resposta ao impulso sintética (ruído com decaimento exponencial filtrado).
	room 0,4 s · plate 1,1 s · chapel 1,6 s · hall 2,2 s · swamp 1,4 s (escuro) · cathedral 4,2 s."""
	if kind in _IR_CACHE:
		return _IR_CACHE[kind]
	p = {"room": (0.4, 6000, 0.008), "plate": (1.1, 7000, 0.004), "chapel": (1.6, 5000, 0.018),
		"hall": (2.2, 5500, 0.025), "swamp": (1.4, 2500, 0.015), "cathedral": (4.2, 4200, 0.045)}[kind]
	rt60, lp, pre = p
	rng = np.random.default_rng(7)
	n = int(SR * rt60 * 1.1)
	t = np.arange(n) / SR
	env = np.exp(-6.91 * t / rt60)
	ir = rng.standard_normal(n) * env
	# o "ar" absorve agudos com o tempo: duas bandas
	ir = 0.6 * _butter(ir, "low", lp) + 0.4 * _butter(ir, "low", lp * 0.35)
	# primeiras reflexões
	for d, g in ((0.011, 0.5), (0.019, 0.35), (0.029, 0.25), (0.041, 0.2)):
		k = int(d * SR * (1 + rt60 / 3))
		if k < n:
			ir[k] += g
	ir = np.concatenate([np.zeros(int(pre * SR)), ir])
	ir /= np.sqrt(np.sum(ir ** 2))
	_IR_CACHE[kind] = ir.astype(np.float32)
	return _IR_CACHE[kind]


def reverb(x, kind, wet):
	ir = make_ir(kind)
	w = signal.fftconvolve(x, ir)[: len(x) + len(ir)]
	d = np.concatenate([x, np.zeros(len(w) - len(x), dtype=np.float32)])
	# mantém energia: seco + molhado
	return ((1 - wet) * d + wet * w * 0.9).astype(np.float32)


def doubler(x, n, cents, ms, mix):
	"""Dobra de voz (2+ cópias desafinadas e atrasadas): sensação de voz sem corpo."""
	out = x.copy()
	for i in range(n):
		sgn = 1 if i % 2 == 0 else -1
		c = pitch_shift(x, sgn * cents / 100.0, "preserved")
		d = int(SR * ms * (i + 1) / 1000)
		c = np.concatenate([np.zeros(d, dtype=np.float32), c])[: len(x)]
		out = out + mix * c / n
	return out.astype(np.float32)


def octave(x, semis, mix):
	low = pitch_shift(x, semis, "shifted")
	return (x + mix * low[: len(x)]).astype(np.float32)


def drive(x, amount, mix):
	pk = np.max(np.abs(x)) + 1e-9
	y = np.tanh(amount * x / pk) / np.tanh(amount)
	y = _butter(y, "low", 6500) * pk
	return ((1 - mix) * x + mix * y).astype(np.float32)


def whisper(x, mix):
	"""Sussurro de verdade: mantém o envelope espectral e troca a fonte vocal
	por ruído (fase aleatória na STFT)."""
	f, t, Z = signal.stft(x, SR, nperseg=1024, noverlap=768)
	rng = np.random.default_rng(3)
	ph = np.exp(1j * rng.uniform(0, 2 * np.pi, Z.shape))
	_, y = signal.istft(np.abs(Z) * ph, SR, nperseg=1024, noverlap=768)
	y = y[: len(x)].astype(np.float32)
	y = _butter(y, "high", 300)
	return ((1 - mix) * x + mix * y * 1.2).astype(np.float32)


def metal(x, mix):
	"""Brilho metálico curto (pente de 3 ms + 7 ms): o elo de corrente."""
	y = x.copy()
	for ms, g in ((3.1, 0.5), (7.3, 0.35)):
		d = int(SR * ms / 1000)
		y[d:] += g * x[:-d]
	y = _butter(y, "high", 400)
	return ((1 - mix) * x + mix * y).astype(np.float32)


def wobble(x, depth_s, rate_hz):
	"""Atraso modulado lento (voz 'úmida', borbulhando)."""
	n = np.arange(len(x))
	d = depth_s * SR * (1 + np.sin(2 * np.pi * rate_hz * n / SR)) / 2
	idx = np.clip(n - d, 0, len(x) - 1)
	y = np.interp(idx, n, x).astype(np.float32)
	return (0.6 * x + 0.4 * y).astype(np.float32)


def mirror(x, mix):
	"""Espelho: a fala dobrada por ela mesma 3 st acima (a Sophia 'por trás do
	vidro') + um pré-eco invertido que chega ANTES da palavra."""
	up = pitch_shift(x, 3, "shifted")[: len(x)]
	y = x + mix * 0.6 * up
	pad = int(0.35 * SR)
	rev = reverb(x[::-1].copy(), "hall", 1.0)[: len(x) + pad][::-1]
	out = np.concatenate([np.zeros(pad, dtype=np.float32), y])
	out[: len(rev)] += 0.22 * mix * rev[: len(out)]
	return out.astype(np.float32)


def apply_fx(x: np.ndarray, chain: list) -> np.ndarray:
	for step in chain:
		k, a = step[0], step[1:]
		if k == "hpf": x = _butter(x, "high", a[0])
		elif k == "lpf": x = _butter(x, "low", a[0])
		elif k == "lowshelf": x = _shelf_low(x, a[0], a[1])
		elif k == "gain": x = (x * 10 ** (a[0] / 20)).astype(np.float32)
		elif k == "reverb": x = reverb(x, a[0], a[1])
		elif k == "doubler": x = doubler(x, a[0], a[1], a[2], a[3])
		elif k == "octave": x = octave(x, a[0], a[1])
		elif k == "drive": x = drive(x, a[0], a[1])
		elif k == "whisper": x = whisper(x, a[0])
		elif k == "metal": x = metal(x, a[0])
		elif k == "wobble": x = wobble(x, a[0], a[1])
		elif k == "mirror": x = mirror(x, a[0])
		elif k == "tempo": x = time_stretch(x, a[0])
		elif k == "pitch": x = pitch_shift(x, a[0], a[1] if len(a) > 1 else "preserved")
		else: raise ValueError("fx desconhecido: %s" % k)
	return x


def trim(x: np.ndarray, thr_db: float = -45, pad_ms: int = 60) -> np.ndarray:
	"""Corta silêncio no começo/fim (energia em janelas de 10 ms)."""
	win = int(SR * 0.01)
	if len(x) < win * 3:
		return x
	e = np.sqrt(np.convolve(x ** 2, np.ones(win) / win, mode="same"))
	thr = np.max(e) * 10 ** (thr_db / 20)
	idx = np.where(e > thr)[0]
	if len(idx) == 0:
		return x
	pad = int(SR * pad_ms / 1000)
	return x[max(0, idx[0] - pad): min(len(x), idx[-1] + pad)]


def finalize(x: np.ndarray, gain_db: float = 0.0) -> np.ndarray:
	"""Fade curto, −18 LUFS (pyloudnorm) e teto de pico −1 dBFS."""
	import pyloudnorm as pyln
	f = int(SR * 0.012)
	x = x.copy()
	x[:f] *= np.linspace(0, 1, f)
	ft = int(SR * 0.08)
	x[-ft:] *= np.linspace(1, 0, ft)
	meter = pyln.Meter(SR)
	try:
		lufs = meter.integrated_loudness(x.astype(np.float64))
		if np.isfinite(lufs):
			x = (x * 10 ** ((TARGET_LUFS + gain_db - lufs) / 20)).astype(np.float32)
	except ValueError:
		pass  # trecho curto demais para medir: só o teto de pico
	pk = np.max(np.abs(x)) + 1e-9
	ceil = 10 ** (-1 / 20)
	if pk > ceil:
		x = (np.tanh(x / ceil * 1.0) * ceil).astype(np.float32) if pk > 1.6 * ceil else x * (ceil / pk)
	return x.astype(np.float32)


def write_ogg(x: np.ndarray, path: str | Path, q: int = 5) -> None:
	path = Path(path)
	path.parent.mkdir(parents=True, exist_ok=True)
	with tempfile.TemporaryDirectory() as td:
		a = os.path.join(td, "a.wav")
		sf.write(a, x, SR, subtype="PCM_16")
		subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", a, "-c:a", "libvorbis", "-q:a", str(q), str(path)], check=True)


# --- motores -----------------------------------------------------------------
_kokoro: dict = {}


def kokoro(text: str, voice: str, lang: str, speed: float = 1.0) -> np.ndarray:
	from kokoro import KPipeline
	code = "p" if lang == "pt" else ("b" if voice.startswith("b") and lang == "en" else "a")
	if code not in _kokoro:
		_kokoro[code] = KPipeline(lang_code=code, repo_id="hexgrad/Kokoro-82M")
	chunks = [a.numpy() for _, _, a in _kokoro[code](text, voice=voice, speed=speed)]
	return np.concatenate(chunks).astype(np.float32)


class Chatterbox:
	"""Carrega o Chatterbox Multilingual para UM idioma (pt → finetune pt-br;
	en → V3). Sem o from_pretrained: arquivos locais do HF_HOME."""

	def __init__(self, lang: str, device: str = "cpu"):
		import torch
		from safetensors.torch import load_file
		from chatterbox.mtl_tts import ChatterboxMultilingualTTS, Conditionals
		from chatterbox.models.t3 import T3
		from chatterbox.models.t3.modules.t3_config import T3Config
		from chatterbox.models.s3gen import S3Gen
		from chatterbox.models.voice_encoder import VoiceEncoder
		from chatterbox.models.tokenizers import MTLTokenizer
		hub = Path(os.environ["HF_HOME"]) / "hub"
		base = next((hub / "models--ResembleAI--chatterbox/snapshots").iterdir())
		ptbr = next((hub / "models--ResembleAI--Chatterbox-Multilingual-pt-br/snapshots").iterdir())
		torch.set_num_threads(int(os.environ.get("VOICE_THREADS", "6")))
		self.torch = torch
		self.lang = lang
		ve = VoiceEncoder()
		ve.load_state_dict(torch.load(base / "ve.pt", map_location="cpu", weights_only=True))
		t3 = T3(T3Config.multilingual())
		st = load_file(ptbr / "t3_pt_br.safetensors" if lang == "pt" else base / "t3_mtl23ls_v3.safetensors")
		if "model" in st:
			st = st["model"][0]
		t3.load_state_dict(st)
		del st
		s3 = S3Gen()
		s3.load_state_dict(load_file(base / "s3gen_v3.safetensors"), strict=False)
		tok = MTLTokenizer(str(base / "grapheme_mtl_merged_expanded_v1.json"))
		conds = Conditionals.load(base / "conds.pt", map_location="cpu")
		self.m = ChatterboxMultilingualTTS(t3.to(device).eval(), s3.to(device).eval(), ve.to(device).eval(), tok, device, conds=conds.to(device))
		self._ref = None

	def gen(self, text: str, ref_wav: str, ex: float, cfg: float, temp: float, seed: int) -> np.ndarray:
		self.torch.manual_seed(seed)
		# Teto de tokens pela duração esperada (25 tokens/s; ~12 caracteres/s; 2×
		# de folga): sem isto, uma geração que "perde" o fim roda até 1000 tokens
		# (40 s de áudio, ~5 min de CPU) inventando sons.
		cap = int((len(text) / 12.0 + 1.5) * 25 * 2)
		t3 = self.m.t3
		if not hasattr(t3, "_inf_orig"):
			t3._inf_orig = t3.inference
		t3.inference = lambda *a, **kw: t3._inf_orig(*a, **{**kw, "max_new_tokens": min(kw.get("max_new_tokens") or 1000, cap)})
		if ref_wav != self._ref:
			self.m.prepare_conditionals(ref_wav, exaggeration=ex)
			self._ref = ref_wav
		w = self.m.generate(text, language_id=self.lang, exaggeration=ex, cfg_weight=cfg, temperature=temp)
		return w.squeeze().cpu().numpy().astype(np.float32)

	def close(self):
		del self.m
		gc.collect()


# --- referências de timbre -----------------------------------------------------
def ref_path(char: str, lang: str, root: Path) -> Path:
	safe = re.sub(r"[^a-z0-9]+", "_", char.lower()).strip("_")
	return root / ("%s_%s.wav" % (safe, lang))


def make_ref(char: str, lang: str, root: Path) -> Path:
	"""Gera (ou reaproveita) a referência de ~9 s do personagem: Kokoro + tom."""
	p = ref_path(char, lang, root)
	if p.exists():
		return p
	c = CAST["characters"][char]
	if "ref_from" in c:
		src = make_ref(c["ref_from"], lang, root)
		x, _ = sf.read(src, dtype="float32")
	else:
		r = c["ref"][lang]
		x = kokoro(CAST["ref_text"][lang], r["voice"], lang, r.get("speed", 1.0))
	x = pitch_shift(x, c["ref"].get("pitch", 0), c["ref"].get("formant", "preserved"))
	x = finalize(trim(x))
	p.parent.mkdir(parents=True, exist_ok=True)
	sf.write(p, x, SR)
	return p


def params_for(char: str, mood: str, text_pt: str) -> dict:
	c = CAST["characters"][char]["cb"]
	ex, cfg, temp = c["ex"], c["cfg"], c["temp"]
	moods = [mood] if mood else []
	if re.search(r"\b[A-ZÁÉÍÓÚÂÊÔÃÕÇ]{2,}\b", text_pt) or "!" in text_pt:
		moods.append("grito")
	for m in moods:
		d = CAST["_moods"].get(m)
		if d:
			ex += d["ex"]
			cfg += d["cfg"]
	return {"ex": float(np.clip(ex, 0.2, 1.0)), "cfg": float(np.clip(cfg, 0.2, 0.8)), "temp": temp}


def fx_for(char: str, mode: str) -> list:
	c = CAST["characters"][char]
	if mode == "pensamento" and "fx_pensamento" in c:
		return c["fx_pensamento"]
	return c["fx"]
