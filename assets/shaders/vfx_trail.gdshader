shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// RASTRO DE ATAQUE (VFX7): fita num Line2D (texture_mode STRETCH: UV.x 0 = cabeça,
// 1 = cauda; UV.y atravessa a fita). Cor = gradiente do Line2D (cor de vértice).
uniform float dark = 0.0;       // 1 = rastro corrompido (veio escuro no meio)
uniform float links = 0.0;      // > 0: corrente (n elos ao longo da fita)
uniform float scroll = 3.0;     // velocidade do ruído correndo pra trás
uniform float breakup = 0.55;   // quanto o ruído recorta a fita (0 = lisa)
uniform float core_w = 0.32;    // largura do veio branco

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
	float x = UV.x;
	float y = abs(UV.y * 2.0 - 1.0);
	float soft = 1.0 - smoothstep(0.3, 1.0, y);
	float core = 1.0 - smoothstep(0.0, core_w, y);
	float n = noise(vec2(x * 8.0 + TIME * scroll, UV.y * 2.5 - TIME * 1.3));
	float cut = mix(1.0, smoothstep(0.2, 0.8, n + (1.0 - x) * 0.55), breakup);
	vec3 rgb = m.rgb * soft * cut + vec3(1.0) * core * (1.0 - x) * (1.0 - x) * 0.8 * cut;
	float alpha = 0.0;
	if (links > 0.0) {
		// elos ovais encadeados (alternando de frente e de perfil)
		float u = fract(x * links);
		float side = mod(floor(x * links), 2.0);
		vec2 q = vec2((u - 0.5) * 2.0, (UV.y * 2.0 - 1.0) * mix(1.0, 2.2, side));
		float r = length(q * vec2(0.9, 1.0));
		float ring = smoothstep(0.95, 0.75, r) * smoothstep(0.35, 0.55, r);
		rgb = m.rgb * ring * 1.3 + vec3(1.0) * ring * (1.0 - x) * 0.5 + m.rgb * soft * 0.18;
		alpha = ring * 0.55;
	}
	if (dark > 0.5) {
		float vein = core * cut * (1.0 - x * 0.7);
		rgb = rgb * (1.0 - vein * 0.85) + m.rgb * 0.15 * vein;
		alpha = max(alpha, vein * 0.75);
	}
	COLOR = vec4(rgb * m.a, alpha * m.a);
}
