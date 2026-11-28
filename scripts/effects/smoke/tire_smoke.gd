class_name TireSmoke
extends MultiMeshInstance3D

const SHADER: Shader = preload("res://shaders/effects/smoke/tire_smoke.gdshader")

const MAX_PUFFS: int = 400
const NOISE_SIZE: int = 256

const MIN_RATE: float = 0.03

const TRAIL_PUFFS_PER_S: float = 16.0
const TRAIL_SPACING_M: float = 0.7
const MAX_TRAIL_PUFFS_PER_S: float = 34.0

const BOIL_PUFFS_PER_S: float = 18.0
const FULL_BOIL_SLIP_MPS: float = 8.0

const WIND_SHARE: float = 0.5
const CARRY_SHARE: float = 0.2
const THROW_SHARE: float = 0.22

const MAX_THROW_MPS: float = 4.0
const SPREAD_MPS: float = 0.45
const SIDE_SPREAD_MPS: float = 0.7

const WAKE_SIZE_M_PER_MPS: float = 0.006
const MAX_WAKE_MPS: float = 30.0

const REACH_M: float = 20.0
const BOUNDS_INTERVAL_S: float = 0.25

const WARM_UP_S: float = 0.5
const EVERYWHERE: AABB = AABB(Vector3.ONE * -10000.0, Vector3.ONE * 20000.0)


class Contact extends RefCounted:
	var wheel: Wheel
	var rate: float = 0.0

	var forward: Vector3 = Vector3.FORWARD
	var outboard: Vector3 = Vector3.RIGHT

	var moving: Vector3 = Vector3.ZERO
	var wind: Vector3 = Vector3.ZERO

	var slip_mps: float = 0.0


static var _noise: ImageTexture
static var _puff_mesh: ArrayMesh

var sources: Array[TireSmokeSource] = []

var obstacles: TireSmokeObstacles
var flow: TireSmokeFlow = TireSmokeFlow.new(MAX_PUFFS)

var _vehicle: Vehicle
var _sun: DirectionalLight3D
var _material: ShaderMaterial = ShaderMaterial.new()

var _contact: Contact = Contact.new()

var _owed_trail: PackedFloat32Array = PackedFloat32Array()
var _owed_boil: PackedFloat32Array = PackedFloat32Array()

var _born_at: PackedVector3Array = PackedVector3Array()
var _dies_s: PackedFloat32Array = PackedFloat32Array()

var _next: int = 0

var _clock_s: float = 0.0
var _empty_s: float = WARM_UP_S
var _since_bounds_s: float = 0.0

var _bounds: AABB = AABB()


func _init(vehicle: Vehicle) -> void:
	_vehicle = vehicle

	name = "TireSmoke"
	top_level = true
	custom_aabb = EVERYWHERE
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for i in range(vehicle.wheels.size()):
		sources.append(TireSmokeSource.new())

	obstacles = TireSmokeObstacles.new(vehicle)

	_owed_trail.resize(vehicle.wheels.size())
	_owed_boil.resize(vehicle.wheels.size())

	_born_at.resize(MAX_PUFFS)
	_dies_s.resize(MAX_PUFFS)


func _ready() -> void:
	global_transform = Transform3D.IDENTITY

	var puffs := MultiMesh.new()
	puffs.transform_format = MultiMesh.TRANSFORM_3D
	puffs.use_custom_data = true
	puffs.use_colors = true
	puffs.mesh = _shared_mesh()
	puffs.instance_count = MAX_PUFFS

	var nothing := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
	for i in range(MAX_PUFFS):
		puffs.set_instance_transform(i, nothing)
		puffs.set_instance_color(i, Color(0.0, 0.0, 0.0, 1.0))

	multimesh = puffs

	if _noise == null:
		_noise = _make_noise()

	_material.shader = SHADER
	_material.render_priority = 1
	_material.set_shader_parameter("noise_tex", _noise)

	material_override = _material

	var suns: Array[Node] = get_tree().root.find_children("*", "DirectionalLight3D", true, false)
	if not suns.is_empty():
		_sun = suns[0]


func _process(_delta: float) -> void:
	if not visible:
		return

	var ahead_s: float = (
		Engine.get_physics_interpolation_fraction() / float(Engine.physics_ticks_per_second)
	)

	_material.set_shader_parameter("smoke_time", _clock_s + ahead_s)
	obstacles.send(_material)

	if is_instance_valid(_sun):
		_material.set_shader_parameter("sun_direction", _sun.global_basis.z.normalized())


