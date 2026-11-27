class_name MechanicalDamage
extends RefCounted

enum Part {
	RADIATOR,
	INTERCOOLER,
	ENGINE,
	OIL_PAN,
	POWER_STEERING,
	STEERING_RACK,
	GEARBOX,
	DRIVESHAFT,
	AXLE_FRONT_LEFT,
	AXLE_FRONT_RIGHT,
	AXLE_REAR_LEFT,
	AXLE_REAR_RIGHT,
}

const PART_NAMES: Array[String] = [
	"Radiator",
	"Intercooler",
	"Engine",
	"Oil pan",
	"Power steering",
	"Steering rack",
	"Gearbox",
	"Driveshaft",
	"Front left axle",
	"Front right axle",
	"Rear left axle",
	"Rear right axle",
]

const HIT_LIMITS: Array[float] = [0.4, 0.4, 0.25, 0.35, 0.4, 0.35, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3]
const IMPACT_WINDOW_S: float = 1.5

const SPAWN_SAFE_S: float = 3.0

const HISTORY_TICKS: int = 12
const SLOWED_RATIO: float = 1.2
const SLOWED_SLACK_MPS: float = 1.0

const REACH_PAST_M: float = 0.2
const UNDERSIDE_PUSH_Y: float = 0.75

const UNDERSIDE_CRUSH: float = 0.35
const REPEAT_HIT_SHARE: float = 0.5

const STRIKE_WINDOW_S: float = 0.05
const STRIKE_YIELD_NS: float = 2000.0
const STRIKE_BREAK_NS: float = 4000.0

const STRIKE_MARGIN_M: float = 0.15
const STRIKE_HEIGHT_M: float = 0.1

const WARM_C: float = 88.0

const IDLE_HEAT_KW: float = 7.0
const HEAT_PER_KW: float = 0.85
const BLOCK_KW_K: float = 0.04
const BLOCK_FLOW_KW_K: float = 0.1

const RADIATOR_STILL_KW_K: float = 0.45
const RADIATOR_FLOW_KW_K: float = 2.4

const RADIATOR_FLOW_MPS: float = 30.0
const RADIATOR_FLOW_POWER: float = 0.65

const CRUSHED_CORE_LOSS: float = 0.75

const FAN_ON_C: float = 96.0
const FAN_MPS: float = 10.0

const STAT_SHUT_C: float = 82.0
const STAT_OPEN_C: float = 92.0
const STAT_BYPASS: float = 0.05

const METAL_KJ_K: float = 55.0

const COOLANT_KJ_K: float = 35.0
const COOLANT_DRY_AT: float = 0.15
const COOLANT_FULL_AT: float = 0.75
const COOLANT_LEAK_PER_S: float = 0.012
const COOLANT_DRAINS: float = 0.85

const BOIL_C: float = 120.0
const BOIL_PER_C_S: float = 0.0015
const MAX_COOLANT_C: float = 150.0

const LIMP_START_C: float = 108.0
const LIMP_FULL_C: float = 122.0
const LIMP_POWER: float = 0.35

const HEAD_DAMAGE_C: float = 118.0
const HEAD_DAMAGE_PER_C_S: float = 0.0008

const OIL_LEAK_PER_S: float = 0.01
const OIL_SEEP_PER_S: float = 0.001
const OIL_DRAINS: float = 0.75

const OIL_DRY_AT: float = 0.15
const OIL_FULL_AT: float = 0.6

const OIL_SURGE_FROM_G: float = 0.4
const OIL_SURGE_PER_G: float = 0.15

const OIL_SLOSH_S: float = 0.2
const DRY_WEAR_PER_S: float = 0.003
const DRY_REV_WEAR_PER_S: float = 0.025

const OVERREV_MARGIN_RPM: float = 600.0
const OVERREV_PER_S: float = 0.12

const WEAK_POWER: float = 0.6

const MISFIRE_BELOW: float = 0.5
const MISFIRE_PER_HEALTH: float = 1.2

const MISFIRE_MAX: float = 0.4
const MISFIRE_S: float = 0.07
const MISFIRE_POWER: float = 0.5

const WORN_DRAG_NM: float = 15.0
const DRY_DRAG_NM: float = 40.0

const SEIZED_NM: float = 400.0

const BOOST_LOSS: float = 0.5

