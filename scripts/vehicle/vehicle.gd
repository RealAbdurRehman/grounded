class_name Vehicle
extends RigidBody3D

const GEAR_HOLD_FREE: float = 0.02
const GEAR_HOLD_FADE: float = 0.02

## Wheels this far apart are on different axles.
const AXLE_GAP_M: float = 0.3

const PLAYER_WHEEL_LIMIT: int = 8


class WheelPair extends RefCounted:
	var left: Wheel
	var right: Wheel

	var axle_index: int = 0


@export var config: ChassisConfig

@export_group("Wheels")
@export var is_player_built: bool = false

@export_group("References")
@export var engine_node: VehicleEngine
@export var drivetrain_node: Drivetrain

@export var center_of_mass_node: Marker3D

@export_group("Assists")
@export var assists_config: AssistsConfig


@export_group("Aerodynamics")
@export var aero_config: AeroConfig = AeroConfig.new()

var throttle_input: float = 0.0
var brake_input: float = 0.0
var handbrake_input: float = 0.0
var steer_input: float = 0.0

var handbrake_latched: bool = false

var gear_hold: float = 0.0
var _gear_holding: bool = false

var steer_cap_rad: float = 0.0
var steer_angle_rad: float = 0.0

var assists: Assists
var steering: Steering = Steering.new()

var aero: Aero

var obstacles: ObstacleSolver = ObstacleSolver.new()

var wheels: Array[Wheel] = []
var axles: Array[Array] = []
var wheel_pairs: Array[WheelPair] = []

var _com_applied: Vector3 = Vector3.INF

var _wheelbase_m: float = 2.7

var _steer_lever_m: Dictionary[Wheel, float] = { }
var _steer_reference_lever_m: float = 2.7
var _steer_reference: Wheel

var _steer_x_offset: Dictionary[Wheel, float] = { }


func _ready() -> void:
	mass = config.vehicle_mass

	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	_sync_center_of_mass()

	continuous_cd = true

	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE

	linear_damp = 0.0
	angular_damp = 0.0

	_find_wheels()
	if wheels.is_empty():
		set_physics_process(false)
		return

	_build_axles()
	_name_wheels()

	_cache_steering_geometry()
	steer_cap_rad = deg_to_rad(config.max_steer_angle_deg)

	assists = Assists.new(self, assists_config, _wheelbase_m)

	aero = Aero.new(self)


func _sync_center_of_mass() -> void:
	var local_com: Vector3 = to_local(center_of_mass_node.global_position)
	if local_com.is_equal_approx(_com_applied):
		return

	_com_applied = local_com
	center_of_mass = local_com


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("parking_brake"):
		handbrake_latched = not handbrake_latched


func _physics_process(delta: float) -> void:
	_handle_inputs(delta)

	_update_gear_hold()
	_compute_anti_roll_bars()
	_update_drivetrain_and_wheels(delta)

	aero.apply()


func _handle_inputs(delta: float) -> void:
	var throttle_target: float = Input.get_action_strength("throttle")
	var brake_target: float = Input.get_action_strength("brake")

	var pedal_rate: float = config.brake_pedal_rate
	if brake_target < brake_input:
		pedal_rate *= 3.0
	brake_input = move_toward(brake_input, brake_target, delta * pedal_rate)

	var handbrake_target: float = Input.get_action_strength("handbrake")
	if handbrake_latched:
		handbrake_target = 1.0

	var handbrake_rate: float = config.handbrake_pull_rate
	if handbrake_target < handbrake_input:
		handbrake_rate = config.handbrake_release_rate

	handbrake_input = move_toward(handbrake_input, handbrake_target, delta * handbrake_rate)

	var override: float = 0.0
	if config.brake_overrides_throttle:
		override = clampf((brake_input - 0.1) / 0.3, 0.0, 1.0)

	var final_throttle_target: float = throttle_target * (1.0 - override)

	var throttle_rate: float = config.throttle_ramp_speed
	if final_throttle_target < throttle_input:
		throttle_rate *= 2.0

	throttle_input = move_toward(throttle_input, final_throttle_target, delta * throttle_rate)

	_update_steering(delta)


