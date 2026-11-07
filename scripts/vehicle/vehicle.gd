class_name Vehicle
extends RigidBody3D

@export_group("Specs")
## In Kg.
@export var vehicle_mass: float = 1350.0

## In Nm.
@export var max_brake_torque: float = 3200.0

@export var max_steer_angle_deg: float = 32.0

## In square meters.
@export var frontal_area: float = 2.2

@export var drag_coefficient: float = 0.38

# Controls body roll
@export_group("Anti Roll Bars")
@export var front_arb_stiffness: float = 8000.0
@export var rear_arb_stiffness: float = 5000.0

@export_group("References")
@export var wheel_fl: Wheel
@export var wheel_fr: Wheel
@export var wheel_rl: Wheel
@export var wheel_rr: Wheel

@export var engine_node: VehicleEngine
@export var drivetrain_node: Drivetrain

@export var telemetry_hud: Telemetry

var throttle_input: float = 0.0
var brake_input: float = 0.0
var steer_input: float = 0.0

func _ready() -> void:
	mass = vehicle_mass

	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.2, 0.0)

	continuous_cd = true

	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE

	linear_damp = 0.0
	angular_damp = 0.0

func _physics_process(delta: float) -> void:
	_handle_inputs(delta)

	_update_drivetrain_and_wheels(delta)
	_apply_anti_roll_bars()
	_apply_aerodynamic_drag()
	
	_update_telemetry()

func _handle_inputs(delta: float) -> void:
	throttle_input = Input.get_action_strength("throttle")
	brake_input = Input.get_action_strength("brake")

	var target_steer := Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")
	steer_input = move_toward(steer_input, target_steer, delta * 4.0)

	var steer_rad := deg_to_rad(steer_input * max_steer_angle_deg)
	wheel_fl.steer_angle_rad = steer_rad
	wheel_fr.steer_angle_rad = steer_rad

func _apply_anti_roll_bars() -> void:
	if wheel_fl.is_grounded and wheel_fr.is_grounded:
		var front_diff: float = wheel_fl.spring_displacement - wheel_fr.spring_displacement
		var front_arb_force: float = front_diff * front_arb_stiffness
		apply_force(wheel_fl.contact_normal * -front_arb_force, wheel_fl.contact_point - global_position)
		apply_force(wheel_fr.contact_normal * front_arb_force, wheel_fr.contact_point - global_position)

	if wheel_rl.is_grounded and wheel_rr.is_grounded:
		var rear_diff: float = wheel_rl.spring_displacement - wheel_rr.spring_displacement
		var rear_arb_force: float = rear_diff * rear_arb_stiffness
		apply_force(wheel_rl.contact_normal * -rear_arb_force, wheel_rl.contact_point - global_position)
		apply_force(wheel_rr.contact_normal * rear_arb_force, wheel_rr.contact_point - global_position)

func _update_drivetrain_and_wheels(delta: float) -> void:
	var driven_wheels: Array[Wheel] = []

	var total_driven_w: float = 0.0
	for w in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		if w.is_driven:
			driven_wheels.append(w)
			total_driven_w += abs(w.angular_velocity_rad_s)

	var avg_driven_w: float = total_driven_w / max(driven_wheels.size(), 1)
	var forward_speed: float = linear_velocity.dot(-global_transform.basis.z)
	drivetrain_node.handle_transmission(engine_node.current_rpm, forward_speed, avg_driven_w)

	var target_engine_rpm: float = drivetrain_node.calculate_target_engine_rpm(avg_driven_w)
	var engine_torque: float = engine_node.update_engine(delta, throttle_input, target_engine_rpm, drivetrain_node.is_clutch_engaged(), drivetrain_node.is_shifting)

	var total_wheel_torque: float = drivetrain_node.calculate_wheel_drive_torque(engine_torque)
	var torque_per_driven_wheel: float = total_wheel_torque / max(driven_wheels.size(), 1)

	for w in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		var w_drive_torque: float = torque_per_driven_wheel if w.is_driven else 0.0
		w.update_wheel(self, delta, w_drive_torque, brake_input, max_brake_torque)

func _apply_aerodynamic_drag() -> void:
	var speed: float = linear_velocity.length()
	if speed > 0.1:
		var air_density := 1.225
		var drag_scalar: float = 0.5 * air_density * drag_coefficient * frontal_area * (speed * speed)

		var drag_vector: Vector3 = -linear_velocity.normalized() * drag_scalar
		apply_central_force(drag_vector)

func _update_telemetry() -> void:
	var fl_grip := wheel_fl.friction_coef * wheel_fl.suspension_force_n
	telemetry_hud.update_wheel_telemetry("FL", wheel_fl.suspension_force_n, rad_to_deg(wheel_fl.steer_angle_rad), 0.0, wheel_fl.compression, wheel_fl.longitudinal_force_n, wheel_fl.lateral_force_n, fl_grip)

	var fr_grip := wheel_fr.friction_coef * wheel_fr.suspension_force_n
	telemetry_hud.update_wheel_telemetry("FR", wheel_fr.suspension_force_n, rad_to_deg(wheel_fr.steer_angle_rad), 0.0, wheel_fr.compression, wheel_fr.longitudinal_force_n, wheel_fr.lateral_force_n, fr_grip)

	var rl_grip := wheel_rl.friction_coef * wheel_rl.suspension_force_n
	telemetry_hud.update_wheel_telemetry("RL", wheel_rl.suspension_force_n, 0.0, 0.0, wheel_rl.compression, wheel_rl.longitudinal_force_n, wheel_rl.lateral_force_n, rl_grip)

	var rr_grip := wheel_rr.friction_coef * wheel_rr.suspension_force_n
	telemetry_hud.update_wheel_telemetry("RR", wheel_rr.suspension_force_n, 0.0, 0.0, wheel_rr.compression, wheel_rr.longitudinal_force_n, wheel_rr.lateral_force_n, rr_grip)
