const int SQUASH_LANES = 5;
const int SQUASH_ANGLES = 49;

uniform float squash_depth[245];

uniform mat3 squash_hub_basis = mat3(1.0);

uniform float squash_radius = 0.31;
uniform float squash_rim_radius = 0.19;

uniform float squash_half_width = 0.125;
uniform float squash_lane_offset = 0.11;

uniform float squash_step = 0.0698;

uniform vec4 squash_shear = vec4(0.0, 0.0, 0.3, 1.0);

uniform float squash_bulge = 0.4;
uniform float squash_bulge_max = 0.03;
uniform float squash_bulge_peak : hint_range(0.3, 0.95) = 0.78;

uniform float squash_widen = 0.12;

uniform float squash_swell_reach : hint_range(0.1, 1.5) = 0.45;

const int SQUASH_SIDE_ANGLES = 9;
const float SQUASH_SIDE_STEP = 0.2617994;

uniform float squash_side[18];

float squash_blend(float a, float b, float f) {
	float edge = smoothstep(0.01, 0.03, abs(a - b));
	return mix(mix(a, b, f), max(a, b), edge);
}

float squash_at(int lane, int angle) {
	if (angle < 0 || angle >= SQUASH_ANGLES) return 0.0;
	return squash_depth[lane * SQUASH_ANGLES + angle];
}


float squash_lane_at(int lane, float theta) {
	float u = theta / squash_step + float(SQUASH_ANGLES - 1) * 0.5;
	int a0 = int(floor(u));

	return squash_blend(squash_at(lane, a0), squash_at(lane, a0 + 1), u - float(a0));
}

float squash_swell(float theta, float right) {
	float swell = 0.0;
	float tap = squash_swell_reach / 3.0;

	for (int k = -3; k <= 3; k++) {
		float d = mix(squash_lane_at(0, theta + float(k) * tap), squash_lane_at(SQUASH_LANES - 1, theta + float(k) * tap), right);
		swell = max(swell, d * (1.0 - abs(float(k)) * 0.25));
	}

	return swell;
}

float squash_room(float theta, float x) {
	int base = x < 0.0 ? 0 : SQUASH_SIDE_ANGLES;

	float f = clamp(theta / SQUASH_SIDE_STEP + float(SQUASH_SIDE_ANGLES / 2), 0.0, float(SQUASH_SIDE_ANGLES - 1));

	int i0 = int(floor(f));
	int i1 = min(i0 + 1, SQUASH_SIDE_ANGLES - 1);

	float room = mix(squash_side[base + i0], squash_side[base + i1], f - float(i0));
	float edge = smoothstep(float(SQUASH_SIDE_ANGLES / 2) * SQUASH_SIDE_STEP, float(SQUASH_SIDE_ANGLES / 2 + 1) * SQUASH_SIDE_STEP, abs(theta));

	return max(mix(room, 10.0, edge), 0.04);
}

void tire_squash(mat4 model, inout vec3 vertex, inout vec3 normal) {
	mat3 to_world = mat3(model);
	mat3 from_world = inverse(to_world);

	mat3 hub_from_world = transpose(squash_hub_basis);

	vec3 p = hub_from_world * (to_world * vertex);
	float r = length(p.yz);

	float sidewall = max(squash_radius - squash_rim_radius, 0.0001);
	float stiff = clamp((r - squash_rim_radius) / sidewall, 0.0, 1.0);

	if (stiff <= 0.001) return;

	float twist = squash_shear.y * stiff;

	float turn_cos = cos(twist);
	float turn_sin = sin(twist);

	vec3 q = vec3(p.x, p.y * turn_cos - p.z * turn_sin, p.y * turn_sin + p.z * turn_cos);
	vec3 move = q - p;

	float theta = atan(-q.z, -q.y);
	float up_down = cos(theta);
	float to_front = sin(theta);

	vec3 outward = vec3(0.0, -up_down, -to_front);
	vec3 around = vec3(0.0, to_front, -up_down);

	float away = max(abs(theta) - squash_shear.z, 0.0);
	float reach = max(squash_shear.w, 0.01);
	float shift = squash_shear.x * exp(-away / reach);

	float shift_slope = 0.0;
	if (away > 0.0) shift_slope = -sign(theta) * shift / reach;

	move.x += shift * stiff;

	vec3 at = q + move;

	float room = squash_room(theta, at.x);
	if (abs(at.x) > room)
		at.x = sign(at.x) * mix(abs(at.x), room, smoothstep(0.0, 0.3, stiff));
	
	move = at - q;

	float u = theta / squash_step + float(SQUASH_ANGLES - 1) * 0.5;
	float v = clamp(q.x / squash_lane_offset, -1.0, 1.0) * float(SQUASH_LANES - 1) * 0.5
			+ float(SQUASH_LANES - 1) * 0.5;

	int a0 = int(floor(u));
	int l0 = min(int(floor(v)), SQUASH_LANES - 2);

	float fa = u - float(a0);
	float fl = v - float(l0);

	float d00 = squash_at(l0, a0);
	float d01 = squash_at(l0, a0 + 1);

	float d10 = squash_at(l0 + 1, a0);
	float d11 = squash_at(l0 + 1, a0 + 1);

	float depth = squash_blend(squash_blend(d00, d01, fa), squash_blend(d10, d11, fa), fl);

	float slope = mix(d01 - d00, d11 - d10, fl) / squash_step;
	slope *= 1.0 - smoothstep(0.01, 0.03, max(abs(d01 - d00), abs(d11 - d10)));

	if (depth > 0.0) move += -outward * (stiff * depth);

	float side = clamp(q.x / squash_half_width, -1.0, 1.0);
	float swell = squash_swell(theta, clamp(q.x / squash_half_width * 0.5 + 0.5, 0.0, 1.0));

	float shape = log(0.5) / log(squash_bulge_peak);

	float up = pow(stiff, shape);
	float pi_up = 3.14159265 * up;

	float swell_m = squash_bulge_max * tanh(squash_bulge * swell / squash_bulge_max);
	float spread = swell_m * sin(pi_up) + squash_widen * stiff * stiff * stiff * depth;

	move.x += side * spread;

	float spread_slope = swell_m * 3.14159265 * cos(pi_up) * shape * pow(stiff, shape - 1.0) / sidewall
			+ squash_widen * 3.0 * stiff * stiff * depth / sidewall;

	vec3 n = normalize(hub_from_world * transpose(from_world) * normal);
	n = vec3(n.x, n.y * turn_cos - n.z * turn_sin, n.y * turn_sin + n.z * turn_cos);

	float n_out = dot(n, outward);

	float round_radius = max(r - stiff * depth, 0.0001);

	float n_around = dot(n, around) + n_out * stiff * slope * step(0.0, depth) / round_radius;
	float n_side = n.x - n_out * stiff * shift_slope / round_radius;

	n_out -= n.x * side * spread_slope;
	n = outward * n_out + around * n_around + vec3(n_side, 0.0, 0.0);

	vertex += from_world * (squash_hub_basis * move);
	normal = normalize(transpose(to_world) * (squash_hub_basis * n));
}