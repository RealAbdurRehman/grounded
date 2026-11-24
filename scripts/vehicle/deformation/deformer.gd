class_name CarDeformer
extends RefCounted

## Force it takes to crush the car.
const CRUSH_A_N_PER_M: float = 67700.0
const CRUSH_B_N_PER_M2: float = 996000.0

const RESTITUTION: float = 0.1 # 0.1 is realistic.

const MIN_WIDTH_M: float = 0.5
const MAX_WIDTH_M: float = 1.8

## How deep the car can crush on impact.
const CRUMPLE_ZONE_M: float = 0.9

## No point on the body is pushed further than this.
const MAX_OFFSET_M: float = 0.6

const BOW_SHARE: float = 0.3
const FOLD_SHARE: float = 0.1
const CRINKLE_SHARE: float = 0.25

const BROAD_LUMPS_PER_M: float = 7.0
const FINE_LUMPS_PER_M: float = 22.0
const CREASES_PER_M: float = 14.0

const BROAD_SHARE: float = 0.1
const FINE_SHARE: float = 0.5
const CREASE_SHARE: float = 0.45

## Color of the scrape marks left behind.
const SCUFF_COLOR: Color = Color(0.5, 0.48, 0.47)

const MAX_EDGE_M: float = 0.07
const MAX_SPLIT_PASSES: int = 5

const CELL_M: float = 0.25

## Rays finding how wide the collided thing is.
const PROBE_STEP_M: float = 0.25
const PROBE_STEPS_SIDE: int = 4
const PROBE_STEPS_UP: int = 2
const PROBE_LEAD_M: float = 0.4
const PROBE_TOLERANCE_M: float = 0.15

## Time spent bending metal per physics tick.
const BUDGET_USEC: int = 2000
const MAX_JOBS: int = 8

const FORGIVEN_DELTA_V_MPS: float = 3.0

const CRUSH_SHARE: float = 0.5
const SOFT_MAX_CRUSH_M: float = 0.15

const SAME_CRASH_S: float = 0.03
const SAME_CRASH_M: float = 1.2
const SAME_CRASH_ALIGNMENT: float = 0.7

# Between two dents that are close, area in the middle is pulled in too to avoid creating a point.
const BRIDGE_SHARE: float = 0.6

const SPREAD_PER_DEPTH: float = 1.4
const MAX_RADIUS_M: float = 0.7

const BRIDGE_MAX_GAP_M: float = 1.4
const BRIDGE_MIN_GAP_M: float = 0.25
const BRIDGE_ALIGNMENT: float = 0.5

const ANIMATION_S: float = 0.18

const SETTLE_S: float = 0.5

const UPLOAD_BUDGET_USEC: int = 3000

const MAX_APPLIED: int = 16

const START_AFTER_TICKS: int = 30

const WELD_BIAS: int = 1 << 19
const WELD_SPAN: int = 1 << 20


class Piece extends RefCounted:
	var node: MeshInstance3D
	var mesh: ArrayMesh
	var material: Material

	var to_car: Transform3D
	var from_car: Transform3D
	var turn: Quaternion

	var bounds: AABB

	var stage: int = 0
	var passes: int = 0

	var ready: bool = false
	var skip: bool = false
	var dirty: bool = false
	var deformed: bool = false

	var busy: bool = false
	var task: int = -1

	var shown_pos: PackedVector3Array
	var shown_normal: PackedVector3Array
	var shown_tangent: PackedFloat32Array

	var anim_pos: PackedVector3Array
	var anim_normal: PackedVector3Array
	var anim_tangent: PackedFloat32Array

	var waiting: bool = false
	var animating: bool = false
	var progress: float = 0.0

	var rest_pos: PackedVector3Array
	var pos: PackedVector3Array

	var auth_normal: PackedVector3Array
	var normal: PackedVector3Array

	var auth_tangent: PackedFloat32Array
	var tangent: PackedFloat32Array

	var uv: PackedVector2Array
	var uv2: PackedVector2Array

	var color: PackedColorArray
	var index: PackedInt32Array

	var weld: PackedInt32Array

	var w_rest: PackedVector3Array
	var w_pos: PackedVector3Array
	var w_normal_rest: PackedVector3Array

	var w_dirt: PackedFloat32Array
	var w_rough: PackedFloat32Array

	var w_vert_start: PackedInt32Array
	var w_verts: PackedInt32Array

	var w_tri_start: PackedInt32Array
	var w_tris: PackedInt32Array

	var face: PackedVector3Array

	var w_stamp: PackedInt32Array
	var t_stamp: PackedInt32Array
	var stamp: int = 0

	var cells: Dictionary = { }


class Job extends RefCounted:
	var pieces: Array[Piece] = []
	var next: int = 0

	var push: Vector3
	var side: Vector3

	var up: Vector3
	var axis: Vector3

	var plane: float
	var crush: float
	var radius: float

	var center_side: float
	var center_up: float

	var half_side: float
	var half_up: float

	var box: AABB

	var low: Vector3i
	var high: Vector3i

	var slab: int = 0
	var started: bool = false

	var fills: bool = false


var pieces: Array[Piece] = []
var prepared: int = 0

var _car: RigidBody3D
var _all_bounds: AABB

var _queue: Array[Piece] = []
var _jobs: Array[Job] = []

var _ticks: int = 0
var _clock: float = 0.0

var _threaded: bool = OS.has_feature("threads")
var _next_prepare: int = 0

