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


## The temperature stays between these.
const MIN_TEMP_C: float = -80.0
const MAX_TEMP_C: float = 300.0

## Max heat a tire can be given in one step.
const MAX_HEAT_W: float = 500000.0

## Air speed cap.
const MAX_AIR_SPEED_MPS: float = 150.0


## Current tread temperature.
var tread_c: float = 20.0

## Current core temperature.
var core_c: float = 20.0


## The temperature of the air inside the tire.
var cavity_c: float = 20.0

## Grip multiplier based on temperature.
var grip_factor: float = 1.0

## Rolling resistance multiplier based on temperature.
var rolling_factor: float = 1.0

## Heat from rolling friction.
var rolling_heat_w: float = 0.0

## Heat from tire sliding.
var sliding_heat_w: float = 0.0

var _is_started: bool = false

var _ambient_c: float = 20.0


func start(tire: Tire, ambient_c: float) -> void:
	_is_started = true
	_ambient_c = ambient_c if is_finite(ambient_c) else 20.0

	var first_c: float = _ambient_c if tire.starts_at_ambient else tire.optimal_temp_c
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
	if not (delta > 0.0):
		return

	if not _is_started:
		start(tire, ambient_c)

	if not (is_finite(tread_c) and is_finite(core_c)):
		start(tire, ambient_c)

	_ambient_c = ambient_c if is_finite(ambient_c) else _ambient_c

	rolling_w = _safe_heat(rolling_w)
	sliding_w = _safe_heat(sliding_w)
	var speed: float = clampf(speed_mps, 0.0, MAX_AIR_SPEED_MPS) if is_finite(speed_mps) else 0.0

	rolling_heat_w = rolling_w
	sliding_heat_w = sliding_w

	var tread_heat_w: float = (
		rolling_w * tire.hysteresis_tread_share + sliding_w * tire.sliding_heat_share
	)
	var core_heat_w: float = rolling_w * (1.0 - tire.hysteresis_tread_share)

	var air: float = pow(speed, AIR_SPEED_POWER)
	var tread_to_air: float = (
		maxf(tire.tread_to_air_w_k + tire.tread_to_air_speed_w_k * air, 0.0) * area_scale
	)
	var core_to_air: float = maxf(tire.core_to_air_w_k, 0.0) * area_scale
	var between: float = maxf(tire.tread_core_w_k, 0.0) * area_scale

	var tread_mass: float = maxf(tire.tread_heat_capacity_j_k * area_scale, 1.0) / delta
	var core_mass: float = maxf(tire.core_heat_capacity_j_k * area_scale, 1.0) / delta

	var a11: float = tread_mass + tread_to_air + between
	var a22: float = core_mass + core_to_air + between

	var b1: float = tread_mass * tread_c + tread_heat_w + tread_to_air * _ambient_c
	var b2: float = core_mass * core_c + core_heat_w + core_to_air * _ambient_c

	var det: float = a11 * a22 - between * between

	tread_c = clampf((b1 * a22 + between * b2) / det, MIN_TEMP_C, MAX_TEMP_C)
	core_c = clampf((a11 * b2 + between * b1) / det, MIN_TEMP_C, MAX_TEMP_C)

	_update_factors(tire)


static func _safe_heat(watts: float) -> float:
	return clampf(watts, 0.0, MAX_HEAT_W) if is_finite(watts) else 0.0


func _update_factors(tire: Tire) -> void:
	cavity_c = _ambient_c + tire.cavity_temp_share * (core_c - _ambient_c)

	var off: float = (tread_c - tire.optimal_temp_c) / maxf(tire.grip_window_c, 1.0)
	grip_factor = clampf(1.0 - tire.grip_loss_at_window * off * off, GRIP_FACTOR_MIN, 1.0)

	rolling_factor = clampf(
		1.0 + tire.rolling_resistance_per_c * (tire.reference_temp_c - core_c),
		ROLLING_FACTOR_MIN,
		ROLLING_FACTOR_MAX,
	)
