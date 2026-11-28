shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform;

uniform float smoke_time = 0.0;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

uniform vec3 smoke_color : source_color = vec3(0.60, 0.61, 0.62);

uniform vec3 sky_light : source_color = vec3(0.62, 0.65, 0.68);

uniform vec3 sun_color : source_color = vec3(0.68, 0.65, 0.58);
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);

uniform float widest_on_screen = 0.3;

const int MAX_BOXES = 16;
const int CABIN_BOX = 1;

uniform vec4 box_center[MAX_BOXES];

uniform vec4 box_x[MAX_BOXES];
uniform vec4 box_y[MAX_BOXES];
uniform vec4 box_z[MAX_BOXES];

const float DRAG_S = 0.4;

const float RISE_MPS = 0.45;

const float RISE_DELAY_S = 0.6;

const float WANDER_M = 0.14;
const float GROUND_FADE_M = 0.12;

const float SOFT_RADII = 0.55;

const float MIN_SOFT_M = 0.05;
const float MAX_SOFT_M = 0.45;

const float CABIN_DEPTH_M = 0.25;
const float CABIN_SOFT_M = 0.35;

const float PULL_RADII = 0.35;
const float MAX_PULL_M = 0.15;

varying vec2 disc;
varying vec2 noise_uv;

varying vec2 turn;

varying vec3 sun_view;
varying vec3 shade_light;
varying vec3 sun_light;

varying float strength;
varying float ragged;

varying float above_ground;

varying vec3 box_gap;
varying flat vec2 box_edge;

void vertex() {
	vec3 start = MODEL_MATRIX[3].xyz;
	vec3 push = MODEL_MATRIX[0].xyz;

	vec3 timing = MODEL_MATRIX[1].xyz;
	vec3 extra = MODEL_MATRIX[2].xyz;

	float life = max(timing.z, 0.001);
	float age = smoke_time - timing.x;
	float alive = step(0.0, age) * step(age, life - 0.001);
	age = clamp(age, 0.0, life);

	float used = age / life;
	float seed = INSTANCE_CUSTOM.z;
	float phase = seed * 61.7;

	vec3 wind = vec3(extra.x, 0.0, extra.y);
	float slowed = DRAG_S * (1.0 - exp(-age / DRAG_S));

	vec3 center = start + wind * age + (push - wind) * slowed;
	center.y += RISE_MPS * (age - RISE_DELAY_S * (1.0 - exp(-age / RISE_DELAY_S)));
	center += vec3(
		sin(age * 1.7 + phase) - sin(phase),
		0.4 * (sin(age * 2.3 + phase * 1.7) - sin(phase * 1.7)),
		cos(age * 1.5 + phase * 2.3) - cos(phase * 2.3)
	) * WANDER_M * min(age, 1.5);

	float first = extra.z;
	float radius = first + INSTANCE_CUSTOM.y * (sqrt(age + 0.04) - 0.2);
	center += COLOR.rgb;
	center.y = max(center.y, timing.y + radius * 0.45);

	vec3 view_center = (VIEW_MATRIX * vec4(center, 1.0)).xyz;

	float away = max(-view_center.z, 0.05);
	float cover = radius / away;

	float too_close = smoothstep(widest_on_screen, widest_on_screen * 2.5, cover);
	float thinning = pow(first / max(radius, 0.001), 0.55);

	strength = INSTANCE_CUSTOM.x * smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(0.45, 1.0, used))
			* thinning * (1.0 - too_close) * smoothstep(0.3, 1.2, away) * alive;
	radius = min(radius * COLOR.a, away * widest_on_screen * 1.4) * step(0.004, strength);

	float soft_m = clamp(radius * SOFT_RADII * smoothstep(0.0, 0.8, age), MIN_SOFT_M, MAX_SOFT_M);
	ragged = 0.35 * used;

	float angle = phase + age * (seed - 0.5) * 1.6;
	turn = vec2(cos(angle), sin(angle));

	disc = VERTEX.xy;

	vec2 turned = vec2(disc.x * turn.x - disc.y * turn.y, disc.x * turn.y + disc.y * turn.x);
	noise_uv = turned * 0.34 + vec2(seed, fract(seed * 7.31)) + vec2(0.013, -0.021) * age;

	vec3 corner = view_center + vec3(disc * radius, 0.0);
	vec3 corner_world = (INV_VIEW_MATRIX * vec4(corner, 1.0)).xyz;
	above_ground = (corner_world.y - timing.y) / GROUND_FADE_M;

	box_gap = vec3(1.0, 0.0, 0.0);
	box_edge = vec2(0.0);

	int touching = int(INSTANCE_CUSTOM.w + 0.5) - 1;

	if (touching >= 0) {
		int box = touching / 6;
		int side = touching - box * 6;

		int axis = side / 2;
		int across = (axis + 1) % 3;

		int up = (axis + 2) % 3;

		vec3 from = corner_world - box_center[box].xyz;
		vec3 at = vec3(
			dot(from, box_x[box].xyz),
			dot(from, box_y[box].xyz),
			dot(from, box_z[box].xyz)
		);

		vec3 size = vec3(box_x[box].w, box_y[box].w, box_z[box].w);

		float depth = box == CABIN_BOX ? CABIN_DEPTH_M : 0.0;
		float width = box == CABIN_BOX ? CABIN_SOFT_M : soft_m;
		float ahead = at[axis] * (side == axis * 2 ? 1.0 : -1.0) - size[axis];

		box_gap = vec3(ahead + depth, at[across], at[up]) / width;
		box_edge = (vec2(size[across], size[up]) - depth) / width;
	}

	float pull = min(radius * PULL_RADII, MAX_PULL_M);
	float nearer = 1.0 - min(pull / max(length(view_center), 0.1), 0.5);
	VERTEX = corner * nearer;

	sun_view = normalize((VIEW_MATRIX * vec4(sun_direction, 0.0)).xyz);
	float glow = pow(max(dot(normalize(view_center), sun_view), 0.0), 6.0);

	shade_light = smoke_color * (sky_light + sun_color * (0.35 * glow));
	sun_light = smoke_color * sun_color;
}

void fragment() {
	vec4 noise = texture(noise_tex, noise_uv);
	vec2 swirl = noise.gb * 2.0 - 1.0;
	vec2 bump = vec2(swirl.x * turn.x + swirl.y * turn.y, swirl.y * turn.x - swirl.x * turn.y);

	vec2 torn = disc + bump * 0.25;

	float rim = dot(disc, disc);
	float body = 1.0 - dot(torn, torn) + (noise.r - 0.6) * 1.8;
	float density = smoothstep(ragged, 1.0, body) * (1.0 - smoothstep(0.55, 1.0, rim));

	vec3 normal = vec3(disc * 0.6 + bump * 0.5, 1.25 - 0.7 * rim);
	float facing = clamp(dot(normal, sun_view) * 0.4 + 0.45, 0.0, 1.0);

	ALBEDO = (shade_light + sun_light * facing * facing) * mix(0.82, 1.1, noise.r);

	vec2 beside = abs(box_gap.yz) - box_edge;
	float clear_of = max(box_gap.x, max(beside.x, beside.y));

	ALPHA = density * strength * clamp(above_ground, 0.0, 1.0) * clamp(clear_of, 0.0, 1.0);
}