var _hits: Array[Dictionary] = []
var _first_hit: float = 0.0

var _group: int = -1
var _group_job: Job = null

var _applied: Array[Job] = []
var _recent: Array[Job] = []

var _hull_shapes: Dictionary = { }
var _hull_queue: Array[CollisionShape3D] = []

var _hull_due: bool = false
var _hull_restore: bool = false
var _last_change: float = 0.0


func _init(car: RigidBody3D, model: Node3D) -> void:
	_car = car

	if model == null:
		return

	var to_car_root: Transform3D = car.global_transform.affine_inverse()

	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D

		if mesh_node.mesh == null or mesh_node.mesh.get_surface_count() != 1:
			continue

		if not mesh_node.is_visible_in_tree():
			continue

		var piece := Piece.new()
		piece.node = mesh_node
		piece.material = mesh_node.mesh.surface_get_material(0)

		var paint := piece.material as BaseMaterial3D
		if paint != null and paint.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			paint.vertex_color_use_as_albedo = true

		piece.to_car = to_car_root * mesh_node.global_transform
		piece.from_car = piece.to_car.affine_inverse()
		piece.turn = Quaternion(piece.to_car.basis.orthonormalized())

		piece.bounds = piece.to_car * mesh_node.get_aabb()
		_all_bounds = piece.bounds if pieces.is_empty() else _all_bounds.merge(piece.bounds)

		pieces.append(piece)
		_queue.append(piece)


func step() -> void:
	_ticks += 1
	_clock += 1.0 / float(Engine.physics_ticks_per_second)

	_prepare_pieces()

	_start_crashes()
	_run_jobs()
	_slide()

	_upload_pieces()
	_follow_with_hull()


func repair() -> void:
	if _group >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_group)
		_group = -1
		_group_job = null

	_jobs.clear()
	_hits.clear()
	_applied.clear()
	_recent.clear()

	_hull_due = false
	_hull_restore = true
	_hull_queue.clear()

	for piece in pieces:
		if not piece.ready or not piece.deformed:
			continue

		piece.pos = piece.rest_pos.duplicate()
		piece.normal = piece.auth_normal.duplicate()
		piece.tangent = piece.auth_tangent.duplicate()

		piece.w_pos = piece.w_rest.duplicate()
		piece.w_dirt.fill(0.0)
		piece.color.fill(Color.WHITE)

		piece.face = _rest_faces(piece)

		piece.deformed = false
		piece.dirty = true


func dent(
	_part_name: String,
	points: PackedVector3Array,
	direction: Vector3,
	delta_v: float,
) -> void:
	if points.is_empty() or direction.is_zero_approx():
		return

	var push: Vector3 = direction.normalized()

	var middle: Vector3 = Vector3.ZERO
	for point in points:
		middle += point

	middle /= float(points.size())

	if push.dot(_car.center_of_mass - middle) < 0.0:
		push = -push

	if _hits.is_empty():
		_first_hit = _clock

	_hits.append({ "points": points, "push": push, "middle": middle, "delta_v": delta_v })


func _start_crashes() -> void:
	if _hits.is_empty() or _clock - _first_hit < SAME_CRASH_S:
		return

	var crashes: Array[Dictionary] = []

	for hit in _hits:
		var merged: bool = false

		for crash in crashes:
			if (
				(crash["push"] as Vector3).dot(hit["push"]) > SAME_CRASH_ALIGNMENT
				and (crash["middle"] as Vector3).distance_to(hit["middle"]) < SAME_CRASH_M
			):
				crash["points"] = (crash["points"] as PackedVector3Array) + (
					hit["points"] as PackedVector3Array
				)
				crash["delta_v"] += hit["delta_v"]

				merged = true
				break

		if not merged:
			crashes.append(hit.duplicate())

	_hits.clear()

	for crash in crashes:
		_start_job(crash["points"], crash["push"], crash["delta_v"])


func _start_job(points: PackedVector3Array, push: Vector3, delta_v: float) -> void:
	if _jobs.size() >= MAX_JOBS:
		return

	var touch: PackedVector3Array = _probe(points, push)

	var job := Job.new()
	job.push = push

	job.side = push.cross(Vector3.UP)
	if job.side.length_squared() < 0.01:
		job.side = Vector3.RIGHT

	job.side = job.side.normalized()
	job.up = push.cross(job.side).normalized()

	var side_low: float = INF
	var side_high: float = -INF

	var up_low: float = INF
	var up_high: float = -INF

	job.plane = INF
	job.axis = Vector3.ZERO

	for point in touch:
		var a: float = point.dot(job.side)
		var b: float = point.dot(job.up)

		side_low = minf(side_low, a)
		side_high = maxf(side_high, a)

		up_low = minf(up_low, b)
		up_high = maxf(up_high, b)

		job.plane = minf(job.plane, point.dot(push))
		job.axis += point

	job.axis /= float(touch.size())

	job.crush = _crush_m(delta_v, clampf(side_high - side_low, MIN_WIDTH_M, MAX_WIDTH_M))
	if job.crush < 0.005:
		return

	job.center_side = (side_low + side_high) * 0.5
	job.center_up = (up_low + up_high) * 0.5
	job.half_side = (side_high - side_low) * 0.5
	job.half_up = (up_high - up_low) * 0.5

	var already: float = _depth_there(job)
	job.radius = clampf(
		maxf(0.2 + 0.8 * job.crush, SPREAD_PER_DEPTH * (job.crush + already)),
		0.3,
		MAX_RADIUS_M,
	)

	_queue_job(job)
	_bridge(job)

	_recent.append(job)
	if _recent.size() > MAX_APPLIED:
		_recent.pop_front()


