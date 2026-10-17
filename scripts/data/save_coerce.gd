class_name SaveCoerce
extends RefCounted
## Conversões TOLERANTES para dados vindos do disco (REVISAO #5). Um save com
## JSON válido mas tipos errados (edição manual, ferramenta de terceiros, save
## de versão futura) não pode derrubar o jogo nem o "Continuar": cada campo
## ruim cai no padrão e o resto do save segue valendo.
## Obs.: o JSON do Godot devolve TODO número como float — por isso int aceita
## float (e bool) e string só quando é um inteiro válido.


static func as_int(v: Variant, fallback: int) -> int:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT, TYPE_BOOL: return int(v)
		TYPE_STRING: return int(v) if (v as String).is_valid_int() else fallback
	return fallback


static func as_float(v: Variant, fallback: float) -> float:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT: return float(v)
		TYPE_STRING: return float(v) if (v as String).is_valid_float() else fallback
	return fallback


## Só aceita bool de verdade ou número (0 = falso). "sim", [1], null → padrão.
static func as_bool(v: Variant, fallback: bool) -> bool:
	match typeof(v):
		TYPE_BOOL: return v
		TYPE_INT, TYPE_FLOAT: return v != 0
	return fallback


## Lista de textos: não-lista → padrão; dentro da lista, só os itens que já
## são texto (números/listas/null são descartados, não convertidos).
static func as_str_array(v: Variant, fallback: Array = []) -> Array[String]:
	var out: Array[String] = []
	if typeof(v) != TYPE_ARRAY:
		out.assign(fallback)
		return out
	for item in v:
		if typeof(item) == TYPE_STRING or typeof(item) == TYPE_STRING_NAME:
			out.append(String(item))
	return out


static func as_dict(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


## Valor de opção só é aceito se o tipo bater com o padrão (números se
## convertem entre int/float, pois o JSON só tem float). Senão: null (= rejeita).
static func match_type(v: Variant, default_value: Variant) -> Variant:
	var want := typeof(default_value)
	var got := typeof(v)
	if got == want:
		return v
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if want in numeric and got in numeric:
		return int(v) if want == TYPE_INT else float(v)
	return null
