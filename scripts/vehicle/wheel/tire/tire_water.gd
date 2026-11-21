class_name TireWater
extends RefCounted

## Water depth that makes a surface mostly wet.
const WETTING_MM: float = 0.3

## Speed range where wet grip is highest.
const SLOW_MPS: float = 9.0

## Speed range where wet grip is lowest.
const FAST_MPS: float = 27.0

## Grip never drops based on speed past this point.
const MAX_CURVE_MPS: float = 40.0

## Minimum grip water can leave.
const MIN_GRIP: float = 0.05

## Grip left when the tire is completely floating on water.
const FLOATING_GRIP: float = 0.1

const GROOVE_GAIN: float = 2.0

const FILM_MM: float = 1.0

## How much faster heat moves between tire and road when wet.
const HEAT_GAIN: float = 1.0

var depth_mm: float = 0.0

## How wet the tire is.
var wet_amount: float = 0.0

## Grip multiplier based on water.
var grip_factor: float = 1.0

var hydroplane_speed_mps: float = INF


func update(
	surface: SurfaceType,
	water_depth_mm: float,
	speed_mps: float,
	tire: Tire,
	tread_mm: float,
	pressure_kpa: float,
) -> void:
	depth_mm = maxf(water_depth_mm, 0.0) * (1.0 - surface.drainage) if is_finite(water_depth_mm) else 0.0
	wet_amount = 1.0 - exp(-depth_mm / WETTING_MM)

	if wet_amount < 0.0005:
		wet_amount = 0.0
		grip_factor = 1.0
		hydroplane_speed_mps = INF

		return

	var speed: float = clampf(speed_mps, 0.0, MAX_CURVE_MPS) if is_finite(speed_mps) else 0.0

	var tread_mm_now: float = tread_mm if tire.wear_enabled else tire.new_tread_mm
	var tread_share: float = clampf(tread_mm_now / maxf(tire.new_tread_mm, 0.1), 0.0, 1.0)

	var along: float = maxf(speed - SLOW_MPS, 0.0) / (FAST_MPS - SLOW_MPS)
	var with_tread: float = lerpf(surface.wet_grip_slow, surface.wet_grip_fast, along)

	var smooth: float = lerpf(surface.wet_smooth_slow, surface.wet_smooth_fast, along)
	var wet_ratio: float = maxf(lerpf(smooth, with_tread, tread_share), MIN_GRIP)

	var grip: float = lerpf(1.0, wet_ratio, wet_amount)

	var psi: float = maxf(pressure_kpa, 0.0) * 0.145038
	var base_mps: float = 10.35 * sqrt(psi) * 0.44704

	var clearance: float = tread_mm_now / maxf(depth_mm, 0.01)
	var grooves: float = lerpf(1.0, GROOVE_GAIN, clampf((clearance - 1.0) / 2.0, 0.0, 1.0))

	hydroplane_speed_mps = maxf(base_mps * grooves * surface.hydroplane_scale, 1.0)

	var floating: float = smoothstep(0.75, 1.1, speed_mps / hydroplane_speed_mps)
	var film: float = clampf(depth_mm / FILM_MM, 0.0, 1.0)

	grip_factor = maxf(lerpf(grip, minf(grip, FLOATING_GRIP), film * floating), MIN_GRIP)
