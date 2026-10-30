# Conversão de timbre ChatterboxVC (MIT) na GPU (venv-rocm). Entrada: JSON [[fonte, alvo_timbre, saida], ...]. Retomável.
import os, sys, json
sys.stdout.reconfigure(encoding="utf-8")
os.environ["HF_HOME"] = r"C:\Users\jmtat\gnosis-tools\voice\hf"; os.environ["HF_HUB_OFFLINE"] = "1"
import numpy as np, soundfile as sf, torch
torch.backends.cudnn.enabled = False
from pathlib import Path
from safetensors.torch import load_file
from chatterbox.vc import ChatterboxVC
from chatterbox.models.s3gen import S3Gen
lst = [x for x in json.load(open(sys.argv[1], encoding="utf-8")) if not os.path.exists(x[2])]
print("cbx: %d" % len(lst), flush=True)
if lst:
	base = next((Path(os.environ["HF_HOME"]) / "hub/models--ResembleAI--chatterbox/snapshots").iterdir())
	s3 = S3Gen(); s3.load_state_dict(load_file(base / "s3gen_v3.safetensors"), strict=False); s3.to("cuda").eval()
	vc = ChatterboxVC(s3, "cuda")
	for src, alvo, out in lst:
		w = vc.generate(src, target_voice_path=alvo).squeeze().cpu().numpy().astype(np.float32)
		os.makedirs(os.path.dirname(out), exist_ok=True)
		sf.write(out, w, vc.sr, subtype="PCM_16")
print("FIM cbx")
