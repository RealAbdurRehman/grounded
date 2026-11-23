@tool
extends EditorScript

const COLLISION_PREFIX: String = "Collision"
const OLD_BOX: String = "Collider"

var _vehicle: Node3D
var _definition: CarDefinition

var _folder: String
var _to_save: Array[Resource] = []

var _ground: float = 0.0
var _collision: CarCollision


func _run() -> void:
	_vehicle = EditorInterface.get_edited_scene_root() as Node3D
	if _vehicle == null:
		return

	var body: Node = _vehicle.get_node_or_null("Body")
	if body == null or body.get_script() == null or not body.has_method("rebuild"):
		return

	_definition = body.get("definition")
	if _definition == null:
		return

	if _definition.model == null:
		return

	_folder = "res://resources/cars/%s/" % _car_id()

	_set_chassis()
	_set_aero()

	_set_engine()
	_set_drivetrain()

	_set_wheels()
	_set_center_of_mass()

	body.call("rebuild")
	_make_collision()

	_save_resources()
	body.call("rebuild")


func _car_id() -> String:
	var id: String = _definition.resource_path.get_file().get_basename()

	if id == "":
		id = _definition.car_name.to_snake_case()

	return id


func _gravity() -> float:
	var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	return gravity * float(_vehicle.get("gravity_scale"))


func _have(field: String, fallback: Resource, file_name: String) -> Resource:
	var resource: Resource = _definition.get(field)

	if resource == null:
		DirAccess.make_dir_recursive_absolute(_folder)

		resource = fallback
		resource.resource_path = _folder + file_name + ".tres"
		_definition.set(field, resource)

	_to_save.append(resource)

	return resource


func _save_resources() -> void:
	for resource in _to_save:
		ResourceSaver.save(resource, resource.resource_path)

	if _definition.resource_path != "":
		ResourceSaver.save(_definition, _definition.resource_path)


func _set_chassis() -> void:
	var chassis: Resource = _have("chassis", ChassisConfig.new(), "chassis")
	chassis.set("vehicle_mass", _definition.mass_kg)

	_vehicle.set("config", chassis)


func _set_aero() -> void:
	var aero: Resource = _have("aero", AeroConfig.new(), "aero")
	aero.set("frontal_area", _definition.frontal_area_m2)
	aero.set("drag_coefficient", _definition.drag_coefficient)

	_vehicle.set("aero_config", aero)


func _set_engine() -> void:
	var engine: Resource = _have("engine", EngineConfig.new(), "engine")

	engine.set("displacement", _definition.torque_floor_nm)
	engine.set("boost", _definition.torque_peak_nm)
	engine.set("falloff", 1.0)
	engine.set("cam_peak_rpm", _definition.torque_peak_rpm)
	engine.set("bandwidth", _definition.torque_bandwidth_rpm)

	engine.set("idle_rpm", _definition.idle_rpm)
	engine.set("rev_limiter_rpm", _definition.rev_limiter_rpm)
	engine.set("max_rpm", _definition.max_rpm)

	_vehicle.get_node("Engine").set("config", engine)


func _set_drivetrain() -> void:
	var drivetrain: Resource = _have("drivetrain", DrivetrainConfig.new(), "drivetrain")

	drivetrain.set("gear_ratios", _definition.gear_ratios.duplicate())
	drivetrain.set("final_drive_ratio", _definition.final_drive)
	drivetrain.set("drivetrain_efficiency", _definition.efficiency)
	drivetrain.set("auto_upshift_rpm", _definition.automatic_upshift_rpm)
	drivetrain.set("center_front_torque_share", _definition.center_front_torque_share)

	drivetrain.set(
		"front_differential",
		_have("front_differential", DifferentialConfig.new(), "front_differential"),
	)
	drivetrain.set(
		"rear_differential",
		_have("rear_differential", DifferentialConfig.new(), "rear_differential"),
	)
	drivetrain.set(
		"center_differential",
		_have("center_differential", DifferentialConfig.new(), "center_differential"),
	)

	_vehicle.get_node("Drivetrain").set("config", drivetrain)


func _set_wheels() -> void:
	var front: Resource = _suspension(
		"front_suspension",
		_definition.front_weight_share,
		_definition.front_ride_hz,
	)

	var rear: Resource = _suspension(
		"rear_suspension",
		1.0 - _definition.front_weight_share,
		_definition.rear_ride_hz,
	)

	for node in _vehicle.find_children("*", "Wheel", true, false):
		var wheel := node as Node3D

		var is_front: bool = wheel.position.z < 0.0
		var side: float = -1.0 if wheel.position.x < 0.0 else 1.0

		var half_track: float = (
			_definition.front_track_m if is_front else _definition.rear_track_m
		) * 0.5
		var half_base: float = _definition.wheelbase_m * 0.5

		wheel.position = Vector3(
			side * half_track,
			wheel.position.y,
			-half_base if is_front else half_base,
		)

		wheel.set("suspension_config", front if is_front else rear)
		wheel.set("is_driven", _definition.front_driven if is_front else _definition.rear_driven)

		var tire: Tire = _definition.front_tire if is_front else _definition.rear_tire
		if tire != null:
			wheel.set("tire_model", tire)


