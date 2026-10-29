# Troca manual da semente escolhida (critério: tom compatível com o papel — homens graves).
import sys, json, soundfile as sf
sys.path.insert(0, r"C:\gnosis-wt\dublagem\tools\voice")
import voicelib as V
R = r"C:\gnosis-wt\_caps\dublagem\r2\refs"
OV = {"armupiel": "s13", "adormecido": "s11", "harmas": "s11"}
d = json.load(open(R + r"\escolhidas.json", encoding="utf-8"))
for v, s in OV.items():
	c = next(c for c in d[v]["cands"] if c["wav"].endswith("_%s.wav" % s))
	x, sr = sf.read(c["wav"], dtype="float32")
	sf.write(d[v]["wav24"], V.trim(x, -42, 60), V.SR, subtype="PCM_16")
	d[v]["wav"] = c["wav"]
	print(v, c)
json.dump(d, open(R + r"\escolhidas.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