func _find_wheels() -> void:
	wheels.clear()
	_collect_wheels(self)

	if is_player_built and wheels.size() > PLAYER_WHEEL_LIMIT:
		while wheels.size() > PLAYER_WHEEL_LIMIT:
			wheels.pop_back().queue_free()

	for w in wheels:
		w.mass_fraction = 1.0 / float(wheels.size())


func _collect_wheels(node: Node) -> void:
	for child in node.get_children():
		if child is Wheel:
			wheels.append(child)

		_collect_wheels(child)


func _build_axles() -> void:
	axles.clear()
	wheel_pairs.clear()

	var ordered: Array[Wheel] = wheels.duplicate()
	ordered.sort_custom(
		func(a: Wheel, b: Wheel) -> bool:
			return to_local(a.global_position).z < to_local(b.global_position).z,
	)

	var axle_z: float = INF
	for w in ordered:
		var z: float = to_local(w.global_position).z

		if axles.is_empty() or absf(z - axle_z) > AXLE_GAP_M:
			var fresh: Array[Wheel] = []
			axles.append(fresh)

			axle_z = z

		axles[-1].append(w)

	for index in range(axles.size()):
		var axle: Array = axles[index]
		axle.sort_custom(
			func(a: Wheel, b: Wheel) -> bool:
				return to_local(a.global_position).x < to_local(b.global_position).x,
		)

		for w: Wheel in axle:
			w.axle_index = index
			w.is_front = index == 0

		for i in range(int(axle.size() / 2.0)):
			var pair := WheelPair.new()
			pair.left = axle[i]
			pair.right = axle[axle.size() - 1 - i]
			pair.axle_index = index

			wheel_pairs.append(pair)


func _name_wheels() -> void:
	for index in range(axles.size()):
		var axle: Array = axles[index]

		var prefix: String = ""
		if axles.size() > 1:
			if index == 0:
				prefix = "F"
			elif index == axles.size() - 1:
				prefix = "R"
			else:
				prefix = "M" if axles.size() == 3 else "M%d" % index

		var left_seen: int = 0
		for i in range(axle.size()):
			var w: Wheel = axle[i]
			var x: float = to_local(w.global_position).x

			var side: String = "C"
			if x < -Wheel.CENTER_WHEEL_M:
				left_seen += 1
				side = "L" if left_seen == 1 else "L%d" % left_seen

			w.label = prefix + side

		var seen: int = 0
		for i in range(axle.size() - 1, -1, -1):
			var w: Wheel = axle[i]
			if to_local(w.global_position).x > Wheel.CENTER_WHEEL_M:
				seen += 1
				w.label = prefix + ("R" if seen == 1 else "R%d" % seen)


func front_axle() -> Array[Wheel]:
	var result: Array[Wheel] = []
	result.assign(axles[0])

	return result


func rear_axle() -> Array[Wheel]:
	var result: Array[Wheel] = []
	result.assign(axles[-1])

	return result


func corner_wheel(front: bool, right: bool) -> Wheel:
	var axle: Array = axles[0] if front else axles[-1]
	return axle[-1] if right else axle[0]


func front_wheel() -> Wheel:
	return axles[0][0]


func rear_wheel() -> Wheel:
	return axles[-1][0]


