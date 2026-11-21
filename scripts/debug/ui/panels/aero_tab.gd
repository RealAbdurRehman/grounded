class_name AeroTab
extends DebugPanel

const CURVE_SPEED_KMH: float = 300.0
const CURVE_SAMPLES: int = 61

const DOWNFORCE_COLOR := Color(0.70, 0.45, 1.00)
const DRAG_COLOR := Color(1.00, 0.62, 0.20)

var _aero: Tuner


func _build() -> void:
	_aero = Tuner.new(
		"Aerodynamics",
		func() -> Object:
			return vehicle.aero_config,
	)

	_aero.group(
		"Drag",
		[
			Tuner.slider(
				&"drag_coefficient",
				"Drag coefficient",
				0.1,
				1.2,
				"%.2f",
				"How slippery the shape is.",
			),
			Tuner.slider(&"frontal_area", "Frontal area", 1.0, 4.0, "%.2f", "In square meters."),
			Tuner.slider(
				&"drag_height_m",
				"Drag height",
				-0.5,
				0.8,
				"%.2f m",
				"How high the wind pushes on the car. Higher values push the rear down at speed.",
			),
		],
	)

	_aero.group(
		"Crosswind",
		[
			Tuner.slider(
				&"side_force_coefficient",
				"Side push",
				0.0,
				4.0,
				"%.2f",
				"How hard air pushes the car sideways.",
			),
			Tuner.slider(
				&"drag_yaw_gain",
				"Angled drag",
				0.0,
				3.0,
				"%.2f",
				"How much the air resistance grows when the air hits the car at an angle.",
			),
			Tuner.slider(
				&"center_of_pressure_m",
				"Push point",
				-1.5,
				1.5,
				"%.2f m",
				"How far ahead of the center of mass the sideways push acts.",
			),
			Tuner.slider(
				&"side_force_height_m",
				"Push height",
				-0.5,
				1.0,
				"%.2f m",
				"How high above the center of mass the sideways push acts.",
			),
		],
	)

	_aero.group(
		"Downforce",
		[
			Tuner.slider(
				&"downforce_coefficient",
				"Downforce",
				-0.5,
				4.0,
				"%.2f",
				"Downforce strength. Positive pushes the car down, negative lifts it up.",
			),
			Tuner.slider(
				&"front_share",
				"Front share",
				0.0,
				1.0,
				"%.2f",
				"How much of the downforce is on the front axle.",
			),
			Tuner.slider(
				&"downforce_efficiency",
				"Efficiency",
				1.0,
				20.0,
				"%.1f",
				"Higher values create less drag.",
			),
			Tuner.slider(
				&"ground_effect_per_m",
				"Ground effect",
				0.0,
				10.0,
				"%.1f /m",
				"Extra downforce when the car sits lower than normal.",
			),
		],
	)

	_aero.group(
		"Air",
		[
			Tuner.custom(
				&"air_density",
				"Air density",
				func() -> float:
					return Atmosphere.config.air_density,
				func(value: float) -> void:
					Atmosphere.config.air_density = value,
				0.5,
				1.5,
				"%.3f",
				"Controls drag and downforce caused by air. The same for every car.",
			),
			Tuner.custom(
				&"air_temperature",
				"Air temperature",
				func() -> float:
					return Atmosphere.config.air_temperature_c,
				func(value: float) -> void:
					Atmosphere.config.air_temperature_c = value,
				-30.0,
				50.0,
				"%.0f C",
				"The temperature tires start at and cool toward.",
			),
			Tuner.custom(
				&"road_above_air",
				"Road above air",
				func() -> float:
					return Atmosphere.config.road_above_air_c,
				func(value: float) -> void:
					Atmosphere.config.road_above_air_c = value,
				-15.0,
				40.0,
				"%.0f C",
				"How much hotter the road is than the air.",
			),
		],
	)


func draw() -> void:
	fit_begin()

	_summary()
	_axle_bars()
	_details()
	_curves()
	Widgets.gap(0.4)

	_aero.draw(true)

	fit_end()


func _weight_n() -> float:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	return vehicle.mass * gravity * vehicle.gravity_scale


func _summary() -> void:
	var aero: Aero = vehicle.aero
	var total: float = aero.total_downforce_n()

	Widgets.stat_row(
		"aero_stats",
		[
			["Airspeed", "%.0f km/h" % (aero.airspeed_mps * 3.6)],
			["Downforce" if total >= 0.0 else "Lift", "%.0f N" % absf(total), _force_color(total)],
			["Drag", "%.0f N" % aero.drag_n, DRAG_COLOR],
		],
	)

	Widgets.gap(0.3)


