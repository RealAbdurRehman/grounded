@tool
class_name CarBody
extends Node3D

@export var definition: CarDefinition:
	set(value):
		if definition != null and definition.changed.is_connected(_on_definition_changed):
			definition.changed.disconnect(_on_definition_changed)

		definition = value
		if definition != null:
			definition.changed.connect(_on_definition_changed)

		_on_definition_changed()

const SQUASH_SHADER: Shader = preload("res://shaders/tire/tire_squash.gdshader")

var _made: Array[Node] = []
var _holders: Array[Dictionary] = []

var _tires: Array[Dictionary] = []

var _generation: int = 0
var _rebuild_queued: bool = false


func _ready() -> void:
	_build()


func rebuild() -> void:
	_rebuild_queued = false

	_clear()
	_build()


func _on_definition_changed() -> void:
	if Engine.is_editor_hint() and is_node_ready() and not _rebuild_queued:
		_rebuild_queued = true
		rebuild.call_deferred()


func _clear() -> void:
	_generation += 1

	for node in _made:
		if is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)

			node.free()

	_made.clear()
	_holders.clear()
	_tires.clear()


func _build() -> void:
	if definition == null or definition.model == null:
		return

	var model := definition.model.instantiate() as Node3D
	model.name = "Model"
	add_child(model)

	_made.append(model)

	_hide_parts(model)

	var vehicle := get_parent() as Node3D
	if vehicle == null:
		return

	var wheels: Array[Node3D] = []
	for node in vehicle.find_children("*", "Wheel", true, false):
		wheels.append(node as Node3D)

	_fit(model, vehicle, wheels)

	var carriers: Dictionary = _mount_tires(model, wheels)

	for word in definition.spinning_words:
		_mount_on_tires(model, wheels, carriers, word, false)

	for word in definition.fixed_words:
		_mount_on_tires(model, wheels, carriers, word, true)

	_add_collision.call_deferred(_generation)
	_set_body_material(vehicle)


func _add_collision(generation: int) -> void:
	var vehicle := get_parent() as Node3D

	if (
		generation != _generation or vehicle == null
		or definition == null or definition.collision == null
	):
		return

	for i in range(definition.collision.shapes.size()):
		var piece := CollisionShape3D.new()
		piece.name = definition.collision.piece_names[i]
		piece.shape = definition.collision.shapes[i]

		_made.append(piece)
		vehicle.add_child(piece)


func _set_body_material(vehicle: Node3D) -> void:
	var body := vehicle as RigidBody3D
	if body == null or Engine.is_editor_hint():
		return

	var material := PhysicsMaterial.new()
	material.friction = definition.body_friction
	material.bounce = definition.body_bounce

	body.physics_material_override = material


func _process(_delta: float) -> void:
	for entry in _tires:
		if (
			is_instance_valid(entry["wheel"]) and not entry["wheel"].get("detached")
			and _sizes(entry["wheel"]) != entry["sizes"]
		):
			_refit(entry)

	if Engine.is_editor_hint():
		return

	for entry in _holders:
		var wheel: Node3D = entry["wheel"]
		var carrier: Node3D = entry["carrier"]
		var holder: Node3D = entry["holder"]

		if is_instance_valid(wheel) and is_instance_valid(carrier):
			holder.position = carrier.position
			holder.basis = wheel.call("_alignment_basis")


func _fit(model: Node3D, vehicle: Node3D, wheels: Array[Node3D]) -> void:
	basis = Basis.IDENTITY
	position = Vector3.ZERO

	var tires: Array[Node3D] = _top_parts(model, definition.tire_word)
	var to_model: Transform3D = model.global_transform.affine_inverse()

	var front: float = -INF
	var rear: float = INF
	var height: float = 0.0

	for tire in tires:
		var middle: Vector3 = to_model * _center_of(tire)
		front = maxf(front, middle.z)
		rear = minf(rear, middle.z)
		height += middle.y

	if tires.size() >= 2 and front - rear > 0.1:
		height /= float(tires.size())
	else:
		front = 0.0
		rear = 0.0

	var spot := Vector3.ZERO
	var hub_y: float = 0.0
	var counted: int = 0

	for wheel in wheels:
		spot += vehicle.to_local(wheel.global_position)
		hub_y += _hub_height(wheel)
		counted += 1

	if counted > 0:
		spot /= float(counted)
		hub_y /= float(counted)

	var axle_middle := Vector3(0.0, height, (front + rear) * 0.5)
	position = Vector3(0.0, hub_y - axle_middle.y, spot.z - axle_middle.z)


func _hub_height(wheel: Node3D) -> float:
	var config: Resource = wheel.get("suspension_config")
	var vehicle := get_parent() as Node3D
	var top: float = vehicle.to_local(wheel.global_position).y

	if config == null:
		return top - 0.35 + 0.15

	return top - float(config.get("suspension_rest_length")) + float(
		config.get("alignment_compression")
	)