func _cache_steering_geometry() -> void:
	var steered: Array[Wheel] = []
	var fixed: Array[Wheel] = []
	for w in wheels:
		if w.can_steer:
			steered.append(w)
		else:
			fixed.append(w)

	var pivot_from: Array[Wheel] = fixed if not fixed.is_empty() else wheels

	var pivot_z: float = 0.0
	for w in pivot_from:
		pivot_z += to_local(w.global_position).z
	pivot_z /= float(pivot_from.size())

	_steer_lever_m.clear()
	_steer_x_offset.clear()

	_steer_reference = wheels[0]
	_steer_reference_lever_m = 0.0

	var wheelbase: float = 0.0
	for w in steered:
		var lever: float = pivot_z - to_local(w.global_position).z
		_steer_lever_m[w] = lever

		if absf(lever) > absf(_steer_reference_lever_m):
			_steer_reference_lever_m = lever
			_steer_reference = w

		wheelbase = maxf(wheelbase, lever)

		var mid_x: float = 0.0
		var axle: Array = axles[w.axle_index]
		for other: Wheel in axle:
			mid_x += to_local(other.global_position).x
		mid_x /= float(axle.size())

		_steer_x_offset[w] = to_local(w.global_position).x - mid_x

	if steered.is_empty():
		wheelbase = to_local(rear_wheel().global_position).z - to_local(
			front_wheel().global_position
		).z

	if _steer_reference_lever_m == 0.0:
		_steer_reference_lever_m = 1.0
	_steer_reference_lever_m = absf(_steer_reference_lever_m)

	_wheelbase_m = maxf(wheelbase, 0.5)


func _update_steering(delta: float) -> void:
	steer_input = Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")

	var lock_rad: float = deg_to_rad(config.max_steer_angle_deg)
	steer_cap_rad = _speed_steer_cap_rad(linear_velocity.length(), lock_rad)

	var target_rad: float = steer_input * steer_cap_rad

	var cap_fraction: float = clampf(steer_cap_rad / lock_rad, 0.15, 1.0)
	var rate_rad_s: float = deg_to_rad(config.steer_rate_deg_s) * cap_fraction

	steer_angle_rad = steering.step(
		config,
		delta,
		steer_angle_rad,
		steer_input,
		target_rad,
		rate_rad_s,
		lock_rad,
		_tire_steering_torque_nm(),
		linear_velocity.length(),
	)

	for w in wheels:
		if w.can_steer:
			w.steer_angle_rad = _ackermann_angle_rad(steer_angle_rad, w)


func _tire_steering_torque_nm() -> float:
	var total: float = 0.0
	for w in wheels:
		total += w.steering_torque_nm

	return total


func _speed_steer_cap_rad(speed: float, lock_rad: float) -> float:
	var sensitivity: float = config.steer_speed_sensitivity
	if sensitivity <= 0.0:
		return lock_rad

	var tire: Tire = _steer_reference.tire_model
	var ref_load: float = tire.reference_load_n
	var mu: float = tire.peak_lateral_force_n(ref_load, _steer_reference.grip_scale()) / ref_load

	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var corner_accel: float = mu * gravity * gravity_scale

	var geometric_rad: float = atan(_wheelbase_m * corner_accel / maxf(speed * speed, 0.01))
	var slip_rad: float = config.steer_slip_allowance * tire.alpha_peak()
	var grip_cap_rad: float = minf(geometric_rad + slip_rad, lock_rad)

	return lerpf(lock_rad, grip_cap_rad, sensitivity)


func _ackermann_angle_rad(centre_rad: float, wheel: Wheel) -> float:
	var lever: float = _steer_lever_m.get(wheel, _steer_reference_lever_m)
	var x_offset: float = _steer_x_offset.get(wheel, 0.0)

	var t: float = tan(centre_rad)
	var reference: float = _steer_reference_lever_m

	var straight_rad: float = atan(lever * t / reference)
	var ideal_rad: float = atan2(lever * t, maxf(reference + x_offset * t, 0.01))

	return lerpf(straight_rad, ideal_rad, config.ackermann_factor)


func _compute_anti_roll_bars() -> void:
	for w in wheels:
		w.arb_force_n = 0.0

	for pair in wheel_pairs:
		var stiffness: float = config.front_arb_stiffness
		if pair.axle_index > 0:
			stiffness = config.rear_arb_stiffness

		_set_axle_arb(pair.left, pair.right, stiffness)


