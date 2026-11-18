class_name Vehicle
extends RigidBody3D

const GEAR_HOLD_FREE: float = 0.02
const GEAR_HOLD_FADE: float = 0.02

@export var config: ChassisConfig

@export_group("References")
@export var wheel_fl: Wheel
@export var wheel_fr: Wheel
@export var wheel_rl: Wheel
@export var wheel_rr: Wheel

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

var _com_applied: Vector3 = Vector3.INF

var _wheelbase_m: float = 2.7
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


func _cache_steering_geometry() -> void:
	var fl: Vector3 = to_local(wheel_fl.global_position)
	var fr: Vector3 = to_local(wheel_fr.global_position)
	var rl: Vector3 = to_local(wheel_rl.global_position)
	var rr: Vector3 = to_local(wheel_rr.global_position)

	_wheelbase_m = maxf(((rl.z + rr.z) - (fl.z + fr.z)) * 0.5, 0.5)

	var axle_mid_x: float = (fl.x + fr.x) * 0.5
	_steer_x_offset[wheel_fl] = fl.x - axle_mid_x
	_steer_x_offset[wheel_fr] = fr.x - axle_mid_x


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

	for w in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		if w.can_steer:
			w.steer_angle_rad = _ackermann_angle_rad(steer_angle_rad, _steer_x_offset.get(w, 0.0))


func _tire_steering_torque_nm() -> float:
	var total: float = 0.0
	for w in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		total += w.steering_torque_nm

	return total


func _speed_steer_cap_rad(speed: float, lock_rad: float) -> float:
	var sensitivity: float = config.steer_speed_sensitivity
	if sensitivity <= 0.0:
		return lock_rad

	var tire: Tire = wheel_fl.tire_model
	var ref_load: float = tire.reference_load_n
	var mu: float = tire.peak_lateral_force_n(ref_load, wheel_fl.friction_coef) / ref_load

	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var corner_accel: float = mu * gravity * gravity_scale

	var geometric_rad: float = atan(_wheelbase_m * corner_accel / maxf(speed * speed, 0.01))
	var slip_rad: float = config.steer_slip_allowance * tire.alpha_peak()
	var grip_cap_rad: float = minf(geometric_rad + slip_rad, lock_rad)

	return lerpf(lock_rad, grip_cap_rad, sensitivity)


func _ackermann_angle_rad(centre_rad: float, x_offset: float) -> float:
	var t: float = tan(centre_rad)
	var ideal_rad: float = atan2(_wheelbase_m * t, maxf(_wheelbase_m + x_offset * t, 0.01))

	return lerpf(centre_rad, ideal_rad, config.ackermann_factor)


func _compute_anti_roll_bars() -> void:
	_set_axle_arb(wheel_fl, wheel_fr, config.front_arb_stiffness)
	_set_axle_arb(wheel_rl, wheel_rr, config.rear_arb_stiffness)


func _set_axle_arb(left: Wheel, right: Wheel, stiffness: float) -> void:
	if left.is_grounded and right.is_grounded:
		var diff: float = left.spring_displacement - right.spring_displacement
		var force: float = diff * stiffness
		left.arb_force_n = force
		right.arb_force_n = -force
	else:
		left.arb_force_n = 0.0
		right.arb_force_n = 0.0


func _update_drivetrain_and_wheels(delta: float) -> void:
	var driver_brake_nm: Dictionary[Wheel, float] = { }
	for w in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		driver_brake_nm[w] = brake_input * brakes_for(w).max_torque_nm

	assists.update(delta, throttle_input, driver_brake_nm, handbrake_input)

	var driven_wheels: Array[Wheel] = []
	for w in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
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

	for w in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		var w_drive_torque: float = drive_torques.get(w, 0.0)
		var w_reflected: float = engine_inertia * drivetrain_node.get_wheel_share(w)

		var w_brake_torque: float = (
			assists.brake_torque(w) + get_handbrake_torque_nm(w) + get_gear_hold_torque_nm(w)
		)

		w.update_wheel(self, delta, w_drive_torque, w_brake_torque, w_reflected)

	var wheels: Array[Wheel] = [wheel_fl, wheel_fr, wheel_rl, wheel_rr]
	for w in wheels:
		w.find_obstacles(self, delta)

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
