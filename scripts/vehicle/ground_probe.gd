class_name GroundProbe
extends RefCounted

const SLICES: int = 7

## Ground steeper than this is considered a wall.
const MIN_GROUND_COS: float = 0.5

## How close to the ground counts as touching it.
const REST_MARGIN_M: float = 0.02

const SHARPEN_LIMIT_M: float = 0.004

const SLICE_LOAD_FLOOR_M: float = 0.005

const MIN_WIDTH_M: float = 0.05

var hub_position: Vector3 = Vector3.ZERO

var contact_point: Vector3 = Vector3.ZERO
var contact_normal: Vector3 = Vector3.UP

var displacement: float = 0.0

var _tire: CylinderShape3D = CylinderShape3D.new()
var _slice: CylinderShape3D = CylinderShape3D.new()

var _tire_start: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()

var _start: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _cast: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _rest: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()

var _space: PhysicsDirectSpaceState3D
var _config: SuspensionConfig
var _mask: int = 1

var _down: Vector3 = Vector3.DOWN
var _excluded: Array[RID] = []
var _wheel_basis: Basis = Basis.IDENTITY

var _found_along: float = 0.0
var _found_normal: Vector3 = Vector3.UP
var _found_reach: float = 0.0

var _alongs: PackedFloat32Array = PackedFloat32Array()
var _normals: PackedVector3Array = PackedVector3Array()

var _touching: PackedByteArray = PackedByteArray()
var _offsets: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	_tire_start.shape = _tire

	_start.shape = _slice
	_cast.shape = _slice

	_rest.shape = _slice
	_rest.margin = REST_MARGIN_M

	_alongs.resize(SLICES)
	_normals.resize(SLICES)

	_touching.resize(SLICES)
	_offsets.resize(SLICES)


func find(wheel: Node3D, chassis: RigidBody3D, config: SuspensionConfig, mask: int) -> bool:
	var basis: Basis = wheel.global_transform.basis.orthonormalized()

	_space = wheel.get_world_3d().direct_space_state
	_config = config
	_mask = mask

	var origin: Vector3 = wheel.global_position
	_down = -basis.y
	_excluded = [chassis.get_rid()]

	var width: float = maxf(config.wheel_width, MIN_WIDTH_M)
	var slice_width: float = width / SLICES
	_fit_shapes(config.wheel_radius, width, slice_width)

	_wheel_basis = basis * Basis(Vector3.BACK, PI * 0.5)

	var axis: Vector3 = _wheel_basis.y
	var travel: float = config.suspension_rest_length

	var tire_buried: bool = not _space.get_rest_info(_query(_tire_start, origin)).is_empty()

	var touching_count: int = 0
	var along_sum: float = 0.0
	var reach_sum: float = 0.0

	for i in range(SLICES):
		var offset: float = (i - (SLICES - 1) * 0.5) * slice_width
		_offsets[i] = offset

		var found: bool = _probe_slice(origin + axis * offset, travel, tire_buried)

		_touching[i] = 1 if found else 0
		if not found:
			continue

		_alongs[i] = _found_along
		_normals[i] = _found_normal

		touching_count += 1
		along_sum += _found_along
		reach_sum += _found_reach

	if touching_count == 0:
		return false

	var along: float = along_sum / touching_count
	var reach: float = reach_sum / touching_count

	var normal_sum: Vector3 = Vector3.ZERO
	var side_sum: float = 0.0
	var weight_sum: float = 0.0

	for i in range(SLICES):
		if _touching[i] == 0:
			continue

		var weight: float = maxf(along - _alongs[i], 0.0) + SLICE_LOAD_FLOOR_M
		normal_sum += _normals[i] * weight
		side_sum += _offsets[i] * weight
		weight_sum += weight

	var normal: Vector3 = normal_sum.normalized()

	hub_position = origin + _down * along

	contact_normal = normal
	contact_point = hub_position - normal * reach + axis * (side_sum / weight_sum)

	displacement = travel - along

	return true


func _fit_shapes(radius: float, width: float, slice_width: float) -> void:
	if not is_equal_approx(_tire.radius, radius):
		_tire.radius = radius
		_slice.radius = radius

	if not is_equal_approx(_tire.height, width):
		_tire.height = width

	if not is_equal_approx(_slice.height, slice_width):
		_slice.height = slice_width


func _query(
	query: PhysicsShapeQueryParameters3D,
	position: Vector3,
) -> PhysicsShapeQueryParameters3D:
	query.transform = Transform3D(_wheel_basis, position)
	query.collision_mask = _mask
	query.exclude = _excluded

	return query


func _probe_slice(origin: Vector3, travel: float, check_buried: bool) -> bool:
	if check_buried:
		var buried: Dictionary = _space.get_rest_info(_query(_start, origin))

		if not buried.is_empty():
			return _squash(buried, origin)

	_cast.motion = _down * travel
	var fractions: PackedFloat32Array = _space.cast_motion(_query(_cast, origin))
	if fractions.size() < 2 or fractions[1] >= 1.0:
		return false

	var along: float = travel * (fractions[0] + fractions[1]) * 0.5

	var touch: Vector3 = origin + _down * (travel * fractions[1])
	var info: Dictionary = _space.get_rest_info(_query(_rest, touch))

	var normal: Vector3 = -_down
	if not info.is_empty() and (info["normal"] as Vector3).length_squared() > 0.5:
		normal = (info["normal"] as Vector3).normalized()

	if normal.dot(-_down) < MIN_GROUND_COS:
		return _find_with_ray(origin)

	var tilt: float = normal.dot(_wheel_basis.y)
	var round_part: float = _config.wheel_radius * sqrt(maxf(1.0 - tilt * tilt, 0.0))
	var reach: float = round_part + _slice.height * 0.5 * absf(tilt)

	if info.has("point"):
		var sharp: float = (
			(reach - normal.dot(origin - (info["point"] as Vector3))) / normal.dot(_down)
		)

		if absf(sharp - along) < SHARPEN_LIMIT_M:
			along = sharp

	_found_along = clampf(along, 0.0, travel)
	_found_normal = normal
	_found_reach = reach

	return true


func _squash(buried: Dictionary, origin: Vector3) -> bool:
	var normal: Vector3 = buried["normal"]
	if normal.length_squared() < 0.5 or normal.dot(-_down) < MIN_GROUND_COS:
		return _find_with_ray(origin)

	_found_along = 0.0
	_found_normal = normal.normalized()
	_found_reach = _config.wheel_radius

	return true


func _find_with_ray(origin: Vector3) -> bool:
	var reach: float = _config.suspension_rest_length + _config.wheel_radius

	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin,
		origin + _down * reach,
		_mask,
		_excluded,
	)

	var hit: Dictionary = _space.intersect_ray(ray)
	if hit.is_empty():
		return false

	var distance: float = origin.distance_to(hit["position"])

	_found_along = clampf(distance - _config.wheel_radius, 0.0, _config.suspension_rest_length)
	_found_normal = hit["normal"]
	_found_reach = _config.wheel_radius

	return true
