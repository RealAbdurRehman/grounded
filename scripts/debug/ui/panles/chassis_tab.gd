class_name ChassisTab
extends DebugPanel

var _chassis: Tuner
var _suspension: Tuner
var _mass: Tuner


func _build() -> void:
	_chassis = Tuner.new(
		"Chassis",
		func() -> Object:
			return vehicle.config,
	)

	_chassis.group(
		"Steering",
		[
			Tuner.slider(&"max_steer_angle_deg", "Max angle", 15.0, 45.0, "%.0f deg"),
			Tuner.slider(
				&"ackermann_factor",
				"Ackermann",
				-1.0,
				1.0,
				"%.2f",
				"0 is parallel steering, 1 is true Ackermann.",
			),
			Tuner.slider(
				&"steer_rate_deg_s",
				"Steer rate",
				20.0,
				300.0,
				"%.0f",
				"How fast the wheels turn, in degrees per second.",
			),
			Tuner.slider(
				&"steer_speed_sensitivity",
				"Speed sensitivity",
				0.0,
				1.0,
				"%.2f",
				"How much steering is limited at speed.",
			),
		],
	)

	_chassis.group(
		"Brakes",
		[
			Tuner.slider(
				&"brake_bias_front",
				"Front bias",
				0.3,
				0.9,
				"%.2f",
				"Share of braking done by the front axle.",
			),
			Tuner.slider(
				&"max_brake_torque",
				"Brake torque",
				1000.0,
				10000.0,
				"%.0f",
				"Total for all four wheels, in Nm.",
			),
			Tuner.slider(&"brake_pedal_rate", "Pedal speed", 0.5, 10.0, "%.1f"),
			Tuner.slider(
				&"max_handbrake_torque",
				"Handbrake torque",
				0.0,
				6000.0,
				"%.0f",
				"Total for the rear axle, in Nm.",
			),
		],
	)

	_chassis.group(
		"Anti-roll bars",
		[
			Tuner.slider(&"front_arb_stiffness", "Front", 0.0, 20000.0, "%.0f"),
			Tuner.slider(&"rear_arb_stiffness", "Rear", 0.0, 20000.0, "%.0f"),
		],
	)

	_chassis.group(
		"Aerodynamics",
		[
			Tuner.slider(&"drag_coefficient", "Drag coefficient", 0.1, 1.0, "%.2f"),
			Tuner.slider(&"frontal_area", "Frontal area", 1.0, 4.0, "%.2f", "In square meters."),
		],
	)

	_suspension = Tuner.new(
		"Suspension",
		func() -> Object:
			return vehicle.wheel_fl.suspension_config,
	)

	_suspension.group(
		"",
		[
			Tuner.slider(&"spring_stiffness", "Spring", 10000.0, 60000.0, "%.0f", "In N/m."),
			Tuner.slider(&"damper_stiffness", "Damper", 500.0, 6000.0, "%.0f"),
			Tuner.slider(
				&"suspension_rest_length",
				"Travel",
				0.1,
				0.8,
				"%.2f",
				"How far the wheel hangs below the car, in m.",
			),
			Tuner.slider(&"wheel_radius", "Wheel radius", 0.2, 0.5, "%.2f", "In m."),
		],
	)

	_mass = Tuner.new(
		"Mass and balance",
		func() -> Object:
			return vehicle,
	)

	_mass.group(
		"",
		[
			Tuner.slider(&"mass", "Mass", 500.0, 2500.0, "%.0f", "In kg."),
			Tuner.custom(
				&"com_y",
				"Center of mass height",
				_com_axis_getter(1),
				_com_axis_setter(1),
				0.1,
				1.0,
				"%.2f",
				"In m.",
			),
			Tuner.custom(
				&"com_z",
				"Center of mass fore/aft",
				_com_axis_getter(2),
				_com_axis_setter(2),
				-2.0,
				2.0,
				"%.2f",
				"Negative is towards the front.",
			),
		],
	)


func draw() -> void:
	_status()
	Widgets.gap(0.4)

	_chassis.draw(true)
	_ride()
	_mass.draw(true)