func _queue_job(job: Job) -> void:
	var corners: Array[Vector3] = []
	for a in [-1.0, 1.0]:
		for b in [-1.0, 1.0]:
			for c in [-0.5, 2.0]:
				corners.append(
					job.side * (job.center_side + a * (job.half_side + job.radius))
					+ job.up * (job.center_up + b * (job.half_up + job.radius))
					+ job.push * (job.plane + c * job.radius),
				)

	job.box = AABB(corners[0], Vector3.ZERO)
	for corner in corners:
		job.box = job.box.expand(corner)

	job.low = Vector3i((job.box.position / CELL_M).floor())
	job.high = Vector3i((job.box.end / CELL_M).floor())

	for piece in pieces:
		if not piece.skip and piece.bounds.intersects(job.box):
			job.pieces.append(piece)

	job.pieces.sort_custom(
		func(a: Piece, b: Piece) -> bool:
			return a.bounds.get_center().distance_squared_to(job.axis) < b \
					.bounds \
					.get_center() \
					.distance_squared_to(job.axis),
	)

	_jobs.append(job)


func _depth_there(job: Job) -> float:
	var middle: Vector3 = _rect_centre(job)
	var along: Vector3 = job.side * job.half_side

	var depth: float = 0.0
	for point in [middle, middle - along, middle + along]:
		depth = maxf(depth, (_crushed_by(point, _recent) - point).dot(job.push))

	return depth


func _rect_centre(job: Job) -> Vector3:
	return job.side * job.center_side + job.up * job.center_up + job.push * job.plane


func _rect_reach(job: Job, direction: Vector3) -> float:
	return absf(job.side.dot(direction)) * job.half_side + absf(job.up.dot(direction)) * job.half_up


func _bridge(job: Job) -> void:
	if _jobs.size() >= MAX_JOBS:
		return

	var best: Job = null
	var best_gap: float = BRIDGE_MAX_GAP_M

	for other in _recent:
		if other.push.dot(job.push) < BRIDGE_ALIGNMENT:
			continue

		var push: Vector3 = (job.push + other.push).normalized()

		var side: Vector3 = push.cross(Vector3.UP)
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT

		side = side.normalized()
		var up: Vector3 = push.cross(side).normalized()

		var between: Vector3 = _rect_centre(other) - _rect_centre(job)

		var gap: float = absf(between.dot(side)) - _rect_reach(job, side) - _rect_reach(other, side)
		var rise: float = absf(between.dot(up)) - _rect_reach(job, up) - _rect_reach(other, up)

		if gap < BRIDGE_MIN_GAP_M or gap >= best_gap or rise > 0.0:
			continue

		best = other
		best_gap = gap

	if best == null:
		return

	var bridge := Job.new()
	bridge.fills = true

	bridge.push = (job.push + best.push).normalized()

	bridge.side = bridge.push.cross(Vector3.UP)
	if bridge.side.length_squared() < 0.01:
		bridge.side = Vector3.RIGHT

	bridge.side = bridge.side.normalized()
	bridge.up = bridge.push.cross(bridge.side).normalized()

	var a: Vector3 = _rect_centre(job)
	var b: Vector3 = _rect_centre(best)

	bridge.axis = (a + b) * 0.5
	bridge.plane = minf(a.dot(bridge.push), b.dot(bridge.push))

	var a_side: float = a.dot(bridge.side)
	var b_side: float = b.dot(bridge.side)

	var inner_a: float = a_side + _rect_reach(job, bridge.side) * signf(b_side - a_side)
	var inner_b: float = b_side + _rect_reach(best, bridge.side) * signf(a_side - b_side)

	bridge.center_side = (inner_a + inner_b) * 0.5
	bridge.half_side = absf(inner_a - inner_b) * 0.5

	var low: float = minf(
		a.dot(bridge.up) - _rect_reach(job, bridge.up),
		b.dot(bridge.up) - _rect_reach(best, bridge.up),
	)
	var high: float = maxf(
		a.dot(bridge.up) + _rect_reach(job, bridge.up),
		b.dot(bridge.up) + _rect_reach(best, bridge.up),
	)

	bridge.center_up = (low + high) * 0.5
	bridge.half_up = (high - low) * 0.5

	bridge.crush = BRIDGE_SHARE * 0.5 * (job.crush + best.crush)
	bridge.radius = minf(job.radius, best.radius)

	_queue_job(bridge)


func _probe(points: PackedVector3Array, push: Vector3) -> PackedVector3Array:
	var space: PhysicsDirectSpaceState3D = _car.get_world_3d().direct_space_state
	if space == null:
		return points

	var side: Vector3 = push.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT

	side = side.normalized()
	var up: Vector3 = push.cross(side).normalized()

	var plane: float = INF
	var middle: Vector3 = Vector3.ZERO

	for point in points:
		plane = minf(plane, point.dot(push))
		middle += point

	middle /= float(points.size())
	var base: Vector3 = middle + push * (plane - middle.dot(push))

	var found: PackedVector3Array = points.duplicate()

	var inside: AABB = _all_bounds.grow(0.1)
	var skip: Array[RID] = [_car.get_rid()]

	for i in range(-PROBE_STEPS_SIDE, PROBE_STEPS_SIDE + 1):
		for j in range(-PROBE_STEPS_UP, PROBE_STEPS_UP + 1):
			var spot: Vector3 = base + side * (float(i) * PROBE_STEP_M) + up * (
				float(j) * PROBE_STEP_M
			)

			if not inside.has_point(spot):
				continue

			var from: Vector3 = _car.to_global(spot + push * PROBE_LEAD_M)
			var to: Vector3 = _car.to_global(spot - push * PROBE_LEAD_M)

			var query := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, skip)
			var hit: Dictionary = space.intersect_ray(query)
			if hit.is_empty():
				continue

			var hit_at: Vector3 = _car.to_local(hit["position"])
			if absf(hit_at.dot(push) - plane) <= PROBE_TOLERANCE_M:
				found.append(hit_at)

	return found


