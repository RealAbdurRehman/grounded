class_name RideTab
extends DebugPanel

const SAMPLE_INTERVAL: float = 1.0 / 60.0
const HISTORY_LENGTH: int = 240

var _susp: Tuner
var _alignment: Tuner
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
			Tuner.slider(
				&"spring_stiffness",
				"Spring rate",
				8000.0,
				90000.0,
				"%.0f",
				"Measured at the spring.",
			),
			Tuner.slider(
				&"motion_ratio",
				"Motion ratio",
				0.4,
				1.2,
				"%.2f",
				"How much the spring moves compared to the wheel.",
			),
			Tuner.slider(
				&"suspension_rest_length",
				"Travel",
				0.1,
				0.8,
				"%.2f",
				"How far the wheel hangs below the car.",
			),
		],
	)

	_susp.group(
		"Damper",
		[
			Tuner.slider(
				&"damper_bump",
				"Bump",
				300.0,
				6000.0,
				"%.0f",
				"Resists the wheel moving up.",
			),
			Tuner.slider(
				&"damper_rebound",
				"Rebound",
				300.0,
				8000.0,
				"%.0f",
				"Resists the wheel dropping. Usually higher than bump.",
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
				"How hard the wheel is to spin up.",
			),
		],
	)

	_alignment = Tuner.new(
		"Alignment",
		func() -> Object:
			return vehicle.wheel_fl.suspension_config,
		func() -> Object:
			return vehicle.wheel_rl.suspension_config,
	)

	_alignment.group(
		"Camber",
		[
			Tuner.slider(
				&"static_camber_deg",
				"Static camber",
				-8.0,
				4.0,
				"%.1f deg",
				"Wheel tilt when parked. Negative means the top leans inward.",
			),
			Tuner.slider(
				&"camber_gain_deg_per_m",
				"Camber gain",
				-60.0,
				20.0,
				"%.0f deg/m",
				"## How much wheel tilt changes as the suspension moves up.",
			),
			Tuner.slider(
				&"alignment_compression",
				"Set at sag",
				0.0,
				0.4,
				"%.3f m",
				"How much the suspension is compressed at normal ride height.",
			),
		],
	)

	_alignment.group(
		"Toe",
		[
			Tuner.slider(
				&"static_toe_deg",
				"Static toe",
				-2.0,
				2.0,
				"%.2f deg",
				"How much the front of the wheels point inward. Negative means outward.",
			),
			Tuner.slider(
				&"bump_steer_deg_per_m",
				"Bump steer",
				-30.0,
				30.0,
				"%.0f deg/m",
				"How much the toe changes as the wheel moves up.",
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
	Widgets.plot_title("Wheel travel, last 4 s")
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
	_alignment_table()
	Widgets.gap(0.4)

	_susp.draw(true)
	_alignment.draw(true)
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

	Widgets.axle_table(
		"ride_table",
		[
			[
				"Wheel rate",
				"%.1f N/mm" % (front.wheel_rate() / 1000.0),
				"%.1f N/mm" % (rear.wheel_rate() / 1000.0),
			],
			[
				"Ride frequency",
				"%.2f Hz" % f_freq,
				"%.2f Hz" % r_freq,
				_range_color(f_freq, 0.8, 3.5),
				_range_color(r_freq, 0.8, 3.5),
			],
			[
				"Damping, bump",
				"%.2f" % _damping_ratio(front.wheel_bump(), front, front_mass),
				"%.2f" % _damping_ratio(rear.wheel_bump(), rear, rear_mass),
				_range_color(_damping_ratio(front.wheel_bump(), front, front_mass), 0.15, 0.6),
				_range_color(_damping_ratio(rear.wheel_bump(), rear, rear_mass), 0.15, 0.6),
			],
			[
				"Damping, rebound",
				"%.2f" % _damping_ratio(front.wheel_rebound(), front, front_mass),
				"%.2f" % _damping_ratio(rear.wheel_rebound(), rear, rear_mass),
				_range_color(_damping_ratio(front.wheel_rebound(), front, front_mass), 0.25, 0.9),
				_range_color(_damping_ratio(rear.wheel_rebound(), rear, rear_mass), 0.25, 0.9),
			],
			[
				"Static sag",
				"%.0f mm" % (front_mass * gravity / front.wheel_rate() * 1000.0),
				"%.0f mm" % (rear_mass * gravity / rear.wheel_rate() * 1000.0),
				_sag_color(front_mass * gravity / front.wheel_rate(), front.suspension_rest_length),
				_sag_color(rear_mass * gravity / rear.wheel_rate(), rear.suspension_rest_length),
			],
		],
	)

	Widgets.key_value(
		"Rear / front frequency",
		"%.2f" % (r_freq / maxf(f_freq, 0.01)),
		UITheme.GOOD if r_freq >= f_freq * 1.0 and r_freq <= f_freq * 1.3 else UITheme.TEXT,
	)

	Widgets.tip("A rear a little higher than the front settles the car quickly after a bump.")


func _alignment_table() -> void:
	Widgets.wheel_table(
		"alignment_table",
		["Camber", "Toe"],
		func(i: int) -> Array:
			var wheel: Wheel = wheels()[i]
			var camber: float = rad_to_deg(wheel.camber_rad)

			return [
				["%+.2f deg" % camber, _camber_color(camber)],
				"%+.2f deg" % rad_to_deg(wheel.toe_rad),
			],
	)


func _camber_color(camber_deg: float) -> Color:
	var lean: float = absf(camber_deg)
	if lean > 4.0:
		return UITheme.BAD

	return UITheme.WARN if lean > 2.5 else UITheme.GOOD


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


func _frequency(config: SuspensionConfig, corner_mass: float) -> float:
	return sqrt(config.wheel_rate() / maxf(corner_mass, 1.0)) / TAU


func _damping_ratio(wheel_damping: float, config: SuspensionConfig, corner_mass: float) -> float:
	return wheel_damping / (2.0 * sqrt(config.wheel_rate() * maxf(corner_mass, 1.0)))


func _range_color(value: float, low: float, high: float) -> Color:
	return UITheme.GOOD if value >= low and value <= high else UITheme.WARN


func _sag_color(sag: float, travel: float) -> Color:
	var used: float = sag / maxf(travel, 0.01)
	if used > 0.85:
		return UITheme.BAD

	return UITheme.WARN if used > 0.6 or used < 0.15 else UITheme.GOOD
