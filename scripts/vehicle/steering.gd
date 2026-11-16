class_name Steering
extends RefCounted

## How hard the driver pulls the wheels toward the target angle.
const FOLLOW_GAIN: float = 30.0
const DRIVER_DAMPING: float = 2500.0

## How quickly steering input turns on and off.
const GRIP_RATE: float = 25.0

var hands_on: float = 0.0

var velocity_rad_s: float = 0.0

## Torque tires put on steering.
var load_torque_nm: float = 0.0

## Torque driver puts on steering.
var driver_torque_nm: float = 0.0


func step(
	config: ChassisConfig,
	delta: float,
	angle_rad: float,
	steer_input: float,
	target_rad: float,
	rate_rad_s: float,
	lock_rad: float,
	tire_torque_nm: float,
) -> float:
	var grabbing: float = 1.0 if absf(steer_input) > 0.02 else 0.0
	hands_on = move_toward(hands_on, grabbing, delta * GRIP_RATE)

	var inertia: float = maxf(config.steering_inertia, 0.01)
	var damping: float = config.steering_damping

	load_torque_nm = tire_torque_nm
	var passive_nm: float = tire_torque_nm - config.low_speed_return_nm_per_rad * angle_rad

	var grip: float = hands_on * DRIVER_DAMPING
	var strength_nm: float = hands_on * config.driver_strength_nm

	var momentum: float = inertia * velocity_rad_s / delta
	var error_rad: float = target_rad - angle_rad
	var speed_wanted: float = FOLLOW_GAIN * error_rad

	var new_velocity: float
	var resistance: float

	if absf(speed_wanted) <= rate_rad_s:
		resistance = inertia / delta + damping + grip + grip * FOLLOW_GAIN * delta
		new_velocity = (
			(
				momentum + hands_on * damping * speed_wanted
				+ grip * FOLLOW_GAIN * error_rad + passive_nm
			)
			/ resistance
		)

		driver_torque_nm = (
			grip * (FOLLOW_GAIN * (error_rad - new_velocity * delta) - new_velocity)
			+ hands_on * damping * speed_wanted
		)
	else:
		var speed_limit: float = signf(speed_wanted) * rate_rad_s

		resistance = inertia / delta + damping + grip
		new_velocity = (
			(momentum + hands_on * damping * speed_limit + grip * speed_limit + passive_nm)
			/ resistance
		)

		driver_torque_nm = grip * (speed_limit - new_velocity) + hands_on * damping * speed_limit

	if absf(driver_torque_nm) > strength_nm:
		driver_torque_nm = signf(driver_torque_nm) * strength_nm

		resistance = inertia / delta + damping
		new_velocity = (momentum + driver_torque_nm + passive_nm) / resistance

	new_velocity = move_toward(new_velocity, 0.0, config.steering_friction_nm / resistance)

	var new_angle: float = angle_rad + new_velocity * delta
	if absf(new_angle) > lock_rad:
		new_angle = signf(new_angle) * lock_rad

		if new_velocity * new_angle > 0.0:
			new_velocity = 0.0

	velocity_rad_s = new_velocity

	return new_angle
