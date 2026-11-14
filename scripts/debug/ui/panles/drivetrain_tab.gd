class_name DrivetrainTab
extends DebugPanel

const LAYOUT_NAMES: Array = ["RWD", "FWD", "AWD"]
const DIFFERENTIAL_NAMES: Array = ["Open", "Locked", "Limited slip"]

const GEAR_COUNT_MIN: int = 3
const GEAR_COUNT_MAX: int = 8

var _layout: Tuner
var _gearbox: Tuner

var _default_ratios: Array = []


func _build() -> void:
	var config := func() -> Object:
		return vehicle.drivetrain_node.config

	var limited_slip: int = DrivetrainConfig.DifferentialType.LIMITED_SLIP

	var all_wheel: Callable = func() -> bool:
		return _drive_layout() == 2

	var one_axle: Callable = func() -> bool:
		return _drive_layout() != 2

	var axle_lsd: Callable = func() -> bool:
		return vehicle.drivetrain_node.config.differential_type == limited_slip

	var center_lsd: Callable = func() -> bool:
		return (
			_drive_layout() == 2
			and vehicle.drivetrain_node.config.center_differential_type == limited_slip
		)

	_layout = Tuner.new("Layout and differentials", config)

	_layout.group(
		"",
		[
			Tuner.custom_choice(
				&"layout",
				"Drive layout",
				LAYOUT_NAMES,
				_drive_layout,
				_set_drive_layout,
				"Which wheels the engine drives.",
			),
		],
	)

	_layout.group(
		"Center differential",
		[
			Tuner.choice(
				&"center_differential_type",
				"Type",
				DIFFERENTIAL_NAMES,
				"Shares the engine torque between the front and rear axles.",
			),
			Tuner.slider(
				&"center_front_torque_share",
				"Front torque",
				0.0,
				1.0,
				"%.2f",
				"Share of the engine torque sent to the front.",
			),
		],
		all_wheel,
	)

	_layout.group(
		"Center limited slip",
		[
			Tuner.slider(&"center_lsd_preload_nm", "Preload", 0.0, 300.0, "%.0f"),
			Tuner.slider(&"center_lsd_power_lock", "Lock on power", 0.0, 1.0, "%.2f"),
			Tuner.slider(&"center_lsd_coast_lock", "Lock on coast", 0.0, 1.0, "%.2f"),
		],
		center_lsd,
	)

	_layout.group(
		"Front and rear differentials",
		[
			Tuner.choice(
				&"differential_type",
				"Type",
				DIFFERENTIAL_NAMES,
				"Used on both axles. Each one shares torque between its own two wheels.",
			),
		],
		all_wheel,
	)

	_layout.group(
		"Differential",
		[
			Tuner.choice(
				&"differential_type",
				"Type",
				DIFFERENTIAL_NAMES,
				"Shares torque between the two driven wheels.",
			),
		],
		one_axle,
	)

	_layout.group(
		"Axle limited slip",
		[
			Tuner.slider(
				&"lsd_preload_nm",
				"Preload",
				0.0,
				300.0,
				"%.0f",
				"Locking torque that is always present, in Nm.",
			),
			Tuner.slider(&"lsd_power_lock", "Lock on power", 0.0, 1.0, "%.2f"),
			Tuner.slider(&"lsd_coast_lock", "Lock on coast", 0.0, 1.0, "%.2f"),
		],
		axle_lsd,
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
			Tuner.slider(&"auto_upshift_rpm", "Auto upshift", 4000.0, 9000.0, "%.0f"),
			Tuner.slider(&"auto_downshift_rpm", "Auto downshift", 1000.0, 5000.0, "%.0f"),
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
	_gearbox.draw(true)
	_gear_ratios(drivetrain)

	fit_end()


func _chart(drivetrain: Drivetrain) -> void:
	var config: DrivetrainConfig = drivetrain.config
	var ratios: Array = Array(config.gear_ratios)

	var wheel_radius: float = vehicle.wheel_fl.suspension_config.wheel_radius
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

	Widgets.key_value(
		"Top speed",
		"%.0f km/h" % Plots.top_speed_kmh(ratios, config.final_drive_ratio, wheel_radius, rev_limit),
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
	var front: bool = vehicle.wheel_fl.is_driven or vehicle.wheel_fr.is_driven
	var rear: bool = vehicle.wheel_rl.is_driven or vehicle.wheel_rr.is_driven

	if front and rear:
		return 2

	return 1 if front else 0


func _set_drive_layout(layout: int) -> void:
	var front: bool = layout != 0
	var rear: bool = layout != 1

	vehicle.wheel_fl.is_driven = front
	vehicle.wheel_fr.is_driven = front
	vehicle.wheel_rl.is_driven = rear
	vehicle.wheel_rr.is_driven = rear
