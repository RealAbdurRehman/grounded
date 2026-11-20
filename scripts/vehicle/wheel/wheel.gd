class_name Wheel
extends Node3D

const RIM_PUSH_OUT_MPS: float = 1.5

const CENTER_WHEEL_M: float = 0.05

@export var suspension_config: SuspensionConfig

@export var tire_model: Tire

@export_group("Ground")
## What the wheel can drive on.
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Wheel")
@export var is_driven: bool = true
@export var can_steer: bool = false

@export var has_handbrake: bool = false

@export_group("Friction")
@export var friction_coef: float = 1.0
@export var rolling_resistance_coef: float = 0.012

@export_group("Solver")
@export_range(0.0, 1.0, 0.05) var spin_stability_weight: float = 0.75


@export_group("Mesh")
@onready var visual_mesh: MeshInstance3D = get_node_or_null("Mesh")

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

var _stick_y: float = 0.0

var _hub_speed: float = 0.0
var _tire_squash: float = 0.0
var _stop_force_n: float = 0.0

var _hub_started: bool = false

var _spin_angle: float = 0.0

var is_front: bool = false

var axle_index: int = 0
var label: String = ""
var mass_fraction: float = 0.25

var _side: float = 0.0
var _side_known: bool = false
var _mesh_rest: Basis = Basis.IDENTITY

var _ground: GroundProbe = GroundProbe.new()

var _visual: TireVisual = TireVisual.new()

var collider: TireCollider = TireCollider.new()

var thermal: TireThermal = TireThermal.new()

var inflation: TirePressure = TirePressure.new()

var spin_inertia: float = 1.2
var obstacle_impulse_n_s: Vector3 = Vector3.ZERO


func _ready() -> void:
	if not visual_mesh:
		visual_mesh = MeshInstance3D.new()
		visual_mesh.name = "Mesh"

		add_child(visual_mesh)

	_visual.setup(visual_mesh, suspension_config, tire_model)
	_mesh_rest = _visual.rest_basis


func _design_camber_rad() -> float:
	var config: SuspensionConfig = suspension_config
	var offset: float = spring_displacement - config.alignment_compression

	return deg_to_rad(config.static_camber_deg + config.camber_gain_deg_per_m * offset)


func _design_toe_rad() -> float:
	var config: SuspensionConfig = suspension_config
	var offset: float = spring_displacement - config.alignment_compression

	return deg_to_rad(config.static_toe_deg + config.bump_steer_deg_per_m * offset)


func _alignment_basis() -> Basis:
	return _alignment_basis_at(steer_angle_rad)


func _alignment_basis_at(steer: float, with_camber: bool = true) -> Basis:
	var camber := Basis.IDENTITY
	if with_camber:
		camber = Basis(Vector3.FORWARD, _side * _design_camber_rad())

	var toe := Basis(Vector3.UP, _side * _design_toe_rad())

	var caster: float = deg_to_rad(suspension_config.caster_deg)
	var steering_axis := Vector3(0.0, cos(caster), sin(caster))

	return Basis(steering_axis, steer) * toe * camber


func _update_visual(delta: float) -> void:
	if not visual_mesh:
		return

	var rest_len: float = suspension_config.suspension_rest_length
	visual_mesh.position = Vector3(0.0, -(rest_len - spring_displacement), 0.0)

	_spin_angle = fposmod(_spin_angle + angular_velocity_rad_s * delta, TAU)
	visual_mesh.basis = _alignment_basis() * Basis(Vector3.RIGHT, -_spin_angle) * _mesh_rest


func grip_scale() -> float:
	return friction_coef * thermal.grip_factor * inflation.grip_factor


func tire_area_scale() -> float:
	var config: SuspensionConfig = suspension_config
	return maxf(config.wheel_radius * config.width_m() / TireThermal.REFERENCE_TIRE_AREA_M2, 0.05)


func tire_stiffness_n_m() -> float:
	return suspension_config.tire_stiffness * inflation.stiffness_factor


func kappa_peak() -> float:
	return tire_model.kappa_peak() / inflation.cornering_factor


func alpha_peak() -> float:
	return tire_model.alpha_peak() / inflation.cornering_factor


