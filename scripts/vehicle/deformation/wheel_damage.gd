class_name WheelDamage
extends RefCounted

const REACH_M: float = 1.0

const LOAD_SHARE: float = 0.5

const CRASH_S: float = 0.08
const PEAK_FACTOR: float = 1.8

const LOAD_JITTER: float = 0.15
const STRENGTH_SPREAD: float = 0.25

const STRIKE_FLOOR_N: float = 8000.0
const STRIKE_SMOOTHING_S: float = 0.02

const INNER_MOUNT_M: float = 0.25

const SWING_YIELD_N: float = 18000.0
const LEAN_YIELD_N: float = 20000.0
const SIDEWAYS_YIELD_N: float = 24000.0

const STIFFNESS_N_M: float = 180000.0

const MAX_SWING_RAD: float = 0.35
const MAX_LEAN_RAD: float = 0.35

const MAX_SIDEWAYS_M: float = 0.1
const MAX_SETBACK_M: float = 0.05

const STRUT_YIELD_N: float = 45000.0
const STRUT_STIFFNESS_N_M: float = 400000.0
const MAX_SAG_M: float = 0.08

const RIM_YIELD_N: float = 28000.0
const RIM_STIFFNESS_N_RAD: float = 900000.0

const MAX_TILT_RAD: float = 0.07

const RADIAL_PER_TILT_M: float = 0.12

const LEAK_N: float = 40000.0
const BURST_N: float = 70000.0

const LEAK_MIN_PER_S: float = 0.03
const LEAK_MAX_PER_S: float = 0.12

const BURST_PER_S: float = 6.0

const CARVE_EVERY_S: float = 0.25
const CARVE_MOVED_M: float = 0.004
const CARVE_TURNED_COS: float = 0.99998
const CARVE_NEAR_M: float = 0.3

const HISTORY_TICKS: int = 12

const SLOWED_RATIO: float = 1.2
const SLOWED_SLACK_MPS: float = 1.0


class WheelState extends RefCounted:
	var wheel: Wheel

	var side: float = 1.0
	var rest_position: Vector3

	var inner_x: float = 0.0
	var lever_m: float = 0.5

	var strength: float = 1.0
	var tire_strength: float = 1.0

	var swing_rad: float = 0.0
	var lean_rad: float = 0.0
	var sideways_m: float = 0.0

	var sag_m: float = 0.0
	var setback_m: float = 0.0

	var tilt_rad: float = 0.0
	var tilt_phase: float = 0.0

	var air: float = 1.0
	var leak_per_s: float = 0.0
	var burst: bool = false

	var worst_n: float = 0.0

	var strike_n: Vector3 = Vector3.ZERO
	var strike_spot: Vector3 = Vector3.ZERO

	var carve_due: bool = false
	var carve_clock: float = 0.0

	var carved_center: Vector3 = Vector3.INF
	var carved_axis: Vector3 = Vector3.ZERO


var states: Array[WheelState] = []

var _car: RigidBody3D
var _deformer: CarDeformer
var _random := RandomNumberGenerator.new()

var _clock: float = 0.0

var _history: PackedVector3Array = PackedVector3Array()
var _head: int = 0


func _init(car: RigidBody3D, wheels: Array[Wheel], deformer: CarDeformer) -> void:
	_car = car
	_deformer = deformer

	_random.randomize()
	_history.resize(HISTORY_TICKS)

	for wheel in wheels:
		var hub: Vector3 = _car.to_local(wheel.hub_world_position())
		if absf(hub.x) < Wheel.CENTER_WHEEL_M:
			continue

		var state := WheelState.new()
		state.wheel = wheel

		state.side = signf(hub.x)
		state.rest_position = wheel.position

		state.inner_x = state.side * INNER_MOUNT_M
		state.lever_m = clampf(absf(hub.x) - INNER_MOUNT_M, 0.3, 0.9)

		state.strength = _roll_strength()
		state.tire_strength = _roll_strength()

		states.append(state)

	if _deformer != null:
		_deformer.dented.connect(_on_dented)


func on_crash(points: PackedVector3Array, push: Vector3, delta_v: float) -> void:
	delta_v = minf(delta_v, _slowed_by().length() * SLOWED_RATIO + SLOWED_SLACK_MPS)

	var peak_force: float = _car.mass * delta_v / CRASH_S * PEAK_FACTOR
	for state in states:
		var hub: Vector3 = _car.to_local(state.wheel.hub_world_position())

		var nearest: float = INF
		var spot: Vector3 = hub

		for point in points:
			var distance: float = _distance_to_tire(state.wheel, hub, point)
			if distance < nearest:
				nearest = distance
				spot = point

		if nearest >= REACH_M:
			continue

		var closeness: float = 1.0 - nearest / REACH_M
		var force: float = peak_force * LOAD_SHARE * closeness * closeness
		force *= _random.randf_range(1.0 - LOAD_JITTER, 1.0 + LOAD_JITTER)

		_load(state, _nearest_on_tire(state.wheel, hub, spot), push, force)


