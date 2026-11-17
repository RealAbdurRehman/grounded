extends Node

const MODE_COUNT: int = 8
const GUST_SLOTS: int = 4

const MIN_WAVELENGTH_M: float = 15.0
const MAX_WAVELENGTH_M: float = 180.0

const ACROSS_RATIO: float = 0.75

const GUST_SPEED_MPS: float = 15.0

const GUST_LEAD_S: float = 4.0

var config: AirConfig = preload("res://resources/air/default.tres")

var time_s: float = 0.0

var gusts: Array[Dictionary] = []

var gusts_started: int = 0

var _rng := RandomNumberGenerator.new()
var _built_seed: int = -1

var _wave: PackedVector2Array = PackedVector2Array()
var _weight: PackedFloat32Array = PackedFloat32Array()
var _phase: PackedFloat32Array = PackedFloat32Array()
var _drift: PackedFloat32Array = PackedFloat32Array()

var _next_gust_s: float = INF
var _scheduled_interval_s: float = 0.0

var _watched: Array[Node3D] = []


func _ready() -> void:
	_build_waves()
	_schedule_gust()


func _physics_process(delta: float) -> void:
	if config.random_seed != _built_seed:
		_build_waves()

	time_s += delta

	for i in range(gusts.size() - 1, -1, -1):
		if time_s - gusts[i].start_s > GUST_LEAD_S + 6.0 + gusts[i].length_m / GUST_SPEED_MPS:
			gusts.remove_at(i)

	if not is_equal_approx(config.gust_interval_s, _scheduled_interval_s):
		_schedule_gust()

	if time_s >= _next_gust_s:
		trigger_gust()
		_schedule_gust()


func watch(node: Node3D) -> void:
	for i in range(_watched.size() - 1, -1, -1):
		if not is_instance_valid(_watched[i]):
			_watched.remove_at(i)

	if not _watched.has(node):
		_watched.append(node)


func unwatch(node: Node3D) -> void:
	_watched.erase(node)


func wind_direction() -> Vector2:
	var heading: float = deg_to_rad(config.wind_heading_deg)
	return Vector2(-sin(heading), -cos(heading))


func mean_wind() -> Vector2:
	return wind_direction() * config.wind_speed_mps


func wind_at(position: Vector3) -> Vector3:
	var spot := Vector2(position.x, position.z)
	var wind: Vector2 = mean_wind() + turbulence_at(spot)

	for gust in gusts:
		wind += _gust_at(gust, spot)

	return Vector3(wind.x, 0.0, wind.y)


func turbulence_at(spot: Vector2) -> Vector2:
	if config.turbulence_mps <= 0.0 or _wave.size() == 0:
		return Vector2.ZERO

	var carried: Vector2 = mean_wind()
	var slowness: float = 1.0 / maxf(config.turbulence_time_s, 0.1)

	var along: float = 0.0
	var across: float = 0.0

	for i in range(MODE_COUNT):
		along += _mode(i, spot, carried, slowness)
		across += _mode(i + MODE_COUNT, spot, carried, slowness)

	var direction: Vector2 = wind_direction()
	var side := Vector2(-direction.y, direction.x)

	return (
		direction * (config.turbulence_mps * along)
		+ side * (config.turbulence_mps * ACROSS_RATIO * across)
	)


func trigger_gust(peak_mps: float = -1.0, heading_deg: float = NAN) -> void:
	var peak: float = peak_mps if peak_mps >= 0.0 else config.gust_peak_mps
	var random_gust: bool = is_nan(heading_deg)

	var heading: float = config.wind_heading_deg
	if random_gust:
		heading += _rng.randf_range(-config.gust_spread_deg, config.gust_spread_deg)
	else:
		heading = heading_deg

	var direction := Vector2(-sin(deg_to_rad(heading)), -cos(deg_to_rad(heading)))
	var side := Vector2(-direction.y, direction.x)

	var target: Vector2 = _target_position()
	var offset: float = 0.0

	if random_gust:
		offset = _rng.randf_range(-0.5, 0.5) * config.gust_width_m

	var length: float = GUST_SPEED_MPS * config.gust_duration_s

	var gust := {
		"start_s": time_s,
		"origin": target - direction * GUST_SPEED_MPS * GUST_LEAD_S + side * offset,
		"direction": direction,
		"peak_mps": peak,
		"length_m": length,
		"width_m": config.gust_width_m,
	}

	gusts.append(gust)
	gusts_started += 1
	while gusts.size() > GUST_SLOTS:
		gusts.pop_front()


