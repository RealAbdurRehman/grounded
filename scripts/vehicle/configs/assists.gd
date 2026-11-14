class_name AssistsConfig
extends Resource

@export_group("ABS")
@export var abs_enabled: bool = true

## Wheel slip level where ABS lets off brakes.
@export_range(0.5, 2.0, 0.05) var abs_release_slip: float = 1.4

## Wheel slip level where ABS starts braking again.
@export_range(0.3, 1.5, 0.05) var abs_apply_slip: float = 1.0

## How fast ABS lets go of the brakes.
@export var abs_release_rate: float = 60.0

## How fast ABS presses the brakes.
@export var abs_apply_rate: float = 15.0

## Shares rear braking to keep the car straight when one side slips.
@export var abs_rear_select_low: bool = true

## Keeps the steering straight when one front wheel has less grip.
@export_range(0.0, 1.0, 0.05) var abs_front_pressure_split: float = 0.3

@export var abs_min_speed: float = 2.5

@export_group("Traction Control")
@export var tcs_enabled: bool = true

## Wheel spin level where traction control cuts engine power.
@export_range(0.3, 1.5, 0.05) var tcs_slip_target: float = 1.0

## How fast traction control cuts engine power.
@export var tcs_cut_rate: float = 8.0

## How fast traction control gives power back.
@export var tcs_restore_rate: float = 6.0

## How fast traction control brakes a spinning wheel to slow it down.
@export var tcs_brake_gain: float = 4000.0

## Wheel spin difference ignored by TCS before it starts braking.
@export_range(0.0, 0.3, 0.01) var tcs_brake_deadband: float = 0.04

@export var tcs_brake_max_nm: float = 600.0

@export_group("Stability Control")
@export var esc_enabled: bool = true

## How much the car understeers.
@export var esc_understeer_gradient: float = 0.005

## Allowed slide before ESC kicks in.
@export var esc_deadband: float = 0.08

## Extra slide allowed when steering hard.
@export_range(0.0, 1.0, 0.05) var esc_deadband_fraction: float = 0.25

## How hard ESC brakes to stop oversteer.
@export var esc_oversteer_gain: float = 3000.0

## How hard ESC brakes to stop understeer.
@export var esc_understeer_gain: float = 1500.0

## How much engine power ESC cuts when sliding.
@export_range(0.0, 1.0, 0.05) var esc_throttle_cut: float = 0.5

## Delay before the car reacts to the steering, in seconds.
@export var esc_reference_lag: float = 0.15

@export var esc_max_brake_nm: float = 1200.0

@export var esc_min_speed: float = 6.0
