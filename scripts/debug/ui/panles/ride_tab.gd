class_name RideTab
extends DebugPanel

const SAMPLE_INTERVAL: float = 1.0 / 60.0
const HISTORY_LENGTH: int = 240

var _susp: Tuner
var _arb: Tuner

var _sample_timer: float = 0.0
var _travel: Array = [[], [], [], []]


func _build() -> void:
	_susp = Tuner.new(
		"Suspension",
		func() -> Object:
			return vehicle.wheel_fl.suspension_config,
		func() -> Object:
			return vehicle.wheel_rl.suspension_config,
	)

	_susp.group(
		"Spring",
		[
			Tuner.slider(&"spring_stiffness", "Spring rate", 8000.0, 90000.0, "%.0f", "In N/m."),
			Tuner.slider(
				&"suspension_rest_length",
				"Travel",
				0.1,
				0.8,
				"%.2f",
				"How far the wheel hangs below the car, in m.",
			),
		],
	)

	_susp.group(
		"Damper",
		[
			Tuner.slider(
				&"damper_stiffness",
				"Damper",
				300.0,
				8000.0,
				"%.0f",
				"Resists the wheel moving up or down, in N.s/m.",
			),
		],
	)

	_susp.group(
		"Wheel",
		[
			Tuner.slider(&"wheel_radius", "Wheel radius", 0.2, 0.5, "%.2f", "In m."),
			Tuner.slider(
				&"wheel_inertia",
				"Wheel inertia",
				0.3,
				4.0,
				"%.2f",
				"How hard the wheel is to spin up, in kg.m2.",
			),
		],
	)

	_arb = Tuner.new(
		"Anti-roll bars",
		func() -> Object:
			return vehicle.config,
	)

	_arb.group(
		"",
		[
			Tuner.slider(
				&"front_arb_stiffness",
				"Front",
				0.0,
				20000.0,
				"%.0f",
				"Stiffer bars move load transfer to that axle.",
			),
			Tuner.slider(&"rear_arb_stiffness", "Rear", 0.0, 20000.0, "%.0f"),
		],
	)


func update(delta: float) -> void:
	_sample_timer += delta
	if _sample_timer < SAMPLE_INTERVAL:
		return

	_sample_timer = 0.0
	for i in range(4):
		_travel[i].append(telemetry.wheels[i].compression)

		if _travel[i].size() > HISTORY_LENGTH:
			_travel[i].pop_front()


func draw() -> void:
	fit_begin()

	var unit: float = ImGui.GetFontSize()

	Widgets.wheel_legend()
	Widgets.plot_title("Wheel travel, last 4 s (top is fully compressed)")
	Plots.multi_line_plot(
		_travel,
		UITheme.WHEEL_COLORS,
		0.0,
		1.0,
		fit(1.0, unit * 5.0, unit * 30.0),
	)

	Widgets.gap(0.4)
	_readouts()

	Widgets.gap(0.4)

	_susp.draw(true)
	_arb.draw(true)

	fit_end()


func _readouts() -> void:
	var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity")) * vehicle.gravity_scale

	var front: SuspensionConfig = vehicle.wheel_fl.suspension_config
	var rear: SuspensionConfig = vehicle.wheel_rl.suspension_config

	var front_mass: float = _corner_mass(true)
	var rear_mass: float = _corner_mass(false)

	var f_freq: float = _frequency(front, front_mass)
	var r_freq: float = _frequency(rear, rear_mass)

	var f_damping: float = _damping_ratio(front, front_mass)
	var r_damping: float = _damping_ratio(rear, rear_mass)

	Widgets.axle_table(
		"ride_table",
		[
			[
				"Wheel rate",
				"%.1f N/mm" % (_wheel_rate(front) / 1000.0),
				"%.1f N/mm" % (_wheel_rate(rear) / 1000.0),
			],
			[
				"Ride frequency",
				"%.2f Hz" % f_freq,
				"%.2f Hz" % r_freq,
				_range_color(f_freq, 0.8, 3.5),
				_range_color(r_freq, 0.8, 3.5),
			],
			[
				"Damping ratio",
				"%.2f" % f_damping,
				"%.2f" % r_damping,
				_range_color(f_damping, 0.2, 0.8),
				_range_color(r_damping, 0.2, 0.8),
			],
			[
				"Static sag",
				"%.0f mm" % (front_mass * gravity / _wheel_rate(front) * 1000.0),
				"%.0f mm" % (rear_mass * gravity / _wheel_rate(rear) * 1000.0),
				_sag_color(front_mass * gravity / _wheel_rate(front), front.suspension_rest_length),
				_sag_color(rear_mass * gravity / _wheel_rate(rear), rear.suspension_rest_length),
			],
		],
	)

	Widgets.key_value(
		"Rear / front frequency",
		"%.2f" % (r_freq / maxf(f_freq, 0.01)),
		UITheme.GOOD if r_freq >= f_freq * 1.0 and r_freq <= f_freq * 1.3 else UITheme.TEXT,
	)

	Widgets.tip("A rear a little higher than the front settles the car quickly after a bump.")


func _corner_mass(front: bool) -> float:
	var front_z: float = (vehicle.to_local(vehicle.wheel_fl.global_position).z + vehicle
		.to_local(vehicle.wheel_fr.global_position)
		.z) * 0.5

	var rear_z: float = (vehicle.to_local(vehicle.wheel_rl.global_position).z + vehicle
		.to_local(vehicle.wheel_rr.global_position)
		.z) * 0.5

	var share: float = clampf(
		(rear_z - vehicle.center_of_mass.z) / maxf(rear_z - front_z, 0.1),
		0.05,
		0.95,
	)

	if not front:
		share = 1.0 - share

	return vehicle.mass * share * 0.5


func _wheel_rate(config: SuspensionConfig) -> float:
	return config.spring_stiffness


func _frequency(config: SuspensionConfig, corner_mass: float) -> float:
	return sqrt(_wheel_rate(config) / maxf(corner_mass, 1.0)) / TAU


func _damping_ratio(config: SuspensionConfig, corner_mass: float) -> float:
	return config.damper_stiffness / (2.0 * sqrt(_wheel_rate(config) * maxf(corner_mass, 1.0)))


func _range_color(value: float, low: float, high: float) -> Color:
	return UITheme.GOOD if value >= low and value <= high else UITheme.WARN


func _sag_color(sag: float, travel: float) -> Color:
	var used: float = sag / maxf(travel, 0.01)
	if used > 0.85:
		return UITheme.BAD

	return UITheme.WARN if used > 0.6 or used < 0.15 else UITheme.GOOD
