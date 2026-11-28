class_name TireSmokeObstacles
extends RefCounted

const CAR_SLOTS: int = 2
const CABIN_SLOT: int = 1
const MAX_BOXES: int = 16

const MASK: int = 1 | PanelDamage.PANEL_LAYER | LostWheel.OWN_LAYER

const SCAN_EVERY_S: float = 0.15
const SCAN_REACH_M: float = 3.0
const MAX_SCAN_HALF_M: float = 25.0

const MAX_HITS: int = 48

const FLOOR_MARGIN_M: float = 0.12

const BELT_SHARE: float = 0.62

const CABIN_GAP_M: float = 0.06

const WIDTH_QUANTILE: float = 0.92
const CABIN_WIDTH_SHARE: float = 0.9

const MAX_CORNER_M: float = 0.35
const CORNER_SHARE: float = 0.8

const REACH_M: float = 2.2


class Box extends RefCounted:
	var body: Node3D
	var local: Transform3D
	var size: Vector3

	var key: String = ""
	var slot: int = 0

	var is_car: bool = false

	var center: Vector3
	var turn: Basis
	var inverse: Basis
	var half: Vector3
	var corner: float
	var reach: AABB

	var velocity: Vector3
	var spin: Vector3
	var pivot: Vector3


	func _init(on: Node3D, at: Transform3D, box_size: Vector3) -> void:
		body = on
		local = at
		size = box_size


	func update() -> void:
		var frame: Transform3D = body.global_transform * local
		var axes: Basis = frame.basis

		center = frame.origin
		turn = axes.orthonormalized()
		inverse = turn.transposed()
		half = size * 0.5 * Vector3(axes.x.length(), axes.y.length(), axes.z.length())
		corner = minf(MAX_CORNER_M, half[half.min_axis_index()] * CORNER_SHARE)

		var extent: Vector3 = (
			turn.x.abs() * half.x + turn.y.abs() * half.y + turn.z.abs() * half.z
		)
		reach = AABB(center - extent, extent * 2.0).grow(REACH_M)

		var rigid := body as RigidBody3D
		if rigid == null:
			return

		velocity = rigid.linear_velocity
		spin = rigid.angular_velocity
		pivot = rigid.to_global(rigid.center_of_mass)


var boxes: Array[Box] = []
var area: AABB = AABB()

var _vehicle: Vehicle

var _car: Array[Box] = []
var _slots: Array[Box] = []

var _centers: PackedVector4Array = PackedVector4Array()
var _axes_x: PackedVector4Array = PackedVector4Array()
var _axes_y: PackedVector4Array = PackedVector4Array()
var _axes_z: PackedVector4Array = PackedVector4Array()

var _hulls: Dictionary[Shape3D, AABB] = { }

var _area_shape: BoxShape3D = BoxShape3D.new()
var _query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()

var _since_scan_s: float = SCAN_EVERY_S


func _init(vehicle: Vehicle) -> void:
	_vehicle = vehicle

	_slots.resize(MAX_BOXES)

	_centers.resize(MAX_BOXES)
	_axes_x.resize(MAX_BOXES)
	_axes_y.resize(MAX_BOXES)
	_axes_z.resize(MAX_BOXES)

	_query.shape = _area_shape
	_query.collision_mask = MASK


func update(delta: float, smoke: AABB) -> void:
	if _car.is_empty():
		_measure_car()

	_since_scan_s += delta
	if _since_scan_s >= SCAN_EVERY_S:
		_since_scan_s = 0.0
		_scan(smoke)

	boxes.clear()

	for box in _slots:
		if box == null or not is_instance_valid(box.body):
			continue

		box.update()

		area = box.reach if boxes.is_empty() else area.merge(box.reach)
		boxes.append(box)


func send(material: ShaderMaterial) -> void:
	for box in boxes:
		if not is_instance_valid(box.body):
			continue

		var at: Transform3D = box.body.get_global_transform_interpolated() * box.local
		var turn: Basis = at.basis.orthonormalized()

		_centers[box.slot] = Vector4(at.origin.x, at.origin.y, at.origin.z, 0.0)

		_axes_x[box.slot] = Vector4(turn.x.x, turn.x.y, turn.x.z, box.half.x)
		_axes_y[box.slot] = Vector4(turn.y.x, turn.y.y, turn.y.z, box.half.y)
		_axes_z[box.slot] = Vector4(turn.z.x, turn.z.y, turn.z.z, box.half.z)

	material.set_shader_parameter("box_center", _centers)
	material.set_shader_parameter("box_x", _axes_x)
	material.set_shader_parameter("box_y", _axes_y)
	material.set_shader_parameter("box_z", _axes_z)


func car_boxes() -> Array[Box]:
	return _car


