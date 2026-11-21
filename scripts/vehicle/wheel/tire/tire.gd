class_name Tire
extends Resource

# Longitudinal Pacejka Magic Formula Coefficients
@export_group("Longitudinal Slip")
## Stiffness factor.
@export var long_B: float = 15.0

## Shape factor.
@export var long_C: float = 1.4

## Peak factor, normalized.
@export var long_D: float = 1.05

## Curvature factor, negative values will result in a sharper peak.
@export var long_E: float = -1.0

# Lateral Pacejka Magic Formula Coefficients
@export_group("Lateral Slip")
## Stiffness factor.
@export var lat_B: float = 12.0

## Shape factor.
@export var lat_C: float = 1.35

## Peak factor, normalized.
@export var lat_D: float = 1.0

## Curvature factor, negative values will result in a sharper peak.
@export var lat_E: float = -1.0

@export_group("Load Sensitivity")
## Weight resting on a single car tire.
@export var reference_load_n: float = 3300.0

## Grip lost due to tire overload.
@export var load_sensitivity: float = 0.2

@export_group("Combined Slip")
## How much slip angle shrinks the longitudinal peak.
@export var combined_long_strength: float = 0.5

## How much slip ratio shrinks the lateral peak.
@export var combined_lat_strength: float = 0.35

@export_group("Camber")
## How much cornering grip the wheel gains from leaning.
@export_range(0.0, 0.5, 0.01) var camber_stiffness_ratio: float = 0.12

## How much grip is lost when the wheel leans too far.
@export_range(0.0, 10.0, 0.1) var camber_grip_loss: float = 3.0

@export_group("Low Speed Handling")
@export var slip_speed_floor: float = 1.0

@export var low_speed_start: float = 1.0
@export var low_speed_threshold: float = 3.0

@export_group("Aligning Moment")
## Strength of steering self centering force.
@export_range(0.0, 0.08, 0.001) var pneumatic_trail_m: float = 0.03

## How much slip is allowed before self centering fades.
@export_range(0.5, 3.0, 0.05) var trail_zero_slip_ratio: float = 1.3

@export_group("Rolling Radius")
## How much the tire's rolling radius shrinks when squashed.
@export_range(0.0, 1.0, 0.01) var rolling_radius_loss: float = 0.25 # 0.25 is a realistic amount.

@export_group("Static Hold")
## Speed below which braking wheels stick to the road, in meters per second.
@export var stick_speed: float = 0.15

## How far the tire can stretch before slipping.
@export var stick_deflection_m: float = 0.02

## How smooth the sticking effect is.
@export_range(0.1, 2.0, 0.05) var stick_damping_ratio: float = 0.8

@export_group("Tire Temperature")
@export var temperature_enabled: bool = true

## Start at temperature of the air.
@export var starts_at_ambient: bool = true

## Temperature where the tire has the most grip.
@export_range(20.0, 150.0, 1.0) var optimal_temp_c: float = 65.0

## How far the tire can get from optimal temperature before losing grip.
@export_range(10.0, 150.0, 1.0) var grip_window_c: float = 50.0

## Grip lost when the tire is completely cold or overheated.
@export_range(0.0, 0.6, 0.01) var grip_loss_at_window: float = 0.10

@export_subgroup("Rolling Resistance")
## How much colder temperatures increase rolling resistance.
@export_range(0.0, 0.02, 0.0005) var rolling_resistance_per_c: float = 0.006

## The temperature where rolling resistance is normal.
@export_range(0.0, 120.0, 1.0) var reference_temp_c: float = 40.0

@export_subgroup("Heat")
## How much tire flexing heat goes into the tread instead of the tires body.
@export_range(0.0, 1.0, 0.01) var hysteresis_tread_share: float = 0.59

## How much sliding heat goes into the tire instead of the road.
@export_range(0.0, 1.0, 0.05) var sliding_heat_share: float = 0.5

@export_subgroup("Heat Capacity and Cooling")
## How much heat the tire body absorbs.
@export_range(100.0, 200000.0, 100.0) var core_heat_capacity_j_k: float = 14000.0

## How much heat the tread absorbs.
@export_range(100.0, 100000.0, 100.0) var tread_heat_capacity_j_k: float = 3000.0

## How fast the tire body cools down when driving.
@export_range(0.0, 500.0, 0.5) var core_to_air_w_k: float = 15.0

## How fast the tread cools down when parked.
@export_range(0.0, 500.0, 0.5) var tread_to_air_w_k: float = 21.0

## How much faster the tread cools down at high speed.
@export_range(0.0, 50.0, 0.1) var tread_to_air_speed_w_k: float = 0.8

## How fast heat moves between the tread and the tire body.
@export_range(0.0, 1000.0, 1.0) var tread_core_w_k: float = 50.0

@export_group("Road")
## How well heat moves between the tread and the road.
@export_range(0.0, 2000.0, 10.0) var road_heat_transfer: float = 215.0

@export_group("Air in tire")
## How much the air inside the tire warms up from the tire body.
@export_range(0.0, 1.0, 0.01) var cavity_temp_share: float = 0.6

