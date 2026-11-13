class_name ChassisConfig
extends Resource

@export_group("Specs")
## In Kg.
@export var vehicle_mass: float = 1400.0

## In Nm.
@export var max_brake_torque: float = 4500.0
@export_range(0.3, 0.9) var brake_bias_front: float = 0.75

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

## When returning the steering wheel to center, the wheels turn this many times faster.
@export_range(1.0, 4.0, 0.1) var steer_return_multiplier: float = 1.5

## Limits the maximum steering angle based on the car's speed.
@export_range(0.0, 1.0, 0.05) var steer_speed_sensitivity: float = 1.0

## Adds a little extra steering past the limit to help tires reach max grip.
@export_range(0.0, 1.5, 0.05) var steer_slip_allowance: float = 0.4

# Controls body roll
@export_group("Anti Roll Bars")
@export var front_arb_stiffness: float = 12000.0
@export var rear_arb_stiffness: float = 5000.0
