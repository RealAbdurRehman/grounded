class_name GroundProbe
extends RefCounted

const SLICES: int = 7
const OUTER_SLICES: int = 3

## Ground steeper than this is considered a wall.
const MIN_GROUND_COS: float = 0.5

## How close to the ground counts as touching it.
const REST_MARGIN_M: float = 0.02

const SHARPEN_LIMIT_M: float = 0.004

const SLICE_LOAD_FLOOR_M: float = 0.005

const PATCH_HALF_M: float = 0.10

const MAX_SAMPLES: int = 6
const SAMPLE_SPACING_M: float = 0.10

const MAX_RISE_PER_M: float = 1.7320508

var hub_position: Vector3 = Vector3.ZERO

var contact_point: Vector3 = Vector3.ZERO
var contact_normal: Vector3 = Vector3.UP

var displacement: float = 0.0

var first_touch_along: float = 0.0

var collider_id: int = 0

var _tire: CylinderShape3D = CylinderShape3D.new()

var _slice: CylinderShape3D = CylinderShape3D.new()
var _wide_slice: CylinderShape3D = CylinderShape3D.new()
var _slice_shape: CylinderShape3D

var _slice_count: int = SLICES

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

var _shift: Vector3 = Vector3.ZERO

var _found_along: float = 0.0
var _found_normal: Vector3 = Vector3.UP
var _found_reach: float = 0.0

var _found_collider_id: int = 0

var _alongs: PackedFloat32Array = PackedFloat32Array()
var _normals: PackedVector3Array = PackedVector3Array()

var _touching: PackedByteArray = PackedByteArray()
var _offsets: PackedFloat32Array = PackedFloat32Array()

var _scan_along: float = 0.0
var _scan_min: float = 0.0

var _scan_normal: Vector3 = Vector3.UP
var _scan_collider_id: int = 0

var _slice_ids: PackedInt64Array = PackedInt64Array()
var _votes: Dictionary = { }

var _scan_contact: Vector3 = Vector3.ZERO

var _shifts: PackedFloat32Array = PackedFloat32Array()

var _place_state: PackedByteArray = PackedByteArray()
var _place_displacement: PackedFloat32Array = PackedFloat32Array()
var _place_touch: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	_tire_start.shape = _tire

	_rest.margin = REST_MARGIN_M

	_use_slices(SLICES)

	_alongs.resize(SLICES)
	_normals.resize(SLICES)

	_touching.resize(SLICES)
	_slice_ids.resize(SLICES)
	_offsets.resize(SLICES)

	_shifts.resize(MAX_SAMPLES)

	_place_state.resize(MAX_SAMPLES)
	_place_displacement.resize(MAX_SAMPLES)
	_place_touch.resize(MAX_SAMPLES)


func find(
	wheel: Node3D,
	chassis: RigidBody3D,
	config: SuspensionConfig,
	mask: int,
	tire_basis: Basis,
	path: Vector3,
	shift: Vector3 = Vector3.ZERO,
) -> bool:
	_space = wheel.get_world_3d().direct_space_state
	_config = config
	_mask = mask

	var up: Vector3 = wheel.global_transform.basis.orthonormalized().y
	_down = -up
	_excluded = [chassis.get_rid()]
	_wheel_basis = tire_basis
	_shift = shift

	var mount: Vector3 = wheel.global_position + shift

	var width: float = config.width_m()
	_fit_shapes(config.wheel_radius, width)

	var travel: float = config.suspension_rest_length

	var length: float = path.length()
	var heading: Vector3 = _wheel_basis.y.cross(up).normalized()
	if length > 0.001:
		heading = path / length

	var count: int = _plan_places(length)

	if not _look_at(1, mount, heading, travel, 0):
		return false

	var last: int = 1
	for k in range(2, count):
		if not _look_at(k, mount, heading, travel, last):
			break

		last = k

	_look_at(0, mount, heading, travel, 1)

	return _combine(wheel, count, travel)


