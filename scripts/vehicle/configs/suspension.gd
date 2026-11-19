class_name SuspensionConfig
extends Resource

@export_group("Wheel Geometry")
@export var wheel_radius: float = 0.31
@export var wheel_width: float = 0.25

## How hard it is to spin the wheel.
@export var wheel_inertia: float = 1.2

@export_group("Tire and Hub")
## Weight of the wheel and brake. Affects how bumps move the wheel.
@export var unsprung_mass: float = 35.0

## How stiff the tire is when squashed.
@export var tire_stiffness: float = 190000.0

@export_group("Spring")
@export var spring_stiffness: float = 24000.0

## How far the wheel hangs down from the car, in meters.
@export var suspension_rest_length: float = 0.35

## How much the spring moves compared to the wheel.
@export_range(0.4, 1.2, 0.01) var motion_ratio: float = 1.0

# Stops bottom of the car from scraping the ground.
@export_group("Bump Stop")
@export_range(0.5, 0.98, 0.01) var bump_stop_start: float = 0.75

## How hard bump stop pushes back.
@export var bump_stop_stiffness: float = 80000.0


@export_group("Alignment")
## How much the suspension is compressed at normal ride height.
@export var alignment_compression: float = 0.15

## Wheel tilt when parked. Negative means the top leans inward.
@export_range(-8.0, 4.0, 0.1) var static_camber_deg: float = -1.0

## How much wheel tilt changes as the suspension moves up.
@export_range(-60.0, 20.0, 0.5) var camber_gain_deg_per_m: float = -20.0

## How much the front of the wheels point inward. Negative means outward.
@export_range(-3.0, 3.0, 0.01) var static_toe_deg: float = 0.0

## How much the toe changes as the wheel moves up.
@export_range(-30.0, 30.0, 0.5) var bump_steer_deg_per_m: float = 0.0

## Tilt of the steering axis.
@export_range(-12.0, 12.0, 0.1) var caster_deg: float = 5.0

# Resists suspension bouncing.
@export_group("Damper")
## Resists the wheel moving up.
@export var damper_bump: float = 1800.0

## Resists the wheel dropping.
@export var damper_rebound: float = 3000.0

## Speed where damper softens.
@export_range(0.05, 3.0, 0.05) var damper_knee_speed: float = 1.5

## Damper strength remaining after softening.
@export_range(0.05, 1.0, 0.05) var damper_knee_ratio: float = 0.5


func caster_trail() -> float:
	return wheel_radius * tan(deg_to_rad(caster_deg))


func wheel_rate() -> float:
	return spring_stiffness * motion_ratio * motion_ratio


func bump_stop_force(displacement: float) -> float:
	var start: float = suspension_rest_length * bump_stop_start
	var span: float = maxf(suspension_rest_length - start, 0.001)
	var over: float = maxf(displacement - start, 0.0)

	return bump_stop_stiffness * motion_ratio * motion_ratio * over * over / span


func damper_force(speed: float) -> float:
	var pace: float = absf(speed)
	var effective: float = (
		minf(pace, damper_knee_speed) + maxf(pace - damper_knee_speed, 0.0) * damper_knee_ratio
	)

	var rate: float = wheel_bump() if speed > 0.0 else wheel_rebound()

	return signf(speed) * rate * effective


func wheel_bump() -> float:
	return damper_bump * motion_ratio * motion_ratio


func wheel_rebound() -> float:
	return damper_rebound * motion_ratio * motion_ratio