@export_group("Tire Pressure")
@export var pressure_enabled: bool = true

## How much air is in the tire when cold.
@export_range(50.0, 450.0, 1.0) var cold_pressure_kpa: float = 220.0

## Pressure the tire is designed for.
@export_range(50.0, 450.0, 1.0) var design_pressure_kpa: float = 220.0

## Temperature the tire was filled at.
@export_range(-20.0, 50.0, 1.0) var inflation_temp_c: float = 20.0

## How much stiffness comes from the rubber itself.
@export_range(0.0, 0.5, 0.01) var structural_stiffness_share: float = 0.15

@export_subgroup("Effects")
## How strongly pressure changes rolling resistance.
@export_range(0.0, 1.5, 0.05) var rolling_pressure_power: float = 0.55

## How strongly pressure changes cornering grip.
@export_range(0.0, 1.0, 0.05) var cornering_pressure_power: float = 0.5

## How much low pressure makes the steering want to self center more.
@export_range(0.0, 3.0, 0.05) var trail_pressure_power: float = 1.5

## How much the load the tire is made for changes with pressure.
@export_range(0.0, 2.0, 0.05) var load_capacity_pressure_power: float = 1.0

## How much grip is lost when the tire is overinflated.
@export_range(0.0, 4.0, 0.1) var grip_loss_overinflated: float = 0.7

@export_group("Tire Wear")
@export var wear_enabled: bool = true

## Tread depth of a new tire.
@export_range(3.0, 14.0, 0.5) var new_tread_mm: float = 8.0

## How much tread is lost from sliding on the road.
@export_range(0.0, 1.0, 0.0001) var wear_mm_per_mj: float = 0.01

## Multiplier for how fast tires wear out. 1 is realistic.
@export_range(0.0, 10000.0, 1.0) var wear_rate_scale: float = 1.0

@export_subgroup("Effects")
## Tread depth where the effects max out.
@export_range(1.0, 6.0, 0.5) var measured_tread_mm: float = 3.0

## How much stiffer the tire gets as it wears down.
@export_range(0.0, 1.0, 0.01) var worn_stiffness_gain: float = 0.33

## How much extra grip the tire gets as it wears down.
@export_range(0.0, 0.3, 0.01) var worn_grip_gain: float = 0.09

## How much rolling resistance drops as the tread disappears.
@export_range(0.0, 0.8, 0.01) var worn_rolling_loss: float = 0.38

var _cache_long: Vector3 = Vector3.INF
var _cache_lat: Vector3 = Vector3.INF

var _kappa_peak: float = 0.1
var _alpha_peak: float = 0.14


## Pacejka Magic Formula
static func _pacejka(x: float, B: float, C: float, D: float, E: float) -> float:
	var Bx: float = B * x
	return D * sin(C * atan(Bx - E * (Bx - atan(Bx))))


static func _scale_drop(force: float, peak: float, slip_norm: float, drop_scale: float) -> float:
	if slip_norm <= 1.0 or peak <= 0.0:
		return force

	var ratio: float = clampf(absf(force) / peak, 0.0, 1.0)
	return signf(force) * peak * (1.0 - (1.0 - ratio) * drop_scale)


static func _find_peak(B: float, C: float, E: float, x_max: float) -> float:
	var best_x: float = 0.0
	var best_y: float = 0.0

	var steps: int = 300
	for i in range(1, steps + 1):
		var x: float = x_max * float(i) / float(steps)
		var y: float = _pacejka(x, B, C, 1.0, E)

		if y > best_y:
			best_y = y
			best_x = x

	return maxf(best_x, 0.001)


func _ensure_cache() -> void:
	var long_now := Vector3(long_B, long_C, long_E)
	var lat_now := Vector3(lat_B, lat_C, lat_E)
	if long_now == _cache_long and lat_now == _cache_lat:
		return

	_cache_long = long_now
	_cache_lat = lat_now

	_kappa_peak = _find_peak(long_B, long_C, long_E, 1.5)
	_alpha_peak = _find_peak(lat_B, lat_C, lat_E, 0.8)


func kappa_peak() -> float:
	_ensure_cache()
	return _kappa_peak


func alpha_peak() -> float:
	_ensure_cache()
	return _alpha_peak


## Calculate grip multiplier based on how heavy the car is pressing down on the tire.
func _get_peak_mu(fz: float) -> float:
	if fz <= 0.0:
		return 0.0

	var load_ratio: float = fz / reference_load_n
	return clampf(1.0 - load_sensitivity * (load_ratio - 1.0), 0.5, 1.5)


func capacity_grip_factor(fz: float, capacity_scale: float) -> float:
	if not (fz > 0.0):
		return 1.0

	var load_ratio: float = fz / (reference_load_n * maxf(capacity_scale, 0.01))
	var scaled: float = clampf(1.0 - load_sensitivity * (load_ratio - 1.0), 0.5, 1.5)

	return scaled / _get_peak_mu(fz)


func camber_grip_factor(lean_rad: float) -> float:
	return clampf(1.0 - camber_grip_loss * lean_rad * lean_rad, 0.5, 1.0)


