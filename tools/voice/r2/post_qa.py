# Pós-processamento + QA (CPU) da dublagem R2 do GNOSIS. Ferramenta OFFLINE.
# Para cada fala: escolhe o melhor candidato cru (ASR + similaridade de locutor), corta cauda,
# aplica a cadeia do personagem (inclui a "legião" do Rei/Yaldabaoth), loudness −21 LUFS
# (grito −18), true peak ≤ −1 dBTP, mede de novo por ASR DEPOIS dos efeitos e grava .ogg.
# Uso (venv principal): python -I post_qa.py job_post.json
#   job_post: {"items": [{"key", "char", "fx", "said", "lang", "cands": [wav...], "out": ogg,
#              "grito": bool, "stereo": bool}]}
# Saída: <out>.qa.json por fala + resumo no stdout. NUNCA toca áudio.
import os, sys, json, ctypes
sys.path.insert(0, r"C:\gnosis-wt\dublagem\tools\voice")
os.environ["HF_HOME"] = r"C:\Users\jmtat\gnosis-tools\voice\hf"
os.environ["HF_HUB_OFFLINE"] = "1"
ctypes.windll.kernel32.SetPriorityClass(ctypes.windll.kernel32.GetCurrentProcess(), 0x4000)

import numpy as np
import soundfile as sf
import librosa
from scipy import signal
import voicelib as V
from asr_check import cer, norm

SR = V.SR
NORMAL_LUFS = -21.0
GRITO_LUFS = -18.0
CER_RAW_OK = 0.12
CER_POS_OK = 0.15
CER_POS_OK_LEGIAO = 0.20
PROMPT_NOMES = "Sophia, Yaldabaoth, Portadora, Kenoma, Éons, Arcontes, Athoth, Harmas, Galila, Yabel, Astaphaios, Belias, Armupiel, Soter, Velkar, Pleroma."

_asr = None


def asr(x, lang):
	global _asr
	from faster_whisper import WhisperModel
	if _asr is None:
		_asr = WhisperModel("small", device="cpu", compute_type="int8", cpu_threads=4)
	a16 = librosa.resample(np.asarray(x, dtype=np.float32), orig_sr=SR, target_sr=16000)
	segs, _ = _asr.transcribe(a16, language=lang, beam_size=5, word_timestamps=True, vad_filter=False,
		initial_prompt=PROMPT_NOMES if lang == "pt" else None, condition_on_previous_text=False)
	words = []
	for s in segs:
		for w in (s.words or []):
			words.append((w.word.strip(), w.start, w.end))
	return words


def cut_tail(x, words, expected):
	"""Corta o que vier depois da última palavra esperada (cauda inventada)."""
	ref = norm(expected).split()
	if not ref or not words:
		return x
	last = ref[-1]
	for i in range(len(words) - 1, -1, -1):
		w = norm(words[i][0])
		if w and (w == last or (len(last) > 3 and (w.startswith(last[:4]) or last.startswith(w[:4])))):
			if i == len(words) - 1:
				return x
			t = min(words[i][2] + 0.25, words[i + 1][1] - 0.02)
			return x[: int(max(t, words[i][2] + 0.05) * SR)]
	return x


# --- reverbs curtos (Guardião §17: cena ≤ 1,8 s; combate ≤ 0,8 s) -------------
_IR = {}


def ir(kind):
	if kind in _IR:
		return _IR[kind]
	rt60, lp, pre = {"sala": (0.45, 6000, 0.006), "placa": (0.9, 7000, 0.004), "capela": (1.3, 5000, 0.015),
		"salao": (1.5, 5200, 0.02), "catedral": (1.75, 4200, 0.03), "pantano": (1.2, 2500, 0.012), "combate": (0.7, 5000, 0.01)}[kind]
	rng = np.random.default_rng(7)
	n = int(SR * rt60 * 1.05)
	t = np.arange(n) / SR
	h = rng.standard_normal(n) * np.exp(-6.91 * t / rt60)
	h = 0.6 * V._butter(h, "low", lp) + 0.4 * V._butter(h, "low", lp * 0.35)
	for d, g in ((0.011, 0.5), (0.019, 0.35), (0.029, 0.25), (0.041, 0.2)):
		k = int(d * SR * (1 + rt60 / 3))
		if k < n:
			h[k] += g
	h = np.concatenate([np.zeros(int(pre * SR)), h])
	h /= np.sqrt(np.sum(h ** 2))
	_IR[kind] = h.astype(np.float32)
	return _IR[kind]


MODO = {"combate": False}


def rev(x, kind, wet, tail=True):
	if MODO["combate"]:  # Guardião §17: cauda ≤ 0,8 s em combate
		kind = "combate"
	w = signal.fftconvolve(x, ir(kind))
	n = len(w) if tail else len(x)
	d = np.zeros(n, dtype=np.float32)
	d[: len(x)] = x
	return ((1 - wet) * d + wet * 0.9 * w[:n]).astype(np.float32)


