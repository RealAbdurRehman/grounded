class_name ChassisConfig
extends Resource

@export_group("Specs")
## In Kg.
@export var vehicle_mass: float = 1400.0

@export var brake_pedal_rate: float = 4.0
@export var brake_overrides_throttle: bool = true

@export var throttle_ramp_speed: float = 6.0

@export var max_steer_angle_deg: float = 32.0

## In square meters.
@export var frontal_area: float = 2.2

@export var drag_coefficient: float = 0.31

@export_group("Steering")
## -1 for reverse ackermann, +1 for true ackermann, 0 for parallel steering.
@export_range(-1.0, 1.0, 0.05) var ackermann_factor: float = 0.8

## How fast wheels turn at low speed.
@export var steer_rate_deg_s: float = 90.0

## How much the steering wheel turns compared to the front wheels.
@export_range(8.0, 24.0, 0.5) var steering_ratio: float = 16.0

## How heavy the steering wheel feels.
@export_range(0.1, 10.0, 0.1) var steering_inertia: float = 2.0

## How much the steering resists fast movements.
@export_range(10.0, 2000.0, 10.0) var steering_damping: float = 600.0

## Friction in the steering rack.
@export_range(0.0, 60.0, 1.0) var steering_friction_nm: float = 6.0

## Maximum turning force the driver can apply.
@export_range(50.0, 2000.0, 10.0) var driver_strength_nm: float = 800.0

## How strongly the wheel straightens itself when released.
@export_range(0.0, 2000.0, 10.0) var low_speed_return_nm_per_rad: float = 1200.0

## Limits the maximum steering angle based on the car's speed.
@export_range(0.0, 1.0, 0.05) var steer_speed_sensitivity: float = 1.0

## Adds a little extra steering past the limit to help tires reach max grip.
@export_range(0.0, 1.5, 0.05) var steer_slip_allowance: float = 0.4

# Controls body roll
@export_group("Anti Roll Bars")
@export var front_arb_stiffness: float = 12000.0
@export var rear_arb_stiffness: float = 5000.0

@export_group("Brakes")
@export var front_brakes: BrakeConfig
@export var rear_brakes: BrakeConfig

@export_group("Handbrake")
@export var handbrake_pull_rate: float = 6.0
@export var handbrake_release_rate: float = 10.0