func _crush_m(delta_v: float, width_m: float) -> float:
	var felt: float = delta_v - FORGIVEN_DELTA_V_MPS
	if felt <= 0.0:
		return 0.0

	var approach: float = felt / (1.0 + RESTITUTION)
	var energy: float = 0.5 * _car.mass * approach * approach * (1.0 - RESTITUTION * RESTITUTION)

	var per_width: float = energy / width_m

	var threshold: float = CRUSH_A_N_PER_M * CRUSH_A_N_PER_M / (2.0 * CRUSH_B_N_PER_M2)
	if per_width <= threshold:
		return 0.0

	var crush: float = (sqrt(2.0 * CRUSH_B_N_PER_M2 * per_width) - CRUSH_A_N_PER_M) / CRUSH_B_N_PER_M2

	var shown: float = crush * CRUSH_SHARE
	return SOFT_MAX_CRUSH_M * (1.0 - exp(-shown / SOFT_MAX_CRUSH_M))


func _work() -> void:
	var stop: int = Time.get_ticks_usec() + BUDGET_USEC

	while not _jobs.is_empty() and Time.get_ticks_usec() < stop:
		var job: Job = _jobs[0]

		if job.next >= job.pieces.size():
			_finish_job(_jobs.pop_front())
			continue

		var piece: Piece = job.pieces[job.next]

		if not piece.ready:
			_prepare(piece)

		if not job.started:
			job.started = true
			job.slab = job.low.x

		if piece.ready:
			_dent_slab(piece, job, job.slab)

		job.slab += 1

		if job.slab > job.high.x or not piece.ready:
			job.next += 1
			job.started = false

			if piece.deformed:
				piece.dirty = true


func _dent_slab(piece: Piece, job: Job, x: int) -> void:
	var radius_squared: float = job.radius * job.radius
	var scuff: float = 0.0 if job.fills else clampf(job.crush * 5.0, 0.0, 1.0)

	var moved := PackedInt32Array()

	for y in range(job.low.y, job.high.y + 1):
		for z in range(job.low.z, job.high.z + 1):
			var list: Variant = piece.cells.get(Vector3i(x, y, z))
			if list == null:
				continue

			for w in list:
				var rest: Vector3 = piece.w_rest[w]

				var behind: float = maxf(rest.dot(job.push) - job.plane, 0.0)
				var spread: float = 1.0 - behind / CRUMPLE_ZONE_M
				if spread <= 0.0:
					continue

				var across: float = maxf(
					absf(rest.dot(job.side) - job.center_side) - job.half_side,
					0.0,
				)
				var over: float = maxf(absf(rest.dot(job.up) - job.center_up) - job.half_up, 0.0)

				var gap: float = across * across + over * over + behind * behind * 0.25
				if gap >= radius_squared:
					continue

				var fall: float = 1.0 - gap / radius_squared
				var weight: float = fall * fall

				var give: float = job.crush * spread * weight

				var offset: Vector3 = piece.w_pos[w] - rest
				if job.fills:
					give = maxf(give - maxf(offset.dot(job.push), 0.0), 0.0)

				if give < 0.0005:
					continue

				give *= 1.0 - 0.5 * offset.length() / MAX_OFFSET_M

				var parallel: float = 1.0 - absf(piece.w_normal_rest[w].dot(job.push))

				var away: Vector3 = rest - job.axis
				away -= job.push * away.dot(job.push)

				var bow: Vector3 = away.normalized() * clampf(away.length() / 0.3, 0.0, 1.0)
				var rough: float = piece.w_rough[w * 2]
				var fold: float = 1.0 + piece.w_rough[w * 2 + 1] * FOLD_SHARE

				offset += job.push * (give * (1.0 + rough * CRINKLE_SHARE))
				offset += bow * (give * BOW_SHARE * parallel * fold)

				if offset.length() > MAX_OFFSET_M:
					offset = offset.normalized() * MAX_OFFSET_M

				piece.w_pos[w] = rest + offset
				piece.w_dirt[w] = minf(1.0, piece.w_dirt[w] + weight * scuff)

				moved.append(w)

	if moved.is_empty():
		return

	_refresh(piece, moved)
	piece.deformed = true