const STEER_ARM_M: float = 0.14

const ROD_YIELD_N: float = 20000.0
const ROD_BREAK_N: float = 60000.0

const OFFSET_PER_N: float = 0.000001
const MAX_OFFSET_RAD: float = 0.04
const CRUSH_OFFSET_RAD: float = 0.025

const MAX_PLAY_RAD: float = 0.025
const BENT_LOCK_LOSS: float = 0.35
const BENT_FRICTION_NM: float = 60.0

const NO_ASSIST_FRICTION_NM: float = 40.0
const NO_ASSIST_STRENGTH: float = 0.55
const NO_ASSIST_RATE: float = 0.5

const LINE_YIELD_N: float = 70000.0
const LINE_BREAK_N: float = 80000.0

const BRAKE_PUMP_PER_S: float = 0.5
const BRAKE_DRIP_PER_S: float = 0.01
const BRAKE_FULL_AT: float = 0.5

const SLOW_SHIFT: float = 3.0
const POP_FROM: float = 0.7
const POP_PER_S: float = 0.8
const RESELECT_S: float = 0.6

const AXLE_YIELD_N: float = 50000.0
const AXLE_BREAK_N: float = 100000.0
const AXLE_TORQUE_NM: float = 2400.0
const AXLE_WEAK_FROM: float = 0.2
const AXLE_GRIND_PER_S: float = 0.3

const DAMPER_SAFE_MPS: float = 7.0
const DAMPER_PER_MPS: float = 0.1

const DAMPER_YIELD_N: float = 50000.0
const DAMPER_BREAK_N: float = 80000.0

const DAMPER_MAX_LOSS: float = 0.75


class Box extends RefCounted:
	var center: Vector3
	var half: Vector3

	var break_m: float = 0.1


var damage: Array[float] = []

var coolant: float = 1.0
var coolant_c: float = WARM_C

var oil: float = 1.0
var oil_pressure: float = 1.0

var seized: bool = false

var steer_offset_rad: float = 0.0

var brake_leak: Array[float] = [0.0, 0.0]
var brake_fluid: Array[float] = [1.0, 1.0]

var aero_drag: float = 1.0
var lift_front: float = 0.0
var lift_rear: float = 0.0

var _vehicle: Vehicle
var _boxes: Array[Box] = []
var _random := RandomNumberGenerator.new()

var _clock: float = 0.0

var _history: PackedVector3Array = PackedVector3Array()
var _head: int = 0

var _last_velocity: Vector3 = Vector3.ZERO
var _sloshing_g: float = 0.0

var _misfire: float = 1.0
var _misfire_s: float = 0.0

var _rack_rad: float = 0.0

var _strike_ns: Dictionary[int, float] = { }
var _counted_ns: Dictionary[int, float] = { }

var _damper: Dictionary[Wheel, float] = { }

var _impact_base: Array[float] = []
var _last_hit_s: float = -INF

var _reselect_s: float = 0.0
var _reselect_gear: int = 2


func _init(vehicle: Vehicle) -> void:
	_vehicle = vehicle

	_random.randomize()
	_history.resize(HISTORY_TICKS)

	_place_parts()

	damage.resize(_boxes.size())
	damage.fill(0.0)

	_impact_base = damage.duplicate()


func on_crash(points: PackedVector3Array, push: Vector3, delta_v: float) -> void:
	if points.is_empty():
		return

	delta_v = minf(delta_v, _slowed_by().length() * SLOWED_RATIO + SLOWED_SLACK_MPS)

	var side: Vector3 = push.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT

	side = side.normalized()
	var up: Vector3 = push.cross(side).normalized()

	var plane: float = INF
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)

	for point in _vehicle.deformer._probe(points, push):
		var across := Vector2(point.dot(side), point.dot(up))

		low = low.min(across)
		high = high.max(across)
		plane = minf(plane, point.dot(push))

	var width: float = clampf(high.x - low.x, CarDeformer.MIN_WIDTH_M, CarDeformer.MAX_WIDTH_M)
	var crush: float = _crush_depth_m(delta_v / _vehicle.mechanical_toughness, width)

	if push.y > UNDERSIDE_PUSH_Y:
		crush *= UNDERSIDE_CRUSH

	_note_hit()

	for part in range(_boxes.size()):
		var box: Box = _boxes[part]

		var depth: float = maxf(box.center.dot(push) - _extent(box.half, push) - plane, 0.0)
		var gap: float = maxf(
			_gap(box.center.dot(side), _extent(box.half, side), low.x, high.x),
			_gap(box.center.dot(up), _extent(box.half, up), low.y, high.y),
		)

		var intrusion: float = (crush - depth) * (1.0 - clampf(gap / REACH_PAST_M, 0.0, 1.0))
		if intrusion > 0.0:
			_crush(part, minf(intrusion / box.break_m, 1.0), push)


