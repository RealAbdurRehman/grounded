class_name Wheel
extends RayCast3D

@export var suspension_config: SuspensionConfig

@export var tire_model: Tire

@export_group("Wheel")
@export var is_front: bool = false
@export var is_driven: bool = true
@export var can_steer: bool = false

@export var has_handbrake: bool = false

@export_group("Friction")
@export var friction_coef: float = 1.0
@export var rolling_resistance_coef: float = 0.012

@export_group("Solver")
@export_range(0.0, 1.0, 0.05) var spin_stability_weight: float = 0.75


@export_group("Mesh")
@onready var visual_mesh: MeshInstance3D = $Mesh

var is_grounded: bool = false

var is_locked: bool = false
var is_stuck: bool = false

var compression: float = 0.0
var spring_displacement: float = 0.0

var contact_point: Vector3 = Vector3.ZERO
var contact_normal: Vector3 = Vector3.UP

var suspension_force_n: float = 0.0
var arb_force_n: float = 0.0
var normal_load_n: float = 0.0

var lateral_force_n: float = 0.0
var longitudinal_force_n: float = 0.0

var steer_angle_rad: float = 0.0
var angular_velocity_rad_s: float = 0.0

var slip_ratio: float = 0.0
var slip_angle_rad: float = 0.0

var camber_rad: float = 0.0
var toe_rad: float = 0.0

var grip_limit_n: float = 0.0

var pneumatic_trail_m: float = 0.0
var aligning_torque_nm: float = 0.0
var steering_torque_nm: float = 0.0

var _stick_x: float = 0.0
var _stick_fx: float = 0.0

var _prev_displacement: float = -1.0
var _spin_angle: float = 0.0

var _side: float = 0.0
var _mesh_rest: Basis = Basis.IDENTITY


func _ready() -> void:
	_update_ray_length()

	enabled = true
	exclude_parent = true

	if visual_mesh:
		_mesh_rest = visual_mesh.basis


func _update_ray_length() -> void:
	var length: float = suspension_config.suspension_rest_length + suspension_config.wheel_radius
	if not is_equal_approx(-target_position.y, length):
		target_position = Vector3(0.0, -length, 0.0)


func _design_camber_rad() -> float:
	var config: SuspensionConfig = suspension_config
	var offset: float = spring_displacement - config.alignment_compression

	return deg_to_rad(config.static_camber_deg + config.camber_gain_deg_per_m * offset)


func _design_toe_rad() -> float:
	var config: SuspensionConfig = suspension_config
	var offset: float = spring_displacement - config.alignment_compression

	return deg_to_rad(config.static_toe_deg + config.bump_steer_deg_per_m * offset)


func _alignment_basis() -> Basis:
	var camber := Basis(Vector3.FORWARD, _side * _design_camber_rad())
	var toe := Basis(Vector3.UP, _side * _design_toe_rad())

	var caster: float = deg_to_rad(suspension_config.caster_deg)
	var steering_axis := Vector3(0.0, cos(caster), sin(caster))

	return Basis(steering_axis, steer_angle_rad) * toe * camber


func _update_visual(delta: float) -> void:
	if not visual_mesh:
		return

	var rest_len: float = suspension_config.suspension_rest_length
	visual_mesh.position = Vector3(0.0, -(rest_len - spring_displacement), 0.0)

	_spin_angle += angular_velocity_rad_s * delta
	visual_mesh.basis = _alignment_basis() * Basis(Vector3.RIGHT, -_spin_angle) * _mesh_rest