func step(delta: float) -> void:
	_clock_s += delta

	for i in range(sources.size()):
		var wheel: Wheel = _vehicle.wheels[i]
		var source: TireSmokeSource = sources[i]

		source.step(wheel, delta)

		if source.rate < MIN_RATE or not wheel.is_grounded or wheel.detached:
			_owed_trail[i] = 0.0
			_owed_boil[i] = 0.0
			continue

		_read_contact(wheel, source.rate)
		_emit(i, delta)

	_since_bounds_s += delta
	if _since_bounds_s >= BOUNDS_INTERVAL_S:
		_since_bounds_s = 0.0
		_shrink_bounds()

	visible = _clock_s < _empty_s
	if visible:
		obstacles.update(delta, _bounds)
		flow.step(_clock_s, obstacles, multimesh)


func _read_contact(wheel: Wheel, rate: float) -> void:
	_contact.wheel = wheel
	_contact.rate = rate

	var axle: Vector3 = wheel.spin_axis(_vehicle).normalized()
	_contact.forward = axle.cross(wheel.contact_normal).normalized()

	var local_x: float = _vehicle.to_local(wheel.global_position).x
	_contact.outboard = _vehicle.global_basis.x.normalized() * signf(local_x)

	var com: Vector3 = _vehicle.to_global(_vehicle.center_of_mass)
	_contact.moving = (_vehicle.linear_velocity + _vehicle.angular_velocity.cross(
			wheel.contact_point - com
		))

	var surface_mps: float = wheel.angular_velocity_rad_s * wheel.suspension_config.wheel_radius
	_contact.slip_mps = surface_mps - _contact.moving.dot(_contact.forward)

	_contact.wind = Atmosphere.wind_at(wheel.contact_point) * WIND_SHARE


func _emit(index: int, delta: float) -> void:
	var rate: float = _contact.rate

	var trail_per_s: float = minf(
		TRAIL_PUFFS_PER_S + _contact.wheel.ground_speed_mps / TRAIL_SPACING_M,
		MAX_TRAIL_PUFFS_PER_S,
	)

	_owed_trail[index] += trail_per_s * lerpf(0.5, 1.0, rate) * delta

	while _owed_trail[index] >= 1.0:
		_owed_trail[index] -= 1.0
		_spawn_trail(randf() * delta)

	var spinning: float = minf(absf(_contact.slip_mps) / FULL_BOIL_SLIP_MPS, 1.0)
	_owed_boil[index] += BOIL_PUFFS_PER_S * rate * spinning * delta

	while _owed_boil[index] >= 1.0:
		_owed_boil[index] -= 1.0
		_spawn_boil(randf() * delta)


func _spawn_trail(back_s: float) -> void:
	var wheel: Wheel = _contact.wheel
	var rate: float = _contact.rate
	var outboard: Vector3 = _contact.outboard

	var width: float = wheel.suspension_config.width_m()
	var up: Vector3 = wheel.contact_normal

	var side: float = randf_range(-0.5, 1.0)
	var wake_m: float = minf(wheel.ground_speed_mps, MAX_WAKE_MPS) * WAKE_SIZE_M_PER_MPS
	var size_m: float = width * lerpf(0.55, 0.8, rate) + wake_m

	var at: Vector3 = wheel.contact_point + outboard * (side * width * 0.6) + up * (size_m * 0.5)
	var throw_mps: float = clampf(_contact.slip_mps * THROW_SHARE, -MAX_THROW_MPS, MAX_THROW_MPS)

	var velocity: Vector3 = _contact.moving * CARRY_SHARE - _contact.forward * throw_mps
	velocity += up * randf_range(0.1, 0.9) + outboard * (side * SIDE_SPREAD_MPS)
	velocity += Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * SPREAD_MPS

	_add_puff(
		at,
		velocity,
		size_m,
		lerpf(0.35, 0.95, rate) * randf_range(0.7, 1.3),
		lerpf(1.2, 4.4, rate) * randf_range(0.75, 1.25),
		lerpf(0.2, 1.0, rate) * randf_range(0.8, 1.0),
		back_s,
	)


