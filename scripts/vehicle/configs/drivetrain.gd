class_name DrivetrainConfig
extends Resource

@export_group("Transmission")
## How much power actually reaches the wheels.
@export var drivetrain_efficiency: float = 0.88

@export_group("Gear Ratios")
## Gears, in order: [Reverse, Neutral, 1st, 2nd, ...]
@export var gear_ratios: Array[float] = [-3.4, 0.0, 3.6, 2.05, 1.4, 1.05, 0.84, 0.68]

## Multiplies gear ratio to get the final drive.
@export var final_drive_ratio: float = 3.80

@export_group("Shifting")
## Time it takes to change gears.
@export var shift_delay_seconds: float = 0.20

@export var auto_upshift_rpm: float = 5200.0
@export var auto_downshift_rpm: float = 1600.0

## Engine speed to shift up when pressing the throttle gently.
@export var auto_light_upshift_rpm: float = 3000.0

## Engine speed to shift down when flooring the throttle.
@export var auto_kickdown_rpm: float = 2700.0

## With the throttle pressed this far, the automatic may skip several gears going down.
@export_range(0.5, 1.0, 0.01) var auto_kickdown_throttle: float = 0.85

## Max speed you can be going to shift into reverse.
@export var selector_max_speed: float = 1.5

@export_group("Differentials")
## Splits torque between front wheels.
@export var front_differential: DifferentialConfig

## Splits torque between rear wheels.
@export var rear_differential: DifferentialConfig

## Splits torque between the front and rear axles. Only used when both are driven.
@export var center_differential: DifferentialConfig

## Share of the engine torque sent to the front axle.
@export_range(0.0, 1.0, 0.05) var center_front_torque_share: float = 0.4
