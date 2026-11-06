class_name EngineDebug
extends Control

@export var engine_node: VehicleEngine
@export var drivetrain_node: Drivetrain
@export var target_vehicle: RigidBody3D

var graph_rect: Rect2 = Rect2(20, 20, 300, 180)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(graph_rect, Color(0.08, 0.09, 0.12, 0.88))
	draw_rect(graph_rect, Color(0.3, 0.35, 0.45, 1.0), false, 1.5)

	for rpm_step in range(1000, int(engine_node.max_rpm), 1000):
		var x: float = graph_rect.position.x + (float(rpm_step) / engine_node.max_rpm) * graph_rect.size.x
		draw_line(Vector2(x, graph_rect.position.y), Vector2(x, graph_rect.end.y), Color(0.2, 0.22, 0.28, 0.5), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(x - 12, graph_rect.end.y - 4), str(rpm_step / 1000.0) + "k", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.6, 0.65, 0.7))

	var max_torque_display: float = 450.0
	var max_power_display: float = 250.0
	
	var current_ratio: float = abs(drivetrain_node.gear_ratios[drivetrain_node.current_gear_index]) * drivetrain_node.final_drive_ratio
	if current_ratio == 0.0: current_ratio = 1.0 
	var max_wheel_torque_display: float = max_torque_display * current_ratio * drivetrain_node.drivetrain_efficiency

	var prev_torque_pos := Vector2.ZERO
	var prev_power_pos := Vector2.ZERO
	var prev_wheel_pos := Vector2.ZERO

	for i in range(100):
		var rpm: float = (float(i) / 99.0) * engine_node.max_rpm
		var t_nm: float = engine_node.calculate_raw_torque(rpm)
		var p_kw: float = engine_node.calculate_power_kw(rpm)
		var wheel_t_nm: float = t_nm * current_ratio * drivetrain_node.drivetrain_efficiency

		var px: float = graph_rect.position.x + (rpm / engine_node.max_rpm) * graph_rect.size.x
		
		var py_t: float = graph_rect.end.y - clamp(t_nm / max_torque_display, 0.0, 1.0) * (graph_rect.size.y - 25.0) - 15.0
		var py_p: float = graph_rect.end.y - clamp(p_kw / max_power_display, 0.0, 1.0) * (graph_rect.size.y - 25.0) - 15.0
		var py_w: float = graph_rect.end.y - clamp(wheel_t_nm / max_wheel_torque_display, 0.0, 1.0) * (graph_rect.size.y - 25.0) - 15.0

		var cur_torque_pos := Vector2(px, py_t)
		var cur_power_pos := Vector2(px, py_p)
		var cur_wheel_pos := Vector2(px, py_w)

		if i > 0:
			draw_line(prev_wheel_pos, cur_wheel_pos, Color(0.2, 1.0, 0.4), 1.5) 
			draw_line(prev_power_pos, cur_power_pos, Color(1.0, 0.45, 0.2), 2.0)  
			draw_line(prev_torque_pos, cur_torque_pos, Color(0.2, 0.7, 1.0), 3.0) 

		prev_torque_pos = cur_torque_pos
		prev_power_pos = cur_power_pos
		prev_wheel_pos = cur_wheel_pos

	var live_x: float = graph_rect.position.x + (engine_node.current_rpm / engine_node.max_rpm) * graph_rect.size.x
	draw_line(Vector2(live_x, graph_rect.position.y), Vector2(live_x, graph_rect.end.y), Color.YELLOW, 2.0)

	var speed_kmh: float = target_vehicle.linear_velocity.length() * 3.6 if target_vehicle else 0.0
	var mode_str: String = "AUTO" if drivetrain_node.transmission_type == Drivetrain.TransmissionType.AUTOMATIC else "MANUAL"
	var shift_indicator: String = " [SHIFTING]" if drivetrain_node.is_shifting else ""

	var readout := "RPM: %4.0f / %4.0f\nGear: %s (%s)%s\nSpeed: %4.1f km/h\nTorque: %3.0f Nm | Power: %3.0f kW" % [
		engine_node.current_rpm, engine_node.rev_limiter_rpm,
		drivetrain_node.get_gear_name(), mode_str, shift_indicator,
		speed_kmh,
		engine_node.output_torque_nm, engine_node.calculate_power_kw(engine_node.current_rpm)
	]

	draw_multiline_string(
		ThemeDB.fallback_font, 
		Vector2(graph_rect.position.x + 10, graph_rect.end.y + 20), 
		readout, 
		HORIZONTAL_ALIGNMENT_LEFT, 
		-1, 
		14, 
		4, 
		Color.WHITE
	)

	draw_string(ThemeDB.fallback_font, Vector2(graph_rect.position.x + 10, graph_rect.position.y + 20), "Engine Torque (Nm)", HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, Color(0.2, 0.7, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(graph_rect.position.x + 10, graph_rect.position.y + 35), "Power (kW)", HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, Color(1.0, 0.45, 0.2))
	draw_string(ThemeDB.fallback_font, Vector2(graph_rect.position.x + 10, graph_rect.position.y + 50), "Wheel Torque (Gear)", HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, Color(0.2, 1.0, 0.4))
