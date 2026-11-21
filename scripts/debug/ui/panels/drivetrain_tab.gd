class_name DrivetrainTab
extends DebugPanel

const LAYOUT_NAMES: Array = ["RWD", "FWD", "AWD"]
const DIFFERENTIAL_NAMES: Array = ["Open", "Locked", "Limited slip"]

const GEAR_COUNT_MIN: int = 3
const GEAR_COUNT_MAX: int = 8

var _layout: Tuner

var _center: Tuner
var _axles: Tuner

var _gearbox: Tuner

var _default_ratios: Array = []


func _build() -> void:
	var config := func() -> Object:
		return vehicle.drivetrain_node.config

	var limited_slip: int = DifferentialConfig.Type.LIMITED_SLIP

	_layout = Tuner.new("Drive layout", config)

	_layout.group(
		"",
		[
			Tuner.custom_choice(
				&"layout",
				"Layout",
				LAYOUT_NAMES,
				_drive_layout,
				_set_drive_layout,
				"Which wheels the engine drives.",
			),
		],
	)

	_center = Tuner.new(
		"Center differential",
		func() -> Object:
			return vehicle.drivetrain_node.config.center_differential,
	)

	_center.group(
		"",
		[
			Tuner.choice(
				&"type",
				"Type",
				DIFFERENTIAL_NAMES,
				"Shares the engine torque between the front and rear axles.",
			),
			Tuner.custom(
				&"front_share",
				"Front torque",
				_front_share,
				_set_front_share,
				0.0,
				1.0,
				"%.2f",
				"Share of the engine torque sent to the front.",
			),
		],
	)

	_center.group(
		"Limited slip",
		[
			Tuner.slider(
				&"preload_nm",
				"Preload",
				0.0,
				300.0,
				"%.0f",
				"Locking torque that is always present, in Nm.",
			),
			Tuner.slider(&"power_lock", "Lock on power", 0.0, 1.0, "%.2f"),
			Tuner.slider(&"coast_lock", "Lock on coast", 0.0, 1.0, "%.2f"),
		],
		func() -> bool:
			return vehicle.drivetrain_node.config.center_differential.type == limited_slip,
	)

	var front_diff: Callable = func() -> DifferentialConfig:
		return vehicle.drivetrain_node.config.front_differential
	var rear_diff: Callable = func() -> DifferentialConfig:
		return vehicle.drivetrain_node.config.rear_differential

	_axles = Tuner.new(
		"Axle differentials",
		func() -> Object:
			return front_diff.call(),
		func() -> Object:
			return rear_diff.call(),
		_driven_axles,
	)

	_axles.group(
		"",
		[
			Tuner.choice(
				&"type",
				"Type",
				DIFFERENTIAL_NAMES,
				"Shares torque between the two wheels of an axle.",
			),
		],
	)

	_axles.group(
		"Limited slip",
		[
			Tuner.slider(
				&"preload_nm",
				"Preload",
				0.0,
				300.0,
				"%.0f",
				"Locking torque that is always present, in Nm.",
			),
			Tuner.slider(&"power_lock", "Lock on power", 0.0, 1.0, "%.2f"),
			Tuner.slider(&"coast_lock", "Lock on coast", 0.0, 1.0, "%.2f"),
		],
		func() -> bool:
			return front_diff.call().type == limited_slip or rear_diff.call().type == limited_slip,
	)

	_gearbox = Tuner.new("Gearbox", config)

	_gearbox.group(
		"",
		[
			Tuner.slider(
				&"final_drive_ratio",
				"Final drive",
				2.0,
				6.0,
				"%.2f",
				"Multiplies every gear ratio.",
			),
			Tuner.slider(
				&"shift_delay_seconds",
				"Shift time",
				0.0,
				1.0,
				"%.2f",
				"Seconds the drive is cut during a shift.",
			),
			Tuner.slider(&"auto_upshift_rpm", "Upshift, full throttle", 4000.0, 9000.0, "%.0f"),
			Tuner.slider(
				&"auto_light_upshift_rpm",
				"Upshift, light throttle",
				1500.0,
				6000.0,
				"%.0f",
				"Engine speed to shift up when pressing the throttle gently.",
			),
			Tuner.slider(&"auto_downshift_rpm", "Downshift, light throttle", 1000.0, 5000.0, "%.0f"),
			Tuner.slider(
				&"auto_kickdown_rpm",
				"Downshift, full throttle",
				1000.0,
				5000.0,
				"%.0f",
				"Engine speed to shift down when flooring the throttle.",
			),
			Tuner.slider(
				&"auto_kickdown_throttle",
				"Kickdown throttle",
				0.5,
				1.0,
				"%.2f",
				"With the throttle pressed this far, the automatic may skip several gears going down.",
			),
		],
	)


