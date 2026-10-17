shader_type canvas_item;
render_mode unshaded;
// NÉVOA EM FAIXA (cenário). Ruído fbm que escorre na horizontal; o perfil
// vertical (topo → pico → base) diz onde a névoa mora. `offset` é o x da
// câmera × paralaxe (cada faixa anda num ritmo = profundidade).

uniform vec4 col : source_color = vec4(0.6, 0.65, 0.75, 1.0);
uniform float density = 0.35;
uniform float offset = 0.0;
uniform float y_top = 0.0;
uniform float y_peak = 200.0;
uniform float y_bot = 300.0;
uniform float scale = 0.006;
uniform float speed = 6.0;
uniform float seed = 0.0;

varying vec2 p;

void vertex() {
	p = VERTEX;
}

float hash2(vec2 q) {
	return fract(sin(dot(q, vec2(127.1, 311.7)) + seed) * 43758.5453);
}

float vnoise(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 q) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += vnoise(q) * a;
		q = q * 2.03 + vec2(13.1, 7.7);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 q = vec2((p.x + offset + TIME * speed) * scale, p.y * scale * 2.6 + TIME * 0.015);
	float n = fbm(q);
	float prof = smoothstep(y_top, y_peak, p.y) * (1.0 - smoothstep(y_peak, y_bot, p.y));
	float a = density * prof * smoothstep(0.28, 0.8, n);
	COLOR = vec4(col.rgb, a);
}
