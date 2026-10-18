// GNOSIS — Onda 6 (inimigos6): o contorno de leitura do VfxLibrary.rim_shader()
// + uma GRADUAÇÃO DE COR do corpo (girar matiz, saturação, tinta). Serve para os
// bots do Éon e o Campeão NÃO terem a cara do Arconte (a pintura deles é da
// mesma família: mesma paleta, mesmos motivos). Sem arte nova, a cor separa:
// o Arconte fica com a cor-assinatura; os servos, cinzentos; o Campeão, invertido.
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 rim_color : source_color = vec4(0.55, 0.8, 1.0, 0.5);
uniform float rim_strength = 1.0;
uniform float rim_px = 1.0;
uniform float grade_hue = 0.0;      // giro de matiz (radianos)
uniform float grade_sat = 1.0;      // 0 = cinza · 1 = original
uniform vec4 grade_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

vec3 hue_rotate(vec3 c, float a) {
	// rotação no espaço YIQ (preserva a luminância)
	mat3 to_yiq = mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312));
	mat3 to_rgb = mat3(vec3(1.0, 1.0, 1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703));
	vec3 yiq = to_yiq * c;
	float h = atan(yiq.z, yiq.y) + a;
	float ch = length(yiq.yz);
	yiq.y = ch * cos(h);
	yiq.z = ch * sin(h);
	return clamp(to_rgb * yiq, 0.0, 1.0);
}

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	vec3 g = c.rgb;
	if (grade_hue != 0.0) {
		g = hue_rotate(g, grade_hue);
	}
	float l = dot(g, vec3(0.299, 0.587, 0.114));
	g = mix(vec3(l), g, grade_sat) * grade_tint.rgb;
	c.rgb = g;
	float k = max(1.0, (1.0 / SCREEN_PIXEL_SIZE.y) / 360.0) * rim_px;
	vec2 d = SCREEN_PIXEL_SIZE * k;
	float n = 0.0;
	n = max(n, textureLod(screen_texture, SCREEN_UV + vec2(d.x, 0.0), 0.0).a);
	n = max(n, textureLod(screen_texture, SCREEN_UV - vec2(d.x, 0.0), 0.0).a);
	n = max(n, textureLod(screen_texture, SCREEN_UV + vec2(0.0, d.y), 0.0).a);
	n = max(n, textureLod(screen_texture, SCREEN_UV - vec2(0.0, d.y), 0.0).a);
	n = max(n, textureLod(screen_texture, SCREEN_UV + d * 0.7, 0.0).a);
	n = max(n, textureLod(screen_texture, SCREEN_UV - d * 0.7, 0.0).a);
	n = max(n, textureLod(screen_texture, SCREEN_UV + vec2(d.x, -d.y) * 0.7, 0.0).a);
	n = max(n, textureLod(screen_texture, SCREEN_UV + vec2(-d.x, d.y) * 0.7, 0.0).a);
	float edge = clamp(n - c.a, 0.0, 1.0) * rim_color.a * rim_strength;
	vec4 body = COLOR * c;
	vec4 rim = vec4(rim_color.rgb, edge * COLOR.a);
	float oa = body.a + rim.a * (1.0 - body.a);
	vec3 orgb = oa > 0.0001 ? (body.rgb * body.a + rim.rgb * rim.a * (1.0 - body.a)) / oa : vec3(0.0);
	COLOR = vec4(orgb, oa);
}
