class_name PanelDamage
extends RefCounted

const PANEL_LAYER: int = 1 << 19
const WORLD_MASK: int = 1

const HINGE_SPREAD: float = 0.6
const CLIP_SPREAD: float = 0.85
const GRIP_SPREAD: float = 0.25

const MIN_LOAD_SHARE: float = 0.4
const LOAD_JITTER: float = 0.2

const CRUMPLED_AT: float = 2.5

const HISTORY_TICKS: int = 12

const SLOWED_RATIO: float = 1.2
const SLOWED_SLACK_MPS: float = 1.0

const CARRY_SHARE: float = 0.5
const POP_SHARE: float = 0.12

const STRAY_M: float = 3.0

const CLOSED_SLACK_DEG: float = 3.0

const SPRING_SAG_RAD: float = 0.075
const SPRING_PROP_RAD: float = 0.1
const SPRING_DAMPING: float = 1.0

const AIR_DRAG_COEF: float = 1.2
const AIR_MIN_MPS: float = 3.0

const AIR_TEAR_N_PER_KG: float = 120.0
const AIR_TEAR_S: float = 0.2

const SKID_MIN_FROM_MIDDLE_M: float = 0.8
const SKID_MIN_DROP_M: float = 0.03

const SKID_SLOPE: float = 1.0
const SKID_SIDE_INSET_M: float = 0.05


class Mount extends RefCounted:
	var point: Vector3
	var on_panel: Vector3

	var is_hinge: bool = false

	var grip_mps: float = 10.0
	var wear: float = 0.0

	var broken: bool = false


class PanelState extends RefCounted:
	var def: CarPanel

	var nodes: Array[MeshInstance3D] = []
	var rest: Array[Transform3D] = []
	var offsets: Array[Transform3D] = []

	var bounds: AABB
	var mounts: Array[Mount] = []

	var wear: float = 0.0
	var fold: float = 0.0
	var jam: float = 1.0

	var pushed: float = 0.0
	var strength: float = 1.0

	var broken: bool = false

	var body: RigidBody3D
	var joint: Generic6DOFJoint3D

	var springy: bool = false

	var face: Vector3 = Vector3.UP
	var area_m2: float = 0.0

	var air_s: float = 0.0

	var spring_axis: Vector3
	var spring_sign: float = 1.0

	var spring_target: float = 0.0
	var spring_damping: float = 0.0
	var spring_stiffness: float = 0.0


var panels: Array[PanelState] = []

var _car: RigidBody3D
var _vehicle: Vehicle
var _random := RandomNumberGenerator.new()

var _history: PackedVector3Array = PackedVector3Array()
var _head: int = 0


func _init(car: RigidBody3D, model: Node3D, definitions: Array[CarPanel]) -> void:
	_car = car
	_vehicle = car as Vehicle

	_random.randomize()
	_history.resize(HISTORY_TICKS)
	_car.tree_exiting.connect(_free_all)

	if model == null:
		return

	var from_car: Transform3D = _car.global_transform.affine_inverse()

	for def in definitions:
		var state := PanelState.new()
		state.def = def

		var box_set: bool = false
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var piece := node as MeshInstance3D

			if piece.mesh == null or not def.matches(piece):
				continue

			state.nodes.append(piece)
			state.rest.append(piece.transform)

			var box: AABB = from_car * piece.global_transform * piece.mesh.get_aabb()
			state.bounds = box if not box_set else state.bounds.merge(box)

			box_set = true

		if state.nodes.is_empty():
			continue

		state.strength = _roll_strength()

		if def.kind != CarPanel.Kind.GLASS:
			_make_mounts(state)

		panels.append(state)


func on_crash(points: PackedVector3Array, push: Vector3, delta_v: float) -> void:
	delta_v = minf(delta_v, _slowed_by().length() * SLOWED_RATIO + SLOWED_SLACK_MPS)

	for state in panels:
		if state.broken:
			continue

		var facing: float = _facing(state.def, push)
		if state.def.kind == CarPanel.Kind.GLASS:
			_hit_glass(state, points, delta_v, facing)
		else:
			_hit_panel(state, points, delta_v, facing)


