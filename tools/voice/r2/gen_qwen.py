# Gerador GPU do GNOSIS (Qwen3-TTS, Apache-2.0). Ferramenta OFFLINE.
#   design: cria a voz-base de um personagem por DESCRIÇÃO (VoiceDesign) — sintética, ninguém clonado.
#   clone : fala as linhas do jogo com a voz-base FIXA do personagem (Base, modo ICL com a
#           referência projetada) => mesma voz no jogo todo.
# Entrada: um job JSON {"mode": "design"|"clone", "items": [...]}. Retomável: pula saída existente.
# Cada item: {"out": wav, "text": str, "lang": "pt"|"en", "seed": int,
#             design: "instruct": str | clone: "ref_wav": str, "ref_text": str}
# Grava ao lado de cada wav um .json com dur e similaridade de locutor (cosseno vs referência).
# Uso: python -I gen_qwen.py job.json [--batch 4] [--prio normal]
import os, sys, json, time, ctypes

os.environ["HF_HOME"] = r"C:\Users\jmtat\gnosis-tools\voice\hf"
os.environ["HF_HUB_OFFLINE"] = "1"
os.environ.setdefault("OMP_NUM_THREADS", "4")
if "--prio" in sys.argv and sys.argv[sys.argv.index("--prio") + 1] == "normal":
	pass
else:
	ctypes.windll.kernel32.SetPriorityClass(ctypes.windll.kernel32.GetCurrentProcess(), 0x4000)

import numpy as np
import torch
import soundfile as sf
import librosa

torch.set_num_threads(4)
torch.backends.cudnn.enabled = False  # MIOpen quebra convoluções no ROCm-Windows

HUB = r"C:\Users\jmtat\gnosis-tools\voice\hf\hub"
MODELOS = {
	"design": HUB + r"\models--Qwen--Qwen3-TTS-12Hz-1.7B-VoiceDesign\snapshots\5ecdb67327fd37bb2e042aab12ff7391903235d3",
	"clone": HUB + r"\models--Qwen--Qwen3-TTS-12Hz-1.7B-Base\snapshots\fd4b254389122332181a7c3db7f27e918eec64e3",
}
LANG = {"pt": "Portuguese", "en": "English"}


def arg(nome, padrao):
	return sys.argv[sys.argv.index(nome) + 1] if nome in sys.argv else padrao


def mono(w):
	w = np.asarray(w, dtype=np.float32)
	if w.ndim > 1:
		w = w.mean(axis=-1) if w.shape[-1] <= 2 else w.mean(axis=0)
	return w


def max_tok(texto):
	# 12,5 tokens/s; fala dramática ~9 caracteres/s; folga 2x + 3 s
	return int(min(2048, 12.5 * (len(texto) / 9.0 * 2.0 + 3.0)))


def main():
	job = json.load(open(sys.argv[1], encoding="utf-8"))
	mode = job["mode"]
	B = int(arg("--batch", "4"))
	itens = [it for it in job["items"] if not os.path.exists(it["out"])]
	print("job %s: %d itens (%d já prontos)" % (mode, len(itens), len(job["items"]) - len(itens)), flush=True)
	if not itens:
		return
	from qwen_tts import Qwen3TTSModel
	t0 = time.time()
	model = Qwen3TTSModel.from_pretrained(MODELOS[mode], device_map="cuda:0", dtype=torch.bfloat16, attn_implementation="sdpa")
	print("modelo %.0f s" % (time.time() - t0), flush=True)
	prompts = {}   # ref_wav -> VoiceClonePromptItem (cache)
	spk_ref = {}

	def emb(w, sr):
		if not hasattr(model, "model") or not hasattr(model.model, "extract_speaker_embedding"):
			return None
		ssr = model.model.speaker_encoder_sample_rate
		x = librosa.resample(w, orig_sr=sr, target_sr=ssr) if sr != ssr else w
		e = model.model.extract_speaker_embedding(audio=x, sr=ssr)
		e = e.float().cpu().numpy().ravel() if hasattr(e, "cpu") else np.asarray(e).ravel()
		return e / (np.linalg.norm(e) + 1e-9)

	# agrupa por (ref, seed) para lotes homogêneos
	grupos = {}
	for it in itens:
		k = (it.get("ref_wav", ""), 0)  # lote misto: a "semente" do item vira só um número de tomada
		grupos.setdefault(k, []).append(it)
	t_gen = 0.0
	d_tot = 0.0
	for (ref, seed), lst in grupos.items():
		for i in range(0, len(lst), B):
			lote = lst[i:i + B]
			seed = 1000 * i + sum(it["seed"] for it in lote)
			torch.manual_seed(seed)
			torch.cuda.manual_seed_all(seed)
			mt = max(max_tok(it["text"]) for it in lote)
			t1 = time.time()
			if mode == "design":
				wavs, sr = model.generate_voice_design(text=[it["text"] for it in lote], language=[LANG[it["lang"]] for it in lote],
					instruct=[it["instruct"] for it in lote], max_new_tokens=mt)
			else:
				if ref not in prompts:
					prompts[ref] = model.create_voice_clone_prompt(ref_audio=ref, ref_text=lote[0]["ref_text"])[0]
					rw, rsr = sf.read(ref, dtype="float32")
					spk_ref[ref] = emb(mono(rw), rsr)
				wavs, sr = model.generate_voice_clone(text=[it["text"] for it in lote], language=[LANG[it["lang"]] for it in lote],
					voice_clone_prompt=[prompts[ref]] * len(lote), max_new_tokens=mt)
			dt = time.time() - t1
			t_gen += dt
			for it, w in zip(lote, wavs):
				w = mono(w)
				d = len(w) / sr
				d_tot += d
				os.makedirs(os.path.dirname(it["out"]), exist_ok=True)
				tmp = it["out"] + ".tmp.wav"
				sf.write(tmp, w, sr, subtype="PCM_16")
				os.replace(tmp, it["out"])
				meta = {"dur": round(d, 3), "sr": sr, "seed": seed, "t_gen_lote": round(dt, 2)}
				if mode == "clone" and spk_ref.get(ref) is not None:
					e = emb(w, sr)
					meta["spk_sim"] = round(float(np.dot(e, spk_ref[ref])), 4)
				json.dump(meta, open(it["out"][:-4] + ".json", "w", encoding="utf-8"))
			print("lote %d itens seed %d: %.1f s de áudio em %.1f s (RTF %.2f) %s" % (len(lote), seed, sum(len(mono(w)) for w in wavs) / sr, dt,
				dt / max(1e-6, sum(len(mono(w)) for w in wavs) / sr), os.path.basename(lote[0]["out"])), flush=True)
	print("FIM: %.0f s de áudio, %.0f s de GPU, RTF %.2f" % (d_tot, t_gen, t_gen / max(d_tot, 1e-6)), flush=True)


if __name__ == "__main__":
	main()
