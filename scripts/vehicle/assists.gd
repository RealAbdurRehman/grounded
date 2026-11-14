class_name Assists
extends RefCounted

const MIN_THROTTLE: float = 0.02

var config: AssistsConfig

var abs_pressure: Dictionary[Wheel, float] = { }

var abs_active: bool = false
var tcs_active: bool = false
var esc_active: bool = false

var throttle_scale: float = 0.0

var yaw_rate_target: float = 0.0
var yaw_rate_error: float = 0.0

var _vehicle: Vehicle
var _wheelbase_m: float
var _wheels: Array[Wheel] = []

var _tcs_throttle: float = 1.0
var _esc_throttle: float = 1.0

var _demand_nm: Dictionary[Wheel, float] = { }
var _tcs_brake_nm: Dictionary[Wheel, float] = { }
var _esc_brake_nm: Dictionary[Wheel, float] = { }

var _abs_timer: Dictionary[Wheel, float] = { }
var _tcs_timer: float = 0.0
var _esc_timer: float = 0.0


func _init(vehicle: Vehicle, assists_config: AssistsConfig, wheelbase_m: float) -> void:
	_vehicle = vehicle
	config = assists_config

	_wheelbase_m = wheelbase_m
	_wheels = [vehicle.wheel_fl, vehicle.wheel_fr, vehicle.wheel_rl, vehicle.wheel_rr]

	for w in _wheels:
		_abs_timer[w] = 0.0
		abs_pressure[w] = 1.0

		_demand_nm[w] = 0.0
		_tcs_brake_nm[w] = 0.0
		_esc_brake_nm[w] = 0.0


func update(delta: float, throttle: float, driver_brake_nm: Dictionary[Wheel, float]) -> void:
	var forward_speed: float = _vehicle.linear_velocity.dot(-_vehicle.global_transform.basis.z)

	_update_traction_control(delta, throttle)
	_update_stability_control(delta, forward_speed)
	_update_abs(delta, driver_brake_nm, forward_speed)

	throttle_scale = minf(_tcs_throttle, _esc_throttle)


func filter_throttle(throttle: float) -> float:
	return maxf(throttle * throttle_scale, minf(throttle, MIN_THROTTLE))


func brake_torque(wheel: Wheel) -> float:
	return _demand_nm[wheel] * abs_pressure[wheel]


func _update_traction_control(delta: float, throttle: float) -> void:
	var cfg: AssistsConfig = config

	if not cfg.tcs_enabled or throttle < 0.05:
		_tcs_throttle = move_toward(_tcs_throttle, 1.0, cfg.tcs_restore_rate * 4.0 * delta)
		_release_brakes(_tcs_brake_nm, delta)

		_tcs_timer = maxf(_tcs_timer - delta, 0.0)
		tcs_active = _tcs_timer > 0.0

		return

	var worst: float = 0.0
	for w in _wheels:
		if w.is_driven and w.is_grounded:
			var target: float = w.tire_model.kappa_peak() * cfg.tcs_slip_target
			worst = maxf(worst, w.slip_ratio / target)

	if worst > 1.0:
		_tcs_throttle = maxf(_tcs_throttle - cfg.tcs_cut_rate * worst * delta, 0.0)
		_tcs_timer = 0.3
	elif worst < 0.9:
		var room: float = clampf(1.0 - worst, 0.0, 1.0)
		_tcs_throttle = minf(_tcs_throttle + cfg.tcs_restore_rate * room * delta, 1.0)

	_tcs_axle_brakes(_wheels[0], _wheels[1], delta)
	_tcs_axle_brakes(_wheels[2], _wheels[3], delta)

	_tcs_timer = maxf(_tcs_timer - delta, 0.0)
	tcs_active = _tcs_timer > 0.0


func _tcs_axle_brakes(left: Wheel, right: Wheel, delta: float) -> void:
	var cfg: AssistsConfig = config

	var target_left: float = 0.0
	var target_right: float = 0.0

	if left.is_driven and right.is_driven and left.is_grounded and right.is_grounded:
		var difference: float = left.slip_ratio - right.slip_ratio

		var spin_floor: float = left.tire_model.kappa_peak() * config.tcs_slip_target * 0.5
		if maxf(left.slip_ratio, right.slip_ratio) < spin_floor:
			difference = 0.0

		var excess: float = (absf(difference) - cfg.tcs_brake_deadband) * cfg.tcs_brake_gain
		var torque: float = clampf(excess, 0.0, cfg.tcs_brake_max_nm)

		if difference > 0.0:
			target_left = torque
		else:
			target_right = torque

		if torque > 0.0:
			_tcs_timer = 0.3

	_slew(_tcs_brake_nm, left, target_left, delta)
	_slew(_tcs_brake_nm, right, target_right, delta)


