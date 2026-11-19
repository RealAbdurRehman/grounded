shader_type spatial;

#include "res://shaders/tire/tire_squash.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.0, 0.0277, 0.0742, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

uniform vec4 rim_albedo : source_color = vec4(0.5, 0.52, 0.56, 1.0);

void vertex() {
	tire_squash(MODEL_MATRIX, VERTEX, NORMAL);
}

void fragment() {
	float rim = 1.0 - COLOR.r;

	ALBEDO = mix(albedo.rgb, rim_albedo.rgb, rim);
	ROUGHNESS = mix(roughness, 0.35, rim);
	METALLIC = rim * 0.8;
}