def rms(x):
	return float(np.sqrt(np.mean(np.square(x)) + 1e-12))


def pad(x, n):
	return x[:n] if len(x) >= n else np.concatenate([x, np.zeros(n - len(x), dtype=np.float32)])


def delay(x, ms, n):
	d = int(SR * ms / 1000)
	return pad(np.concatenate([np.zeros(d, dtype=np.float32), x]), n)


def deesser(x):
	return V.ffmpeg_af(x, "deesser=i=0.6:m=0.6:f=0.5:s=o")


# camadas da legião: (semitons, formante, atraso ms, ganho dB relativo entre ecos, passa-baixas Hz, pan -1..1)
LEGIAO = {
	1: {"camadas": [(-12, "shifted", 34, 0, 2600, -0.3), (-5, "preserved", 27, -3, 3500, 0.3)],
		"bus_db": -13.0, "rev": ("salao", 0.12, 0.45), "peso": 1.5, "drive": 0.0},
	3: {"camadas": [(-5, "preserved", 26, -2, 3800, -0.45), (-12, "shifted", 38, 0, 2600, 0.45), (-19, "shifted", 52, -2, 1800, 0.0)],
		"bus_db": -9.0, "rev": ("catedral", 0.14, 0.55), "peso": 2.5, "drive": 0.15},
	4: {"camadas": [(-5, "preserved", 25, -1, 3800, -0.5), (-12, "shifted", 37, 0, 2600, 0.5), (-19, "shifted", 51, -1, 1800, -0.1),
		(5, "shifted", 31, -8, 6000, 0.15)],
		"bus_db": -8.0, "rev": ("catedral", 0.16, 0.6), "peso": 3.0, "drive": 0.22},
	5: {"camadas": [(-5, "preserved", 25, -1, 3800, -0.55), (-12, "shifted", 36, 0, 2600, 0.55), (-19, "shifted", 50, -1, 1800, -0.2),
		(5, "shifted", 31, -7, 6000, 0.2), (-8, "shifted", 58, -3, 2200, 0.0)],
		"bus_db": -6.5, "rev": ("catedral", 0.18, 0.65), "peso": 3.5, "drive": 0.3},
}


def legiao(x, nivel, stereo=False):
	"""Voz principal NA FRENTE + coro de ecos graves (tom/formante diferentes, atrasos 25–60 ms,
	passa-altas 150 Hz, reverb maior atrás). Bus de ecos ≥ 6 dB abaixo da principal (Guardião §16)."""
	L = LEGIAO[nivel]
	n = len(x)
	ecos = []
	for st, fm, ms, g, lp, pan in L["camadas"]:
		y = pad(V.pitch_shift(x, st, fm), n)
		if st > 0:  # a camada aguda é sussurrada (fantasma), bem baixa
			y = V.whisper(y, 0.8)
		y = V._butter(V._butter(y, "high", 150), "low", lp)
		y = delay(y, ms, n) * 10 ** (g / 20)
		ecos.append((y, pan))
	kind, wet_m, wet_e = L["rev"]
	main = x.copy()
	if L["drive"] > 0:
		main = V.drive(main, 2.5, L["drive"])
		main = deesser(main)[:n] if len(main) else main
		main = pad(main, n)
	if L["peso"] > 0:
		main = V._shelf_low(main, 140, L["peso"])
	main = V._butter(main, "high", 70)
	# escala do bus de ecos: soma dos ecos fica bus_db abaixo da principal (RMS)
	soma = np.sum([e for e, _ in ecos], axis=0)
	k = rms(main) * 10 ** (L["bus_db"] / 20) / max(rms(soma), 1e-9)
	main_r = rev(main, kind, wet_m)
	m = len(main_r)
	if not stereo:
		eco_r = rev(pad(soma * k, n), kind, wet_e)
		out = pad(main_r, m) + pad(eco_r, m)
		return out.astype(np.float32)
	esq = pad(main_r, m).copy()
	dir_ = pad(main_r, m).copy()
	for e, pan in ecos:
		er = pad(rev(e * k, kind, wet_e), m)
		a = (pan + 1) / 2 * np.pi / 2
		esq += er * np.cos(a) * 1.41
		dir_ += er * np.sin(a) * 1.41
	return np.stack([esq, dir_], axis=1).astype(np.float32)


