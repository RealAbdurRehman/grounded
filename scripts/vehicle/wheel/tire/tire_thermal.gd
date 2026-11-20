class_name TireThermal
extends RefCounted

## Size of the reference tire that the heat numbers were tuned for.
const REFERENCE_TIRE_AREA_M2: float = 0.305 * 0.184

## How much faster air cools the tire as speed increases.
const AIR_SPEED_POWER: float = 0.8

## Limits for how rolling resistance can scale with temperature.
const ROLLING_FACTOR_MIN: float = 0.6
const ROLLING_FACTOR_MAX: float = 1.8

## Grip never drops below this fraction, no matter the temperature.
const GRIP_FACTOR_MIN: float = 0.4

## Current tread temperature.
var tread_c: float = 20.0

## Current core temperature.
var core_c: float = 20.0

## Grip multiplier based on temperature.
var grip_factor: float = 1.0

## Rolling resistance multiplier based on temperature.
var rolling_factor: float = 1.0

## Heat from rolling friction.
var rolling_heat_w: float = 0.0

## Heat from tire sliding.
var sliding_heat_w: float = 0.0

var _is_started: bool = false


func start(tire: Tire, ambient_c: float) -> void:
	_is_started = true

	var first_c: float = ambient_c if tire.starts_at_ambient else tire.optimal_temp_c
	tread_c = first_c
	core_c = first_c

	_update_factors(tire)


func step(
	tire: Tire,
	area_scale: float,
	ambient_c: float,
	rolling_w: float,
	sliding_w: float,
	speed_mps: float,
	delta: float,
) -> void:
	if not _is_started:
		start(tire, ambient_c)

	rolling_heat_w = rolling_w
	sliding_heat_w = sliding_w

	var tread_heat_w: float = (
		rolling_w * tire.hysteresis_tread_share + sliding_w * tire.sliding_heat_share
	)
	var core_heat_w: float = rolling_w * (1.0 - tire.hysteresis_tread_share)

	var air: float = pow(maxf(speed_mps, 0.0), AIR_SPEED_POWER)
	var tread_to_air: float = (tire.tread_to_air_w_k + tire.tread_to_air_speed_w_k * air) * area_scale
	var core_to_air: float = tire.core_to_air_w_k * area_scale

	var between: float = tire.tread_core_w_k * area_scale

	var tread_mass: float = tire.tread_heat_capacity_j_k * area_scale / maxf(delta, 0.0001)
	var core_mass: float = tire.core_heat_capacity_j_k * area_scale / maxf(delta, 0.0001)

	var a11: float = tread_mass + tread_to_air + between
	var a22: float = core_mass + core_to_air + between

	var b1: float = tread_mass * tread_c + tread_heat_w + tread_to_air * ambient_c
	var b2: float = core_mass * core_c + core_heat_w + core_to_air * ambient_c

	var det: float = a11 * a22 - between * between

	tread_c = (b1 * a22 + between * b2) / det
	core_c = (a11 * b2 + between * b1) / det

	_update_factors(tire)


func _update_factors(tire: Tire) -> void:
	var off: float = (tread_c - tire.optimal_temp_c) / maxf(tire.grip_window_c, 1.0)
	grip_factor = clampf(1.0 - tire.grip_loss_at_window * off * off, GRIP_FACTOR_MIN, 1.0)

	rolling_factor = clampf(
		1.0 + tire.rolling_resistance_per_c * (tire.reference_temp_c - core_c),
		ROLLING_FACTOR_MIN,
		ROLLING_FACTOR_MAX,
	)
