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

## Max speed you can be going to shift into reverse.
@export var selector_max_speed: float = 1.5
