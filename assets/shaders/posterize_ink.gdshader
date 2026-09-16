shader_type canvas_item;
// POSTERIZACAO + CONTORNO DE TINTA — aplicado aos PNGs ilustrados (Rei/Demiurgo)
// pra casar com o mundo vetorial: achata os tons em bandas suaves (tira o
// fotorrealismo sem afundar os meios-tons) e desenha uma linha escura na borda
// do recorte (mesma linguagem de tinta da Sophia).

uniform float levels : hint_range(2.0, 32.0) = 12.0;       // bandas de cor
uniform float outline_px : hint_range(0.0, 6.0) = 2.0;     // grossura do traco
uniform vec4 outline_color : source_color = vec4(0.06, 0.05, 0.09, 1.0);
uniform float saturation : hint_range(0.0, 2.0) = 0.95;    // 1 = original

varying vec4 v_mod;   // modulate puro (no fragment, COLOR ja vem x textura)

void vertex() {
	v_mod = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * outline_px;
	// alpha dos vizinhos (pra achar a borda do recorte)
	float na = texture(TEXTURE, UV + vec2(px.x, 0.0)).a
		+ texture(TEXTURE, UV - vec2(px.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, px.y)).a
		+ texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	// posterizacao com leve dessaturacao
	vec3 q = floor(tex.rgb * levels) / levels + 0.5 / levels;
	float g = dot(q, vec3(0.299, 0.587, 0.114));
	q = mix(vec3(g), q, saturation);
	vec4 outc = vec4(q, tex.a);
	// fora do corpo mas com vizinho dentro = traco de tinta
	if (tex.a < 0.45 && na > 0.25) {
		outc = vec4(outline_color.rgb, clamp(na, 0.0, 1.0));
	}
	COLOR = outc * v_mod;   // v_mod = modulate (flash de dano etc.)
}
