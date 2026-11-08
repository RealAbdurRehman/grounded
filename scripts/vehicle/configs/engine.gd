class_name EngineConfig
extends Resource

@export_group("Torque Curve")
## Lowest amount of torque the engine makes, in Nm.
@export var displacement: float = 140.0

## Highest amount of torque the engine makes, in Nm.
@export var boost: float = 225.0

## How fast torque drops after the peak.
@export var falloff: float = 1.0

## RPM where engine makes highest torque.
@export var cam_peak_rpm: float = 4000.0

## How wide the torque curve is.
@export var bandwidth: float = 3000.0

@export_group("RPM Limits")
@export var max_rpm: float = 6800.0

@export var idle_rpm: float = 750.0
@export var rev_limiter_rpm: float = 6500.0

@export_group("Engine Resistance")
## How heavy the flywheel is. Higher results in slower revs.
@export var flywheel_inertia: float = 0.20

## Drag force, in Nm.
@export var engine_braking_factor: float = 45.0

## How fast the engine RPM matches wheel speed.
@export var clutch_blend_rate: float = 22.0