func _step_tire_state(delta: float, rolling_w: float, sliding_w: float, speed: float) -> void:
	var ambient_c: float = Atmosphere.config.air_temperature_c

	if not tire_model.temperature_enabled:
		thermal.grip_factor = 1.0
		thermal.rolling_factor = 1.0

		inflation.update(tire_model, ambient_c, normal_load_n)

		return

	thermal.step(tire_model, tire_area_scale(), ambient_c, rolling_w, sliding_w, speed, delta)
	inflation.update(tire_model, thermal.cavity_c, normal_load_n)


func rolling_radius_m() -> float:
	return suspension_config.wheel_radius - tire_model.rolling_radius_loss * _tire_squash


func hub_basis() -> Basis:
	return global_transform.basis.orthonormalized() * _alignment_basis()


func hub_world_position() -> Vector3:
	var up: Vector3 = global_transform.basis.orthonormalized().y
	return global_position - up * (suspension_config.suspension_rest_length - spring_displacement)


func spin_axis(chassis: RigidBody3D) -> Vector3:
	return -(chassis.global_transform.basis * _alignment_basis()).x


func hub_speed() -> float:
	return _hub_speed


func kick_hub(speed_change: float) -> void:
	_hub_speed += speed_change


func kick_spin(speed_change: float) -> void:
	angular_velocity_rad_s += speed_change


func _tire_center() -> Vector3:
	var up: Vector3 = global_transform.basis.orthonormalized().y

	var along: float = suspension_config.suspension_rest_length - spring_displacement
	if is_grounded:
		along = _ground.first_touch_along

	return global_position - up * along + up * TireCollider.LIFT_M


func _tire_basis(chassis: RigidBody3D, steer: float, with_camber: bool = true) -> Basis:
	var alignment: Basis = _alignment_basis_at(steer, with_camber)
	var wheel_basis: Basis = chassis.global_transform.basis * alignment

	return wheel_basis * Basis(Vector3.BACK, PI * 0.5)


func find_obstacles(chassis: RigidBody3D, delta: float) -> void:
	var config: SuspensionConfig = suspension_config

	var up: Vector3 = global_transform.basis.orthonormalized().y
	var center: Vector3 = _tire_center()

	var com: Vector3 = chassis.to_global(chassis.center_of_mass)
	var velocity: Vector3 = chassis.linear_velocity + chassis.angular_velocity.cross(center - com)
	var motion: Vector3 = (velocity - up * velocity.dot(up)) * delta * 1.5

	var exclude: Array[RID] = [chassis.get_rid()]

	collider.scan(
		get_world_3d().direct_space_state,
		exclude,
		collision_mask,
		config.wheel_radius,
		config.width_m(),
		_tire_basis(chassis, steer_angle_rad),
		center,
		up,
		motion,
	)


func update_squash(chassis: RigidBody3D, delta: float) -> void:
	_visual.update(self, chassis, delta)


func _tick_path(chassis: RigidBody3D, delta: float) -> Vector3:
	var up: Vector3 = global_transform.basis.orthonormalized().y
	var center: Vector3 = chassis.to_global(chassis.center_of_mass)

	var velocity: Vector3 = (chassis.linear_velocity + chassis.angular_velocity.cross(
			global_position - center
		))

	return (velocity - up * velocity.dot(up)) * delta


