class_name Tuner
extends RefCounted

const LABEL_FRACTION: float = 0.44
const AXLE_LABEL_FRACTION: float = 0.30

var title: String

var _target: Callable
var _rear_target: Callable

var _active: Callable
var _groups: Array = []

var _defaults: Array = [{ }, { }]
var _snapshot_of: Array = [null, null]

var _link: Array = [false]


func _init(
	section_title: String,
	target: Callable,
	rear_target: Callable = Callable(),
	active: Callable = Callable(),
) -> void:
	title = section_title

	_target = target
	_rear_target = rear_target

	_active = active


static func slider(
	prop: StringName,
	label: String,
	v_min: float,
	v_max: float,
	fmt: String = "%.2f",
	tip: String = "",
) -> Dictionary:
	return {
		"kind": "slider",
		"id": prop,
		"prop": prop,
		"label": label,
		"min": v_min,
		"max": v_max,
		"fmt": fmt,
		"tip": tip,
	}


static func toggle(prop: StringName, label: String, tip: String = "") -> Dictionary:
	return { "kind": "toggle", "id": prop, "prop": prop, "label": label, "tip": tip }


static func choice(prop: StringName, label: String, names: Array, tip: String = "") -> Dictionary:
	return {
		"kind": "choice",
		"id": prop,
		"prop": prop,
		"label": label,
		"names": names,
		"tip": tip,
	}


static func custom(
	id: StringName,
	label: String,
	getter: Callable,
	setter: Callable,
	v_min: float,
	v_max: float,
	fmt: String = "%.2f",
	tip: String = "",
) -> Dictionary:
	return {
		"kind": "slider",
		"id": id,
		"label": label,
		"getter": getter,
		"setter": setter,
		"min": v_min,
		"max": v_max,
		"fmt": fmt,
		"tip": tip,
	}


static func custom_choice(
	id: StringName,
	label: String,
	names: Array,
	getter: Callable,
	setter: Callable,
	tip: String = "",
) -> Dictionary:
	return {
		"kind": "choice",
		"id": id,
		"label": label,
		"names": names,
		"getter": getter,
		"setter": setter,
		"tip": tip,
	}


static func field(
	label: String,
	id: String,
	buffer: Array,
	v_min: float,
	v_max: float,
	fmt: String,
	tip: String = "",
) -> bool:
	_label(label, tip)
	return ImGui.SliderFloatEx("##%s" % id, buffer, v_min, v_max, fmt, 0)


static func int_field(
	label: String,
	id: String,
	buffer: Array,
	v_min: int,
	v_max: int,
	tip: String = "",
) -> bool:
	_label(label, tip)
	return ImGui.SliderIntEx("##%s" % id, buffer, v_min, v_max, "%d", 0)


static func _label(label: String, tip: String) -> void:
	var start_x: float = ImGui.GetCursorPosX()
	var avail: float = ImGui.GetContentRegionAvail().x

	ImGui.AlignTextToFramePadding()
	ImGui.TextDisabled(label)
	Widgets.tip(tip)

	ImGui.SameLineEx(start_x + avail * LABEL_FRACTION, -1.0)
	ImGui.SetNextItemWidth(-1.0)


func group(group_title: String, rows: Array, when: Callable = Callable()) -> Tuner:
	_groups.append({ "title": group_title, "rows": rows, "when": when })
	return self


func draw(open: bool = false) -> void:
	var objs: Array = _objects()
	if objs[0] == null or not Widgets.section(title, open):
		return

	_draw_rows(objs)


func draw_body() -> void:
	var objs: Array = _objects()
	if objs[0] != null:
		_draw_rows(objs)


func reset() -> void:
	var objs: Array = _objects()
	for i in range(2):
		if objs[i] == null or _snapshot_of[i] != objs[i]:
			continue

		for g in _groups:
			for row in g.rows:
				_write(objs[i], row, _defaults[i][row.id])


func _objects() -> Array:
	var first: Object = _target.call()
	var second: Object = null
	if _rear_target.is_valid():
		second = _rear_target.call()
		if second == first:
			second = null

	return [first, second]


func _draw_rows(objs: Array) -> void:
	_snapshot(objs)

	var dual: bool = objs[1] != null

	ImGui.PushID(title)
	if dual:
		_draw_axle_header()

	for g in _groups:
		var when: Callable = g.when
		if when.is_valid() and not when.call():
			continue

		if g.title != "":
			ImGui.SeparatorText(g.title)

		for row in g.rows:
			if dual:
				_draw_row_dual(objs, row)
			else:
				_draw_row(objs[0], row)

	Widgets.gap(0.2)
	if ImGui.SmallButton("Reset"):
		reset()

	ImGui.PopID()