func _scan(smoke: AABB) -> void:
	var around: AABB = smoke.grow(SCAN_REACH_M)
	_area_shape.size = (around.size * 0.5).min(Vector3.ONE * MAX_SCAN_HALF_M) * 2.0

	_query.transform = Transform3D(Basis.IDENTITY, around.get_center())
	_query.exclude = [_vehicle.get_rid()]

	var hits: Array[Dictionary] = _vehicle.get_world_3d().direct_space_state.intersect_shape(
		_query,
		MAX_HITS,
	)

	var floor_y: float = _floor_y()
	var from: Vector3 = _vehicle.global_position

	var found: Array[Array] = []
	var cars: Array[Vehicle] = []

	for hit in hits:
		var body := hit["collider"] as CollisionObject3D
		if body == null:
			continue

		var other := body as Vehicle
		if other != null:
			if not cars.has(other) and other.tire_smoke != null:
				cars.append(other)
				_find_car(other, from, found)

			continue

		var index: int = hit["shape"]
		var owner_id: int = body.shape_find_owner(index)
		var shape: Shape3D = _shape_at(body, owner_id, index)

		var bounds: AABB = _local_box(shape)
		if not bounds.has_volume():
			continue

		var box := Box.new(
			body,
			body.shape_owner_get_transform(owner_id)
			* Transform3D(Basis.IDENTITY, bounds.get_center()),
			bounds.size,
		)
		box.key = "%d:%d" % [body.get_instance_id(), index]
		box.update()

		if box.reach.end.y - REACH_M <= floor_y + FLOOR_MARGIN_M:
			continue

		var nearest: Vector3 = (box.inverse * (from - box.center)).clamp(-box.half, box.half)
		found.append([(box.center + box.turn * nearest).distance_to(from), box])

	found.sort_custom(
		func(a: Array, b: Array) -> bool:
			return a[0] < b[0],
	)

	_fill_slots(found)


func _find_car(other: Vehicle, from: Vector3, found: Array[Array]) -> void:
	var theirs: Array[Box] = other.tire_smoke.obstacles.car_boxes()

	for i in range(theirs.size()):
		var box := Box.new(other, theirs[i].local, theirs[i].size)
		box.key = "%d:car%d" % [other.get_instance_id(), i]
		box.is_car = true

		found.append([other.global_position.distance_to(from), box])


func _fill_slots(found: Array[Array]) -> void:
	var wanted: Dictionary[String, Box] = { }

	for i in range(mini(found.size(), MAX_BOXES - CAR_SLOTS)):
		var box: Box = found[i][1]
		wanted[box.key] = box

	for slot in range(CAR_SLOTS, MAX_BOXES):
		var held: Box = _slots[slot]
		if held == null:
			continue

		_slots[slot] = wanted.get(held.key)
		wanted.erase(held.key)

		if _slots[slot] != null:
			_slots[slot].slot = slot

	var free: int = CAR_SLOTS

	for box: Box in wanted.values():
		while _slots[free] != null:
			free += 1

		box.slot = free
		_slots[free] = box


func _measure_car() -> void:
	var points := PackedVector3Array()

	for owner_id in _vehicle.get_shape_owners():
		var frame: Transform3D = _vehicle.shape_owner_get_transform(owner_id)

		for i in range(_vehicle.shape_owner_get_shape_count(owner_id)):
			var box: AABB = _local_box(_vehicle.shape_owner_get_shape(owner_id, i))
			if not box.has_volume():
				continue

			for corner in range(8):
				points.append(frame * box.get_endpoint(corner))

	if points.is_empty():
		return

	var bottom: float = INF
	var top: float = -INF

	for point in points:
		bottom = minf(bottom, point.y)
		top = maxf(top, point.y)

	var belt: float = lerpf(bottom, top, BELT_SHARE)

	_add_car_box(points, -INF, belt, bottom, belt)
	_add_car_box(points, belt + CABIN_GAP_M, INF, belt - MAX_CORNER_M, top)

	if _car.size() == CAR_SLOTS:
		_car[1].size.x = minf(_car[1].size.x, _car[0].size.x * CABIN_WIDTH_SHARE)


func _add_car_box(
	points: PackedVector3Array,
	above: float,
	below: float,
	bottom: float,
	top: float,
) -> void:
	var widths := PackedFloat32Array()

	var front: float = INF
	var back: float = -INF

	for point in points:
		if point.y < above or point.y > below:
			continue

		widths.append(absf(point.x))

		front = minf(front, point.z)
		back = maxf(back, point.z)

	if widths.is_empty() or back <= front:
		return

	widths.sort()
	var half_width: float = widths[int((widths.size() - 1) * WIDTH_QUANTILE)]

	var middle := Vector3(0.0, (bottom + top) * 0.5, (front + back) * 0.5)
	var box := Box.new(
		_vehicle,
		Transform3D(Basis.IDENTITY, middle),
		Vector3(half_width * 2.0, top - bottom, back - front),
	)
	box.is_car = true
	box.slot = _car.size()

	_slots[box.slot] = box
	_car.append(box)


func _floor_y() -> float:
	var lowest: float = INF

	for wheel in _vehicle.wheels:
		if wheel.is_grounded:
			lowest = minf(lowest, wheel.contact_point.y)

	if lowest == INF:
		lowest = _vehicle.global_position.y - 1.0

	return lowest


func _shape_at(body: CollisionObject3D, owner_id: int, index: int) -> Shape3D:
	for i in range(body.shape_owner_get_shape_count(owner_id)):
		if body.shape_owner_get_shape_index(owner_id, i) == index:
			return body.shape_owner_get_shape(owner_id, i)

	return null


func _local_box(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var size: Vector3 = shape.size
		return AABB(size * -0.5, size)

	if shape is CylinderShape3D or shape is CapsuleShape3D:
		var size := Vector3(shape.radius * 2.0, shape.height, shape.radius * 2.0)
		return AABB(size * -0.5, size)

	if shape is SphereShape3D:
		var size: Vector3 = Vector3.ONE * shape.radius * 2.0
		return AABB(size * -0.5, size)

	if shape is ConvexPolygonShape3D:
		if not _hulls.has(shape):
			var points: PackedVector3Array = shape.points
			var box := AABB(points[0], Vector3.ZERO) if not points.is_empty() else AABB()

			for point in points:
				box = box.expand(point)

			_hulls[shape] = box

		return _hulls[shape]

	return AABB()
