class_name TireVisual
extends RefCounted

const SQUASH_SHADER: Shader = preload("res://shaders/tire/tire_squash.gdshader")

const SHEAR_SMOOTHING_S: float = 0.03

const SIZE_WARNING_M: float = 0.015

const CULL_MARGIN_M: float = 0.06

var rest_basis: Basis = Basis.IDENTITY

var _node: MeshInstance3D
var _config: SuspensionConfig
var _tire_model: Tire

var _is_generated: bool = false
var _size: Vector3 = Vector3.ZERO

var _deflection: TireDeflection = TireDeflection.new()
var _materials: Array[ShaderMaterial] = []

var _shear_m: float = 0.0
var _twist_rad: float = 0.0


func setup(node: MeshInstance3D, config: SuspensionConfig, tire_model: Tire) -> void:
	_node = node
	_config = config
	_tire_model = tire_model

	_is_generated = node.mesh == null

	if _is_generated:
		rest_basis = Basis.IDENTITY
	else:
		rest_basis = node.basis
		node.extra_cull_margin = maxf(node.extra_cull_margin, CULL_MARGIN_M)

	_build()


func update(wheel: Wheel, chassis: RigidBody3D, delta: float) -> void:
	if _materials.is_empty():
		return

	var hub: Vector3 = wheel.hub_world_position()
	if not hub.is_finite():
		return

	if _config.tire_size() != _size:
		_build()

	var hub_basis: Basis = wheel.hub_basis()

	_deflection.update(
		wheel.get_world_3d().direct_space_state,
		[chassis.get_rid()],
		wheel.collision_mask,
		hub,
		hub_basis,
		_config,
		delta,
	)

	_update_shear(wheel, delta)

	var reach_rad: float = clampf(
		_tire_model.relaxation_length_m() / maxf(_config.wheel_radius, 0.01),
		0.3,
		2.0,
	)

	for material in _materials:
		_deflection.apply_to(material, hub_basis, _config, _shear_m, _twist_rad, reach_rad)


func _build() -> void:
	_size = _config.tire_size()

	if _is_generated:
		var tire: ArrayMesh = TireMesh.build(_config)

		var material := ShaderMaterial.new()
		material.shader = SQUASH_SHADER

		tire.surface_set_material(0, material)

		_node.mesh = tire

	_materials.clear()

	for surface in range(_node.mesh.get_surface_count()):
		var material := _node.mesh.surface_get_material(surface) as ShaderMaterial
		if not material or not _squashes(material):
			continue

		var own: ShaderMaterial = material
		if not _is_generated:
			own = material.duplicate() as ShaderMaterial
			_node.set_surface_override_material(surface, own)

		TireDeflection.setup_material(own, _config)
		_materials.append(own)


func _squashes(material: ShaderMaterial) -> bool:
	if not material.shader:
		return false

	for uniform in material.shader.get_shader_uniform_list():
		if uniform["name"] == "squash_depth":
			return true

	return false


func _update_shear(wheel: Wheel, delta: float) -> void:
	var give_m: float = _tire_model.stick_deflection_m

	var peak_lateral: float = _tire_model.peak_lateral_force_n(
		wheel.normal_load_n,
		wheel.friction_coef,
		wheel.camber_rad,
	)

	var peak_longitudinal: float = _tire_model.peak_longitudinal_force_n(
		wheel.normal_load_n,
		wheel.friction_coef,
	)

	var shear_target: float = 0.0
	if peak_lateral > 1.0:
		shear_target = clampf(wheel.lateral_force_n / peak_lateral, -1.0, 1.0) * give_m

	var twist_target: float = 0.0
	if peak_longitudinal > 1.0:
		var ratio: float = clampf(wheel.longitudinal_force_n / peak_longitudinal, -1.0, 1.0)
		twist_target = ratio * give_m / maxf(_config.wheel_radius, 0.01)

	var blend: float = 1.0 - exp(-delta / SHEAR_SMOOTHING_S)
	_shear_m = lerpf(_shear_m, shear_target, blend)
	_twist_rad = lerpf(_twist_rad, twist_target, blend)
