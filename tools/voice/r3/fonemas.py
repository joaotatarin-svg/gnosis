# Sotaque PT-BR × PT-PT por FONEMAS (reconhecedor wav2vec2 XLSR-53 espeak, Apache-2.0; só QA offline).
# Pistas contadas na transcrição fonética, normalizadas pelas OPORTUNIDADES do texto:
#   palat = (tʃ + dʒ) / nº de "de/te/di/ti"  -> Brasil ~1 (dji/tchi); Portugal ~0
#   schwa = ɨ / nº de "e" átono final        -> Portugal alto (ɨ ou apagado); Brasil ~0 (vira i)
#   chiado= ʃ / nº de S em coda              -> Portugal e Rio ~1; paulista ~0 (só informativo)
# nota_br = média(palat, 1 - schwa) ; >= 0,6 => brasileiro, <= 0,4 => europeu.
# Uso: python -I fonemas.py <texto|@arquivo.json> <wav...>   (json: {"wav": "texto", ...})
import os, sys, json, re, glob, ctypes
os.environ["HF_HOME"] = r"C:\Users\jmtat\gnosis-tools\voice\hf"
os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["OMP_NUM_THREADS"] = "4"
os.environ["MKL_NUM_THREADS"] = "4"
ctypes.windll.kernel32.SetPriorityClass(ctypes.windll.kernel32.GetCurrentProcess(), 0x4000)
import numpy as np
import soundfile as sf
import librosa
import torch
torch.set_num_threads(4)
DEV = "cuda" if torch.cuda.is_available() else "cpu"
if DEV == "cuda":
	torch.backends.cudnn.enabled = False  # ROCm-Windows
from transformers import Wav2Vec2FeatureExtractor, Wav2Vec2ForCTC

M = r"C:\Users\jmtat\gnosis-tools\voice\hf\hub\models--facebook--wav2vec2-xlsr-53-espeak-cv-ft\snapshots\2c733782da5604684829819a5eb744c193fe9398"
_p = _m = None


def ipa(path):
	global _p, _m
	if _m is None:
		_p = Wav2Vec2FeatureExtractor.from_pretrained(M)  # sem o tokenizer (pediria o phonemizer): decodifica pelo vocab
		_m = Wav2Vec2ForCTC.from_pretrained(M).eval().to(DEV)
		voc = json.load(open(os.path.join(M, "vocab.json"), encoding="utf-8"))
		_m._inv = {v: k for k, v in voc.items()}
	x, sr = sf.read(path, dtype="float32")
	if x.ndim > 1:
		x = x.mean(axis=1)
	x = librosa.resample(x, orig_sr=sr, target_sr=16000)
	with torch.no_grad():
		lg = _m(_p(x, sampling_rate=16000, return_tensors="pt").input_values.to(DEV)).logits.float().cpu()
	ids = torch.argmax(lg, dim=-1)[0].tolist()
	out, prev = [], None
	TEMPOS.clear()
	for k, i in enumerate(ids):   # CTC guloso: junta repetidos, tira o branco
		if i != prev:
			t = _m._inv.get(i, "")
			if t not in ("<pad>", "<s>", "</s>", "<unk>"):
				out.append(t)
				TEMPOS.append((t, round(k * 0.02, 3)))
		prev = i
	return " ".join(out)


TEMPOS = []


def oportunidades(texto):
	t = texto.lower()
	t = re.sub(r"[^a-záéíóúâêôãõàç\s-]", " ", t)
	pal = t.split()
	n_dt = sum(len(re.findall(r"(?:d|t)(?:i|e(?=$))", w)) for w in pal)   # di/ti em qualquer lugar; de/te no fim
	n_e = sum(1 for w in pal if re.search(r"[^aeiouáéíóúâêô]e$", w) and len(w) > 2) + sum(1 for w in pal if w in ("de", "te", "se", "me", "que", "lhe"))
	n_s = 0
	for i, w in enumerate(pal):
		if w.endswith("s") or w.endswith("z"):
			prox = pal[i + 1] if i + 1 < len(pal) else ""
			if not prox or prox[0] not in "aeiouáéíóúâêôãõ":
				n_s += 1
	return n_dt, n_e, n_s


def mede(texto, path):
	f = ipa(path)
	s = f.replace(" ", "")
	n_dt, n_e, n_s = oportunidades(texto)
	af = s.count("tʃ") + s.count("dʒ")
	schwa = s.count("ɨ")
	ch = s.count("ʃ") - s.count("tʃ")
	palat = min(1.0, af / n_dt) if n_dt else None
	sw = min(1.0, schwa / n_e) if n_e else None
	chi = min(1.0, max(0, ch) / n_s) if n_s else None
	vs = [v for v in (palat, None if sw is None else 1 - sw) if v is not None]
	return {"ipa": f, "tempos": list(TEMPOS), "palat": palat, "schwa": sw, "chiado": chi, "n_dt": n_dt, "n_e": n_e, "n_s": n_s,
		"nota_br": round(float(np.mean(vs)), 2) if vs else None}


def main():
	sys.stdout.reconfigure(encoding="utf-8")
	a = sys.argv[1]
	if a.startswith("@"):
		mapa = json.load(open(a[1:], encoding="utf-8"))
		itens = list(mapa.items())
	else:
		itens = [(p, a) for g in sys.argv[2:] for p in sorted(glob.glob(g))]
	out = {}
	for p, texto in itens:
		r = mede(texto, p)
		out[p] = r
		fmt = lambda v: "—" if v is None else "%.2f" % v
		print("%-38s BR=%s  palat %s  schwa %s  chiado %s | %s" % (os.path.basename(p), fmt(r["nota_br"]), fmt(r["palat"]), fmt(r["schwa"]), fmt(r["chiado"]), r["ipa"]), flush=True)
	if "--out" in sys.argv:
		json.dump(out, open(sys.argv[sys.argv.index("--out") + 1], "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
	main()
