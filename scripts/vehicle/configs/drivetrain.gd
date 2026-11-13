class_name DrivetrainConfig
extends Resource

enum DifferentialType {
	OPEN, # Wheels spin independently.
	LOCKED, # Wheels spin together.
	LIMITED_SLIP, # Friction based.
}

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

@export_group("Differential")
## Used for the front and rear axle differentials.
@export var differential_type: DifferentialType = DifferentialType.OPEN

## Base locking force.
@export var lsd_preload_nm: float = 40.0

## Locking strength under acceleration.
@export_range(0.0, 1.0, 0.05) var lsd_power_lock: float = 0.3

## Locking strength when coasting.
@export_range(0.0, 1.0, 0.05) var lsd_coast_lock: float = 0.15

@export_group("Center Differential")
## Only used when both axles are driven.
@export var center_differential_type: DifferentialType = DifferentialType.OPEN

## Share of the engine torque sent to the front axle.
@export_range(0.0, 1.0, 0.05) var center_front_torque_share: float = 0.4

## Base locking force.
@export var center_lsd_preload_nm: float = 80.0

## Locking strength under acceleration.
@export_range(0.0, 1.0, 0.05) var center_lsd_power_lock: float = 0.4

## Locking strength when coasting.
@export_range(0.0, 1.0, 0.05) var center_lsd_coast_lock: float = 0.2
