class_name TiresTab
extends DebugPanel

const SMOOTHING: float = 14.0

const HOT: Color = Color(1.0, 0.60, 0.20, 0.18)

var _kappa := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _alpha := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

var _mu_x := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _mu_y := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

var _fx_norm := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _fy_norm := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

var _tire: Tuner
var _surface: Tuner


func _build() -> void:
	_tire = Tuner.new(
		"Tire model",
		func() -> Object:
			return vehicle.wheel_fl.tire_model,
		func() -> Object:
			return vehicle.wheel_rl.tire_model,
	)

	_tire.group(
		"Longitudinal (braking and drive)",
		[
			Tuner.slider(
				&"long_B",
				"Stiffness",
				4.0,
				30.0,
				"%.1f",
				"How quickly force builds with slip.",
			),
			Tuner.slider(&"long_C", "Shape", 1.0, 2.0, "%.2f", "How the force curve is shaped."),
			Tuner.slider(
				&"long_D",
				"Peak grip",
				0.5,
				2.0,
				"%.2f",
				"Highest force, as a multiple of the load.",
			),
			Tuner.slider(
				&"long_E",
				"Curvature",
				-2.0,
				1.0,
				"%.2f",
				"Lower values give a sharper peak.",
			),
		],
	)

	_tire.group(
		"Lateral (cornering)",
		[
			Tuner.slider(
				&"lat_B",
				"Stiffness",
				4.0,
				30.0,
				"%.1f",
				"How quickly cornering force builds with slip angle.",
			),
			Tuner.slider(&"lat_C", "Shape", 1.0, 2.0, "%.2f", "How the force curve is shaped."),
			Tuner.slider(
				&"lat_D",
				"Peak grip",
				0.5,
				2.0,
				"%.2f",
				"Highest force, as a multiple of the load.",
			),
			Tuner.slider(
				&"lat_E",
				"Curvature",
				-2.0,
				1.0,
				"%.2f",
				"Lower values give a sharper peak.",
			),
		],
	)

	_tire.group(
		"Load and combined slip",
		[
			Tuner.slider(
				&"load_sensitivity",
				"Load sensitivity",
				0.0,
				0.6,
				"%.2f",
				"Grip lost as a tire is overloaded.",
			),
			Tuner.slider(
				&"reference_load_n",
				"Reference load",
				1000.0,
				6000.0,
				"%.0f",
				"Load the grip numbers are quoted at, in N.",
			),
			Tuner.slider(
				&"combined_long_strength",
				"Angle cuts drive",
				0.0,
				1.5,
				"%.2f",
				"How much cornering reduces braking and drive force.",
			),
			Tuner.slider(
				&"combined_lat_strength",
				"Slip cuts turn",
				0.0,
				1.5,
				"%.2f",
				"How much wheelspin or braking reduces cornering force.",
			),
		],
	)

	_tire.group(
		"Camber",
		[
			Tuner.slider(
				&"camber_stiffness_ratio",
				"Camber thrust",
				0.0,
				0.5,
				"%.2f",
				"How much cornering grip the wheel gains from leaning.",
			),
			Tuner.slider(
				&"camber_grip_loss",
				"Grip loss",
				0.0,
				10.0,
				"%.1f",
				"How much grip is lost when the wheel leans too far.",
			),
		],
	)

	_tire.group(
		"Aligning moment",
		[
			Tuner.slider(
				&"pneumatic_trail_m",
				"Pneumatic trail",
				0.0,
				0.08,
				"%.3f m",
				"Strength of steering self centering force.",
			),
			Tuner.slider(
				&"trail_zero_slip_ratio",
				"Trail fades at",
				0.5,
				3.0,
				"%.2f",
				"How much slip is allowed before self centering fades.",
			),
		],
	)

	_surface = Tuner.new(
		"Surface grip",
		func() -> Object:
			return vehicle,
	)

	var rows: Array = []
	for i in range(4):
		var wheel: Wheel = wheels()[i]
		rows.append(
			Tuner.custom(
				StringName("grip_%d" % i),
				UITheme.WHEEL_NAMES[i],
				func() -> float:
					return wheel.friction_coef,
				func(value: float) -> void:
					wheel.friction_coef = value,
				0.1,
				1.5,
				"%.2f",
				"Grip multiplier for this wheel. Lower it to try ice or gravel.",
			),
		)

	_surface.group("", rows)


func update(delta: float) -> void:
	var blend: float = 1.0 - exp(-SMOOTHING * delta)
	for i in range(4):
		var sample = telemetry.wheels[i]
		var load_n: float = maxf(sample.normal_load_n, 1.0)
		var grip: float = maxf(sample.grip_limit_n, 1.0)

		_kappa[i] = lerpf(_kappa[i], sample.slip_ratio, blend)
		_alpha[i] = lerpf(_alpha[i], sample.slip_angle_rad, blend)

		_mu_x[i] = lerpf(_mu_x[i], sample.longitudinal_force_n / load_n, blend)
		_mu_y[i] = lerpf(_mu_y[i], sample.lateral_force_n / load_n, blend)

		_fx_norm[i] = lerpf(_fx_norm[i], sample.longitudinal_force_n / grip, blend)
		_fy_norm[i] = lerpf(_fy_norm[i], sample.lateral_force_n / grip, blend)