func _refresh(piece: Piece, moved: PackedInt32Array) -> void:
	piece.stamp += 1
	var stamp: int = piece.stamp

	var around := PackedInt32Array()

	for w in moved:
		for k in range(piece.w_tri_start[w], piece.w_tri_start[w + 1]):
			var t: int = piece.w_tris[k]
			if piece.t_stamp[t] == stamp:
				continue

			piece.t_stamp[t] = stamp

			var wa: int = piece.weld[piece.index[t * 3]]
			var wb: int = piece.weld[piece.index[t * 3 + 1]]
			var wc: int = piece.weld[piece.index[t * 3 + 2]]

			var a: Vector3 = piece.w_pos[wa]
			piece.face[t] = (piece.w_pos[wb] - a).cross(piece.w_pos[wc] - a)

			if piece.w_stamp[wa] != stamp:
				piece.w_stamp[wa] = stamp
				around.append(wa)

			if piece.w_stamp[wb] != stamp:
				piece.w_stamp[wb] = stamp
				around.append(wb)

			if piece.w_stamp[wc] != stamp:
				piece.w_stamp[wc] = stamp
				around.append(wc)

	var rotation_back: Quaternion = piece.turn.inverse()
	var has_tangents: bool = not piece.auth_tangent.is_empty()

	for w in around:
		var now: Vector3 = Vector3.ZERO

		for k in range(piece.w_tri_start[w], piece.w_tri_start[w + 1]):
			now += piece.face[piece.w_tris[k]]

		var tilt: Quaternion = Quaternion.IDENTITY

		if now.length_squared() > 0.0000000001:
			now = now.normalized()

			if piece.w_normal_rest[w].dot(now) > -0.95:
				tilt = rotation_back * Quaternion(piece.w_normal_rest[w], now) * piece.turn

		var shade: Color = Color.WHITE.lerp(SCUFF_COLOR, piece.w_dirt[w] * 0.85)

		for k in range(piece.w_vert_start[w], piece.w_vert_start[w + 1]):
			var v: int = piece.w_verts[k]

			piece.pos[v] = piece.w_pos[w]
			piece.normal[v] = tilt * piece.auth_normal[v]
			piece.color[v] = shade

			if has_tangents:
				var tangent: Vector3 = tilt * Vector3(
					piece.auth_tangent[v * 4],
					piece.auth_tangent[v * 4 + 1],
					piece.auth_tangent[v * 4 + 2],
				)

				piece.tangent[v * 4] = tangent.x
				piece.tangent[v * 4 + 1] = tangent.y
				piece.tangent[v * 4 + 2] = tangent.z


func _hash(x: int, y: int, z: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + z * 1274126177
	h = (h ^ (h >> 13)) * 1103515245
	h = h ^ (h >> 16)

	return float(h & 0xFFFF) / 32767.5 - 1.0


func _value_noise(point: Vector3, scale: float) -> float:
	var scaled: Vector3 = point * scale
	var corner: Vector3 = scaled.floor()

	var t: Vector3 = scaled - corner
	t = t * t * (Vector3.ONE * 3.0 - t * 2.0)

	var x: int = int(corner.x)
	var y: int = int(corner.y)
	var z: int = int(corner.z)

	var low_front: float = lerpf(_hash(x, y, z), _hash(x + 1, y, z), t.x)
	var high_front: float = lerpf(_hash(x, y + 1, z), _hash(x + 1, y + 1, z), t.x)

	var low_back: float = lerpf(_hash(x, y, z + 1), _hash(x + 1, y, z + 1), t.x)
	var high_back: float = lerpf(_hash(x, y + 1, z + 1), _hash(x + 1, y + 1, z + 1), t.x)

	return lerpf(lerpf(low_front, high_front, t.y), lerpf(low_back, high_back, t.y), t.z)


func _upload(piece: Piece) -> void:
	piece.dirty = false

	if not is_instance_valid(piece.node):
		return

	piece.anim_pos = piece.pos
	piece.anim_normal = piece.normal
	piece.anim_tangent = piece.tangent

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	arrays[Mesh.ARRAY_VERTEX] = piece.from_car * piece.shown_pos
	arrays[Mesh.ARRAY_NORMAL] = piece.shown_normal
	arrays[Mesh.ARRAY_COLOR] = piece.color
	arrays[Mesh.ARRAY_INDEX] = piece.index

	var shape: Array = []
	shape.resize(Mesh.ARRAY_MAX)

	shape[Mesh.ARRAY_VERTEX] = piece.from_car * piece.anim_pos
	shape[Mesh.ARRAY_NORMAL] = piece.anim_normal

	if not piece.tangent.is_empty():
		arrays[Mesh.ARRAY_TANGENT] = piece.shown_tangent
		shape[Mesh.ARRAY_TANGENT] = piece.anim_tangent

	if not piece.uv.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = piece.uv

	if not piece.uv2.is_empty():
		arrays[Mesh.ARRAY_TEX_UV2] = piece.uv2

	if piece.mesh == null:
		piece.mesh = ArrayMesh.new()

	piece.mesh.clear_surfaces()
	piece.mesh.clear_blend_shapes()

	piece.mesh.add_blend_shape(&"bend")
	piece.mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED

	piece.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [shape])
	piece.mesh.surface_set_material(0, piece.material)

	if piece.node.mesh != piece.mesh:
		piece.node.mesh = piece.mesh

	piece.node.set_blend_shape_value(0, 0.0)

	piece.waiting = true


func _upload_pieces() -> void:
	if _group >= 0:
		return

	var stop: int = Time.get_ticks_usec() + UPLOAD_BUDGET_USEC

	for piece in pieces:
		if piece.dirty and not piece.animating:
			_upload(piece)

			if Time.get_ticks_usec() > stop:
				break

	if _uploading():
		return

	for piece in pieces:
		if piece.waiting:
			piece.waiting = false
			piece.animating = true
			piece.progress = 0.0


func _uploading() -> bool:
	for piece in pieces:
		if piece.dirty and not piece.animating:
			return true

	return false


