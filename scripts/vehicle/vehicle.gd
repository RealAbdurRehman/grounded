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

@export var telemetry_hud: Telemetry

var throttle_input: float = 0.0
var brake_input: float = 0.0
var steer_input: float = 0.0

var _com_applied: Vector3 = Vector3.INF


func _ready() -> void:
	if config:
		mass = config.vehicle_mass

	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	_sync_center_of_mass()

	continuous_cd = true

	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE

	linear_damp = 0.0
	angular_damp = 0.0


func _sync_center_of_mass() -> void:
	if not center_of_mass_node:
		return

	var local_com: Vector3 = to_local(center_of_mass_node.global_position)
	if local_com.is_equal_approx(_com_applied):
		return

	_com_applied = local_com
	center_of_mass = local_com


func _physics_process(delta: float) -> void:
	_handle_inputs(delta)

	_update_drivetrain_and_wheels(delta)
	_apply_anti_roll_bars()
	_apply_aerodynamic_drag()

	_update_telemetry()


func _handle_inputs(delta: float) -> void:
	throttle_input = Input.get_action_strength("throttle")
	brake_input = Input.get_action_strength("brake")

	var target_steer := Input.get_action_strength("steer_left") - Input.get_action_strength(
		"steer_right"
	)
	steer_input = move_toward(steer_input, target_steer, delta * 4.0)

	var max_steer: float = config.max_steer_angle_deg if config else 32.0
	var steer_rad := deg_to_rad(steer_input * max_steer)
	for w in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		if w and w.can_steer:
			w.steer_angle_rad = steer_rad


func _apply_anti_roll_bars() -> void:
	if wheel_fl.is_grounded and wheel_fr.is_grounded:
		var front_diff: float = wheel_fl.spring_displacement - wheel_fr.spring_displacement
		var front_arb_force: float = front_diff * config.front_arb_stiffness
		apply_force(
			wheel_fl.contact_normal * front_arb_force,
			wheel_fl.global_position - global_position,
		)
		apply_force(
			wheel_fr.contact_normal * -front_arb_force,
			wheel_fr.global_position - global_position,
		)

	if wheel_rl.is_grounded and wheel_rr.is_grounded:
		var rear_diff: float = wheel_rl.spring_displacement - wheel_rr.spring_displacement
		var rear_arb_force: float = rear_diff * config.rear_arb_stiffness
		apply_force(
			wheel_rl.contact_normal * rear_arb_force,
			wheel_rl.global_position - global_position,
		)
		apply_force(
			wheel_rr.contact_normal * -rear_arb_force,
			wheel_rr.global_position - global_position,
		)


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

	for w in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		var w_drive_torque: float = torque_per_driven_wheel if w.is_driven else 0.0
		var w_reflected: float = reflected_inertia if w.is_driven else 0.0

		var brake_torque_base: float = config.max_brake_torque if config else 5000.0
		var brake_bias: float = config.brake_bias_front if config else 0.7
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


func _update_telemetry() -> void:
	if not telemetry_hud:
		return

	var ids: Array[String] = ["FL", "FR", "RL", "RR"]
	var wheels: Array[Wheel] = [wheel_fl, wheel_fr, wheel_rl, wheel_rr]

	for i in range(4):
		var w: Wheel = wheels[i]
		telemetry_hud.update_wheel_telemetry(
			ids[i],
			w.suspension_force_n,
			rad_to_deg(w.slip_angle_rad),
			w.slip_ratio,
			w.compression,
			w.longitudinal_force_n,
			w.lateral_force_n,
			w.grip_limit_n,
		)