func _update_stability_control(delta: float, forward_speed: float) -> void:
	var cfg: AssistsConfig = config

	if not cfg.esc_enabled or forward_speed < cfg.esc_min_speed:
		_esc_throttle = move_toward(_esc_throttle, 1.0, 2.0 * delta)
		_release_brakes(_esc_brake_nm, delta)

		yaw_rate_target = 0.0
		yaw_rate_error = 0.0

		_esc_timer = maxf(_esc_timer - delta, 0.0)
		esc_active = _esc_timer > 0.0

		return

	var steer_rad: float = _vehicle.steer_angle_rad
	var desired: float = forward_speed * steer_rad / (
		_wheelbase_m + cfg.esc_understeer_gradient * forward_speed * forward_speed
	)

	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var limit: float = _estimate_friction() * gravity * _vehicle.gravity_scale / forward_speed
	desired = clampf(desired, -limit, limit)

	var blend: float = 1.0 - exp(-delta / maxf(cfg.esc_reference_lag, 0.001))
	yaw_rate_target = lerpf(yaw_rate_target, desired, blend)

	var yaw_rate: float = _vehicle.angular_velocity.dot(_vehicle.global_transform.basis.y)
	yaw_rate_error = yaw_rate - yaw_rate_target

	var turn_sign: float = (
		signf(yaw_rate_target)
		if absf(yaw_rate_target) > 0.02
		else signf(yaw_rate)
	)

	var excess: float = yaw_rate_error * turn_sign
	var deadband: float = cfg.esc_deadband + cfg.esc_deadband_fraction * absf(yaw_rate_target)

	var target_brakes: Dictionary[Wheel, float] = { }
	for w in _wheels:
		target_brakes[w] = 0.0

	var intervention: float = 0.0
	var brake_right: bool = yaw_rate_error > 0.0

	if excess > deadband:
		var wheel: Wheel = _vehicle.wheel_fr if brake_right else _vehicle.wheel_fl
		target_brakes[wheel] = clampf(
			(excess - deadband) * cfg.esc_oversteer_gain,
			0.0,
			cfg.esc_max_brake_nm,
		)

		intervention = excess - deadband
	elif excess < -deadband:
		var wheel: Wheel = _vehicle.wheel_rr if brake_right else _vehicle.wheel_rl
		target_brakes[wheel] = clampf(
			(-excess - deadband) * cfg.esc_understeer_gain,
			0.0,
			cfg.esc_max_brake_nm,
		)

		intervention = -excess - deadband

	for w in _wheels:
		_slew(_esc_brake_nm, w, target_brakes[w], delta)

	if intervention > 0.0:
		var cut: float = cfg.esc_throttle_cut * clampf(intervention / 0.3, 0.0, 1.0)
		_esc_throttle = minf(_esc_throttle, 1.0 - cut)

		_esc_timer = 0.3
	else:
		_esc_throttle = move_toward(_esc_throttle, 1.0, 2.0 * delta)

	_esc_timer = maxf(_esc_timer - delta, 0.0)
	esc_active = _esc_timer > 0.0


func _update_abs(
	delta: float,
	driver_brake_nm: Dictionary[Wheel, float],
	forward_speed: float,
) -> void:
	var cfg: AssistsConfig = config
	abs_active = false

	for w in _wheels:
		var demand: float = driver_brake_nm.get(w, 0.0) + _tcs_brake_nm[w] + _esc_brake_nm[w]
		_demand_nm[w] = demand

		var pressure: float = abs_pressure[w]
		var braking: bool = (
			demand > 1.0 and w.is_grounded and absf(forward_speed) > cfg.abs_min_speed
		)

		if not cfg.abs_enabled or not braking:
			_abs_timer[w] = maxf(_abs_timer[w] - delta, 0.0)

			abs_pressure[w] = 1.0
			abs_active = abs_active or _abs_timer[w] > 0.0
			continue

		var slip: float = -w.slip_ratio * signf(forward_speed)
		var peak: float = w.tire_model.kappa_peak()

		if slip > peak * cfg.abs_release_slip:
			pressure -= cfg.abs_release_rate * delta
			_abs_timer[w] = 0.3
		elif slip < peak * cfg.abs_apply_slip:
			pressure += cfg.abs_apply_rate * delta

		_abs_timer[w] = maxf(_abs_timer[w] - delta, 0.0)

		abs_pressure[w] = clampf(pressure, 0.0, 1.0)
		abs_active = abs_active or _abs_timer[w] > 0.0

	if cfg.abs_enabled:
		_balance_axle(_wheels[0], _wheels[1], false, cfg.abs_front_pressure_split)
		_balance_axle(_wheels[2], _wheels[3], cfg.abs_rear_select_low, 1.0)


func _balance_axle(left: Wheel, right: Wheel, select_low: bool, max_split: float) -> void:
	if not (left.is_grounded and right.is_grounded):
		return

	var low: float = minf(abs_pressure[left], abs_pressure[right])
	if select_low:
		abs_pressure[left] = low
		abs_pressure[right] = low
	else:
		abs_pressure[left] = minf(abs_pressure[left], low + max_split)
		abs_pressure[right] = minf(abs_pressure[right], low + max_split)


func _estimate_friction() -> float:
	var grip: float = 0.0
	var wheel_load: float = 0.0

	for w in _wheels:
		if w.is_grounded:
			grip += w.grip_limit_n
			wheel_load += w.normal_load_n

	return grip / maxf(wheel_load, 1.0)


func _slew(values: Dictionary[Wheel, float], wheel: Wheel, target: float, delta: float) -> void:
	var rate: float = 12000.0 if target > values[wheel] else 30000.0
	values[wheel] = move_toward(values[wheel], target, rate * delta)


func _release_brakes(values: Dictionary[Wheel, float], delta: float) -> void:
	for w in _wheels:
		_slew(values, w, 0.0, delta)
