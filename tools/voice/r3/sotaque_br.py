# Checagem OBJETIVA de sotaque PT-BR (palavra por palavra). Ferramenta offline; nunca toca áudio.
# Entrada: o JSON do fonemas.py (fonemas IPA com tempo, wav2vec2 XLSR-53 espeak, Apache-2.0) + o texto.
# O Whisper dá o tempo de cada palavra; os fonemas dentro dela são comparados com as marcas do Brasil:
#   e_final  — "e" átono no fim (de, gente, noite, estive): Brasil = [i]; leitura/Portugal = [e]/[ɨ]/some
#   o_final  — "o" átono no fim (tudo, medo, tempo): Brasil e Portugal = [u]; leitura "de professora" = [o]
#   palat    — "ti/di" e "-te/-de" finais: Brasil = [tʃ]/[dʒ] ("tchi/dji"); Portugal/leitura = [t]/[d]
#   schwa    — qualquer [ɨ] na fala (marca forte do europeu)
# nota_br = média(e_final, o_final, palat) − 0,5·schwa_por_palavra ; >= 0,65 brasileiro claro; < 0,45 não-BR.
# Uso: python -I sotaque_br.py <fonemas.json> [--out res.json]
import os, sys, json, re
sys.path.insert(0, r"C:\gnosis-wt\_caps\dublagem\r2\_scripts\prod")
import numpy as np
import soundfile as sf
import librosa
import post_qa as Q
from asr_check import norm

ATONAS_E = {"de", "te", "se", "me", "lhe", "que", "e"}


def palavras_txt(t):
	t = t.lower().replace("—", " ")
	return [w for w in re.sub(r"[^a-záéíóúâêôãõàçü\s-]", " ", t).split() if w]


def mede(wav, texto, fon):
	x, sr = sf.read(wav, dtype="float32")
	if x.ndim > 1:
		x = x.mean(axis=1)
	if sr != Q.SR:
		x = librosa.resample(x, orig_sr=sr, target_sr=Q.SR)
	ws = Q.asr(x, "pt")
	tempos = fon["tempos"]
	esperadas = set(palavras_txt(texto))
	ef, of, pl, det = [], [], [], []
	sch = sum(1 for t, _ in tempos if t == "ɨ")
	for k, (w, a, b) in enumerate(ws):
		n = norm(w)
		if not n or n not in esperadas:
			continue
		ph = [t for t, tt in tempos if a - 0.02 <= tt <= b + 0.04]
		if not ph:
			continue
		vog = [t for t in ph if re.match(r"^[aeiouɐɛɔəɨɪʊ]", t)]
		ult = vog[-1] if vog else ""
		if (n in ATONAS_E or (len(n) > 3 and n.endswith("e") and not n.endswith(("é", "ê")))) and n != "e":
			v = 1.0 if ult.startswith(("i", "ɪ", "j")) else 0.0
			ef.append(v); det.append((n, "e→" + (ult or "∅"), v))
		if len(n) > 2 and n.endswith("o") and not n.endswith(("ó", "ô")) and n not in ("não",):
			v = 1.0 if ult.startswith(("u", "ʊ", "w")) else 0.0
			of.append(v); det.append((n, "o→" + (ult or "∅"), v))
		if re.search(r"[td]i|[td]e$", n):
			j = "".join(ph)
			v = 1.0 if ("tʃ" in j or "dʒ" in j) else 0.0
			pl.append(v); det.append((n, "palat:" + ("sim" if v else "não"), v))
	m = lambda l: float(np.mean(l)) if l else None
	r = {"e_final": m(ef), "o_final": m(of), "palat": m(pl), "n": [len(ef), len(of), len(pl)], "schwa": sch,
		"asr": " ".join(w for w, _, _ in ws), "detalhe": det}
	vs = [v for v in (r["e_final"], r["o_final"], r["palat"]) if v is not None]
	r["nota_br"] = round(float(np.mean(vs)) - 0.5 * min(1.0, sch / max(1, len(ws))), 2) if vs else None
	return r


def main():
	sys.stdout.reconfigure(encoding="utf-8")
	fon = json.load(open(sys.argv[1], encoding="utf-8"))
	mapa = json.load(open(sys.argv[1].replace("_fon.json", "_mapa.json"), encoding="utf-8")) if os.path.exists(sys.argv[1].replace("_fon.json", "_mapa.json")) else None
	out = {}
	f = lambda v: "—" if v is None else "%.2f" % v
	for wav, fr in fon.items():
		texto = mapa[wav] if mapa else ""
		r = mede(wav, texto, fr)
		out[wav] = r
		print("%-26s BR=%s  e→i %s  o→u %s  tchi/dji %s  ɨ %d  n=%s" % (os.path.basename(wav), f(r["nota_br"]), f(r["e_final"]), f(r["o_final"]), f(r["palat"]), r["schwa"], r["n"]), flush=True)
	if "--out" in sys.argv:
		json.dump(out, open(sys.argv[sys.argv.index("--out") + 1], "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
	main()
