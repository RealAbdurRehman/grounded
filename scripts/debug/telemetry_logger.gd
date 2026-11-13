class_name TelemetryLogger
extends Node

@export var telemetry: Telemetry

@export var is_logging: bool = false
@export var sample_interval: float = 1 / 120.0

var _file: FileAccess
var _timer: float = 0.0
var _elapsed_time: float = 0.0


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_logging"):
		toggle_logging()
		get_viewport().set_input_as_handled()


func toggle_logging() -> void:
	if is_logging:
		stop_logging()
	else:
		start_logging()


func start_logging() -> void:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "user://telemetry_%s.csv" % timestamp
	_file = FileAccess.open(path, FileAccess.WRITE)

	if _file == null:
		push_error("Failed to open telemetry file: " + ProjectSettings.globalize_path(path))
		return

	is_logging = true
	_timer = 0.0
	_elapsed_time = 0.0

	_file.store_line(
		"time,speed_kmh,rpm,gear,fl_sr,fl_sa,fl_fx,fl_fy,fl_fz,fr_sr,fr_sa,fr_fx,fr_fy,fr_fz,rl_sr,rl_sa,rl_fx,rl_fy,rl_fz,rr_sr,rr_sa,rr_fx,rr_fy,rr_fz,steer_deg,fl_steer_deg,fr_steer_deg"
	)
	print("[TelemetryLogger] Started: ", ProjectSettings.globalize_path(path))


func stop_logging() -> void:
	if is_logging and _file:
		_file.close()
		_file = null

		is_logging = false
		print("[TelemetryLogger] Logging stopped.")


func _physics_process(delta: float) -> void:
	if not is_logging or not _file:
		return

	_timer += delta
	_elapsed_time += delta

	if _timer >= sample_interval:
		_timer = 0.0
		_record_sample()


func _record_sample() -> void:
	var v: Vehicle = telemetry.vehicle

	var speed_kmh: float = v.linear_velocity.length() * 3.6
	var rpm: float = v.engine_node.current_rpm if v.engine_node else 0.0
	var gear: String = v.drivetrain_node.get_gear_name() if v.drivetrain_node else "?"

	var wheels: Array[Wheel] = [v.wheel_fl, v.wheel_fr, v.wheel_rl, v.wheel_rr]
	var parts: PackedStringArray = PackedStringArray()
	parts.append("%8.3f,%6.2f,%5.0f,%s" % [_elapsed_time, speed_kmh, rpm, gear])

	for w in wheels:
		parts.append(
			",%+6.2f,%+6.2f,%+8.1f,%+8.1f,%+8.1f"
			% [
				w.slip_ratio,
				rad_to_deg(w.slip_angle_rad),
				w.longitudinal_force_n,
				w.lateral_force_n,
				w.normal_load_n,
			]
		)

	parts.append(
		",%+6.2f,%+6.2f,%+6.2f"
		% [
			rad_to_deg(v.steer_angle_rad),
			rad_to_deg(v.wheel_fl.steer_angle_rad),
			rad_to_deg(v.wheel_fr.steer_angle_rad),
		]
	)

	_file.store_line("".join(parts))

	_file.store_line("".join(parts))
