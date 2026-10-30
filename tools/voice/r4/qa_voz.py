# QA "mesma voz" (venv-rocm): similaridade de locutor de cada fala final com a voz-base fixa do personagem
# (VoiceEncoder do Chatterbox, MIT). A narradora é a Sophia mais grave (efeito), então a nota dela é só informativa.
import os, sys, json
sys.stdout.reconfigure(encoding="utf-8")
os.environ["HF_HOME"] = r"C:\Users\jmtat\gnosis-tools\voice\hf"; os.environ["HF_HUB_OFFLINE"] = "1"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np, librosa, torch
from pathlib import Path
from chatterbox.models.voice_encoder import VoiceEncoder
import r4lib as L
base = next((Path(os.environ["HF_HOME"]) / "hub/models--ResembleAI--chatterbox/snapshots").iterdir())
ve = VoiceEncoder(); ve.load_state_dict(torch.load(base / "ve.pt", map_location="cpu", weights_only=True)); ve.eval()
def emb(f):
	x, _ = librosa.load(f, sr=16000); e = np.asarray(ve.embeds_from_wavs([x], sample_rate=16000)).ravel(); return e / np.linalg.norm(e)
el = L.elenco(); falas = json.load(open(L.W + "falas_limiar2.json", encoding="utf-8"))
ref = {v: emb(el[v]["ref_wav"]) for v in ("sophia", "demiurgo")}
res = {}
for f in falas:
	q = json.load(open(L.W + "amostra/%s_%s.ogg.qa.json" % (f["num"], f["quem"].lower()), encoding="utf-8"))
	o = q["wav"].replace("/monta/", "/raw/").replace("_t", "_v") if "--cru" in sys.argv else L.W + "amostra/%s_%s.ogg" % (f["num"], f["quem"].lower())
	res[f["num"]] = round(float(np.dot(emb(o), ref[f["voz"]])), 3)
json.dump(res, open(L.W + ("qa_voz_cru.json" if "--cru" in sys.argv else "qa_voz.json"), "w"), indent=1)
por = {}
for f in falas:
	por.setdefault(f["quem"], []).append(res[f["num"]])
for q, v in por.items():
	print("%-10s n=%d sim min %.3f média %.3f" % (q, len(v), min(v), sum(v) / len(v)))
