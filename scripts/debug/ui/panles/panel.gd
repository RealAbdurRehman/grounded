class_name DebugPanel
extends RefCounted

var vehicle: Vehicle
var telemetry: Telemetry
var weight_transfer: WeightTransfer

var _fit_fixed: float = -1.0
var _fit_budget: float = 0.0

var _fit_used: float = 0.0
var _fit_start: float = 0.0


func _init(v: Vehicle, t: Telemetry, w: WeightTransfer) -> void:
	vehicle = v
	telemetry = t
	weight_transfer = w

	_build()


func _build() -> void:
	pass


func update(_delta: float) -> void:
	pass


func draw() -> void:
	pass


func wheels() -> Array[Wheel]:
	return [vehicle.wheel_fl, vehicle.wheel_fr, vehicle.wheel_rl, vehicle.wheel_rr]


func grip_usage(index: int) -> float:
	var sample = telemetry.wheels[index]
	var force := Vector2(sample.longitudinal_force_n, sample.lateral_force_n)

	return force.length() / maxf(sample.grip_limit_n, 1.0)


func fit_begin() -> void:
	_fit_start = ImGui.GetCursorPosY()
	_fit_used = 0.0
	_fit_budget = 0.0

	if _fit_fixed >= 0.0:
		var free: float = ImGui.GetContentRegionAvail().y - _fit_fixed
		_fit_budget = maxf(free - ImGui.GetFontSize() * 0.8, 0.0)


func fit(share: float, min_h: float, max_h: float) -> float:
	var height: float = floorf(clampf(_fit_budget * share, min_h, max_h))
	_fit_used += height

	return height


func fit_end() -> void:
	var total: float = ImGui.GetCursorPosY() - _fit_start
	_fit_fixed = maxf(total - _fit_used, 0.0)