func _axle_bars() -> void:
	var aero: Aero = vehicle.aero
	var full: float = maxf(_weight_n() * 0.5, 1.0)

	Widgets.centered_bar(
		"Front",
		aero.downforce_front_n / full,
		"%+.0f N" % aero.downforce_front_n,
		_force_color(aero.downforce_front_n),
	)

	Widgets.centered_bar(
		"Rear",
		aero.downforce_rear_n / full,
		"%+.0f N" % aero.downforce_rear_n,
		_force_color(aero.downforce_rear_n),
	)

	Widgets.gap(0.3)


func _details() -> void:
	var aero: Aero = vehicle.aero
	var total: float = aero.total_downforce_n()

	Widgets.key_value(
		"Share of the car's weight",
		"%+.0f%%" % (total / maxf(_weight_n(), 1.0) * 100.0),
		_force_color(total),
	)

	var gain: float = _grip_gain()
	Widgets.key_value(
		"Cornering grip from the air",
		"%+.1f%%" % (gain * 100.0),
		UITheme.GOOD if gain > 0.005 else (UITheme.WARN if gain < -0.005 else UITheme.TEXT),
	)

	var worst: float = maxf(aero.travel_front, aero.travel_rear)
	Widgets.key_value(
		"Suspension used (front / rear)",
		"%.0f%% / %.0f%%" % [aero.travel_front * 100.0, aero.travel_rear * 100.0],
		UITheme.BAD if worst > 0.9 else (UITheme.WARN if worst > 0.75 else UITheme.TEXT),
	)

	if worst > 0.9:
		ImGui.TextColored(UITheme.BAD, "Out of suspension travel.")
	elif total < -50.0:
		ImGui.TextColored(UITheme.WARN, "The air is lifting the car, which takes grip away.")

	Widgets.gap(0.3)


func _curves() -> void:
	var aero: Aero = vehicle.aero
	var config: AeroConfig = vehicle.aero_config
	var unit: float = ImGui.GetFontSize()

	var x_max: float = maxf(CURVE_SPEED_KMH, aero.airspeed_mps * 3.6 * 1.1)

	var downforce: Array = []
	var drag: Array = []

	var peak: float = 1.0
	var low: float = 0.0

	for i in range(CURVE_SAMPLES):
		var speed: float = x_max / 3.6 * float(i) / float(CURVE_SAMPLES - 1)
		var pressure: float = 0.5 * Atmosphere.config.air_density * speed * speed

		var base: float = pressure * config.downforce_coefficient * config.frontal_area
		var f: float = base * config.front_share * aero.ground_effect_front
		var r: float = base * (1.0 - config.front_share) * aero.ground_effect_rear

		var induced: float = (maxf(f, 0.0) + maxf(r, 0.0)) / maxf(config.downforce_efficiency, 0.1)
		var d: float = pressure * config.drag_coefficient * config.frontal_area + induced

		downforce.append(f + r)
		drag.append(d)

		peak = maxf(peak, maxf(f + r, d))
		low = minf(low, f + r)

	ImGui.SeparatorText("Force against speed")
	ImGui.TextColored(DOWNFORCE_COLOR, "Downforce")
	ImGui.SameLine()
	ImGui.TextColored(DRAG_COLOR, "Drag")

	Plots.speed_plot(
		[downforce, drag],
		[DOWNFORCE_COLOR, DRAG_COLOR],
		low * 1.1,
		peak * 1.1,
		fit(0.35, unit * 6.0, unit * 11.0),
		aero.airspeed_mps * 3.6 / x_max,
		"%.0f km/h" % x_max,
		"%.0f N" % peak,
	)

	Widgets.gap(0.3)


func _force_color(force: float) -> Color:
	return DOWNFORCE_COLOR if force >= 0.0 else UITheme.WARN


func _grip_gain() -> float:
	var aero: Aero = vehicle.aero

	var with_air: float = 0.0
	var without_air: float = 0.0

	var rear_axle: Array[Wheel] = vehicle.rear_axle()
	var front_axle: Array[Wheel] = vehicle.front_axle()

	for wheel in wheels():
		if not wheel.is_grounded:
			continue

		var from_air: float = 0.0
		if wheel.is_front:
			from_air = aero.downforce_front_n / float(front_axle.size())
		elif wheel in rear_axle:
			from_air = aero.downforce_rear_n / float(rear_axle.size())

		var load_n: float = wheel.normal_load_n

		with_air += wheel.tire_model.peak_lateral_force_n(load_n, wheel.grip_scale())
		without_air += wheel.tire_model.peak_lateral_force_n(
			maxf(load_n - from_air, 0.0),
			wheel.grip_scale(),
		)

	if without_air < 1.0:
		return 0.0

	return with_air / without_air - 1.0
