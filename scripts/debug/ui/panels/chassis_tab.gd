class_name ChassisTab
extends DebugPanel

const DRIVER_LABEL_HOLD_S: float = 1.0

var _chassis: Tuner
var _brakes: Tuner
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
		"Steering feel",
		[
			Tuner.slider(
				&"steering_ratio",
				"Steering ratio",
				8.0,
				24.0,
				"%.1f : 1",
				"How much the steering wheel turns compared to the front wheels.",
			),
			Tuner.slider(
				&"steering_inertia",
				"Inertia",
				0.1,
				10.0,
				"%.1f",
				"How heavy the steering wheel feels.",
			),
			Tuner.slider(
				&"steering_damping",
				"Damping",
				10.0,
				2000.0,
				"%.0f",
				"How much the steering resists fast movements.",
			),
			Tuner.slider(
				&"steering_friction_nm",
				"Friction",
				0.0,
				60.0,
				"%.0f Nm",
				"Friction in the steering rack.",
			),
			Tuner.slider(
				&"driver_strength_nm",
				"Driver Strength",
				50.0,
				2000.0,
				"%.0f Nm",
				"Maximum turning force the driver can apply.",
			),
			Tuner.slider(
				&"low_speed_return_nm_per_rad",
				"Low speed return",
				0.0,
				2000.0,
				"%.0f",
				"How strongly the wheel straightens itself when released.",
			),
			Tuner.slider(
				&"relaxed_grip",
				"Relaxed grip",
				0.0,
				1.0,
				"%.2f",
				"How firmly the driver holds the wheel at speed when no key is pressed.",
			),
		],
	)

	_chassis.group(
		"Pedal",
		[
			Tuner.slider(
				&"brake_pedal_rate",
				"Pedal speed",
				0.5,
				10.0,
				"%.1f",
				"How fast the brake pedal goes down.",
			),
		],
	)

	_chassis.group(
		"Aerodynamics",
		[
			Tuner.slider(&"drag_coefficient", "Drag coefficient", 0.1, 1.0, "%.2f"),
			Tuner.slider(&"frontal_area", "Frontal area", 1.0, 4.0, "%.2f", "In square meters."),
		],
	)

	_brakes = Tuner.new(
		"Brakes",
		func() -> Object:
			return vehicle.config.front_brakes,
		func() -> Object:
			return vehicle.config.rear_brakes,
	)

	_brakes.group(
		"",
		[
			Tuner.slider(
				&"max_torque_nm",
				"Torque per wheel",
				200.0,
				4000.0,
				"%.0f",
				"Brake torque at each wheel with the pedal fully down.",
			),
			Tuner.slider(
				&"handbrake_torque_nm",
				"Handbrake torque",
				0.0,
				3000.0,
				"%.0f",
				"Handbrake torque at each wheel that has a handbrake.",
			),
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

	_steering_status()
	Widgets.gap(0.4)

	_chassis.draw(true)
	_brake_section()
	_mass.draw(true)


func _brake_section() -> void:
	if not Widgets.section(_brakes.title, true):
		return

	_brakes.draw_body()

	var front: BrakeConfig = vehicle.config.front_brakes
	var rear: BrakeConfig = vehicle.config.rear_brakes
	var total: float = maxf(front.max_torque_nm + rear.max_torque_nm, 1.0)

	var bias: Array = [front.max_torque_nm / total * 100.0]
	ImGui.SeparatorText("Brake bias")
	if Tuner.field(
		"Front share",
		"brake_bias",
		bias,
		30.0,
		90.0,
		"%.0f%%",
		"Moves braking between the axles.",
	):
		front.max_torque_nm = total * bias[0] / 100.0
		rear.max_torque_nm = total - front.max_torque_nm


func _steering_status() -> void:
	if not Widgets.section("Steering status", true):
		return

	var steering: Steering = vehicle.steering
	var ratio: float = vehicle.config.steering_ratio

	var wheel_deg: float = rad_to_deg(vehicle.steer_angle_rad) * ratio
	Widgets.key_value("Steering wheel", "%+.0f deg" % wheel_deg)

	var pull_nm: float = steering.load_torque_nm / ratio
	var pull_color: Color = UITheme.GOOD if absf(pull_nm) < 8.0 else UITheme.WARN

	Widgets.centered_bar(
		"PULL",
		pull_nm / 12.0,
		"%.1f Nm %s" % [absf(pull_nm), "left" if pull_nm > 0.0 else "right"],
		pull_color,
	)

	Widgets.key_value("Tire torque on steering", "%+.0f Nm" % steering.load_torque_nm)

	var driver_state: String = "hands off"
	if steering.idle_time_s < DRIVER_LABEL_HOLD_S:
		driver_state = "steering"
	elif steering.hands_on > 0.05:
		driver_state = "relaxed grip"

	Widgets.key_value(
		"Driver",
		driver_state,
		UITheme.DIM if driver_state == "hands off" else UITheme.TEXT,
	)


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
