extends StaticBody3D

@export var noise: FastNoiseLite

@export var width: int = 128
@export var depth: int = 128

@export var height_scale: float = 6.0
@export var noise_scale: float = 2.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	_generate_terrain()

func _generate_terrain() -> void:
	var heights = PackedFloat32Array()
	heights.resize(width * depth)
	
	for z in range(depth):
		for x in range(width):
			var noise_val = noise.get_noise_2d(x * noise_scale, z * noise_scale)
			heights[z * width + x] = noise_val * height_scale
	
	_build_mesh(heights)
	_build_collision(heights)

func _build_mesh(heights: PackedFloat32Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var offset_x = (width - 1) / 2.0
	var offset_z = (depth - 1) / 2.0
	
	for z in range(depth - 1):
		for x in range(width - 1):
			var h_tl = heights[z * width + x]
			var h_tr = heights[z * width + x + 1]
			var h_bl = heights[(z + 1) * width + x]
			var h_br = heights[(z + 1) * width + x + 1]
			
			st.set_uv(Vector2(0, 0)); st.add_vertex(Vector3(x - offset_x, h_tl, z - offset_z))
			st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3(x + 1 - offset_x, h_tr, z - offset_z))
			st.set_uv(Vector2(0, 1)); st.add_vertex(Vector3(x - offset_x, h_bl, z + 1 - offset_z))
			
			st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3(x + 1 - offset_x, h_tr, z - offset_z))
			st.set_uv(Vector2(1, 1)); st.add_vertex(Vector3(x + 1 - offset_x, h_br, z + 1 - offset_z))
			st.set_uv(Vector2(0, 1)); st.add_vertex(Vector3(x - offset_x, h_bl, z + 1 - offset_z))
	
	st.generate_normals()
	st.generate_tangents()
	
	mesh_instance.mesh = st.commit()

func _build_collision(heights: PackedFloat32Array) -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = width
	shape.map_depth = depth
	shape.map_data = heights
	
	collision_shape.shape = shape