func draw() -> void:
	var drivetrain: Drivetrain = vehicle.drivetrain_node
	if drivetrain == null or drivetrain.config == null:
		ImGui.Text("Drivetrain unavailable")
		return

	fit_begin()

	_chart(drivetrain)
	Widgets.gap(0.6)

	_layout.draw(true)
	if _drive_layout() == 2:
		_center.draw(true)

	_axles.draw(true)
	_gearbox.draw(true)
	_gear_ratios(drivetrain)

	fit_end()


func _chart(drivetrain: Drivetrain) -> void:
	var config: DrivetrainConfig = drivetrain.config
	var ratios: Array = Array(config.gear_ratios)

	var wheel_radius: float = _drive_radius()
	var rev_limit: float = vehicle.engine_node.config.rev_limiter_rpm

	var top_speed: float = Plots.top_speed_kmh(
		ratios,
		config.final_drive_ratio,
		wheel_radius,
		rev_limit,
	)

	Widgets.stat_row(
		"drive_now",
		[
			["Gear", telemetry.gear_name],
			[
				"Overall ratio",
				"%.2f" % (absf(drivetrain.get_current_ratio()) * config.final_drive_ratio),
			],
			["Top speed", "%.0f km/h" % top_speed],
		],
	)

	Widgets.gap(0.3)

	Widgets.plot_title("Gears: rpm against km/h")
	Plots.gear_chart(
		ratios,
		config.final_drive_ratio,
		wheel_radius,
		rev_limit,
		telemetry.speed_kmh,
		telemetry.rpm,
		drivetrain.current_gear_index,
		fit(1.0, ImGui.GetFontSize() * 10.0, ImGui.GetFontSize() * 40.0),
	)


func _gear_ratios(drivetrain: Drivetrain) -> void:
	if not Widgets.section("Gear ratios", true):
		return

	var config: DrivetrainConfig = drivetrain.config
	var ratios: Array = Array(config.gear_ratios)
	if _default_ratios.is_empty():
		_default_ratios = ratios.duplicate()

	if ratios.size() > 0:
		_gear_row(config, 0, "Reverse", -6.0, -1.0)

	for i in range(2, ratios.size()):
		_gear_row(config, i, "Gear %d" % (i - 1), 0.3, 5.0)

	var count: Array = [maxi(ratios.size() - 2, GEAR_COUNT_MIN)]
	if Tuner.int_field("Gear count", "gear_count", count, GEAR_COUNT_MIN, GEAR_COUNT_MAX):
		_set_gear_count(drivetrain, count[0])

	Widgets.gap(0.2)
	if ImGui.SmallButton("Reset gears"):
		_assign_ratios(drivetrain, _default_ratios)


func _gear_row(
	config: DrivetrainConfig,
	index: int,
	label: String,
	v_min: float,
	v_max: float,
) -> void:
	var buffer: Array = [float(config.gear_ratios[index])]
	if Tuner.field(label, "gear_%d" % index, buffer, v_min, v_max, "%.3f"):
		config.gear_ratios[index] = buffer[0]


func _set_gear_count(drivetrain: Drivetrain, forward_count: int) -> void:
	var ratios: Array = Array(drivetrain.config.gear_ratios)
	var target: int = forward_count + 2

	while ratios.size() > target:
		ratios.pop_back()

	while ratios.size() < target:
		ratios.append(float(ratios.back()) * 0.82)

	_assign_ratios(drivetrain, ratios)


func _assign_ratios(drivetrain: Drivetrain, ratios: Array) -> void:
	var config: DrivetrainConfig = drivetrain.config

	if typeof(config.gear_ratios) == TYPE_PACKED_FLOAT32_ARRAY:
		config.gear_ratios = PackedFloat32Array(ratios)
	else:
		config.gear_ratios.assign(ratios)

	drivetrain.current_gear_index = mini(drivetrain.current_gear_index, ratios.size() - 1)


func _drive_layout() -> int:
	var front: bool = false
	var rear: bool = false

	for wheel in wheels():
		if wheel.is_front:
			front = front or wheel.is_driven
		else:
			rear = rear or wheel.is_driven

	if front and rear:
		return 2

	return 1 if front else 0


func _set_drive_layout(layout: int) -> void:
	var front: bool = layout != 0
	var rear: bool = layout != 1

	for wheel in wheels():
		wheel.is_driven = front if wheel.is_front else rear


func _drive_radius() -> float:
	var total: float = 0.0
	var count: int = 0
	for wheel in wheels():
		if wheel.is_driven:
			total += wheel.suspension_config.wheel_radius
			count += 1

	if count == 0:
		return vehicle.rear_wheel().suspension_config.wheel_radius

	return total / float(count)


func _driven_axles() -> Array:
	var layout: int = _drive_layout()
	return [layout != 0, layout != 1]


func _front_share() -> float:
	return vehicle.drivetrain_node.config.center_front_torque_share


func _set_front_share(value: float) -> void:
	vehicle.drivetrain_node.config.center_front_torque_share = value
