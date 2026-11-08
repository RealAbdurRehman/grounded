class_name VehicleEngine
extends Node

@export_group("Torque Curve")
## Lowest amount of torque the engine makes, in Nm.
@export var displacement: float = 160.0

## Highest amount of torque the engine makes, in Nm.
@export var boost: float = 320.0

## How fast torque drops after the peak.
@export var falloff: float = 1.0

## RPM where engine makes highest torque.
@export var cam_peak_rpm: float = 4200.0

## How wide the torque curve is.
@export var bandwidth: float = 2800.0

@export_group("RPM Limits")
@export var max_rpm: float = 7000.0

@export var idle_rpm: float = 850.0
@export var rev_limiter_rpm: float = 6800.0

@export_group("Engine Resistance")
## How heavy the flywheel is. Higher results in slower revs.
@export var flywheel_inertia: float = 0.18

## Drag force, in Nm.
@export var engine_braking_factor: float = 65.0

## How fast the engine RPM matches wheel speed.
@export var clutch_blend_rate: float = 22.0

var current_rpm: float = 850.0
var output_torque_nm: float = 0.0

var is_rev_limiter_active: bool = false


func _ready() -> void:
	current_rpm = idle_rpm


func calculate_raw_torque(rpm: float) -> float:
	var diff_rpm: float = rpm - cam_peak_rpm
	var exponent: float = -pow(falloff * diff_rpm, 2.0) / max(pow(bandwidth, 2.0), 1.0)
	var torque: float = displacement + (boost - displacement) * exp(exponent)

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
	if current_rpm >= rev_limiter_rpm:
		is_rev_limiter_active = true
	elif current_rpm <= rev_limiter_rpm - 250.0:
		is_rev_limiter_active = false

	var effective_throttle: float = 0.0 if is_rev_limiter_active else throttle_input

	if is_shifting:
		current_rpm = lerp(
			current_rpm,
			max(target_drivetrain_rpm, idle_rpm),
			clamp(12.0 * delta, 0.0, 1.0),
		)
	elif not is_clutch_engaged:
		var net_torque: float = 0.0

		if effective_throttle > 0.01:
			net_torque = calculate_raw_torque(current_rpm) * effective_throttle
		else:
			net_torque = -engine_braking_factor * (current_rpm / max_rpm)

		var rpm_accel: float = (net_torque / flywheel_inertia) * (60.0 / (2.0 * PI))
		current_rpm += rpm_accel * delta
	else:
		current_rpm = lerp(
			current_rpm,
			max(target_drivetrain_rpm, idle_rpm),
			clamp(clutch_blend_rate * delta, 0.0, 1.0),
		)

	if current_rpm < idle_rpm:
		current_rpm = move_toward(current_rpm, idle_rpm, delta * 1200.0)
	current_rpm = clamp(current_rpm, 0.0, max_rpm)

	if effective_throttle > 0.01:
		output_torque_nm = calculate_raw_torque(current_rpm) * effective_throttle
	else:
		output_torque_nm = -engine_braking_factor * clamp(
			(current_rpm - idle_rpm) / (max_rpm - idle_rpm),
			0.0,
			1.0,
		)

	return output_torque_nm
