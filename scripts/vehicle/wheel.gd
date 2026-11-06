class_name Wheel
extends RayCast3D

@export_group("Wheel")
@export var is_front: bool = false
@export var is_driven: bool = true

@export var wheel_radius: float = 0.33
@export var wheel_inertia: float = 1.2

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
var angular_velocity_rad_s: float = 0.0

var _prev_displacement: float = 0.0
var _spin_angle: float = 0.0

func _ready() -> void:
	var total_ray_length := suspension_rest_length + wheel_radius
	target_position = Vector3(0, -total_ray_length, 0)

	enabled = true
	exclude_parent = true

func update_wheel(chassis: RigidBody3D, delta: float, drive_torque_nm: float, brake_input: float, max_brake_torque: float) -> void:
	force_raycast_update()
	is_grounded = is_colliding()

	if not is_grounded:
		compression = 0.0
		spring_displacement = 0.0

		suspension_force_n = 0.0
		lateral_force_n = 0.0
		longitudinal_force_n = 0.0

		_prev_displacement = 0.0

		if is_driven and abs(drive_torque_nm) > 0.1: angular_velocity_rad_s += (drive_torque_nm / wheel_inertia) * delta
		else: angular_velocity_rad_s = move_toward(angular_velocity_rad_s, 0.0, delta * 8.0)

		if visual_mesh:
			_spin_angle += angular_velocity_rad_s * delta
			visual_mesh.rotation.x = _spin_angle

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

	var com_world: Vector3 = chassis.to_global(chassis.center_of_mass)
	var r: Vector3 = contact_point - com_world
	var contact_velocity: Vector3 = chassis.linear_velocity + chassis.angular_velocity.cross(r)

	var v_lat: float = contact_velocity.dot(wheel_right)
	var v_long: float = contact_velocity.dot(wheel_forward)

	var max_grip: float = friction_coef * suspension_force_n

	var drive_force: float = 0.0
	if is_driven: drive_force = drive_torque_nm / wheel_radius

	var brake_torque: float = brake_input * max_brake_torque
	var brake_force: float = 0.0
	if brake_torque > 0.01 and abs(v_long) > 0.1: brake_force = -sign(v_long) * (brake_torque / wheel_radius)

	var rolling_resistance: float = -0.015 * suspension_force_n * sign(v_long)
	longitudinal_force_n = drive_force + brake_force + rolling_resistance

	var wheel_share_mass: float = chassis.mass * 0.25
	var desired_lateral_force: float = -v_lat * (wheel_share_mass / max(delta, 0.0001))
	lateral_force_n = clamp(desired_lateral_force, -max_grip, max_grip)

	var total_horizontal_force := Vector2(longitudinal_force_n, lateral_force_n)
	if total_horizontal_force.length() > max_grip and max_grip > 0.0:
		total_horizontal_force = total_horizontal_force.normalized() * max_grip
		longitudinal_force_n = total_horizontal_force.x
		lateral_force_n = total_horizontal_force.y

	angular_velocity_rad_s = v_long / wheel_radius

	var total_force: Vector3 = (contact_normal * suspension_force_n) + (wheel_forward * longitudinal_force_n) + (wheel_right * lateral_force_n)
	chassis.apply_force(total_force, contact_point - chassis.global_position)

	if visual_mesh:
		var visual_y = -(suspension_rest_length - spring_displacement)
		visual_mesh.position = Vector3(0, visual_y, 0)
		
		_spin_angle += angular_velocity_rad_s * delta
		visual_mesh.rotation.x = -_spin_angle
		visual_mesh.rotation.y = steer_angle_rad

	DebugDraw3D.draw_line(contact_point, contact_point + contact_normal * (suspension_force_n / 1500.0), Color.GREEN)
	DebugDraw3D.draw_line(contact_point, contact_point + wheel_right * (lateral_force_n / 1500.0), Color.RED)
	DebugDraw3D.draw_line(contact_point, contact_point + wheel_forward * (longitudinal_force_n / 1500.0), Color.BLUE)
