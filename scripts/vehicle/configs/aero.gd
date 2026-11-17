class_name AeroConfig
extends Resource

@export_group("Drag")
## In square meters.
@export var frontal_area: float = 2.2

@export var drag_coefficient: float = 0.31

## How high the wind pushes on the car. Higher values push the rear down at speed.
@export_range(-0.5, 0.8, 0.01) var drag_height_m: float = 0.0

@export_group("Crosswind")
## How hard air pushes the car sideways.
@export_range(0.0, 4.0, 0.05) var side_force_coefficient: float = 2.0

## How much the air resistance grows when the air hits the car at an angle.
@export_range(0.0, 3.0, 0.05) var drag_yaw_gain: float = 0.0

## How far ahead of the center of mass the sideways push acts.
@export_range(-1.5, 1.5, 0.01) var center_of_pressure_m: float = 0.3

## How high above the center of mass the sideways push acts.
@export_range(-0.5, 1.0, 0.01) var side_force_height_m: float = 0.2

@export_group("Downforce")
## Downforce strength. Positive pushes the car down, negative lifts it up.
@export_range(-0.5, 4.0, 0.01) var downforce_coefficient: float = -0.12

## How much of the downforce is on the front axle.
@export_range(0.0, 1.0, 0.01) var front_share: float = 0.5

## Downforce efficiency. Higher values create less drag.
@export_range(1.0, 20.0, 0.1) var downforce_efficiency: float = 4.0

@export_group("Ride Height")
## Extra downforce when the car sits lower than normal.
@export_range(0.0, 10.0, 0.1) var ground_effect_per_m: float = 2.0
