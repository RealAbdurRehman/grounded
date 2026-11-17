class_name AirConfig
extends Resource

@export_range(0.5, 1.5, 0.005) var air_density: float = 1.225

@export_group("Wind")
@export_range(0.0, 60.0, 0.5) var wind_speed_mps: float = 0.0
@export_range(-180.0, 180.0, 1.0) var wind_heading_deg: float = 90.0

@export_group("Turbulence")
## How much the wind changes all the time.
@export_range(0.0, 15.0, 0.1) var turbulence_mps: float = 0.0

@export_range(0.5, 20.0, 0.5) var turbulence_time_s: float = 4.0

@export_group("Gusts")
@export_range(0.0, 40.0, 0.5) var gust_peak_mps: float = 12.0

@export_range(0.0, 60.0, 0.5) var gust_interval_s: float = 0.0
@export_range(0.5, 10.0, 0.1) var gust_duration_s: float = 2.5

## How far a gust can turn away from the wind direction.
@export_range(0.0, 90.0, 1.0) var gust_spread_deg: float = 45.0

@export_range(10.0, 200.0, 1.0) var gust_width_m: float = 60.0

## 0 means different every time.
@export var random_seed: int = 0
