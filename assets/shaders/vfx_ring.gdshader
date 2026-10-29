shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// ANEL DE CHOQUE (VFX7): anel macio num quad (UV 0..1) com borda quente.
// Cor = COLOR (modulate); o nó cresce por escala e apaga por alfa.
uniform float thickness = 0.14;
uniform float haze = 0.05;       // véu claro dentro do anel
uniform float dark = 0.0;        // 1 = anel com miolo escuro (choque corrompido)

varying vec4 vcol;   // cor do vértice (modulate/gradiente) sem a textura

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec4 m = vcol;
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float outer = smoothstep(1.0, 1.0 - thickness * 0.5, d);
	float inner = smoothstep(1.0 - thickness * 2.2, 1.0 - thickness * 0.6, d);
	float ring = outer * inner;
	float hot = smoothstep(1.0 - thickness * 1.3, 1.0 - thickness * 0.7, d) * outer;
	float veil = (1.0 - smoothstep(0.0, 1.0, d)) * haze;
	vec3 rgb = m.rgb * (ring * 0.85 + veil) + vec3(1.0) * hot * ring * 0.3;
	float alpha = dark > 0.5 ? ring * 0.35 : 0.0;
	COLOR = vec4(rgb * m.a, alpha * m.a);
}