func step(delta: float) -> void:
	_history[_head] = _car.linear_velocity
	_head = (_head + 1) % HISTORY_TICKS

	_clock += delta

	for state in states:
		_strike(state, delta)

		if _clock - state.carve_clock >= CARVE_EVERY_S and (state.carve_due or _is_bent(state)):
			_carve(state)

		var rate: float = BURST_PER_S if state.burst else state.leak_per_s
		if rate > 0.0 and state.air > 0.0:
			state.air *= exp(-rate * delta)

			if state.air < 0.001:
				state.air = 0.0

		state.wheel.inflation.air_left = state.air


func _strike(state: WheelState, delta: float) -> void:
	var wheel: Wheel = state.wheel
	var impulse: Vector3 = wheel.obstacle_impulse_n_s

	if impulse.is_zero_approx() and state.strike_n.length_squared() < 1.0:
		return

	var up: Vector3 = wheel.global_transform.basis.orthonormalized().y
	impulse -= up * impulse.dot(up)

	var push: Vector3 = _car.global_basis.orthonormalized().inverse() * impulse / delta
	state.strike_n = state.strike_n.lerp(push, 1.0 - exp(-delta / STRIKE_SMOOTHING_S))

	var force: float = state.strike_n.length()
	if force < STRIKE_FLOOR_N:
		return

	var deepest: float = INF
	for i in range(wheel.collider.count):
		if wheel.collider.gaps[i] < deepest:
			deepest = wheel.collider.gaps[i]
			state.strike_spot = _car.to_local(wheel.collider.points[i])

	if deepest == INF and state.strike_spot == Vector3.ZERO:
		state.strike_spot = _car.to_local(wheel.hub_world_position())

	_load(state, state.strike_spot, state.strike_n / force, force)


func _is_bent(state: WheelState) -> bool:
	return (
		absf(state.swing_rad) > 0.002 or absf(state.lean_rad) > 0.002
		or absf(state.sideways_m) > 0.002 or state.sag_m > 0.002 or state.tilt_rad > 0.0
	)


func _on_dented(box: AABB) -> void:
	for state in states:
		var hub: Vector3 = _car.to_local(state.wheel.hub_world_position())
		var reach: float = state.wheel.suspension_config.wheel_radius + CARVE_NEAR_M

		if box.grow(CARVE_NEAR_M).intersects(
			AABB(hub - Vector3.ONE * reach, Vector3.ONE * reach * 2.0)
		):
			state.carve_due = true


func _carve(state: WheelState) -> void:
	var wheel: Wheel = state.wheel
	var config: SuspensionConfig = wheel.suspension_config

	var hub: Vector3 = _car.to_local(wheel.hub_world_position())
	var axis: Vector3 = (_car.global_basis.orthonormalized().inverse() * wheel.hub_basis()) \
			.x \
			.normalized()

	var still: bool = (
		hub.distance_to(state.carved_center) < CARVE_MOVED_M
		and absf(axis.dot(state.carved_axis)) > CARVE_TURNED_COS
	)

	if still and not state.carve_due:
		return

	var radius: float = config.wheel_radius + wheel.damage_radial_m
	var half: float = config.width_m() * 0.5 + config.wheel_radius * sin(state.tilt_rad)

	if _deformer.carve(hub, axis, radius, half):
		state.carved_center = hub
		state.carved_axis = axis

		state.carve_due = false
		state.carve_clock = _clock


func burst(state: WheelState) -> void:
	state.burst = true


## Put every wheel back.
func repair() -> void:
	for state in states:
		state.swing_rad = 0.0
		state.lean_rad = 0.0
		state.sideways_m = 0.0

		state.sag_m = 0.0
		state.setback_m = 0.0

		state.tilt_rad = 0.0

		state.air = 1.0
		state.leak_per_s = 0.0
		state.burst = false

		state.worst_n = 0.0

		state.strike_n = Vector3.ZERO
		state.strike_spot = Vector3.ZERO

		state.carve_due = false
		state.carved_center = Vector3.INF

		state.strength = _roll_strength()
		state.tire_strength = _roll_strength()

		_apply(state)
		state.wheel.inflation.air_left = 1.0