def fx(x, preset, mode, stereo=False):
	hp = lambda y, f: V._butter(y, "high", f)
	if preset == "sophia":
		if mode == "pensamento":
			return V.gain_db(rev(V._butter(hp(x, 120), "low", 7000), "sala", 0.18), -2) if hasattr(V, "gain_db") else rev(V._butter(hp(x, 120), "low", 7000), "sala", 0.18) * 0.8
		return rev(hp(x, 75), "sala", 0.07)
	if preset == "a_voz":
		y = V.doubler(hp(x, 70), 2, 7, 14, 0.30)
		return rev(y, "placa", 0.13)
	if preset.startswith("legiao"):
		return legiao(x, int(preset[-1]), stereo)
	if preset == "narrador":
		return rev(V._shelf_low(hp(x, 60), 150, 2.0), "capela", 0.09)
	if preset == "estela":
		return rev(V._butter(V._shelf_low(hp(x, 60), 150, 1.5), "low", 6500), "catedral", 0.2)
	if preset == "athoth":
		return rev(V._butter(V.whisper(hp(x, 80), 0.25), "low", 6000), "salao", 0.22)
	if preset == "harmas":
		return rev(V.drive(V._shelf_low(hp(x, 60), 160, 3.0), 2.0, 0.25), "sala", 0.12)
	if preset == "galila":
		return rev(V.metal(hp(x, 90), 0.3), "sala", 0.05)
	if preset == "yabel":
		return rev(V.whisper(hp(x, 100), 0.55), "catedral", 0.22)
	if preset == "astaphaios":
		y = V.pitch_shift(x, -3, "shifted")
		return rev(V.mirror(hp(y, 80), 0.5), "salao", 0.14)
	if preset == "belias":
		return rev(V._butter(V.wobble(hp(x, 70), 0.0025, 0.7), "low", 5000), "pantano", 0.2)
	if preset == "armupiel":
		return rev(V.octave(V._shelf_low(hp(x, 60), 140, 2.0), -12, 0.12), "salao", 0.22)
	if preset == "soter":
		return rev(hp(x, 70), "capela", 0.12)
	if preset == "velkar":
		return rev(V.drive(hp(x, 70), 1.5, 0.15), "sala", 0.1)
	if preset == "aneis":
		return rev(V._butter(V.whisper(hp(x, 200), 0.4), "low", 5000), "catedral", 0.35)
	if preset == "cego":
		return rev(V.pitch_shift(hp(x, 80), 6, "shifted"), "sala", 0.18) * 0.8
	if preset == "cru":
		return hp(x, 60)
	return rev(hp(x, 70), "sala", 0.08)   # "comum"


def short_term_max(x):
	import pyloudnorm as pyln
	mono = x if x.ndim == 1 else x.mean(axis=1)
	meter = pyln.Meter(SR, block_size=0.4)
	w = int(3 * SR)
	if len(mono) <= w:
		try:
			return float(meter.integrated_loudness(np.pad(mono, (0, max(0, int(0.5 * SR) - len(mono))))))
		except Exception:
			return float("nan")
	best = -99.0
	for i in range(0, len(mono) - w + 1, int(0.25 * SR)):
		try:
			v = meter.integrated_loudness(mono[i:i + w].astype(np.float64))
			if np.isfinite(v):
				best = max(best, v)
		except Exception:
			pass
	return best


def loud(x, alvo):
	import pyloudnorm as pyln
	meter = pyln.Meter(SR)
	f = int(SR * 0.012)
	x = x.copy()
	x[:f] *= np.linspace(0, 1, f)[:, None] if x.ndim > 1 else np.linspace(0, 1, f)
	ft = int(SR * 0.08)
	x[-ft:] *= np.linspace(1, 0, ft)[:, None] if x.ndim > 1 else np.linspace(1, 0, ft)
	v = meter.integrated_loudness(x.astype(np.float64))
	if np.isfinite(v):
		x = (x * 10 ** ((alvo - v) / 20)).astype(np.float32)
	if x.ndim == 1:
		return V.tp_limit(x, V.TP_PRE_DB)
	g = np.minimum(1.0, 10 ** (V.TP_PRE_DB / 20) / (np.max(np.abs(x)) * 1.12 + 1e-9))
	return (x * g).astype(np.float32)


def write_ogg(x, path):
	if x.ndim == 1:
		return V.write_ogg(x, path)
	import subprocess, tempfile
	with tempfile.TemporaryDirectory() as td:
		a = os.path.join(td, "a.wav")
		sf.write(a, x, SR, subtype="PCM_16")
		subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", a, "-c:a", "libvorbis", "-q:a", "5", str(path)], check=True)
	y, _ = sf.read(str(path), dtype="float32")
	return max(V.true_peak_db(y[:, 0]), V.true_peak_db(y[:, 1]))


def trim_lead(x):
	"""Silêncio no começo ≤ 80 ms e no fim ≤ 250 ms (contrato)."""
	y = V.trim(x, -42, 50)
	return y