func draw() -> void:
	fit_begin()

	_curves()
	Widgets.gap(0.4)

	_table()
	Widgets.gap(0.4)

	_friction_circles()
	Widgets.gap(0.4)

	_aligning_table()
	Widgets.gap(0.4)

	_tire.draw(true)
	_surface.draw(true)

	fit_end()


func _curves() -> void:
	var unit: float = ImGui.GetFontSize()
	var front: Tire = wheels()[0].tire_model
	var rear: Tire = wheels()[2].tire_model
	var split: bool = front != rear

	var grounded: Array[bool] = []
	for i in range(4):
		grounded.append(telemetry.wheels[i].grounded)

	Widgets.wheel_legend()
	if split:
		ImGui.SameLine()
		ImGui.TextDisabled("  colored line: front, white line: rear")

	var ratio := Plots.PlotSpec.new()
	ratio.x_extent = 0.5
	ratio.height = fit(0.5, unit * 5.0, unit * 13.0)
	ratio.color = UITheme.ACCENT
	ratio.peak_x = front.kappa_peak()

	if split:
		ratio.peak_x2 = rear.kappa_peak()

	var ratio_rear: Callable = Callable()
	if split:
		ratio_rear = func(x: float) -> float:
			return rear.compute_fx(x, rear.reference_load_n) / rear.reference_load_n

	Widgets.plot_title("Fx/Fz vs slip ratio")
	Plots.curve_plot(
		"##ratio_plot",
		func(x: float) -> float:
			return front.compute_fx(x, front.reference_load_n) / front.reference_load_n,
		ratio,
		_kappa,
		_mu_x,
		grounded,
		ratio_rear,
	)

	var angle := Plots.PlotSpec.new()
	angle.x_extent = deg_to_rad(20.0)
	angle.x_display_scale = rad_to_deg(1.0)
	angle.x_format = "%.0f deg"
	angle.height = fit(0.5, unit * 5.0, unit * 13.0)
	angle.color = Color(1.0, 0.45, 0.45)
	angle.peak_x = front.alpha_peak()

	if split:
		angle.peak_x2 = rear.alpha_peak()

	var angle_rear: Callable = Callable()
	if split:
		angle_rear = func(x: float) -> float:
			return rear.compute_fy(x, rear.reference_load_n) / rear.reference_load_n

	Widgets.gap(0.3)
	Widgets.plot_title("Fy/Fz vs slip angle")
	Plots.curve_plot(
		"##angle_plot",
		func(x: float) -> float:
			return front.compute_fy(x, front.reference_load_n) / front.reference_load_n,
		angle,
		_alpha,
		_mu_y,
		grounded,
		angle_rear,
	)


func _table() -> void:
	Widgets.wheel_table(
		"tire_table",
		["Slip", "Angle", "Fx", "Fy", "Fz", "Grip"],
		func(i: int) -> Array:
			var sample = telemetry.wheels[i]
			var tire: Tire = wheels()[i].tire_model

			var force: Vector2 = Vector2(sample.longitudinal_force_n, sample.lateral_force_n)
			var grip: float = force.length() / maxf(sample.grip_limit_n, 1.0)

			var grip_color: Color = UITheme.GOOD
			if grip > 1.0:
				grip_color = UITheme.BAD
			elif grip > 0.85:
				grip_color = UITheme.WARN

			var ratio_hot: bool = absf(sample.slip_ratio) > tire.kappa_peak()
			var angle_hot: bool = absf(sample.slip_angle_rad) > tire.alpha_peak()

			return [
				["%+.2f" % sample.slip_ratio, UITheme.TEXT, HOT if ratio_hot else Color(0, 0, 0, 0)],
				[
					"%+.1f" % rad_to_deg(sample.slip_angle_rad),
					UITheme.TEXT,
					HOT if angle_hot else Color(0, 0, 0, 0),
				],
				"%+.0f" % sample.longitudinal_force_n,
				"%+.0f" % sample.lateral_force_n,
				"%.0f" % sample.normal_load_n,
				["%.0f%%" % (grip * 100.0), grip_color],
			],
	)


func _aligning_table() -> void:
	Widgets.wheel_table(
		"aligning_table",
		["Trail", "Twist"],
		func(i: int) -> Array:
			var wheel: Wheel = wheels()[i]

			return [
				"%.0f mm" % (wheel.pneumatic_trail_m * 1000.0),
				"%+.1f Nm" % wheel.aligning_torque_nm,
			],
	)


func _friction_circles() -> void:
	var spacing: float = ImGui.GetFontSize() * 0.6
	var diameter: float = minf(
		(ImGui.GetContentRegionAvail().x - spacing * 3.0) / 4.0,
		ImGui.GetFontSize() * 8.0,
	)

	for i in range(4):
		if i > 0:
			ImGui.SameLine()

		Plots.friction_circle(
			UITheme.WHEEL_NAMES[i],
			UITheme.WHEEL_COLORS[i],
			_fx_norm[i],
			_fy_norm[i],
			diameter,
		)