func _plan_places(length: float) -> int:
	var reach: float = length + PATCH_HALF_M
	var ahead: int = clampi(ceili(reach / SAMPLE_SPACING_M), 1, MAX_SAMPLES - 2)

	_shifts[0] = -PATCH_HALF_M
	_shifts[1] = 0.0
	for i in range(1, ahead + 1):
		_shifts[i + 1] = reach * i / ahead

	var count: int = ahead + 2
	for k in range(count):
		_place_state[k] = 0

	return count


func _look_at(k: int, mount: Vector3, heading: Vector3, travel: float, neighbor: int) -> bool:
	var is_under: bool = k == 1
	var origin: Vector3 = mount + heading * _shifts[k]

	var buried: bool = not _space.get_rest_info(_query(_tire_start, origin)).is_empty()
	if buried and not is_under:
		return false

	_use_slices(SLICES if is_under else OUTER_SLICES)
	if not _scan_slices(origin, travel, buried, is_under):
		if is_under:
			return false

		_place_state[k] = 1
		_place_displacement[k] = 0.0

		return true

	var disp: float = travel - _scan_along
	if not is_under:
		var rise: float = disp - _place_displacement[neighbor]
		var gap: float = absf(_shifts[k] - _shifts[neighbor])

		if rise > MAX_RISE_PER_M * gap:
			return false

	_place_state[k] = 2
	_place_displacement[k] = disp
	_place_touch[k] = _scan_min

	if is_under:
		contact_normal = _scan_normal
		contact_point = _scan_contact - _shift

		collider_id = _scan_collider_id

	return true


func _combine(wheel: Node3D, count: int, travel: float) -> bool:
	var first: int = 0
	while _place_state[first] == 0:
		first += 1

	var last: int = count - 1
	while _place_state[last] == 0:
		last -= 1

	var weight_sum: float = 0.0
	var displacement_sum: float = 0.0

	var touch: float = travel

	for k in range(first, last + 1):
		var from: float = _shifts[k - 1] if k > first else _shifts[k]
		var to: float = _shifts[k + 1] if k < last else _shifts[k]

		var weight: float = 0.5 * (to - from) if last > first else 1.0

		weight_sum += weight
		displacement_sum += weight * _place_displacement[k]

		if _place_state[k] == 2:
			touch = minf(touch, _place_touch[k])

	displacement = displacement_sum / weight_sum

	hub_position = wheel.global_position + _down * (travel - displacement)

	first_touch_along = touch

	return true


func _fit_shapes(radius: float, width: float) -> void:
	if not is_equal_approx(_tire.radius, radius):
		_tire.radius = radius
		_slice.radius = radius
		_wide_slice.radius = radius

	if not is_equal_approx(_tire.height, width):
		_tire.height = width
		_slice.height = width / SLICES
		_wide_slice.height = width / OUTER_SLICES


func _use_slices(count: int) -> void:
	_slice_count = count
	_slice_shape = _slice if count == SLICES else _wide_slice

	_start.shape = _slice_shape
	_cast.shape = _slice_shape
	_rest.shape = _slice_shape


