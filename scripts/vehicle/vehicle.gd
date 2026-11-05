class_name Vehicle
extends RigidBody3D

@export_group("Specs")
@export var vehicle_mass: float = 1350.0

@export var max_engine_force: float = 7500.0
@export var max_brake_force: float = 12000.0
@export var max_steer_angle_deg: float = 32.0

@export var frontal_area: float = 2.2
@export var drag_coefficient: float = 0.38

@export_group("Anti Roll Bars")
@export var front_arb_stiffness: float = 8000.0
@export var rear_arb_stiffness: float = 5000.0

@export_group("References")
@export var wheel_fl: Wheel
@export var wheel_fr: Wheel
@export var wheel_rl: Wheel
@export var wheel_rr: Wheel

@export var telemetry_hud: Telemetry

var throttle_input: float = 0.0
var brake_input: float = 0.0
var steer_input: float = 0.0

func _ready() -> void:
	mass = vehicle_mass

	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.2, 0.0)

	continuous_cd = true

func _physics_process(delta: float) -> void:
	_handle_inputs(delta)

	_apply_anti_roll_bars()
	_update_wheels(delta)
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

func _update_wheels(delta: float) -> void:
	var driven_wheel_count := 0

	var wheels: Array[Wheel] = [wheel_fl, wheel_fr, wheel_rl, wheel_rr]
	for w in wheels:
		if w.is_driven: driven_wheel_count += 1

	var drive_share: float = max_engine_force / max(driven_wheel_count, 1)
	var brake_share: float = max_brake_force / 4.0

	for w in wheels:
		w.update_wheel(self, delta, throttle_input, brake_input, drive_share, brake_share)

func _apply_aerodynamic_drag() -> void:
	var speed: float = linear_velocity.length()
	if speed > 0.1:
		var air_density := 1.225
		var drag_scalar: float = 0.5 * air_density * drag_coefficient * frontal_area * (speed * speed)

		var drag_vector: Vector3 = -linear_velocity.normalized() * drag_scalar
		apply_central_force(drag_vector)

func _update_telemetry() -> void:
	telemetry_hud.update_wheel_telemetry("FL", wheel_fl.suspension_force_n, rad_to_deg(wheel_fl.steer_angle_rad), 0.0, wheel_fl.compression)
	telemetry_hud.update_wheel_telemetry("FR", wheel_fr.suspension_force_n, rad_to_deg(wheel_fr.steer_angle_rad), 0.0, wheel_fr.compression)
	telemetry_hud.update_wheel_telemetry("RL", wheel_rl.suspension_force_n, 0.0, 0.0, wheel_rl.compression)
	telemetry_hud.update_wheel_telemetry("RR", wheel_rr.suspension_force_n, 0.0, 0.0, wheel_rr.compression)