func _slide() -> void:
	var phys_step: float = 1.0 / float(Engine.physics_ticks_per_second) / ANIMATION_S

	for piece in pieces:
		if not piece.animating:
			continue

		piece.progress = minf(piece.progress + phys_step, 1.0)

		if is_instance_valid(piece.node):
			piece.node.set_blend_shape_value(
				0,
				piece.progress * piece.progress * (3.0 - 2.0 * piece.progress),
			)

		if piece.progress >= 1.0:
			piece.animating = false

			piece.shown_pos = piece.anim_pos
			piece.shown_normal = piece.anim_normal
			piece.shown_tangent = piece.anim_tangent

			piece.anim_pos = PackedVector3Array()
			piece.anim_normal = PackedVector3Array()
			piece.anim_tangent = PackedFloat32Array()


func _prepare_pieces() -> void:
	if _ticks <= START_AFTER_TICKS:
		return

	if not _threaded:
		if not _queue.is_empty():
			var next: Piece = _queue[0]

			if next.ready or next.skip or _prepare_stage(next):
				_queue.pop_front()

		return

	for piece in pieces:
		if piece.task >= 0 and WorkerThreadPool.is_task_completed(piece.task):
			WorkerThreadPool.wait_for_task_completion(piece.task)

			piece.task = -1
			piece.busy = false

	while _next_prepare < pieces.size():
		var piece: Piece = pieces[_next_prepare]
		_next_prepare += 1

		if piece.ready or piece.skip or piece.busy:
			continue

		_read(piece)
		if piece.skip:
			continue

		piece.stage = 1
		piece.busy = true
		piece.task = WorkerThreadPool.add_task(_prepare_in_thread.bind(piece), false, "car piece")

		break


func _prepare_in_thread(piece: Piece) -> void:
	while not piece.ready and not piece.skip:
		_prepare_stage(piece)


func _ensure_ready(piece: Piece) -> void:
	if piece.ready or piece.skip:
		return

	if piece.task >= 0:
		WorkerThreadPool.wait_for_task_completion(piece.task)

		piece.task = -1
		piece.busy = false
	elif not piece.busy:
		_prepare(piece)


func _run_jobs() -> void:
	if not _threaded:
		_work()
		return

	if _group >= 0:
		if not WorkerThreadPool.is_group_task_completed(_group):
			return

		WorkerThreadPool.wait_for_group_task_completion(_group)
		_group = -1

		_finish_job(_group_job)
		_group_job = null

		return

	if _jobs.is_empty() or _uploading():
		return

	var job: Job = _jobs.pop_front()

	if job.pieces.is_empty():
		return

	for piece in job.pieces:
		_ensure_ready(piece)

	_group_job = job
	_group = WorkerThreadPool.add_group_task(
		_dent_in_thread.bind(job),
		job.pieces.size(),
		-1,
		true,
		"car dent",
	)


func _dent_in_thread(index: int, job: Job) -> void:
	var piece: Piece = job.pieces[index]

	if not piece.ready:
		return

	for x in range(job.low.x, job.high.x + 1):
		_dent_slab(piece, job, x)


func _finish_job(job: Job) -> void:
	for piece in job.pieces:
		if piece.deformed:
			piece.dirty = true

	_applied.append(job)
	if _applied.size() > MAX_APPLIED:
		_applied.pop_front()

	_hull_due = true
	_hull_restore = false
	_last_change = _clock


func crushed(point: Vector3) -> Vector3:
	return _crushed_by(point, _applied)


func _crushed_by(point: Vector3, jobs: Array[Job]) -> Vector3:
	var offset: Vector3 = Vector3.ZERO

	for job in jobs:
		var behind: float = maxf(point.dot(job.push) - job.plane, 0.0)
		var spread: float = 1.0 - behind / CRUMPLE_ZONE_M
		if spread <= 0.0:
			continue

		var across: float = maxf(absf(point.dot(job.side) - job.center_side) - job.half_side, 0.0)
		var over: float = maxf(absf(point.dot(job.up) - job.center_up) - job.half_up, 0.0)

		var gap: float = across * across + over * over + behind * behind * 0.25
		if gap >= job.radius * job.radius:
			continue

		var fall: float = 1.0 - gap / (job.radius * job.radius)

		var give: float = job.crush * spread * fall * fall
		if job.fills:
			give = maxf(give - maxf(offset.dot(job.push), 0.0), 0.0)

		give *= 1.0 - 0.5 * offset.length() / MAX_OFFSET_M
		offset += job.push * give

		if offset.length() > MAX_OFFSET_M:
			offset = offset.normalized() * MAX_OFFSET_M

	return point + offset


func _follow_with_hull() -> void:
	if not _hull_due and not _hull_restore:
		return

	if _clock - _last_change < SETTLE_S or not _jobs.is_empty() or _group >= 0:
		return

	if _hull_queue.is_empty():
		for child in _car.get_children():
			var node := child as CollisionShape3D

			if node == null or not node.shape is ConvexPolygonShape3D:
				continue

			if _hull_restore and not _hull_shapes.has(node):
				continue

			_hull_queue.append(node)

		if _hull_queue.is_empty():
			_hull_due = false
			_hull_restore = false
			return

	var shape_node: CollisionShape3D = _hull_queue.pop_back()

	if not _hull_shapes.has(shape_node):
		var own: ConvexPolygonShape3D = (shape_node.shape as ConvexPolygonShape3D).duplicate()
		_hull_shapes[shape_node] = own.points

		shape_node.shape = own

	var rest: PackedVector3Array = _hull_shapes[shape_node]
	var points := PackedVector3Array()
	points.resize(rest.size())

	for i in range(rest.size()):
		points[i] = rest[i] if _hull_restore else crushed(rest[i])

	(shape_node.shape as ConvexPolygonShape3D).points = points

	if _hull_queue.is_empty():
		_hull_due = false
		_hull_restore = false