func on_wheel_load(state: WheelDamage.WheelState, spot: Vector3, push: Vector3) -> void:
	push /= _vehicle.mechanical_toughness

	var wheel: Wheel = state.wheel
	var line: int = circuit_of(wheel)

	var cracked: float = clampf((push.length() - LINE_YIELD_N) / LINE_BREAK_N, 0.0, 1.0)
	brake_leak[line] = maxf(brake_leak[line], cracked)

	_note_hit()

	var axle: int = axle_of(wheel)
	var strain: float = clampf((push.length() - AXLE_YIELD_N) / AXLE_BREAK_N, 0.0, 1.0)
	damage[axle] = maxf(damage[axle], _limited(axle, strain))

	if not wheel.can_steer:
		return

	var hub: Vector3 = _vehicle.to_local(wheel.hub_world_position())
	var twist: float = (spot - hub).cross(push).y

	var over: float = absf(twist) / STEER_ARM_M - ROD_YIELD_N
	if over <= 0.0:
		return

	var rack: int = Part.STEERING_RACK
	damage[rack] = maxf(damage[rack], _limited(rack, minf(over / ROD_BREAK_N, 1.0)))

	var bent: float = signf(twist) * minf(over * OFFSET_PER_N, MAX_OFFSET_RAD)
	if absf(bent) > absf(steer_offset_rad):
		steer_offset_rad = bent


func step(delta: float) -> void:
	_clock += delta

	_history[_head] = _vehicle.linear_velocity
	_head = (_head + 1) % HISTORY_TICKS

	if _clock > SPAWN_SAFE_S:
		_belly_strikes(delta)

	_step_cooling(delta)
	_step_oil(delta)
	_step_engine(delta)
	_step_brakes(delta)
	_step_dampers()
	_step_aero()
	_step_reselect(delta)


func repair() -> void:
	damage.fill(0.0)

	coolant = 1.0
	coolant_c = WARM_C

	oil = 1.0
	oil_pressure = 1.0

	seized = false

	steer_offset_rad = 0.0
	_rack_rad = 0.0

	brake_leak = [0.0, 0.0]
	brake_fluid = [1.0, 1.0]

	_misfire = 1.0

	_strike_ns.clear()
	_counted_ns.clear()
	_damper.clear()

	_impact_base = damage.duplicate()
	_last_hit_s = -INF
	_reselect_s = 0.0


func repair_part(part: int) -> void:
	damage[part] = 0.0
	_impact_base[part] = 0.0

	match part:
		Part.RADIATOR:
			coolant = 1.0
			coolant_c = minf(coolant_c, WARM_C)
		Part.ENGINE:
			seized = false
			_misfire = 1.0
		Part.OIL_PAN:
			oil = 1.0
		Part.STEERING_RACK:
			steer_offset_rad = 0.0


func repair_brakes(line: int) -> void:
	brake_leak[line] = 0.0
	brake_fluid[line] = 1.0


func break_part(part: int) -> void:
	_hurt(part, 0.5, Vector3.RIGHT)


func cut_brake_line(line: int) -> void:
	brake_leak[line] = 1.0


func engine_health() -> float:
	return 1.0 - damage[Part.ENGINE]


func power_factor() -> float:
	if seized:
		return 0.0

	var hot: float = clampf(inverse_lerp(LIMP_START_C, LIMP_FULL_C, coolant_c), 0.0, 1.0)
	return lerpf(WEAK_POWER, 1.0, engine_health()) * lerpf(1.0, LIMP_POWER, hot) * _misfire


func boost_factor() -> float:
	return 1.0 - BOOST_LOSS * damage[Part.INTERCOOLER]


func engine_drag_nm() -> float:
	return damage[Part.ENGINE] * WORN_DRAG_NM + (1.0 - oil_pressure) * DRY_DRAG_NM


