shader_type canvas_item;
render_mode unshaded;
// CHÃO 2.5D DO CENÁRIO (scenery.gd › FloorBand). Uma faixa em coords de mundo
// que segue a câmera em x. A textura é o chão PINTADO do Éon (gerado pelo
// pipeline), repetida em espelho (sem emenda) e com perspectiva falsa: na
// linha dos pés anda 1:1 com o mundo; mais perto da câmera, mais rápido
// (o chão "abre"). Por cima: névoa no horizonte, poça de luz onde se luta,
// reflexo do fundo (tela espelhada no horizonte), borda iluminada e
// escurecimento em direção à câmera. Abaixo da faixa de luta (P2): manchas
// de luz que passam devagar e o brilho do Éon escorrendo pelas rachaduras.

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

uniform float lane_amt = 0.07;      // luz na faixa de luta
uniform float calm = 0.35;          // quanto a textura acalma na faixa de luta (R18)
uniform float lane_dim = 0.0;       // Éons claros (Espelho/Coroa): escurece o chão atrás dos pés (R18)
uniform float life = 1.0;          // vida da faixa de baixo (P2): luz nas fendas + manchas de luz
uniform float crack_amt = 1.1;    // brilho do Éon vazando pelas rachaduras (a faísca presa na matéria)

varying vec2 local;

float fhash(vec2 q) {
	return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453);
}

float fnoise(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(fhash(i), fhash(i + vec2(1.0, 0.0)), f.x), mix(fhash(i + vec2(0.0, 1.0)), fhash(i + vec2(1.0, 1.0)), f.x), f.y);
}

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
	vec2 fuv = vec2(mirror1(wx / tile_w), vt);
	float l0 = 0.0;
	if (has_tex > 0.5) {
		c = texture(floor_tex, fuv).rgb;
		l0 = dot(c, vec3(0.3, 0.59, 0.11));
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
	// poça de luz na faixa de luta. Cenário 7 (R18): a textura do chão HD (mais
	// detalhada) se ACALMA ali — menos contraste interno e saturação atrás dos pés.
	float lane = exp(-pow((y - feet_y) / 22.0, 2.0));
	c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))) * 0.9 + haze.rgb * 0.1, lane * calm);
	c *= 1.0 - lane * lane_dim;
	c += glow.rgb * lane * lane_amt;
	// escurece em direção à câmera (o primeiro plano é sombra)
	c *= mix(1.0, mix(0.42, 0.52, life), smoothstep(0.3, 1.0, vt));
	if (life > 0.0) {
		// VIDA NA FAIXA DE BAIXO (abaixo da faixa de luta, sem disputar com ela):
		// 1) manchas de luz que passam devagar (nuvem/vitral lá em cima), presas
		//    ao chão em perspectiva;
		float below = smoothstep(0.22, 0.55, vt);
		if (below > 0.0) {
			float warp = fnoise(vec2(wx * 0.004, vt * 3.0));
			float pool = 0.5 + 0.5 * sin(wx * 0.009 + vt * 5.0 + TIME * 0.25 + warp * 7.0);
			c *= 1.0 + below * life * 0.22 * smoothstep(0.55, 1.0, pool);
			// 2) a faísca presa na matéria: o brilho do Éon escorre pelas fendas em
			//    ondas lentas que viajam pelo chão. As 4 amostras extras (rachadura =
			//    mais escura que a vizinhança, em cruz) só onde a onda está passando.
			float wave = 0.5 + 0.5 * sin(wx * 0.014 - TIME * 0.7 + warp * 9.0 + vt * 3.0);
			float seep = smoothstep(0.6, 1.0, wave) * (0.7 + 0.3 * sin(TIME * 1.3 + wx * 0.02)) * below;
			if (seep > 0.01 && has_tex > 0.5) {
				vec2 px = 2.5 / vec2(textureSize(floor_tex, 0));
				vec3 nb = texture(floor_tex, vec2(mirror1(fuv.x + px.x), fuv.y)).rgb + texture(floor_tex, vec2(mirror1(fuv.x - px.x), fuv.y)).rgb
					+ texture(floor_tex, fuv + vec2(0.0, px.y)).rgb + texture(floor_tex, fuv - vec2(0.0, px.y)).rgb;
				float crack = smoothstep(0.02, 0.07, dot(nb * 0.25, vec3(0.3, 0.59, 0.11)) - l0);
				c += glow.rgb * crack * seep * crack_amt * life;
			}
		}
	}
	// borda iluminada no horizonte
	c += glow.rgb * exp(-max(dy, 0.0) / 1.8) * 0.14;
	COLOR = vec4(c, smoothstep(-1.5, 3.0, dy));
}
