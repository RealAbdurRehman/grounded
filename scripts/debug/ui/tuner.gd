class_name Tuner
extends RefCounted

const LABEL_FRACTION: float = 0.44

var title: String

var _target: Callable
var _groups: Array = []

var _defaults: Dictionary = { }
var _snapshot_of: Object = null


func _init(section_title: String, target: Callable) -> void:
	title = section_title
	_target = target


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
	var obj: Object = _target.call()
	if obj == null or not Widgets.section(title, open):
		return

	_draw_rows(obj)


func draw_body() -> void:
	var obj: Object = _target.call()
	if obj != null:
		_draw_rows(obj)


func reset() -> void:
	var obj: Object = _target.call()
	if obj == null or _snapshot_of != obj:
		return

	for g in _groups:
		for row in g.rows:
			_write(obj, row, _defaults[row.id])


func _draw_rows(obj: Object) -> void:
	_snapshot(obj)

	ImGui.PushID(title)
	for g in _groups:
		var when: Callable = g.when
		if when.is_valid() and not when.call():
			continue

		if g.title != "":
			ImGui.SeparatorText(g.title)

		for row in g.rows:
			_draw_row(obj, row)

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


func _snapshot(obj: Object) -> void:
	if _snapshot_of == obj:
		return

	_snapshot_of = obj
	_defaults.clear()

	for g in _groups:
		for row in g.rows:
			_defaults[row.id] = _read(obj, row)


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