func _spawn_boil(back_s: float) -> void:
	var wheel: Wheel = _contact.wheel
	var outboard: Vector3 = _contact.outboard

	var width: float = wheel.suspension_config.width_m()
	var radius: float = wheel.suspension_config.wheel_radius
	var up: Vector3 = wheel.contact_normal

	var angle: float = randf_range(-1.3, 2.1)
	var behind: Vector3 = -_contact.forward * signf(_contact.slip_mps)
	var from_hub: Vector3 = behind * sin(angle) - up * cos(angle)
	var along: Vector3 = behind * cos(angle) + up * sin(angle)

	var side: float = randf_range(0.55, 1.2) * (1.0 if randf() < 0.75 else -1.0)
	var throw_mps: float = minf(absf(_contact.slip_mps) * THROW_SHARE, MAX_THROW_MPS)
	var ahead: float = maxf(-sin(angle), 0.0)

	var at: Vector3 = wheel.hub_world_position() + from_hub * (radius * randf_range(0.65, 1.05))
	at += outboard * (side * width * 0.75)

	var velocity: Vector3 = _contact.moving * CARRY_SHARE + along * (throw_mps * 0.3)
	velocity += outboard * (side * SIDE_SPREAD_MPS * 0.5) - behind * (ahead * throw_mps * 0.35)

	_add_puff(
		at,
		velocity,
		width * randf_range(0.65, 0.95),
		randf_range(0.2, 0.45),
		randf_range(0.5, 1.1),
		lerpf(0.2, 0.65, _contact.rate),
		back_s,
	)


func _add_puff(
	at: Vector3,
	velocity: Vector3,
	size_m: float,
	growth_m: float,
	life_s: float,
	opacity: float,
	back_s: float,
) -> void:
	var born_s: float = _clock_s - back_s
	var start: Vector3 = at - _contact.moving * back_s

	var data := Basis(
		velocity,
		Vector3(born_s, _contact.wheel.contact_point.y, life_s),
		Vector3(_contact.wind.x, _contact.wind.z, size_m),
	)

	var custom := Color(opacity, growth_m, randf(), 0.0)

	multimesh.set_instance_transform(_next, Transform3D(data, start))
	multimesh.set_instance_custom_data(_next, custom)
	multimesh.set_instance_color(_next, Color(0.0, 0.0, 0.0, 1.0))

	flow.add(
		_next,
		start,
		velocity,
		_contact.wind,
		born_s,
		life_s,
		_contact.wheel.contact_point.y,
		size_m,
		custom,
	)

	_born_at[_next] = start
	_dies_s[_next] = born_s + life_s
	_next = (_next + 1) % MAX_PUFFS

	if _clock_s >= _empty_s:
		_bounds = AABB(start, Vector3.ZERO)
	else:
		_bounds = _bounds.expand(start)

	_empty_s = maxf(_empty_s, born_s + life_s)
	custom_aabb = _bounds.grow(REACH_M)


func _shrink_bounds() -> void:
	var found: bool = false

	for i in range(MAX_PUFFS):
		if _dies_s[i] <= _clock_s:
			continue

		if found:
			_bounds = _bounds.expand(_born_at[i])
		else:
			_bounds = AABB(_born_at[i], Vector3.ZERO)
			found = true

	if found:
		custom_aabb = _bounds.grow(REACH_M)


static func _shared_mesh() -> ArrayMesh:
	if _puff_mesh != null:
		return _puff_mesh

	var points := PackedVector3Array()
	var corners: int = 8
	var reach: float = 1.0 / cos(PI / corners)

	for i in range(1, corners - 1):
		for k in [0, i, i + 1]:
			var angle: float = TAU * (float(k) + 0.5) / corners
			points.append(Vector3(cos(angle), sin(angle), 0.0) * reach)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points

	_puff_mesh = ArrayMesh.new()
	_puff_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return _puff_mesh


static func _make_noise() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.45
	noise.frequency = 0.018

	noise.seed = 7
	var lumps: PackedByteArray = noise \
			.get_seamless_image(NOISE_SIZE, NOISE_SIZE, 0, true) \
			.get_data()

	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.025

	noise.seed = 11
	var swirl_x: PackedByteArray = noise.get_seamless_image(NOISE_SIZE, NOISE_SIZE).get_data()

	noise.seed = 23
	var swirl_y: PackedByteArray = noise.get_seamless_image(NOISE_SIZE, NOISE_SIZE).get_data()

	var data := PackedByteArray()
	data.resize(NOISE_SIZE * NOISE_SIZE * 3)

	for i in range(NOISE_SIZE * NOISE_SIZE):
		data[i * 3] = lumps[i]
		data[i * 3 + 1] = swirl_x[i]
		data[i * 3 + 2] = swirl_y[i]

	var image: Image = Image.create_from_data(
		NOISE_SIZE,
		NOISE_SIZE,
		false,
		Image.FORMAT_RGB8,
		data,
	)

	image.generate_mipmaps()

	return ImageTexture.create_from_image(image)
