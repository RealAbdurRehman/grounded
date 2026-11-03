
@tool
extends StaticBody3D

@export var noise: FastNoiseLite:
	set(value):
		noise = value
		if is_inside_tree(): call_deferred("_generate_terrain")

@export_range(2, 512) var width: int = 128:
	set(value):
		width = value
		if is_inside_tree(): call_deferred("_generate_terrain")

@export_range(2, 512) var depth: int = 128:
	set(value):
		depth = value
		if is_inside_tree(): call_deferred("_generate_terrain")

@export var height_scale: float = 6.0:
	set(value):
		height_scale = value
		if is_inside_tree(): call_deferred("_generate_terrain")

@export var noise_scale: float = 2.0:
	set(value):
		noise_scale = value
		if is_inside_tree(): call_deferred("_generate_terrain")


func _ready() -> void:
	_generate_terrain()


func _generate_terrain() -> void:
	var mesh_instance := get_node_or_null("MeshInstance3D") as MeshInstance3D
	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	
	var heights := PackedFloat32Array()
	heights.resize(width * depth)
	
	for z in range(depth):
		for x in range(width):
			var noise_val := noise.get_noise_2d(x * noise_scale, z * noise_scale)
			heights[z * width + x] = noise_val * height_scale
	
	_build_mesh(heights, mesh_instance)
	_build_collision(heights, collision_shape)


func _build_mesh(heights: PackedFloat32Array, mesh_instance: MeshInstance3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var offset_x := (width - 1) / 2.0
	var offset_z := (depth - 1) / 2.0
	
	for z in range(depth - 1):
		for x in range(width - 1):
			var h_tl := heights[z * width + x]
			var h_tr := heights[z * width + x + 1]
			var h_bl := heights[(z + 1) * width + x]
			var h_br := heights[(z + 1) * width + x + 1]

			st.set_uv(Vector2(0, 0))
			st.add_vertex(Vector3(x - offset_x, h_tl, z - offset_z))

			st.set_uv(Vector2(1, 0))
			st.add_vertex(Vector3(x + 1 - offset_x, h_tr, z - offset_z))

			st.set_uv(Vector2(0, 1))
			st.add_vertex(Vector3(x - offset_x, h_bl, z + 1 - offset_z))

			st.set_uv(Vector2(1, 0))
			st.add_vertex(Vector3(x + 1 - offset_x, h_tr, z - offset_z))

			st.set_uv(Vector2(1, 1))
			st.add_vertex(Vector3(x + 1 - offset_x, h_br, z + 1 - offset_z))

			st.set_uv(Vector2(0, 1))
			st.add_vertex(Vector3(x - offset_x, h_bl, z + 1 - offset_z))

	st.generate_normals()
	st.generate_tangents()

	mesh_instance.mesh = st.commit()


func _build_collision(heights: PackedFloat32Array, collision_shape: CollisionShape3D) -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = width
	shape.map_depth = depth
	shape.map_data = heights

	collision_shape.shape = shape
