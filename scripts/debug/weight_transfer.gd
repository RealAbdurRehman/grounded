class_name WeightTransfer
extends Node

@export var vehicle: Vehicle
@export_range(0.02, 0.5, 0.01) var accel_smoothing_time: float = 0.15

var wheelbase: float = 1.0

var cg_to_front: float = 0.5
var cg_to_rear: float = 0.5

var track_front: float = 1.0
var track_rear: float = 1.0

var cg_height: float = 0.5

var roll_stiffness_front: float = 1.0
var roll_stiffness_rear: float = 1.0

var front_roll_share: float = 0.5

var accel_long: float = 0.0
var accel_lat: float = 0.0

var predicted: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var measured: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

var roll_pred_deg: float = 0.0
var roll_meas_deg: float = 0.0

var lift_off_g: float = 0.0

var _wheels: Array[Wheel] = []

var _prev_velocity: Vector3 = Vector3.ZERO

var _geometry_ready: bool = false

var _h_valid: bool = false


func _ready() -> void:
	await get_tree().physics_frame
	_measure_geometry()

	_prev_velocity = vehicle.linear_velocity
	_geometry_ready = true


func _measure_geometry() -> void:
	_wheels = [vehicle.wheel_fl, vehicle.wheel_fr, vehicle.wheel_rl, vehicle.wheel_rr]

	var com: Vector3 = vehicle.center_of_mass
	var fl: Vector3 = vehicle.to_local(vehicle.wheel_fl.global_position)
	var fr: Vector3 = vehicle.to_local(vehicle.wheel_fr.global_position)
	var rl: Vector3 = vehicle.to_local(vehicle.wheel_rl.global_position)
	var rr: Vector3 = vehicle.to_local(vehicle.wheel_rr.global_position)

	var front_z: float = (fl.z + fr.z) * 0.5
	var rear_z: float = (rl.z + rr.z) * 0.5

	wheelbase = rear_z - front_z

	cg_to_front = com.z - front_z
	cg_to_rear = rear_z - com.z

	track_front = absf(fl.x - fr.x)
	track_rear = absf(rl.x - rr.x)

	roll_stiffness_front = _axle_roll_stiffness(
		vehicle.wheel_fl,
		track_front,
		vehicle.config.front_arb_stiffness,
	)
	roll_stiffness_rear = _axle_roll_stiffness(
		vehicle.wheel_rl,
		track_rear,
		vehicle.config.rear_arb_stiffness,
	)
	front_roll_share = roll_stiffness_front / maxf(roll_stiffness_front + roll_stiffness_rear, 1.0)


func _axle_roll_stiffness(wheel: Wheel, track: float, arb_stiffness: float) -> float:
	var k_wheel: float = wheel.suspension_config.spring_stiffness
	return (0.5 * k_wheel + arb_stiffness) * track * track


func _physics_process(delta: float) -> void:
	if not _geometry_ready:
		return

	_update_acceleration(delta)

	_update_cg_height()
	_update_prediction()
	_update_measurement()


func _update_acceleration(delta: float) -> void:
	var v: Vector3 = vehicle.linear_velocity
	var a_world: Vector3 = (v - _prev_velocity) / maxf(delta, 0.0001)
	_prev_velocity = v

	var basis: Basis = vehicle.global_transform.basis.orthonormalized()
	var k: float = 1.0 - exp(-delta / accel_smoothing_time)

	accel_long = lerpf(accel_long, a_world.dot(-basis.z), k)
	accel_lat = lerpf(accel_lat, a_world.dot(basis.x), k)


func _update_cg_height() -> void:
	var sum_y: float = 0.0
	var count: int = 0
	for w in _wheels:
		if w.is_grounded:
			sum_y += vehicle.to_local(w.contact_point).y
			count += 1

	if count == 0:
		return

	var h: float = vehicle.center_of_mass.y - sum_y / count
	cg_height = h if not _h_valid else lerpf(cg_height, h, 0.05)
	_h_valid = true


func _update_prediction() -> void:
	var m: float = vehicle.mass
	var g: float = float(ProjectSettings.get_setting("physics/3d/default_gravity")) * vehicle.gravity_scale

	var weight: float = m * g
	var safe_wheelbase: float = maxf(absf(wheelbase), 0.001)
	var avg_track: float = 0.5 * (track_front + track_rear)
	var safe_track: float = maxf(avg_track, 0.001)

	var front_static: float = weight * cg_to_rear / safe_wheelbase
	var rear_static: float = weight * cg_to_front / safe_wheelbase

	var dw_long: float = m * accel_long * cg_height / safe_wheelbase
	var front_axle: float = maxf(front_static - dw_long, 0.0)
	var rear_axle: float = maxf(rear_static + dw_long, 0.0)

	var x_total: float = m * absf(accel_lat) * cg_height / safe_track
	var x_front: float = x_total * front_roll_share
	var x_rear: float = x_total - x_front

	var front_pair: Vector2 = _axle_pair(front_axle, x_front)
	var rear_pair: Vector2 = _axle_pair(rear_axle, x_rear)

	var left_outside: bool = accel_lat >= 0.0

	predicted[0] = front_pair.x if left_outside else front_pair.y
	predicted[1] = front_pair.y if left_outside else front_pair.x
	predicted[2] = rear_pair.x if left_outside else rear_pair.y
	predicted[3] = rear_pair.y if left_outside else rear_pair.x

	var k_total: float = roll_stiffness_front + roll_stiffness_rear
	var k_eff: float = maxf(k_total - weight * cg_height, 1.0)

	roll_pred_deg = rad_to_deg(m * absf(accel_lat) * cg_height / k_eff)

	lift_off_g = safe_track / (2.0 * maxf(cg_height, 0.01))


func _axle_pair(axle_load: float, transfer: float) -> Vector2:
	var outside: float = axle_load * 0.5 + transfer
	var inside: float = axle_load * 0.5 - transfer
	if inside < 0.0:
		outside += inside
		inside = 0.0

	return Vector2(outside, inside)


func _update_measurement() -> void:
	for i in range(4):
		measured[i] = _wheels[i].normal_load_n

	var basis: Basis = vehicle.global_transform.basis.orthonormalized()
	roll_meas_deg = rad_to_deg(asin(clampf(basis.x.y, -1.0, 1.0)))
