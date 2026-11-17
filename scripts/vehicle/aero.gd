class_name Aero
extends RefCounted

const DOWNFORCE_COLOR := Color(0.70, 0.45, 1.00)
const DRAG_COLOR := Color(1.00, 0.62, 0.20)
const WIND_COLOR := Color(0.35, 0.85, 1.00)

const GROUND_EFFECT_MIN: float = 0.4
const GROUND_EFFECT_MAX: float = 1.6

var airspeed_mps: float = 0.0

var dynamic_pressure_pa: float = 0.0

var flow_angle_deg: float = 0.0

var drag_n: float = 0.0
var induced_drag_n: float = 0.0

var force_long_n: float = 0.0
var force_side_n: float = 0.0

var yaw_moment_nm: float = 0.0

var wind_mps: Vector3 = Vector3.ZERO
var headwind_mps: float = 0.0
var crosswind_mps: float = 0.0

var downforce_front_n: float = 0.0
var downforce_rear_n: float = 0.0

var ground_effect_front: float = 1.0
var ground_effect_rear: float = 1.0

var travel_front: float = 0.0
var travel_rear: float = 0.0

var _vehicle: Vehicle

var _front_local: Vector3 = Vector3.ZERO
var _rear_local: Vector3 = Vector3.ZERO


func _init(vehicle: Vehicle) -> void:
	_vehicle = vehicle
	Atmosphere.watch(vehicle)

	var fl: Vector3 = vehicle.to_local(vehicle.wheel_fl.global_position)
	var fr: Vector3 = vehicle.to_local(vehicle.wheel_fr.global_position)
	var rl: Vector3 = vehicle.to_local(vehicle.wheel_rl.global_position)
	var rr: Vector3 = vehicle.to_local(vehicle.wheel_rr.global_position)

	_front_local = (fl + fr) * 0.5
	_rear_local = (rl + rr) * 0.5


func total_downforce_n() -> float:
	return downforce_front_n + downforce_rear_n


func front_balance() -> float:
	var total: float = total_downforce_n()
	if absf(total) < 1.0:
		return _vehicle.aero_config.front_share

	return clampf(downforce_front_n / total, 0.0, 1.0)


