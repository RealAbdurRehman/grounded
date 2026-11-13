class_name Vehicle
extends RigidBody3D

@export var config: ChassisConfig

@export_group("References")
@export var wheel_fl: Wheel
@export var wheel_fr: Wheel
@export var wheel_rl: Wheel
@export var wheel_rr: Wheel

@export var engine_node: VehicleEngine
@export var drivetrain_node: Drivetrain

@export var center_of_mass_node: Marker3D

var throttle_input: float = 0.0
var brake_input: float = 0.0
var steer_input: float = 0.0

var steer_cap_rad: float = 0.0
var steer_angle_rad: float = 0.0

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


func _sync_center_of_mass() -> void:
	var local_com: Vector3 = to_local(center_of_mass_node.global_position)
	if local_com.is_equal_approx(_com_applied):
		return

	_com_applied = local_com
	center_of_mass = local_com


func _physics_process(delta: float) -> void:
	_handle_inputs(delta)

	_compute_anti_roll_bars()
	_update_drivetrain_and_wheels(delta)
	_apply_aerodynamic_drag()


func _handle_inputs(delta: float) -> void:
	var throttle_target: float = Input.get_action_strength("throttle")
	var brake_target: float = Input.get_action_strength("brake")

	var pedal_rate: float = config.brake_pedal_rate
	if brake_target < brake_input:
		pedal_rate *= 3.0
	brake_input = move_toward(brake_input, brake_target, delta * pedal_rate)

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

	var unwinding: bool = (target_rad - steer_angle_rad) * steer_angle_rad < 0.0
	if unwinding:
		rate_rad_s *= config.steer_return_multiplier

	steer_angle_rad = move_toward(steer_angle_rad, target_rad, rate_rad_s * delta)
	for w in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		if w.can_steer:
			w.steer_angle_rad = _ackermann_angle_rad(steer_angle_rad, _steer_x_offset.get(w, 0.0))


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
	var driven_wheels: Array[Wheel] = []

	var total_driven_w: float = 0.0
	for w in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		if w.is_driven:
			driven_wheels.append(w)
			total_driven_w += abs(w.angular_velocity_rad_s)

	var driven_count: int = max(driven_wheels.size(), 1)
	var avg_driven_w: float = total_driven_w / driven_count
	var forward_speed: float = linear_velocity.dot(-global_transform.basis.z)
	drivetrain_node.handle_transmission(engine_node.current_rpm, forward_speed, avg_driven_w)

	var target_engine_rpm: float = drivetrain_node.calculate_target_engine_rpm(avg_driven_w)
	var engine_torque: float = engine_node.update_engine(
		delta,
		throttle_input,
		target_engine_rpm,
		drivetrain_node.is_clutch_engaged(),
		drivetrain_node.is_shifting,
	)

	var total_wheel_torque: float = drivetrain_node.calculate_wheel_drive_torque(engine_torque)
	var torque_per_driven_wheel: float = total_wheel_torque / driven_count

	var reflected_inertia: float = 0.0
	if drivetrain_node.is_clutch_engaged() and engine_node.config and drivetrain_node.config:
		var total_ratio: float = drivetrain_node.get_current_ratio() * drivetrain_node \
				.config \
				.final_drive_ratio
		reflected_inertia = engine_node.config.flywheel_inertia * total_ratio * total_ratio / driven_count

	var drive_torques: Dictionary[Wheel, float] = { }
	for w in driven_wheels:
		drive_torques[w] = torque_per_driven_wheel

	if driven_wheels.size() == 2:
		var split: Vector2 = drivetrain_node.split_axle_torque(
			total_wheel_torque,
			engine_torque >= 0.0,
			driven_wheels[0],
			driven_wheels[1],
			reflected_inertia,
			delta,
		)

		drive_torques[driven_wheels[0]] = split.x
		drive_torques[driven_wheels[1]] = split.y

	for w in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		var w_drive_torque: float = drive_torques.get(w, 0.0)
		var w_reflected: float = reflected_inertia if w.is_driven else 0.0

		var brake_torque_base: float = config.max_brake_torque
		var brake_bias: float = config.brake_bias_front
		var axle_share: float = brake_bias if w.is_front else (1.0 - brake_bias)
		var w_brake_torque: float = brake_input * brake_torque_base * axle_share * 0.5

		w.update_wheel(self, delta, w_drive_torque, w_brake_torque, w_reflected)


func _apply_aerodynamic_drag() -> void:
	var speed: float = linear_velocity.length()
	if speed > 0.1:
		var air_density := 1.225
		var drag_scalar: float = 0.5 * air_density * config.drag_coefficient * config.frontal_area * (
			speed * speed
		)

		var drag_vector: Vector3 = -linear_velocity.normalized() * drag_scalar
		apply_central_force(drag_vector)