func seized_torque_nm(wheel: Wheel) -> float:
	var drive: Drivetrain = _vehicle.drivetrain_node
	if not seized or not drive.is_clutch_engaged():
		return 0.0

	var ratio: float = absf(drive.get_current_ratio()) * drive.config.final_drive_ratio
	return SEIZED_NM * ratio * drive.get_wheel_share(wheel)


func steering_assist() -> float:
	return 0.0 if seized else 1.0 - damage[Part.POWER_STEERING]


func steer_strength_scale() -> float:
	return lerpf(NO_ASSIST_STRENGTH, 1.0, steering_assist())


func steer_rate_scale() -> float:
	return lerpf(NO_ASSIST_RATE, 1.0, steering_assist())


func steer_friction_nm() -> float:
	return (
		damage[Part.STEERING_RACK] * BENT_FRICTION_NM
		+ (1.0 - steering_assist()) * NO_ASSIST_FRICTION_NM
	)


func steer_lock_scale() -> float:
	return 1.0 - BENT_LOCK_LOSS * damage[Part.STEERING_RACK]


func steer_play_rad() -> float:
	return MAX_PLAY_RAD * damage[Part.STEERING_RACK]


func road_angle(wheel_rad: float) -> float:
	var play: float = steer_play_rad()
	_rack_rad = clampf(_rack_rad, wheel_rad - play, wheel_rad + play)

	return _rack_rad + steer_offset_rad


func circuit_of(wheel: Wheel) -> int:
	var left: bool = _vehicle.to_local(wheel.global_position).x < 0.0
	return 0 if wheel.is_front == left else 1


func brake_pressure(line: int) -> float:
	return clampf(brake_fluid[line] / BRAKE_FULL_AT, 0.0, 1.0)


func brake_factor(wheel: Wheel) -> float:
	return brake_pressure(circuit_of(wheel))


func shift_time_scale() -> float:
	return 1.0 + SLOW_SHIFT * damage[Part.GEARBOX]


func pops_out(delta: float, throttle: float) -> bool:
	var worn: float = damage[Part.GEARBOX]
	if worn <= POP_FROM or throttle < 0.5:
		return false

	if _random.randf() >= (worn - POP_FROM) * POP_PER_S * delta:
		return false

	_reselect_s = RESELECT_S
	_reselect_gear = _vehicle.drivetrain_node.current_gear_index

	return true


func axle_of(wheel: Wheel) -> int:
	var left: bool = _vehicle.to_local(wheel.global_position).x < 0.0
	if wheel.is_front:
		return Part.AXLE_FRONT_LEFT if left else Part.AXLE_FRONT_RIGHT

	return Part.AXLE_REAR_LEFT if left else Part.AXLE_REAR_RIGHT


func broken_axles() -> Array[Wheel]:
	var loose: Array[Wheel] = []

	for wheel in _vehicle.wheels:
		var broken: bool = damage[axle_of(wheel)] >= 1.0
		if not wheel.is_front:
			broken = broken or damage[Part.DRIVESHAFT] >= 1.0

		if broken and wheel.is_driven:
			loose.append(wheel)

	return loose


func load_axles(torques: Dictionary[Wheel, float], delta: float) -> void:
	for wheel in torques:
		var axle: int = axle_of(wheel)
		var worn: float = damage[axle]
		if worn <= AXLE_WEAK_FROM or worn >= 1.0:
			continue

		var excess: float = absf(torques[wheel]) / (AXLE_TORQUE_NM * (1.0 - worn)) - 1.0
		if excess > 0.0:
			_hurt(axle, excess * AXLE_GRIND_PER_S * delta)


func damper_health(wheel: Wheel) -> float:
	return _damper.get(wheel, 1.0)


