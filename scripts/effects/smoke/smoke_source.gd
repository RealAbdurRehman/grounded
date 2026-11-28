class_name TireSmokeSource
extends RefCounted

const RUBBER_EFFUSIVITY: float = 770.0
const ROAD_EFFUSIVITY: float = 1200.0

const TREAD_CONTACT_SHARE: float = 0.7

const SKIN_HEAT_J_M2K: float = 980.0

const SKIN_TO_TREAD_W_M2K: float = 560.0
const SKIN_TO_AIR_W_M2K: float = 10.0
const SKIN_TO_AIR_SPEED_W_M2K: float = 3.0

const SKIN_MIX_S: float = 0.25

const MIN_CONTACT_SPEED_MPS: float = 0.5
const MIN_LOAD_N: float = 100.0

const SMOKE_START_C: float = 130.0
const SMOKE_FULL_C: float = 260.0
const FULL_POWER_W: float = 40000.0

const AFTER_SMOKE_SHARE: float = 0.3
const AFTER_SMOKE_HEADROOM_C: float = 30.0
const AFTER_SMOKE_RISE_K: float = 60.0

const MAX_RISE_K: float = 600.0

var surface_c: float = 20.0
var contact_c: float = 20.0
var rate: float = 0.0

var _skin_rise_k: float = 0.0
var _heated_area_m2: float = 0.0


func step(wheel: Wheel, delta: float) -> void:
	var config: SuspensionConfig = wheel.suspension_config

	var width: float = config.width_m()
	var radius: float = config.wheel_radius

	var spin_mps: float = absf(wheel.angular_velocity_rad_s) * radius
	var power_w: float = wheel.sliding_power_w

	var patch_m: float = 0.0
	if wheel.is_grounded and not wheel.detached and wheel.normal_load_n > MIN_LOAD_N:
		var pressure_pa: float = maxf(wheel.inflation.gauge_kpa, 50.0) * 1000.0
		patch_m = clampf(wheel.normal_load_n / pressure_pa / width, 0.02, 0.4)

	var heated_m: float = minf(patch_m + spin_mps * SKIN_MIX_S, TAU * radius)
	var area: float = width * maxf(heated_m, 0.05) * TREAD_CONTACT_SHARE

	if area > _heated_area_m2 and _heated_area_m2 > 0.0:
		_skin_rise_k *= _heated_area_m2 / area
	_heated_area_m2 = area

	var skin_c: float = wheel.thermal.tread_c + _skin_rise_k

	var heat_w: float = 0.0
	var flash_k: float = 0.0

	if patch_m > 0.0:
		var rubber_m2: float = patch_m * width * TREAD_CONTACT_SHARE
		var flux: float = power_w / rubber_m2

		var rubber_s: float = patch_m / maxf(spin_mps, MIN_CONTACT_SPEED_MPS)
		var road_s: float = patch_m / maxf(wheel.ground_speed_mps, MIN_CONTACT_SPEED_MPS)

		var rubber_r: float = 2.0 * sqrt(rubber_s / PI) / RUBBER_EFFUSIVITY
		var road_r: float = 2.0 * sqrt(road_s / PI) / ROAD_EFFUSIVITY

		var road_c: float = wheel.surface.temperature_c(Atmosphere.config)
		var into_rubber: float = (road_c - skin_c + road_r * flux) / (rubber_r + road_r)

		into_rubber = minf(into_rubber, flux)
		heat_w = into_rubber * rubber_m2
		flash_k = clampf(rubber_r * into_rubber, 0.0, MAX_RISE_K)

	var air_mps: float = maxf(spin_mps, wheel.ground_speed_mps)
	var cooling_w_m2k: float = (
		SKIN_TO_TREAD_W_M2K + SKIN_TO_AIR_W_M2K + SKIN_TO_AIR_SPEED_W_M2K * air_mps
	)

	_skin_rise_k = (
		(_skin_rise_k + delta * heat_w / (SKIN_HEAT_J_M2K * area))
		/ (1.0 + delta * cooling_w_m2k / SKIN_HEAT_J_M2K)
	)

	_skin_rise_k = clampf(_skin_rise_k, -50.0, MAX_RISE_K)

	surface_c = wheel.thermal.tread_c + _skin_rise_k
	contact_c = surface_c + flash_k

	var sliding: float = (
		smoothstep(SMOKE_START_C, SMOKE_FULL_C, contact_c)
		* sqrt(clampf(power_w / FULL_POWER_W, 0.0, 1.0))
	)

	var still_hot: float = smoothstep(
		SMOKE_START_C - AFTER_SMOKE_HEADROOM_C,
		SMOKE_FULL_C - AFTER_SMOKE_HEADROOM_C,
		surface_c,
	)

	var just_slid: float = clampf(_skin_rise_k / AFTER_SMOKE_RISE_K, 0.0, 1.0)
	var leftover: float = AFTER_SMOKE_SHARE * still_hot * just_slid

	rate = maxf(sliding, leftover) * wheel.surface.smoke_scale
