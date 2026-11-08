class_name ChassisConfig
extends Resource

@export_group("Specs")
## In Kg.
@export var vehicle_mass: float = 1350.0

## In Nm.
@export var max_brake_torque: float = 5000.0
@export_range(0.3, 0.9) var brake_bias_front: float = 0.75

@export var brake_pedal_rate: float = 4.0
@export var brake_overrides_throttle: bool = true

@export var max_steer_angle_deg: float = 32.0

## In square meters.
@export var frontal_area: float = 2.2

@export var drag_coefficient: float = 0.31

# Controls body roll
@export_group("Anti Roll Bars")
@export var front_arb_stiffness: float = 4500.0
@export var rear_arb_stiffness: float = 3000.0
