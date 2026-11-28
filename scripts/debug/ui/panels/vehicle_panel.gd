class_name VehiclePanel
extends DebugPanel

const SHIFT_LIGHT_COUNT: int = 14

const SAMPLE_INTERVAL: float = 1.0 / 30.0
const TRAIL_LENGTH: int = 90
const SPEED_LENGTH: int = 300

var _performance: PerformanceSection

var _trail: Array = []
var _speed_history: Array = []
var _sample_timer: float = 0.0


func _build() -> void:
	_performance = PerformanceSection.new(vehicle, telemetry, weight_transfer)


func update(delta: float) -> void:
	_performance.update(delta)

	_sample_timer += delta
	if _sample_timer >= SAMPLE_INTERVAL:
		_sample_timer = 0.0

		var g := Vector2(telemetry.lateral_g, telemetry.longitudinal_g)

		_trail.append(g)
		_speed_history.append(telemetry.speed_kmh)

		if _trail.size() > TRAIL_LENGTH:
			_trail.pop_front()

		if _speed_history.size() > SPEED_LENGTH:
			_speed_history.pop_front()


func draw() -> void:
	fit_begin()

	_speedometer()
	_inputs()
	_lamps()

	ImGui.SeparatorText("G-force")
	_g_force()

	_speed_chart()

	ImGui.SeparatorText("Powertrain")
	Widgets.stat_row(
		"powertrain",
		[
			["Engine", "%.0f Nm" % telemetry.engine_torque_nm],
			["Wheels", "%.0f Nm" % telemetry.wheel_torque_nm],
			["Power", "%.0f kW" % telemetry.engine_power_kw],
		],
	)

	Widgets.gap(0.4)
	var unit: float = ImGui.GetFontSize()
	_performance.draw(
		func() -> float:
			return fit(0.1, unit * 2.6, unit * 9.0),
	)

	fit_end()


func _speedometer() -> void:
	ImGui.SetWindowFontScale(2.6)
	ImGui.Text("%3.0f" % telemetry.speed_kmh)
	ImGui.SameLine()

	ImGui.SetWindowFontScale(1.0)
	ImGui.TextDisabled("km/h")
	ImGui.SameLine()

	ImGui.SetWindowFontScale(2.6)
	Widgets.right_text(telemetry.gear_name, UITheme.ACCENT)
	ImGui.SetWindowFontScale(1.0)

	var shifting: String = "  shifting" if telemetry.is_shifting else ""
	ImGui.TextDisabled(telemetry.transmission_name + shifting)


func _inputs() -> void:
	var rpm_fraction: float = telemetry.rpm / maxf(telemetry.rev_limit_rpm, 1.0)
	var rpm_color: Color = UITheme.BAD if rpm_fraction > 0.94 else Color(1.0, 0.75, 0.25)

	Widgets.gap(0.3)
	Plots.shift_lights(rpm_fraction, SHIFT_LIGHT_COUNT, ImGui.GetFontSize() * 1.0)
	Widgets.labeled_bar("RPM", rpm_fraction, "%.0f" % telemetry.rpm, rpm_color)

	Widgets.labeled_bar(
		"THR",
		telemetry.throttle,
		"%.0f%%" % (telemetry.throttle * 100.0),
		UITheme.GOOD,
	)

	Widgets.labeled_bar("BRK", telemetry.brake, "%.0f%%" % (telemetry.brake * 100.0), UITheme.BAD)

	Widgets.labeled_bar(
		"HND",
		vehicle.handbrake_input,
		"%.0f%%" % (vehicle.handbrake_input * 100.0),
		UITheme.WARN,
	)

	Widgets.centered_bar(
		"STR",
		telemetry.steering,
		"%+.1f deg" % telemetry.steer_angle_deg,
		UITheme.ACCENT,
	)


