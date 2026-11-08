class_name VehicleEngine
extends Node

@export var config: EngineConfig

var current_rpm: float = 850.0
var output_torque_nm: float = 0.0

var is_rev_limiter_active: bool = false


func _ready() -> void:
	if config:
		current_rpm = config.idle_rpm


func calculate_raw_torque(rpm: float) -> float:
	var diff_rpm: float = rpm - config.cam_peak_rpm
	var exponent: float = -pow(config.falloff * diff_rpm, 2.0) / max(
		pow(config.bandwidth, 2.0),
		1.0,
	)
	var torque: float = config.displacement + (config.boost - config.displacement) * exp(exponent)

	return max(0.0, torque)


func calculate_power_kw(rpm: float) -> float:
	return (calculate_raw_torque(rpm) * rpm) / 9549.0


func update_engine(
	delta: float,
	throttle_input: float,
	target_drivetrain_rpm: float,
	is_clutch_engaged: bool,
	is_shifting: bool = false,
) -> float:
	if current_rpm >= config.rev_limiter_rpm:
		is_rev_limiter_active = true
	elif current_rpm <= config.rev_limiter_rpm - 250.0:
		is_rev_limiter_active = false

	var effective_throttle: float = 0.0 if is_rev_limiter_active else throttle_input

	if is_shifting:
		current_rpm = lerp(
			current_rpm,
			max(target_drivetrain_rpm, config.idle_rpm),
			clamp(12.0 * delta, 0.0, 1.0),
		)
	elif not is_clutch_engaged:
		var net_torque: float = 0.0

		if effective_throttle > 0.01:
			net_torque = calculate_raw_torque(current_rpm) * effective_throttle
		else:
			net_torque = -config.engine_braking_factor * (current_rpm / config.max_rpm)

		var rpm_accel: float = (net_torque / config.flywheel_inertia) * (60.0 / (2.0 * PI))
		current_rpm += rpm_accel * delta
	else:
		current_rpm = lerp(
			current_rpm,
			max(target_drivetrain_rpm, config.idle_rpm),
			clamp(config.clutch_blend_rate * delta, 0.0, 1.0),
		)

	if current_rpm < config.idle_rpm:
		current_rpm = move_toward(current_rpm, config.idle_rpm, delta * 1200.0)
	current_rpm = clamp(current_rpm, 0.0, config.max_rpm)

	if effective_throttle > 0.01:
		output_torque_nm = calculate_raw_torque(current_rpm) * effective_throttle
	else:
		output_torque_nm = -config.engine_braking_factor * clamp(
			(current_rpm - config.idle_rpm) / (config.max_rpm - config.idle_rpm),
			0.0,
			1.0,
		)

	return output_torque_nm
