class_name LostWheel
extends RigidBody3D

const MASS_KG: float = 18.0

const FRICTION: float = 0.9
const BOUNCE: float = 0.4
const FLAT_BOUNCE: float = 0.12

const LINEAR_DAMP: float = 0.05
const ANGULAR_DAMP: float = 0.35

const LIFETIME_S: float = 60.0

const OWN_LAYER: int = 1 << 20
const WORLD_LAYER: int = 1

const FREE_OF_CAR_S: float = 0.6

const SQUASH_EVERY_S: float = 0.03
const SQUASH_REACH_RAD: float = 0.8

var _car: RigidBody3D
var _config: SuspensionConfig

var _deflection: TireDeflection = TireDeflection.new()
var _materials: Array[ShaderMaterial] = []

var _age_s: float = 0.0
var _squash_s: float = 0.0


func setup(
	car: RigidBody3D,
	source: MeshInstance3D,
	config: SuspensionConfig,
	hub_words: Array[String],
	velocity: Vector3,
	spin: Vector3,
	air: float,
) -> void:
	_car = car
	_config = config

	mass = MASS_KG
	continuous_cd = true

	collision_layer = OWN_LAYER
	collision_mask = WORLD_LAYER

	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE

	linear_damp = LINEAR_DAMP
	angular_damp = ANGULAR_DAMP

	var rubber := PhysicsMaterial.new()
	rubber.friction = FRICTION
	rubber.bounce = lerpf(FLAT_BOUNCE, BOUNCE, clampf(air, 0.0, 1.0))
	physics_material_override = rubber

	var shape := CollisionShape3D.new()
	var tire := CylinderShape3D.new()
	tire.radius = config.wheel_radius
	tire.height = config.width_m()
	shape.shape = tire
	shape.basis = Basis(Vector3.BACK, PI * 0.5)
	add_child(shape)

	var view := source.duplicate() as MeshInstance3D
	view.transform = Transform3D.IDENTITY
	view.layers = 1

	for child in view.get_children():
		for word in hub_words:
			if String(child.name).contains(word):
				child.free()
				break

	add_child(view)

	if view.mesh != null:
		for surface in range(view.mesh.get_surface_count()):
			var material := view.get_surface_override_material(surface) as ShaderMaterial
			if material == null:
				continue

			var own := material.duplicate() as ShaderMaterial
			TireDeflection.setup_material(own, config)

			view.set_surface_override_material(surface, own)
			_materials.append(own)

	global_transform = Transform3D(source.global_basis.orthonormalized(), source.global_position)

	linear_velocity = velocity
	angular_velocity = spin

	add_collision_exception_with(car)


func _physics_process(delta: float) -> void:
	_age_s += delta

	if _age_s > LIFETIME_S:
		freeze = true
		set_physics_process(false)

		return

	if _age_s >= FREE_OF_CAR_S and collision_layer == OWN_LAYER:
		remove_collision_exception_with(_car)
		collision_layer = OWN_LAYER | WORLD_LAYER

	if sleeping or _materials.is_empty():
		return

	_squash_s += delta
	if _squash_s < SQUASH_EVERY_S:
		return

	var step: float = _squash_s
	_squash_s = 0.0

	var axle: Vector3 = global_basis.orthonormalized().x
	var up: Vector3 = Vector3.UP - axle * Vector3.UP.dot(axle)

	if up.length() < 0.05:
		return

	up = up.normalized()
	var frame := Basis(axle, up, axle.cross(up))

	_deflection.update(
		get_world_3d().direct_space_state,
		[get_rid(), _car.get_rid()],
		WORLD_LAYER,
		global_position,
		frame,
		_config,
		step,
	)

	for material in _materials:
		_deflection.apply_to(material, frame, _config, 0.0, 0.0, SQUASH_REACH_RAD)
