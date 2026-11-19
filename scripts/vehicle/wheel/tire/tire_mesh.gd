class_name TireMesh
extends RefCounted

const TREAD_FRACTION: float = 0.8
const SHOULDER_FRACTION: float = 0.22
const BEAD_FRACTION: float = 0.93

const SHOULDER_STEPS: int = 3
const SIDEWALL_STEPS: int = 5

const BOX_MARGIN_M: float = 0.06


static func build(config: SuspensionConfig, segments: int = 96) -> ArrayMesh:
	var radius: float = config.wheel_radius
	var width: float = config.width_m()

	var rim_radius: float = config.rim_m()
	var half_width: float = width * 0.5

	var right: Array[Vector2] = _right_side(radius, half_width, rim_radius)

	var section: Array[Vector2] = []
	for i in range(right.size() - 1, 0, -1):
		section.append(Vector2(-right[i].x, right[i].y))
	for i in range(right.size()):
		section.append(right[i])

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()

	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()

	var indices: PackedInt32Array = PackedInt32Array()

	var smooth: Array[Vector2] = _smooth_normals(section)
	_add_strip(section, smooth, segments, Color.WHITE, vertices, normals, uvs, colors, indices)

	var bead: float = half_width * BEAD_FRACTION
	for side in [-1.0, 1.0]:
		var face: Array[Vector2] = [
			Vector2(side * bead * 0.96, 0.0),
			Vector2(side * bead, rim_radius),
		]

		if side > 0.0:
			face.reverse()

		var flat: Array[Vector2] = [Vector2(side, 0.0), Vector2(side, 0.0)]
		_add_strip(face, flat, segments, Color.BLACK, vertices, normals, uvs, colors, indices)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var box := AABB(
		Vector3(-half_width, -radius, -radius),
		Vector3(width, radius * 2.0, radius * 2.0),
	)

	mesh.custom_aabb = box.grow(BOX_MARGIN_M)

	return mesh


static func _right_side(radius: float, half_width: float, rim_radius: float) -> Array[Vector2]:
	var sidewall: float = maxf(radius - rim_radius, 0.001)

	var tread: float = half_width * TREAD_FRACTION
	var shoulder: float = sidewall * SHOULDER_FRACTION
	var bead: float = half_width * BEAD_FRACTION

	var points: Array[Vector2] = []
	points.append(Vector2(0.0, radius))
	points.append(Vector2(tread * 0.5, radius))
	points.append(Vector2(tread, radius))

	for i in range(1, SHOULDER_STEPS + 1):
		var angle: float = (PI * 0.5) * float(i) / float(SHOULDER_STEPS)
		points.append(
			Vector2(
				tread + (half_width - tread) * sin(angle),
				radius - shoulder * (1.0 - cos(angle)),
			),
		)

	var top: float = radius - shoulder
	for i in range(1, SIDEWALL_STEPS + 1):
		var t: float = 1.0 - float(i) / float(SIDEWALL_STEPS)
		var pull: float = sin(PI * 0.5 * t)

		points.append(
			Vector2(bead + (half_width - bead) * pull, rim_radius + (top - rim_radius) * t),
		)

	return points


static func _smooth_normals(section: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []

	for i in range(section.size()):
		var before: Vector2 = section[maxi(i - 1, 0)]
		var after: Vector2 = section[mini(i + 1, section.size() - 1)]

		var along: Vector2 = (after - before).normalized()
		result.append(Vector2(-along.y, along.x))

	return result


static func _add_strip(
	section: Array[Vector2],
	section_normals: Array[Vector2],
	segments: int,
	color: Color,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
) -> void:
	var first: int = vertices.size()
	var length: float = 0.0

	var at: PackedFloat32Array = PackedFloat32Array()
	at.append(0.0)

	for i in range(1, section.size()):
		length += section[i].distance_to(section[i - 1])
		at.append(length)

	for ring in range(section.size()):
		for s in range(segments + 1):
			var angle: float = TAU * float(s) / float(segments)
			var around := Vector3(0.0, sin(angle), cos(angle))

			var point: Vector2 = section[ring]
			var normal: Vector2 = section_normals[ring]

			vertices.append(around * point.y + Vector3(point.x, 0.0, 0.0))
			normals.append(around * normal.y + Vector3(normal.x, 0.0, 0.0))

			uvs.append(Vector2(float(s) / float(segments), at[ring] / maxf(length, 0.0001)))
			colors.append(color)

	for ring in range(section.size() - 1):
		for s in range(segments):
			var a: int = first + ring * (segments + 1) + s
			var b: int = a + 1
			var c: int = a + segments + 1
			var d: int = c + 1

			indices.append_array([a, b, c, b, d, c])
