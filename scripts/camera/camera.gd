extends Camera3D

enum CameraMode { FLY, FOLLOW }
var current_mode: CameraMode = CameraMode.FOLLOW

@export_group("Fly Mode")
@export var base_speed: float = 15.0
@export var fast_multiplier: float = 4.0
@export var mouse_sensitivity: float = 0.004

@export_group("Follow Mode")
@export var target_vehicle: Node3D

@export var follow_smoothing: float = 16.0
@export var max_follow_distance: float = 6.0
@export var follow_offset: Vector3 = Vector3(0.0, 1.25, 4.5)

var _yaw: float = 0.0
var _pitch: float = 0.0

var _follow_yaw: float = 0.0
var _follow_pitch: float = 0.0

func _ready() -> void:
	_yaw = rotation.y
	_pitch = rotation.x

	if current_mode == CameraMode.FOLLOW: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_mode"):
		current_mode = CameraMode.FOLLOW if current_mode == CameraMode.FLY else CameraMode.FLY

		if current_mode == CameraMode.FOLLOW:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED 
			_follow_yaw = 0.0   
			_follow_pitch = 0.0
		else: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE 

	if current_mode == CameraMode.FLY:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				if event.pressed: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				else: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_yaw -= event.relative.x * mouse_sensitivity

			_pitch -= event.relative.y * mouse_sensitivity
			_pitch = clamp(_pitch, -PI/2 + 0.01, PI/2 - 0.01)

			rotation = Vector3(_pitch, _yaw, 0)
	elif current_mode == CameraMode.FOLLOW:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_follow_yaw -= event.relative.x * mouse_sensitivity

			_follow_pitch -= event.relative.y * mouse_sensitivity
			_follow_pitch = clamp(_follow_pitch, deg_to_rad(-80.0), deg_to_rad(80.0))

	if event.is_action_pressed("ui_cancel"): 
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if current_mode == CameraMode.FLY: _process_debug_fly(delta)
	elif current_mode == CameraMode.FOLLOW and is_instance_valid(target_vehicle): _process_follow_car(delta)

func _process_debug_fly(delta: float) -> void:
	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): direction.z -= 1
	if Input.is_key_pressed(KEY_S): direction.z += 1
	if Input.is_key_pressed(KEY_A): direction.x -= 1
	if Input.is_key_pressed(KEY_D): direction.x += 1
	if Input.is_key_pressed(KEY_E): direction.y += 1
	if Input.is_key_pressed(KEY_Q): direction.y -= 1

	if direction != Vector3.ZERO:
		direction = direction.normalized()

		var current_speed := base_speed
		if Input.is_key_pressed(KEY_SHIFT): current_speed *= fast_multiplier

		global_position += (global_transform.basis * direction) * current_speed * delta

func _process_follow_car(delta: float) -> void:
	var car_basis := target_vehicle.global_transform.basis
	var yaw_basis := car_basis.rotated(Vector3.UP, _follow_yaw)
	var orbit_basis := yaw_basis.rotated(yaw_basis.x, _follow_pitch)

	var target_position: Vector3 = target_vehicle.global_position + (orbit_basis * follow_offset)
	var look_target: Vector3 = target_vehicle.global_position + Vector3(0.0, follow_offset.y * 0.5, 0.0)

	var target_transform := Transform3D().looking_at(look_target - target_position, Vector3.UP)
	target_transform.origin = target_position

	var weight = 1.0 - exp(-follow_smoothing * delta)
	global_position = global_position.lerp(target_transform.origin, weight)
	global_basis = global_basis.slerp(target_transform.basis, weight)

	var offset_from_car: Vector3 = global_position - target_vehicle.global_position
	if offset_from_car.length() > max_follow_distance:
		global_position = target_vehicle.global_position + offset_from_car.normalized() * max_follow_distance

	_yaw = rotation.y
	_pitch = rotation.x
