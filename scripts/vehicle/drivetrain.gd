class_name Drivetrain
extends Node

enum TransmissionType {
	MANUAL_SEQUENTIAL,
	AUTOMATIC,
}

@export var config: DrivetrainConfig

@export var transmission_type: TransmissionType = TransmissionType.MANUAL_SEQUENTIAL

var is_shifting: bool = false

var current_gear_index: int = 2

var _shift_timer: float = 0.0

var _shift_cooldown: float = 0.0

var _forward_speed: float = 0.0


func _process(delta: float) -> void:
	if is_shifting:
		_shift_timer -= delta

		if _shift_timer <= 0.0:
			is_shifting = false
			_shift_cooldown = 0.3
	elif _shift_cooldown > 0.0:
		_shift_cooldown -= delta


func get_current_ratio() -> float:
	if is_shifting:
		return 0.0
	return config.gear_ratios[current_gear_index]


func is_clutch_engaged() -> bool:
	return (not is_shifting) and (config.gear_ratios[current_gear_index] != 0.0)


func get_gear_name() -> String:
	match current_gear_index:
		0:
			return "R"
		1:
			return "N"
		_:
			return str(current_gear_index - 1)


func calculate_wheel_drive_torque(engine_torque: float) -> float:
	if is_shifting or config.gear_ratios[current_gear_index] == 0.0:
		return 0.0

	var total_ratio: float = config.gear_ratios[current_gear_index] * config.final_drive_ratio
	return engine_torque * total_ratio * config.drivetrain_efficiency


func calculate_target_engine_rpm(driven_wheel_rad_per_sec: float) -> float:
	var ratio: float = abs(config.gear_ratios[current_gear_index]) * config.final_drive_ratio
	var engine_rad_s: float = abs(driven_wheel_rad_per_sec) * ratio

	return (engine_rad_s * 60.0) / (2.0 * PI)


func handle_transmission(engine_rpm: float, forward_speed: float, wheel_rad_s: float) -> void:
	_forward_speed = forward_speed

	if is_shifting or _shift_cooldown > 0.0:
		return

	if Input.is_action_just_pressed("toggle_transmission"):
		transmission_type = TransmissionType.MANUAL_SEQUENTIAL if transmission_type == TransmissionType.AUTOMATIC else TransmissionType.AUTOMATIC

	if transmission_type == TransmissionType.MANUAL_SEQUENTIAL:
		if Input.is_action_just_pressed("gear_up"):
			shift_up()
		elif Input.is_action_just_pressed("gear_down"):
			shift_down()
	else:
		if _handle_selector(wheel_rad_s):
			return
		_handle_automatic_shifting(engine_rpm)


func _gear_allowed(target_index: int) -> bool:
	var ratio: float = config.gear_ratios[target_index]
	if ratio < 0.0 and _forward_speed > config.selector_max_speed:
		return false
	if ratio > 0.0 and _forward_speed < -config.selector_max_speed:
		return false

	return true


func _handle_selector(wheel_rad_s: float) -> bool:
	var up: bool = Input.is_action_just_pressed("gear_up")
	var down: bool = Input.is_action_just_pressed("gear_down")
	if not (up or down):
		return false

	if down:
		if current_gear_index >= 2:
			current_gear_index = 1
			_start_shift()
		elif current_gear_index == 1 and _gear_allowed(0):
			current_gear_index = 0
			_start_shift()
	else:
		if current_gear_index == 0:
			current_gear_index = 1
			_start_shift()
		elif current_gear_index == 1 and _gear_allowed(2):
			current_gear_index = _pick_drive_gear(wheel_rad_s)
			_start_shift()

	return true


func _pick_drive_gear(wheel_rad_s: float) -> int:
	for i in range(2, config.gear_ratios.size()):
		var rpm: float = abs(wheel_rad_s) * config.gear_ratios[i] * config.final_drive_ratio * 60.0 / (
			2.0 * PI
		)
		if rpm <= config.auto_upshift_rpm:
			return i

	return config.gear_ratios.size() - 1


func _handle_automatic_shifting(engine_rpm: float) -> void:
	if current_gear_index >= 2 and current_gear_index < config.gear_ratios.size() - 1:
		if engine_rpm >= config.auto_upshift_rpm:
			shift_up()
			return

	if current_gear_index > 2:
		if engine_rpm <= config.auto_downshift_rpm:
			shift_down()


func _start_shift() -> void:
	is_shifting = true
	_shift_timer = config.shift_delay_seconds


func shift_up() -> void:
	if current_gear_index < config.gear_ratios.size() - 1 and _gear_allowed(current_gear_index + 1):
		current_gear_index += 1
		_start_shift()


func shift_down() -> void:
	if current_gear_index > 0 and _gear_allowed(current_gear_index - 1):
		current_gear_index -= 1
		_start_shift()