func on_piece_pushed(piece_name: String, impulse_ns: float) -> void:
	for state in panels:
		var def: CarPanel = state.def
		if def.touch_piece != piece_name or def.touch_limit_ns <= 0.0:
			continue

		state.pushed += impulse_ns
		if state.pushed < def.touch_limit_ns:
			continue

		var latches: Array[Mount] = []
		for mount in state.mounts:
			if not mount.is_hinge and not mount.broken:
				latches.append(mount)

		if latches.is_empty():
			continue

		for mount in latches:
			mount.broken = true

		_let_go(state, latches, minf(impulse_ns / def.mass_kg, 4.0), 1.0)


func step(delta: float) -> void:
	_history[_head] = _car.linear_velocity
	_head = (_head + 1) % HISTORY_TICKS

	for state in panels:
		if state.body == null:
			continue

		if state.springy:
			_spring(state)

		_air(state, delta)

		var wanted: Vector3 = _car.to_global(state.bounds.get_center())
		if state.joint != null and state.body.global_position.distance_to(wanted) > STRAY_M:
			_put_back(state)


func update_visuals() -> void:
	for state in panels:
		if state.body == null:
			continue

		var at: Transform3D = state.body.global_transform
		for i in range(state.nodes.size()):
			if is_instance_valid(state.nodes[i]):
				state.nodes[i].global_transform = at * state.offsets[i]


func repair() -> void:
	for state in panels:
		_free_physics(state)

		state.wear = 0.0
		state.fold = 0.0
		state.pushed = 0.0
		state.air_s = 0.0
		state.strength = _roll_strength()

		for mount in state.mounts:
			mount.broken = false
			mount.wear = 0.0
			mount.grip_mps = _roll_grip(state.def, mount.is_hinge)

		for i in range(state.nodes.size()):
			if is_instance_valid(state.nodes[i]):
				state.nodes[i].transform = state.rest[i]

		if state.broken:
			state.broken = false

			for node in state.nodes:
				if is_instance_valid(node):
					node.visible = true


func _make_mounts(state: PanelState) -> void:
	var def: CarPanel = state.def

	var middle: Vector3 = state.bounds.get_center()
	var half: Vector3 = state.bounds.size * 0.5

	if def.kind == CarPanel.Kind.HINGED:
		var edge: Vector3 = def.hinge_edge.normalized()
		var axis: Vector3 = def.hinge_axis.normalized()

		var to_edge: float = _half_length(half, edge)
		var along: float = _half_length(half, axis) * HINGE_SPREAD

		var edge_middle: Vector3 = middle + edge * to_edge

		state.mounts.append(_mount(def, edge_middle - axis * along, true))
		state.mounts.append(_mount(def, edge_middle + axis * along, true))
		state.mounts.append(_mount(def, middle - edge * to_edge, false))
	else:
		var row: Vector3 = def.clips_along.normalized()
		var span: float = _half_length(half, row) * CLIP_SPREAD

		for i in range(def.clip_count):
			var t: float = lerpf(-1.0, 1.0, float(i) / float(def.clip_count - 1))
			state.mounts.append(_mount(def, middle + row * span * t, false))


func _mount(def: CarPanel, point: Vector3, is_hinge: bool) -> Mount:
	var mount := Mount.new()

	mount.point = point
	mount.is_hinge = is_hinge
	mount.grip_mps = _roll_grip(def, is_hinge)

	return mount


func _hit_glass(
	state: PanelState,
	points: PackedVector3Array,
	delta_v: float,
	facing: float,
) -> void:
	var nearest: float = INF
	for point in points:
		nearest = minf(nearest, _distance_to_box(state.bounds, point, state.def.reach_m))

	if nearest >= 1.0:
		return

	var glass_load: float = delta_v * (1.0 - nearest * nearest) * facing
	if glass_load < state.def.break_mps * MIN_LOAD_SHARE:
		return

	state.wear += glass_load * glass_load

	if sqrt(state.wear) / state.strength >= state.def.break_mps:
		_break(state)


