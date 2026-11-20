class_name TireWear
extends RefCounted

const MAX_SLIDING_W: float = 500000.0

## 1 means effects max out when the tread is gone.
const MAX_WEAR_EFFECT: float = 1.0

## Current tread depth.
var tread_mm: float = 8.0

## 0 means a tire is new and 1 means a tire has no tread left.
var worn_fraction: float = 0.0

var stiffness_factor: float = 1.0
var grip_factor: float = 1.0
var rolling_factor: float = 1.0

## How fast the tire is wearing out right now.
var wear_rate_mm_s: float = 0.0

## Total sliding energy the tire has absorbed.
var energy_j: float = 0.0

var _is_started: bool = false


func start(tire: Tire) -> void:
	_is_started = true

	tread_mm = maxf(tire.new_tread_mm, 0.1)
	energy_j = 0.0

	update_factors(tire)


func is_started() -> bool:
	return _is_started


func step(tire: Tire, area_scale: float, sliding_w: float, delta: float) -> void:
	if not tire.wear_enabled:
		wear_rate_mm_s = 0.0
		reset_factors()

		return

	if not _is_started or not is_finite(tread_mm):
		start(tire)

	if not (delta > 0.0):
		return

	var power_w: float = clampf(sliding_w, 0.0, MAX_SLIDING_W) if is_finite(sliding_w) else 0.0

	var mm_per_joule: float = tire.wear_mm_per_mj * 0.000001 / maxf(area_scale, 0.05)
	var lost_mm: float = power_w * delta * mm_per_joule * maxf(tire.wear_rate_scale, 0.0)

	lost_mm = minf(lost_mm, tread_mm)
	tread_mm -= lost_mm

	wear_rate_mm_s = lost_mm / delta
	energy_j += power_w * delta

	update_factors(tire)


func update_factors(tire: Tire) -> void:
	var fresh_mm: float = maxf(tire.new_tread_mm, 0.1)
	tread_mm = clampf(tread_mm, 0.0, fresh_mm)

	worn_fraction = 1.0 - tread_mm / fresh_mm

	var span_mm: float = maxf(fresh_mm - tire.measured_tread_mm, 0.1)
	var effect: float = clampf((fresh_mm - tread_mm) / span_mm, 0.0, MAX_WEAR_EFFECT)

	stiffness_factor = 1.0 + tire.worn_stiffness_gain * effect
	grip_factor = 1.0 + tire.worn_grip_gain * effect

	rolling_factor = clampf(1.0 - tire.worn_rolling_loss * worn_fraction, 0.3, 1.0)


func reset_factors() -> void:
	stiffness_factor = 1.0
	grip_factor = 1.0
	rolling_factor = 1.0
