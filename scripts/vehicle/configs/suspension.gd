class_name SuspensionConfig
extends Resource

@export_group("Wheel Geometry")
## Size of the wheel, in meters.
@export var wheel_radius: float = 0.31

## How hard it is to spin the wheel.
@export var wheel_inertia: float = 1.2

@export_group("Spring")
@export var spring_stiffness: float = 24000.0

## Resists suspension bouncing.
@export var damper_stiffness: float = 2400.0

## How far the wheel hangs down from the car, in meters.
@export var suspension_rest_length: float = 0.35

## How much the spring moves compared to the wheel.
@export_range(0.4, 1.2, 0.01) var motion_ratio: float = 1.0


func wheel_rate() -> float:
	return spring_stiffness * motion_ratio * motion_ratio


func wheel_damper() -> float:
	return damper_stiffness * motion_ratio * motion_ratio
