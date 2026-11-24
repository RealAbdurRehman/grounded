class_name CarDamage
extends RefCounted

signal part_hit(part_name: String, points: PackedVector3Array, direction: Vector3, delta_v: float)
signal piece_pushed(piece_name: String, impulse_ns: float)

signal repaired

const MIN_DELTA_V_MPS: float = 2.5
const FULL_DELTA_V_MPS: float = 15.6

const MAX_CONTACTS: int = 64

const SPAWN_PROTECTION_MS: int = 3000

const FLOOR_NORMAL_Y: float = 0.75
const MIN_FLOOR_DELTA_V_MPS: float = 8.0

const PIECE_PREFIX: String = "Collision"


class Part extends RefCounted:
	var damage: float = 0.0

	var last_delta_v: float = 0.0
	var peak_delta_v: float = 0.0

	var hits: int = 0
	var was_hit: bool = false


var parts: Dictionary[String, Part] = { }

var last_delta_v: float = 0.0
var peak_delta_v: float = 0.0

var last_part: String = ""

var _car: RigidBody3D
var _child_count: int = -1

var _spawn_ms: int = 0


func _init(car: RigidBody3D) -> void:
	_car = car

	_car.contact_monitor = true
	_car.max_contacts_reported = MAX_CONTACTS

	_spawn_ms = Time.get_ticks_msec()


func step() -> void:
	_find_parts()

	if Time.get_ticks_msec() - _spawn_ms < SPAWN_PROTECTION_MS:
		return

	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(_car.get_rid())
	if state == null:
		return

	var impulses: Dictionary[String, Vector3] = { }
	var points: Dictionary[String, PackedVector3Array] = { }

	var floor_impulses: Dictionary[String, Vector3] = { }
	var floor_points: Dictionary[String, PackedVector3Array] = { }

	for i in range(state.get_contact_count()):
		var impulse: Vector3 = state.get_contact_impulse(i)
		var part_name: String = _part_at(state.get_contact_local_shape(i))

		var on_floor: bool = absf(state.get_contact_local_normal(i).y) > FLOOR_NORMAL_Y

		var sums: Dictionary[String, Vector3] = floor_impulses if on_floor else impulses
		var spots: Dictionary[String, PackedVector3Array] = floor_points if on_floor else points

		sums[part_name] = sums.get(part_name, Vector3.ZERO) + impulse

		var list: PackedVector3Array = spots.get(part_name, PackedVector3Array())
		list.append(_car.to_local(state.get_contact_local_position(i)))
		spots[part_name] = list

	for part_name in floor_impulses:
		var landing: Vector3 = floor_impulses[part_name]

		if landing.length() / _car.mass > MIN_FLOOR_DELTA_V_MPS:
			impulses[part_name] = impulses.get(part_name, Vector3.ZERO) + landing

			var list: PackedVector3Array = points.get(part_name, PackedVector3Array())
			list.append_array(floor_points[part_name])
			points[part_name] = list

	var total: Vector3 = Vector3.ZERO
	for part_name in impulses:
		total += impulses[part_name]

	var car_delta_v: float = total.length() / _car.mass
	if car_delta_v > MIN_DELTA_V_MPS:
		last_delta_v = car_delta_v
		peak_delta_v = maxf(peak_delta_v, car_delta_v)

	var to_car: Basis = _car.global_basis.inverse()

	for part_name in parts:
		var impulse: Vector3 = impulses.get(part_name, Vector3.ZERO)
		var delta_v: float = impulse.length() / _car.mass

		if impulse.length_squared() > 0.0:
			piece_pushed.emit(part_name, impulse.length())

		if _hit(part_name, parts[part_name], delta_v):
			part_hit.emit(part_name, points[part_name], (to_car * impulse).normalized(), delta_v)


func reset() -> void:
	last_delta_v = 0.0
	peak_delta_v = 0.0

	last_part = ""

	for part_name in parts:
		var part: Part = parts[part_name]

		part.damage = 0.0

		part.last_delta_v = 0.0
		part.peak_delta_v = 0.0

		part.hits = 0

	repaired.emit()


func _hit(part_name: String, part: Part, delta_v: float) -> bool:
	var hit: bool = delta_v > MIN_DELTA_V_MPS

	if hit:
		var energy: float = delta_v * delta_v - MIN_DELTA_V_MPS * MIN_DELTA_V_MPS
		part.damage = minf(part.damage + energy / (FULL_DELTA_V_MPS * FULL_DELTA_V_MPS), 1.0)

		part.last_delta_v = delta_v
		part.peak_delta_v = maxf(part.peak_delta_v, delta_v)

		if not part.was_hit:
			part.hits += 1

		last_part = part_name

	part.was_hit = hit

	return hit


func _find_parts() -> void:
	if _car.get_child_count() == _child_count:
		return

	_child_count = _car.get_child_count()

	for child in _car.get_children():
		if child is CollisionShape3D:
			_part(_part_name(child.name))


func _part_at(shape_index: int) -> String:
	var owner: Object = _car.shape_owner_get_owner(_car.shape_find_owner(shape_index))
	if owner == null:
		return "Body"

	var part_name: String = _part_name((owner as Node).name)
	_part(part_name)

	return part_name


func _part(part_name: String) -> Part:
	if not parts.has(part_name):
		parts[part_name] = Part.new()

	return parts[part_name]


func _part_name(piece_name: String) -> String:
	var part_name: String = piece_name.trim_prefix(PIECE_PREFIX).rstrip("0123456789")
	return part_name if part_name != "" else "Body"
