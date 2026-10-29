# Baixa o Qwen3-TTS Base (clonagem da voz PROJETADA — sintética) para o HF_HOME.
import os
os.environ["HF_HOME"] = r"C:\Users\jmtat\gnosis-tools\voice\hf"
from huggingface_hub import snapshot_download, model_info
repo = "Qwen/Qwen3-TTS-12Hz-1.7B-Base"
info = model_info(repo)
print("licenca:", [t for t in info.tags if t.startswith("license")])
p = snapshot_download(repo, max_workers=1)
print(repo, "->", p)
