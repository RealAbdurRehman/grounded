class_name UI
extends Node

@export var vehicle: Vehicle
@export var telemetry: Telemetry
@export var weight_transfer: WeightTransfer

@export var enabled: bool = true

@export var speed_bar_max_kmh: float = 250.0
@export_range(1.0, 40.0, 0.5) var marker_smoothing: float = 14.0

const HISTORY_LENGTH := 150
const SHIFT_LIGHT_COUNT := 10
const GEAR_COUNT_MIN := 3
const GEAR_COUNT_MAX := 8

const TIRE_SLIDERS_LONGITUDINAL: Array = [
	[&"long_B", "B  stiffness", 4.0, 30.0, "%.2f"],
	[&"long_C", "C  shape", 1.0, 2.0, "%.2f"],
	[&"long_D", "D  peak", 0.5, 2.0, "%.2f"],
	[&"long_E", "E  curvature", -2.0, 1.0, "%.2f"],
]

const TIRE_SLIDERS_LATERAL: Array = [
	[&"lat_B", "B  stiffness", 4.0, 30.0, "%.2f"],
	[&"lat_C", "C  shape", 1.0, 2.0, "%.2f"],
	[&"lat_D", "D  peak", 0.5, 2.0, "%.2f"],
	[&"lat_E", "E  curvature", -2.0, 1.0, "%.2f"],
]

const TIRE_SLIDERS_OTHER: Array = [
	[&"load_sensitivity", "Load sensitivity", 0.0, 0.6, "%.2f"],
	[&"reference_load_n", "Reference load N", 1000.0, 6000.0, "%.0f"],
	[&"combined_long_strength", "Combined: long", 0.0, 1.5, "%.2f"],
	[&"combined_lat_strength", "Combined: lat", 0.0, 1.5, "%.2f"],
]

const ENGINE_SLIDERS: Array = [
	[&"displacement", "Displacement", 50.0, 500.0, "%.0f"],
	[&"boost", "Boost", 100.0, 1000.0, "%.0f"],
	[&"cam_peak_rpm", "Cam peak", 2000.0, 8000.0, "%.0f"],
	[&"falloff", "Falloff shape", 1.0, 10.0, "%.2f"],
	[&"bandwidth", "Bandwidth", 1000.0, 8000.0, "%.0f"],
	[&"rev_limiter_rpm", "Rev limiter", 4000.0, 10000.0, "%.0f"],
	[&"max_rpm", "Max RPM", 4000.0, 10000.0, "%.0f"],
	[&"idle_rpm", "Idle RPM", 500.0, 1500.0, "%.0f"],
	[&"engine_braking_factor", "Engine Braking", 0.0, 200.0, "%.0f"],
	[&"flywheel_inertia", "Flywheel", 0.05, 1.0, "%.2f"],
]

const DRIVE_LAYOUT_NAMES: Array = ["RWD", "FWD", "AWD"]
const DIFFERENTIAL_NAMES: Array = ["Open", "Locked", "Limited slip"]

const DRIVETRAIN_SLIDERS: Array = [
	[&"drivetrain_efficiency", "Efficiency", 0.6, 1.0, "%.2f"],
	[&"shift_delay_seconds", "Shift Delay", 0.0, 1.0, "%.2f"],
	[&"auto_upshift_rpm", "Auto upshift", 4000.0, 9000.0, "%.0f"],
	[&"auto_downshift_rpm", "Auto downshift", 1000.0, 5000.0, "%.0f"],
	[&"lsd_preload_nm", "LSD preload Nm", 0.0, 300.0, "%.0f"],
	[&"lsd_power_lock", "LSD power lock", 0.0, 1.0, "%.2f"],
	[&"lsd_coast_lock", "LSD coast lock", 0.0, 1.0, "%.2f"],
	[&"center_front_torque_share", "Center front share", 0.0, 1.0, "%.2f"],
	[&"center_lsd_preload_nm", "Center preload Nm", 0.0, 300.0, "%.0f"],
	[&"center_lsd_power_lock", "Center power lock", 0.0, 1.0, "%.2f"],
	[&"center_lsd_coast_lock", "Center coast lock", 0.0, 1.0, "%.2f"],
]

const ABS_SLIDERS: Array = [
	[&"abs_release_slip", "Release slip", 0.5, 2.0, "%.2f"],
	[&"abs_apply_slip", "Apply slip", 0.3, 1.5, "%.2f"],
	[&"abs_release_rate", "Release rate /s", 5.0, 200.0, "%.0f"],
	[&"abs_apply_rate", "Apply rate /s", 1.0, 60.0, "%.0f"],
	[&"abs_front_pressure_split", "Front L/R split", 0.0, 1.0, "%.2f"],
	[&"abs_min_speed", "Min speed m/s", 0.0, 10.0, "%.1f"],
]

const TCS_SLIDERS: Array = [
	[&"tcs_slip_target", "Slip target", 0.3, 1.5, "%.2f"],
	[&"tcs_cut_rate", "Cut rate /s", 1.0, 30.0, "%.1f"],
	[&"tcs_restore_rate", "Restore rate /s", 0.5, 20.0, "%.1f"],
	[&"tcs_brake_gain", "Brake gain", 0.0, 10000.0, "%.0f"],
	[&"tcs_brake_deadband", "Brake deadband", 0.0, 0.3, "%.2f"],
	[&"tcs_brake_max_nm", "Brake max Nm", 0.0, 1500.0, "%.0f"],
]

const ESC_SLIDERS: Array = [
	[&"esc_understeer_gradient", "Understeer grad", 0.0, 0.02, "%.4f"],
	[&"esc_deadband", "Deadband rad/s", 0.0, 0.3, "%.2f"],
	[&"esc_deadband_fraction", "Deadband frac", 0.0, 1.0, "%.2f"],
	[&"esc_oversteer_gain", "Oversteer gain", 0.0, 10000.0, "%.0f"],
	[&"esc_understeer_gain", "Understeer gain", 0.0, 10000.0, "%.0f"],
	[&"esc_max_brake_nm", "Max brake Nm", 0.0, 3000.0, "%.0f"],
	[&"esc_throttle_cut", "Throttle cut", 0.0, 1.0, "%.2f"],
	[&"esc_min_speed", "Min speed m/s", 0.0, 20.0, "%.1f"],
	[&"esc_reference_lag", "Reference lag s", 0.02, 0.6, "%.2f"],
]

const ASSIST_TOGGLES: Array = [
	&"abs_enabled",
	&"abs_rear_select_low",
	&"tcs_enabled",
	&"esc_enabled",
	&"esc_off_with_handbrake",
]

const HANDBRAKE_SLIDERS: Array = [
	[&"max_handbrake_torque", "Clamp torque Nm", 0.0, 6000.0, "%.0f"],
	[&"handbrake_pull_rate", "Pull rate /s", 1.0, 20.0, "%.1f"],
	[&"handbrake_release_rate", "Release rate /s", 1.0, 20.0, "%.1f"],
]

