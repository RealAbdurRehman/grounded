class_name TireCollider
extends RefCounted

## Ground steeper than this is considered a wall.
const MIN_GROUND_COS: float = 0.5

## Collider is always lifted by this amount above the ground.
const LIFT_M: float = 0.03

const TOUCH_MARGIN_M: float = 0.01

const MAX_CONTACTS: int = 4

const MAX_PAIRS: int = 24

## Contacts with normals this alike are the same contact.
const SAME_NORMAL_COS: float = 0.98

## Contacts with gaps this close are the same contact.
const SAME_GAP_M: float = 0.004

const BODY_PROBE_M: float = 0.02

var count: int = 0

var points: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var gaps: PackedFloat32Array = PackedFloat32Array()

var bodies: Array[RID] = []

var _tire: CylinderShape3D = CylinderShape3D.new()
var _ball: SphereShape3D = SphereShape3D.new()

var _touch: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _sweep: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _rest: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _find_body: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()


func _init() -> void:
	_touch.shape = _tire
	_touch.margin = TOUCH_MARGIN_M

	_sweep.shape = _tire

	_rest.shape = _tire
	_rest.margin = TOUCH_MARGIN_M

	_ball.radius = BODY_PROBE_M
	_find_body.shape = _ball

	points.resize(MAX_CONTACTS)
	normals.resize(MAX_CONTACTS)
	gaps.resize(MAX_CONTACTS)
	bodies.resize(MAX_CONTACTS)


func scan(
	space: PhysicsDirectSpaceState3D,
	exclude: Array[RID],
	mask: int,
	radius: float,
	width: float,
	tire_basis: Basis,
	center: Vector3,
	up: Vector3,
	motion: Vector3,
) -> int:
	count = 0

	_fit(radius, width)
	_aim(_touch, tire_basis, center, mask, exclude)

	var pairs: Array[Vector3] = space.collide_shape(_touch, MAX_PAIRS)
	for i in range(0, pairs.size() - 1, 2):
		var push: Vector3 = pairs[i + 1] - pairs[i]
		var depth: float = push.length()
		if depth < 0.00001:
			continue

		var normal: Vector3 = push / depth
		if normal.dot(up) >= MIN_GROUND_COS:
			continue

		_add(pairs[i + 1], normal, TOUCH_MARGIN_M - depth)

	if motion.length() > TOUCH_MARGIN_M:
		_sweep_ahead(space, exclude, mask, tire_basis, center, up, motion)

	for i in range(count):
		bodies[i] = _body_at(space, exclude, mask, points[i])

	return count


func _fit(radius: float, width: float) -> void:
	if not is_equal_approx(_tire.radius, radius):
		_tire.radius = radius

	if not is_equal_approx(_tire.height, width):
		_tire.height = width


func _aim(
	query: PhysicsShapeQueryParameters3D,
	tire_basis: Basis,
	center: Vector3,
	mask: int,
	exclude: Array[RID],
) -> void:
	query.transform = Transform3D(tire_basis, center)
	query.collision_mask = mask
	query.exclude = exclude


func _sweep_ahead(
	space: PhysicsDirectSpaceState3D,
	exclude: Array[RID],
	mask: int,
	tire_basis: Basis,
	center: Vector3,
	up: Vector3,
	motion: Vector3,
) -> void:
	_aim(_sweep, tire_basis, center, mask, exclude)
	_sweep.motion = motion

	var fractions: PackedFloat32Array = space.cast_motion(_sweep)
	if fractions.size() < 2 or fractions[1] >= 1.0:
		return

	_aim(_rest, tire_basis, center + motion * fractions[1], mask, exclude)

	var info: Dictionary = space.get_rest_info(_rest)
	if info.is_empty():
		return

	var normal: Vector3 = info["normal"]
	if normal.length_squared() < 0.5 or normal.dot(up) >= MIN_GROUND_COS:
		return

	normal = normal.normalized()

	var approach: float = motion.dot(normal)
	if approach >= 0.0:
		return

	_add(info["point"], normal, -approach * fractions[1])


func _body_at(
	space: PhysicsDirectSpaceState3D,
	exclude: Array[RID],
	mask: int,
	point: Vector3,
) -> RID:
	_find_body.transform = Transform3D(Basis.IDENTITY, point)
	_find_body.collision_mask = mask
	_find_body.exclude = exclude

	var found: Array[Dictionary] = space.intersect_shape(_find_body, 1)
	if found.is_empty():
		return RID()

	return found[0]["rid"]


func _add(point: Vector3, normal: Vector3, gap: float) -> void:
	for i in range(count):
		if normals[i].dot(normal) > SAME_NORMAL_COS and absf(gaps[i] - gap) < SAME_GAP_M:
			points[i] = (points[i] + point) * 0.5

			return

	if count >= MAX_CONTACTS:
		return

	points[count] = point
	normals[count] = normal
	gaps[count] = gap
	count += 1
