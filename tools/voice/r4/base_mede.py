# Escolhe o conversor de cada voz-base (venv-rocm): mede (1) similaridade de locutor com o alvo (VoiceEncoder do
# Chatterbox, MIT) e (2) o "s" ANTES/DEPOIS da conversão nos MESMOS quadros de fricativa (centroide 1,5-10,5 kHz).
# Regra: ChatterboxVC (opção 2, a do João) por padrão; OpenVoice (opção 3) se o ChatterboxVC escurecer o "s"
# (queda > 700 Hz ou > +25 pontos de quadros abaixo de 4,8 kHz) e o OpenVoice não. Grava elenco_r4.json.
import os, sys, json
sys.stdout.reconfigure(encoding="utf-8")
os.environ["HF_HOME"] = r"C:\Users\jmtat\gnosis-tools\voice\hf"; os.environ["HF_HUB_OFFLINE"] = "1"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np, soundfile as sf, librosa, torch
from pathlib import Path
from chatterbox.models.voice_encoder import VoiceEncoder
import r4lib as L
base = next((Path(os.environ["HF_HOME"]) / "hub/models--ResembleAI--chatterbox/snapshots").iterdir())
ve = VoiceEncoder(); ve.load_state_dict(torch.load(base / "ve.pt", map_location="cpu", weights_only=True)); ve.eval()
def emb(f):
	x, _ = librosa.load(f, sr=16000); e = np.asarray(ve.embeds_from_wavs([x], sample_rate=16000)).ravel(); return e / np.linalg.norm(e)
def S(f):
	x, sr = librosa.load(f, sr=22050); return np.abs(librosa.stft(x, n_fft=1024, hop_length=220)) ** 2
fr = librosa.fft_frequencies(sr=22050, n_fft=1024); band = (fr > 1500) & (fr < 10500)
def sib(src, conv):
	a = S(src); lo = a[fr < 1000].sum(0); hi = a[fr > 3000].sum(0); db = 10 * np.log10(a.sum(0) + 1e-12)
	idx = np.where((hi > 6 * lo) & (db > db.max() - 30))[0]
	out = []
	for X in (a, S(conv)):
		i2 = idx[idx < X.shape[1]]; B = X[band][:, i2]; c = (B * fr[band][:, None]).sum(0) / (B.sum(0) + 1e-12)
		out.append((float(np.median(c)), float(np.mean(c < 4800) * 100)))
	return out
el = {}
for voz, (kv, sp, alvo, ref) in L.VOZES.items():
	b = L.W + "base/" + voz
	ea = emb(alvo)
	sim = {k: round(float(np.dot(emb(b + "_%s_ref.wav" % k), ea)), 3) for k in ("k", "cbx", "ov")}
	(c0, p0), (c1, p1) = sib(b + "_k_diag.wav", b + "_cbx_diag.wav")
	_, (c2, p2) = sib(b + "_k_diag.wav", b + "_ov_diag.wav")
	ruim = lambda c, p: (c0 - c > 700) or (p - p0 > 25)
	conv = "ov" if (ruim(c1, p1) and not ruim(c2, p2)) else "cbx"
	el[voz] = {"kokoro": kv, "vel": sp, "alvo": alvo, "conv": conv, "sim": sim,
		"s_hz": {"fonte": int(c0), "cbx": int(c1), "ov": int(c2)}, "s_chiado_pct": {"fonte": round(p0), "cbx": round(p1), "ov": round(p2)},
		"ref_wav": b + "_%s_ref.wav" % conv, "ref_texto": ref}
	print("%-11s conv=%-3s sim k/cbx/ov %.2f/%.2f/%.2f | s Hz fonte %d cbx %d ov %d | <4,8k %d%% %d%% %d%%" % (voz, conv, sim["k"], sim["cbx"], sim["ov"], c0, c1, c2, p0, p1, p2), flush=True)
json.dump(el, open(L.ELENCO, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
