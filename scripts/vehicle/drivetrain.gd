class_name Drivetrain
extends Node

enum TransmissionType { MANUAL_SEQUENTIAL, AUTOMATIC }

@export_group("Transmission")
@export var transmission_type: TransmissionType = TransmissionType.AUTOMATIC
@export var drivetrain_efficiency: float = 0.85

@export_group("Gear Ratios")
@export var gear_ratios: Array[float] = [-3.40, 0.0, 3.40, 2.05, 1.38, 1.03, 0.82]
@export var final_drive_ratio: float = 3.90

@export_group("Shifting")
@export var shift_delay_seconds: float = 0.12
@export var auto_upshift_rpm: float = 5800.0
@export var auto_downshift_rpm: float = 2200.0

var is_shifting: bool = false

var current_gear_index: int = 2

var _shift_timer: float = 0.0

var _shift_cooldown: float = 0.0 

func _process(delta: float) -> void:
	if is_shifting:
		_shift_timer -= delta

		if _shift_timer <= 0.0:
			is_shifting = false
			_shift_cooldown = 0.3 
	elif _shift_cooldown > 0.0: _shift_cooldown -= delta

func get_current_ratio() -> float:
	if is_shifting: return 0.0
	return gear_ratios[current_gear_index]

func is_clutch_engaged() -> bool:
	return (not is_shifting) and (gear_ratios[current_gear_index] != 0.0)

func get_gear_name() -> String:
	match current_gear_index:
		0: return "R"
		1: return "N"
		_: return str(current_gear_index - 1)

func calculate_wheel_drive_torque(engine_torque: float) -> float:
	if is_shifting or gear_ratios[current_gear_index] == 0.0: return 0.0
	
	var total_ratio: float = gear_ratios[current_gear_index] * final_drive_ratio
	return engine_torque * total_ratio * drivetrain_efficiency

func calculate_target_engine_rpm(driven_wheel_rad_per_sec: float) -> float:
	var ratio: float = abs(gear_ratios[current_gear_index]) * final_drive_ratio
	var engine_rad_s: float = abs(driven_wheel_rad_per_sec) * ratio
	return (engine_rad_s * 60.0) / (2.0 * PI)

func handle_transmission(engine_rpm: float) -> void:
	if is_shifting or _shift_cooldown > 0.0: return

	if Input.is_action_just_pressed("toggle_transmission"):
		transmission_type = TransmissionType.MANUAL_SEQUENTIAL if transmission_type == TransmissionType.AUTOMATIC else TransmissionType.AUTOMATIC

	if transmission_type == TransmissionType.MANUAL_SEQUENTIAL:
		if Input.is_action_just_pressed("gear_up"): shift_up()
		elif Input.is_action_just_pressed("gear_down"): shift_down()
	else: _handle_automatic_shifting(engine_rpm)

func _handle_automatic_shifting(engine_rpm: float) -> void:
	if current_gear_index >= 2 and current_gear_index < gear_ratios.size() - 1:
		if engine_rpm >= auto_upshift_rpm:
			shift_up()
			return

	if current_gear_index > 2:
		if engine_rpm <= auto_downshift_rpm: shift_down()

func _start_shift() -> void:
	is_shifting = true
	_shift_timer = shift_delay_seconds

func shift_up() -> void:
	if current_gear_index < gear_ratios.size() - 1:
		current_gear_index += 1
		_start_shift()

func shift_down() -> void:
	if current_gear_index > 0:
		current_gear_index -= 1
		_start_shift()