const HOLD_SLIDERS: Array = [
	[&"stick_speed", "Hold below m/s", 0.02, 0.5, "%.2f"],
	[&"stick_deflection_m", "Stretch at grip m", 0.002, 0.08, "%.3f"],
	[&"stick_damping_ratio", "Damping ratio", 0.1, 2.0, "%.2f"],
]

const FINAL_DRIVE_SLIDER: Array = [&"final_drive_ratio", "Final drive", 2.0, 6.0, "%.2f"]

const CHASSIS_SLIDERS: Array = [
	[&"front_arb_stiffness", "Front ARB", 0.0, 20000.0, "%.0f"],
	[&"rear_arb_stiffness", "Rear ARB", 0.0, 20000.0, "%.0f"],
	[&"brake_bias_front", "Brake bias", 0.3, 0.9, "%.2f"],
	[&"max_brake_torque", "Max brake Nm", 1000.0, 10000.0, "%.0f"],
	[&"drag_coefficient", "Drag Cd", 0.1, 1.0, "%.2f"],
	[&"frontal_area", "Frontal Area", 1.0, 4.0, "%.2f"],
	[&"max_steer_angle_deg", "Max steer deg", 15.0, 45.0, "%.0f"],
	[&"ackermann_factor", "Ackermann", -1.0, 1.0, "%.2f"],
	[&"steer_rate_deg_s", "Steer rate deg/s", 20.0, 300.0, "%.0f"],
	[&"steer_return_multiplier", "Steer return x", 1.0, 4.0, "%.1f"],
	[&"steer_speed_sensitivity", "Speed steering", 0.0, 1.0, "%.2f"],
	[&"steer_slip_allowance", "Steer slip allow", 0.0, 1.5, "%.2f"],
	[&"throttle_ramp_speed", "Throttle ramp", 0.5, 10.0, "%.1f"],
	[&"brake_pedal_rate", "Brake ramp", 0.5, 10.0, "%.1f"],
]

const SUSPENSION_SLIDERS: Array = [
	[&"spring_stiffness", "Spring N/m", 10000.0, 60000.0, "%.0f"],
	[&"damper_stiffness", "Damper", 500.0, 6000.0, "%.0f"],
	[&"suspension_rest_length", "Rest length", 0.1, 0.8, "%.2f"],
	[&"wheel_radius", "Wheel Radius", 0.2, 0.5, "%.2f"],
	[&"wheel_inertia", "Wheel Inertia", 0.5, 5.0, "%.2f"],
]

const BODY_SLIDERS: Array = [[&"mass", "Mass kg", 500.0, 2500.0, "%.0f"]]

var _visible: bool = true
var _locked: bool = true

var _reset_layout: bool = false

var _locked_flag: Array = [true]

var _show_vectors: Array = [true]

var _time_scale: Array = [1.0]

var _ui_scale: float = 1.0
var _ui_scale_edit: Array = [1.0]

var _fps_history: Array = []
var _frame_ms_history: Array = []

var _tire_defaults: Dictionary = { }
var _engine_defaults: Dictionary = { }
var _drivetrain_defaults: Dictionary = { }
var _assists_defaults: Dictionary = { }
var _handbrake_defaults: Dictionary = { }
var _hold_defaults: Dictionary = { }
var _gearing_defaults: Dictionary = { }
var _chassis_defaults: Dictionary = { }
var _suspension_defaults: Dictionary = { }
var _body_defaults: Dictionary = { }

var _smooth_kappa := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

var _smooth_mu_x := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _smooth_alpha := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

var _smooth_mu_y := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

var _smooth_fx_norm := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _smooth_fy_norm := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

var _display: Vector2 = Vector2.ZERO

var _left_w: float = 0.0
var _right_w: float = 0.0

var _top_h: float = 0.0
var _bottom_h: float = 0.0


func _ready() -> void:
	process_priority = 100

	_ui_scale = 1.0
	_ui_scale_edit = [1.0]

	await get_tree().physics_frame
	_snapshot_defaults()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_visible = not _visible


func _process(delta: float) -> void:
	if not enabled or not _visible:
		return

	_sample_performance()
	_update_smoothing(delta / maxf(Engine.time_scale, 0.001))

	ImGui.GetIO().FontGlobalScale = _ui_scale

	DebugDraw3D.enabled = _show_vectors[0]
	Engine.time_scale = _time_scale[0]

	UITheme.push()

	_update_layout()
	_draw_status_window()
	_draw_vehicle_window()
	_draw_performance_window()
	_draw_physics_window()
	_draw_controls_window()

	UITheme.pop()

	_locked = _locked_flag[0]
	_reset_layout = false


func _update_layout() -> void:
	var unit: float = ImGui.GetFontSize()
	_display = ImGui.GetIO().DisplaySize

	_left_w = clampf(_display.x * 0.15, unit * 17.0, unit * 24.0)
	_right_w = clampf(_display.x * 0.20, unit * 22.0, unit * 32.0)

	_top_h = unit * 4.4
	_bottom_h = unit * 7.4


func _center_width() -> float:
	return maxf(_display.x - _left_w - _right_w, 100.0)


func _begin_panel(title: String, rect: Rect2) -> bool:
	var flags: int = 0

	if _locked:
		ImGui.SetNextWindowPos(rect.position, ImGui.Cond_Always)
		ImGui.SetNextWindowSize(rect.size, ImGui.Cond_Always)

		flags = (
			ImGui.WindowFlags_NoMove | ImGui.WindowFlags_NoResize | ImGui.WindowFlags_NoCollapse
			| ImGui.WindowFlags_NoSavedSettings | ImGui.WindowFlags_NoDocking
		)
	else:
		var condition: int = ImGui.Cond_Always if _reset_layout else ImGui.Cond_FirstUseEver
		ImGui.SetNextWindowPos(rect.position, condition)
		ImGui.SetNextWindowSize(rect.size, condition)

	return ImGui.Begin(title, [], flags)


func _draw_status_window() -> void:
	var rect := Rect2(_left_w, 0.0, _center_width(), _top_h)
	if _begin_panel("Settings", rect):
		var unit: float = ImGui.GetFontSize()

		ImGui.Checkbox("Force vectors", _show_vectors)
		ImGui.SameLine()

		ImGui.Checkbox("Layout locked", _locked_flag)
		ImGui.SameLine()

		ImGui.SetNextItemWidth(unit * 7.0)
		ImGui.SliderFloatEx("Time scale", _time_scale, 0.05, 1.0, "%.2f", 0)
		ImGui.SameLine()

		ImGui.SetNextItemWidth(unit * 7.0)
		ImGui.SliderFloatEx("UI scale", _ui_scale_edit, 0.8, 1.2, "%.2f", 0)

		if ImGui.IsItemDeactivatedAfterEdit():
			_ui_scale = _ui_scale_edit[0]

		ImGui.SameLine()
		if ImGui.Button("Reset layout"):
			_reset_layout = true

	ImGui.End()


