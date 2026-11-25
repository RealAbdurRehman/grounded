class_name TirePressure
extends RefCounted

## Air pressure outside the tire.
const OUTSIDE_AIR_KPA: float = 101.325

const KELVIN: float = 273.15

const MIN_WARMING: float = 0.5
const MAX_WARMING: float = 2.0

const MIN_RATIO: float = 0.2
const MAX_RATIO: float = 3.0

const ROLLING_FACTOR_MIN: float = 0.5
const ROLLING_FACTOR_MAX: float = 2.5

const CORNERING_FACTOR_MIN: float = 0.5
const CORNERING_FACTOR_MAX: float = 1.5

const TRAIL_FACTOR_MIN: float = 0.5
const TRAIL_FACTOR_MAX: float = 2.0

const GRIP_FACTOR_MIN: float = 0.5
const GRIP_FACTOR_MAX: float = 1.2

const FLAT_BELOW_RATIO: float = 0.35

const FLAT_STIFFNESS: float = 0.5
const FLAT_ROLLING: float = 2.0

const FLAT_GRIP: float = 0.8
const FLAT_CORNERING: float = 0.8

var gauge_kpa: float = 220.0
var air_left: float = 1.0

var flat: float = 0.0
var ratio: float = 1.0

var stiffness_factor: float = 1.0

var rolling_factor: float = 1.0
var cornering_factor: float = 1.0

var trail_factor: float = 1.0
var grip_factor: float = 1.0


func update(tire: Tire, cavity_c: float, load_n: float) -> void:
	if not tire.pressure_enabled:
		reset(tire)
		return

	var air_c: float = cavity_c if is_finite(cavity_c) else tire.inflation_temp_c
	air_c = maxf(air_c, -KELVIN + 1.0)

	var cold_kpa: float = maxf(tire.cold_pressure_kpa, 0.0) + OUTSIDE_AIR_KPA
	var warming: float = clampf(
		(air_c + KELVIN) / maxf(tire.inflation_temp_c + KELVIN, 1.0),
		MIN_WARMING,
		MAX_WARMING,
	)

	gauge_kpa = maxf(cold_kpa * warming * air_left - OUTSIDE_AIR_KPA, 0.0)
	ratio = clampf(gauge_kpa / maxf(tire.design_pressure_kpa, 1.0), MIN_RATIO, MAX_RATIO)

	var structure: float = clampf(tire.structural_stiffness_share, 0.0, 1.0)
	stiffness_factor = structure + (1.0 - structure) * ratio

	rolling_factor = clampf(
		pow(ratio, -tire.rolling_pressure_power),
		ROLLING_FACTOR_MIN,
		ROLLING_FACTOR_MAX,
	)

	cornering_factor = clampf(
		pow(ratio, tire.cornering_pressure_power),
		CORNERING_FACTOR_MIN,
		CORNERING_FACTOR_MAX,
	)

	trail_factor = clampf(
		pow(ratio, -tire.trail_pressure_power),
		TRAIL_FACTOR_MIN,
		TRAIL_FACTOR_MAX,
	)

	var capacity: float = pow(ratio, tire.load_capacity_pressure_power)
	var over: float = maxf(ratio - 1.0, 0.0)
	grip_factor = clampf(
		tire.capacity_grip_factor(load_n, capacity) - tire.grip_loss_overinflated * over * over,
		GRIP_FACTOR_MIN,
		GRIP_FACTOR_MAX,
	)

	_go_flat(tire)


func reset(tire: Tire) -> void:
	gauge_kpa = maxf(
		(maxf(tire.cold_pressure_kpa, 0.0) + OUTSIDE_AIR_KPA) * air_left - OUTSIDE_AIR_KPA,
		0.0,
	)

	ratio = 1.0

	stiffness_factor = 1.0

	rolling_factor = 1.0
	cornering_factor = 1.0

	trail_factor = 1.0
	grip_factor = 1.0

	_go_flat(tire)


func _go_flat(tire: Tire) -> void:
	flat = 1.0 - clampf(
		gauge_kpa / maxf(tire.design_pressure_kpa * FLAT_BELOW_RATIO, 1.0),
		0.0,
		1.0,
	)

	stiffness_factor *= lerpf(1.0, FLAT_STIFFNESS, flat)
	rolling_factor *= lerpf(1.0, FLAT_ROLLING, flat)
	grip_factor *= lerpf(1.0, FLAT_GRIP, flat)
	cornering_factor *= lerpf(1.0, FLAT_CORNERING, flat)