func _hit_panel(
	state: PanelState,
	points: PackedVector3Array,
	delta_v: float,
	facing: float,
) -> void:
	var def: CarPanel = state.def

	var gave_way: Array[Mount] = []

	for mount in state.mounts:
		if mount.broken:
			continue

		var nearest: float = INF
		for point in points:
			nearest = minf(nearest, _distance_to_point(mount.point, point, def.reach_m))

		if nearest >= 1.0:
			continue

		var panel_load: float = delta_v * (1.0 - nearest * nearest) * facing
		panel_load *= _random.randf_range(1.0 - LOAD_JITTER, 1.0 + LOAD_JITTER)

		if panel_load < mount.grip_mps * MIN_LOAD_SHARE:
			continue

		mount.wear += panel_load * panel_load
		if sqrt(mount.wear) >= mount.grip_mps:
			gave_way.append(mount)

	var near_panel: float = INF
	for point in points:
		near_panel = minf(near_panel, _distance_to_box(state.bounds, point, def.reach_m))

	if near_panel < 1.0:
		var panel_load: float = delta_v * (1.0 - near_panel * near_panel) * facing

		if panel_load > def.latch_grip_mps * MIN_LOAD_SHARE:
			state.wear += panel_load * panel_load
			state.fold = clampf(sqrt(state.wear) / (def.latch_grip_mps * CRUMPLED_AT), 0.0, 1.0)

	var held: int = 0
	for mount in state.mounts:
		if not mount.broken:
			held += 1

	if gave_way.size() >= held:
		var strongest: Mount = gave_way[0]

		for mount in gave_way:
			if mount.grip_mps - sqrt(mount.wear) > strongest.grip_mps - sqrt(strongest.wear):
				strongest = mount

		gave_way.erase(strongest)

	for mount in gave_way:
		mount.broken = true

	if not gave_way.is_empty():
		_let_go(state, gave_way, delta_v, facing)
	elif state.body != null:
		_connect(state)


func _let_go(state: PanelState, gave_way: Array[Mount], delta_v: float, facing: float) -> void:
	var def: CarPanel = state.def

	if state.body == null:
		_make_body(state)

		state.body.linear_velocity += _slowed_by() * CARRY_SHARE
		state.jam = _random.randf_range(0.5, 1.0)

	_connect(state)

	var at := Vector3.ZERO
	for mount in gave_way:
		at += state.body.global_transform * mount.on_panel

	at /= float(gave_way.size())

	var open: Vector3 = _car.global_basis * def.open_direction.normalized()
	var shove: float = def.mass_kg * delta_v * POP_SHARE * facing * _random.randf_range(0.4, 1.2)

	state.body.apply_impulse(open * shove, at - state.body.global_position)


func _make_body(state: PanelState) -> void:
	var def: CarPanel = state.def
	var world: Node = _car.get_parent()

	var body := RigidBody3D.new()

	body.mass = def.mass_kg
	body.collision_layer = PANEL_LAYER
	body.collision_mask = WORLD_MASK
	body.continuous_cd = true
	body.can_sleep = false
	body.linear_damp = 0.1
	body.angular_damp = def.swing_damping

	var paint := PhysicsMaterial.new()

	paint.friction = 0.6
	paint.bounce = 0.15
	body.physics_material_override = paint

	var middle: Vector3 = state.bounds.get_center()
	var hulls: Array[CollisionShape3D] = _hulls_of(def)

	var size: Vector3 = state.bounds.size
	state.face = def.open_direction.normalized()
	state.area_m2 = (
		absf(state.face.x) * size.y * size.z + absf(state.face.y) * size.x * size.z
		+ absf(state.face.z) * size.x * size.y
	)

	for hull in hulls:
		var shape := CollisionShape3D.new()
		shape.shape = hull.shape.duplicate()
		shape.transform = Transform3D(Basis.IDENTITY, -middle) * hull.transform

		body.add_child(shape)

	if not hulls.is_empty():
		var skid: ConvexPolygonShape3D = _skid_of(state, hulls)
		if skid != null:
			var skid_shape := CollisionShape3D.new()
			skid_shape.shape = skid
			skid_shape.transform = Transform3D(Basis.IDENTITY, -middle)

			body.add_child(skid_shape)

	if hulls.is_empty():
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()

		box.size = state.bounds.size.max(Vector3(0.04, 0.04, 0.04))
		shape.shape = box
		body.add_child(shape)

	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3.ZERO

	world.add_child(body)
	body.add_collision_exception_with(_car)

	var rigid := Transform3D(
		_car.global_basis.orthonormalized(),
		_car.to_global(state.bounds.get_center()),
	)
	body.global_transform = rigid

	state.offsets.clear()
	for node in state.nodes:
		state.offsets.append(rigid.affine_inverse() * node.global_transform)

	for mount in state.mounts:
		mount.on_panel = rigid.affine_inverse() * _car.to_global(mount.point)

	var physics: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(_car.get_rid())
	if physics != null:
		body.linear_velocity = physics.get_velocity_at_local_position(
			rigid.origin - _car.global_position
		)

	body.angular_velocity = _car.angular_velocity
	state.body = body


