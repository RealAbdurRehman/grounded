class_name SuspensionConfig
extends Resource

@export_group("Wheel Geometry")
## Size of the wheel, in meters.
@export var wheel_radius: float = 0.33

## How hard it is to spin the wheel.
@export var wheel_inertia: float = 1.2

@export_group("Spring")
@export var spring_stiffness: float = 26000.0

## Resists suspension bouncing.
@export var damper_stiffness: float = 2300.0

## How far the wheel hangs down from the car, in meters.
@export var suspension_rest_length: float = 0.35