func apply() -> void:
	var config: AeroConfig = _vehicle.aero_config
	var basis: Basis = _vehicle.global_transform.basis.orthonormalized()

	var forward: Vector3 = -basis.z
	var right: Vector3 = basis.x
	var up: Vector3 = basis.y

	var center_of_mass: Vector3 = _vehicle.center_of_mass
	var half_density: float = 0.5 * Atmosphere.config.air_density

	wind_mps = Atmosphere.wind_at(_vehicle.to_global(center_of_mass))
	headwind_mps = -wind_mps.dot(forward)
	crosswind_mps = -wind_mps.dot(right)

	var air: Vector3 = wind_mps - _vehicle.linear_velocity
	var speed: float = air.length()

	var along: float = air.dot(forward)
	var across: float = air.dot(right)
	var over: float = air.dot(up)

	airspeed_mps = speed
	dynamic_pressure_pa = half_density * speed * speed
	flow_angle_deg = rad_to_deg(atan2(absf(across), absf(along)))

	var slant: float = 0.0
	if speed > 0.01:
		slant = across * across / (speed * speed)

	var drag_area: float = half_density * config.drag_coefficient * config.frontal_area
	var yaw_gain: float = 1.0 + config.drag_yaw_gain * slant

	force_long_n = drag_area * yaw_gain * speed * along
	force_side_n = half_density * config.side_force_coefficient * config.frontal_area * speed * across
	var force_up: float = drag_area * speed * over

	var head_on: float = maxf(-along, 0.0)
	var base_force: float = half_density * head_on * head_on * (
		config.downforce_coefficient * config.frontal_area
	)

	ground_effect_front = _ground_effect(_vehicle.wheel_fl, _vehicle.wheel_fr, config)
	ground_effect_rear = _ground_effect(_vehicle.wheel_rl, _vehicle.wheel_rr, config)

	travel_front = _travel_fraction(_vehicle.wheel_fl, _vehicle.wheel_fr)
	travel_rear = _travel_fraction(_vehicle.wheel_rl, _vehicle.wheel_rr)

	downforce_front_n = base_force * config.front_share * ground_effect_front
	downforce_rear_n = base_force * (1.0 - config.front_share) * ground_effect_rear

	induced_drag_n = (
		(maxf(downforce_front_n, 0.0) + maxf(downforce_rear_n, 0.0))
		/ maxf(config.downforce_efficiency, 0.1)
	)

	if speed > 0.01:
		force_long_n += induced_drag_n * along / speed
		force_side_n += induced_drag_n * across / speed

		force_up += induced_drag_n * over / speed

	drag_n = absf(force_long_n)
	yaw_moment_nm = -config.center_of_pressure_m * force_side_n

	var drag_point: Vector3 = center_of_mass + Vector3(0.0, config.drag_height_m, 0.0)
	var drag_force: Vector3 = forward * force_long_n + up * force_up
	_vehicle.apply_force(drag_force, basis * drag_point)

	var push_point: Vector3 = center_of_mass + Vector3(
		0.0,
		config.side_force_height_m,
		-config.center_of_pressure_m,
	)

	var side_force: Vector3 = right * force_side_n
	_vehicle.apply_force(side_force, basis * push_point)

	var down: Vector3 = -up
	var front_point := Vector3(_front_local.x, center_of_mass.y, _front_local.z)
	var rear_point := Vector3(_rear_local.x, center_of_mass.y, _rear_local.z)

	_vehicle.apply_force(down * downforce_front_n, basis * front_point)
	_vehicle.apply_force(down * downforce_rear_n, basis * rear_point)

	_draw_vectors(
		basis,
		down,
		drag_force,
		drag_point,
		side_force,
		push_point,
		front_point,
		rear_point,
	)


func _ground_effect(left: Wheel, right: Wheel, config: AeroConfig) -> float:
	var travel: float = (left.spring_displacement + right.spring_displacement) * 0.5
	var normal_travel: float = left.suspension_config.alignment_compression

	return clampf(
		1.0 + config.ground_effect_per_m * (travel - normal_travel),
		GROUND_EFFECT_MIN,
		GROUND_EFFECT_MAX,
	)


func _travel_fraction(left: Wheel, right: Wheel) -> float:
	var travel: float = (left.spring_displacement + right.spring_displacement) * 0.5
	return clampf(travel / maxf(left.suspension_config.suspension_rest_length, 0.001), 0.0, 1.0)


func _draw_vectors(
	basis: Basis,
	down: Vector3,
	drag_force: Vector3,
	drag_point: Vector3,
	side_force: Vector3,
	push_point: Vector3,
	front_point: Vector3,
	rear_point: Vector3,
) -> void:
	var debug_scale: float = 1.0 / 2000.0

	var origin: Vector3 = _vehicle.global_position
	var above: Vector3 = -down

	DebugDraw3D.draw_vector(
		origin + basis * front_point + above,
		down * (downforce_front_n * debug_scale),
		DOWNFORCE_COLOR,
		_vehicle,
	)

	DebugDraw3D.draw_vector(
		origin + basis * rear_point + above,
		down * (downforce_rear_n * debug_scale),
		DOWNFORCE_COLOR,
		_vehicle,
	)

	DebugDraw3D.draw_vector(
		origin + basis * drag_point,
		drag_force * debug_scale,
		DRAG_COLOR,
		_vehicle,
	)

	DebugDraw3D.draw_vector(
		origin + basis * push_point,
		side_force * debug_scale,
		WIND_COLOR,
		_vehicle,
	)

	DebugDraw3D.draw_vector(origin + Vector3(0.0, 1.25, 0.0), wind_mps * 0.25, WIND_COLOR, _vehicle)
