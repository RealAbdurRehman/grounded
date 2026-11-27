shader_type spatial;

#include "res://shaders/tire/tire_squash.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);

uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_depth = 0.0;

uniform float roughness : hint_range(0.0, 1.0) = 0.9;

void vertex() {
	tire_squash(MODEL_MATRIX, VERTEX, NORMAL);
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * albedo_color.rgb;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;

	ROUGHNESS = roughness;
	METALLIC = 0.0;
}