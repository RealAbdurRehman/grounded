class_name ObstacleSolver
extends RefCounted

## Times the solver runs each step.
const ITERATIONS: int = 4

## How much the tire grips when rubbing a rasied surface.
const FRICTION: float = 0.7

## How far the tire can sink into a wall before being pushed out.
const SLOP_M: float = 0.004

const SPRING_DEPTH_M: float = 0.025

const PUSH_RATE: float = 0.2
const MAX_PUSH_SPEED: float = 1.5

const DEBUG_SCALE: float = 1.0 / 3500.0


## A loose body that a tire is touching.
class Obstacle:
	var state: PhysicsDirectBodyState3D

	var inverse_mass: float = 0.0
	var inverse_inertia: Basis = Basis()

	var center: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var spin: Vector3 = Vector3.ZERO


## One place a tire touches something.
class Row:
	var wheel: Wheel
	var obstacle: Obstacle

	var slot: int = 0

	var point: Vector3 = Vector3.ZERO
	var from_center: Vector3 = Vector3.ZERO
	var from_hub: Vector3 = Vector3.ZERO
	var from_obstacle: Vector3 = Vector3.ZERO

	var up: Vector3 = Vector3.UP
	var normal: Vector3 = Vector3.UP

	var spin_axis: Vector3 = Vector3.RIGHT

	var slide_a: Vector3 = Vector3.RIGHT
	var slide_b: Vector3 = Vector3.FORWARD

	var gap: float = 0.0
	var friction: float = 0.0

	var mass_a: float = 0.0
	var mass_b: float = 0.0
	var mass_normal: float = 0.0

	var push_a: float = 0.0
	var push_b: float = 0.0
	var push_normal: float = 0.0


var _rows: Array[Row] = []
var _obstacles: Dictionary[RID, Obstacle] = { }

var _hub_speed_change: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _wheel_spin_change: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

var _inverse_mass: float = 0.0
var _inverse_inertia: Basis = Basis()

var _velocity: Vector3 = Vector3.ZERO
var _spin: Vector3 = Vector3.ZERO


func solve(chassis: RigidBody3D, wheels: Array[Wheel], delta: float) -> void:
	_rows.clear()
	_obstacles.clear()

	var center: Vector3 = chassis.to_global(chassis.center_of_mass)

	for slot in range(wheels.size()):
		var wheel: Wheel = wheels[slot]
		wheel.obstacle_impulse_n_s = Vector3.ZERO

		_hub_speed_change[slot] = 0.0
		_wheel_spin_change[slot] = 0.0

		for i in range(wheel.collider.count):
			_rows.append(_make_row(wheel, slot, i, center, chassis))

	if _rows.is_empty():
		return

	_inverse_mass = 1.0 / maxf(chassis.mass, 0.001)
	_inverse_inertia = chassis.get_inverse_inertia_tensor()

	_velocity = chassis.linear_velocity
	_spin = chassis.angular_velocity

	for row in _rows:
		_prepare(row)

	for iteration in range(ITERATIONS):
		for row in _rows:
			_keep_out(row, delta)
			_rub(row)

	_hand_back(chassis, delta)


func _make_row(wheel: Wheel, slot: int, i: int, center: Vector3, chassis: RigidBody3D) -> Row:
	var row := Row.new()
	row.wheel = wheel

	row.slot = slot

	row.point = wheel.collider.points[i]
	row.from_center = row.point - center
	row.from_hub = row.point - wheel.hub_world_position()

	row.up = wheel.global_transform.basis.orthonormalized().y
	row.normal = wheel.collider.normals[i]

	row.spin_axis = wheel.spin_axis(chassis)

	row.gap = wheel.collider.gaps[i]
	row.friction = FRICTION * wheel.friction_coef

	row.obstacle = _obstacle_for(wheel.collider.bodies[i])

	if row.obstacle != null:
		row.from_obstacle = row.point - row.obstacle.center

	return row


func _obstacle_for(rid: RID) -> Obstacle:
	if not rid.is_valid():
		return null

	if _obstacles.has(rid):
		return _obstacles[rid]

	var mode: PhysicsServer3D.BodyMode = PhysicsServer3D.body_get_mode(rid)
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(rid)
	if mode == PhysicsServer3D.BODY_MODE_STATIC or state == null:
		_obstacles[rid] = null

		return null

	var obstacle := Obstacle.new()
	obstacle.state = state
	obstacle.center = state.transform * state.center_of_mass_local
	obstacle.velocity = state.linear_velocity
	obstacle.spin = state.angular_velocity

	if mode == PhysicsServer3D.BODY_MODE_RIGID or mode == PhysicsServer3D.BODY_MODE_RIGID_LINEAR:
		obstacle.inverse_mass = state.inverse_mass
		obstacle.inverse_inertia = state.inverse_inertia_tensor

	_obstacles[rid] = obstacle

	return obstacle


func _prepare(row: Row) -> void:
	var sliding: Vector3 = _relative_velocity(row)
	sliding -= row.normal * row.normal.dot(sliding)

	if sliding.length_squared() < 0.0001:
		sliding = row.normal.cross(Vector3.UP)

		if sliding.length_squared() < 0.0001:
			sliding = row.normal.cross(Vector3.RIGHT)

	row.slide_a = sliding.normalized()
	row.slide_b = row.normal.cross(row.slide_a).normalized()

	row.mass_normal = 1.0 / _give(row, row.normal)
	row.mass_a = 1.0 / _give(row, row.slide_a)
	row.mass_b = 1.0 / _give(row, row.slide_b)