func pneumatic_trail(
	slip_angle_rad: float,
	fz: float,
	trail_scale: float = 1.0,
	stiffness_scale: float = 1.0,
) -> float:
	if fz <= 1.0:
		return 0.0

	_ensure_cache()

	var load_scale: float = clampf(sqrt(fz / reference_load_n), 0.5, 1.5)

	var sliding: float = clampf(
		absf(slip_angle_rad) * stiffness_scale / (trail_zero_slip_ratio * _alpha_peak),
		0.0,
		1.0,
	)
	var shape: float = pow(1.0 - sliding, 3.0) / (1.0 - sliding + sliding * sliding / 3.0)

	return pneumatic_trail_m * load_scale * shape * trail_scale


func peak_longitudinal_force_n(fz: float, grip_scale: float = 1.0) -> float:
	return _get_peak_mu(fz) * maxf(fz, 0.0) * long_D * grip_scale


func peak_lateral_force_n(fz: float, grip_scale: float = 1.0, lean_rad: float = 0.0) -> float:
	return _get_peak_mu(fz) * maxf(fz, 0.0) * lat_D * grip_scale * camber_grip_factor(lean_rad)


func peak_force_n(fz: float) -> float:
	return peak_lateral_force_n(fz)


func project_to_friction_ellipse(force: Vector2, peak_x: float, peak_y: float) -> Vector2:
	if peak_x <= 0.0 or peak_y <= 0.0:
		return Vector2.ZERO

	var ellipse_sq := (force.x / peak_x) * (force.x / peak_x)
	ellipse_sq += (force.y / peak_y) * (force.y / peak_y)

	if ellipse_sq <= 1.0:
		return force

	return force / sqrt(ellipse_sq)


## Longitudinal force
func compute_fx(slip_ratio: float, fz: float) -> float:
	if fz <= 0.0:
		return 0.0

	var mu: float = _get_peak_mu(fz)
	var D_scaled: float = mu * fz * long_D
	return _pacejka(slip_ratio, long_B, long_C, D_scaled, long_E)


func curve_weight(speed_long: float) -> float:
	return smoothstep(
		low_speed_start,
		maxf(low_speed_threshold, low_speed_start + 0.01),
		speed_long,
	)


func relaxation_length_m() -> float:
	return lat_B * lat_C * stick_deflection_m


## Lateral force
func compute_fy(slip_angle_rad: float, fz: float) -> float:
	if fz <= 0.0:
		return 0.0

	var mu: float = _get_peak_mu(fz)
	var D_scaled: float = mu * fz * lat_D
	return _pacejka(slip_angle_rad, lat_B, lat_C, D_scaled, lat_E)


func compute_combined(slip_ratio: float, slip_angle_rad: float, fz: float) -> Vector2:
	return compute_forces(slip_ratio, slip_angle_rad, 0.0, 99.0, fz, 1.0)


func compute_forces(
	slip_ratio: float,
	slip_angle_rad: float,
	hold_fy: float,
	speed_long: float,
	fz: float,
	grip_scale: float = 1.0,
	lean_rad: float = 0.0,
	stiffness_scale: float = 1.0,
	drop_scale: float = 1.0,
) -> Vector2:
	if fz <= 1.0:
		return Vector2.ZERO

	_ensure_cache()

	var mu: float = _get_peak_mu(fz) * grip_scale
	var peak_x: float = mu * fz * long_D
	var peak_y: float = mu * fz * lat_D * camber_grip_factor(lean_rad)
	if peak_x <= 0.0 or peak_y <= 0.0:
		return Vector2.ZERO

	var kappa_norm: float = absf(slip_ratio) * stiffness_scale / _kappa_peak
	var alpha_norm: float = absf(slip_angle_rad) * stiffness_scale / _alpha_peak

	var long_scale: float = 1.0 / sqrt(1.0 + pow(combined_long_strength * alpha_norm, 2.0))
	var lat_scale: float = 1.0 / sqrt(1.0 + pow(combined_lat_strength * kappa_norm, 2.0))

	var fx: float = _pacejka(
		slip_ratio,
		long_B * stiffness_scale,
		long_C,
		peak_x * long_scale,
		long_E,
	)

	var shifted_angle: float = slip_angle_rad + camber_stiffness_ratio * lean_rad
	var fy_curve: float = _pacejka(
		shifted_angle,
		lat_B * stiffness_scale,
		lat_C,
		peak_y * lat_scale,
		lat_E,
	)

	if drop_scale != 1.0:
		fx = _scale_drop(fx, peak_x * long_scale, kappa_norm, drop_scale)
		fy_curve = _scale_drop(fy_curve, peak_y * lat_scale, alpha_norm, drop_scale)

	var fy: float = lerpf(hold_fy, fy_curve, curve_weight(speed_long))

	var ellipse_sq: float = (fx / peak_x) * (fx / peak_x) + (fy / peak_y) * (fy / peak_y)
	if ellipse_sq > 1.0:
		var shrink: float = 1.0 / sqrt(ellipse_sq)
		fx *= shrink
		fy *= shrink

	return Vector2(fx, fy)