func _set_axle_arb(left: Wheel, right: Wheel, stiffness: float) -> void:
	if left.is_grounded and right.is_grounded:
		var diff: float = left.spring_displacement - right.spring_displacement
		var force: float = diff * stiffness
		left.arb_force_n = force
		right.arb_force_n = -force


func _update_drivetrain_and_wheels(delta: float) -> void:
	var driver_brake_nm: Dictionary[Wheel, float] = { }
	for w in wheels:
		driver_brake_nm[w] = brake_input * brakes_for(w).max_torque_nm

	assists.update(delta, throttle_input, driver_brake_nm, handbrake_input)

	var driven_wheels: Array[Wheel] = []
	for axle in axles:
		for w: Wheel in axle:
			if w.is_driven:
				driven_wheels.append(w)

	drivetrain_node.setup_driveline(driven_wheels)
	var driveline_speed: float = drivetrain_node.get_input_speed_rad_s()

	var forward_speed: float = linear_velocity.dot(-global_transform.basis.z)
	drivetrain_node.handle_transmission(
		engine_node.current_rpm,
		forward_speed,
		driveline_speed,
		engine_node.is_rev_limiter_active,
	)

	var target_engine_rpm: float = drivetrain_node.calculate_target_engine_rpm(driveline_speed)
	var engine_torque: float = engine_node.update_engine(
		delta,
		assists.filter_throttle(throttle_input),
		target_engine_rpm,
		drivetrain_node.is_clutch_engaged(),
		drivetrain_node.is_shifting,
	)

	var total_wheel_torque: float = drivetrain_node.calculate_wheel_drive_torque(engine_torque)

	var engine_inertia: float = 0.0
	if drivetrain_node.is_clutch_engaged() and engine_node.config and drivetrain_node.config:
		var total_ratio: float = drivetrain_node.get_current_ratio() * drivetrain_node \
				.config \
				.final_drive_ratio
		engine_inertia = engine_node.config.flywheel_inertia * total_ratio * total_ratio

	var drive_torques: Dictionary[Wheel, float] = drivetrain_node.split_drive_torque(
		total_wheel_torque,
		engine_torque >= 0.0,
		engine_inertia,
		delta,
	)

	for w in wheels:
		var w_drive_torque: float = drive_torques.get(w, 0.0)
		var w_reflected: float = engine_inertia * drivetrain_node.get_wheel_share(w)

		var w_brake_torque: float = (
			assists.brake_torque(w) + get_handbrake_torque_nm(w) + get_gear_hold_torque_nm(w)
		)

		w.update_wheel(self, delta, w_drive_torque, w_brake_torque, w_reflected)
		w.find_obstacles(self, delta)
		w.update_squash(self, delta)

	obstacles.solve(self, wheels, delta)


func _update_gear_hold() -> void:
	if not drivetrain_node.is_in_gear():
		_gear_holding = false
		gear_hold = 0.0

		return

	var speed: float = linear_velocity.length()
	var limit: float = config.gear_hold_speed

	if _gear_holding:
		_gear_holding = speed < limit * 2.0
	else:
		_gear_holding = speed < limit

	var release: float = 1.0 - clampf((throttle_input - GEAR_HOLD_FREE) / GEAR_HOLD_FADE, 0.0, 1.0)
	gear_hold = release if _gear_holding else 0.0


func get_gear_hold_torque_nm(wheel: Wheel) -> float:
	return gear_hold * config.gear_hold_strength * brakes_for(wheel).max_torque_nm


func brakes_for(wheel: Wheel) -> BrakeConfig:
	return config.front_brakes if wheel.is_front else config.rear_brakes


func get_handbrake_torque_nm(wheel: Wheel) -> float:
	if not wheel.has_handbrake:
		return 0.0

	return handbrake_input * brakes_for(wheel).handbrake_torque_nm
