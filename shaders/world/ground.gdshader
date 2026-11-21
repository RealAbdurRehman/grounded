shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform bool use_normal = true;
uniform bool use_orm = true;

uniform vec4 tint : source_color = vec4(1.0);

uniform float tile_m = 6.0;

uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float roughness_scale : hint_range(0.0, 1.5) = 1.0;

uniform float variation : hint_range(0.0, 1.0) = 1.0;

varying vec2 world_xz;

const mat2 TURN = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
const float SECOND_SCALE = 0.83;
const vec2 SECOND_SHIFT = vec2(0.31, 0.77);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv_a = world_xz / tile_m;
	vec2 uv_b = TURN * uv_a * SECOND_SCALE + SECOND_SHIFT;

	float mix_amount = smoothstep(0.3, 0.7, value_noise(world_xz / 13.0)) * variation;

	vec3 color_a = texture(albedo_tex, uv_a).rgb;
	vec3 color_b = texture(albedo_tex, uv_b).rgb;
	vec3 average = textureLod(albedo_tex, uv_a, 10.0).rgb;

	float keep = 1.0 / sqrt((1.0 - mix_amount) * (1.0 - mix_amount) + mix_amount * mix_amount);
	vec3 color = average + (mix(color_a, color_b, mix_amount) - average) * keep;

	float slow_change = value_noise(world_xz / 37.0) - 0.5;
	color *= 1.0 + slow_change * 0.3 * variation;

	ALBEDO = clamp(color, 0.0, 1.0) * tint.rgb;

	float rough = 1.0;
	float occlusion = 1.0;
	if (use_orm) {
		vec3 orm_a = texture(orm_tex, uv_a).rgb;
		vec3 orm_b = texture(orm_tex, uv_b).rgb;
		vec3 orm = mix(orm_a, orm_b, mix_amount);

		occlusion = orm.r;
		rough = orm.g;
	}

	ROUGHNESS = clamp(rough * roughness_scale, 0.04, 1.0);
	METALLIC = 0.0;

	AO = occlusion;
	AO_LIGHT_AFFECT = 0.5;

	if (use_normal) {
		vec2 n_a = texture(normal_tex, uv_a).xy * 2.0 - 1.0;
		vec2 n_b = texture(normal_tex, uv_b).xy * 2.0 - 1.0;

		n_b = vec2(dot(n_b, TURN[0]), dot(n_b, TURN[1]));
		vec2 slope = mix(n_a, n_b, mix_amount);
		vec3 n = vec3(slope, sqrt(max(1.0 - dot(slope, slope), 0.0)));

		vec3 world_normal = normalize(vec3(n.x * normal_strength, n.z, -n.y * normal_strength));
		NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	}
}