func _keep_out(row: Row, delta: float) -> void:
	var approach: float = row.normal.dot(_relative_velocity(row))

	var wanted: float = 0.0
	if row.gap > 0.0:
		wanted = -row.gap / delta
	elif -row.gap > SLOP_M:
		var depth: float = -row.gap - SLOP_M
		var spring: float = row.wheel.suspension_config.tire_stiffness * minf(depth, SPRING_DEPTH_M)
		var beyond: float = PUSH_RATE * maxf(depth - SPRING_DEPTH_M, 0.0) / delta

		wanted = minf(spring * delta / row.mass_normal + beyond, MAX_PUSH_SPEED)

	var total: float = maxf(row.push_normal + (wanted - approach) * row.mass_normal, 0.0)

	_push(row, row.normal, total - row.push_normal)
	row.push_normal = total


func _rub(row: Row) -> void:
	var limit: float = row.friction * row.push_normal
	if limit <= 0.0:
		return

	var along_a: float = row.slide_a.dot(_relative_velocity(row))
	var total_a: float = clampf(row.push_a - along_a * row.mass_a, -limit, limit)

	_push(row, row.slide_a, total_a - row.push_a)
	row.push_a = total_a

	var along_b: float = row.slide_b.dot(_relative_velocity(row))
	var total_b: float = clampf(row.push_b - along_b * row.mass_b, -limit, limit)

	_push(row, row.slide_b, total_b - row.push_b)
	row.push_b = total_b


func _relative_velocity(row: Row) -> Vector3:
	var hub_speed: float = row.wheel.hub_speed() + _hub_speed_change[row.slot]
	var wheel_spin: float = row.wheel.angular_velocity_rad_s + _wheel_spin_change[row.slot]

	var moving: Vector3 = (
		_velocity + _spin.cross(row.from_center) + row.up * hub_speed
		+ (row.spin_axis * wheel_spin).cross(row.from_hub)
	)

	var obstacle: Obstacle = row.obstacle
	if obstacle != null:
		moving -= obstacle.velocity + obstacle.spin.cross(row.from_obstacle)

	return moving


func _give(row: Row, direction: Vector3) -> float:
	var vertical: float = direction.dot(row.up)
	var to_car: Vector3 = direction - row.up * vertical

	var lever: Vector3 = row.from_center.cross(direction)
	var lever_car: Vector3 = row.from_center.cross(to_car)
	var wheel_turn: float = row.spin_axis.dot(row.from_hub.cross(direction))

	var give: float = (
		direction.dot(to_car) * _inverse_mass + lever.dot(_inverse_inertia * lever_car)
		+ vertical * vertical / maxf(row.wheel.suspension_config.unsprung_mass, 1.0)
		+ wheel_turn * wheel_turn / maxf(row.wheel.spin_inertia, 0.01)
	)

	var obstacle: Obstacle = row.obstacle
	if obstacle != null:
		var lever_obstacle: Vector3 = row.from_obstacle.cross(direction)
		var turn_obstacle: Vector3 = obstacle.inverse_inertia * lever_obstacle
		give += obstacle.inverse_mass + lever_obstacle.dot(turn_obstacle)

	return maxf(give, 0.000001)


func _push(row: Row, direction: Vector3, amount: float) -> void:
	if amount == 0.0:
		return

	var vertical: float = direction.dot(row.up)
	var to_car: Vector3 = direction - row.up * vertical

	_velocity += to_car * (amount * _inverse_mass)
	_spin += _inverse_inertia * (row.from_center.cross(to_car) * amount)

	var hub_mass: float = maxf(row.wheel.suspension_config.unsprung_mass, 1.0)
	_hub_speed_change[row.slot] += vertical * amount / hub_mass

	var turn: float = row.spin_axis.dot(row.from_hub.cross(direction))
	_wheel_spin_change[row.slot] += turn * amount / maxf(row.wheel.spin_inertia, 0.01)

	var obstacle: Obstacle = row.obstacle
	if obstacle != null:
		obstacle.velocity -= direction * (amount * obstacle.inverse_mass)
		obstacle.spin -= obstacle.inverse_inertia * (row.from_obstacle.cross(direction) * amount)

	row.wheel.obstacle_impulse_n_s += direction * amount


func _hand_back(chassis: RigidBody3D, delta: float) -> void:
	var handed: Dictionary[Wheel, bool] = { }

	for row in _rows:
		var total: Vector3 = (
			row.normal * row.push_normal + row.slide_a * row.push_a + row.slide_b * row.push_b
		)

		var to_car: Vector3 = total - row.up * total.dot(row.up)
		if not to_car.is_zero_approx():
			chassis.apply_impulse(to_car, row.point - chassis.global_position)

		if row.obstacle != null and not total.is_zero_approx():
			var state: PhysicsDirectBodyState3D = row.obstacle.state
			state.apply_impulse(-total, row.point - state.transform.origin)

		if not handed.has(row.wheel):
			handed[row.wheel] = true

			row.wheel.kick_hub(_hub_speed_change[row.slot])
			row.wheel.kick_spin(_wheel_spin_change[row.slot])

		DebugDraw3D.draw_vector(row.point, total / delta * DEBUG_SCALE, Color.YELLOW, chassis)
