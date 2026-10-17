shader_type canvas_item;
render_mode unshaded;
// CHÃO 2.5D DO CENÁRIO (scenery.gd › FloorBand). Uma faixa em coords de mundo
// que segue a câmera em x. A textura é o chão PINTADO do Éon (gerado pelo
// pipeline), repetida em espelho (sem emenda) e com perspectiva falsa: na
// linha dos pés anda 1:1 com o mundo; mais perto da câmera, mais rápido
// (o chão "abre"). Por cima: névoa no horizonte, poça de luz onde se luta,
// reflexo do fundo (tela espelhada no horizonte), borda iluminada e
// escurecimento em direção à câmera.

uniform sampler2D floor_tex : source_color, filter_linear;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float node_x = 0.0;        // x de mundo do nó (o shader acha o resto)
uniform float floor_y = 292.0;     // horizonte do chão (y de mundo)
uniform float feet_y = 310.0;      // linha dos pés
uniform float band_h = 140.0;      // altura de mundo que a textura cobre
uniform float tile_w = 540.0;      // largura de mundo de um ladrilho
uniform float persp = 0.45;        // abertura da perspectiva
uniform float view_w = 640.0;      // largura lógica da tela
uniform float view_h = 360.0;
uniform float reflect_amt = 0.3;
uniform vec4 haze : source_color = vec4(0.5, 0.55, 0.65, 1.0);
uniform vec4 glow : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float has_tex = 1.0;
uniform vec4 base_col : source_color = vec4(0.14, 0.13, 0.17, 1.0);

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float mirror1(float u) {
	float t = mod(u, 2.0);
	return t < 1.0 ? t : 2.0 - t;
}

void fragment() {
	float y = local.y;
	float dy = y - floor_y;
	float vt = clamp(dy / band_h, 0.0, 1.0);
	// câmera exata a partir da própria tela (sem atraso de um quadro)
	float sx = (SCREEN_UV.x - 0.5) * view_w;
	float world_x = node_x + local.x;
	float cam_x = world_x - sx;
	float s = max(0.55, 1.0 + (y - feet_y) / band_h * persp);
	float wx = cam_x + sx / s;
	vec3 c = base_col.rgb * (1.0 - vt * 0.5);
	if (has_tex > 0.5) {
		c = texture(floor_tex, vec2(mirror1(wx / tile_w), vt)).rgb;
	}
	// reflexo: a tela espelhada no horizonte, com ondulação leve
	float floor_sv = SCREEN_UV.y - dy / view_h;
	vec2 ruv = vec2(SCREEN_UV.x + sin(y * 0.8 + TIME * 1.2) * 0.0012 * vt, 2.0 * floor_sv - SCREEN_UV.y);
	vec3 r = texture(screen_tex, ruv).rgb;
	float rk = reflect_amt * (1.0 - smoothstep(0.0, 0.8, vt)) * smoothstep(0.0, 0.04, ruv.y);
	c = mix(c, max(c, r * 0.85), rk);
	// névoa colada no horizonte
	float hz = 1.0 - smoothstep(0.0, 0.2, vt);
	c = mix(c, haze.rgb * 0.6, hz * 0.3);
	// poça de luz na faixa de luta
	float lane = exp(-pow((y - feet_y) / 16.0, 2.0));
	c += glow.rgb * lane * 0.07;
	// escurece em direção à câmera (o primeiro plano é sombra)
	c *= mix(1.0, 0.42, smoothstep(0.3, 1.0, vt));
	// borda iluminada no horizonte
	c += glow.rgb * exp(-max(dy, 0.0) / 1.8) * 0.14;
	COLOR = vec4(c, smoothstep(-1.5, 3.0, dy));
}