func update_wheel(
	chassis: RigidBody3D,
	delta: float,
	drive_torque_nm: float,
	brake_torque_nm: float,
	reflected_inertia: float = 0.0,
) -> void:
	if _side == 0.0:
		_side = 1.0 if chassis.to_local(global_position).x >= 0.0 else -1.0

	_update_ray_length()
	force_raycast_update()
	is_grounded = is_colliding()

	var radius: float = suspension_config.wheel_radius
	var base_inertia: float = suspension_config.wheel_inertia
	var rest_len: float = suspension_config.suspension_rest_length

	var k_spring: float = suspension_config.wheel_rate()

	var c_bump: float = suspension_config.wheel_bump()
	var c_rebound: float = suspension_config.wheel_rebound()

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

	if _prev_displacement < 0.0:
		_prev_displacement = spring_displacement

	var compression_speed: float = (spring_displacement - _prev_displacement) / max(delta, 0.0001)
	_prev_displacement = spring_displacement

	var f_spring: float = k_spring * spring_displacement
	var f_damper: float = (c_bump if compression_speed > 0.0 else c_rebound) * compression_speed
	suspension_force_n = max(0.0, f_spring + f_damper)
	normal_load_n = maxf(0.0, suspension_force_n + arb_force_n)

	var wheel_basis: Basis = chassis.global_transform.basis * _alignment_basis()

	var wheel_forward: Vector3 = -wheel_basis.z
	wheel_forward = (
		wheel_forward - contact_normal * wheel_forward.dot(contact_normal)
	).normalized()

	var wheel_right: Vector3 = wheel_forward.cross(contact_normal).normalized()

	var lean: float = asin(clampf(wheel_basis.y.normalized().dot(wheel_right), -1.0, 1.0))
	camber_rad = _side * lean
	toe_rad = _design_toe_rad()

	var com_world: Vector3 = chassis.to_global(chassis.center_of_mass)
	var r: Vector3 = contact_point - com_world
	var contact_velocity: Vector3 = chassis.linear_velocity + chassis.angular_velocity.cross(r)

	var v_lat: float = contact_velocity.dot(wheel_right)
	var v_long: float = contact_velocity.dot(wheel_forward)
	var speed_long: float = absf(v_long)

	var fz: float = normal_load_n
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
		lean,
	)

	var kappa_step: float = 0.02
	var f_step: Vector2 = tire_model.compute_forces(
		kappa_now + kappa_step,
		alpha,
		v_lat,
		speed_long,
		fz,
		friction_coef,
		lean,
	)

	var force_slope: float = maxf((f_step.x - f_now.x) / kappa_step, 0.0)

	if absf(kappa_now) > 0.001:
		force_slope = maxf(force_slope, spin_stability_weight * f_now.x / kappa_now)
	var stiffness_w: float = force_slope * radius / speed_denominator

	var implicit_inertia: float = inertia + delta * radius * stiffness_w
	var w_new: float = (
		angular_velocity_rad_s + delta * (drive_torque_nm - radius * f_now.x) / implicit_inertia
	)

	w_new = move_toward(w_new, 0.0, delta * brake_torque_nm / implicit_inertia)

	var mass_share: float = chassis.mass * 0.25

	is_stuck = _update_stick(
		delta,
		v_long,
		fz,
		radius,
		drive_torque_nm,
		brake_torque_nm,
		mass_share,
	)

	if is_stuck:
		w_new = 0.0

	angular_velocity_rad_s = w_new
	is_locked = brake_torque_nm > 0.0 and absf(angular_velocity_rad_s) < 0.01

	var kappa_new: float = (angular_velocity_rad_s * radius - v_long) / speed_denominator
	var f_final: Vector2 = tire_model.compute_forces(
		kappa_new,
		alpha,
		v_lat,
		speed_long,
		fz,
		friction_coef,
		lean,
	)

	var fx: float = f_final.x
	if is_stuck:
		fx = _stick_fx

	var fy: float = f_final.y

	if absf(v_lat) > 0.0001 and fy * v_lat < 0.0:
		fy = fy * mass_share * absf(v_lat) / (mass_share * absf(v_lat) + delta * absf(fy))

	var wheel_surface_speed: float = absf(angular_velocity_rad_s * radius)
	if (
		not is_stuck and brake_torque_nm > 0.0 and fx * v_long < 0.0
		and wheel_surface_speed < speed_long
	):
		fx = fx * mass_share * speed_long / (mass_share * speed_long + delta * absf(fx))

	fx += -rolling_resistance_coef * fz * clampf(v_long / 0.5, -1.0, 1.0)

	var gravity_dir: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector")
	var gravity_strength: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var gravity: Vector3 = gravity_dir * gravity_strength * chassis.gravity_scale

	var gravity_tangent: Vector3 = gravity - (contact_normal * gravity.dot(contact_normal))
	var expected_normal_load: float = chassis.mass * absf(gravity.dot(contact_normal))
	var load_share: float = clampf(fz / maxf(expected_normal_load, 1.0), 0.0, 1.0)

	var tangent_velocity: Vector3 = (
		contact_velocity - contact_normal * contact_velocity.dot(contact_normal)
	)
	var static_blend: float = 1.0 - smoothstep(
		0.05,
		tire_model.static_lateral_hold_speed,
		tangent_velocity.length(),
	)

	var static_lateral_force: float = (
		-gravity_tangent * chassis.mass * load_share
	).dot(wheel_right)
	fy += static_lateral_force * static_blend

	var combined_force: Vector2 = tire_model.project_to_friction_ellipse(
		Vector2(fx, fy),
		tire_model.peak_longitudinal_force_n(fz, friction_coef),
		tire_model.peak_lateral_force_n(fz, friction_coef, lean),
	)
	fx = combined_force.x
	fy = combined_force.y

	longitudinal_force_n = fx
	lateral_force_n = fy

	var rolling_fade: float = smoothstep(0.5, 4.0, speed_long) * smoothstep(0.0, 1.5, v_long)
	pneumatic_trail_m = tire_model.pneumatic_trail(alpha, fz)
	aligning_torque_nm = fy * pneumatic_trail_m * rolling_fade

	steering_torque_nm = 0.0
	if can_steer:
		var trail_m: float = pneumatic_trail_m + suspension_config.caster_trail()
		steering_torque_nm = fy * trail_m * rolling_fade

	slip_ratio = kappa_new
	slip_angle_rad = alpha

	var total_force: Vector3 = (
		(contact_normal * normal_load_n) + (wheel_forward * longitudinal_force_n)
		+ (wheel_right * lateral_force_n)
	)
	chassis.apply_force(total_force, contact_point - chassis.global_position)

	if visual_mesh:
		_update_visual(delta)

	var debug_scale: float = 1.0 / 3500.0
	DebugDraw3D.draw_vector(
		contact_point,
		contact_normal * (normal_load_n * debug_scale),
		Color.GREEN,
		chassis,
	)
	DebugDraw3D.draw_vector(
		contact_point,
		wheel_right * (lateral_force_n * debug_scale),
		Color.RED,
		chassis,
	)
	DebugDraw3D.draw_vector(
		contact_point,
		wheel_forward * (longitudinal_force_n * debug_scale),
		Color.BLUE,
		chassis,
	)