func _prepare(piece: Piece) -> void:
	while not piece.ready and not piece.skip:
		_prepare_stage(piece)


func _prepare_stage(piece: Piece) -> bool:
	match piece.stage:
		0:
			_read(piece)
			piece.stage = 1
		1:
			if not _split_pass(piece):
				piece.stage = 2
		2:
			_weld_table(piece)
			piece.stage = 3
		3:
			_weld_links(piece)
			piece.stage = 4
		_:
			_grid(piece)
			_finish(piece)

	return piece.ready or piece.skip


func _read(piece: Piece) -> void:
	var source: Mesh = piece.node.mesh
	var arrays: Array = source.surface_get_arrays(0)

	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

	if vertices.is_empty() or indices.is_empty() or arrays[Mesh.ARRAY_NORMAL] == null:
		piece.skip = true
		return

	piece.pos = piece.to_car * vertices
	piece.index = indices
	piece.auth_normal = arrays[Mesh.ARRAY_NORMAL]

	if arrays[Mesh.ARRAY_TANGENT] != null:
		piece.auth_tangent = arrays[Mesh.ARRAY_TANGENT]

	if arrays[Mesh.ARRAY_TEX_UV] != null:
		piece.uv = arrays[Mesh.ARRAY_TEX_UV]

	if arrays[Mesh.ARRAY_TEX_UV2] != null:
		piece.uv2 = arrays[Mesh.ARRAY_TEX_UV2]


func _finish(piece: Piece) -> void:
	piece.rest_pos = piece.pos.duplicate()
	piece.normal = piece.auth_normal.duplicate()
	piece.tangent = piece.auth_tangent.duplicate()

	piece.color = PackedColorArray()
	piece.color.resize(piece.pos.size())
	piece.color.fill(Color.WHITE)

	piece.w_stamp = PackedInt32Array()
	piece.w_stamp.resize(piece.w_rest.size())

	piece.t_stamp = PackedInt32Array()
	piece.t_stamp.resize(int(piece.index.size() / 3.0))

	piece.face = _rest_faces(piece)

	piece.shown_pos = piece.pos
	piece.shown_normal = piece.normal
	piece.shown_tangent = piece.tangent

	piece.ready = true
	prepared += 1


func _rest_faces(piece: Piece) -> PackedVector3Array:
	var faces := PackedVector3Array()
	faces.resize(int(piece.index.size() / 3.0))

	for t in range(faces.size()):
		var a: Vector3 = piece.w_rest[piece.weld[piece.index[t * 3]]]
		faces[t] = (
			piece.w_rest[piece.weld[piece.index[t * 3 + 1]]] - a
		).cross(piece.w_rest[piece.weld[piece.index[t * 3 + 2]]] - a)

	return faces


func _split_pass(piece: Piece) -> bool:
	var limit: float = MAX_EDGE_M * MAX_EDGE_M

	piece.passes += 1

	if piece.passes > MAX_SPLIT_PASSES:
		return false

	var count: int = piece.pos.size()
	var indices: PackedInt32Array = piece.index

	var mids: Dictionary = { }

	for t in range(0, indices.size(), 3):
		for e in range(3):
			var a: int = indices[t + e]
			var b: int = indices[t + (e + 1) % 3]

			if piece.pos[a].distance_squared_to(piece.pos[b]) > limit:
				var key: int = mini(a, b) * count + maxi(a, b)
				if not mids.has(key):
					mids[key] = _add_middle(piece, a, b)

	if mids.is_empty():
		return false

	var out := PackedInt32Array()

	for t in range(0, indices.size(), 3):
		var a: int = indices[t]
		var b: int = indices[t + 1]
		var c: int = indices[t + 2]

		var m0: int = mids.get(mini(a, b) * count + maxi(a, b), -1)
		var m1: int = mids.get(mini(b, c) * count + maxi(b, c), -1)
		var m2: int = mids.get(mini(c, a) * count + maxi(c, a), -1)

		var mask: int = (1 if m0 >= 0 else 0) | (2 if m1 >= 0 else 0) | (4 if m2 >= 0 else 0)

		match mask:
			0:
				out.append_array([a, b, c])
			1:
				out.append_array([a, m0, c, m0, b, c])
			2:
				out.append_array([a, b, m1, a, m1, c])
			4:
				out.append_array([a, b, m2, m2, b, c])
			3:
				out.append_array([m0, b, m1, a, m0, m1, a, m1, c])
			6:
				out.append_array([m1, c, m2, a, b, m1, a, m1, m2])
			5:
				out.append_array([a, m0, m2, m0, b, c, m0, c, m2])
			_:
				out.append_array([a, m0, m2, m0, b, m1, m2, m1, c, m0, m1, m2])

	piece.index = out

	return true


