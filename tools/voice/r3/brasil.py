# "Texto falado" em grafia BRASILEIRA para o TTS (a legenda continua com o texto certo).
# O Qwen3-TTS lê letras e, em português, tende à leitura "de professora"/europeia: "de" [de], "noite"
# [noite], "medo" [medo]. Reescrever o que ele LÊ força a fonética do Brasil (paulista neutro):
#   ti/di -> tchi/dji  ·  -te/-de átonos -> -tchi/-dji  ·  -e átono final -> -i  ·  -o átono final -> -u
# (S final fica [s]; nada de chiado.) Ex.: "de verdade" -> "dji verdadji"; "noite" -> "noitchi".
import re
import unicodedata

_ACENTO = set("áéíóúâêôãõà")
_NAO = {"e", "é", "o", "ó", "não", "nós", "vós", "pô", "só", "lá", "já", "pé", "fé", "dó", "pó", "nó", "tô", "tá"}
_FUNC_E = {"de": "dji", "te": "tchi", "se": "si", "me": "mi", "lhe": "lhi", "que": "qui"}


def _tonica_final(w):
	"""Oxítona sem acento gráfico terminada em e/o é rara; tratamos como paroxítona (átona final)."""
	return any(c in _ACENTO for c in w[-2:])


def _palavra(w):
	lo = w.lower()
	if lo in _FUNC_E:
		r = _FUNC_E[lo]
		return r.capitalize() if w[0].isupper() else r
	if lo in _NAO or len(lo) < 2:
		return w
	s = w
	# -e / -o átonos no fim
	if re.search(r"[^aeiouáéíóúâêôãõ]e$", lo) and not _tonica_final(lo):
		s = s[:-1] + "i"
	elif re.search(r"[^aeiouáéíóúâêôãõ]o$", lo) and not _tonica_final(lo) and len(lo) > 2:
		s = s[:-1] + "u"
	elif lo.endswith("es") and len(lo) > 3 and not _tonica_final(lo[:-1]):
		s = s[:-2] + "is"
	elif lo.endswith("os") and len(lo) > 3 and not _tonica_final(lo[:-1]):
		s = s[:-2] + "us"
	# palatalização: ti/di (inclui os -i recém-criados) -> tchi/dji; não mexe em "tch"/"dj" já feitos
	s = re.sub(r"(?<![sc])t(?=[iíĩ])", "tch", s)
	s = re.sub(r"(?<![sc])T(?=[iíĩ])", "Tch", s)
	s = re.sub(r"d(?=[iíĩ])", "dj", s)
	s = re.sub(r"D(?=[iíĩ])", "Dj", s)
	return s


def falado(texto):
	"""Converte o texto da legenda no texto que o TTS lê (mantém pontuação e pausas)."""
	partes = re.split(r"(\w+)", texto, flags=re.UNICODE)
	return "".join(_palavra(p) if re.match(r"\w", p) else p for p in partes)


if __name__ == "__main__":
	import sys
	sys.stdout.reconfigure(encoding="utf-8")
	for t in ["Você sabe que a gente precisa de tempo de verdade. Hoje à noite, todos os dias parecem iguais, e as pedras do monte não dizem nada.",
			"Ei. Ei! Acorda. ...Isso, devagar. Eu tô aqui.", "Tente. E não tema: um rei jamais se curva.", "Atrás de você. Sempre estivemos."]:
		print(falado(t))
