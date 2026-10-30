# Conversão de timbre OpenVoice v2 (MIT, código e pesos) na CPU (venv principal). Entrada: JSON [[fonte, alvo, saida], ...].
# A "cor" da fonte é medida na referência longa Kokoro da mesma voz (src_ref, opcional 4º campo). Sem marca d'água.
import os, sys, json, types
sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, r"C:\Users\jmtat\gnosis-tools\voice\openvoice\src\OpenVoice-main")
fake = types.ModuleType("openvoice.text"); fake.text_to_sequence = None; sys.modules["openvoice.text"] = fake
_wm = types.ModuleType("wavmark"); _wm.load_model = lambda: types.SimpleNamespace(to=lambda d: None); sys.modules["wavmark"] = _wm
import torch; torch.set_num_threads(4)
from openvoice.api import ToneColorConverter
lst = [x for x in json.load(open(sys.argv[1], encoding="utf-8")) if not os.path.exists(x[2])]
print("ov: %d" % len(lst), flush=True)
if lst:
	CK = r"C:\Users\jmtat\gnosis-tools\voice\openvoice\ckpt\converter"
	tc = ToneColorConverter(CK + r"\config.json", device="cpu"); tc.load_ckpt(CK + r"\checkpoint.pth"); tc.watermark_model = None
	se = {}
	def SE(f):
		if f not in se:
			se[f] = tc.extract_se([f])
		return se[f]
	for it in lst:
		src, alvo, out = it[:3]
		sref = it[3] if len(it) > 3 else src
		os.makedirs(os.path.dirname(out), exist_ok=True)
		tc.convert(audio_src_path=src, src_se=SE(sref), tgt_se=SE(alvo), output_path=out, tau=0.3)
print("FIM ov")