func _update_stick(
	delta: float,
	v_long: float,
	fz: float,
	radius: float,
	drive_torque_nm: float,
	brake_torque_nm: float,
	mass_share: float,
) -> bool:
	var limit: float = tire_model.stick_speed * (2.0 if is_stuck else 1.0)
	var surface_speed: float = absf(angular_velocity_rad_s) * radius
	if brake_torque_nm <= 0.0 or absf(v_long) > limit or surface_speed > limit:
		return false

	var peak: float = tire_model.peak_longitudinal_force_n(fz, friction_coef)
	if peak <= 1.0:
		return false

	var stiffness: float = peak / maxf(tire_model.stick_deflection_m, 0.001)
	var damping: float = 2.0 * tire_model.stick_damping_ratio * sqrt(stiffness * mass_share)

	if not is_stuck:
		_stick_x = -(longitudinal_force_n + damping * v_long) / stiffness

	_stick_x = clampf(_stick_x + v_long * delta, -peak / stiffness, peak / stiffness)
	var force: float = -(stiffness * _stick_x + damping * v_long)

	var force_low: float = (drive_torque_nm - brake_torque_nm) / radius
	var force_high: float = (drive_torque_nm + brake_torque_nm) / radius
	if force < force_low or force > force_high:
		return false

	_stick_fx = clampf(force, -peak, peak)

	return true


func _handle_airborne(
	delta: float,
	drive_torque_nm: float,
	brake_torque_nm: float,
	inertia: float,
) -> void:
	is_stuck = false
	is_locked = false

	compression = 0.0
	spring_displacement = 0.0

	suspension_force_n = 0.0
	normal_load_n = 0.0

	lateral_force_n = 0.0
	longitudinal_force_n = 0.0

	slip_ratio = 0.0
	slip_angle_rad = 0.0

	grip_limit_n = 0.0

	pneumatic_trail_m = 0.0
	aligning_torque_nm = 0.0
	steering_torque_nm = 0.0

	_prev_displacement = -1.0

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
		camber_rad = _design_camber_rad()
		toe_rad = _design_toe_rad()

		_update_visual(delta)
