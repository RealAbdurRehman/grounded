class_name AssistsTab
extends DebugPanel

const SAMPLE_INTERVAL: float = 1.0 / 60.0
const HISTORY_LENGTH: int = 240

var _abs: Tuner
var _tcs: Tuner
var _esc: Tuner

var _sample_timer: float = 0.0

var _abs_history: Array = []
var _tcs_history: Array = []
var _esc_history: Array = []


func _build() -> void:
	var config := func() -> Object:
		return vehicle.assists_config

	_abs = Tuner.new("ABS", config)
	_abs.group(
		"",
		[
			Tuner.toggle(
				&"abs_rear_select_low",
				"Rear select-low",
				"Both rear wheels follow the one with less grip.",
			),
			Tuner.slider(
				&"abs_release_slip",
				"Release slip",
				0.5,
				2.0,
				"%.2f",
				"Pressure is dumped past this fraction of the peak-grip slip.",
			),
			Tuner.slider(
				&"abs_release_rate",
				"Release rate",
				5.0,
				200.0,
				"%.0f",
				"How fast pressure is dumped, per second.",
			),
			Tuner.slider(
				&"abs_apply_rate",
				"Apply rate",
				1.0,
				60.0,
				"%.0f",
				"How fast pressure is rebuilt, per second.",
			),
			Tuner.slider(
				&"abs_front_pressure_split",
				"Front L/R split",
				0.0,
				1.0,
				"%.2f",
				"Most the front pressures may differ. 1 means no limit.",
			),
			Tuner.slider(
				&"abs_min_speed",
				"Min speed",
				0.0,
				10.0,
				"%.1f m/s",
				"Below this the wheels may lock.",
			),
		],
	)

	_tcs = Tuner.new("Traction control", config)
	_tcs.group(
		"",
		[
			Tuner.slider(
				&"tcs_slip_target",
				"Slip target",
				0.3,
				1.5,
				"%.2f",
				"Wheelspin allowed, as a fraction of the peak-grip slip.",
			),
			Tuner.slider(
				&"tcs_cut_rate",
				"Cut rate",
				1.0,
				30.0,
				"%.1f",
				"How fast throttle is cut, per second.",
			),
			Tuner.slider(
				&"tcs_restore_rate",
				"Restore rate",
				0.5,
				20.0,
				"%.1f",
				"How fast throttle comes back, per second.",
			),
			Tuner.slider(
				&"tcs_brake_max_nm",
				"Axle brake max",
				0.0,
				1500.0,
				"%.0f",
				"Most brake torque used to send power to the wheel with grip, in Nm.",
			),
		],
	)

	_esc = Tuner.new("Stability control", config)
	_esc.group(
		"",
		[
			Tuner.toggle(
				&"esc_off_with_handbrake",
				"Off with handbrake",
				"Steps aside while the handbrake is up.",
			),
			Tuner.slider(
				&"esc_understeer_gradient",
				"Understeer gradient",
				0.0,
				0.02,
				"%.4f",
				"How much the car understeers. Used to predict the intended turn.",
			),
			Tuner.slider(
				&"esc_deadband",
				"Allowed slide",
				0.0,
				0.3,
				"%.2f",
				"Yaw rate error ignored, in rad/s.",
			),
			Tuner.slider(
				&"esc_oversteer_gain",
				"Oversteer brake",
				0.0,
				10000.0,
				"%.0f",
				"Brake torque per rad/s of error.",
			),
			Tuner.slider(
				&"esc_understeer_gain",
				"Understeer brake",
				0.0,
				10000.0,
				"%.0f",
				"Brake torque per rad/s of error.",
			),
			Tuner.slider(
				&"esc_throttle_cut",
				"Throttle cut",
				0.0,
				1.0,
				"%.2f",
				"How much power is cut when the car slides.",
			),
			Tuner.slider(&"esc_min_speed", "Min speed", 0.0, 20.0, "%.1f m/s"),
		],
	)