func _load(state: WheelState, spot: Vector3, direction: Vector3, force_n: float) -> void:
	state.worst_n = maxf(state.worst_n, force_n)

	var hub: Vector3 = _car.to_local(state.wheel.hub_world_position())
	var inner := Vector3(state.inner_x, hub.y, hub.z)

	var push: Vector3 = direction * force_n
	var torque: Vector3 = (spot - inner).cross(push)

	var lever: float = state.lever_m
	var strength: float = state.strength

	state.swing_rad = _bent_by(
		torque.y / lever,
		SWING_YIELD_N * strength,
		state.swing_rad,
		STIFFNESS_N_M * lever,
		MAX_SWING_RAD,
	)

	state.lean_rad = _bent_by(
		torque.z / lever,
		LEAN_YIELD_N * strength,
		state.lean_rad,
		STIFFNESS_N_M * lever,
		MAX_LEAN_RAD,
	)

	state.sideways_m = _bent_by(
		push.x,
		SIDEWAYS_YIELD_N * strength,
		state.sideways_m,
		STIFFNESS_N_M,
		MAX_SIDEWAYS_M,
	)

	state.sag_m = _bent_by(
		force_n,
		STRUT_YIELD_N * strength,
		state.sag_m,
		STRUT_STIFFNESS_N_M,
		MAX_SAG_M,
	)

	var tilt: float = clampf(
		(force_n - RIM_YIELD_N * strength) / RIM_STIFFNESS_N_RAD,
		0.0,
		MAX_TILT_RAD,
	)

	if tilt > state.tilt_rad:
		state.tilt_rad = tilt
		state.tilt_phase = _random.randf_range(0.0, TAU)

	var tire_strength: float = state.tire_strength

	if force_n > BURST_N * tire_strength:
		state.burst = true
	elif force_n > LEAK_N * tire_strength:
		var share: float = (force_n - LEAK_N * tire_strength) / ((BURST_N - LEAK_N) * tire_strength)
		state.leak_per_s = maxf(state.leak_per_s, lerpf(LEAK_MIN_PER_S, LEAK_MAX_PER_S, share))

	_apply(state)


func _bent_by(
	wheel_load: float,
	yield_n: float,
	bent: float,
	stiffness: float,
	limit: float,
) -> float:
	var over: float = absf(wheel_load) - yield_n
	if over <= 0.0:
		return bent

	var target: float = signf(wheel_load) * over / stiffness
	var further: float = target

	if signf(bent) == signf(target):
		further = target - bent if absf(target) > absf(bent) else 0.0

	return clampf(bent + further, -limit, limit)


func _apply(state: WheelState) -> void:
	var wheel: Wheel = state.wheel

	wheel.damage_toe_rad = state.side * state.swing_rad
	wheel.damage_camber_rad = -state.side * state.lean_rad

	wheel.damage_tilt_rad = state.tilt_rad
	wheel.damage_tilt_phase = state.tilt_phase
	wheel.damage_radial_m = state.tilt_rad * RADIAL_PER_TILT_M

	var lever_x: float = state.side * state.lever_m
	state.setback_m = clampf(-state.swing_rad * lever_x, -MAX_SETBACK_M, MAX_SETBACK_M)

	var shift := Vector3(state.sideways_m, state.sag_m, state.setback_m)

	var parent: Node3D = wheel.get_parent_node_3d()
	if parent != null:
		shift = parent.global_basis.orthonormalized().inverse() * (
			_car.global_basis.orthonormalized() * shift
		)

	wheel.position = state.rest_position + shift


func _nearest_on_tire(wheel: Wheel, hub: Vector3, point: Vector3) -> Vector3:
	var config: SuspensionConfig = wheel.suspension_config

	var around := Vector2(point.y - hub.y, point.z - hub.z)
	if around.length() > config.wheel_radius:
		around = around.normalized() * config.wheel_radius

	var half: float = config.width_m() * 0.5
	return Vector3(hub.x + clampf(point.x - hub.x, -half, half), hub.y + around.x, hub.z + around.y)


func _distance_to_tire(wheel: Wheel, hub: Vector3, point: Vector3) -> float:
	var config: SuspensionConfig = wheel.suspension_config
	var around: float = Vector2(point.y - hub.y, point.z - hub.z).length() - config.wheel_radius
	var across: float = absf(point.x - hub.x) - config.width_m() * 0.5

	return Vector2(maxf(around, 0.0), maxf(across, 0.0)).length()


func _slowed_by() -> Vector3:
	return _history[_head] - _car.linear_velocity


func _roll_strength() -> float:
	return _random.randf_range(1.0 - STRENGTH_SPREAD, 1.0 + STRENGTH_SPREAD)