func _draw_vehicle_window() -> void:
	var rect := Rect2(0.0, 0.0, _left_w, _display.y * 0.54)
	if _begin_panel("Vehicle", rect):
		ImGui.SetWindowFontScale(2.0)
		ImGui.Text("%3.0f" % telemetry.speed_kmh)
		ImGui.SameLine()

		ImGui.SetWindowFontScale(1.0)
		ImGui.TextDisabled("km/h")
		ImGui.SameLine()

		ImGui.SetWindowFontScale(2.0)
		Widgets.right_text(telemetry.gear_name, UITheme.ACCENT)
		ImGui.SetWindowFontScale(1.0)

		var shifting: String = "  shifting" if telemetry.is_shifting else ""
		ImGui.TextDisabled(telemetry.transmission_name + shifting)

		var rpm_fraction: float = telemetry.rpm / maxf(telemetry.rev_limit_rpm, 1.0)
		var rpm_color: Color = UITheme.BAD if rpm_fraction > 0.94 else Color(1.0, 0.75, 0.25)
		Widgets.labeled_bar("RPM", rpm_fraction, "%.0f" % telemetry.rpm, rpm_color)

		Widgets.labeled_bar(
			"THR",
			telemetry.throttle,
			"%.0f%%" % (telemetry.throttle * 100.0),
			UITheme.GOOD,
		)

		Widgets.labeled_bar(
			"BRK",
			telemetry.brake,
			"%.0f%%" % (telemetry.brake * 100.0),
			UITheme.BAD,
		)

		ImGui.SeparatorText("Dynamics")
		Widgets.key_value("Lateral", "%+.2f g" % telemetry.lateral_g)
		Widgets.key_value("Long.", "%+.2f g" % telemetry.longitudinal_g)
		Widgets.key_value(
			"Steering",
			"%+.1f deg (cap %.1f)" % [telemetry.steer_angle_deg, telemetry.steer_cap_deg],
		)

		ImGui.SeparatorText("Powertrain")
		Widgets.key_value("Engine", "%.0f Nm" % telemetry.engine_torque_nm)
		Widgets.key_value("Wheel", "%.0f Nm" % telemetry.wheel_torque_nm)
		Widgets.key_value("Power", "%.1f kW" % telemetry.engine_power_kw)

	ImGui.End()