func _place_parts() -> void:
	var front: Vector3 = _axle_middle(_vehicle.front_axle())
	var rear: Vector3 = _axle_middle(_vehicle.rear_axle())

	var body := _vehicle.get_node(^"Body") as CarBody
	var radiator_z: float = -body.definition.radiator_ahead_m

	_add_box(front + Vector3(0.0, 0.09, radiator_z), Vector3(0.36, 0.16, 0.03), 0.25)
	_add_box(front + Vector3(0.0, 0.4, -0.12), Vector3(0.26, 0.05, 0.2), 0.25)
	_add_box(front + Vector3(0.0, 0.09, -0.3), Vector3(0.34, 0.12, 0.19), 0.5)
	_add_box(front + Vector3(0.0, -0.09, -0.3), Vector3(0.18, 0.03, 0.18), 0.25)
	_add_box(front + Vector3(0.22, 0.19, -0.52), Vector3(0.08, 0.08, 0.05), 0.25)
	_add_box(front + Vector3(0.0, -0.03, 0.16), Vector3(0.52, 0.04, 0.04), 0.3)
	_add_box(front + Vector3(0.0, 0.02, 0.42), Vector3(0.18, 0.08, 0.35), 0.45)
	_add_box((front + rear) * 0.5 + Vector3(0.0, -0.03, 0.05), Vector3(0.05, 0.04, 0.6), 0.3)

	for middle in [front, rear]:
		for side in [-1.0, 1.0]:
			_add_box(middle + Vector3(side * 0.45, 0.0, 0.0), Vector3(0.2, 0.04, 0.04), 0.35)


func _axle_middle(wheels: Array[Wheel]) -> Vector3:
	var middle: Vector3 = Vector3.ZERO
	for wheel in wheels:
		var config: SuspensionConfig = wheel.suspension_config

		middle += _vehicle.to_local(wheel.global_position)
		middle.y -= config.suspension_rest_length - config.alignment_compression

	return middle / float(wheels.size())


func _add_box(center: Vector3, half: Vector3, break_m: float) -> void:
	var box := Box.new()
	box.center = center
	box.half = half
	box.break_m = break_m

	_boxes.append(box)


func _crush(part: int, amount: float, push: Vector3) -> void:
	var worn: float = damage[part]
	var total: float = maxf(worn, amount) + REPEAT_HIT_SHARE * minf(worn, amount)

	total = _limited(part, minf(total, 1.0))
	if total > worn:
		_hurt(part, total - worn, push)


func _note_hit() -> void:
	if _clock - _last_hit_s > IMPACT_WINDOW_S:
		_impact_base = damage.duplicate()

	_last_hit_s = _clock


func _limited(part: int, wanted: float) -> float:
	return minf(wanted, _impact_base[part] + HIT_LIMITS[part])


func _hurt(part: int, amount: float, push: Vector3 = Vector3.ZERO) -> void:
	damage[part] = minf(damage[part] + amount, 1.0)

	if part == Part.STEERING_RACK and not is_zero_approx(push.x):
		var bent: float = signf(push.x) * minf(amount, 1.0) * CRUSH_OFFSET_RAD
		steer_offset_rad = clampf(steer_offset_rad + bent, -MAX_OFFSET_RAD, MAX_OFFSET_RAD)


func _belly_strikes(delta: float) -> void:
	var body: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(_vehicle.get_rid())
	if body == null:
		return

	var low_parts: Array[int] = [Part.OIL_PAN, Part.GEARBOX, Part.DRIVESHAFT]
	var fresh: Dictionary[int, float] = { }

	for i in range(body.get_contact_count()):
		var at: Vector3 = _vehicle.to_local(body.get_contact_local_position(i))

		for part in low_parts:
			var box: Box = _boxes[part]
			var off: Vector3 = (at - box.center).abs()

			if (
				at.y < box.center.y - box.half.y + STRIKE_HEIGHT_M
				and off.x < box.half.x + STRIKE_MARGIN_M and off.z < box.half.z + STRIKE_MARGIN_M
			):
				var hit_ns: float = body.get_contact_impulse(i).length()
				fresh[part] = fresh.get(part, 0.0) + hit_ns / _vehicle.mechanical_toughness

	for part in low_parts:
		var level: float = _strike_ns.get(part, 0.0) * exp(-delta / STRIKE_WINDOW_S)
		level += fresh.get(part, 0.0)
		_strike_ns[part] = level

		var counted: float = _counted_ns.get(part, 0.0)
		if level > counted:
			var over: float = level - maxf(counted, STRIKE_YIELD_NS)
			if over > 0.0:
				_note_hit()

				var total: float = _limited(part, damage[part] + over / STRIKE_BREAK_NS)
				_hurt(part, maxf(total - damage[part], 0.0))

			_counted_ns[part] = level
		elif level < STRIKE_YIELD_NS * 0.5:
			_counted_ns[part] = 0.0


