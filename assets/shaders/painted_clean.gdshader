shader_type canvas_item;
// Folhas DERIVADAS (assets/painted/derived/): o alfa já vem recortado e
// desmisturado offline (tools/anim/clean_sheets.py). O shader só aplica a
// tinta/flash do nó (modulate/self_modulate chegam em COLOR) — sem chave
// cromática, então nenhuma franja magenta nasce do filtro bilinear/mipmap.
void fragment() {
	COLOR = texture(TEXTURE, UV) * COLOR;
}
