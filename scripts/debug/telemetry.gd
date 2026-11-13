class_name Telemetry
extends Node


class WheelSample extends RefCounted:
	var grounded: bool = false

	var normal_load_n: float = 0.0

	var longitudinal_force_n: float = 0.0
	var lateral_force_n: float = 0.0

	var grip_limit_n: float = 0.0

	var slip_ratio: float = 0.0
	var slip_angle_rad: float = 0.0

	var compression: float = 0.0


@export var vehicle: Vehicle
@export_range(0.02, 0.5, 0.01) var acceleration_filter_time: float = 0.1

var speed_mps: float = 0.0
var speed_kmh: float = 0.0

var lateral_g: float = 0.0
var longitudinal_g: float = 0.0

var throttle: float = 0.0
var brake: float = 0.0
var steering: float = 0.0

var steer_angle_deg: float = 0.0
var steer_cap_deg: float = 0.0

var rpm: float = 0.0
var rev_limit_rpm: float = 0.0

var gear_name: String = "1"
var transmission_name: String = "MANUAL"

var is_shifting: bool = false

var engine_power_kw: float = 0.0

var engine_torque_nm: float = 0.0
var wheel_torque_nm: float = 0.0

var wheels: Array[WheelSample] = []

var _wheel_nodes: Array[Wheel] = []

var _has_previous_velocity: bool = false
var _previous_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	for _i in range(4):
		wheels.append(WheelSample.new())

	process_physics_priority = 100


func _physics_process(delta: float) -> void:
	if vehicle == null:
		return

	if _wheel_nodes.is_empty():
		_wheel_nodes = [vehicle.wheel_fl, vehicle.wheel_fr, vehicle.wheel_rl, vehicle.wheel_rr]

	_sample_vehicle(delta)
	_sample_powertrain()
	_sample_wheels()


func _sample_vehicle(delta: float) -> void:
	var velocity: Vector3 = vehicle.linear_velocity

	speed_mps = velocity.length()
	speed_kmh = speed_mps * 3.6

	throttle = vehicle.throttle_input
	brake = vehicle.brake_input
	steering = vehicle.steer_angle_rad / deg_to_rad(vehicle.config.max_steer_angle_deg)

	steer_angle_deg = rad_to_deg(vehicle.steer_angle_rad)
	steer_cap_deg = rad_to_deg(vehicle.steer_cap_rad)

	if not _has_previous_velocity:
		_previous_velocity = velocity
		_has_previous_velocity = true

		return

	var acceleration_world: Vector3 = (velocity - _previous_velocity) / maxf(delta, 0.0001)
	_previous_velocity = velocity

	var basis: Basis = vehicle.global_transform.basis.orthonormalized()
	var acceleration_local: Vector3 = basis.inverse() * acceleration_world
	var filter_strength: float = 1.0 - exp(-delta / acceleration_filter_time)

	longitudinal_g = lerpf(longitudinal_g, -acceleration_local.z / 9.81, filter_strength)
	lateral_g = lerpf(lateral_g, acceleration_local.x / 9.81, filter_strength)


func _sample_powertrain() -> void:
	var engine: VehicleEngine = vehicle.engine_node
	var drivetrain: Drivetrain = vehicle.drivetrain_node

	if engine == null or drivetrain == null:
		return

	rpm = engine.current_rpm
	rev_limit_rpm = engine.config.rev_limiter_rpm

	engine_power_kw = engine.calculate_power_kw(engine.current_rpm)
	engine_torque_nm = engine.output_torque_nm

	gear_name = drivetrain.get_gear_name()
	is_shifting = drivetrain.is_shifting

	transmission_name = (
		"AUTOMATIC"
		if drivetrain.transmission_type == Drivetrain.TransmissionType.AUTOMATIC
		else "MANUAL"
	)

	var ratio: float = absf(drivetrain.get_current_ratio())
	var final_drive: float = drivetrain.config.final_drive_ratio

	wheel_torque_nm = (
		engine_torque_nm * ratio * final_drive * drivetrain.config.drivetrain_efficiency
	)


func _sample_wheels() -> void:
	for index in range(4):
		var source: Wheel = _wheel_nodes[index]
		var sample: WheelSample = wheels[index]

		sample.grounded = source.is_grounded

		sample.normal_load_n = source.normal_load_n

		sample.longitudinal_force_n = source.longitudinal_force_n
		sample.lateral_force_n = source.lateral_force_n

		sample.grip_limit_n = source.grip_limit_n

		sample.slip_ratio = source.slip_ratio
		sample.slip_angle_rad = source.slip_angle_rad

		sample.compression = source.compression
