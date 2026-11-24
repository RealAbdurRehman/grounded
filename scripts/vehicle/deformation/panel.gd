class_name PanelDamage
extends RefCounted

const SPRING: float = 90.0
const SETTLE: float = 7.0

const MIN_LOAD_SHARE: float = 0.4
const STRENGTH_SPREAD: float = 0.12

const HISTORY_TICKS: int = 12

const SLOWED_RATIO: float = 1.2
const SLOWED_SLACK_MPS: float = 1.0

const MIDDLE_M: float = 0.2

const SHARDS: int = 40
const SHARD_LIFE_S: float = 1.6


class PanelState extends RefCounted:
	var def: CarPanel

	var nodes: Array[MeshInstance3D] = []
	var rest: Array[Transform3D] = []
	var to_car: Array[Transform3D] = []

	var bounds: AABB

	var wear: float = 0.0
	var pushed: float = 0.0

	var strength: float = 1.0

	var target: float = 0.0
	var angle: float = 0.0

	var velocity: float = 0.0
	var shown: float = 0.0

	var broken: bool = false

	var chosen: bool = false
	var pivot: Vector3 = Vector3.ZERO

	var swing_sign: float = 1.0
	var droop_sign: float = 1.0


var panels: Array[PanelState] = []

var _car: RigidBody3D
var _random := RandomNumberGenerator.new()

var _history: PackedVector3Array = PackedVector3Array()
var _head: int = 0


func _init(car: RigidBody3D, model: Node3D, definitions: Array[CarPanel]) -> void:
	_car = car

	_random.randomize()
	_history.resize(HISTORY_TICKS)

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
			state.to_car.append(from_car * piece.get_parent().global_transform)

			var box: AABB = from_car * piece.global_transform * piece.mesh.get_aabb()
			state.bounds = box if not box_set else state.bounds.merge(box)
			box_set = true

		if state.nodes.is_empty():
			continue

		state.strength = _roll_strength()
		panels.append(state)


func on_crash(points: PackedVector3Array, push: Vector3, delta_v: float) -> void:
	delta_v = minf(delta_v, _slowed_by() * SLOWED_RATIO + SLOWED_SLACK_MPS)

	for state in panels:
		if state.broken:
			continue

		var def: CarPanel = state.def

		var nearest: float = INF
		for point in points:
			nearest = minf(nearest, _distance_to(state.bounds, point, def.reach_m))

		if nearest >= 1.0:
			continue

		var facing: float = 1.0
		if def.load_direction != Vector3.ZERO:
			facing = def.load_floor + (1.0 - def.load_floor) * maxf(
				push.dot(def.load_direction.normalized()),
				0.0,
			)

		var panel_load: float = delta_v * (1.0 - nearest * nearest) * facing
		if panel_load < def.start_mps * MIN_LOAD_SHARE:
			continue

		state.wear += panel_load * panel_load
		_aim(state, push, points)


func on_piece_pushed(piece_name: String, impulse_ns: float) -> void:
	for state in panels:
		if state.def.touch_piece != piece_name or state.def.touch_limit_ns <= 0.0:
			continue

		state.pushed += impulse_ns

		var share: float = clampf(state.pushed / state.def.touch_limit_ns, 0.0, 1.0)
		_swing_towards(state, share)


func step(delta: float) -> void:
	_history[_head] = _car.linear_velocity
	_head = (_head + 1) % HISTORY_TICKS

	for state in panels:
		if state.def.kind == CarPanel.Kind.GLASS:
			continue

		state.velocity += (state.target - state.angle) * SPRING * delta
		state.velocity *= exp(-SETTLE * delta)
		state.angle += state.velocity * delta

		if absf(state.angle - state.shown) > 0.0003:
			_swing(state, state.angle)
			state.shown = state.angle


func repair() -> void:
	for state in panels:
		state.wear = 0.0
		state.pushed = 0.0
		state.strength = _roll_strength()

		state.target = 0.0
		state.angle = 0.0

		state.velocity = 0.0
		state.shown = 0.0

		state.chosen = false

		for i in range(state.nodes.size()):
			if is_instance_valid(state.nodes[i]):
				state.nodes[i].transform = state.rest[i]

		if state.broken:
			state.broken = false

			for node in state.nodes:
				if is_instance_valid(node):
					node.visible = true


