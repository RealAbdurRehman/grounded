class_name VehiclePanel
extends DebugPanel

const SHIFT_LIGHT_COUNT: int = 14

const SAMPLE_INTERVAL: float = 1.0 / 30.0
const TRAIL_LENGTH: int = 90
const SPEED_LENGTH: int = 300

var _performance: PerformanceSection

var _trail: Array = []
var _speed_history: Array = []
var _sample_timer: float = 0.0

var _g_extent: float = 1.5


func _build() -> void:
	_performance = PerformanceSection.new(vehicle, telemetry, weight_transfer)


func update(delta: float) -> void:
	_performance.update(delta)

	var g := Vector2(telemetry.lateral_g, telemetry.longitudinal_g)
	_g_extent = maxf(_g_extent, ceilf(g.length() * 2.0) * 0.5)

	_sample_timer += delta
	if _sample_timer >= SAMPLE_INTERVAL:
		_sample_timer = 0.0

		_trail.append(g)
		_speed_history.append(telemetry.speed_kmh)

		if _trail.size() > TRAIL_LENGTH:
			_trail.pop_front()

		if _speed_history.size() > SPEED_LENGTH:
			_speed_history.pop_front()


func draw() -> void:
	fit_begin()

	_speedometer()
	_inputs()
	_lamps()

	ImGui.SeparatorText("G-force")
	_g_force()

	_speed_chart()

	ImGui.SeparatorText("Powertrain")
	Widgets.stat_row(
		"powertrain",
		[
			["Engine", "%.0f Nm" % telemetry.engine_torque_nm],
			["Wheels", "%.0f Nm" % telemetry.wheel_torque_nm],
			["Power", "%.0f kW" % telemetry.engine_power_kw],
		],
	)

	Widgets.gap(0.4)
	var unit: float = ImGui.GetFontSize()
	_performance.draw(
		func() -> float:
			return fit(0.1, unit * 2.6, unit * 9.0),
	)

	fit_end()


func _speedometer() -> void:
	ImGui.SetWindowFontScale(2.6)
	ImGui.Text("%3.0f" % telemetry.speed_kmh)
	ImGui.SameLine()

	ImGui.SetWindowFontScale(1.0)
	ImGui.TextDisabled("km/h")
	ImGui.SameLine()

	ImGui.SetWindowFontScale(2.6)
	Widgets.right_text(telemetry.gear_name, UITheme.ACCENT)
	ImGui.SetWindowFontScale(1.0)

	var shifting: String = "  shifting" if telemetry.is_shifting else ""
	ImGui.TextDisabled(telemetry.transmission_name + shifting)


func _inputs() -> void:
	var rpm_fraction: float = telemetry.rpm / maxf(telemetry.rev_limit_rpm, 1.0)
	var rpm_color: Color = UITheme.BAD if rpm_fraction > 0.94 else Color(1.0, 0.75, 0.25)

	Widgets.gap(0.3)
	Plots.shift_lights(rpm_fraction, SHIFT_LIGHT_COUNT, ImGui.GetFontSize() * 1.0)
	Widgets.labeled_bar("RPM", rpm_fraction, "%.0f" % telemetry.rpm, rpm_color)

	Widgets.labeled_bar(
		"THR",
		telemetry.throttle,
		"%.0f%%" % (telemetry.throttle * 100.0),
		UITheme.GOOD,
	)

	Widgets.labeled_bar("BRK", telemetry.brake, "%.0f%%" % (telemetry.brake * 100.0), UITheme.BAD)

	Widgets.labeled_bar(
		"HND",
		vehicle.handbrake_input,
		"%.0f%%" % (vehicle.handbrake_input * 100.0),
		UITheme.WARN,
	)

	Widgets.centered_bar(
		"STR",
		telemetry.steering,
		"%+.1f deg" % telemetry.steer_angle_deg,
		UITheme.ACCENT,
	)


func _lamps() -> void:
	Widgets.gap(0.2)

	var lamps: Array = []
	if vehicle.assists != null:
		var config: AssistsConfig = vehicle.assists_config
		lamps.append(["ABS", config.abs_enabled, vehicle.assists.abs_active])
		lamps.append(["TCS", config.tcs_enabled, vehicle.assists.tcs_active])
		lamps.append(["ESC", config.esc_enabled, vehicle.assists.esc_active])

	for i in range(lamps.size()):
		if i > 0:
			ImGui.SameLine()

		var color: Color = UITheme.DIM
		if lamps[i][1]:
			color = UITheme.WARN if lamps[i][2] else UITheme.GOOD

		Widgets.lamp(lamps[i][0], color)

	if not lamps.is_empty():
		ImGui.SameLine()

	Widgets.lamp("HB", UITheme.BAD if vehicle.handbrake_input > 0.05 else UITheme.DIM)

	ImGui.SameLineEx(0.0, ImGui.GetFontSize() * 1.2)
	Widgets.parking_icon(vehicle.handbrake_latched)
	Widgets.tip("Parking brake (P)")


func _g_force() -> void:
	var unit: float = ImGui.GetFontSize()
	var width: float = ImGui.GetContentRegionAvail().x
	var current := Vector2(telemetry.lateral_g, telemetry.longitudinal_g)

	Plots.gg_plot(_trail, current, _g_extent, fit(0.45, unit * 9.0, width))
	Widgets.stat_row(
		"g_force",
		[
			["Lateral", "%+.2f g" % current.x],
			["Longitudinal", "%+.2f g" % current.y],
			["Total", "%.2f g" % current.length()],
		],
	)


func _speed_chart() -> void:
	var unit: float = ImGui.GetFontSize()

	var peak: float = 0.0
	for value in _speed_history:
		peak = maxf(peak, value)

	ImGui.SeparatorText("Speed, last 10 s")
	Plots.line_plot(
		"##speed_history",
		_speed_history,
		0.0,
		maxf(ceilf(peak * 1.1 / 20.0) * 20.0, 40.0),
		fit(0.3, unit * 4.0, unit * 16.0),
		UITheme.ACCENT,
		"%.0f km/h" % telemetry.speed_kmh,
	)
