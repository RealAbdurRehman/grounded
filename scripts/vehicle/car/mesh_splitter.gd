class_name MeshSplitter
extends RefCounted

const WELD_PRECISION: float = 10000.0


static func split_by_shape(mesh: ArrayMesh, inside: Callable) -> Array[ArrayMesh]:
	var found: Dictionary = _find_shapes(mesh)
	if found.is_empty():
		return []

	var arrays: Array = found["arrays"]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var shape_of: PackedInt32Array = found["shape_of"]

	var goes: Dictionary = { }
	var any_in: bool = false
	var any_out: bool = false

	for root in found["boxes"]:
		var yes: bool = inside.call(found["boxes"][root])
		goes[root] = yes

		any_in = any_in or yes
		any_out = any_out or not yes

	if not any_in or not any_out:
		return []

	var first := PackedInt32Array()
	var second := PackedInt32Array()

	for t in range(index.size() / 3.0):
		var root: int = shape_of[index[t * 3]]
		var list: PackedInt32Array = first if goes[root] else second

		list.append(index[t * 3])
		list.append(index[t * 3 + 1])
		list.append(index[t * 3 + 2])

	var material: Material = mesh.surface_get_material(0)

	var result: Array[ArrayMesh] = []
	for list in [first, second]:
		var piece := ArrayMesh.new()
		piece.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _take(arrays, list))
		piece.surface_set_material(0, material)

		result.append(piece)

	return result


static func _find_shapes(mesh: ArrayMesh) -> Dictionary:
	if mesh == null or mesh.get_surface_count() != 1:
		return { }

	var arrays: Array = mesh.surface_get_arrays(0)

	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if index.is_empty() or verts.is_empty():
		return { }

	var corner_of: Dictionary = { }
	var weld := PackedInt32Array()
	weld.resize(verts.size())

	var corners: int = 0
	for i in range(verts.size()):
		var key := Vector3i((verts[i] * WELD_PRECISION).round())

		if not corner_of.has(key):
			corner_of[key] = corners
			corners += 1

		weld[i] = corner_of[key]

	var parent := PackedInt32Array()
	parent.resize(corners)
	for i in range(corners):
		parent[i] = i

	for t in range(index.size() / 3.0):
		var a: int = _top(parent, weld[index[t * 3]])
		var b: int = _top(parent, weld[index[t * 3 + 1]])
		var c: int = _top(parent, weld[index[t * 3 + 2]])

		parent[b] = a
		parent[c] = a

	var shape_of := PackedInt32Array()
	shape_of.resize(verts.size())

	var boxes: Dictionary = { }

	for i in range(verts.size()):
		var root: int = _top(parent, weld[i])
		shape_of[i] = root

		if boxes.has(root):
			boxes[root] = (boxes[root] as AABB).expand(verts[i])
		else:
			boxes[root] = AABB(verts[i], Vector3.ZERO)

	return { "arrays": arrays, "shape_of": shape_of, "boxes": boxes }


static func _top(parent: PackedInt32Array, corner: int) -> int:
	while parent[corner] != corner:
		parent[corner] = parent[parent[corner]]
		corner = parent[corner]

	return corner


static func _take(arrays: Array, triangles: PackedInt32Array) -> Array:
	var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()

	var old_to_new := PackedInt32Array()
	old_to_new.resize(count)
	old_to_new.fill(-1)

	var kept := PackedInt32Array()
	var index := PackedInt32Array()

	for old in triangles:
		if old_to_new[old] < 0:
			old_to_new[old] = kept.size()
			kept.append(old)

		index.append(old_to_new[old])

	var result: Array = []
	result.resize(Mesh.ARRAY_MAX)

	for channel in [
		Mesh.ARRAY_VERTEX,
		Mesh.ARRAY_NORMAL,
		Mesh.ARRAY_COLOR,
		Mesh.ARRAY_TEX_UV,
		Mesh.ARRAY_TEX_UV2,
	]:
		if arrays[channel] == null:
			continue

		var source: Variant = arrays[channel]
		var picked: Variant = source.duplicate()
		picked.resize(kept.size())

		for i in range(kept.size()):
			picked[i] = source[kept[i]]

		result[channel] = picked

	if arrays[Mesh.ARRAY_TANGENT] != null:
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var picked_tangents := PackedFloat32Array()
		picked_tangents.resize(kept.size() * 4)

		for i in range(kept.size()):
			for k in range(4):
				picked_tangents[i * 4 + k] = tangents[kept[i] * 4 + k]

		result[Mesh.ARRAY_TANGENT] = picked_tangents

	result[Mesh.ARRAY_INDEX] = index

	return result
