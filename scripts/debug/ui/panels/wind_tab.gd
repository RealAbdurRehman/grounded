class_name WindTab
extends DebugPanel

const SAMPLE_INTERVAL: float = 1.0 / 20.0
const HISTORY_LENGTH: int = 300

const WIND_COLOR := Color(0.35, 0.85, 1.00)
const CROSS_COLOR := Color(1.00, 0.62, 0.20)

var _weather: Tuner

var _history: Array = [[], []]
var _sample_timer: float = 0.0

var _show_view: Array = [false]
var _view: WindDebug


func _build() -> void:
	_weather = Tuner.new(
		"Weather",
		func() -> Object:
			return Atmosphere.config,
	)

	_weather.group(
		"Wind",
		[
			Tuner.slider(&"wind_speed_mps", "Speed", 0.0, 40.0, "%.1f m/s"),
			Tuner.slider(&"wind_heading_deg", "Heading", -180.0, 180.0, "%.0f deg"),
		],
	)

	_weather.group(
		"Shifts",
		[
			Tuner.slider(&"wander_deg", "Direction", 0.0, 90.0, "%.0f deg"),
			Tuner.slider(&"wander_speed_ratio", "Speed", 0.0, 0.9, "%.2f"),
			Tuner.slider(&"wander_time_s", "Time", 5.0, 300.0, "%.0f s"),
		],
	)

	_weather.group(
		"Turbulence",
		[
			Tuner.slider(
				&"turbulence_mps",
				"Strength",
				0.0,
				10.0,
				"%.1f m/s",
				"How much the wind changes all the time.",
			),
			Tuner.slider(&"turbulence_time_s", "Slowness", 0.5, 20.0, "%.1f s"),
		],
	)

	_weather.group(
		"Gusts",
		[
			Tuner.slider(&"gust_peak_mps", "Strength", 0.0, 30.0, "%.1f m/s"),
			Tuner.slider(&"gust_interval_s", "Every", 0.0, 60.0, "%.0f s"),
			Tuner.slider(&"gust_duration_s", "Length", 0.5, 10.0, "%.1f s"),
			Tuner.slider(
				&"gust_spread_deg",
				"Spread",
				0.0,
				90.0,
				"%.0f deg",
				"How far a gust can turn away from the wind direction.",
			),
			Tuner.slider(&"gust_width_m", "Width", 10.0, 200.0, "%.0f m"),
		],
	)


func update(delta: float) -> void:
	_sample_timer += delta
	if _sample_timer < SAMPLE_INTERVAL:
		return

	_sample_timer = 0.0

	var aero: Aero = vehicle.aero
	_history[0].append(aero.headwind_mps)
	_history[1].append(aero.crosswind_mps)

	for series in _history:
		if series.size() > HISTORY_LENGTH:
			series.pop_front()


func draw() -> void:
	fit_begin()

	_summary()
	_bars()
	_details()
	_plot()

	Widgets.gap(0.4)
	_controls()
	Widgets.gap(0.4)

	_weather.draw(true)

	fit_end()


func _weight_n() -> float:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	return vehicle.mass * gravity * vehicle.gravity_scale


func _summary() -> void:
	var aero: Aero = vehicle.aero

	Widgets.stat_row(
		"wind_stats",
		[
			["Wind", "%.1f m/s" % aero.wind_mps.length(), WIND_COLOR],
			["Head", "%+.1f m/s" % aero.headwind_mps],
			["Cross", "%+.1f m/s" % aero.crosswind_mps, CROSS_COLOR],
		],
	)

	Widgets.gap(0.3)


func _bars() -> void:
	var aero: Aero = vehicle.aero

	Widgets.centered_bar(
		"Push",
		aero.force_side_n / maxf(_weight_n() * 0.25, 1.0),
		"%+.0f N" % aero.force_side_n,
		WIND_COLOR,
	)

	Widgets.centered_bar(
		"Twist",
		aero.yaw_moment_nm / 1500.0,
		"%+.0f Nm" % aero.yaw_moment_nm,
		CROSS_COLOR,
	)

	Widgets.gap(0.3)


func _details() -> void:
	var aero: Aero = vehicle.aero

	Widgets.key_value(
		"Wind now",
		"%.1f m/s at %.0f deg"
		% [Atmosphere.current_speed_mps(), wrapf(Atmosphere.current_heading_deg(), -180.0, 180.0)],
	)

	Widgets.key_value("Air angle", "%.1f deg" % aero.flow_angle_deg)
	Widgets.key_value("Airspeed", "%.0f km/h" % (aero.airspeed_mps * 3.6))
	Widgets.key_value("Gusts in the air", "%d" % Atmosphere.gusts.size())

	Widgets.gap(0.3)


func _plot() -> void:
	var peak: float = 6.0
	for series in _history:
		for value in series:
			peak = maxf(peak, absf(value))

	ImGui.SeparatorText("Wind on the car, last 15 s")
	ImGui.TextColored(UITheme.TEXT, "Head")
	ImGui.SameLine()
	ImGui.TextColored(CROSS_COLOR, "Cross")

	Plots.multi_line_plot(
		_history,
		[UITheme.TEXT, CROSS_COLOR],
		-peak * 1.1,
		peak * 1.1,
		fit(0.35, ImGui.GetFontSize() * 5.0, ImGui.GetFontSize() * 11.0),
	)


func _controls() -> void:
	if ImGui.Checkbox("Show wind on the ground", _show_view):
		_set_view(_show_view[0])

	ImGui.SameLine()
	if ImGui.Button("Gust now"):
		Atmosphere.trigger_gust()


func _set_view(show: bool) -> void:
	if show and _view == null:
		_view = WindDebug.new()
		_view.target = vehicle

		vehicle.get_tree().current_scene.add_child(_view)

	if _view != null:
		_view.visible = show