func _aim(state: PanelState, push: Vector3, points: PackedVector3Array) -> void:
	var def: CarPanel = state.def
	var felt: float = sqrt(state.wear) / state.strength

	if def.kind == CarPanel.Kind.GLASS:
		if felt >= def.full_mps:
			_break(state, push)

		return

	var share: float = clampf(
		(felt - def.start_mps) / maxf(def.full_mps - def.start_mps, 0.001),
		0.0,
		1.0,
	)

	if def.kind == CarPanel.Kind.HANGING and share > 0.0 and not state.chosen:
		_let_go_of_one_end(state, points)

	_swing_towards(state, share)


func _let_go_of_one_end(state: PanelState, points: PackedVector3Array) -> void:
	var def: CarPanel = state.def

	var hit_x: float = 0.0
	for point in points:
		hit_x += point.x

	hit_x /= float(maxi(points.size(), 1))

	var near_a: float = absf(hit_x - def.hinge_point.x)
	var near_b: float = absf(hit_x - def.other_end_point.x)

	var a_lets_go: bool = near_a < near_b
	if absf(near_a - near_b) < MIDDLE_M:
		a_lets_go = _random.randf() < 0.5

	var loose: Vector3 = def.hinge_point if a_lets_go else def.other_end_point
	state.pivot = def.other_end_point if a_lets_go else def.hinge_point

	var loose_side: float = signf(loose.x - state.pivot.x)
	var outward: float = signf(state.bounds.get_center().z)

	state.swing_sign = -loose_side * outward
	state.droop_sign = -loose_side
	state.chosen = true


func _swing_towards(state: PanelState, share: float) -> void:
	var wanted: float = deg_to_rad(state.def.max_angle_deg) * share
	if absf(wanted) > absf(state.target):
		state.target = wanted


func _swing(state: PanelState, angle: float) -> void:
	var def: CarPanel = state.def

	var turn: Basis
	var about: Vector3 = def.hinge_point

	if def.kind == CarPanel.Kind.HANGING:
		if not state.chosen:
			return

		var droop: float = angle * (def.droop_deg / maxf(def.max_angle_deg, 0.001)) * state.droop_sign
		turn = Basis(Vector3.BACK, droop) * Basis(Vector3.UP, angle * state.swing_sign)
		about = state.pivot
	else:
		turn = Basis(def.hinge_axis.normalized(), angle)

	var pose := Transform3D(turn, about - turn * about)

	for i in range(state.nodes.size()):
		if is_instance_valid(state.nodes[i]):
			state.nodes[i].transform = state.to_car[i].affine_inverse() * pose * state.to_car[i] * state.rest[
				i
			]


func _break(state: PanelState, push: Vector3) -> void:
	state.broken = true

	var shown: bool = false
	for node in state.nodes:
		if is_instance_valid(node) and node.is_visible_in_tree():
			shown = true
			node.visible = false

	if shown:
		_scatter(state, push)


func _scatter(state: PanelState, push: Vector3) -> void:
	var world: Node = _car.get_parent()
	if world == null:
		return

	var middle: Vector3 = state.bounds.get_center()
	var outward: Vector3 = (middle - _car.center_of_mass).normalized()

	var shards := CPUParticles3D.new()
	shards.emitting = false
	shards.one_shot = true

	shards.amount = SHARDS
	shards.lifetime = SHARD_LIFE_S

	shards.explosiveness = 1.0

	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)

	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.albedo_color = Color(0.78, 0.9, 0.95, 0.75)

	quad.material = paint

	shards.mesh = quad

	shards.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	shards.emission_box_extents = state.bounds.size * 0.5

	shards.direction = _car.global_basis * (outward - push * 0.4).normalized()

	shards.spread = 55.0
	shards.initial_velocity_min = 1.0
	shards.initial_velocity_max = 4.5

	shards.gravity = Vector3(0.0, -9.8, 0.0)

	shards.angular_velocity_min = -540.0
	shards.angular_velocity_max = 540.0

	shards.scale_amount_min = 0.6
	shards.scale_amount_max = 1.8

	world.add_child(shards)
	shards.global_position = _car.to_global(middle)
	shards.emitting = true

	_car.get_tree().create_timer(SHARD_LIFE_S + 0.5).timeout.connect(shards.queue_free)


func _slowed_by() -> float:
	var before: Vector3 = _history[_head]
	return (before - _car.linear_velocity).length()


func _roll_strength() -> float:
	return _random.randf_range(1.0 - STRENGTH_SPREAD, 1.0 + STRENGTH_SPREAD)


func _distance_to(box: AABB, point: Vector3, reach: Vector3) -> float:
	var over: Vector3 = (point - box.get_center()).abs() - box.size * 0.5
	over = Vector3(maxf(over.x, 0.0), maxf(over.y, 0.0), maxf(over.z, 0.0))

	return Vector3(over.x / reach.x, over.y / reach.y, over.z / reach.z).length()
