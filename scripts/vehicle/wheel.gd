class_name Wheel
extends RayCast3D

@export var suspension_config: SuspensionConfig

@export var tire_model: Tire

@export_group("Wheel")
@export var is_front: bool = false
@export var is_driven: bool = true
@export var can_steer: bool = false

@export_group("Friction")
@export var friction_coef: float = 1.0
@export var rolling_resistance_coef: float = 0.012


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

var slip_ratio: float = 0.0
var slip_angle_rad: float = 0.0

var grip_limit_n: float = 0.0

var _prev_displacement: float = 0.0
var _spin_angle: float = 0.0


func _ready() -> void:
	var rest_length: float = suspension_config.suspension_rest_length
	var radius: float = suspension_config.wheel_radius
	var total_ray_length := rest_length + radius
	target_position = Vector3(0, -total_ray_length, 0)

	enabled = true
	exclude_parent = true


func update_wheel(
	chassis: RigidBody3D,
	delta: float,
	drive_torque_nm: float,
	brake_torque_nm: float,
	reflected_inertia: float = 0.0,
) -> void:
	force_raycast_update()
	is_grounded = is_colliding()

	var radius: float = suspension_config.wheel_radius
	var base_inertia: float = suspension_config.wheel_inertia
	var rest_len: float = suspension_config.suspension_rest_length

	var k_spring: float = suspension_config.spring_stiffness
	var k_damper: float = suspension_config.damper_stiffness

	var inertia: float = base_inertia + reflected_inertia

	if not is_grounded:
		_handle_airborne(delta, drive_torque_nm, brake_torque_nm, inertia)
		return

	contact_point = get_collision_point()
	contact_normal = get_collision_normal()
	var hit_dist: float = (contact_point - global_position).length()

	var total_length: float = rest_len + radius
	spring_displacement = clamp(total_length - hit_dist, 0.0, rest_len)
	compression = spring_displacement / rest_len

	var compression_speed: float = (spring_displacement - _prev_displacement) / max(delta, 0.0001)
	_prev_displacement = spring_displacement

	var f_spring: float = k_spring * spring_displacement
	var f_damper: float = k_damper * compression_speed
	suspension_force_n = max(0.0, f_spring + f_damper)

	var chassis_up: Vector3 = chassis.global_transform.basis.y.normalized()
	var wheel_basis: Basis = chassis.global_transform.basis.rotated(chassis_up, steer_angle_rad)

	var wheel_forward: Vector3 = -wheel_basis.z.normalized()
	var wheel_right: Vector3 = wheel_basis.x.normalized()
	wheel_forward = (
		wheel_forward - contact_normal * wheel_forward.dot(contact_normal)
	).normalized()
	wheel_right = (wheel_right - contact_normal * wheel_right.dot(contact_normal)).normalized()

	var com_world: Vector3 = chassis.to_global(chassis.center_of_mass)
	var r: Vector3 = contact_point - com_world
	var contact_velocity: Vector3 = chassis.linear_velocity + chassis.angular_velocity.cross(r)

	var v_lat: float = contact_velocity.dot(wheel_right)
	var v_long: float = contact_velocity.dot(wheel_forward)
	var speed_long: float = absf(v_long)

	var fz: float = suspension_force_n
	grip_limit_n = tire_model.peak_force_n(fz) * friction_coef

	var alpha: float = atan2(-v_lat, maxf(speed_long, tire_model.slip_speed_floor))

	var speed_denominator: float = maxf(speed_long, tire_model.slip_speed_floor)
	var kappa_now: float = (angular_velocity_rad_s * radius - v_long) / speed_denominator

	var f_now: Vector2 = tire_model.compute_forces(
		kappa_now,
		alpha,
		v_lat,
		speed_long,
		fz,
		friction_coef,
	)
	var kappa_step: float = 0.02
	var f_step: Vector2 = tire_model.compute_forces(
		kappa_now + kappa_step,
		alpha,
		v_lat,
		speed_long,
		fz,
		friction_coef,
	)

	var force_slope: float = maxf((f_step.x - f_now.x) / kappa_step, 0.0)
	var stiffness_w: float = force_slope * radius / speed_denominator

	var implicit_inertia: float = inertia + delta * radius * stiffness_w
	var w_new: float = (
		angular_velocity_rad_s + delta * (drive_torque_nm - radius * f_now.x) / implicit_inertia
	)

	w_new = move_toward(w_new, 0.0, delta * brake_torque_nm / implicit_inertia)
	angular_velocity_rad_s = w_new

	var kappa_new: float = (angular_velocity_rad_s * radius - v_long) / speed_denominator
	var f_final: Vector2 = tire_model.compute_forces(
		kappa_new,
		alpha,
		v_lat,
		speed_long,
		fz,
		friction_coef,
	)
	var fx: float = f_final.x
	var fy: float = f_final.y

	var mass_share: float = chassis.mass * 0.25
	if absf(v_lat) > 0.0001 and fy * v_lat < 0.0:
		fy = fy * mass_share * absf(v_lat) / (mass_share * absf(v_lat) + delta * absf(fy))

	var wheel_surface_speed: float = absf(angular_velocity_rad_s * radius)
	if brake_torque_nm > 0.0 and fx * v_long < 0.0 and wheel_surface_speed < speed_long:
		fx = fx * mass_share * speed_long / (mass_share * speed_long + delta * absf(fx))

	fx += -rolling_resistance_coef * fz * clampf(v_long / 0.5, -1.0, 1.0)

	longitudinal_force_n = fx
	lateral_force_n = fy
	slip_ratio = kappa_new
	slip_angle_rad = alpha

	var total_force: Vector3 = (
		(contact_normal * suspension_force_n)
		+ (wheel_forward * longitudinal_force_n) + (wheel_right * lateral_force_n)
	)
	chassis.apply_force(total_force, contact_point - chassis.global_position)

	if visual_mesh:
		var visual_y = -(rest_len - spring_displacement)
		visual_mesh.position = Vector3(0, visual_y, 0)

		_spin_angle += angular_velocity_rad_s * delta
		visual_mesh.rotation.x = -_spin_angle
		visual_mesh.rotation.y = steer_angle_rad

	DebugDraw3D.draw_line(
		contact_point,
		contact_point + contact_normal * (suspension_force_n / 1500.0),
		Color.GREEN,
	)
	DebugDraw3D.draw_line(
		contact_point,
		contact_point + wheel_right * (lateral_force_n / 1500.0),
		Color.RED,
	)
	DebugDraw3D.draw_line(
		contact_point,
		contact_point + wheel_forward * (longitudinal_force_n / 1500.0),
		Color.BLUE,
	)


func _handle_airborne(
	delta: float,
	drive_torque_nm: float,
	brake_torque_nm: float,
	inertia: float,
) -> void:
	compression = 0.0
	spring_displacement = 0.0

	suspension_force_n = 0.0
	lateral_force_n = 0.0
	longitudinal_force_n = 0.0

	slip_ratio = 0.0
	slip_angle_rad = 0.0

	grip_limit_n = 0.0

	_prev_displacement = 0.0

	var T_bearing: float = -signf(angular_velocity_rad_s) * minf(
		absf(angular_velocity_rad_s) * 0.5,
		5.0,
	)
	var w_free: float = (
		angular_velocity_rad_s + ((drive_torque_nm + T_bearing) / maxf(inertia, 0.001)) * delta
	)
	angular_velocity_rad_s = move_toward(
		w_free,
		0.0,
		delta * brake_torque_nm / maxf(inertia, 0.001),
	)

	if visual_mesh:
		_spin_angle += angular_velocity_rad_s * delta
		visual_mesh.rotation.x = -_spin_angle