func update(delta: float) -> void:
	if vehicle.assists == null:
		return

	_sample_timer += delta
	if _sample_timer < SAMPLE_INTERVAL:
		return

	_sample_timer = 0.0

	var lowest: float = 1.0
	for wheel in wheels():
		lowest = minf(lowest, vehicle.assists.abs_pressure[wheel])

	_push(_abs_history, lowest)
	_push(_tcs_history, vehicle.assists.throttle_scale)
	_push(_esc_history, rad_to_deg(vehicle.assists.yaw_rate_error))


func draw() -> void:
	if vehicle.assists == null or vehicle.assists_config == null:
		ImGui.Text("Assists unavailable")
		return

	fit_begin()

	var assists: Assists = vehicle.assists
	var config: AssistsConfig = vehicle.assists_config

	if Widgets.section(_abs.title, true):
		_header(&"abs_enabled", config.abs_enabled, assists.abs_active)

		for i in range(4):
			var pressure: float = assists.abs_pressure[wheels()[i]]
			Widgets.labeled_bar(
				UITheme.WHEEL_NAMES[i],
				pressure,
				"%.0f%%" % (pressure * 100.0),
				UITheme.WHEEL_COLORS[i],
			)

		_abs.draw_body()

	if Widgets.section(_tcs.title, true):
		_header(&"tcs_enabled", config.tcs_enabled, assists.tcs_active)
		Widgets.labeled_bar(
			"PWR",
			assists.throttle_scale,
			"%.0f%%" % (assists.throttle_scale * 100.0),
			UITheme.GOOD,
		)

		_tcs.draw_body()

	if Widgets.section(_esc.title, true):
		_header(&"esc_enabled", config.esc_enabled, assists.esc_active)

		var error_high: bool = absf(assists.yaw_rate_error) > config.esc_deadband
		Widgets.key_value("Target yaw", "%.1f deg/s" % rad_to_deg(assists.yaw_rate_target))
		Widgets.key_value(
			"Yaw error",
			"%.1f deg/s" % rad_to_deg(assists.yaw_rate_error),
			UITheme.WARN if error_high else UITheme.TEXT,
		)

		_esc.draw_body()

	_history()
	fit_end()


func _header(prop: StringName, enabled: bool, active: bool) -> void:
	var buffer: Array = [enabled]
	if ImGui.Checkbox("Enabled##%s" % prop, buffer):
		vehicle.assists_config.set(prop, buffer[0])

	var text: String = "off"
	var color: Color = UITheme.DIM
	if enabled:
		text = "ACTIVE" if active else "ready"
		color = UITheme.WARN if active else UITheme.GOOD

	ImGui.SameLine()
	Widgets.right_text(text, color)


func _history() -> void:
	if not Widgets.section("Activity (last 4 s)", true):
		return

	var unit: float = ImGui.GetFontSize()

	var yaw_range: float = 20.0
	for value in _esc_history:
		yaw_range = maxf(yaw_range, absf(value))

	Widgets.plot_title("ABS pressure, lowest wheel")
	Plots.line_plot(
		"##abs_history",
		_abs_history,
		0.0,
		1.0,
		fit(1.0 / 3.0, unit * 3.5, unit * 12.0),
		UITheme.GOOD,
	)

	Widgets.plot_title("Traction control, power left")
	Plots.line_plot(
		"##tcs_history",
		_tcs_history,
		0.0,
		1.0,
		fit(1.0 / 3.0, unit * 3.5, unit * 12.0),
		UITheme.ACCENT,
	)

	Widgets.plot_title("Stability control, yaw error in deg/s")
	Plots.line_plot(
		"##esc_history",
		_esc_history,
		-yaw_range,
		yaw_range,
		fit(1.0 / 3.0, unit * 3.5, unit * 12.0),
		UITheme.WARN,
	)


func _push(history: Array, value: float) -> void:
	history.append(value)
	if history.size() > HISTORY_LENGTH:
		history.pop_front()
