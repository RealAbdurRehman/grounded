class_name TireSmokeFlow
extends RefCounted

const DRAG_S: float = 0.4

const RISE_MPS: float = 0.45
const RISE_DELAY_S: float = 0.6

const WANDER_M: float = 0.14

const TURNS: int = 2

const YOUNG_S: float = 0.6
const OLD_EVERY_S: float = 0.025
const CALM_EVERY_S: float = 0.045
const MAX_STEP_S: float = 0.06

const FEEL_M: float = 0.35

const FEEL_RADII: float = 0.5
const KEEP_OFF_RADII: float = 0.35

const STOP_RATE: float = 14.0
const PUSH_RATE: float = 9.0

const EMERGE_S: float = 0.35

const SLIDE_SHARE: float = 0.8
const SCATTER: float = 0.9

const LIFT: float = 0.7
const LIFT_BY_CAR: float = 0.15

const CHURN_MPS2: float = 2.0

const DRIFT_DECAY_S: float = 0.7
const MAX_DRIFT_MPS: float = 6.0

const SMALLEST: float = 0.55
const SMALLEST_BY_CAR: float = 0.8

const SIZE_RATE: float = 5.0

var _start: PackedVector3Array = PackedVector3Array()
var _push: PackedVector3Array = PackedVector3Array()
var _wind: PackedVector3Array = PackedVector3Array()

var _born_s: PackedFloat32Array = PackedFloat32Array()
var _life_s: PackedFloat32Array = PackedFloat32Array()

var _floor_y: PackedFloat32Array = PackedFloat32Array()

var _first_m: PackedFloat32Array = PackedFloat32Array()
var _growth_m: PackedFloat32Array = PackedFloat32Array()

var _phase: PackedFloat32Array = PackedFloat32Array()

var _offset: PackedVector3Array = PackedVector3Array()
var _drift: PackedVector3Array = PackedVector3Array()
var _size: PackedFloat32Array = PackedFloat32Array()

var _custom: PackedColorArray = PackedColorArray()

var _moved_s: PackedFloat32Array = PackedFloat32Array()
var _calm: PackedByteArray = PackedByteArray()

var _turn: int = 0


func _init(puffs: int) -> void:
	_start.resize(puffs)
	_push.resize(puffs)
	_wind.resize(puffs)

	_born_s.resize(puffs)
	_life_s.resize(puffs)

	_floor_y.resize(puffs)

	_first_m.resize(puffs)
	_growth_m.resize(puffs)

	_phase.resize(puffs)

	_offset.resize(puffs)
	_drift.resize(puffs)
	_size.resize(puffs)

	_custom.resize(puffs)

	_moved_s.resize(puffs)
	_calm.resize(puffs)


func add(
	index: int,
	start: Vector3,
	push: Vector3,
	wind: Vector3,
	born_s: float,
	life_s: float,
	floor_y: float,
	first_m: float,
	custom: Color,
) -> void:
	_start[index] = start
	_push[index] = push
	_wind[index] = wind

	_born_s[index] = born_s
	_life_s[index] = life_s

	_floor_y[index] = floor_y

	_first_m[index] = first_m
	_growth_m[index] = custom.g

	_phase[index] = custom.b * 61.7

	_custom[index] = custom

	_offset[index] = Vector3.ZERO
	_drift[index] = Vector3.ZERO
	_size[index] = 1.0

	_moved_s[index] = born_s
	_calm[index] = 0


func step(clock_s: float, obstacles: TireSmokeObstacles, puffs: MultiMesh) -> void:
	_turn = (_turn + 1) % TURNS

	for i in range(_turn, _born_s.size(), TURNS):
		var age: float = clock_s - _born_s[i]
		if age < 0.0 or age >= _life_s[i]:
			continue

		var since: float = clock_s - _moved_s[i]
		var wait_s: float = CALM_EVERY_S if _calm[i] == 1 else OLD_EVERY_S
		if age > YOUNG_S and since < wait_s:
			continue

		_moved_s[i] = clock_s
		_move(i, age, minf(since, MAX_STEP_S), obstacles, puffs)


