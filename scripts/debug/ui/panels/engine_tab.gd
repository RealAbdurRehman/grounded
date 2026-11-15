class_name EngineTab
extends DebugPanel

var _engine: Tuner


func _build() -> void:
	_engine = Tuner.new(
		"Engine",
		func() -> Object:
			return vehicle.engine_node.config,
	)

	_engine.group(
		"Torque curve",
		[
			Tuner.slider(
				&"displacement",
				"Base torque",
				50.0,
				500.0,
				"%.0f",
				"Torque far from the peak, in Nm.",
			),
			Tuner.slider(
				&"boost",
				"Peak torque",
				100.0,
				1000.0,
				"%.0f",
				"Torque at the peak, in Nm.",
			),
			Tuner.slider(
				&"cam_peak_rpm",
				"Peak rpm",
				2000.0,
				8000.0,
				"%.0f",
				"Where the engine makes the most torque.",
			),
			Tuner.slider(
				&"bandwidth",
				"Curve width",
				1000.0,
				8000.0,
				"%.0f",
				"How wide the torque peak is.",
			),
		],
	)

	_engine.group(
		"Limits and inertia",
		[
			Tuner.slider(&"idle_rpm", "Idle rpm", 500.0, 1500.0, "%.0f"),
			Tuner.custom(
				&"rev_limiter_rpm",
				"Rev limiter",
				_rev_limit,
				_set_rev_limit,
				4000.0,
				10000.0,
				"%.0f",
				"Fuel cut above this rpm.",
			),
			Tuner.slider(
				&"flywheel_inertia",
				"Flywheel",
				0.05,
				1.0,
				"%.2f",
				"Heavier means slower revs.",
			),
			Tuner.slider(
				&"engine_braking_factor",
				"Engine braking",
				0.0,
				200.0,
				"%.0f",
				"Drag when off the throttle, in Nm.",
			),
		],
	)


func _rev_limit() -> float:
	return vehicle.engine_node.config.rev_limiter_rpm


func _set_rev_limit(value: float) -> void:
	var config: EngineConfig = vehicle.engine_node.config
	var gap: float = maxf(config.max_rpm - config.rev_limiter_rpm, 300.0)

	config.rev_limiter_rpm = value
	config.max_rpm = value + gap


func draw() -> void:
	var engine: VehicleEngine = vehicle.engine_node
	if engine == null or engine.config == null:
		ImGui.Text("Engine unavailable")

		return

	var unit: float = ImGui.GetFontSize()
	var max_rpm: float = maxf(engine.config.max_rpm, engine.config.rev_limiter_rpm)

	var torque: Array = []
	var power: Array = []

	var torque_peak: float = 1.0
	var power_peak: float = 1.0

	var torque_peak_rpm: float = 0.0
	var power_peak_rpm: float = 0.0

	for i in range(Plots.CURVE_SAMPLES):
		var rpm: float = float(i) / float(Plots.CURVE_SAMPLES - 1) * max_rpm

		var t: float = engine.calculate_raw_torque(rpm)
		var p: float = engine.calculate_power_kw(rpm)
		torque.append(t)
		power.append(p)

		if t > torque_peak:
			torque_peak = t
			torque_peak_rpm = rpm
		if p > power_peak:
			power_peak = p
			power_peak_rpm = rpm

	var cursor: float = telemetry.rpm / max_rpm
	var axis: String = "%.0f rpm" % max_rpm

	fit_begin()

	Widgets.stat_row(
		"engine_now",
		[
			["RPM", "%.0f" % telemetry.rpm],
			["Torque", "%.0f Nm" % telemetry.engine_torque_nm],
			["Power", "%.0f kW" % telemetry.engine_power_kw],
			["Throttle", "%.0f%%" % (telemetry.throttle * 100.0)],
		],
	)

	Widgets.gap(0.3)

	Widgets.plot_title("Torque at full throttle")
	Plots.line_plot(
		"##torque_plot",
		torque,
		0.0,
		torque_peak * 1.15,
		fit(0.5, unit * 6.0, unit * 30.0),
		UITheme.ACCENT,
		"%.0f Nm @ %.0f rpm" % [torque_peak, torque_peak_rpm],
		cursor,
		engine.calculate_raw_torque(telemetry.rpm),
		axis,
	)

	Widgets.gap(0.3)
	Widgets.plot_title("Power at full throttle")
	Plots.line_plot(
		"##power_plot",
		power,
		0.0,
		power_peak * 1.15,
		fit(0.5, unit * 6.0, unit * 30.0),
		Color(1.0, 0.55, 0.25),
		"%.0f kW @ %.0f rpm" % [power_peak, power_peak_rpm],
		cursor,
		engine.calculate_power_kw(telemetry.rpm),
		axis,
	)

	Widgets.gap(0.6)
	_engine.draw(true)

	fit_end()
