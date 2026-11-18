class_name GroundProbe
extends RefCounted

## Ground steeper than this is considered a wall.
const MIN_GROUND_COS: float = 0.5

## How close to the ground counts as touching it.
const REST_MARGIN_M: float = 0.02

const SHARPEN_LIMIT_M: float = 0.004

var hub_position: Vector3 = Vector3.ZERO

var contact_point: Vector3 = Vector3.ZERO
var contact_normal: Vector3 = Vector3.UP

var displacement: float = 0.0

var _shape: CylinderShape3D = CylinderShape3D.new()

var _cast: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _start: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _rest: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()

var _space: PhysicsDirectSpaceState3D
var _config: SuspensionConfig
var _mask: int = 1

var _origin: Vector3 = Vector3.ZERO
var _down: Vector3 = Vector3.DOWN
var _excluded: Array[RID] = []


func _init() -> void:
	_cast.shape = _shape
	_start.shape = _shape

	_rest.shape = _shape
	_rest.margin = REST_MARGIN_M


func find(wheel: Node3D, chassis: RigidBody3D, config: SuspensionConfig, mask: int) -> bool:
	var basis: Basis = wheel.global_transform.basis.orthonormalized()

	_space = wheel.get_world_3d().direct_space_state
	_config = config
	_mask = mask

	_origin = wheel.global_position
	_down = -basis.y
	_excluded = [chassis.get_rid()]

	if not is_equal_approx(_shape.radius, config.wheel_radius):
		_shape.radius = config.wheel_radius

	if not is_equal_approx(_shape.height, config.wheel_width):
		_shape.height = config.wheel_width

	var wheel_basis: Basis = basis * Basis(Vector3.BACK, PI * 0.5)

	var buried: Dictionary = _space.get_rest_info(_query(_start, wheel_basis, _origin))
	if not buried.is_empty():
		return _squash(buried)

	var travel: float = config.suspension_rest_length

	_cast.motion = _down * travel
	var fractions: PackedFloat32Array = _space.cast_motion(_query(_cast, wheel_basis, _origin))
	if fractions.size() < 2 or fractions[1] >= 1.0:
		return false

	var along: float = travel * (fractions[0] + fractions[1]) * 0.5

	var touch: Vector3 = _origin + _down * (travel * fractions[1])
	var info: Dictionary = _space.get_rest_info(_query(_rest, wheel_basis, touch))

	var normal: Vector3 = -_down
	if not info.is_empty() and (info["normal"] as Vector3).length_squared() > 0.5:
		normal = (info["normal"] as Vector3).normalized()

	if normal.dot(-_down) < MIN_GROUND_COS:
		return _find_with_ray()

	var tilt: float = normal.dot(wheel_basis.y)
	var round_part: float = config.wheel_radius * sqrt(maxf(1.0 - tilt * tilt, 0.0))
	var reach: float = round_part + config.wheel_width * 0.5 * absf(tilt)

	if info.has("point"):
		var sharp: float = (
			(reach - normal.dot(_origin - (info["point"] as Vector3))) / normal.dot(_down)
		)

		if absf(sharp - along) < SHARPEN_LIMIT_M:
			along = sharp

	along = clampf(along, 0.0, travel)

	hub_position = _origin + _down * along

	contact_normal = normal
	contact_point = hub_position - normal * reach

	displacement = travel - along

	return true


func _query(
	query: PhysicsShapeQueryParameters3D,
	wheel_basis: Basis,
	position: Vector3,
) -> PhysicsShapeQueryParameters3D:
	query.transform = Transform3D(wheel_basis, position)
	query.collision_mask = _mask
	query.exclude = _excluded

	return query


func _squash(buried: Dictionary) -> bool:
	var normal: Vector3 = buried["normal"]
	if normal.length_squared() < 0.5 or normal.dot(-_down) < MIN_GROUND_COS:
		return _find_with_ray()

	hub_position = _origin

	contact_normal = normal.normalized()
	contact_point = buried["point"]

	displacement = _config.suspension_rest_length

	return true


func _find_with_ray() -> bool:
	var reach: float = _config.suspension_rest_length + _config.wheel_radius

	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		_origin,
		_origin + _down * reach,
		_mask,
		_excluded,
	)

	var hit: Dictionary = _space.intersect_ray(ray)
	if hit.is_empty():
		return false

	contact_point = hit["position"]
	contact_normal = hit["normal"]

	var distance: float = _origin.distance_to(contact_point)

	hub_position = _origin + _down * (distance - _config.wheel_radius)
	displacement = clampf(reach - distance, 0.0, _config.suspension_rest_length)

	return true
