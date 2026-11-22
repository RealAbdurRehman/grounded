const int SQUASH_LANES = 5;
const int SQUASH_ANGLES = 49;

const int SQUASH_TAPS = 3;
const int SQUASH_TERMS = 24;

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

uniform vec2 squash_near = vec2(0.0, 48.0);

uniform float squash_round_along = 0.015;
uniform float squash_round_across = 0.05;

uniform float squash_soft = 0.002;
uniform float squash_fillet = 0.008;

const float SQUASH_FLAT_ALONG = 0.5;
const float SQUASH_FLAT_ACROSS = 0.25;

const float SQUASH_TOLERANCE = 0.002;
const float SQUASH_BLEND = 0.001;

const int SQUASH_SIDE_ANGLES = 9;
const float SQUASH_SIDE_STEP = 0.2617994;

uniform float squash_side[18];

float squash_at(int lane, int angle) {
	if (angle < 0 || angle >= SQUASH_ANGLES) return 0.0;
	return squash_depth[lane * SQUASH_ANGLES + angle];
}

float squash_lane_at(int lane, float theta) {
	float u = theta / squash_step + float(SQUASH_ANGLES - 1) * 0.5;
	int a0 = int(floor(u));

	return mix(squash_at(lane, a0), squash_at(lane, a0 + 1), u - float(a0));
}

vec2 squash_curve(float p0, float p1, float p2, float p3, float t) {
	float d0 = p1 - p0;
	float d1 = p2 - p1;
	float d2 = p3 - p2;

	float m1 = d0 * d1 > 0.0 ? 2.0 * d0 * d1 / (d0 + d1) : 0.0;
	float m2 = d1 * d2 > 0.0 ? 2.0 * d1 * d2 / (d1 + d2) : 0.0;

	float t2 = t * t;
	float t3 = t2 * t;

	float value = (2.0 * t3 - 3.0 * t2 + 1.0) * p1 + (t3 - 2.0 * t2 + t) * m1 + (-2.0 * t3 + 3.0 * t2) * p2 + (t3 - t2) * m2;
	float slope = (6.0 * t2 - 6.0 * t) * p1 + (3.0 * t2 - 4.0 * t + 1.0) * m1 + (-6.0 * t2 + 6.0 * t) * p2 + (3.0 * t2 - 2.0 * t) * m2;

	return vec2(value, slope);
}