func _step_cooling(delta: float) -> void:
	var engine: VehicleEngine = _vehicle.engine_node

	var heat_kw: float = 0.0
	if not seized:
		var power_kw: float = maxf(engine.output_torque_nm * engine.current_rpm / 9549.0, 0.0)
		heat_kw = IDLE_HEAT_KW + HEAT_PER_KW * power_kw

	var flow: float = _vehicle.aero.airspeed_mps
	if coolant_c > FAN_ON_C:
		flow = maxf(flow, FAN_MPS)

	var open: float = clampf(inverse_lerp(STAT_SHUT_C, STAT_OPEN_C, coolant_c), STAT_BYPASS, 1.0)
	var filled: float = clampf(inverse_lerp(COOLANT_DRY_AT, COOLANT_FULL_AT, coolant), 0.0, 1.0)
	var core: float = 1.0 - CRUSHED_CORE_LOSS * damage[Part.RADIATOR]

	var radiator_kw_k: float = RADIATOR_STILL_KW_K + RADIATOR_FLOW_KW_K * pow(
		flow / RADIATOR_FLOW_MPS,
		RADIATOR_FLOW_POWER,
	)

	var block_kw_k: float = BLOCK_KW_K + BLOCK_FLOW_KW_K * flow / RADIATOR_FLOW_MPS
	var shed_kw_k: float = block_kw_k + radiator_kw_k * open * filled * core

	var ambient_c: float = Atmosphere.config.air_temperature_c
	var capacity_kj_k: float = METAL_KJ_K + COOLANT_KJ_K * coolant

	coolant_c += (heat_kw - shed_kw_k * (coolant_c - ambient_c)) / capacity_kj_k * delta
	coolant_c = clampf(coolant_c, ambient_c, MAX_COOLANT_C)

	var leak: float = damage[Part.RADIATOR] * damage[Part.RADIATOR] * COOLANT_LEAK_PER_S
	var hole: float = 1.0 - COOLANT_DRAINS * damage[Part.RADIATOR]
	coolant = maxf(coolant - leak * delta, minf(coolant, hole))

	var boiled: float = maxf(coolant_c - BOIL_C, 0.0) * BOIL_PER_C_S
	coolant = maxf(coolant - boiled * delta, 0.0)

	if coolant_c > HEAD_DAMAGE_C:
		_hurt(Part.ENGINE, (coolant_c - HEAD_DAMAGE_C) * HEAD_DAMAGE_PER_C_S * delta)


func _step_oil(delta: float) -> void:
	var accel: Vector3 = _vehicle.global_basis.orthonormalized().inverse() * (
		(_vehicle.linear_velocity - _last_velocity) / delta
	)

	_last_velocity = _vehicle.linear_velocity

	var g: float = Vector2(accel.x, accel.z).length() / 9.81
	_sloshing_g = lerpf(_sloshing_g, g, 1.0 - exp(-delta / OIL_SLOSH_S))

	var pan: float = damage[Part.OIL_PAN]
	var drip: float = pan * pan * OIL_LEAK_PER_S + pan * OIL_SEEP_PER_S
	oil = maxf(oil - drip * delta, minf(oil, 1.0 - OIL_DRAINS * pan))

	var surge: float = clampf(_sloshing_g - OIL_SURGE_FROM_G, 0.0, 1.0) * OIL_SURGE_PER_G
	var at_pickup: float = oil - surge
	oil_pressure = clampf(inverse_lerp(OIL_DRY_AT, OIL_FULL_AT, at_pickup), 0.0, 1.0)

	if seized or oil_pressure >= 0.99:
		return

	var engine: VehicleEngine = _vehicle.engine_node
	var rev: float = engine.current_rpm / engine.config.rev_limiter_rpm

	var wear: float = (1.0 - oil_pressure) * (DRY_WEAR_PER_S + DRY_REV_WEAR_PER_S * rev * rev)
	_hurt(Part.ENGINE, wear * (0.4 + _vehicle.throttle_input) * delta)