func update_wheel(
	chassis: RigidBody3D,
	delta: float,
	drive_torque_nm: float,
	brake_torque_nm: float,
	reflected_inertia: float = 0.0,
) -> void:
	if not _side_known:
		_side_known = true

		var x: float = chassis.to_local(global_position).x
		_side = 0.0 if absf(x) < CENTER_WHEEL_M else signf(x)

	var air_speed: float = chassis.linear_velocity.length()

	is_grounded = _ground.find(
		self,
		chassis,
		suspension_config,
		collision_mask,
		_tire_basis(chassis, steer_angle_rad, false),
		_tick_path(chassis, delta),
	)

	_step_hub(chassis, delta)

	var radius: float = rolling_radius_m()
	var base_inertia: float = suspension_config.wheel_inertia
	var rest_len: float = suspension_config.suspension_rest_length

	var k_spring: float = suspension_config.wheel_rate()

	var inertia: float = base_inertia + reflected_inertia
	spin_inertia = inertia

	if not is_grounded:
		_handle_airborne(delta, drive_torque_nm, brake_torque_nm, inertia)
		_step_tire_state(delta, 0.0, 0.0, maxf(air_speed, absf(angular_velocity_rad_s) * radius))

		return

	contact_point = _ground.contact_point
	contact_normal = _ground.contact_normal

	compression = spring_displacement / rest_len

	var f_spring: float = (
		k_spring * spring_displacement + suspension_config.bump_stop_force(spring_displacement)
	)

	var f_damper: float = suspension_config.damper_force(_hub_speed)
	suspension_force_n = maxf(0.0, f_spring + f_damper + arb_force_n)

	normal_load_n = tire_stiffness_n_m() * _tire_squash

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
	var friction: float = grip_scale()
	grip_limit_n = tire_model.peak_force_n(fz) * friction

	var mass_share: float = chassis.mass * mass_fraction
	var hold_fy: float = _lateral_hold(delta, v_lat, v_long, fz, lean, mass_share)

	var alpha: float = atan2(-v_lat, maxf(speed_long, tire_model.slip_speed_floor))

	var speed_denominator: float = maxf(speed_long, tire_model.slip_speed_floor)
	var kappa_now: float = (angular_velocity_rad_s * radius - v_long) / speed_denominator

	var f_now: Vector2 = tire_model.compute_forces(
		kappa_now,
		alpha,
		hold_fy,
		speed_long,
		fz,
		friction,
		lean,
		inflation.cornering_factor,
	)

	var kappa_step: float = 0.02
	var f_step: Vector2 = tire_model.compute_forces(
		kappa_now + kappa_step,
		alpha,
		hold_fy,
		speed_long,
		fz,
		friction,
		lean,
		inflation.cornering_factor,
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
		hold_fy,
		speed_long,
		fz,
		friction,
		lean,
		inflation.cornering_factor,
	)

	var fx: float = f_final.x
	if is_stuck:
		fx = _stick_fx

	var fy: float = f_final.y

	if absf(v_lat) > 0.0001 and fy * v_lat < 0.0:
		var momentum: float = mass_share * absf(v_lat)
		var limited: float = fy * momentum / (momentum + delta * absf(fy))
		fy = lerpf(fy, limited, tire_model.curve_weight(speed_long))

	var wheel_surface_speed: float = absf(angular_velocity_rad_s * radius)
	if (
		not is_stuck and brake_torque_nm > 0.0 and fx * v_long < 0.0
		and wheel_surface_speed < speed_long
	):
		fx = fx * mass_share * speed_long / (mass_share * speed_long + delta * absf(fx))

	var rolling_fade_in: float = clampf(v_long / 0.5, -1.0, 1.0)
	var rolling_coef: float = (
		rolling_resistance_coef * thermal.rolling_factor * inflation.rolling_factor
	)

	fx += -rolling_coef * fz * rolling_fade_in

	var combined_force: Vector2 = tire_model.project_to_friction_ellipse(
		Vector2(fx, fy),
		tire_model.peak_longitudinal_force_n(fz, friction),
		tire_model.peak_lateral_force_n(fz, friction, lean),
	)

	fx = combined_force.x
	fy = combined_force.y

	longitudinal_force_n = fx
	lateral_force_n = fy

	var rolling_fade: float = smoothstep(0.5, 4.0, speed_long) * smoothstep(0.0, 1.5, v_long)
	pneumatic_trail_m = tire_model.pneumatic_trail(
		alpha,
		fz,
		inflation.trail_factor,
		inflation.cornering_factor,
	)

	aligning_torque_nm = fy * pneumatic_trail_m * rolling_fade

	steering_torque_nm = 0.0
	if can_steer:
		var trail_m: float = pneumatic_trail_m + suspension_config.caster_trail()
		steering_torque_nm = fy * trail_m * rolling_fade

	slip_ratio = kappa_new
	slip_angle_rad = alpha

	var rolling_w: float = rolling_coef * fz * absf(rolling_fade_in) * speed_long
	var sliding_w: float = (
		absf(fx) * absf(angular_velocity_rad_s * radius - v_long) + absf(fy) * absf(v_lat)
	)

	_step_tire_state(delta, rolling_w, sliding_w, maxf(air_speed, wheel_surface_speed))

	var strut_up: Vector3 = global_transform.basis.orthonormalized().y
	var strut_extra_n: float = suspension_force_n - normal_load_n + _stop_force_n

	var total_force: Vector3 = (
		(contact_normal * normal_load_n) + (strut_up * strut_extra_n)
		+ (wheel_forward * longitudinal_force_n) + (wheel_right * lateral_force_n)
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


func _step_hub(chassis: RigidBody3D, delta: float) -> void:
	var config: SuspensionConfig = suspension_config

	if not _hub_started:
		_hub_started = true
		spring_displacement = 0.0

		if is_grounded:
			spring_displacement = minf(_ground.displacement, config.suspension_rest_length)

	var squash: float = 0.0
	if is_grounded:
		squash = maxf(_ground.displacement - spring_displacement, 0.0)

	var tire_force: float = tire_stiffness_n_m() * squash
	var spring_force: float = (
		config.wheel_rate() * spring_displacement
		+ config.bump_stop_force(spring_displacement) + arb_force_n
	)

	var damper_rate: float = config.wheel_bump()
	if absf(_hub_speed) > 0.001:
		damper_rate = config.damper_force(_hub_speed) / _hub_speed

	var mass: float = maxf(config.unsprung_mass, 1.0)
	var speed: float = (
		(_hub_speed + delta * (tire_force - spring_force) / mass)
		/ (1.0 + delta * damper_rate / mass)
	)

	var displacement: float = spring_displacement + delta * speed

	var travel: float = config.suspension_rest_length

	var needed: float = _rim_room(chassis, delta)
	if is_grounded and needed > minf(displacement, travel):
		displacement = minf(needed, travel)
		speed = maxf(speed, 0.0)

		var share: float = chassis.mass * mass_fraction
		var leftover: float = needed - travel
		if leftover > 0.0:
			var up: Vector3 = global_transform.basis.orthonormalized().y
			var at: Vector3 = hub_world_position() - chassis.global_position
			chassis.apply_impulse(up * (share * leftover / delta), at)

	_stop_force_n = 0.0
	if displacement < 0.0:
		displacement = 0.0
		speed = maxf(speed, 0.0)
	elif displacement > travel:
		displacement = travel
		speed = minf(speed, 0.0)

		_stop_force_n = maxf(tire_force - spring_force, 0.0)

	spring_displacement = displacement
	_hub_speed = speed

	_tire_squash = 0.0
	if is_grounded:
		_tire_squash = maxf(_ground.displacement - displacement, 0.0)


func _rim_room(chassis: RigidBody3D, delta: float) -> float:
	var up: Vector3 = global_transform.basis.orthonormalized().y
	var com: Vector3 = chassis.to_global(chassis.center_of_mass)
	var mount_velocity: Vector3 = (chassis.linear_velocity + chassis.angular_velocity.cross(
			global_position - com
		))

	var coming_down: float = maxf(-mount_velocity.dot(up), 0.0)

	var limit: float = suspension_config.max_squash_m()
	var needed: float = _ground.displacement + coming_down * delta - limit

	var travel: float = suspension_config.suspension_rest_length
	var past: float = maxf(_ground.displacement - travel - limit, 0.0)
	needed -= maxf(past - RIM_PUSH_OUT_MPS * delta, 0.0)

	return needed


func _lateral_hold(
	delta: float,
	v_lat: float,
	v_long: float,
	fz: float,
	lean: float,
	mass_share: float,
) -> float:
	var peak: float = tire_model.peak_lateral_force_n(fz, grip_scale(), lean)
	if peak <= 1.0:
		_stick_y = 0.0
		return 0.0

	var reach: float = maxf(tire_model.stick_deflection_m, peak * delta * delta / mass_share)
	var stiffness: float = peak / reach

	var damping: float = 2.0 * tire_model.stick_damping_ratio * sqrt(stiffness * mass_share)
	damping = minf(damping, 0.9 * mass_share / delta)

	var fade: float = absf(v_long) * delta / maxf(tire_model.relaxation_length_m(), 0.01)
	_stick_y = clampf((_stick_y + v_lat * delta) / (1.0 + fade), -reach, reach)

	return clampf(-(stiffness * _stick_y + damping * v_lat), -peak, peak)


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

	var peak: float = tire_model.peak_longitudinal_force_n(fz, grip_scale())
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

	compression = spring_displacement / suspension_config.suspension_rest_length

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

	_stick_y = 0.0

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
