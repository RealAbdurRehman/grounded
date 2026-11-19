class_name TireDeflection
extends RefCounted

## Rows of rays across the tire width.
const LANES: int = 5

## Rays per row.
const ANGLES: int = 49

## Angle between two neighboring rays.
const ANGLE_STEP_RAD: float = 0.069813170

const LANE_SPAN: float = 0.9

## How fast the squash relaxes.
const RELEASE_SPEED_MPS: float = 3.0

const COARSE: int = 2
const NEAR_M: float = 0.03

const ROW_DIFF_M: float = 0.002

const MISS: float = -0.031

const SLANT_FULL_COS: float = 0.5
const SLANT_NONE_COS: float = 0.15

const SIDE_ANGLES: int = 9
const SIDE_STEP_RAD: float = 0.2617994

const SIDE_REACH_M: float = 0.08
const SIDE_HEIGHT: float = 0.9

const SIDE_FREE_M: float = 10.0

const BOOK_WIDTH_PER_STRAIN: float = 0.444

const WIDEN_SHARE: float = 0.3

const MAX_BULGE_M: float = 0.03

var depths: PackedFloat32Array = PackedFloat32Array()

var side_room: PackedFloat32Array = PackedFloat32Array()

var _raw: PackedFloat32Array = PackedFloat32Array()
var _ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()

var _local_directions: PackedVector3Array = PackedVector3Array()
var _directions: PackedVector3Array = PackedVector3Array()
var _direction_ready: PackedByteArray = PackedByteArray()

var _near_from: int = ANGLES
var _near_to: int = -1

var _dirty_from: int = ANGLES
var _dirty_to: int = -1

var _space: PhysicsDirectSpaceState3D
var _basis: Basis = Basis.IDENTITY
var _radius: float = 0.3


func _init() -> void:
	depths.resize(LANES * ANGLES)

	side_room.resize(SIDE_ANGLES * 2)
	side_room.fill(SIDE_FREE_M)

	_raw.resize(LANES * ANGLES)

	_directions.resize(ANGLES)
	_direction_ready.resize(ANGLES)

	var middle: float = (ANGLES - 1) * 0.5
	for k in range(ANGLES):
		var angle: float = (k - middle) * ANGLE_STEP_RAD
		_local_directions.append(Vector3(0.0, -cos(angle), -sin(angle)))


func update(
	space: PhysicsDirectSpaceState3D,
	exclude: Array[RID],
	mask: int,
	hub: Vector3,
	hub_basis: Basis,
	config: SuspensionConfig,
	delta: float,
) -> void:
	_space = space
	_basis = hub_basis
	_radius = config.wheel_radius

	_ray.collision_mask = mask
	_ray.exclude = exclude

	_direction_ready.fill(0)

	_raw.fill(MISS)

	_near_from = ANGLES
	_near_to = -1

	var row_offset: float = LANE_SPAN * config.width_m() * 0.5
	var half_lanes: float = (LANES - 1) * 0.5

	for lane in range(0, LANES, 2):
		_cast_row(lane, hub + hub_basis.x * ((lane - half_lanes) / half_lanes * row_offset))

	if _near_to >= 0:
		for lane in range(1, LANES, 2):
			_fill_row(lane, hub + hub_basis.x * ((lane - half_lanes) / half_lanes * row_offset))

	_store(config.max_squash_m(), RELEASE_SPEED_MPS * delta)
	_look_sideways(hub, hub_basis, config)


static func setup_material(material: ShaderMaterial, config: SuspensionConfig) -> void:
	var width: float = config.width_m()
	var per_side: float = 0.5 * BOOK_WIDTH_PER_STRAIN * width / config.sidewall_m()

	material.set_shader_parameter("squash_radius", config.wheel_radius)
	material.set_shader_parameter("squash_rim_radius", config.rim_m())
	material.set_shader_parameter("squash_half_width", width * 0.5)
	material.set_shader_parameter("squash_lane_offset", LANE_SPAN * width * 0.5)
	material.set_shader_parameter("squash_step", ANGLE_STEP_RAD)
	material.set_shader_parameter("squash_bulge", per_side)
	material.set_shader_parameter("squash_widen", per_side * WIDEN_SHARE)
	material.set_shader_parameter("squash_bulge_max", MAX_BULGE_M)

	var free: PackedFloat32Array = PackedFloat32Array()
	free.resize(SIDE_ANGLES * 2)
	free.fill(SIDE_FREE_M)

	material.set_shader_parameter("squash_side", free)