func clear_gusts() -> void:
	gusts.clear()


func wave_data() -> Dictionary:
	var carried: Vector2 = mean_wind()
	var slowness: float = 1.0 / maxf(config.turbulence_time_s, 0.1)

	var waves := PackedVector4Array()
	var strengths := PackedFloat32Array()

	for i in range(MODE_COUNT * 2):
		var wave: Vector2 = _wave[i]
		var ratio: float = 1.0 if i < MODE_COUNT else ACROSS_RATIO

		waves.append(Vector4(wave.x, wave.y, wave.dot(carried) + _drift[i] * slowness, _phase[i]))
		strengths.append(config.turbulence_mps * ratio * _weight[i])

	return { "waves": waves, "strengths": strengths }


func gust_data() -> Dictionary:
	var starts := PackedVector4Array()
	var shapes := PackedVector4Array()
	var times := PackedVector4Array()

	for slot in range(GUST_SLOTS):
		if slot < gusts.size():
			var gust: Dictionary = gusts[slot]
			var origin: Vector2 = gust.origin
			var direction: Vector2 = gust.direction

			starts.append(Vector4(origin.x, origin.y, direction.x, direction.y))
			shapes.append(Vector4(gust.peak_mps, gust.length_m, gust.width_m, GUST_SPEED_MPS))
			times.append(Vector4(gust.start_s, 1.0, 0.0, 0.0))
		else:
			starts.append(Vector4.ZERO)
			shapes.append(Vector4.ZERO)
			times.append(Vector4.ZERO)

	return { "starts": starts, "shapes": shapes, "times": times }


func _mode(index: int, spot: Vector2, carried: Vector2, slowness: float) -> float:
	var wave: Vector2 = _wave[index]
	var speed: float = wave.dot(carried) + _drift[index] * slowness
	var angle: float = wave.dot(spot) - speed * time_s + _phase[index]

	return _weight[index] * cos(angle)


func _gust_at(gust: Dictionary, spot: Vector2) -> Vector2:
	var direction: Vector2 = gust.direction
	var length: float = gust.length_m
	var relative: Vector2 = spot - gust.origin

	var front: float = relative.dot(direction) - GUST_SPEED_MPS * (time_s - gust.start_s)
	if front > 0.0 or front < -length:
		return Vector2.ZERO

	var side: float = relative.dot(Vector2(-direction.y, direction.x))
	var across: float = side / gust.width_m
	var shape: float = 0.5 * (1.0 - cos(TAU * -front / length))

	return direction * (gust.peak_mps * shape * exp(-across * across))


func _target_position() -> Vector2:
	var seconds: float = GUST_LEAD_S + config.gust_duration_s * 0.5

	for node in _watched:
		if is_instance_valid(node):
			var spot := Vector2(node.global_position.x, node.global_position.z)
			if node is RigidBody3D:
				spot += Vector2(node.linear_velocity.x, node.linear_velocity.z) * seconds

			return spot

	return Vector2.ZERO


func _schedule_gust() -> void:
	_scheduled_interval_s = config.gust_interval_s

	if config.gust_interval_s <= 0.0:
		_next_gust_s = INF
		return

	_next_gust_s = time_s - config.gust_interval_s * log(maxf(_rng.randf(), 0.0001))


func _build_waves() -> void:
	_built_seed = config.random_seed

	if config.random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = config.random_seed

	_wave = PackedVector2Array()
	_weight = PackedFloat32Array()
	_phase = PackedFloat32Array()
	_drift = PackedFloat32Array()

	for group in range(2):
		var first: int = _weight.size()
		var energy: float = 0.0

		for i in range(MODE_COUNT):
			var blend: float = (float(i) + _rng.randf()) / float(MODE_COUNT)
			var wavelength: float = exp(lerpf(log(MIN_WAVELENGTH_M), log(MAX_WAVELENGTH_M), blend))

			var angle: float = _rng.randf() * TAU
			var strength: float = pow(wavelength, 1.0 / 3.0)

			_wave.append(Vector2(cos(angle), sin(angle)) * (TAU / wavelength))
			_weight.append(strength)

			_phase.append(_rng.randf() * TAU)
			_drift.append(_rng.randf_range(0.5, 1.5) * (1.0 if _rng.randf() < 0.5 else -1.0))

			energy += 0.5 * strength * strength

		for i in range(MODE_COUNT):
			_weight[first + i] /= sqrt(energy)
