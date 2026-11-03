class_name TelemetryLogger
extends Node

@export var target_vehicle: RigidBody3D

@export var is_logging: bool = false
@export var sample_interval: float = 0.0166

var _file: FileAccess
var _timer: float = 0.0
var _elapsed_time: float = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1: toggle_logging()

func toggle_logging() -> void:
	if is_logging: stop_logging()
	else: start_logging()

func start_logging() -> void:
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = "user://telemetry_%s.csv" % timestamp
	_file = FileAccess.open(path, FileAccess.WRITE)

	if _file:
		is_logging = true
		_elapsed_time = 0.0

		_file.store_line("time,speed_kmh,accel_long,accel_lat,fl_fz,fr_fz,rl_fz,rr_fz")
		print("[TelemetryLogger] Started logging to: ", OS.get_user_data_dir() + "/" + path)
	else:
		push_error("Failed to open telemetry file.")

func stop_logging() -> void:
	if is_logging and _file:
		_file.close()
		_file = null
		
		is_logging = false
		print("[TelemetryLogger] Logging stopped.")

func _physics_process(delta: float) -> void:
	if not is_logging or not target_vehicle or not _file: return

	_timer += delta
	_elapsed_time += delta

	if _timer >= sample_interval:
		_timer = 0.0
		_record_sample()

func _record_sample() -> void:
	var vel: Vector3 = target_vehicle.linear_velocity
	var speed_kmh: float = vel.length() * 3.6
	
	var line: String = "%8.3f,%6.2f,%6.2f,%6.2f,%6.1f,%6.1f,%6.1f,%6.1f" % [
		_elapsed_time,
		speed_kmh,
		0.0, 0.0,
		0.0, 0.0, 0.0, 0.0
	]

	_file.store_line(line)