func _hulls_of(def: CarPanel) -> Array[CollisionShape3D]:
	var prefix: String = "Collision" + def.panel_name.replace(" ", "")
	var found: Array[CollisionShape3D] = []

	for child in _car.get_children():
		var node := child as CollisionShape3D
		if node == null or node.shape == null or not String(node.name).begins_with(prefix):
			continue

		if String(node.name).trim_prefix(prefix).is_valid_int():
			found.append(node)

	return found


func _skid_of(state: PanelState, hulls: Array[CollisionShape3D]) -> ConvexPolygonShape3D:
	var bounds: AABB = state.bounds
	var middle: Vector3 = bounds.get_center()

	if absf(middle.z - _car.center_of_mass.z) < SKID_MIN_FROM_MIDDLE_M:
		return null

	var hull_low: float = INF
	for hull in hulls:
		var convex := hull.shape as ConvexPolygonShape3D
		if convex == null:
			continue

		for point in convex.points:
			hull_low = minf(hull_low, (hull.transform * point).y)

	var bottom: float = bounds.position.y
	var drop: float = hull_low - bottom

	if drop < SKID_MIN_DROP_M:
		return null

	var outward: float = signf(middle.z - _car.center_of_mass.z)
	var z_out: float = bounds.end.z if outward > 0.0 else bounds.position.z
	var z_in: float = bounds.position.z if outward > 0.0 else bounds.end.z

	var slope: float = minf(drop * SKID_SLOPE, absf(z_out - z_in) * 0.8)
	var half: float = maxf(bounds.size.x * 0.5 - SKID_SIDE_INSET_M, 0.05)

	var points := PackedVector3Array()
	for side in [-1.0, 1.0]:
		points.append(Vector3(side * half, hull_low, z_out))
		points.append(Vector3(side * half, hull_low, z_in))
		points.append(Vector3(side * half, bottom, z_out - outward * slope))
		points.append(Vector3(side * half, bottom, z_in))

	var skid := ConvexPolygonShape3D.new()
	skid.points = points

	return skid