func _add_middle(piece: Piece, a: int, b: int) -> int:
	var made: int = piece.pos.size()

	piece.pos.append(piece.pos[a].lerp(piece.pos[b], 0.5))
	piece.auth_normal.append((piece.auth_normal[a] + piece.auth_normal[b]).normalized())

	if not piece.uv.is_empty():
		piece.uv.append(piece.uv[a].lerp(piece.uv[b], 0.5))

	if not piece.uv2.is_empty():
		piece.uv2.append(piece.uv2[a].lerp(piece.uv2[b], 0.5))

	if not piece.auth_tangent.is_empty():
		var tangent: Vector3 = (
			Vector3(
				piece.auth_tangent[a * 4],
				piece.auth_tangent[a * 4 + 1],
				piece.auth_tangent[a * 4 + 2],
			)
			+ Vector3(
				piece.auth_tangent[b * 4],
				piece.auth_tangent[b * 4 + 1],
				piece.auth_tangent[b * 4 + 2],
			)
		).normalized()

		piece.auth_tangent.append_array(
			[tangent.x, tangent.y, tangent.z, piece.auth_tangent[a * 4 + 3]]
		)

	return made


func _weld_table(piece: Piece) -> void:
	var count: int = piece.pos.size()

	piece.weld.resize(count)

	var table: Dictionary = { }
	var rest := PackedVector3Array()

	for i in range(count):
		var q: Vector3 = (piece.pos[i] * 10000.0).round()
		var key: int = ((int(q.x) + WELD_BIAS) * WELD_SPAN + (int(q.y) + WELD_BIAS)) * WELD_SPAN + int(
			q.z
		) + WELD_BIAS

		var w: int = table.get(key, -1)
		if w < 0:
			w = rest.size()
			table[key] = w
			rest.append(piece.pos[i])

		piece.weld[i] = w

	piece.w_rest = rest
	piece.w_pos = rest.duplicate()

	piece.w_dirt = PackedFloat32Array()
	piece.w_dirt.resize(rest.size())

	piece.w_rough = PackedFloat32Array()
	piece.w_rough.resize(rest.size() * 2)

	for i in range(rest.size()):
		var at: Vector3 = rest[i]

		var broad: float = _value_noise(at, BROAD_LUMPS_PER_M)
		var fine: float = _value_noise(at + Vector3(7.3, 1.9, 4.1), FINE_LUMPS_PER_M)
		var crease: float = 1.0 - 2.0 * absf(
			_value_noise(at + Vector3(2.1, 8.7, 3.3), CREASES_PER_M)
		)

		piece.w_rough[i * 2] = broad * BROAD_SHARE + fine * FINE_SHARE + crease * CREASE_SHARE
		piece.w_rough[i * 2 + 1] = broad


func _weld_links(piece: Piece) -> void:
	var count: int = piece.pos.size()
	var welds: int = piece.w_rest.size()
	var rest: PackedVector3Array = piece.w_rest

	piece.w_vert_start = PackedInt32Array()
	piece.w_vert_start.resize(welds + 1)

	for i in range(count):
		piece.w_vert_start[piece.weld[i] + 1] += 1

	for w in range(welds):
		piece.w_vert_start[w + 1] += piece.w_vert_start[w]

	piece.w_verts = PackedInt32Array()
	piece.w_verts.resize(count)

	var fill: PackedInt32Array = piece.w_vert_start.duplicate()

	for i in range(count):
		var w: int = piece.weld[i]
		piece.w_verts[fill[w]] = i
		fill[w] += 1

	var indices: PackedInt32Array = piece.index
	var tri_count: int = int(indices.size() / 3.0)

	piece.w_tri_start = PackedInt32Array()
	piece.w_tri_start.resize(welds + 1)

	for t in range(tri_count):
		var wa: int = piece.weld[indices[t * 3]]
		var wb: int = piece.weld[indices[t * 3 + 1]]
		var wc: int = piece.weld[indices[t * 3 + 2]]

		piece.w_tri_start[wa + 1] += 1

		if wb != wa:
			piece.w_tri_start[wb + 1] += 1

		if wc != wa and wc != wb:
			piece.w_tri_start[wc + 1] += 1

	for w in range(welds):
		piece.w_tri_start[w + 1] += piece.w_tri_start[w]

	piece.w_tris = PackedInt32Array()
	piece.w_tris.resize(piece.w_tri_start[welds])

	fill = piece.w_tri_start.duplicate()

	piece.w_normal_rest = PackedVector3Array()
	piece.w_normal_rest.resize(welds)

	for t in range(tri_count):
		var wa: int = piece.weld[indices[t * 3]]
		var wb: int = piece.weld[indices[t * 3 + 1]]
		var wc: int = piece.weld[indices[t * 3 + 2]]

		var face: Vector3 = (rest[wb] - rest[wa]).cross(rest[wc] - rest[wa])

		piece.w_tris[fill[wa]] = t
		fill[wa] += 1
		piece.w_normal_rest[wa] += face

		if wb != wa:
			piece.w_tris[fill[wb]] = t
			fill[wb] += 1
			piece.w_normal_rest[wb] += face

		if wc != wa and wc != wb:
			piece.w_tris[fill[wc]] = t
			fill[wc] += 1
			piece.w_normal_rest[wc] += face

	for w in range(welds):
		piece.w_normal_rest[w] = piece.w_normal_rest[w].normalized()


func _grid(piece: Piece) -> void:
	for w in range(piece.w_rest.size()):
		var cell := Vector3i((piece.w_rest[w] / CELL_M).floor())

		var list: Array = piece.cells.get(cell, [])
		if list.is_empty():
			piece.cells[cell] = list

		list.append(w)