func _step_engine(delta: float) -> void:
	var drive: Drivetrain = _vehicle.drivetrain_node

	if drive.is_clutch_engaged() and not seized:
		var forced_rpm: float = drive.calculate_target_engine_rpm(drive.get_input_speed_rad_s())
		var over: float = (
			forced_rpm - _vehicle.engine_node.config.rev_limiter_rpm - OVERREV_MARGIN_RPM
		)

		if over > 0.0:
			_hurt(Part.ENGINE, pow(over / 1000.0, 2.0) * OVERREV_PER_S * delta)

	seized = seized or damage[Part.ENGINE] >= 1.0

	_misfire_s -= delta
	if _misfire_s <= 0.0:
		_misfire_s = MISFIRE_S

		var chance: float = clampf(
			(MISFIRE_BELOW - engine_health()) * MISFIRE_PER_HEALTH,
			0.0,
			MISFIRE_MAX,
		)

		_misfire = MISFIRE_POWER if _random.randf() < chance else 1.0


func _step_brakes(delta: float) -> void:
	for wheel in _vehicle.wheels:
		if wheel.detached:
			brake_leak[circuit_of(wheel)] = 1.0

	for line in range(brake_fluid.size()):
		var loss: float = brake_leak[line] * (
			BRAKE_PUMP_PER_S * _vehicle.brake_input + BRAKE_DRIP_PER_S
		)

		brake_fluid[line] = maxf(brake_fluid[line] - loss * delta, 0.0)


func _step_reselect(delta: float) -> void:
	if _reselect_s <= 0.0:
		return

	_reselect_s -= delta
	if _reselect_s > 0.0:
		return

	var drive: Drivetrain = _vehicle.drivetrain_node
	var automatic: bool = drive.transmission_type == Drivetrain.TransmissionType.AUTOMATIC

	if automatic and drive.current_gear_index == 1:
		drive.current_gear_index = _reselect_gear


func _step_dampers() -> void:
	if _vehicle.wheel_damage == null:
		return

	for state in _vehicle.wheel_damage.states:
		var landed_mps: float = state.bottom_mps / _vehicle.mechanical_toughness
		var load_n: float = state.worst_n / _vehicle.mechanical_toughness

		var from_speed: float = (landed_mps - DAMPER_SAFE_MPS) * DAMPER_PER_MPS
		var from_load: float = (load_n - DAMPER_YIELD_N) / DAMPER_BREAK_N

		_damper[state.wheel] = 1.0 - clampf(maxf(from_speed, from_load), 0.0, DAMPER_MAX_LOSS)


func _step_aero() -> void:
	aero_drag = 1.0
	lift_front = 0.0
	lift_rear = 0.0

	if _vehicle.panel_damage == null:
		return

	for state in _vehicle.panel_damage.panels:
		var gone: bool = state.broken or _all_mounts_broken(state)
		if not gone and state.body == null:
			continue

		match state.def.panel_name:
			"Front Bumper":
				lift_front += 0.06 if gone else 0.03
				aero_drag *= 1.08 if gone else 1.03
			"Rear Bumper":
				aero_drag *= 1.04
			"Hood":
				lift_front += 0.04
				aero_drag *= 1.05
			"Boot":
				lift_rear += 0.12 if gone else 0.06
			_:
				if state.def.kind == CarPanel.Kind.GLASS:
					aero_drag *= 1.015


func _all_mounts_broken(state: PanelDamage.PanelState) -> bool:
	for mount in state.mounts:
		if not mount.broken:
			return false

	return not state.mounts.is_empty()


func _crush_depth_m(delta_v: float, width_m: float) -> float:
	var felt: float = delta_v - CarDeformer.FORGIVEN_DELTA_V_MPS
	if felt <= 0.0:
		return 0.0

	var approach: float = felt / (1.0 + CarDeformer.RESTITUTION)
	var energy: float = 0.5 * _vehicle.mass * approach * approach * (
		1.0 - CarDeformer.RESTITUTION * CarDeformer.RESTITUTION
	)

	var a: float = CarDeformer.CRUSH_A_N_PER_M
	var b: float = CarDeformer.CRUSH_B_N_PER_M2

	return maxf((sqrt(2.0 * b * energy / width_m) - a) / b, 0.0)


func _extent(half: Vector3, axis: Vector3) -> float:
	return half.dot(axis.abs())


func _gap(center: float, extent: float, low: float, high: float) -> float:
	return maxf(maxf(low - center - extent, center - extent - high), 0.0)


func _slowed_by() -> Vector3:
	return _history[_head] - _vehicle.linear_velocity
