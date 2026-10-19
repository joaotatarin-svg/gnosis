"""Mede (e com --fix corrige) o pico verdadeiro de .ogg já prontos.
Teto: −1 dBTP no arquivo decodificado (pedido do Guardião, R13 volume/fadiga).

Uso: python tools/voice/tp_fix.py <pasta> [--fix]
"""
from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import soundfile as sf  # noqa: E402
import voicelib as V  # noqa: E402


def main() -> int:
	sys.stdout.reconfigure(encoding="utf-8")
	d = Path(sys.argv[1])
	fix = "--fix" in sys.argv
	acima = 0
	for f in sorted(d.glob("*.ogg")):
		try:
			x, sr = sf.read(str(f), dtype="float32")
		except Exception as e:  # corrompido (processo morto no meio da escrita)
			print("%-34s ILEGÍVEL (%s) — regerar" % (f.name, type(e).__name__))
			continue
		tp = V.true_peak_db(x)
		if tp > V.TP_MAX_DB:
			acima += 1
			if fix:
				tp2 = V.write_ogg(V.tp_limit(x, V.TP_PRE_DB), f)
				print("%-34s %+.2f → %+.2f dBTP" % (f.name, tp, tp2))
			else:
				print("%-34s %+.2f dBTP  ACIMA" % (f.name, tp))
	print("acima de %.1f dBTP: %d" % (V.TP_MAX_DB, acima))
	return 0


if __name__ == "__main__":
	sys.exit(main())