vec3 squash_field(float theta, float x) {
	float u = theta / squash_step + float(SQUASH_ANGLES - 1) * 0.5;
	if (u < squash_near.x - float(SQUASH_TAPS) || u > squash_near.y + float(SQUASH_TAPS) + 1.0) return vec3(0.0);

	float arc = squash_step * squash_radius;
	float k_along = 0.5 / squash_round_along;
	float k_across = 0.5 / squash_round_across;

	float lane_gap = 2.0 * squash_lane_offset / float(SQUASH_LANES - 1);
	float edge = squash_lane_offset;
	float xc = clamp(x, -edge, edge);

	int l0 = min(int(floor((xc + edge) / lane_gap)), SQUASH_LANES - 2);
	int a0 = int(floor(u));
	float fa = u - float(a0);

	float fl = (xc + edge) / lane_gap - float(l0);
	float across_mix = fl * fl * (3.0 - 2.0 * fl);
	float across_mix_slope = 6.0 * fl * (1.0 - fl) / lane_gap;

	vec2 low = squash_curve(squash_at(l0, a0 - 1), squash_at(l0, a0), squash_at(l0, a0 + 1), squash_at(l0, a0 + 2), fa);
	vec2 high = squash_curve(squash_at(l0 + 1, a0 - 1), squash_at(l0 + 1, a0), squash_at(l0 + 1, a0 + 1), squash_at(l0 + 1, a0 + 2), fa);

	float smooth_depth = mix(low.x, high.x, across_mix);
	float smooth_along = mix(low.y, high.y, across_mix) / arc;
	float smooth_across = (high.x - low.x) * across_mix_slope;

	float top = -1000.0;

	for (int t = 0; t < SQUASH_TERMS; t++) {
		int j = a0 + t / 4 + 1 - SQUASH_TAPS;
		int l = l0 + t % 4 - 1;

		bool inside = j >= 0 && j < SQUASH_ANGLES && l >= 0 && l < SQUASH_LANES;
		float d = squash_depth[clamp(l, 0, SQUASH_LANES - 1) * SQUASH_ANGLES + clamp(j, 0, SQUASH_ANGLES - 1)];
		float on = inside && d > 0.0005 ? 1.0 : 0.0;

		float ds = max(abs(u - float(j)) - SQUASH_FLAT_ALONG, 0.0) * arc;
		float dx = max(abs(xc - (float(l) * lane_gap - edge)) - SQUASH_FLAT_ACROSS * lane_gap, 0.0);

		top = max(top, mix(-1000.0, d - k_along * ds * ds - k_across * dx * dx, on));
	}

	float sum = 0.0;
	float grad_s = 0.0;
	float grad_x = 0.0;

	for (int t = 0; t < SQUASH_TERMS; t++) {
		int j = a0 + t / 4 + 1 - SQUASH_TAPS;
		int l = l0 + t % 4 - 1;

		bool inside = j >= 0 && j < SQUASH_ANGLES && l >= 0 && l < SQUASH_LANES;
		float d = squash_depth[clamp(l, 0, SQUASH_LANES - 1) * SQUASH_ANGLES + clamp(j, 0, SQUASH_ANGLES - 1)];
		float on = inside && d > 0.0005 ? 1.0 : 0.0;

		float gap_u = u - float(j);
		float gap_x = xc - (float(l) * lane_gap - edge);

		float ds = max(abs(gap_u) - SQUASH_FLAT_ALONG, 0.0) * arc;
		float dx = max(abs(gap_x) - SQUASH_FLAT_ACROSS * lane_gap, 0.0);

		float term = d - k_along * ds * ds - k_across * dx * dx;

		float w = on * exp(min((term - top) / squash_soft, 0.0));
		sum += w;
		grad_s += w * (-2.0 * k_along * ds * sign(gap_u));
		grad_x += w * (-2.0 * k_across * dx * sign(gap_x));
	}

	float has = sum > 0.0 ? 1.0 : 0.0;
	float safe = max(sum, 0.000001);

	float dome = mix(-1.0, top + squash_soft * log(safe) - SQUASH_TOLERANCE, has);
	float dome_along = has * grad_s / safe;
	float dome_across = has * grad_x / safe;

	float f = squash_fillet;
	float round_depth = 0.0;
	float round_gain = 0.0;

	if (dome >= f) {
		round_depth = dome;
		round_gain = 1.0;
	} else if (dome > -f) {
		round_depth = (dome + f) * (dome + f) / (4.0 * f);
		round_gain = (dome + f) / (2.0 * f);
	}

	float high_value = max(smooth_depth, round_depth);
	float low_value = min(smooth_depth, round_depth);

	float w_smooth = exp((smooth_depth - high_value) / SQUASH_BLEND);
	float w_round = exp((round_depth - high_value) / SQUASH_BLEND);
	float w_sum = w_smooth + w_round;

	float depth = high_value + SQUASH_BLEND * log(w_sum) * smoothstep(0.0, 0.004, low_value);
	float depth_along = (w_smooth * smooth_along + w_round * round_gain * dome_along) / w_sum;
	float depth_across = (w_smooth * smooth_across + w_round * round_gain * dome_across) / w_sum;

	float across = abs(x) > edge ? 0.0 : 1.0;

	return vec3(depth, depth_along, depth_across * across);
}

float squash_swell(float theta, float right) {
	float u = theta / squash_step + float(SQUASH_ANGLES - 1) * 0.5;
	if (u < squash_near.x - 8.0 || u > squash_near.y + 8.0) return 0.0;

	float tap = squash_swell_reach / 3.0;

	float top = 0.0;

	for (int k = -3; k <= 3; k++) {
		float d = mix(squash_lane_at(0, theta + float(k) * tap), squash_lane_at(SQUASH_LANES - 1, theta + float(k) * tap), right);
		top = max(top, d * (1.0 - abs(float(k)) * 0.25));
	}

	return top;
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

	vec3 field = squash_field(theta, q.x);

	float depth = field.x;
	float slope = field.y * squash_radius;
	float cross_slope = field.z;

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
	float n_side = n.x - n_out * stiff * shift_slope / round_radius + n_out * stiff * cross_slope;

	n_out -= n.x * side * spread_slope;
	n = outward * n_out + around * n_around + vec3(n_side, 0.0, 0.0);

	vertex += from_world * (squash_hub_basis * move);
	normal = normalize(transpose(to_world) * (squash_hub_basis * n));
}