func _draw_row(obj: Object, row: Dictionary) -> void:
	var id: String = str(row.id)

	match row.kind:
		"slider":
			var buffer: Array = [float(_read(obj, row))]
			if field(row.label, id, buffer, row.min, row.max, row.fmt, row.tip):
				_write(obj, row, buffer[0])
		"toggle":
			var buffer: Array = [bool(_read(obj, row))]
			if ImGui.Checkbox("%s##%s" % [row.label, id], buffer):
				_write(obj, row, buffer[0])

			Widgets.tip(row.tip)
		"choice":
			var names: Array = row.names
			var current: int = clampi(int(_read(obj, row)), 0, names.size() - 1)

			_label(row.label, row.tip)
			if ImGui.BeginCombo("##%s" % id, names[current], 0):
				for i in range(names.size()):
					if ImGui.Selectable("%s##%d" % [names[i], i]):
						_write(obj, row, i)

				ImGui.EndCombo()


func _draw_axle_header() -> void:
	var layout: Dictionary = _axle_layout()

	ImGui.AlignTextToFramePadding()
	ImGui.Checkbox("Link##link", _link)
	Widgets.tip("Copy every change to both axles.")

	var names: Array = ["Front", "Rear"]
	for i in range(2):
		var width: float = ImGui.CalcTextSize(names[i]).x
		var x: float = layout.start + layout.label_width + i * (
			layout.column_width + layout.spacing
		)

		ImGui.SameLineEx(x + maxf((layout.column_width - width) * 0.5, 0.0), -1.0)
		ImGui.TextDisabled(names[i])


func _draw_row_dual(objs: Array, row: Dictionary) -> void:
	var layout: Dictionary = _axle_layout()
	var id: String = str(row.id)
	var active: Array = [true, true]
	if _active.is_valid():
		active = _active.call()

	ImGui.AlignTextToFramePadding()
	ImGui.TextDisabled(row.label)
	Widgets.tip(row.tip)

	for i in range(2):
		var x: float = layout.start + layout.label_width + i * (
			layout.column_width + layout.spacing
		)

		ImGui.SameLineEx(x, -1.0)
		ImGui.SetNextItemWidth(layout.column_width)

		ImGui.BeginDisabled(not active[i])
		var changed: bool = false
		var value: Variant = null
		var suffix: String = "##%s_%d" % [id, i]

		match row.kind:
			"slider":
				var buffer: Array = [float(_read(objs[i], row))]
				changed = ImGui.SliderFloatEx(suffix, buffer, row.min, row.max, row.fmt, 0)
				value = buffer[0]
			"toggle":
				var buffer: Array = [bool(_read(objs[i], row))]
				changed = ImGui.Checkbox(suffix, buffer)
				value = buffer[0]
			"choice":
				var names: Array = row.names
				var current: int = clampi(int(_read(objs[i], row)), 0, names.size() - 1)
				if ImGui.BeginCombo(suffix, names[current], 0):
					for n in range(names.size()):
						if ImGui.Selectable("%s##%d" % [names[n], n]):
							changed = true
							value = n

					ImGui.EndCombo()

		ImGui.EndDisabled()

		if changed:
			_write(objs[i], row, value)
			if _link[0]:
				_write(objs[1 - i], row, value)


func _axle_layout() -> Dictionary:
	var avail: float = ImGui.GetContentRegionAvail().x
	var spacing: float = ImGui.GetFontSize() * 0.4
	var label_width: float = avail * AXLE_LABEL_FRACTION

	return {
		"start": ImGui.GetCursorPosX(),
		"label_width": label_width,
		"spacing": spacing,
		"column_width": (avail - label_width - spacing) * 0.5,
	}


func _snapshot(objs: Array) -> void:
	for i in range(2):
		if objs[i] == null or _snapshot_of[i] == objs[i]:
			continue

		_snapshot_of[i] = objs[i]
		_defaults[i].clear()

		for g in _groups:
			for row in g.rows:
				_defaults[i][row.id] = _read(objs[i], row)


func _read(obj: Object, row: Dictionary) -> Variant:
	if row.has("getter"):
		var getter: Callable = row.getter
		return getter.call()

	return obj.get(row.prop)


func _write(obj: Object, row: Dictionary, value: Variant) -> void:
	if row.has("setter"):
		var setter: Callable = row.setter
		setter.call(value)
	else:
		obj.set(row.prop, value)