func _hide_parts(model: Node3D) -> void:
	if definition.show_interior:
		return

	for node in model.find_children("*", "Node3D", true, false):
		var part := node as Node3D

		for word in definition.interior_words:
			if part.name.contains(word):
				part.visible = false


func _mount_tires(model: Node3D, wheels: Array[Node3D]) -> Dictionary:
	var carriers: Dictionary = { }
	var parts: Array[Node3D] = _top_parts(model, definition.tire_word)

	for wheel in wheels:
		var part: Node3D = _nearest(parts, wheel)
		if part == null:
			continue

		parts.erase(part)

		var sources: Array[Node] = part.find_children("*", "MeshInstance3D", true, false)
		if sources.is_empty():
			continue

		var source := sources[0] as MeshInstance3D

		var carrier := MeshInstance3D.new()
		carrier.name = "Mesh"

		var entry: Dictionary = {
			"wheel": wheel,
			"node": carrier,
			"source": source,
			"center": _center_of(part),
			"spinning": [],
			"sizes": _sizes(wheel),
			"inner": 0.0,
		}

		carrier.mesh = _tire_mesh(entry)

		var top: float = (get_parent() as Node3D).to_local(wheel.global_position).y
		carrier.position = Vector3(0.0, _hub_height(wheel) - top, 0.0)

		wheel.add_child(carrier)
		_made.append(carrier)

		part.visible = false

		carriers[wheel] = entry
		_tires.append(entry)

	return carriers


func _sizes(wheel: Node3D) -> Vector3:
	var config: Resource = wheel.get("suspension_config")

	if config == null:
		return Vector3(0.31, 0.25, 0.19)

	return Vector3(
		float(config.get("wheel_radius")),
		float(config.get("wheel_width")),
		float(config.get("rim_radius")),
	)


func _refit(entry: Dictionary) -> void:
	entry["sizes"] = _sizes(entry["wheel"])
	entry["node"].mesh = _tire_mesh(entry)

	for part in entry["spinning"]:
		_place_spinning(part, entry)


func _tire_mesh(entry: Dictionary) -> ArrayMesh:
	var source: MeshInstance3D = entry["source"]
	var wheel: Node3D = entry["wheel"]

	var sizes: Vector3 = entry["sizes"]

	var radius: float = sizes.x
	var width: float = sizes.y

	var rim: float = minf(sizes.z, radius - 0.03)

	var middle: Vector3 = source.get_aabb().get_center()
	var turn: Basis = wheel.global_basis.inverse() * source.global_basis

	var arrays: Array = source.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]

	var tire_rotation: Basis = turn.orthonormalized()

	var outer: float = 0.0
	var inner: float = INF
	var half: float = 0.0

	for i in range(vertices.size()):
		vertices[i] = turn * (vertices[i] - middle)
		normals[i] = tire_rotation * normals[i]

		var distance: float = Vector2(vertices[i].y, vertices[i].z).length()

		outer = maxf(outer, distance)
		inner = minf(inner, distance)
		half = maxf(half, absf(vertices[i].x))

	entry["inner"] = inner

	var width_scale: float = width * 0.5 / maxf(half, 0.001)

	for i in range(vertices.size()):
		var v: Vector3 = vertices[i]
		var distance: float = Vector2(v.y, v.z).length()

		var along: float = (distance - inner) / maxf(outer - inner, 0.001)
		var stretch: float = (rim + along * (radius - rim)) / maxf(distance, 0.001)

		vertices[i] = Vector3(v.x * width_scale, v.y * stretch, v.z * stretch)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals

	if arrays[Mesh.ARRAY_TANGENT] != null:
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]

		for i in range(0, tangents.size(), 4):
			var t: Vector3 = tire_rotation * Vector3(tangents[i], tangents[i + 1], tangents[i + 2])
			tangents[i] = t.x
			tangents[i + 1] = t.y
			tangents[i + 2] = t.z

		arrays[Mesh.ARRAY_TANGENT] = tangents

	arrays[Mesh.ARRAY_TEX_UV2] = null
	arrays[Mesh.ARRAY_COLOR] = null

	for step in range(definition.tire_detail):
		arrays = _cut_in_four(arrays)

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := ShaderMaterial.new()
	material.shader = SQUASH_SHADER

	var original := source.mesh.surface_get_material(0) as BaseMaterial3D
	if original != null:
		material.set_shader_parameter(&"albedo_tex", original.albedo_texture)
		material.set_shader_parameter(&"albedo_color", original.albedo_color)

		if original.normal_enabled:
			material.set_shader_parameter(&"normal_tex", original.normal_texture)
			material.set_shader_parameter(&"normal_depth", original.normal_scale)

	mesh.surface_set_material(0, material)

	return mesh


