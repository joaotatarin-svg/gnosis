shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// RAIOS DE LUZ FALSOS (god rays) do cenário. Retângulo fixo na tela, entre o
// fundo distante e as asas (as asas cobrem os raios = parece volume). Dois
// focos (a pintura é espelhada: cada metade tem o seu astro). Feixes por
// ruído angular que respira devagar. `dark` = raios de VAZIO (escurecem).

uniform vec2 src_a = vec2(380.0, 20.0);
uniform vec2 src_b = vec2(-400.0, 20.0);
uniform vec4 col : source_color = vec4(0.7, 0.85, 1.0, 1.0);
uniform float amt = 0.3;
uniform float spread = 0.5;        // 0 = feixe estreito p/ baixo; 1 = radial
uniform float reach = 300.0;
uniform bool dark = false;

varying vec2 p;

void vertex() {
	p = VERTEX;
}

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), f);
}

float rays(vec2 src) {
	vec2 d = p - src;
	float dist = length(d);
	float a = atan(d.x, d.y);          // 0 = para baixo
	float b = noise1(a * 16.0 + TIME * 0.12) * 0.6 + noise1(a * 37.0 - TIME * 0.19) * 0.4;
	b = pow(b, 2.4) * 1.8;
	float w = 0.25 + spread * 1.4;
	float cone = exp(-pow(a / w, 2.0));
	float fall = exp(-dist / reach);
	float k = b * cone * fall * smoothstep(0.0, 30.0, dist);
	k += exp(-dist / 34.0) * 0.5;      // halo no foco
	return k;
}

void fragment() {
	float k = (rays(src_a) + rays(src_b)) * amt;
	if (dark) {
		float a = clamp(k * 1.4, 0.0, 0.8);
		COLOR = vec4(col.rgb * a, a);
	} else {
		COLOR = vec4(col.rgb * k, 0.0);
	}
}
