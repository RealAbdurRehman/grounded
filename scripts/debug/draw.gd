class_name DebugDraw3D
extends Node3D

static var instance: DebugDraw3D

var _lines: Array[Dictionary] = []

var _immediate_mesh: ImmediateMesh
var _mesh_instance: MeshInstance3D

var _material: StandardMaterial3D

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	_immediate_mesh = ImmediateMesh.new()

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _immediate_mesh
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_material.no_depth_test = true
	_material.vertex_color_use_as_albedo = true

	_mesh_instance.material_override = _material

	add_child(_mesh_instance)

static func draw_line(from: Vector3, to: Vector3, color: Color = Color.WHITE) -> void:
	if instance == null: return
	instance._lines.append({"from": from, "to": to, "color": color})

static func draw_ray(from: Vector3, dir: Vector3, length: float, color: Color = Color.WHITE) -> void:
	if instance == null: return
	instance._lines.append({"from": from, "to": from + dir.normalized() * length, "color": color})

func _process(_delta: float) -> void:
	_immediate_mesh.clear_surfaces()
	if _lines.is_empty(): return

	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for line in _lines:
		_immediate_mesh.surface_set_color(line.color)
		_immediate_mesh.surface_add_vertex(line.from)
		_immediate_mesh.surface_add_vertex(line.to)

	_immediate_mesh.surface_end()
	
	_lines.clear()