func _connect(state: PanelState) -> void:
	state.springy = false

	if state.joint != null:
		state.joint.free()
		state.joint = null

	var held: Array[Mount] = []
	for mount in state.mounts:
		if not mount.broken:
			held.append(mount)

	if held.is_empty():
		return

	var def: CarPanel = state.def
	var body: RigidBody3D = state.body
	var car_basis: Basis = _car.global_basis.orthonormalized()

	var open: Vector3 = car_basis * def.open_direction.normalized()

	var swing_front: float = deg_to_rad(def.swing_front_deg)
	var most: float = deg_to_rad(def.open_limit_deg)

	var stuck: float = maxf(
		deg_to_rad(def.jam_deg) * state.fold * state.jam,
		deg_to_rad(CLOSED_SLACK_DEG),
	)
	var swing_back: float = maxf(stuck, deg_to_rad(def.swing_back_deg))

	var basis: Basis = car_basis
	var pivot: Vector3

	var lowest := Vector3(-swing_front, -swing_front, -swing_front)
	var highest := Vector3(swing_front, swing_front, swing_front)
	var now := Vector3.ZERO

	if held.size() >= 2:
		var first: Mount = held[0]
		var second: Mount = held[1]
		var apart: float = -1.0

		for a in held:
			for b in held:
				var gap: float = (a.on_panel - b.on_panel).length_squared()
				if gap > apart:
					apart = gap
					first = a
					second = b

		pivot = body.global_transform * ((first.on_panel + second.on_panel) * 0.5)

		var axis: Vector3 = (body.global_basis * (second.on_panel - first.on_panel)).normalized()
		basis = _basis_along(axis)

		var opens: float = _opens(axis, body.global_position - pivot, open)

		now.x = _turned_about(axis, car_basis, body.global_basis)

		var lever: float = (body.global_position - pivot).length()
		state.springy = def.kind == CarPanel.Kind.HINGED and absf(axis.y) < 0.5 and lever > 0.05

		if state.springy:
			var weight: float = def.mass_kg * 9.8 * lever
			var inertia: float = def.mass_kg * lever * lever * 1.33

			state.spring_axis = car_basis.inverse() * axis
			state.spring_sign = 1.0 if opens >= 0.0 else -1.0

			state.spring_target = minf(stuck + SPRING_PROP_RAD, most - 0.1)
			state.spring_damping = 2.0 * SPRING_DAMPING * sqrt(state.spring_stiffness * inertia)
			state.spring_stiffness = weight / SPRING_SAG_RAD

		lowest = Vector3.ZERO
		highest = Vector3.ZERO

		if opens >= 0.0:
			lowest.x = stuck
			highest.x = most
		else:
			lowest.x = -most
			highest.x = -stuck
	else:
		pivot = body.global_transform * held[0].on_panel

		var turned: Vector3 = (
			car_basis.inverse() * body.global_basis.orthonormalized()
		).get_euler()
		var reach: Vector3 = body.global_position - pivot

		for i in range(3):
			var opens: float = _opens(basis[i], reach, open)
			now[i] = turned[i]

			if opens > 0.2:
				lowest[i] = -swing_back
			elif opens < -0.2:
				highest[i] = swing_back
			else:
				lowest[i] = -swing_back
				highest[i] = swing_back

	var world: Node = _car.get_parent()
	var joint := Generic6DOFJoint3D.new()
	world.add_child(joint)

	joint.global_transform = Transform3D(basis, pivot)
	joint.node_a = joint.get_path_to(_car)
	joint.node_b = joint.get_path_to(body)

	for i in range(3):
		var lower: float = -(highest[i] - now[i])
		var upper: float = -(lowest[i] - now[i])

		_limit(
			joint,
			i,
			Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT,
			Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT,
			Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT,
			0.0,
			0.0,
		)

		_limit(
			joint,
			i,
			Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT,
			Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT,
			Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT,
			lower,
			upper,
		)

	state.joint = joint


func _spring(state: PanelState) -> void:
	var car_basis: Basis = _car.global_basis.orthonormalized()
	var axis: Vector3 = car_basis * state.spring_axis

	var open: float = state.spring_sign * _turned_about(axis, car_basis, state.body.global_basis)
	var speed: float = state.spring_sign * (
		state.body.angular_velocity - _car.angular_velocity
	).dot(axis)

	var torque: float = state.spring_stiffness * (state.spring_target - open) - state.spring_damping * speed
	state.body.apply_torque(axis * state.spring_sign * torque)


func _air(state: PanelState, delta: float) -> void:
	var def: CarPanel = state.def
	var body: RigidBody3D = state.body

	var wind: Vector3 = Vector3.ZERO
	if _vehicle != null and _vehicle.aero != null:
		wind = _vehicle.aero.wind_mps

	var flow: Vector3 = wind - body.linear_velocity
	var speed: float = flow.length()

	if speed < AIR_MIN_MPS:
		state.air_s = maxf(state.air_s - delta, 0.0)
		return

	var normal: Vector3 = body.global_basis.orthonormalized() * state.face
	var pressure: float = 0.5 * Atmosphere.config.air_density * speed * speed

	var force: Vector3 = normal * (
		pressure * state.area_m2 * AIR_DRAG_COEF * flow.dot(normal) / speed
	)

	body.apply_force(force)

	var lifted: float = maxf(force.dot(normal), 0.0)
	if lifted <= def.mass_kg * AIR_TEAR_N_PER_KG:
		state.air_s = maxf(state.air_s - delta, 0.0)
		return

	state.air_s += delta
	if state.air_s < AIR_TEAR_S:
		return

	var torn: Array[Mount] = []
	for mount in state.mounts:
		if not mount.broken:
			mount.broken = true
			torn.append(mount)

	if not torn.is_empty():
		_let_go(state, torn, 0.0, 0.0)