func _draw_performance_window() -> void:
	var top: float = _display.y * 0.54
	var rect := Rect2(0.0, top, _left_w, _display.y - top)
	if _begin_panel("Performance", rect):
		var fps: float = Engine.get_frames_per_second()
		var fps_color: Color = (
			UITheme.GOOD
			if fps >= 55.0
			else (UITheme.WARN if fps >= 30.0 else UITheme.BAD)
		)

		var unit: float = ImGui.GetFontSize()

		var fps_max: float = _array_max(_fps_history)
		Widgets.line_plot(
			"##fps",
			_fps_history,
			0.0,
			maxf(fps_max * 1.2, 1.0),
			unit * 3.0,
			fps_color,
			"FPS %.0f" % fps,
		)

		var ms_max: float = _array_max(_frame_ms_history)
		Widgets.line_plot(
			"##frame_ms",
			_frame_ms_history,
			0.0,
			maxf(ms_max * 1.2, 1.0),
			unit * 3.0,
			UITheme.ACCENT,
			"Frame %.2f ms" % _frame_ms_history.back(),
		)

		ImGui.SeparatorText("Engine")
		Widgets.key_value(
			"Process",
			"%.2f ms" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0),
		)

		Widgets.key_value(
			"Physics",
			"%.2f ms" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0),
		)

		Widgets.key_value(
			"Draw calls",
			"%d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		)

		Widgets.key_value(
			"Objects",
			"%d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		)

		Widgets.key_value(
			"Memory",
			"%.1f MB" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0),
		)

		Widgets.key_value(
			"VRAM",
			"%.1f MB" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		)

	ImGui.End()


func _draw_physics_window() -> void:
	var rect := Rect2(_display.x - _right_w, 0.0, _right_w, _display.y)
	if _begin_panel("Physics", rect):
		if ImGui.BeginTabBar("physics_tabs"):
			if ImGui.BeginTabItem("Tires"):
				_tab_tires()
				ImGui.EndTabItem()

			if ImGui.BeginTabItem("Engine"):
				_tab_engine()
				ImGui.EndTabItem()

			if vehicle.assists != null and ImGui.BeginTabItem("Assists"):
				_tab_assists()
				ImGui.EndTabItem()

			if ImGui.BeginTabItem("Brakes"):
				_tab_brakes()
				ImGui.EndTabItem()

			if weight_transfer != null and ImGui.BeginTabItem("Load"):
				_tab_load()
				ImGui.EndTabItem()

			if ImGui.BeginTabItem("Body"):
				_tab_body()
				ImGui.EndTabItem()

			ImGui.EndTabBar()

	ImGui.End()


func _draw_controls_window() -> void:
	var rect := Rect2(_left_w, _display.y - _bottom_h, _center_width(), _bottom_h)
	if _begin_panel("Car Controls", rect):
		var unit: float = ImGui.GetFontSize()

		if ImGui.BeginTable("controls_table", 2, ImGui.TableFlags_SizingStretchSame):
			ImGui.TableNextColumn()

			var rpm_fraction: float = telemetry.rpm / maxf(telemetry.rev_limit_rpm, 1.0)
			Widgets.shift_lights(rpm_fraction, SHIFT_LIGHT_COUNT, unit * 1.1)

			Widgets.bar_with_text(
				rpm_fraction,
				"",
				Color(1.0, 0.75, 0.25),
				"RPM: %.0f" % telemetry.rpm,
			)

			Widgets.bar_with_text(
				telemetry.speed_kmh / speed_bar_max_kmh,
				"",
				Color(0.90, 0.70, 0.20),
				"Speed: %.0f km/h" % telemetry.speed_kmh,
			)

			ImGui.TableNextColumn()
			Widgets.bar_with_text(
				telemetry.throttle,
				"",
				UITheme.GOOD,
				"gas: %.0f%%" % (telemetry.throttle * 100.0),
			)

			Widgets.bar_with_text(
				telemetry.brake,
				"",
				UITheme.BAD,
				"brake: %.0f%%" % (telemetry.brake * 100.0),
			)

			Widgets.bar_with_text(
				vehicle.handbrake_input,
				"",
				UITheme.WARN,
				"handbrake: %.0f%%" % (vehicle.handbrake_input * 100.0),
			)

			ImGui.Text("Current gear: %s" % telemetry.gear_name)

			if vehicle.assists != null:
				ImGui.SameLine()
				_assist_lamp("ABS", vehicle.assists_config.abs_enabled, vehicle.assists.abs_active)
				ImGui.SameLine()

				_assist_lamp("TCS", vehicle.assists_config.tcs_enabled, vehicle.assists.tcs_active)
				ImGui.SameLine()

				_assist_lamp("ESC", vehicle.assists_config.esc_enabled, vehicle.assists.esc_active)
				ImGui.SameLine()

				var handbrake_color: Color = UITheme.BAD if vehicle.handbrake_input > 0.05 else UITheme.DIM
				ImGui.TextColored(handbrake_color, "HB")

			ImGui.EndTable()

	ImGui.End()


func _tab_tires() -> void:
	var unit: float = ImGui.GetFontSize()
	var tire: Tire = _selected_tire()

	Widgets.wheel_legend()

	var grounded: Array[bool] = []
	for i in range(4):
		grounded.append(telemetry.wheels[i].grounded)

	var ratio_spec := Widgets.PlotSpec.new()
	ratio_spec.x_extent = 0.5
	ratio_spec.height = unit * 7.0
	ratio_spec.color = UITheme.ACCENT
	ratio_spec.peak_x = tire.kappa_peak()

	Widgets.plot_title("Fx/Fz vs slip ratio")
	Widgets.curve_plot(
		"##ratio_plot",
		func(x: float) -> float:
			return tire.compute_fx(x, tire.reference_load_n) / tire.reference_load_n,
		ratio_spec,
		_smooth_kappa,
		_smooth_mu_x,
		grounded,
	)

	var angle_spec := Widgets.PlotSpec.new()
	angle_spec.x_extent = deg_to_rad(20.0)
	angle_spec.x_display_scale = rad_to_deg(1.0)
	angle_spec.x_format = "%.0f deg"
	angle_spec.height = unit * 7.0
	angle_spec.color = Color(1.0, 0.45, 0.45)
	angle_spec.peak_x = tire.alpha_peak()

	Widgets.gap(0.3)
	Widgets.plot_title("Fy/Fz vs slip angle")
	Widgets.curve_plot(
		"##angle_plot",
		func(x: float) -> float:
			return tire.compute_fy(x, tire.reference_load_n) / tire.reference_load_n,
		angle_spec,
		_smooth_alpha,
		_smooth_mu_y,
		grounded,
	)

	Widgets.gap(0.5)
	_tire_table(tire)

	Widgets.gap(0.8)
	_friction_circles()

	Widgets.gap(0.5)
	if ImGui.CollapsingHeader("Tire model tuning", ImGui.TreeNodeFlags_DefaultOpen):
		_tire_tuning(tire)


func _tire_table(tire: Tire) -> void:
	var flags: int = ImGui.TableFlags_RowBg | ImGui.TableFlags_BordersInnerV | ImGui.TableFlags_SizingStretchProp
	if not ImGui.BeginTable("tire_table", 7, flags):
		return

	ImGui.TableSetupColumn("")
	ImGui.TableSetupColumn("Slip")
	ImGui.TableSetupColumn("Angle")
	ImGui.TableSetupColumn("Fx")
	ImGui.TableSetupColumn("Fy")
	ImGui.TableSetupColumn("Fz")
	ImGui.TableSetupColumn("Grip")

	ImGui.TableHeadersRow()

	var hot := Color(1.0, 0.60, 0.20, 0.18)
	var none := Color(0.0, 0.0, 0.0, 0.0)
	for i in range(4):
		var sample = telemetry.wheels[i]
		var grip: float = Vector2(sample.longitudinal_force_n, sample.lateral_force_n).length() / maxf(
			sample.grip_limit_n,
			1.0,
		)

		var ratio_hot: bool = absf(sample.slip_ratio) > tire.kappa_peak()
		var angle_hot: bool = absf(sample.slip_angle_rad) > tire.alpha_peak()
		var grip_color: Color = UITheme.GOOD
		if grip > 1.0:
			grip_color = UITheme.BAD
		elif grip > 0.85:
			grip_color = UITheme.WARN

		ImGui.TableNextRow()

		Widgets.label_cell(UITheme.WHEEL_NAMES[i], UITheme.WHEEL_COLORS[i])

		Widgets.cell("%+.2f" % sample.slip_ratio, UITheme.TEXT, hot if ratio_hot else none)
		Widgets.cell(
			"%+.1f" % rad_to_deg(sample.slip_angle_rad),
			UITheme.TEXT,
			hot if angle_hot else none,
		)

		Widgets.cell("%+.0f" % sample.longitudinal_force_n)
		Widgets.cell("%+.0f" % sample.lateral_force_n)
		Widgets.cell("%.0f" % sample.normal_load_n)
		Widgets.cell("%.0f%%" % (grip * 100.0), grip_color)

	ImGui.EndTable()


func _friction_circles() -> void:
	var spacing: float = ImGui.GetFontSize() * 0.6
	var diameter: float = minf(
		(ImGui.GetContentRegionAvail().x - spacing * 3.0) / 4.0,
		ImGui.GetFontSize() * 6.0,
	)

	for i in range(4):
		if i > 0:
			ImGui.SameLine()

		Widgets.friction_circle(
			UITheme.WHEEL_NAMES[i],
			UITheme.WHEEL_COLORS[i],
			_smooth_fx_norm[i],
			_smooth_fy_norm[i],
			diameter,
		)


func _tire_tuning(tire: Tire) -> void:
	ImGui.SeparatorText("Longitudinal Pacejka")
	for slider in TIRE_SLIDERS_LONGITUDINAL:
		_tune(tire, slider)

	ImGui.SeparatorText("Lateral Pacejka")
	for slider in TIRE_SLIDERS_LATERAL:
		_tune(tire, slider)

	ImGui.SeparatorText("Load and combined slip")
	for slider in TIRE_SLIDERS_OTHER:
		_tune(tire, slider)

	if Widgets.reset_button("Reset tire to defaults"):
		_reset_tire(tire)


func _tab_engine() -> void:
	var engine: VehicleEngine = vehicle.engine_node
	if engine == null or engine.config == null:
		ImGui.Text("Engine unavailable")
		return

	var unit: float = ImGui.GetFontSize()

	var max_rpm: float = maxf(engine.config.max_rpm, engine.config.rev_limiter_rpm)

	var torque: Array = []
	var power: Array = []

	var torque_peak: float = 1.0
	var power_peak: float = 1.0

	var torque_peak_rpm: float = 0.0
	var power_peak_rpm: float = 0.0
	for i in range(Widgets.CURVE_SAMPLES):
		var rpm: float = float(i) / float(Widgets.CURVE_SAMPLES - 1) * max_rpm

		var t: float = engine.calculate_raw_torque(rpm)
		var p: float = engine.calculate_power_kw(rpm)
		torque.append(t)
		power.append(p)

		if t > torque_peak:
			torque_peak = t
			torque_peak_rpm = rpm
		if p > power_peak:
			power_peak = p
			power_peak_rpm = rpm

	var rpm_cursor: float = telemetry.rpm / max_rpm
	var live_torque: float = engine.calculate_raw_torque(telemetry.rpm)
	var live_power: float = engine.calculate_power_kw(telemetry.rpm)
	var rpm_axis: String = "%.0f rpm" % max_rpm

	Widgets.plot_title("Torque (full throttle)")
	Widgets.line_plot(
		"##torque_plot",
		torque,
		0.0,
		torque_peak * 1.15,
		unit * 6.5,
		UITheme.ACCENT,
		"%.0f Nm @ %.0f rpm" % [torque_peak, torque_peak_rpm],
		rpm_cursor,
		live_torque,
		rpm_axis,
	)

	Widgets.gap(0.3)
	Widgets.plot_title("Power (full throttle)")
	Widgets.line_plot(
		"##power_plot",
		power,
		0.0,
		power_peak * 1.15,
		unit * 6.5,
		Color(1.0, 0.55, 0.25),
		"%.0f kW @ %.0f rpm" % [power_peak, power_peak_rpm],
		rpm_cursor,
		live_power,
		rpm_axis,
	)

	ImGui.SeparatorText("Live")
	Widgets.key_value("RPM", "%.0f / %.0f" % [telemetry.rpm, telemetry.rev_limit_rpm])
	Widgets.key_value("Gear", telemetry.gear_name)
	Widgets.key_value("Transmission", telemetry.transmission_name)
	Widgets.key_value("Output torque", "%.0f Nm" % telemetry.engine_torque_nm)
	Widgets.key_value("Wheel torque", "%.0f Nm" % telemetry.wheel_torque_nm)
	Widgets.key_value("Power", "%.1f kW" % telemetry.engine_power_kw)

	Widgets.gap(0.5)
	var drivetrain: Drivetrain = vehicle.drivetrain_node
	if drivetrain != null and drivetrain.config != null:
		if ImGui.CollapsingHeader("Gearing", ImGui.TreeNodeFlags_DefaultOpen):
			_gearing_section(drivetrain, engine)

	if ImGui.CollapsingHeader("Engine tuning", ImGui.TreeNodeFlags_DefaultOpen):
		for slider in ENGINE_SLIDERS:
			_tune(engine.config, slider)

		if Widgets.reset_button("Reset engine"):
			_reset_object(engine.config, _engine_defaults)

	if drivetrain != null and drivetrain.config != null:
		if ImGui.CollapsingHeader("Drivetrain tuning", ImGui.TreeNodeFlags_DefaultOpen):
			var current_layout: int = _drive_layout()
			var layout: int = _tune_int("Drive layout", "drive_layout", current_layout, 0, 2)
			if layout != current_layout:
				_set_drive_layout(layout)

			Widgets.key_value("Layout", DRIVE_LAYOUT_NAMES[layout])

			var axle_diff: int = _tune_int(
				"Axle differential",
				"diff_type",
				int(drivetrain.config.differential_type),
				0,
				2,
			)
			drivetrain.config.differential_type = axle_diff as DrivetrainConfig.DifferentialType
			Widgets.key_value("Axle type", DIFFERENTIAL_NAMES[axle_diff])

			var center_diff: int = _tune_int(
				"Center differential",
				"center_diff_type",
				int(drivetrain.config.center_differential_type),
				0,
				2,
			)
			drivetrain.config.center_differential_type = center_diff as DrivetrainConfig.DifferentialType
			Widgets.key_value("Center type", DIFFERENTIAL_NAMES[center_diff])

			for slider in DRIVETRAIN_SLIDERS:
				_tune(drivetrain.config, slider)

			if Widgets.reset_button("Reset drivetrain"):
				_reset_object(drivetrain.config, _drivetrain_defaults)

				drivetrain.config.differential_type = _drivetrain_defaults[&"differential_type"]
				drivetrain.config.center_differential_type = _drivetrain_defaults[
					&"center_differential_type"
				]


func _gearing_section(drivetrain: Drivetrain, engine: VehicleEngine) -> void:
	var unit: float = ImGui.GetFontSize()
	var config: DrivetrainConfig = drivetrain.config
	var ratios: Array = Array(config.gear_ratios)

	var wheel_radius: float = vehicle.wheel_fl.suspension_config.wheel_radius
	var rev_limit: float = engine.config.rev_limiter_rpm

	Widgets.plot_title("Gear ratios (RPM vs km/h)")
	Widgets.gear_chart(
		ratios,
		config.final_drive_ratio,
		wheel_radius,
		rev_limit,
		telemetry.speed_kmh,
		telemetry.rpm,
		drivetrain.current_gear_index,
		unit * 11.0,
	)

	Widgets.gap(0.3)
	Widgets.key_value(
		"Top speed",
		"%.0f km/h"
		% Widgets.top_speed_kmh(ratios, config.final_drive_ratio, wheel_radius, rev_limit),
	)

	ImGui.SeparatorText("Ratios")
	_tune(config, FINAL_DRIVE_SLIDER)

	if ratios.size() > 0:
		_tune_gear_ratio(config, 0, "Reverse", -6.0, -1.0)

	for i in range(2, ratios.size()):
		_tune_gear_ratio(config, i, "%s gear" % _ordinal(i - 1), 0.3, 5.0)

	var count_buffer: Array = [maxi(ratios.size() - 2, GEAR_COUNT_MIN)]
	ImGui.SetNextItemWidth(maxf(ImGui.GetContentRegionAvail().x - unit * 11.0, unit * 6.0))
	if ImGui.SliderIntEx(
		"Gear count##gear_count",
		count_buffer,
		GEAR_COUNT_MIN,
		GEAR_COUNT_MAX,
		"%d",
		0,
	):
		_set_forward_gear_count(drivetrain, count_buffer[0])

	if Widgets.reset_button("Reset gearing"):
		_reset_gearing(drivetrain)


func _tune_gear_ratio(
	config: DrivetrainConfig,
	index: int,
	label: String,
	v_min: float,
	v_max: float,
) -> void:
	var buffer: Array = [float(config.gear_ratios[index])]
	if Widgets.slider(label, "gear_%d" % index, buffer, v_min, v_max, "%.3f"):
		config.gear_ratios[index] = buffer[0]


func _set_forward_gear_count(drivetrain: Drivetrain, forward_count: int) -> void:
	var ratios: Array = Array(drivetrain.config.gear_ratios)
	var target: int = forward_count + 2

	while ratios.size() > target:
		ratios.pop_back()

	while ratios.size() < target:
		ratios.append(float(ratios.back()) * 0.82)

	_assign_gear_ratios(drivetrain, ratios)


func _assign_gear_ratios(drivetrain: Drivetrain, ratios: Array) -> void:
	var config: DrivetrainConfig = drivetrain.config

	if typeof(config.gear_ratios) == TYPE_PACKED_FLOAT32_ARRAY:
		config.gear_ratios = PackedFloat32Array(ratios)
	else:
		config.gear_ratios.assign(ratios)

	drivetrain.current_gear_index = mini(drivetrain.current_gear_index, ratios.size() - 1)


func _reset_gearing(drivetrain: Drivetrain) -> void:
	if _gearing_defaults.is_empty():
		return

	_assign_gear_ratios(drivetrain, _gearing_defaults[&"ratios"])
	drivetrain.config.final_drive_ratio = _gearing_defaults[&"final_drive_ratio"]


func _ordinal(number: int) -> String:
	match number:
		1:
			return "1st"
		2:
			return "2nd"
		3:
			return "3rd"
		_:
			return "%dth" % number


func _tab_load() -> void:
	var flags: int = ImGui.TableFlags_RowBg | ImGui.TableFlags_BordersInnerV | ImGui.TableFlags_SizingStretchProp
	if ImGui.BeginTable("load_table", 5, flags):
		ImGui.TableSetupColumn("")
		ImGui.TableSetupColumn("Load N")
		ImGui.TableSetupColumn("Pred N")
		ImGui.TableSetupColumn("Error")
		ImGui.TableSetupColumnEx("Compression", 0, 1.6)

		ImGui.TableHeadersRow()

		var sum_measured: float = 0.0
		var sum_predicted: float = 0.0
		for i in range(4):
			var measured: float = weight_transfer.measured[i]
			var predicted: float = weight_transfer.predicted[i]
			var compression: float = telemetry.wheels[i].compression

			sum_measured += measured
			sum_predicted += predicted

			ImGui.TableNextRow()
			Widgets.label_cell(UITheme.WHEEL_NAMES[i], UITheme.WHEEL_COLORS[i])

			Widgets.cell("%.0f" % measured)
			Widgets.cell("%.0f" % predicted)
			Widgets.cell(
				"%+.0f" % (measured - predicted),
				Widgets.error_color(measured - predicted, measured),
			)

			ImGui.TableNextColumn()
			Widgets.bar(compression, "%.0f%%" % (compression * 100.0), UITheme.ACCENT)

		ImGui.TableNextRow()
		Widgets.label_cell("Sum", UITheme.DIM)

		Widgets.cell("%.0f" % sum_measured)
		Widgets.cell("%.0f" % sum_predicted)
		Widgets.cell(
			"%+.0f" % (sum_measured - sum_predicted),
			Widgets.error_color(sum_measured - sum_predicted, sum_measured),
		)

		ImGui.EndTable()

	var total: float = maxf(_sum(weight_transfer.measured), 1.0)
	var front: float = (weight_transfer.measured[0] + weight_transfer.measured[1]) / total
	var left: float = (weight_transfer.measured[0] + weight_transfer.measured[2]) / total

	ImGui.SeparatorText("Balance")
	Widgets.labeled_bar(
		"F/R",
		front,
		"Front %.1f%%   Rear %.1f%%" % [front * 100.0, (1.0 - front) * 100.0],
		UITheme.ACCENT,
	)

	Widgets.labeled_bar(
		"L/R",
		left,
		"Left %.1f%%   Right %.1f%%" % [left * 100.0, (1.0 - left) * 100.0],
		Color(0.9, 0.7, 0.2),
	)

	ImGui.SeparatorText("Weight transfer")
	Widgets.key_value("Long. accel", "%+.2f g" % (weight_transfer.accel_long / 9.81))
	Widgets.key_value("Lat. accel", "%+.2f g" % (weight_transfer.accel_lat / 9.81))
	Widgets.key_value("Roll measured", "%.2f deg" % absf(weight_transfer.roll_meas_deg))
	Widgets.key_value("Roll predicted", "%.2f deg" % weight_transfer.roll_pred_deg)
	Widgets.key_value("Front roll stiff.", "%.0f%%" % (weight_transfer.front_roll_share * 100.0))
	Widgets.key_value("Lift-off", "%.2f g" % weight_transfer.lift_off_g)

	ImGui.SeparatorText("Geometry")
	Widgets.key_value("CG height", "%.2f m" % weight_transfer.cg_height)
	Widgets.key_value("Wheelbase", "%.2f m" % weight_transfer.wheelbase)
	Widgets.key_value(
		"Track F / R",
		"%.2f / %.2f m" % [weight_transfer.track_front, weight_transfer.track_rear],
	)

	Widgets.gap(0.5)
	if ImGui.CollapsingHeader("Chassis tuning", ImGui.TreeNodeFlags_DefaultOpen):
		for slider in CHASSIS_SLIDERS:
			_tune(vehicle.config, slider)

		if Widgets.reset_button("Reset chassis"):
			_reset_object(vehicle.config, _chassis_defaults)

	if ImGui.CollapsingHeader("Suspension tuning", ImGui.TreeNodeFlags_DefaultOpen):
		for slider in SUSPENSION_SLIDERS:
			_tune(vehicle.wheel_fl.suspension_config, slider)

		if Widgets.reset_button("Reset suspension"):
			_reset_object(vehicle.wheel_fl.suspension_config, _suspension_defaults)


func _tab_body() -> void:
	var position: Vector3 = vehicle.global_position
	var velocity: Vector3 = vehicle.linear_velocity
	var angular: Vector3 = vehicle.angular_velocity

	ImGui.SeparatorText("Rigid body")

	Widgets.key_value("Mass", "%.0f kg" % vehicle.mass)
	Widgets.key_value(
		"COM",
		"%.2f  %.2f  %.2f"
		% [vehicle.center_of_mass.x, vehicle.center_of_mass.y, vehicle.center_of_mass.z],
	)

	Widgets.key_value("Position", "%.1f  %.1f  %.1f" % [position.x, position.y, position.z])
	Widgets.key_value("Velocity", "%.1f  %.1f  %.1f" % [velocity.x, velocity.y, velocity.z])
	Widgets.key_value("Ang. velocity", "%.2f  %.2f  %.2f" % [angular.x, angular.y, angular.z])

	ImGui.SeparatorText("Orientation")

	var basis: Basis = vehicle.global_transform.basis.orthonormalized()
	Widgets.key_value("Roll", "%.1f deg" % rad_to_deg(asin(clampf(basis.x.y, -1.0, 1.0))))
	Widgets.key_value("Pitch", "%.1f deg" % rad_to_deg(asin(clampf(-basis.z.y, -1.0, 1.0))))
	Widgets.key_value("Heading", "%.1f deg" % rad_to_deg(atan2(-basis.z.x, -basis.z.z)))

	Widgets.gap(0.5)
	if ImGui.CollapsingHeader("Body tuning", ImGui.TreeNodeFlags_DefaultOpen):
		for slider in BODY_SLIDERS:
			_tune(vehicle, slider)

		var com_x: Array = [vehicle.center_of_mass.x]
		if Widgets.slider("COM X", "com_x", com_x, -0.5, 0.5, "%.2f"):
			vehicle.center_of_mass.x = com_x[0]

		var com_y: Array = [vehicle.center_of_mass.y]
		if Widgets.slider("COM Y", "com_y", com_y, 0.1, 1.0, "%.2f"):
			vehicle.center_of_mass.y = com_y[0]

		var com_z: Array = [vehicle.center_of_mass.z]
		if Widgets.slider("COM Z", "com_z", com_z, -2.0, 2.0, "%.2f"):
			vehicle.center_of_mass.z = com_z[0]

		if Widgets.reset_button("Reset body"):
			vehicle.mass = _body_defaults[&"mass"]
			vehicle.center_of_mass = Vector3(
				_body_defaults[&"com_x"],
				_body_defaults[&"com_y"],
				_body_defaults[&"com_z"],
			)


func _update_smoothing(delta: float) -> void:
	var blend: float = 1.0 - exp(-marker_smoothing * delta)
	for i in range(4):
		var sample = telemetry.wheels[i]
		var load_n: float = maxf(sample.normal_load_n, 1.0)
		var grip: float = maxf(sample.grip_limit_n, 1.0)

		_smooth_kappa[i] = lerpf(_smooth_kappa[i], sample.slip_ratio, blend)
		_smooth_alpha[i] = lerpf(_smooth_alpha[i], sample.slip_angle_rad, blend)

		_smooth_mu_x[i] = lerpf(_smooth_mu_x[i], sample.longitudinal_force_n / load_n, blend)
		_smooth_mu_y[i] = lerpf(_smooth_mu_y[i], sample.lateral_force_n / load_n, blend)

		_smooth_fx_norm[i] = lerpf(_smooth_fx_norm[i], sample.longitudinal_force_n / grip, blend)
		_smooth_fy_norm[i] = lerpf(_smooth_fy_norm[i], sample.lateral_force_n / grip, blend)


func _wheel_nodes() -> Array[Wheel]:
	return [vehicle.wheel_fl, vehicle.wheel_fr, vehicle.wheel_rl, vehicle.wheel_rr]


func _selected_tire() -> Tire:
	return vehicle.wheel_fl.tire_model


func _snapshot_defaults() -> void:
	for wheel in _wheel_nodes():
		var tire: Tire = wheel.tire_model
		if _tire_defaults.has(tire):
			continue

		var values: Dictionary = { }
		for group in [TIRE_SLIDERS_LONGITUDINAL, TIRE_SLIDERS_LATERAL, TIRE_SLIDERS_OTHER]:
			for slider in group:
				values[slider[0]] = tire.get(slider[0])

		_tire_defaults[tire] = values

	var engine: VehicleEngine = vehicle.engine_node
	if engine != null and engine.config != null:
		for slider in ENGINE_SLIDERS:
			_engine_defaults[slider[0]] = engine.config.get(slider[0])

	if vehicle.drivetrain_node != null and vehicle.drivetrain_node.config != null:
		var drivetrain_config: DrivetrainConfig = vehicle.drivetrain_node.config
		for slider in DRIVETRAIN_SLIDERS:
			_drivetrain_defaults[slider[0]] = drivetrain_config.get(slider[0])

		_drivetrain_defaults[&"differential_type"] = drivetrain_config.differential_type
		_drivetrain_defaults[&"center_differential_type"] = drivetrain_config.center_differential_type

		_gearing_defaults[&"ratios"] = Array(drivetrain_config.gear_ratios).duplicate()
		_gearing_defaults[&"final_drive_ratio"] = drivetrain_config.final_drive_ratio

	if vehicle.assists_config != null:
		for group in [ABS_SLIDERS, TCS_SLIDERS, ESC_SLIDERS]:
			for slider in group:
				_assists_defaults[slider[0]] = vehicle.assists_config.get(slider[0])

		for toggle in ASSIST_TOGGLES:
			_assists_defaults[toggle] = vehicle.assists_config.get(toggle)

	if vehicle.config != null:
		for slider in CHASSIS_SLIDERS:
			_chassis_defaults[slider[0]] = vehicle.config.get(slider[0])

		for slider in HANDBRAKE_SLIDERS:
			_handbrake_defaults[slider[0]] = vehicle.config.get(slider[0])

	var hold_tire: Tire = _selected_tire()
	if hold_tire != null:
		for slider in HOLD_SLIDERS:
			_hold_defaults[slider[0]] = hold_tire.get(slider[0])

	var susp: SuspensionConfig = vehicle.wheel_fl.suspension_config
	if susp != null:
		for slider in SUSPENSION_SLIDERS:
			_suspension_defaults[slider[0]] = susp.get(slider[0])

	_body_defaults[&"mass"] = vehicle.mass
	_body_defaults[&"com_x"] = vehicle.center_of_mass.x
	_body_defaults[&"com_y"] = vehicle.center_of_mass.y
	_body_defaults[&"com_z"] = vehicle.center_of_mass.z


func _reset_object(obj: Object, defaults: Dictionary) -> void:
	if not defaults.size() > 0:
		return

	for property in defaults:
		obj.set(property, defaults[property])


func _reset_tire(tire: Tire) -> void:
	if not _tire_defaults.has(tire):
		return

	_reset_object(tire, _tire_defaults[tire])


func _sample_performance() -> void:
	_fps_history.append(Engine.get_frames_per_second())
	_frame_ms_history.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)

	while _fps_history.size() > HISTORY_LENGTH:
		_fps_history.pop_front()

	while _frame_ms_history.size() > HISTORY_LENGTH:
		_frame_ms_history.pop_front()


