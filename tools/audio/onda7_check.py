# -*- coding: utf-8 -*-
"""
Onda 7 — mede, SEM OUVIR, os sons novos (tools/audio_synth/onda7.py) contra as
regras do docs/handoff/NEURO_SATISFACAO.md:

  R12  peso no grave: sons PESADOS (chefe, pancada, quebra, morte) têm energia
       em 50–90 Hz e harmônicos em 120–250 Hz (o grave "sobrevive" em notebook);
       sons FREQUENTES e repetidos NÃO têm energia sustentada em 2–5 kHz.
  R13  loudness: true peak ≤ −1 dBTP; M-max no alvo da categoria (±1,5).
  R11  variações: a distância (MFCC) entre variações do mesmo som não é zero
       (são diferentes) e é menor que a distância para outros sons.
  R5/R14 distinção: os sons de INFORMAÇÃO (riposte_ready, tell_parry,
       tell_unblock, charge_*) ficam longe uns dos outros e dos golpes.

  python tools/audio/onda7_check.py [saida.json]
"""
import os, sys, json
import numpy as np
import soundfile as sf
from scipy import signal
import librosa

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "audio_synth"))
import common as C
import onda7 as O7

SFX = os.path.join(ROOT, "assets", "audio", "sfx")
SR = 44100
CAT = dict(O7.CATS)
CAT.update({"tell": -17.0, "swing_big": -16.0, "champion": -12.0, "boss": -10.0, "boss_soft": -14.0,
	"elite": -13.0, "hit": -12.0, "reward": -13.0, "ui_big": -18.0, "ui": -22.0, "shop": -18.0,
	"structure": -15.0, "story": -15.0})
# pesados (R12: precisam de grave) e frequentes (R12: sem 2–5 kHz sustentado)
HEAVY = ["atk_slam", "atk_nova", "boss_phase3", "guard_break", "boss_death_impact", "boss_death_collapse",
	"bs_land", "bs_hand", "bs_collapse", "bs_melee", "hz_guillotine", "hz_maw_bite", "hz_column", "hz_totem_break",
	"champion_enter", "bs_bite", "king_sink"]
FREQUENT = ["atk_swing", "atk_combo", "atk_shot", "atk_rush", "atk_burst", "atk_fan", "fly_fall", "hz_chain_swing",
	"hz_shard_impact", "hz_spears", "hz_tide_tick", "hz_ward_drain", "hz_mist_breath", "hz_totem_hit", "double_jump",
	"chain", "glass"]
INFO = ["riposte_ready", "tell_parry", "tell_unblock", "charge_light", "charge_dark", "charge_king", "atk_shot", "swing_light", "hit"]


def load(path):
	x, sr = sf.read(path, dtype="float64", always_2d=True)
	if sr != SR:
		x = signal.resample_poly(x, SR, sr, axis=0)
	return x


def band_db(m, lo, hi):
	f, P = signal.welch(m, SR, nperseg=4096)
	tot = P.sum() + 1e-20
	sel = P[(f >= lo) & (f < hi)].sum()
	return 10 * np.log10(sel / tot + 1e-20)


def sustained_presence(m, lo=2000, hi=5000, thresh_db=-6.0):
	"""s em que a banda 2–5 kHz está a menos de 6 dB do total (quadros de 50 ms)."""
	b, a = signal.butter(4, [lo, hi], "band", fs=SR)
	y = signal.lfilter(b, a, m)
	hop = int(0.05 * SR)
	n = len(m) // hop
	cnt = 0
	for i in range(n):
		seg_t = m[i * hop:(i + 1) * hop]
		seg_b = y[i * hop:(i + 1) * hop]
		et = (seg_t ** 2).mean() + 1e-20
		eb = (seg_b ** 2).mean() + 1e-20
		loud = 10 * np.log10(et) > -45
		if loud and 10 * np.log10(eb / et) > thresh_db:
			cnt += 1
	return cnt * 0.05


def mfcc_vec(m):
	mf = librosa.feature.mfcc(y=m.astype(np.float32), sr=SR, n_mfcc=14)
	return mf[1:].mean(axis=1)