func _ride() -> void:
	if not Widgets.section(_suspension.title, true):
		return

	for i in range(4):
		var travel: float = telemetry.wheels[i].compression
		Widgets.labeled_bar(
			UITheme.WHEEL_NAMES[i],
			travel,
			"%.0f%%" % (travel * 100.0),
			UITheme.WHEEL_COLORS[i],
		)

	_suspension.draw_body()


func _status() -> void:
	if not Widgets.section("Brake status", true):
		return

	Widgets.labeled_bar(
		"HND",
		vehicle.handbrake_input,
		"%.0f%%" % (vehicle.handbrake_input * 100.0),
		UITheme.WARN,
	)

	Widgets.gap(0.2)
	Widgets.wheel_table(
		"brake_table",
		["Handbrake", "State", ["Grip used", 1.3]],
		func(i: int) -> Array:
			var wheel: Wheel = wheels()[i]

			var state: String = "free"
			var color: Color = UITheme.DIM
			if wheel.is_stuck:
				state = "hold"
				color = UITheme.GOOD
			elif wheel.is_locked:
				state = "locked"
				color = UITheme.BAD

			var peak: float = wheel.tire_model.peak_longitudinal_force_n(
				wheel.normal_load_n,
				wheel.friction_coef,
			)
			var used: float = absf(wheel.longitudinal_force_n) / maxf(peak, 1.0)

			return [
				"%.0f Nm" % vehicle.get_handbrake_torque_nm(wheel),
				[state, color],
				{ "fraction": used, "text": "%.0f%%" % (used * 100.0), "color": color },
			],
	)

	_slope_hold()


func _slope_hold() -> void:
	ImGui.SeparatorText("Slope hold")

	var normal_sum: Vector3 = Vector3.ZERO
	var holding: int = 0
	var capacity_n: float = 0.0

	for wheel in wheels():
		if not wheel.is_grounded:
			continue

		normal_sum += wheel.contact_normal
		if wheel.is_stuck:
			holding += 1

		var brake_nm: float = vehicle.assists.brake_torque(wheel) + vehicle.get_handbrake_torque_nm(
			wheel
		)
		var grip_n: float = wheel.tire_model.peak_longitudinal_force_n(
			wheel.normal_load_n,
			wheel.friction_coef,
		)
		capacity_n += minf(grip_n, brake_nm / wheel.suspension_config.wheel_radius)

	var slope: float = 0.0
	if normal_sum.length() > 0.001:
		slope = acos(clampf(normal_sum.normalized().dot(Vector3.UP), -1.0, 1.0))

	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var pull_n: float = vehicle.mass * gravity * vehicle.gravity_scale * sin(slope)
	var used: float = pull_n / maxf(capacity_n, 1.0)

	Widgets.key_value("Slope", "%.1f deg  (%.0f%% grade)" % [rad_to_deg(slope), tan(slope) * 100.0])
	Widgets.labeled_bar(
		"HOLD",
		used,
		"%.0f of %.0f N" % [pull_n, capacity_n],
		UITheme.GOOD if used < 1.0 else UITheme.BAD,
	)

	var speed: float = vehicle.linear_velocity.length()
	var creeping: bool = speed > 0.01 and speed < 0.5 and holding == 0 and pull_n > 0.0
	Widgets.key_value(
		"Wheels holding",
		"%d of 4" % holding,
		UITheme.GOOD if holding > 0 else UITheme.TEXT,
	)
	Widgets.key_value(
		"Speed",
		"%.1f cm/s" % (speed * 100.0) if speed < 0.5 else "%.1f m/s" % speed,
		UITheme.WARN if creeping else UITheme.TEXT,
	)


func _com_axis_getter(axis: int) -> Callable:
	return func() -> float:
		return vehicle.center_of_mass[axis]


func _com_axis_setter(axis: int) -> Callable:
	return func(value: float) -> void:
		var com: Vector3 = vehicle.center_of_mass

		com[axis] = value
		vehicle.center_of_mass = com