func _suspension(field: String, weight_share: float, ride_hz: float) -> Resource:
	var suspension: Resource = _have(field, SuspensionConfig.new(), field)

	suspension.set("wheel_radius", _definition.tire_radius_m)
	suspension.set("wheel_width", _definition.tire_width_m)
	suspension.set("rim_radius", _definition.rim_radius_m)

	var corner_kg: float = _definition.mass_kg * weight_share * 0.5
	var sprung_kg: float = corner_kg - float(suspension.get("unsprung_mass"))

	var omega: float = TAU * ride_hz
	var spring: float = sprung_kg * omega * omega

	suspension.set("spring_stiffness", snappedf(spring, 100.0))

	suspension.set("alignment_compression", snappedf(corner_kg * _gravity() / spring, 0.001))

	var critical: float = 2.0 * sqrt(spring * sprung_kg)
	suspension.set("damper_bump", snappedf(critical * _definition.bump_damping_ratio, 10.0))
	suspension.set("damper_rebound", snappedf(critical * _definition.rebound_damping_ratio, 10.0))

	return suspension


func _set_center_of_mass() -> void:
	var marker: Node3D = _vehicle.get_node("Markers/CenterOfMass")

	var wheel: Node = _vehicle.find_children("*", "Wheel", true, false)[0]
	var config: Resource = wheel.get("suspension_config")

	var hub: float = (wheel as Node3D).position.y - float(config.get("suspension_rest_length")) + float(
		config.get("alignment_compression")
	)

	var load_n: float = _definition.mass_kg * _definition.front_weight_share * 0.5 * _gravity()
	var squash: float = load_n / float(config.get("tire_stiffness"))

	var ground: float = hub - (_definition.tire_radius_m - squash)
	_ground = ground

	var z: float = -_definition.wheelbase_m * 0.5 + (1.0 - _definition.front_weight_share) * _definition.wheelbase_m

	marker.position = Vector3(0.0, ground + _definition.center_of_mass_height_m, z)


func _make_collision() -> void:
	for child in _vehicle.get_children():
		var old: bool = child.name == OLD_BOX or String(child.name).begins_with(COLLISION_PREFIX)

		if old and child.owner != null:
			_vehicle.remove_child(child)
			child.free()

	_collision = _have("collision", CarCollision.new(), "collision")
	_collision.piece_names.clear()
	_collision.shapes.clear()

	var model: Node = _vehicle.get_node_or_null("Body/Model")
	if model == null:
		return

	var meshes: Array[MeshInstance3D] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).is_visible_in_tree():
			meshes.append(node as MeshInstance3D)

	var used: Array[MeshInstance3D] = []

	for part in _definition.collision_parts:
		var found: Array[MeshInstance3D] = []

		for mesh in meshes:
			if not used.has(mesh) and _named(mesh, part.words):
				found.append(mesh)

		_add_pieces(part.part_name, found, part.pieces)
		used.append_array(found)

	var body: Array[MeshInstance3D] = []
	for mesh in meshes:
		if not used.has(mesh) and not _named(mesh, _definition.not_body_words):
			body.append(mesh)

	_add_pieces("Body", body, _definition.body_pieces)


func _named(mesh: Node, words: Array) -> bool:
	var node: Node = mesh

	while node != null and node != _vehicle:
		for word in words:
			if node.name.contains(String(word)):
				return true

		node = node.get_parent()

	return false


func _add_pieces(part_name: String, meshes: Array[MeshInstance3D], most: int) -> void:
	if meshes.is_empty():
		return

	var joined: ArrayMesh = _joined(meshes)

	var shapes: Array[Shape3D] = []
	if most <= 1:
		shapes.append(joined.create_convex_shape(true, true))
	else:
		shapes.append_array(_decomposed(joined, most))

	var number: int = 0
	for shape in shapes:
		if not _lift(shape):
			continue

		number += 1

		_collision.piece_names.append("%s%s%d" % [COLLISION_PREFIX, part_name, number])
		_collision.shapes.append(shape)


func _lift(shape: Shape3D) -> bool:
	var convex := shape as ConvexPolygonShape3D
	if convex == null:
		return true

	var points: PackedVector3Array = convex.points
	var room: float = 0.0

	for i in range(points.size()):
		var floor_y: float = _floor_at(points[i].z)

		room = maxf(room, points[i].y - floor_y)
		points[i].y = maxf(points[i].y, floor_y)

	convex.points = points

	return room > 0.02


func _floor_at(z: float) -> float:
	var half_base: float = _definition.wheelbase_m * 0.5
	var floor_y: float = _ground + _definition.collision_clearance_m

	if z < -half_base:
		floor_y += (-half_base - z) * tan(deg_to_rad(_definition.approach_angle_deg))
	elif z > half_base:
		floor_y += (z - half_base) * tan(deg_to_rad(_definition.departure_angle_deg))

	return floor_y


func _joined(meshes: Array[MeshInstance3D]) -> ArrayMesh:
	var tool := SurfaceTool.new()
	var to_car: Transform3D = _vehicle.global_transform.affine_inverse()

	for mesh in meshes:
		for surface in range(mesh.mesh.get_surface_count()):
			tool.append_from(mesh.mesh, surface, to_car * mesh.global_transform)

	return tool.commit()


func _decomposed(mesh: ArrayMesh, most: int) -> Array[Shape3D]:
	var temporary := MeshInstance3D.new()
	temporary.mesh = mesh

	_vehicle.add_child(temporary)

	var settings := MeshConvexDecompositionSettings.new()
	settings.max_convex_hulls = most
	settings.max_concavity = 0.02
	settings.max_num_vertices_per_convex_hull = 48
	settings.resolution = 100000

	temporary.create_multiple_convex_collisions(settings)

	var shapes: Array[Shape3D] = []

	for body in temporary.get_children():
		for piece in body.get_children():
			var shape := (piece as CollisionShape3D).shape
			if shape != null:
				shapes.append(shape)

	_vehicle.remove_child(temporary)
	temporary.free()

	return shapes
