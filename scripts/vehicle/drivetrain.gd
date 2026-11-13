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

var _root: DriveNode

var _wheel_share: Dictionary[Wheel, float] = { }
var _prev_wheel_speed: Dictionary[Wheel, float] = { }


class DriveNode extends RefCounted:
	var wheel: Wheel

	var first: DriveNode
	var second: DriveNode

	var share_first: float = 0.5
	var is_center: bool = false
	var leaves: Array[Wheel] = []


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


func setup_driveline(driven_wheels: Array[Wheel]) -> void:
	var front: Array[Wheel] = []
	var rear: Array[Wheel] = []
	for w in driven_wheels:
		if w.is_front:
			front.append(w)
		else:
			rear.append(w)

	var front_node: DriveNode = _make_axle_node(front)
	var rear_node: DriveNode = _make_axle_node(rear)

	if front_node == null:
		_root = rear_node
	elif rear_node == null:
		_root = front_node
	else:
		_root = _make_branch(front_node, rear_node, config.center_front_torque_share)
		_root.is_center = true

	_wheel_share.clear()
	if _root != null:
		_assign_shares(_root, 1.0)


func get_wheel_share(wheel: Wheel) -> float:
	return _wheel_share.get(wheel, 0.0)


func get_input_speed_rad_s() -> float:
	var total: float = 0.0
	for w: Wheel in _wheel_share:
		total += _wheel_share[w] * absf(w.angular_velocity_rad_s)

	return total


func split_drive_torque(
	total_torque_nm: float,
	is_power: bool,
	engine_inertia: float,
	delta: float,
) -> Dictionary[Wheel, float]:
	var result: Dictionary[Wheel, float] = { }
	if _root == null:
		return result

	var fix: Dictionary[Wheel, float] = _inertia_fix(total_torque_nm, engine_inertia, delta)
	_distribute(_root, total_torque_nm, is_power, engine_inertia, delta, fix, result)

	return result


func _make_axle_node(wheels: Array[Wheel]) -> DriveNode:
	if wheels.is_empty():
		return null

	var node: DriveNode = _make_leaf(wheels[0])
	for i in range(1, wheels.size()):
		node = _make_branch(node, _make_leaf(wheels[i]), float(i) / float(i + 1))

	return node


func _make_leaf(wheel: Wheel) -> DriveNode:
	var node := DriveNode.new()
	node.wheel = wheel
	node.leaves = [wheel]

	return node


func _make_branch(first: DriveNode, second: DriveNode, share_first: float) -> DriveNode:
	var node := DriveNode.new()
	node.first = first
	node.second = second

	node.share_first = share_first

	node.leaves.append_array(first.leaves)
	node.leaves.append_array(second.leaves)

	return node


func _assign_shares(node: DriveNode, share: float) -> void:
	if node.wheel != null:
		_wheel_share[node.wheel] = share
		return

	_assign_shares(node.first, share * node.share_first)
	_assign_shares(node.second, share * (1.0 - node.share_first))


func _inertia_fix(
	total_torque_nm: float,
	engine_inertia: float,
	delta: float,
) -> Dictionary[Wheel, float]:
	var accel: Dictionary[Wheel, float] = { }
	var mean_accel: float = 0.0
	for w: Wheel in _wheel_share:
		var previous: float = _prev_wheel_speed.get(w, w.angular_velocity_rad_s)
		accel[w] = (w.angular_velocity_rad_s - previous) / delta
		mean_accel += _wheel_share[w] * accel[w]

		_prev_wheel_speed[w] = w.angular_velocity_rad_s

	var fix: Dictionary[Wheel, float] = { }
	for w: Wheel in _wheel_share:
		var share: float = _wheel_share[w]
		var limit: float = maxf(absf(total_torque_nm * share), 100.0)
		fix[w] = clampf(engine_inertia * share * (accel[w] - mean_accel), -limit, limit)

	return fix


func _distribute(
	node: DriveNode,
	torque: float,
	is_power: bool,
	engine_inertia: float,
	delta: float,
	fix: Dictionary[Wheel, float],
	result: Dictionary[Wheel, float],
) -> void:
	if node.wheel != null:
		result[node.wheel] = torque + fix.get(node.wheel, 0.0)
		return

	var torque_a: float = torque * node.share_first
	var torque_b: float = torque - torque_a

	var mode: DrivetrainConfig.DifferentialType = config.differential_type

	var preload_nm: float = config.lsd_preload_nm

	var power_lock: float = config.lsd_power_lock
	var coast_lock: float = config.lsd_coast_lock

	if node.is_center:
		mode = config.center_differential_type

		preload_nm = config.center_lsd_preload_nm

		power_lock = config.center_lsd_power_lock
		coast_lock = config.center_lsd_coast_lock

	if mode != DrivetrainConfig.DifferentialType.OPEN:
		var inertia_a: float = _subtree_inertia(node.first, engine_inertia)
		var inertia_b: float = _subtree_inertia(node.second, engine_inertia)

		var free_a: float = torque_a + _subtree_fix(node.first, fix) - _subtree_tire_torque(
			node.first
		)
		var free_b: float = torque_b + _subtree_fix(node.second, fix) - _subtree_tire_torque(
			node.second
		)

		var speed_gap: float = _subtree_speed(node.first) - _subtree_speed(node.second)
		var needed_nm: float = (speed_gap / delta + free_a / inertia_a - free_b / inertia_b) / (
			1.0 / inertia_a + 1.0 / inertia_b
		)

		var capacity_nm: float = INF
		if mode == DrivetrainConfig.DifferentialType.LIMITED_SLIP:
			var lock: float = power_lock if is_power else coast_lock
			capacity_nm = preload_nm + lock * absf(torque) * 0.5

		var transfer_nm: float = clampf(needed_nm, -capacity_nm, capacity_nm)
		torque_a -= transfer_nm
		torque_b += transfer_nm

	_distribute(node.first, torque_a, is_power, engine_inertia, delta, fix, result)
	_distribute(node.second, torque_b, is_power, engine_inertia, delta, fix, result)


func _subtree_speed(node: DriveNode) -> float:
	var weight: float = 0.0
	var total: float = 0.0
	for w in node.leaves:
		weight += _wheel_share[w]
		total += _wheel_share[w] * w.angular_velocity_rad_s

	return total / maxf(weight, 0.0001)


func _subtree_inertia(node: DriveNode, engine_inertia: float) -> float:
	var total: float = 0.0
	for w in node.leaves:
		total += w.suspension_config.wheel_inertia + engine_inertia * _wheel_share[w]

	return total


func _subtree_fix(node: DriveNode, fix: Dictionary[Wheel, float]) -> float:
	var total: float = 0.0
	for w in node.leaves:
		total += fix.get(w, 0.0)

	return total


func _subtree_tire_torque(node: DriveNode) -> float:
	var total: float = 0.0
	for w in node.leaves:
		total += w.suspension_config.wheel_radius * w.longitudinal_force_n

	return total


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