func _lamps() -> void:
	Widgets.gap(0.2)

	var lamps: Array = []
	if vehicle.assists != null:
		var config: AssistsConfig = vehicle.assists_config
		lamps.append(["ABS", config.abs_enabled, vehicle.assists.abs_active])
		lamps.append(["TCS", config.tcs_enabled, vehicle.assists.tcs_active])
		lamps.append(["ESC", config.esc_enabled, vehicle.assists.esc_active])

	for i in range(lamps.size()):
		if i > 0:
			ImGui.SameLine()

		var color: Color = UITheme.DIM
		if lamps[i][1]:
			color = UITheme.WARN if lamps[i][2] else UITheme.GOOD

		Widgets.lamp(lamps[i][0], color)

	if not lamps.is_empty():
		ImGui.SameLine()

	Widgets.lamp("HB", UITheme.BAD if vehicle.handbrake_input > 0.05 else UITheme.DIM)

	ImGui.SameLine()
	Widgets.lamp("LL", UITheme.BAD if vehicle.is_line_locked else UITheme.DIM)

	ImGui.SameLineEx(0.0, ImGui.GetFontSize() * 1.2)
	Widgets.parking_icon(vehicle.handbrake_latched)
	Widgets.tip("Parking brake (P)")

	_warning_icons()


func _warning_icons() -> void:
	var mechanical: MechanicalDamage = vehicle.mechanical_damage
	if mechanical == null:
		return

	Widgets.gap(0.3)

	var step: float = ImGui.GetFontSize() * DashIcons.SIZE_SCALE + 8.0
	var per_row: int = maxi(int(ImGui.GetContentRegionAvail().x / step), 1)

	var icons: Array = [
		_engine_icon(mechanical),
		_temperature_icon(mechanical),
		_oil_icon(mechanical),
		_brake_icon(mechanical),
		_steering_icon(mechanical),
		_gearbox_icon(mechanical),
		_axle_icon(mechanical),
		_suspension_icon(mechanical),
		_tire_icon(),
	]

	for i in range(icons.size()):
		if i % per_row != 0:
			ImGui.SameLine()

		DashIcons.draw(icons[i][0], icons[i][1])
		Widgets.tip(icons[i][2])


func _icon(kind: DashIcons.Icon, warn: bool, bad: bool, text: String) -> Array:
	var color: Color = UITheme.DIM
	if bad:
		color = UITheme.BAD
	elif warn:
		color = UITheme.WARN

	return [kind, color, text]


func _engine_icon(mechanical: MechanicalDamage) -> Array:
	var health: float = mechanical.engine_health()
	var boost: float = mechanical.boost_factor()

	var text: String = "Engine %.0f%%, boost %.0f%%" % [health * 100.0, boost * 100.0]
	if mechanical.seized:
		text = "Engine seized"

	return _icon(
		DashIcons.Icon.ENGINE,
		health < 0.95 or boost < 0.95,
		health < 0.5 or mechanical.seized,
		text,
	)


func _temperature_icon(mechanical: MechanicalDamage) -> Array:
	var heat: float = mechanical.coolant_c
	var level: float = mechanical.coolant

	return _icon(
		DashIcons.Icon.TEMPERATURE,
		heat > 103.0 or level < 0.9,
		heat > 113.0 or level < 0.35,
		"Coolant %.0f C, %.0f%% full" % [heat, level * 100.0],
	)


func _oil_icon(mechanical: MechanicalDamage) -> Array:
	var level: float = mechanical.oil
	var pressure: float = mechanical.oil_pressure

	return _icon(
		DashIcons.Icon.OIL,
		level < 0.9,
		pressure < 0.9,
		"Oil %.0f%% full, pressure %.0f%%" % [level * 100.0, pressure * 100.0],
	)


func _brake_icon(mechanical: MechanicalDamage) -> Array:
	var first: float = mechanical.brake_pressure(0)
	var second: float = mechanical.brake_pressure(1)
	var leak: float = maxf(mechanical.brake_leak[0], mechanical.brake_leak[1])

	return _icon(
		DashIcons.Icon.BRAKES,
		leak > 0.0,
		minf(first, second) < 0.9,
		"Brakes FL+RR %.0f%%, FR+RL %.0f%%" % [first * 100.0, second * 100.0],
	)


