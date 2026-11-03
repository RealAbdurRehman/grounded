extends Camera3D

@export var base_speed: float = 15.0
@export var fast_multiplier: float = 4.0
@export var mouse_sensitivity: float = 0.004

var _yaw: float = 0.0
var _pitch: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_yaw = rotation.y
	_pitch = rotation.x

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event.is_action_pressed("ui_cancel"): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity

		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, -PI/2 + 0.01, PI/2 - 0.01)

		rotation = Vector3(_pitch, _yaw, 0)

func _process(delta: float) -> void:
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