func apply_to(
	material: ShaderMaterial,
	hub_basis: Basis,
	config: SuspensionConfig,
	shear_m: float = 0.0,
	twist_rad: float = 0.0,
	reach_rad: float = 1.0,
) -> void:
	var middle: int = int(LANES / 2.0) * ANGLES + int((ANGLES - 1) / 2.0)
	var contact_half_angle: float = sqrt(2.0 * depths[middle] / maxf(config.wheel_radius, 0.01))

	material.set_shader_parameter("squash_depth", depths)
	material.set_shader_parameter("squash_side", side_room)
	material.set_shader_parameter("squash_hub_basis", hub_basis)
	material.set_shader_parameter(
		"squash_shear",
		Vector4(shear_m, twist_rad, contact_half_angle, reach_rad),
	)


func _look_sideways(hub: Vector3, hub_basis: Basis, config: SuspensionConfig) -> void:
	var reach: float = config.width_m() * 0.5 + SIDE_REACH_M
	var height: float = config.wheel_radius * SIDE_HEIGHT

	for k in range(SIDE_ANGLES):
		var angle: float = (k - int(SIDE_ANGLES / 2.0)) * SIDE_STEP_RAD
		var origin: Vector3 = hub + hub_basis * Vector3(0.0, -cos(angle), -sin(angle)) * height

		for side in range(2):
			var direction: Vector3 = hub_basis.x * (-1.0 if side == 0 else 1.0)

			_ray.from = origin
			_ray.to = origin + direction * reach

			var room: float = SIDE_FREE_M
			var hit: Dictionary = _space.intersect_ray(_ray)

			if not hit.is_empty() and absf((hit["normal"] as Vector3).dot(hub_basis.x)) > 0.5:
				room = origin.distance_to(hit["position"])

			side_room[side * SIDE_ANGLES + k] = room


func _store(cap: float, relax_by: float) -> void:
	var from: int = mini(_near_from, _dirty_from)
	var to: int = maxi(_near_to, _dirty_to)

	_dirty_from = ANGLES
	_dirty_to = -1

	if to < 0:
		return

	for lane in range(LANES):
		var base: int = lane * ANGLES
		for k in range(from, to + 1):
			var depth: float = clampf(_raw[base + k], 0.0, cap)
			depth = maxf(depth, depths[base + k] - relax_by)

			depths[base + k] = depth

			if depth > 0.0:
				_dirty_from = mini(_dirty_from, k)
				_dirty_to = maxi(_dirty_to, k)


func _cast_row(lane: int, start: Vector3) -> void:
	var base: int = lane * ANGLES

	var from: int = ANGLES
	var to: int = -1
	for k in range(0, ANGLES, COARSE):
		var raw: float = _cast(start, k)
		_raw[base + k] = raw

		if raw > -NEAR_M:
			from = mini(from, k)
			to = maxi(to, k)

	if to < 0:
		return

	from = maxi(from - COARSE, 0)
	to = mini(to + COARSE, ANGLES - 1)

	_near_from = mini(_near_from, from)
	_near_to = maxi(_near_to, to)

	var step: int = int(COARSE / 2.0)
	while step >= 1:
		var span: int = step * 2
		for k in range(from - from % span, to + 1, span):
			if k + span > ANGLES - 1:
				break

			var near: float = _raw[base + k]
			var far: float = _raw[base + k + span]

			if maxf(near, far) > -NEAR_M:
				_raw[base + k + step] = _cast(start, k + step)
			else:
				_raw[base + k + step] = (near + far) * 0.5

		step /= 2


func _fill_row(lane: int, start: Vector3) -> void:
	var base: int = lane * ANGLES

	var before: int = base - ANGLES
	var after: int = base + ANGLES

	for k in range(_near_from, _near_to + 1):
		var a: float = _raw[before + k]
		var b: float = _raw[after + k]

		if absf(a - b) > ROW_DIFF_M and maxf(a, b) > -NEAR_M:
			_raw[base + k] = _cast(start, k)
		else:
			_raw[base + k] = (a + b) * 0.5


func _cast(start: Vector3, k: int) -> float:
	if _direction_ready[k] == 0:
		_directions[k] = _basis * _local_directions[k]
		_direction_ready[k] = 1

	_ray.from = start
	_ray.to = start + _directions[k] * (_radius + NEAR_M)

	var hit: Dictionary = _space.intersect_ray(_ray)
	if hit.is_empty():
		return MISS

	var squash: float = _radius - start.distance_to(hit["position"])
	if squash <= 0.0:
		return squash

	return squash * slant_weight(-_directions[k].dot(hit["normal"]))


static func slant_weight(head_on: float) -> float:
	return smoothstep(SLANT_NONE_COS, SLANT_FULL_COS, head_on)