func _cut_in_four(arrays: Array) -> Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]

	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	var has_tangents: bool = arrays[Mesh.ARRAY_TANGENT] != null
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if has_tangents else PackedFloat32Array()

	var new_vertices := PackedVector3Array()
	var new_normals := PackedVector3Array()

	var new_uvs := PackedVector2Array()
	var new_tangents := PackedFloat32Array()
	var new_indices := PackedInt32Array()

	for t in range(0, indices.size(), 3):
		var corner: Array[int] = [indices[t], indices[t + 1], indices[t + 2]]
		var base: int = new_vertices.size()

		var pairs: Array[Vector2i] = [
			Vector2i(0, 0),
			Vector2i(1, 1),
			Vector2i(2, 2),
			Vector2i(0, 1),
			Vector2i(1, 2),
			Vector2i(2, 0),
		]

		for pair in pairs:
			var a: int = corner[pair.x]
			var b: int = corner[pair.y]
			var share: float = 0.0 if pair.x == pair.y else 0.5

			new_vertices.append(vertices[a].lerp(vertices[b], share))
			new_normals.append(normals[a].lerp(normals[b], share).normalized())
			new_uvs.append(uvs[a].lerp(uvs[b], share))

			if has_tangents:
				for c in range(4):
					new_tangents.append(lerpf(tangents[a * 4 + c], tangents[b * 4 + c], share))

		new_indices.append_array([base, base + 3, base + 5])
		new_indices.append_array([base + 3, base + 1, base + 4])
		new_indices.append_array([base + 5, base + 4, base + 2])
		new_indices.append_array([base + 3, base + 4, base + 5])

	arrays[Mesh.ARRAY_VERTEX] = new_vertices
	arrays[Mesh.ARRAY_NORMAL] = new_normals
	arrays[Mesh.ARRAY_TEX_UV] = new_uvs
	arrays[Mesh.ARRAY_INDEX] = new_indices

	if has_tangents:
		arrays[Mesh.ARRAY_TANGENT] = new_tangents

	return arrays


func _mount_on_tires(
	model: Node3D,
	wheels: Array[Node3D],
	carriers: Dictionary,
	word: String,
	fixed: bool,
) -> void:
	var parts: Array[Node3D] = _top_parts(model, word)

	var vehicle := get_parent() as Node3D
	var car_turn: Basis = vehicle.global_basis.inverse()

	for wheel in wheels:
		if not carriers.has(wheel):
			continue

		var part: Node3D = _nearest(parts, wheel)
		if part == null:
			continue

		parts.erase(part)

		var carrier: Node3D = carriers[wheel]["node"]
		var hub: Vector3 = carriers[wheel]["center"]

		var copy := part.duplicate() as Node3D
		part.visible = false

		var parent: Node3D = carrier
		if fixed:
			parent = _holder_of(wheel, carrier)

		parent.add_child(copy)

		var basis_in_car: Basis = car_turn * part.global_basis
		var offset_in_car: Vector3 = car_turn * (
			part.global_position - hub if fixed else part.global_position - _center_of(part)
		)

		if fixed:
			copy.basis = basis_in_car
			copy.position = offset_in_car
		else:
			var spinning: Dictionary = {
				"node": copy,
				"basis": basis_in_car,
				"position": offset_in_car,
			}

			carriers[wheel]["spinning"].append(spinning)
			_place_spinning(spinning, carriers[wheel])


func _place_spinning(spinning: Dictionary, entry: Dictionary) -> void:
	var sizes: Vector3 = entry["sizes"]
	var rim: float = minf(sizes.z, sizes.x - 0.03)
	var size: float = rim / maxf(float(entry["inner"]), 0.001)

	var base: Basis = spinning["basis"]

	spinning["node"].basis = base.scaled(Vector3.ONE * size)
	spinning["node"].position = (spinning["position"] as Vector3) * size


func _holder_of(wheel: Node3D, carrier: Node3D) -> Node3D:
	for entry in _holders:
		if entry["wheel"] == wheel:
			return entry["holder"]

	var holder := Node3D.new()
	holder.name = "Fixed"
	holder.position = carrier.position

	wheel.add_child(holder)
	_made.append(holder)

	_holders.append({ "wheel": wheel, "carrier": carrier, "holder": holder })

	return holder


func _top_parts(model: Node3D, word: String) -> Array[Node3D]:
	var parts: Array[Node3D] = []

	for node in model.find_children("*" + word + "*", "Node3D", true, false):
		var part := node as Node3D
		if not part.get_parent().name.contains(word):
			parts.append(part)

	return parts


func _nearest(parts: Array[Node3D], wheel: Node3D) -> Node3D:
	var vehicle := get_parent() as Node3D
	var spot: Vector3 = vehicle.to_local(wheel.global_position)

	var best: Node3D = null
	var best_gap: float = INF

	for part in parts:
		var center: Vector3 = vehicle.to_local(_center_of(part))
		var gap: float = Vector2(center.x - spot.x, center.z - spot.z).length()

		if gap < best_gap:
			best_gap = gap
			best = part

	return best


func _center_of(part: Node3D) -> Vector3:
	var box := AABB()
	var first: bool = true

	for node in part.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var world_box: AABB = mesh.global_transform * mesh.get_aabb()

		box = world_box if first else box.merge(world_box)
		first = false

	return box.get_center()