def processa(it):
	lang = it.get("lang", "pt")
	cands = []
	for c in it["cands"]:
		if not os.path.exists(c):
			continue
		w, sr = sf.read(c, dtype="float32")
		if w.ndim > 1:
			w = w.mean(axis=1)
		if sr != SR:
			w = librosa.resample(w, orig_sr=sr, target_sr=SR)
		meta = {}
		mj = c[:-4] + ".json"
		if os.path.exists(mj):
			meta = json.load(open(mj, encoding="utf-8"))
		words = asr(w, lang)
		hyp = " ".join(t for t, _, _ in words)
		e = cer(it["said"], hyp)
		cands.append({"wav": c, "x": w, "words": words, "hyp": hyp, "cer": e, "sim": meta.get("spk_sim")})
	if not cands:
		return {"key": it["key"], "ok": False, "motivo": "sem candidato"}
	sim_min = it.get("sim_min", 0.0)
	# nota: CER manda; similaridade abaixo do piso desclassifica; empate: maior similaridade
	def nota(c):
		pen = 1.0 if (c["sim"] is not None and c["sim"] < sim_min) else 0.0
		return (c["cer"] > CER_RAW_OK) * 1.0 + pen + c["cer"] - 0.05 * (c["sim"] or 0)
	cands.sort(key=nota)
	b = cands[0]
	x = cut_tail(b["x"], b["words"], it["said"])
	x = trim_lead(x)
	MODO["combate"] = bool(it.get("combate"))
	teto = {"combate": 2.5, "morte_chefe": 3.0}.get(it.get("onde", ""), 12.0)
	d0 = len(x) / SR
	if d0 > teto and d0 / teto <= 1.2:  # acelera no máximo 20% para caber na janela do Guardião
		x = V.time_stretch(x, d0 / teto)
	y = fx(x, it["fx"], it.get("mode", "fala"), it.get("stereo", False))
	y = V.trim(y, -50, 40) if y.ndim == 1 else y
	alvo = GRITO_LUFS if it.get("grito") else NORMAL_LUFS
	y = loud(y, alvo)
	os.makedirs(os.path.dirname(it["out"]), exist_ok=True)
	tp = write_ogg(y, it["out"])
	z, _ = sf.read(it["out"], dtype="float32")
	zm = z if z.ndim == 1 else z.mean(axis=1)
	words2 = asr(zm, lang)
	hyp2 = " ".join(t for t, _, _ in words2)
	e2 = cer(it["said"], hyp2)
	lim = CER_POS_OK_LEGIAO if it["fx"] in ("legiao3", "legiao5") else CER_POS_OK
	import pyloudnorm as pyln
	r = {"key": it["key"], "out": it["out"], "wav": b["wav"], "dur": round(len(zm) / SR, 2), "cer_cru": round(b["cer"], 3),
		"cer_pos": round(e2, 3), "asr_pos": hyp2, "spk_sim": b["sim"], "tp": round(tp, 2),
		"lufs_i": round(float(pyln.Meter(SR).integrated_loudness(zm.astype(np.float64))), 1), "lufs_s_max": round(short_term_max(z), 1),
		"nivel": it.get("nivel"), "onde": it.get("onde"), "grito": bool(it.get("grito")),
		"cands": [{"wav": os.path.basename(c["wav"]), "cer": round(c["cer"], 3), "sim": c["sim"]} for c in cands],
		"ok": bool(e2 <= lim and b["cer"] <= 0.2 and tp <= V.TP_MAX_DB + 0.05 and not (b["sim"] is not None and b["sim"] < sim_min))}
	json.dump(r, open(it["out"] + ".qa.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
	return r


def main():
	sys.stdout.reconfigure(encoding="utf-8")
	job = json.load(open(sys.argv[1], encoding="utf-8"))
	force = "--force" in sys.argv
	res = []
	for it in job["items"]:
		q = it["out"] + ".qa.json"
		if os.path.exists(it["out"]) and os.path.exists(q) and not force:
			r = json.load(open(q, encoding="utf-8"))
			if r.get("ok") or not it.get("retry_failed"):
				res.append(r)
				continue
		r = processa(it)
		res.append(r)
		print("%s %-14s cer %.2f→%.2f sim %s tp %.1f Lint %.1f Smax %.1f %.1fs %s | %s" % (
			"OK " if r.get("ok") else "RUIM", it["key"][:14], r.get("cer_cru", 1), r.get("cer_pos", 1), r.get("spk_sim"), r.get("tp", 0),
			r.get("lufs_i", 0), r.get("lufs_s_max", 0), r.get("dur", 0), os.path.basename(it["out"]), r.get("asr_pos", "")), flush=True)
	json.dump(res, open(sys.argv[1][:-5] + "_res.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
	print("FIM %d itens, %d ok" % (len(res), sum(1 for r in res if r.get("ok"))))


if __name__ == "__main__":
	main()
