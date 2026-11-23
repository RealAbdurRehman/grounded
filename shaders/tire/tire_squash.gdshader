shader_type spatial;

#include "res://shaders/tire/tire_squash.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

void vertex() {
	tire_squash(MODEL_MATRIX, VERTEX, NORMAL);
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
}