func _move(
	i: int,
	age: float,
	step_s: float,
	obstacles: TireSmokeObstacles,
	puffs: MultiMesh,
) -> void:
	var wind: Vector3 = _wind[i]
	var thrown: Vector3 = _push[i] - wind

	var drag: float = exp(-age / DRAG_S)
	var phase: float = _phase[i]

	var at: Vector3 = _start[i] + wind * age + thrown * (DRAG_S * (1.0 - drag))
	at.y += RISE_MPS * (age - RISE_DELAY_S * (1.0 - exp(-age / RISE_DELAY_S)))
	at += Vector3(
		sin(age * 1.7 + phase) - sin(phase),
		0.4 * (sin(age * 2.3 + phase * 1.7) - sin(phase * 1.7)),
		cos(age * 1.5 + phase * 2.3) - cos(phase * 2.3),
	) * (WANDER_M * minf(age, 1.5))

	var radius: float = _first_m[i] + _growth_m[i] * (sqrt(age + 0.04) - 0.2)

	var offset: Vector3 = _offset[i]
	var drift: Vector3 = _drift[i]

	at += offset
	at.y = maxf(at.y, _floor_y[i] + radius * 0.45)

	var size: float = 1.0
	var calm: int = 1

	var world_code: int = 0
	var cabin_code: int = 0
	var world_gap: float = INF

	if obstacles.area.has_point(at):
		var moving: Vector3 = wind + thrown * drag
		moving.y += RISE_MPS * (1.0 - exp(-age / RISE_DELAY_S))

		var feel: float = FEEL_M + radius * FEEL_RADII
		var keep_off: float = radius * KEEP_OFF_RADII

		for box in obstacles.boxes:
			if not box.reach.has_point(at):
				continue

			var local: Vector3 = box.inverse * (at - box.center)
			var past: Vector3 = local.abs() - box.half + Vector3.ONE * box.corner

			var out: Vector3 = past.max(Vector3.ZERO)
			var outside: float = out.length()

			var face: int = past.max_axis_index()
			var gap: float = outside + minf(past[face], 0.0) - box.corner

			if gap >= maxf(feel, radius):
				continue

			var normal := Vector3.ZERO

			if outside > 0.001:
				normal = out * local.sign() / outside
			else:
				if not box.is_car:
					var born: Vector3 = box.inverse * (_start[i] - box.center)
					var clear: Vector3 = born.abs() - box.half

					if clear[clear.max_axis_index()] > 0.0:
						face = clear.max_axis_index()
						local[face] = born[face]
				elif face == Vector3.AXIS_Y and local.y < 0.0:
					face = Vector3.AXIS_X if past.x > past.z else Vector3.AXIS_Z

				normal[face] = 1.0 if local[face] >= 0.0 else -1.0

			var side: int = normal.abs().max_axis_index()
			var code: int = box.slot * 6 + side * 2 + (1 if normal[side] >= 0.0 else 2)

			if box.slot == TireSmokeObstacles.CABIN_SLOT:
				cabin_code = code
			elif not box.is_car and gap < world_gap:
				world_gap = gap
				world_code = code

			if gap >= feel:
				continue

			calm = 0
			normal = box.turn * normal

			var near: float = 1.0 - clampf((gap - keep_off) / (feel - keep_off), 0.0, 1.0)
			near *= near

			var surface: Vector3 = box.velocity + box.spin.cross(at - box.pivot)
			var relative: Vector3 = moving + drift - surface
			var closing: float = -relative.dot(normal)

			if closing > 0.0:
				var stopped: float = closing * minf(near * STOP_RATE * step_s, 1.0)

				var along: Vector3 = relative + normal * closing
				var lift: float = LIFT_BY_CAR if box.is_car else LIFT
				var aside := Vector3(sin(phase * 3.1), lift, cos(phase * 4.3))
				aside = aside - normal * aside.dot(normal)

				var spread: Vector3 = along.limit_length(1.0) + aside * SCATTER

				drift += normal * stopped
				drift += spread.limit_length(1.0) * (stopped * SLIDE_SHARE)

			var churn := Vector3(
				sin(phase * 5.3 + age * 7.0),
				sin(phase * 2.9 + age * 5.0),
				cos(phase * 6.1 + age * 6.0),
			)
			drift += churn * (CHURN_MPS2 * near * step_s)

			if gap < keep_off:
				var rate: float = PUSH_RATE * smoothstep(0.0, EMERGE_S, age)
				var push: Vector3 = normal * ((keep_off - gap) * minf(rate * step_s, 1.0))

				offset += push
				at += push

			var least: float = SMALLEST_BY_CAR if box.is_car else SMALLEST
			size = minf(size, clampf((gap + radius * 0.5) / (radius + 0.001), least, 1.0))

	var touching: int = world_code if world_code > 0 else cabin_code
	var custom: Color = _custom[i]

	if int(custom.a) != touching:
		custom.a = touching
		_custom[i] = custom
		puffs.set_instance_custom_data(i, custom)

	_calm[i] = calm if drift == Vector3.ZERO else 0

	var held: float = _size[i]
	size = move_toward(held, size, SIZE_RATE * step_s)

	if drift == Vector3.ZERO and offset == _offset[i] and size == held:
		return

	drift = drift.limit_length(MAX_DRIFT_MPS)
	offset += drift * step_s
	drift *= exp(-step_s / DRIFT_DECAY_S)

	if drift.length_squared() < 0.0004:
		drift = Vector3.ZERO

	_offset[i] = offset
	_drift[i] = drift
	_size[i] = size

	puffs.set_instance_color(i, Color(offset.x, offset.y, offset.z, size))