func _scan_slices(origin: Vector3, travel: float, tire_buried: bool, precise: bool) -> bool:
	var axis: Vector3 = _wheel_basis.y
	var slice_width: float = _slice_shape.height

	var touching_count: int = 0
	var along_sum: float = 0.0
	var reach_sum: float = 0.0

	var along_min: float = travel

	for i in range(_slice_count):
		var offset: float = (i - (_slice_count - 1) * 0.5) * slice_width
		_offsets[i] = offset

		var found: bool = _probe_slice(origin + axis * offset, travel, tire_buried, precise)

		_touching[i] = 1 if found else 0
		if not found:
			continue

		_alongs[i] = _found_along
		_normals[i] = _found_normal
		_slice_ids[i] = _found_collider_id

		touching_count += 1
		along_sum += _found_along
		reach_sum += _found_reach

		along_min = minf(along_min, _found_along)

	if touching_count == 0:
		return false

	var along: float = along_sum / touching_count

	_scan_along = along
	_scan_min = along_min

	if not precise:
		return true

	var reach: float = reach_sum / touching_count

	var normal_sum: Vector3 = Vector3.ZERO
	var side_sum: float = 0.0
	var weight_sum: float = 0.0

	_votes.clear()
	_scan_collider_id = 0

	var best_share: float = 0.0

	for i in range(_slice_count):
		if _touching[i] == 0:
			continue

		var weight: float = maxf(along - _alongs[i], 0.0) + SLICE_LOAD_FLOOR_M
		normal_sum += _normals[i] * weight
		side_sum += _offsets[i] * weight
		weight_sum += weight

		var share: float = _votes.get(_slice_ids[i], 0.0) + weight
		_votes[_slice_ids[i]] = share

		if share > best_share:
			best_share = share
			_scan_collider_id = _slice_ids[i]

	var normal: Vector3 = normal_sum.normalized()
	var hub: Vector3 = origin + _down * along

	_scan_normal = normal
	_scan_contact = hub - normal * reach + axis * (side_sum / weight_sum)

	return true


func _query(
	query: PhysicsShapeQueryParameters3D,
	position: Vector3,
) -> PhysicsShapeQueryParameters3D:
	query.transform = Transform3D(_wheel_basis, position)
	query.collision_mask = _mask
	query.exclude = _excluded

	return query


func _probe_slice(origin: Vector3, travel: float, check_buried: bool, precise: bool) -> bool:
	if check_buried:
		var buried: Dictionary = _space.get_rest_info(_query(_start, origin))

		if not buried.is_empty():
			return _squash(buried, origin)

	_cast.motion = _down * travel
	var fractions: PackedFloat32Array = _space.cast_motion(_query(_cast, origin))
	if fractions.size() < 2 or fractions[1] >= 1.0:
		return false

	var along: float = travel * (fractions[0] + fractions[1]) * 0.5
	if not precise:
		_found_along = clampf(along, 0.0, travel)

		return true

	var touch: Vector3 = origin + _down * (travel * fractions[1])
	var info: Dictionary = _space.get_rest_info(_query(_rest, touch))
	_found_collider_id = info.get("collider_id", 0)

	var normal: Vector3 = -_down
	if not info.is_empty() and (info["normal"] as Vector3).length_squared() > 0.5:
		normal = (info["normal"] as Vector3).normalized()

	if normal.dot(-_down) < MIN_GROUND_COS:
		return _find_with_ray(origin)

	var tilt: float = normal.dot(_wheel_basis.y)
	var round_part: float = _config.wheel_radius * sqrt(maxf(1.0 - tilt * tilt, 0.0))
	var reach: float = round_part + _slice_shape.height * 0.5 * absf(tilt)

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
	_found_collider_id = buried.get("collider_id", 0)

	var normal: Vector3 = buried["normal"]
	if normal.length_squared() < 0.5 or normal.dot(-_down) < MIN_GROUND_COS:
		return _find_with_ray(origin)

	normal = normal.normalized()

	var tilt: float = normal.dot(_wheel_basis.y)
	var round_part: float = _config.wheel_radius * sqrt(maxf(1.0 - tilt * tilt, 0.0))
	var reach: float = round_part + _slice_shape.height * 0.5 * absf(tilt)

	var along: float = 0.0
	if buried.has("point"):
		along = ((reach - normal.dot(origin - (buried["point"] as Vector3))) / normal.dot(_down))

	_found_along = clampf(along, -_config.wheel_radius, 0.0)
	_found_normal = normal
	_found_reach = reach

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

	_found_collider_id = hit.get("collider_id", 0)

	var distance: float = origin.distance_to(hit["position"])

	_found_along = clampf(
		distance - _config.wheel_radius,
		-_config.wheel_radius,
		_config.suspension_rest_length,
	)

	_found_normal = hit["normal"]
	_found_reach = _config.wheel_radius

	return true