func _opens(axis: Vector3, reach: Vector3, open: Vector3) -> float:
	var length: float = reach.length()
	if length < 0.01:
		return 0.0

	return axis.cross(reach).dot(open) / length


func _limit(
	joint: Generic6DOFJoint3D,
	axis: int,
	lower_param: int,
	upper_param: int,
	flag: int,
	lower: float,
	upper: float,
) -> void:
	match axis:
		0:
			joint.set_flag_x(flag, true)
			joint.set_param_x(lower_param, lower)
			joint.set_param_x(upper_param, upper)
		1:
			joint.set_flag_y(flag, true)
			joint.set_param_y(lower_param, lower)
			joint.set_param_y(upper_param, upper)
		_:
			joint.set_flag_z(flag, true)
			joint.set_param_z(lower_param, lower)
			joint.set_param_z(upper_param, upper)


func _basis_along(axis: Vector3) -> Basis:
	var other: Vector3 = Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT
	var z: Vector3 = axis.cross(other).normalized()

	return Basis(axis, z.cross(axis), z)


func _turned_about(axis: Vector3, car_basis: Basis, panel_basis: Basis) -> float:
	var turned: Quaternion = (
		car_basis.inverse() * panel_basis.orthonormalized()
	).get_rotation_quaternion()

	var about: Vector3 = car_basis.inverse() * axis
	var angle: float = 2.0 * atan2(Vector3(turned.x, turned.y, turned.z).dot(about), turned.w)

	return wrapf(angle, -PI, PI)


func _put_back(state: PanelState) -> void:
	state.body.global_transform = Transform3D(
		_car.global_basis.orthonormalized(),
		_car.to_global(state.bounds.get_center()),
	)

	state.body.linear_velocity = _car.linear_velocity
	state.body.angular_velocity = _car.angular_velocity

	_connect(state)


func _free_physics(state: PanelState) -> void:
	if state.joint != null and is_instance_valid(state.joint):
		state.joint.free()

	if state.body != null and is_instance_valid(state.body):
		state.body.free()

	state.joint = null
	state.body = null
	state.springy = false


func _free_all() -> void:
	for state in panels:
		if state.joint != null and is_instance_valid(state.joint):
			state.joint.queue_free()

		if state.body != null and is_instance_valid(state.body):
			state.body.queue_free()

		state.joint = null
		state.body = null


func _facing(def: CarPanel, push: Vector3) -> float:
	if def.load_direction == Vector3.ZERO:
		return 1.0

	return def.load_floor + (1.0 - def.load_floor) * maxf(
		push.dot(def.load_direction.normalized()),
		0.0,
	)


func _break(state: PanelState) -> void:
	state.broken = true
	for node in state.nodes:
		if is_instance_valid(node):
			node.visible = false


func _slowed_by() -> Vector3:
	return _history[_head] - _car.linear_velocity


func _roll_strength() -> float:
	return _random.randf_range(1.0 - GRIP_SPREAD, 1.0 + GRIP_SPREAD)


func _roll_grip(def: CarPanel, is_hinge: bool) -> float:
	return (def.hinge_grip_mps if is_hinge else def.latch_grip_mps) * _roll_strength()


func _half_length(half: Vector3, direction: Vector3) -> float:
	return absf(direction.x) * half.x + absf(direction.y) * half.y + absf(direction.z) * half.z


func _distance_to_point(from: Vector3, to: Vector3, reach: Vector3) -> float:
	var gap: Vector3 = (to - from).abs()
	return Vector3(gap.x / reach.x, gap.y / reach.y, gap.z / reach.z).length()


func _distance_to_box(box: AABB, point: Vector3, reach: Vector3) -> float:
	var over: Vector3 = (point - box.get_center()).abs() - box.size * 0.5
	over = Vector3(maxf(over.x, 0.0), maxf(over.y, 0.0), maxf(over.z, 0.0))

	return Vector3(over.x / reach.x, over.y / reach.y, over.z / reach.z).length()