func _array_max(values: Array) -> float:
	var result: float = 0.0
	for value in values:
		result = maxf(result, value)

	return result


func _sum(values: PackedFloat32Array) -> float:
	var total: float = 0.0
	for value in values:
		total += value

	return total


func _tab_assists() -> void:
	var config: AssistsConfig = vehicle.assists_config
	var assists: Assists = vehicle.assists

	if ImGui.CollapsingHeader("ABS", ImGui.TreeNodeFlags_DefaultOpen):
		_tune_toggle(config, &"abs_enabled", "ABS enabled")
		_tune_toggle(config, &"abs_rear_select_low", "Rear select-low")
		Widgets.key_value(
			"Status",
			_assist_state(config.abs_enabled, assists.abs_active),
			UITheme.WARN if assists.abs_active else UITheme.TEXT,
		)

		for i in range(4):
			var wheel: Wheel = _wheel_nodes()[i]
			var pressure: float = assists.abs_pressure[wheel]
			Widgets.labeled_bar(
				UITheme.WHEEL_NAMES[i],
				pressure,
				"%.0f%%" % (pressure * 100.0),
				UITheme.WHEEL_COLORS[i],
			)

		Widgets.gap(0.3)
		for slider in ABS_SLIDERS:
			_tune(config, slider)

	if ImGui.CollapsingHeader("Traction control", ImGui.TreeNodeFlags_DefaultOpen):
		_tune_toggle(config, &"tcs_enabled", "Traction control enabled")
		Widgets.key_value(
			"Status",
			_assist_state(config.tcs_enabled, assists.tcs_active),
			UITheme.WARN if assists.tcs_active else UITheme.TEXT,
		)
		Widgets.bar_with_text(
			assists.throttle_scale,
			"",
			UITheme.GOOD,
			"power: %.0f%%" % (assists.throttle_scale * 100.0),
		)

		for slider in TCS_SLIDERS:
			_tune(config, slider)

	if ImGui.CollapsingHeader("Stability control", ImGui.TreeNodeFlags_DefaultOpen):
		_tune_toggle(config, &"esc_enabled", "Stability control enabled")
		_tune_toggle(config, &"esc_off_with_handbrake", "Off while handbrake is up")
		Widgets.key_value(
			"Status",
			_assist_state(config.esc_enabled, assists.esc_active),
			UITheme.WARN if assists.esc_active else UITheme.TEXT,
		)
		Widgets.key_value("Target yaw", "%.1f deg/s" % rad_to_deg(assists.yaw_rate_target))
		Widgets.key_value(
			"Yaw error",
			"%.1f deg/s" % rad_to_deg(assists.yaw_rate_error),
			UITheme.WARN if absf(assists.yaw_rate_error) > config.esc_deadband else UITheme.TEXT,
		)

		for slider in ESC_SLIDERS:
			_tune(config, slider)

	if Widgets.reset_button("Reset assists"):
		_reset_object(config, _assists_defaults)


