class_name Wheel
extends RayCast3D

@export_group("Wheel")
@export var is_front: bool = false
@export var is_driven: bool = true

@export var wheel_radius: float = 0.33

@export_group("Suspension")
@export var spring_stiffness: float = 30000.0
@export var damper_stiffness: float = 1600.0

@export var suspension_rest_length: float = 0.35

@export_group("Friction")
@export var friction_coef: float = 1.0

@export_group("Mesh")
@onready var visual_mesh: MeshInstance3D = $Mesh

var is_grounded: bool = false

var compression: float = 0.0
var spring_displacement: float = 0.0

var contact_point: Vector3 = Vector3.ZERO
var contact_normal: Vector3 = Vector3.UP

var suspension_force_n: float = 0.0
var lateral_force_n: float = 0.0
var longitudinal_force_n: float = 0.0

var steer_angle_rad: float = 0.0
var _prev_displacement: float = 0.0

var _spin_angle: float = 0.0

func _ready() -> void:
	var total_ray_length := suspension_rest_length + wheel_radius
	target_position = Vector3(0, -total_ray_length, 0)

	enabled = true
	exclude_parent = true

func update_wheel(chassis: RigidBody3D, delta: float, throttle_input: float, brake_input: float, drive_force_per_wheel: float, brake_force_per_wheel: float) -> void:
	is_grounded = is_colliding()

	if not is_grounded:
		compression = 0.0
		spring_displacement = 0.0

		suspension_force_n = 0.0
		lateral_force_n = 0.0
		longitudinal_force_n = 0.0

		_prev_displacement = 0.0
		return

	contact_point = get_collision_point()
	contact_normal = get_collision_normal()
	var hit_dist: float = (contact_point - global_position).length()

	var total_length: float = suspension_rest_length + wheel_radius
	spring_displacement = clamp(total_length - hit_dist, 0.0, suspension_rest_length)
	compression = spring_displacement / suspension_rest_length

	var compression_speed: float = (spring_displacement - _prev_displacement) / max(delta, 0.0001)
	_prev_displacement = spring_displacement

	var f_spring: float = spring_stiffness * spring_displacement
	var f_damper: float = damper_stiffness * compression_speed
	suspension_force_n = max(0.0, f_spring + f_damper)

	var chassis_up: Vector3 = chassis.global_transform.basis.y.normalized()
	var wheel_basis: Basis = chassis.global_transform.basis.rotated(chassis_up, steer_angle_rad)

	var wheel_forward: Vector3 = -wheel_basis.z.normalized()
	var wheel_right: Vector3 = wheel_basis.x.normalized()
	wheel_forward = (wheel_forward - contact_normal * wheel_forward.dot(contact_normal)).normalized()
	wheel_right = (wheel_right - contact_normal * wheel_right.dot(contact_normal)).normalized()

	var r: Vector3 = contact_point - chassis.global_position
	var contact_velocity: Vector3 = chassis.linear_velocity + chassis.angular_velocity.cross(r)

	var v_lat: float = contact_velocity.dot(wheel_right)
	var v_long: float = contact_velocity.dot(wheel_forward)

	var max_grip: float = friction_coef * suspension_force_n

	var wheel_share_mass: float = chassis.mass * 0.25
	var desired_lateral_force: float = -v_lat * (wheel_share_mass / max(delta, 0.0001))
	lateral_force_n = clamp(desired_lateral_force, -max_grip, max_grip)

	longitudinal_force_n = 0.0
	if is_driven:
		longitudinal_force_n += throttle_input * drive_force_per_wheel

	if brake_input > 0.001 and abs(v_long) > 0.1:
		var desired_brake: float = -sign(v_long) * brake_input * brake_force_per_wheel
		longitudinal_force_n += desired_brake

	var c_rr: float = 0.015 * suspension_force_n
	longitudinal_force_n -= c_rr * sign(v_long)

	var total_horizontal_force := Vector2(longitudinal_force_n, lateral_force_n)
	if total_horizontal_force.length() > max_grip and max_grip > 0.0:
		total_horizontal_force = total_horizontal_force.normalized() * max_grip
		longitudinal_force_n = total_horizontal_force.x
		lateral_force_n = total_horizontal_force.y

	var total_force: Vector3 = (contact_normal * suspension_force_n) + (wheel_forward * longitudinal_force_n) + (wheel_right * lateral_force_n)
	chassis.apply_force(total_force, contact_point - chassis.global_position)

	if visual_mesh:
		var visual_y = -(suspension_rest_length - spring_displacement)
		visual_mesh.position = Vector3(0, visual_y, 0)

		if is_grounded: _spin_angle += (-v_long / wheel_radius) * delta
		visual_mesh.rotation.x = _spin_angle
		visual_mesh.rotation.y = steer_angle_rad

	DebugDraw3D.draw_line(contact_point, contact_point + contact_normal * (suspension_force_n / 1500.0), Color.GREEN)
	DebugDraw3D.draw_line(contact_point, contact_point + wheel_right * (lateral_force_n / 1500.0), Color.RED)
	DebugDraw3D.draw_line(contact_point, contact_point + wheel_forward * (longitudinal_force_n / 1500.0), Color.BLUE)