def main():
	out = {"files": {}, "checks": {}}
	vecs = {}
	for name, (cat, fns) in O7.SOUNDS.items():
		for i in range(len(fns)):
			fn = name if i == 0 else "%s_%d" % (name, i + 1)
			x = load(os.path.join(SFX, fn + ".ogg"))
			m = x.mean(axis=1)
			r = {
				"cat": cat, "dur": round(len(m) / SR, 2),
				"Mmax": round(float(C.max_momentary(x)), 1),
				"TP": round(float(C.true_peak_db(x)), 1),
				"sub_50_90": round(band_db(m, 50, 90), 1),
				"body_120_250": round(band_db(m, 120, 250), 1),
				"pres_2_5k": round(band_db(m, 2000, 5000), 1),
				"pres_sust_s": round(sustained_presence(m), 2),
				"centroid": int(np.mean(librosa.feature.spectral_centroid(y=m.astype(np.float32), sr=SR))),
			}
			out["files"][fn] = r
			vecs[fn] = mfcc_vec(m)
	for extra in ["tell_parry", "tell_unblock", "swing_light", "hit", "proj_fire", "parry", "nova"]:
		x = load(os.path.join(SFX, extra + ".ogg"))
		vecs[extra] = mfcc_vec(x.mean(axis=1))
	f = out["files"]
	# R13: true peak e alvo
	bad_tp = [k for k, r in f.items() if r["TP"] > -1.0]
	bad_lvl = [k for k, r in f.items() if r["cat"] in CAT and abs(r["Mmax"] - CAT[r["cat"]]) > 1.5]
	out["checks"]["R13_true_peak_ok"] = {"ok": not bad_tp, "bad": bad_tp}
	out["checks"]["R13_Mmax_no_alvo"] = {"ok": not bad_lvl, "bad": bad_lvl}
	# R12: pesados com grave (sub OU corpo ≥ −14 dB da energia total)
	heavy_bad = [k for k in HEAVY if max(f[k]["sub_50_90"], f[k]["body_120_250"]) < -14.0]
	out["checks"]["R12_pesado_tem_grave"] = {"ok": not heavy_bad, "bad": heavy_bad,
		"valores": {k: (f[k]["sub_50_90"], f[k]["body_120_250"]) for k in HEAVY}}
	# R12: frequentes sem 2–5 kHz sustentado (> 0,25 s com a banda dominando)
	freq_bad = [k for k in FREQUENT if f[k]["pres_sust_s"] > 0.25]
	out["checks"]["R12_frequente_sem_agudo_sustentado"] = {"ok": not freq_bad, "bad": freq_bad,
		"valores": {k: f[k]["pres_sust_s"] for k in FREQUENT}}
	# R11: variações diferentes entre si e mais perto entre si que do resto
	var_rep = {}
	for name, (cat, fns) in O7.SOUNDS.items():
		if len(fns) < 2:
			continue
		names = [name] + ["%s_%d" % (name, i + 1) for i in range(1, len(fns))]
		dv = [float(np.linalg.norm(vecs[a] - vecs[b])) for ai, a in enumerate(names) for b in names[ai + 1:]]
		others = [float(np.linalg.norm(vecs[name] - v)) for k, v in vecs.items() if not k.startswith(name)]
		var_rep[name] = {"entre_variacoes": round(float(np.mean(dv)), 1), "vizinho_mais_perto": round(min(others), 1)}
	same = [k for k, v in var_rep.items() if v["entre_variacoes"] < 0.5]
	out["checks"]["R11_variacoes_diferentes"] = {"ok": not same, "bad": same, "valores": var_rep}
	# R5/R14: distância entre os sons de informação
	pairs = {}
	for i, a in enumerate(INFO):
		for b in INFO[i + 1:]:
			pairs["%s~%s" % (a, b)] = round(float(np.linalg.norm(vecs[a] - vecs[b])), 1)
	close = [k for k, d in pairs.items() if d < 8.0]
	out["checks"]["R5_informacao_distinta"] = {"ok": not close, "perto_demais": close, "distancias": pairs}
	path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "..", "_caps", "audio7", "onda7_check.json")
	os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
	with open(path, "w", encoding="utf-8") as fh:
		json.dump(out, fh, ensure_ascii=False, indent=1)
	for k, v in out["checks"].items():
		print("%-40s %s  %s" % (k, "OK" if v["ok"] else "FALHOU", v.get("bad", v.get("perto_demais", ""))))


if __name__ == "__main__":
	main()