func _tab_brakes() -> void:
	var config: ChassisConfig = vehicle.config
	var wheels: Array[Wheel] = _wheel_nodes()

	ImGui.SeparatorText("Handbrake")
	Widgets.bar_with_text(
		vehicle.handbrake_input,
		"",
		UITheme.WARN,
		"lever: %.0f%%" % (vehicle.handbrake_input * 100.0),
	)

	var latched: Array = [vehicle.handbrake_latched]
	if ImGui.Checkbox("Keep lever up (parking brake)##handbrake_latched", latched):
		vehicle.handbrake_latched = latched[0]

	Widgets.key_value(
		"Clamp torque",
		"%.0f Nm" % (vehicle.handbrake_input * config.max_handbrake_torque),
	)

	var esc_stepped_aside: bool = (
		vehicle.assists_config.esc_off_with_handbrake and vehicle.handbrake_input > 0.05
	)
	Widgets.key_value(
		"Stability control",
		"stepped aside" if esc_stepped_aside else "normal",
		UITheme.WARN if esc_stepped_aside else UITheme.TEXT,
	)

	Widgets.gap(0.3)
	var flags: int = ImGui.TableFlags_RowBg | ImGui.TableFlags_BordersInnerV | ImGui.TableFlags_SizingStretchProp
	if ImGui.BeginTable("brake_table", 5, flags):
		ImGui.TableSetupColumn("")
		ImGui.TableSetupColumn("HB Nm")
		ImGui.TableSetupColumn("rad/s")
		ImGui.TableSetupColumn("State")
		ImGui.TableSetupColumnEx("Grip used", 0, 1.3)

		ImGui.TableHeadersRow()

		for i in range(4):
			var wheel: Wheel = wheels[i]

			var state: String = "free"
			var state_color: Color = UITheme.DIM
			if wheel.is_stuck:
				state = "HOLD"
				state_color = UITheme.GOOD
			elif wheel.is_locked:
				state = "LOCK"
				state_color = UITheme.BAD

			var peak_n: float = wheel.tire_model.peak_longitudinal_force_n(
				wheel.normal_load_n,
				wheel.friction_coef,
			)
			var grip_used: float = absf(wheel.longitudinal_force_n) / maxf(peak_n, 1.0)

			ImGui.TableNextRow()
			Widgets.label_cell(UITheme.WHEEL_NAMES[i], UITheme.WHEEL_COLORS[i])

			Widgets.cell("%.0f" % vehicle.get_handbrake_torque_nm(wheel))
			Widgets.cell("%.1f" % wheel.angular_velocity_rad_s)
			Widgets.cell(state, state_color)

			ImGui.TableNextColumn()
			Widgets.bar(grip_used, "%.0f%%" % (grip_used * 100.0), state_color)

		ImGui.EndTable()

	ImGui.SeparatorText("Slope hold")

	var normal_sum: Vector3 = Vector3.ZERO
	var holding: int = 0
	var hold_capacity_n: float = 0.0
	for wheel in wheels:
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
		hold_capacity_n += minf(grip_n, brake_nm / wheel.suspension_config.wheel_radius)

	var slope_rad: float = 0.0
	if normal_sum.length() > 0.001:
		slope_rad = acos(clampf(normal_sum.normalized().dot(Vector3.UP), -1.0, 1.0))

	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var pull_n: float = vehicle.mass * gravity * vehicle.gravity_scale * sin(slope_rad)

	Widgets.key_value(
		"Slope",
		"%.1f deg  (%.0f%% grade)" % [rad_to_deg(slope_rad), tan(slope_rad) * 100.0],
	)
	Widgets.key_value("Pull down slope", "%.0f N" % pull_n)

	var hold_used: float = pull_n / maxf(hold_capacity_n, 1.0)
	Widgets.labeled_bar(
		"Hold",
		hold_used,
		"%.0f N of %.0f N" % [pull_n, hold_capacity_n],
		UITheme.GOOD if hold_used < 1.0 else UITheme.BAD,
	)

	Widgets.key_value(
		"Wheels holding",
		"%d of 4" % holding,
		UITheme.GOOD if holding > 0 else UITheme.TEXT,
	)

	var speed: float = vehicle.linear_velocity.length()
	Widgets.key_value(
		"Speed",
		"%.1f cm/s" % (speed * 100.0) if speed < 0.5 else "%.1f m/s" % speed,
		UITheme.WARN if (speed > 0.01 and speed < 0.5 and holding == 0 and pull_n > 0.0) else UITheme.TEXT,
	)

	Widgets.gap(0.5)
	if ImGui.CollapsingHeader("Handbrake tuning", ImGui.TreeNodeFlags_DefaultOpen):
		for slider in HANDBRAKE_SLIDERS:
			_tune(config, slider)

		if Widgets.reset_button("Reset handbrake"):
			_reset_object(config, _handbrake_defaults)

	if ImGui.CollapsingHeader("Static hold tuning", ImGui.TreeNodeFlags_DefaultOpen):
		var tire: Tire = _selected_tire()
		for slider in HOLD_SLIDERS:
			_tune(tire, slider)

		if Widgets.reset_button("Reset hold"):
			_reset_object(tire, _hold_defaults)