func _steering_icon(mechanical: MechanicalDamage) -> Array:
	var assist: float = mechanical.steering_assist()
	var rack: float = mechanical.damage[MechanicalDamage.Part.STEERING_RACK]
	var pull: float = rad_to_deg(mechanical.steer_offset_rad)

	return _icon(
		DashIcons.Icon.STEERING,
		assist < 0.8 or rack > 0.05 or absf(pull) > 0.3,
		assist < 0.3 or rack > 0.6,
		"Power steering %.0f%%, pull %+.1f deg" % [assist * 100.0, pull],
	)


func _gearbox_icon(mechanical: MechanicalDamage) -> Array:
	var worn: float = mechanical.damage[MechanicalDamage.Part.GEARBOX]

	return _icon(
		DashIcons.Icon.GEARBOX,
		worn > 0.05,
		worn > 0.7,
		"Gearbox %.0f%% damaged" % (worn * 100.0),
	)


func _axle_icon(mechanical: MechanicalDamage) -> Array:
	var worst: float = mechanical.damage[MechanicalDamage.Part.DRIVESHAFT]
	var text: String = "Driveshaft %.0f%% damaged" % (worst * 100.0)

	for wheel in vehicle.wheels:
		var worn: float = mechanical.damage[mechanical.axle_of(wheel)]
		worst = maxf(worst, worn)
		text += "\n%s axle %.0f%% damaged" % [wheel.label, worn * 100.0]

	return _icon(DashIcons.Icon.AXLE, worst > 0.2, worst >= 1.0, text)


func _suspension_icon(mechanical: MechanicalDamage) -> Array:
	var damper: float = 1.0
	var bent: bool = false
	var torn: bool = false

	for wheel in vehicle.wheels:
		damper = minf(damper, mechanical.damper_health(wheel))

	for state in vehicle.wheel_damage.states:
		torn = torn or state.torn
		bent = (
			bent or state.sag_m > 0.005 or absf(state.swing_rad) > 0.01
			or absf(state.lean_rad) > 0.01
		)

	var text: String = "Weakest damper %.0f%%" % (damper * 100.0)
	if torn:
		text += "\nWheel torn off"
	elif bent:
		text += "\nSuspension bent"

	return _icon(DashIcons.Icon.SUSPENSION, damper < 0.9 or bent, damper < 0.5 or torn, text)


func _tire_icon() -> Array:
	var warn: bool = false
	var bad: bool = false
	var text: String = "Tire air"

	for state in vehicle.wheel_damage.states:
		warn = warn or state.air < 0.9 or state.leak_per_s > 0.0
		bad = bad or state.air < 0.5 or state.burst or state.torn
		text += "\n%s %.0f%%" % [state.wheel.label, state.air * 100.0]

	return _icon(DashIcons.Icon.TIRE, warn, bad, text)


func _g_force() -> void:
	var unit: float = ImGui.GetFontSize()
	var width: float = ImGui.GetContentRegionAvail().x
	var current := Vector2(telemetry.lateral_g, telemetry.longitudinal_g)

	var peak: float = current.length()
	for sample: Vector2 in _trail:
		peak = maxf(peak, sample.length())

	var extent: float = clampf(ceilf(peak * 2.0) * 0.5, 1.5, 4.0)

	Plots.gg_plot(_trail, current, extent, fit(0.45, unit * 9.0, width))
	Widgets.stat_row(
		"g_force",
		[
			["Lateral", "%+.2f g" % current.x],
			["Longitudinal", "%+.2f g" % current.y],
			["Total", "%.2f g" % current.length()],
		],
	)


func _speed_chart() -> void:
	var unit: float = ImGui.GetFontSize()

	var peak: float = 0.0
	for value in _speed_history:
		peak = maxf(peak, value)

	ImGui.SeparatorText("Speed, last 10 s")
	Plots.line_plot(
		"##speed_history",
		_speed_history,
		0.0,
		maxf(ceilf(peak * 1.1 / 20.0) * 20.0, 40.0),
		fit(0.3, unit * 4.0, unit * 16.0),
		UITheme.ACCENT,
		"%.0f km/h" % telemetry.speed_kmh,
	)
