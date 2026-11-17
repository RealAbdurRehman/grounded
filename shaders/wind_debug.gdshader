shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

const int WAVES = 16;
const int HALF = 8;
const int GUSTS = 4;

uniform float u_time;

uniform float u_cell = 5.0;
uniform float u_radius = 70.0;

uniform float u_speed_scale = 25.0;
uniform float u_gust_scale = 12.0;

uniform vec2 u_center;

uniform vec2 u_mean;
uniform vec2 u_direction;

uniform vec4 u_waves[16];
uniform float u_strengths[16];

uniform vec4 u_gust_starts[4];
uniform vec4 u_gust_shapes[4];

uniform vec4 u_gust_times[4];

varying vec3 world_position;

vec2 turbulence(vec2 p) {
	float along = 0.0;
	float across = 0.0;

	for (int i = 0; i < HALF; i++) {
		vec4 a = u_waves[i];
		along += u_strengths[i] * cos(dot(a.xy, p) - a.z * u_time + a.w);

		vec4 b = u_waves[i + HALF];
		across += u_strengths[i + HALF] * cos(dot(b.xy, p) - b.z * u_time + b.w);
	}

	vec2 side = vec2(-u_direction.y, u_direction.x);
	return u_direction * along + side * across;
}

vec2 gusts(vec2 p) {
	vec2 total = vec2(0.0);
	for (int i = 0; i < GUSTS; i++) {
		if (u_gust_times[i].y < 0.5) continue;
		

		vec2 origin = u_gust_starts[i].xy;
		vec2 direction = u_gust_starts[i].zw;

		float peak = u_gust_shapes[i].x;
		float length_m = u_gust_shapes[i].y;

		float width = u_gust_shapes[i].z;
		float speed = u_gust_shapes[i].w;

		vec2 relative = p - origin;
		float front = dot(relative, direction) - speed * (u_time - u_gust_times[i].x);
		if (front > 0.0 || front < -length_m) {
			continue;
		}

		float across = dot(relative, vec2(-direction.y, direction.x)) / width;
		float shape = 0.5 * (1.0 - cos(6.2831853 * -front / length_m));
		total += direction * (peak * shape * exp(-across * across));
	}

	return total;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;

	vec2 base = floor(p / u_cell);
	vec2 middle = (base + 0.5) * u_cell;

	vec2 gust_here = gusts(p);

	vec2 wind = u_mean + turbulence(middle) + gusts(middle);
	float strength = length(wind);

	float fade = 1.0 - smoothstep(u_radius * 0.55, u_radius, distance(p, u_center));
	float heat = clamp(strength / u_speed_scale, 0.0, 1.0);

	vec3 calm = vec3(0.20, 0.70, 1.00);
	vec3 strong = vec3(1.00, 0.32, 0.12);
	vec3 color = mix(calm, strong, heat);

	float alpha = 0.0;

	float glow = clamp(length(gust_here) / u_gust_scale, 0.0, 1.0);
	vec3 glow_color = vec3(1.00, 0.80, 0.30);

	if (strength > 0.25) {
		vec2 direction = wind / strength;
		vec2 side = vec2(-direction.y, direction.x);

		vec2 q = p - middle;
		float a = dot(q, direction);
		float b = dot(q, side);

		float half_length = clamp(strength * 0.22, 0.6, u_cell * 0.46);
		float thickness = 0.10 + 0.06 * heat;
		float head = min(half_length * 0.7, 1.1);

		float body = (1.0 - smoothstep(thickness * 0.7, thickness, abs(b)))
			* step(-half_length, a) * (1.0 - step(half_length - head * 0.5, a));

		float tip = clamp((half_length - a) / head, 0.0, 1.0);
		float wing = (1.0 - smoothstep(tip * head * 0.45 - 0.03, tip * head * 0.45, abs(b)))
			* step(half_length - head, a) * step(a, half_length);

		float flow = fract((a + half_length) / (half_length * 2.0) - u_time * (0.4 + heat * 0.8));
		float pulse = 0.35 + 0.65 * flow;

		alpha = max(body * pulse, wing);
	}

	vec3 final_color = mix(color, glow_color, glow * 0.6);
	alpha = max(alpha, glow * 0.22);

	ALBEDO = final_color;
	ALPHA = alpha * fade;
}