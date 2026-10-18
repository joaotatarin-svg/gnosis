shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// NÚCLEO DE ATAQUE (VFX7): orbe de plasma procedural num quad (UV 0..1).
// Cor = COLOR (modulate do nó) · força = COLOR.a. Premultiplicado: a luz SOMA
// (alfa 0) e o miolo corrompido ESCURECE o fundo (alfa > 0) — um passe só.
uniform float dark = 0.0;        // 1 = luz corrompida (Arcontes): miolo escuro, borda acesa
uniform float swirl = 1.0;       // velocidade do plasma
uniform float spikes = 0.0;      // pontas da coroa (0 = redondo = luz da Sophia)
uniform float core_size = 0.34;  // raio do miolo branco (0..1)
uniform float flicker = 0.12;    // tremor do brilho
varying float phase;

void vertex() {
	// fase por posição no mundo: orbes vizinhos não giram em uníssono
	phase = MODEL_MATRIX[3].x * 0.013 + MODEL_MATRIX[3].y * 0.031;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec4 m = COLOR;
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float a = atan(p.y, p.x);
	float t = TIME * swirl + phase;
	// plasma: ruído em coordenadas polares, girando e "fervendo"
	float n = noise(vec2(a * 1.9 + t * 1.7, d * 5.0 - t * 2.3)) * 0.6
		+ noise(vec2(a * 4.8 - t * 2.9, d * 9.0 + t * 1.3)) * 0.4;
	float edge = 0.62 + (n - 0.5) * 0.2;
	if (spikes > 0.0) {
		edge += pow(abs(cos(a * spikes * 0.5 + t * 0.7)), 10.0) * 0.3;
	}
	float body = smoothstep(edge, edge - 0.2, d);               // disco do orbe
	float glow = exp(-d * d * 4.0) * 0.5 * (1.0 - smoothstep(0.85, 1.0, d));
	float core = smoothstep(core_size, 0.0, d);                 // miolo quente
	float fl = 1.0 + (noise(vec2(t * 7.0, phase)) - 0.5) * flicker * 2.0;
	vec3 col = m.rgb;
	vec3 rgb;
	float alpha;
	if (dark > 0.5) {
		float rim = smoothstep(edge - 0.3, edge - 0.04, d) * body;
		float inner = body * (1.0 - rim);
		vec3 voidc = mix(vec3(0.06, 0.0, 0.09), col * 0.3, n * 0.55);
		rgb = voidc * inner + col * (rim * 1.7 + glow * 1.1) * fl + vec3(1.0) * rim * rim * 0.4;
		alpha = inner * 0.9;
	} else {
		rgb = col * (body * (0.75 + n * 0.6) + glow * 1.2) * fl + vec3(1.0) * (core * 1.25 + body * 0.18);
		alpha = 0.0;
	}
	COLOR = vec4(rgb * m.a, alpha * m.a);
}
