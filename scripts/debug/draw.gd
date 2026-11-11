class_name DebugDraw3D
extends Node3D

static var instance: DebugDraw3D

var _lines: Array[Dictionary] = []
var _lines_tick: int = -1

var _mesh: ImmediateMesh
var _mesh_instance: MeshInstance3D


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()

	_mesh_instance.mesh = _mesh
	_mesh_instance.top_level = true

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.vertex_color_use_as_albedo = true

	_mesh_instance.material_override = material
	add_child(_mesh_instance)


static func draw_line(
	from: Vector3,
	to: Vector3,
	color: Color = Color.WHITE,
	anchor: Node3D = null,
) -> void:
	if instance != null:
		instance._push(from, to, color, anchor)


static func draw_vector(
	origin: Vector3,
	vector: Vector3,
	color: Color = Color.WHITE,
	anchor: Node3D = null,
) -> void:
	if instance != null:
		instance._push(origin, origin + vector, color, anchor)


func _push(from: Vector3, to: Vector3, color: Color, anchor: Node3D) -> void:
	var tick: int = Engine.get_physics_frames()
	if tick != _lines_tick:
		_lines.clear()
		_lines_tick = tick

	if anchor != null:
		var inverse: Transform3D = anchor.global_transform.affine_inverse()
		from = inverse * from
		to = inverse * to

	_lines.append({ "a": from, "b": to, "color": color, "anchor": anchor })


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()

	var points := PackedVector3Array()
	var colors := PackedColorArray()
	for line in _lines:
		var a: Vector3 = line["a"]
		var b: Vector3 = line["b"]

		var anchor: Node3D = line["anchor"]
		if anchor != null:
			if not is_instance_valid(anchor) or not anchor.is_inside_tree():
				continue

			var xf: Transform3D = anchor.get_global_transform_interpolated()
			a = xf * a
			b = xf * b

		points.append(a)
		points.append(b)

		colors.append(line["color"])
		colors.append(line["color"])

	if points.is_empty():
		return

	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(points.size()):
		_mesh.surface_set_color(colors[i])
		_mesh.surface_add_vertex(points[i])

	_mesh.surface_end()
