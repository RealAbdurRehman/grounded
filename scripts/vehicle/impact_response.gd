class_name ImpactResponse
extends RefCounted

const ONSET_MPS: float = 2.0
const PEAK_BOUNCE: float = 0.75
const BOUNCE_FALLOFF: float = 0.94
const MAX_BOUNCE: float = 0.4

const MIN_CLOSING_MPS: float = 1.0
const MIN_PUSH_MPS: float = 0.1

const QUIET_TICKS: int = 6

var _car: RigidBody3D

var _velocity: Vector3
var _spin: Vector3

var _hardest_mps: float = 0.0
var _quiet: int = 0


func _init(car: RigidBody3D) -> void:
	_car = car


func step() -> void:
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(_car.get_rid())
	if state == null:
		return

	var touching: PackedInt32Array = _wall_contacts(state)

	if touching.is_empty():
		_quiet += 1

		if _quiet >= QUIET_TICKS:
			_hardest_mps = 0.0
	else:
		_quiet = 0

		var closing: float = _closing_mps(state, touching)
		if closing >= MIN_CLOSING_MPS:
			_hardest_mps = maxf(_hardest_mps, closing)
			_push_apart(state, touching, _bounce_at(_hardest_mps))

	_velocity = _car.linear_velocity
	_spin = _car.angular_velocity


func _wall_contacts(state: PhysicsDirectBodyState3D) -> PackedInt32Array:
	var found := PackedInt32Array()
	var push: float = 0.0

	for i in range(state.get_contact_count()):
		var normal: Vector3 = state.get_contact_local_normal(i)
		if absf(normal.y) > CarDamage.FLOOR_NORMAL_Y:
			continue

		var along: float = absf(state.get_contact_impulse(i).dot(normal))
		if along > 0.0:
			found.append(i)
			push += along

	if push < _car.mass * MIN_PUSH_MPS:
		found.clear()

	return found


func _closing_mps(state: PhysicsDirectBodyState3D, touching: PackedInt32Array) -> float:
	var total: float = 0.0
	var weights: float = 0.0

	var center: Vector3 = _car.global_transform * _car.center_of_mass

	for i in touching:
		var normal: Vector3 = state.get_contact_local_normal(i)
		var point: Vector3 = state.get_contact_local_position(i)

		var weight: float = absf(state.get_contact_impulse(i).dot(normal))
		var moving: Vector3 = _velocity + _spin.cross(point - center)

		var other := state.get_contact_collider_object(i) as RigidBody3D
		if other != null:
			moving -= state.get_contact_collider_velocity_at_position(i)

		total += maxf(-moving.dot(normal), 0.0) * weight
		weights += weight

	return total / weights if weights > 0.0 else 0.0


func _bounce_at(closing_mps: float) -> float:
	var eased: float = 1.0 - ONSET_MPS / maxf(closing_mps, ONSET_MPS)
	return minf(PEAK_BOUNCE * (1.0 - BOUNCE_FALLOFF * eased), MAX_BOUNCE)


func _push_apart(
	state: PhysicsDirectBodyState3D,
	touching: PackedInt32Array,
	bounce: float,
) -> void:
	for i in touching:
		var normal: Vector3 = state.get_contact_local_normal(i)
		var push: Vector3 = normal * absf(state.get_contact_impulse(i).dot(normal)) * bounce

		_car.apply_impulse(push, state.get_contact_local_position(i) - _car.global_position)

		var other := state.get_contact_collider_object(i) as RigidBody3D
		if other != null and not other.freeze:
			other.apply_impulse(
				-push,
				state.get_contact_collider_position(i) - other.global_position,
			)
