class_name CarDeformer
extends RefCounted

## Force it takes to crush the car.
const CRUSH_A_N_PER_M: float = 67700.0
const CRUSH_B_N_PER_M2: float = 996000.0

const RESTITUTION: float = 0.1 # 0.1 is realistic.

const MIN_WIDTH_M: float = 0.25
const MAX_WIDTH_M: float = 1.8

## How deep the car can crush on impact.
const CRUMPLE_ZONE_M: float = 0.9

## No point on the body is pushed further than this.
const MAX_OFFSET_M: float = 0.6

const BOW_SHARE: float = 0.3
const FOLD_WAVE: float = 22.0
const FOLD_SHARE: float = 0.25
const CRINKLE_SHARE: float = 0.12

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


var pieces: Array[Piece] = []
var prepared: int = 0

var _car: RigidBody3D
var _all_bounds: AABB

var _queue: Array[Piece] = []
var _jobs: Array[Job] = []

var _ticks: int = 0


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

		piece.to_car = to_car_root * mesh_node.global_transform
		piece.from_car = piece.to_car.affine_inverse()
		piece.turn = Quaternion(piece.to_car.basis.orthonormalized())

		piece.bounds = piece.to_car * mesh_node.get_aabb()
		_all_bounds = piece.bounds if pieces.is_empty() else _all_bounds.merge(piece.bounds)

		pieces.append(piece)
		_queue.append(piece)


func step() -> void:
	_ticks += 1

	if not _jobs.is_empty():
		_work()
	elif _ticks > START_AFTER_TICKS and not _queue.is_empty():
		var next: Piece = _queue[0]

		if next.ready or next.skip or _prepare_stage(next):
			_queue.pop_front()

	for piece in pieces:
		if piece.dirty:
			_upload(piece)
			break


func repair() -> void:
	_jobs.clear()

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
	if points.is_empty() or direction.is_zero_approx() or _jobs.size() >= MAX_JOBS:
		return

	var push: Vector3 = direction.normalized()

	var middle: Vector3 = Vector3.ZERO
	for point in points:
		middle += point

	middle /= float(points.size())

	if push.dot(_car.center_of_mass - middle) < 0.0:
		push = -push

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

	job.radius = clampf(0.2 + 0.8 * job.crush, 0.3, 0.8)

	job.center_side = (side_low + side_high) * 0.5
	job.center_up = (up_low + up_high) * 0.5
	job.half_side = (side_high - side_low) * 0.5
	job.half_up = (up_high - up_low) * 0.5

	var corners: Array[Vector3] = []
	for a in [-1.0, 1.0]:
		for b in [-1.0, 1.0]:
			for c in [-0.5, 2.0]:
				corners.append(
					job.side * (job.center_side + a * (job.half_side + job.radius))
					+ job.up * (job.center_up + b * (job.half_up + job.radius))
					+ push * (job.plane + c * job.radius),
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
	var approach: float = delta_v / (1.0 + RESTITUTION)
	var energy: float = 0.5 * _car.mass * approach * approach * (1.0 - RESTITUTION * RESTITUTION)

	var per_width: float = energy / width_m

	var threshold: float = CRUSH_A_N_PER_M * CRUSH_A_N_PER_M / (2.0 * CRUSH_B_N_PER_M2)
	if per_width <= threshold:
		return 0.0

	var crush: float = (sqrt(2.0 * CRUSH_B_N_PER_M2 * per_width) - CRUSH_A_N_PER_M) / CRUSH_B_N_PER_M2

	return minf(crush, MAX_OFFSET_M)


func _work() -> void:
	var stop: int = Time.get_ticks_usec() + BUDGET_USEC

	while not _jobs.is_empty() and Time.get_ticks_usec() < stop:
		var job: Job = _jobs[0]

		if job.next >= job.pieces.size():
			_jobs.pop_front()
			continue

		var piece: Piece = job.pieces[job.next]

		if not piece.ready:
			_prepare(piece)

		if not job.started:
			job.started = true
			job.slab = job.low.x

		if piece.ready:
			_dent_slab(piece, job)

		job.slab += 1

		if job.slab > job.high.x or not piece.ready:
			job.next += 1
			job.started = false


## Bends the part of a piece that sits in one slab of the grid.
func _dent_slab(piece: Piece, job: Job) -> void:
	var radius_squared: float = job.radius * job.radius
	var scuff: float = clampf(job.crush * 5.0, 0.0, 1.0)

	var moved := PackedInt32Array()

	for y in range(job.low.y, job.high.y + 1):
		for z in range(job.low.z, job.high.z + 1):
			var list: Variant = piece.cells.get(Vector3i(job.slab, y, z))
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
				if give < 0.0005:
					continue

				var offset: Vector3 = piece.w_pos[w] - rest
				give *= 1.0 - 0.5 * offset.length() / MAX_OFFSET_M

				var parallel: float = 1.0 - absf(piece.w_normal_rest[w].dot(job.push))

				var away: Vector3 = rest - job.axis
				away -= job.push * away.dot(job.push)

				var bow: Vector3 = away.normalized() * clampf(away.length() / 0.3, 0.0, 1.0)
				var fold: float = 1.0 + sin(rest.dot(job.push) * FOLD_WAVE) * FOLD_SHARE

				offset += job.push * (give * (1.0 + _noise(rest) * CRINKLE_SHARE))
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
	piece.dirty = true


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


func _noise(p: Vector3) -> float:
	return sin(p.x * 21.0 + p.y * 9.0) * sin(p.y * 19.0 + p.z * 11.0) * 1.4 + sin(
		p.z * 25.0 + p.x * 8.0
	) * 0.4


func _upload(piece: Piece) -> void:
	piece.dirty = false

	if not is_instance_valid(piece.node):
		return

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	arrays[Mesh.ARRAY_VERTEX] = piece.from_car * piece.pos
	arrays[Mesh.ARRAY_NORMAL] = piece.normal
	arrays[Mesh.ARRAY_COLOR] = piece.color
	arrays[Mesh.ARRAY_INDEX] = piece.index

	if not piece.tangent.is_empty():
		arrays[Mesh.ARRAY_TANGENT] = piece.tangent

	if not piece.uv.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = piece.uv

	if not piece.uv2.is_empty():
		arrays[Mesh.ARRAY_TEX_UV2] = piece.uv2

	if piece.mesh == null:
		piece.mesh = ArrayMesh.new()

	piece.mesh.clear_surfaces()
	piece.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	piece.mesh.surface_set_material(0, piece.material)

	if piece.node.mesh != piece.mesh:
		piece.node.mesh = piece.mesh


func _prepare(piece: Piece) -> void:
	while not piece.ready and not piece.skip:
		_prepare_stage(piece)


## Does one slice of the work of getting a piece ready. True once it is done.
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

	var paint := piece.material as BaseMaterial3D
	if paint != null and paint.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		paint.vertex_color_use_as_albedo = true

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
