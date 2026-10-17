shader_type canvas_item;
// PROP PINTADO INTEGRADO AO ÉON (cenário). Recorta o fundo magenta da folha
// (mesma regra do painted_key), multiplica pela luz do Éon, acende a borda de
// cima (luz que vem do alto), puxa pra cor da névoa conforme a distância e
// recolore as chamas ciano da arte pra cor do Éon.

uniform vec4 haze : source_color = vec4(0.5, 0.55, 0.65, 1.0);
uniform float haze_amt = 0.0;
uniform vec4 ambient : source_color = vec4(1.0);
uniform vec4 rim_col : source_color = vec4(1.0);
uniform float rim_amt = 0.6;
uniform float rim_px = 3.0;
uniform vec4 flame_col : source_color = vec4(0.6, 0.9, 1.0, 1.0);
uniform float flame_amt = 0.0;
uniform bool silhouette = false;   // sombra projetada: só a forma, preta

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float keyed_alpha(vec4 c) {
	float key = min(c.r, c.b) - c.g;
	float a = c.a * (1.0 - smoothstep(0.20, 0.48, key));
	return smoothstep(0.10, 0.85, a);
}

void fragment() {
	vec4 raw = texture(TEXTURE, UV);
	vec4 c = raw;
	float key = min(c.r, c.b) - c.g;
	float spill = max(0.0, key - 0.08) * 0.8;
	c.r = max(0.0, c.r - spill);
	c.b = max(0.0, c.b - spill);
	c.a = keyed_alpha(raw);
	if (silhouette) {
		COLOR = vec4(0.0, 0.0, 0.0, c.a) * tint;
	} else {
		float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
		float flame = smoothstep(0.12, 0.32, c.b - c.r) * smoothstep(0.35, 0.6, max(c.g, c.b));
		c.rgb = mix(c.rgb, flame_col.rgb * (0.35 + lum * 1.3), flame * flame_amt);
		c.rgb *= mix(ambient.rgb, vec3(1.0), flame * 0.85);
		float above = keyed_alpha(texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * rim_px)));
		c.rgb += rim_col.rgb * clamp(c.a - above, 0.0, 1.0) * rim_amt;
		c.rgb = mix(c.rgb, haze.rgb, haze_amt * (1.0 - flame * 0.6));
		COLOR = c * tint;
	}
}