func _assist_state(assist_enabled: bool, active: bool) -> String:
	if not assist_enabled:
		return "OFF"

	return "ACTIVE" if active else "ready"


func _assist_lamp(label: String, assist_enabled: bool, active: bool) -> void:
	var color: Color = UITheme.DIM
	if assist_enabled:
		color = UITheme.WARN if active else UITheme.GOOD

	ImGui.TextColored(color, label)


func _tune_toggle(obj: Object, property: StringName, label: String) -> void:
	var buffer: Array = [obj.get(property)]
	if ImGui.Checkbox("%s##%s" % [label, property], buffer):
		obj.set(property, buffer[0])


func _tune_int(label: String, id: String, value: int, v_min: int, v_max: int) -> int:
	var buffer: Array = [value]
	var unit: float = ImGui.GetFontSize()

	ImGui.SetNextItemWidth(maxf(ImGui.GetContentRegionAvail().x - unit * 11.0, unit * 6.0))
	ImGui.SliderIntEx("%s##%s" % [label, id], buffer, v_min, v_max, "%d", 0)

	return buffer[0]


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


func _tune(obj: Object, slider: Array) -> void:
	var buffer: Array = [float(obj.get(slider[0]))]

	if Widgets.slider(slider[1], str(slider[0]), buffer, slider[2], slider[3], slider[4]):
		obj.set(slider[0], buffer[0])
