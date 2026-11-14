class_name Plots
extends RefCounted

const CURVE_SAMPLES: int = 81

const GEAR_COLORS: Array[Color] = [
	Color(0.45, 0.65, 1.00),
	Color(1.00, 0.62, 0.30),
	Color(0.40, 0.85, 0.55),
	Color(1.00, 0.45, 0.45),
	Color(0.75, 0.55, 1.00),
	Color(0.95, 0.85, 0.35),
	Color(0.35, 0.85, 0.90),
	Color(0.90, 0.55, 0.85),
]


class PlotSpec extends RefCounted:
	var x_extent: float = 1.0
	var x_display_scale: float = 1.0
	var x_format: String = "%.1f"

	var y_extent: float = 1.4

	var height: float = 120.0
	var color: Color = UITheme.ACCENT

	var peak_x: float = 0.0


static func curve_plot(
	id: String,
	curve: Callable,
	spec: PlotSpec,
	xs: PackedFloat32Array,
	ys: PackedFloat32Array,
	active: Array[bool],
) -> void:
	var values: Array = []
	for i in range(CURVE_SAMPLES):
		var x: float = lerpf(-spec.x_extent, spec.x_extent, float(i) / float(CURVE_SAMPLES - 1))
		values.append(float(curve.call(x)))

	var size := Vector2(ImGui.GetContentRegionAvail().x, spec.height)

	ImGui.PushStyleVarImVec2(ImGui.StyleVar_FramePadding, Vector2.ZERO)
	ImGui.PushStyleColorImVec4(ImGui.Col_PlotLines, spec.color)
	ImGui.PlotLinesEx(id, values, values.size(), 0, "", -spec.y_extent, spec.y_extent, size)

	ImGui.PopStyleColor()
	ImGui.PopStyleVar()

	_draw_plot_overlay(ImGui.GetItemRectMin(), ImGui.GetItemRectMax(), spec, xs, ys, active)


static func _draw_plot_overlay(
	p_min: Vector2,
	p_max: Vector2,
	spec: PlotSpec,
	xs: PackedFloat32Array,
	ys: PackedFloat32Array,
	active: Array[bool],
) -> void:
	var draw_list = ImGui.GetWindowDrawList()

	var size: Vector2 = p_max - p_min
	var center: Vector2 = p_min + size * 0.5

	var unit: float = ImGui.GetFontSize()

	ImGui.ImDrawList_AddLine(
		draw_list,
		Vector2(center.x, p_min.y),
		Vector2(center.x, p_max.y),
		UITheme.GRID,
	)

	ImGui.ImDrawList_AddLine(
		draw_list,
		Vector2(p_min.x, center.y),
		Vector2(p_max.x, center.y),
		UITheme.GRID,
	)

	for direction: float in [-1.0, 1.0]:
		var px: float = center.x + direction * spec.peak_x / spec.x_extent * size.x * 0.5
		ImGui.ImDrawList_AddLine(
			draw_list,
			Vector2(px, p_min.y),
			Vector2(px, p_max.y),
			UITheme.PEAK,
		)

	var x_text: String = spec.x_format % (spec.x_extent * spec.x_display_scale)
	var plus_text: String = "+" + x_text
	var label_y: float = center.y - unit * 1.15

	ImGui.ImDrawList_AddText(draw_list, Vector2(p_min.x + 4.0, label_y), UITheme.DIM, "-" + x_text)

	ImGui.ImDrawList_AddText(
		draw_list,
		Vector2(p_max.x - ImGui.CalcTextSize(plus_text).x - 4.0, label_y),
		UITheme.DIM,
		plus_text,
	)

	ImGui.ImDrawList_AddText(
		draw_list,
		Vector2(center.x + 4.0, p_min.y + 2.0),
		UITheme.DIM,
		"+%.1f" % spec.y_extent,
	)

	ImGui.ImDrawList_AddText(
		draw_list,
		Vector2(center.x + 4.0, p_max.y - unit - 2.0),
		UITheme.DIM,
		"-%.1f" % spec.y_extent,
	)

	var radius: float = unit * 0.32
	for i in range(4):
		if not active[i]:
			continue

		var tx: float = clampf((xs[i] + spec.x_extent) / (2.0 * spec.x_extent), 0.0, 1.0)
		var ty: float = clampf((ys[i] + spec.y_extent) / (2.0 * spec.y_extent), 0.0, 1.0)
		var pos := Vector2(p_min.x + tx * size.x, p_max.y - ty * size.y)

		ImGui.ImDrawList_AddCircleFilled(draw_list, pos, radius, UITheme.WHEEL_COLORS[i])
		ImGui.ImDrawList_AddCircle(draw_list, pos, radius + 1.0, Color(0.0, 0.0, 0.0, 0.85))


static func line_plot(
	id: String,
	values: Array,
	y_min: float,
	y_max: float,
	height: float,
	color: Color,
	caption: String = "",
	cursor_x: float = -1.0,
	cursor_y: float = 0.0,
	x_label: String = "",
) -> void:
	var size := Vector2(ImGui.GetContentRegionAvail().x, height)

	ImGui.PushStyleVarImVec2(ImGui.StyleVar_FramePadding, Vector2.ZERO)
	ImGui.PushStyleColorImVec4(ImGui.Col_PlotLines, color)
	ImGui.PlotLinesEx(id, values, values.size(), 0, caption, y_min, y_max, size)

	ImGui.PopStyleColor()
	ImGui.PopStyleVar()

	var p_min: Vector2 = ImGui.GetItemRectMin()
	var p_max: Vector2 = ImGui.GetItemRectMax()
	var draw_list = ImGui.GetWindowDrawList()
	var unit: float = ImGui.GetFontSize()

	if x_label != "":
		var label_y: float = p_max.y - unit - 2.0
		ImGui.ImDrawList_AddText(draw_list, Vector2(p_min.x + 4.0, label_y), UITheme.DIM, "0")
		ImGui.ImDrawList_AddText(
			draw_list,
			Vector2(p_max.x - ImGui.CalcTextSize(x_label).x - 4.0, label_y),
			UITheme.DIM,
			x_label,
		)

	if cursor_x < 0.0:
		return

	var x: float = p_min.x + clampf(cursor_x, 0.0, 1.0) * (p_max.x - p_min.x)
	var t: float = clampf((cursor_y - y_min) / maxf(y_max - y_min, 0.0001), 0.0, 1.0)

	ImGui.ImDrawList_AddLineEx(
		draw_list,
		Vector2(x, p_min.y),
		Vector2(x, p_max.y),
		Color(1.0, 0.9, 0.2, 0.9),
		1.5,
	)

	ImGui.ImDrawList_AddCircleFilled(
		draw_list,
		Vector2(x, p_max.y - t * (p_max.y - p_min.y)),
		unit * 0.3,
		color,
	)


static func speed_at_rpm(rpm: float, total_ratio: float, wheel_radius: float) -> float:
	return rpm * TAU / 60.0 * wheel_radius / maxf(total_ratio, 0.0001) * 3.6


static func top_speed_kmh(
	ratios: Array,
	final_drive: float,
	wheel_radius: float,
	rev_limit: float,
) -> float:
	var top: float = 0.0
	for i in range(2, ratios.size()):
		var total: float = absf(float(ratios[i])) * final_drive
		top = maxf(top, speed_at_rpm(rev_limit, total, wheel_radius))

	return top


static func gear_chart(
	ratios: Array,
	final_drive: float,
	wheel_radius: float,
	rev_limit: float,
	speed_kmh: float,
	rpm: float,
	current_index: int,
	height: float,
) -> void:
	var unit: float = ImGui.GetFontSize()
	var width: float = ImGui.GetContentRegionAvail().x
	var origin: Vector2 = ImGui.GetCursorScreenPos()
	ImGui.Dummy(Vector2(width, height))

	var draw_list = ImGui.GetWindowDrawList()

	var top_speed: float = top_speed_kmh(ratios, final_drive, wheel_radius, rev_limit)
	var x_step: float = 50.0
	var y_step: float = 1000.0
	var x_max: float = maxf(ceilf(top_speed * 1.05 / x_step) * x_step, x_step)
	var y_max: float = maxf(ceilf(rev_limit * 1.05 / y_step) * y_step, y_step)

	var plot_min: Vector2 = origin + Vector2(unit * 3.4, unit * 0.4)
	var plot_max: Vector2 = origin + Vector2(width - unit * 0.8, height - unit * 1.6)
	var plot_size: Vector2 = plot_max - plot_min

	ImGui.ImDrawList_AddRectFilled(draw_list, plot_min, plot_max, Color(0.04, 0.05, 0.07, 0.9))

	var x_value: float = 0.0
	while x_value <= x_max + 0.01:
		var px: float = plot_min.x + x_value / x_max * plot_size.x
		var x_label: String = "%d" % int(x_value)

		ImGui.ImDrawList_AddLine(
			draw_list,
			Vector2(px, plot_min.y),
			Vector2(px, plot_max.y),
			UITheme.GRID,
		)

		ImGui.ImDrawList_AddText(
			draw_list,
			Vector2(px - ImGui.CalcTextSize(x_label).x * 0.5, plot_max.y + unit * 0.2),
			UITheme.DIM,
			x_label,
		)

		x_value += x_step

	var y_value: float = 0.0
	while y_value <= y_max + 0.01:
		var py: float = plot_max.y - y_value / y_max * plot_size.y
		var y_label: String = "%d" % int(y_value)

		ImGui.ImDrawList_AddLine(
			draw_list,
			Vector2(plot_min.x, py),
			Vector2(plot_max.x, py),
			UITheme.GRID,
		)

		ImGui.ImDrawList_AddText(
			draw_list,
			Vector2(plot_min.x - ImGui.CalcTextSize(y_label).x - unit * 0.4, py - unit * 0.5),
			UITheme.DIM,
			y_label,
		)

		y_value += y_step

	ImGui.ImDrawList_AddRect(draw_list, plot_min, plot_max, Color(0.75, 0.80, 0.90, 0.6))

	for i in range(2, ratios.size()):
		var raw: float = absf(float(ratios[i]))
		var total: float = raw * final_drive
		var start_rpm: float = 0.0
		if i > 2:
			var previous: float = maxf(absf(float(ratios[i - 1])), 0.0001)
			start_rpm = clampf(rev_limit * raw / previous, 0.0, rev_limit)

		var from_point := Vector2(
			plot_min.x + speed_at_rpm(start_rpm, total, wheel_radius) / x_max * plot_size.x,
			plot_max.y - start_rpm / y_max * plot_size.y,
		)

		var to_point := Vector2(
			plot_min.x + speed_at_rpm(rev_limit, total, wheel_radius) / x_max * plot_size.x,
			plot_max.y - rev_limit / y_max * plot_size.y,
		)

		var color: Color = GEAR_COLORS[(i - 2) % GEAR_COLORS.size()]
		var thickness: float = 2.5 if i == current_index else 1.5

		ImGui.ImDrawList_AddLineEx(draw_list, from_point, to_point, color, thickness)
		ImGui.ImDrawList_AddText(
			draw_list,
			to_point + Vector2(-unit * 0.3, -unit * 1.25),
			color,
			"%d" % (i - 1),
		)

	if current_index >= 2:
		var marker := Vector2(
			plot_min.x + clampf(speed_kmh / x_max, 0.0, 1.0) * plot_size.x,
			plot_max.y - clampf(rpm / y_max, 0.0, 1.0) * plot_size.y,
		)

		ImGui.ImDrawList_AddCircleFilled(draw_list, marker, unit * 0.32, Color(1.0, 1.0, 1.0, 1.0))
		ImGui.ImDrawList_AddCircle(draw_list, marker, unit * 0.32 + 1.0, Color(0.0, 0.0, 0.0, 0.85))


static func friction_circle(
	label: String,
	color: Color,
	fx_norm: float,
	fy_norm: float,
	diameter: float,
) -> void:
	var origin: Vector2 = ImGui.GetCursorScreenPos()

	var label_gap: float = ImGui.GetFontSize() + 2.0
	ImGui.Dummy(Vector2(diameter, diameter + label_gap))

	var draw_list = ImGui.GetWindowDrawList()

	var center: Vector2 = origin + Vector2(diameter * 0.5, label_gap + diameter * 0.5)
	var radius: float = diameter * 0.46

	ImGui.ImDrawList_AddCircleFilled(draw_list, center, radius, Color(0.05, 0.07, 0.11, 0.9), 32)

	ImGui.ImDrawList_AddLine(
		draw_list,
		center - Vector2(radius, 0.0),
		center + Vector2(radius, 0.0),
		UITheme.GRID,
	)

	ImGui.ImDrawList_AddLine(
		draw_list,
		center - Vector2(0.0, radius),
		center + Vector2(0.0, radius),
		UITheme.GRID,
	)

	ImGui.ImDrawList_AddCircle(draw_list, center, radius, Color(0.75, 0.80, 0.90, 0.85))

	var force: Vector2 = Vector2(fy_norm, -fx_norm).limit_length(1.15)
	var dot: Vector2 = center + force * radius
	var dot_color: Color = UITheme.GOOD if Vector2(fx_norm, fy_norm).length() <= 1.0 else UITheme.BAD

	ImGui.ImDrawList_AddLine(draw_list, center, dot, dot_color)
	ImGui.ImDrawList_AddCircleFilled(draw_list, dot, ImGui.GetFontSize() * 0.28, dot_color)

	var text_size: Vector2 = ImGui.CalcTextSize(label)
	var text_x: float = origin.x + (diameter - text_size.x) * 0.5
	var text_y: float = origin.y + (label_gap - text_size.y) * 0.5
	ImGui.ImDrawList_AddText(draw_list, Vector2(text_x, text_y), color, label)


static func shift_lights(rpm_fraction: float, count: int, diameter: float) -> void:
	var gap_width: float = diameter * 0.5
	var origin: Vector2 = ImGui.GetCursorScreenPos()
	ImGui.Dummy(Vector2((diameter + gap_width) * count, diameter))

	var draw_list = ImGui.GetWindowDrawList()
	var lit: int = roundi(clampf((rpm_fraction - 0.55) / 0.45, 0.0, 1.0) * count)
	for i in range(count):
		var color := Color(0.18, 0.20, 0.24, 1.0)
		if i < lit:
			if i < count * 0.6:
				color = UITheme.GOOD
			elif i < count * 0.8:
				color = UITheme.WARN
			else:
				color = UITheme.BAD

		var center: Vector2 = origin + Vector2(
			i * (diameter + gap_width) + diameter * 0.5,
			diameter * 0.5,
		)

		ImGui.ImDrawList_AddCircleFilled(draw_list, center, diameter * 0.5, color, 16)


static func gg_plot(trail: Array, current: Vector2, extent: float, height: float) -> void:
	var unit: float = ImGui.GetFontSize()
	var size := Vector2(ImGui.GetContentRegionAvail().x, height)
	var origin: Vector2 = ImGui.GetCursorScreenPos()
	ImGui.Dummy(size)

	var draw_list = ImGui.GetWindowDrawList()
	var center: Vector2 = origin + size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - unit * 1.0
	var scale: float = radius / extent

	ImGui.ImDrawList_AddRectFilled(draw_list, origin, origin + size, Color(0.04, 0.05, 0.07, 0.9))

	var ring: float = 0.5
	while ring <= extent + 0.01:
		ImGui.ImDrawList_AddCircleEx(draw_list, center, ring * scale, UITheme.GRID, 48, 1.0)
		ImGui.ImDrawList_AddText(
			draw_list,
			center + Vector2(3.0, -ring * scale + 1.0),
			UITheme.DIM,
			"%.1f" % ring,
		)

		ring += 0.5

	ImGui.ImDrawList_AddLine(
		draw_list,
		center - Vector2(radius, 0.0),
		center + Vector2(radius, 0.0),
		UITheme.GRID,
	)

	ImGui.ImDrawList_AddLine(
		draw_list,
		center - Vector2(0.0, radius),
		center + Vector2(0.0, radius),
		UITheme.GRID,
	)

	_centered_text(draw_list, "ACCEL", Vector2(center.x, origin.y + 2.0))
	_centered_text(draw_list, "BRAKE", Vector2(center.x, origin.y + size.y - unit - 2.0))

	ImGui.ImDrawList_AddText(
		draw_list,
		Vector2(origin.x + 4.0, center.y - unit * 0.5),
		UITheme.DIM,
		"L",
	)
	ImGui.ImDrawList_AddText(
		draw_list,
		Vector2(origin.x + size.x - unit * 0.7 - 2.0, center.y - unit * 0.5),
		UITheme.DIM,
		"R",
	)

	var count: int = trail.size()
	for i in range(count):
		var sample: Vector2 = trail[i]
		var point: Vector2 = center + Vector2(sample.x, -sample.y).limit_length(extent * 1.05) * scale
		var age: float = float(i + 1) / float(count)

		ImGui.ImDrawList_AddCircleFilled(
			draw_list,
			point,
			unit * (0.10 + 0.14 * age),
			Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.08 + 0.55 * age),
			8,
		)

	var dot: Vector2 = center + Vector2(current.x, -current.y).limit_length(extent * 1.05) * scale
	var dot_color: Color = UITheme.WARN if current.length() > 1.0 else Color(1.0, 1.0, 1.0, 1.0)

	ImGui.ImDrawList_AddLine(draw_list, center, dot, dot_color)
	ImGui.ImDrawList_AddCircleFilled(draw_list, dot, unit * 0.34, dot_color, 12)
	ImGui.ImDrawList_AddCircle(draw_list, dot, unit * 0.34 + 1.0, Color(0.0, 0.0, 0.0, 0.85))


static func _centered_text(draw_list, text: String, top_center: Vector2) -> void:
	var width: float = ImGui.CalcTextSize(text).x
	ImGui.ImDrawList_AddText(draw_list, top_center - Vector2(width * 0.5, 0.0), UITheme.DIM, text)


static func car_diagram(
	height: float,
	loads: Array,
	usage: Array,
	front_share: float,
	left_share: float,
) -> void:
	var unit: float = ImGui.GetFontSize()
	var width: float = ImGui.GetContentRegionAvail().x
	var origin: Vector2 = ImGui.GetCursorScreenPos()
	ImGui.Dummy(Vector2(width, height))

	var draw_list = ImGui.GetWindowDrawList()

	var box_h: float = minf(height - unit * 0.6, (width - unit * 9.0) * 1.9)
	box_h = maxf(box_h, unit * 6.0)
	var box_w: float = box_h / 1.9

	var center: Vector2 = origin + Vector2(width * 0.5, height * 0.5)
	var top: float = center.y - box_h * 0.5

	var wheel_w: float = box_w * 0.24
	var wheel_h: float = box_h * 0.19

	var left_x: float = center.x - box_w * 0.5 + wheel_w * 0.5
	var right_x: float = center.x + box_w * 0.5 - wheel_w * 0.5

	var front_y: float = top + box_h * 0.2
	var rear_y: float = top + box_h * 0.8

	var body_min := Vector2(left_x + wheel_w * 0.3, top + box_h * 0.02)
	var body_max := Vector2(right_x - wheel_w * 0.3, top + box_h * 0.98)
	var body_color := Color(0.12, 0.16, 0.24, 1.0)

	ImGui.ImDrawList_AddRectFilledEx(draw_list, body_min, body_max, body_color, unit * 1.2, 0)
	ImGui.ImDrawList_AddRectEx(draw_list, body_min, body_max, UITheme.GRID, unit * 1.2, 0, 1.0)

	var nose_y: float = body_min.y + (body_max.y - body_min.y) * 0.16
	ImGui.ImDrawList_AddTriangleFilled(
		draw_list,
		Vector2(center.x, nose_y - unit * 0.7),
		Vector2(center.x - unit * 0.6, nose_y),
		Vector2(center.x + unit * 0.6, nose_y),
		UITheme.DIM,
	)

	for y: float in [front_y, rear_y]:
		ImGui.ImDrawList_AddLine(draw_list, Vector2(left_x, y), Vector2(right_x, y), UITheme.GRID)

	var centers: Array = [
		Vector2(left_x, front_y),
		Vector2(right_x, front_y),
		Vector2(left_x, rear_y),
		Vector2(right_x, rear_y),
	]

	for i in range(4):
		var wheel_center: Vector2 = centers[i]
		var w_min: Vector2 = wheel_center - Vector2(wheel_w, wheel_h) * 0.5
		var w_max: Vector2 = wheel_center + Vector2(wheel_w, wheel_h) * 0.5

		var used: float = clampf(usage[i], 0.0, 1.0)
		var fill_color: Color = UITheme.GOOD
		if usage[i] > 1.0:
			fill_color = UITheme.BAD
		elif usage[i] > 0.85:
			fill_color = UITheme.WARN

		fill_color.a = 0.75

		ImGui.ImDrawList_AddRectFilledEx(
			draw_list,
			w_min,
			w_max,
			Color(0.04, 0.05, 0.07, 1.0),
			3.0,
			0,
		)
		ImGui.ImDrawList_AddRectFilledEx(
			draw_list,
			Vector2(w_min.x, w_max.y - (w_max.y - w_min.y) * used),
			w_max,
			fill_color,
			3.0,
			0,
		)
		ImGui.ImDrawList_AddRectEx(draw_list, w_min, w_max, UITheme.WHEEL_COLORS[i], 3.0, 0, 1.5)

		var name_size: Vector2 = ImGui.CalcTextSize(UITheme.WHEEL_NAMES[i])
		ImGui.ImDrawList_AddText(
			draw_list,
			wheel_center - name_size * 0.5,
			Color(1.0, 1.0, 1.0, 1.0),
			UITheme.WHEEL_NAMES[i],
		)

		var load_text: String = "%.0f N" % loads[i]
		var usage_text: String = "%.0f%%" % (usage[i] * 100.0)
		var text_x: float = w_max.x + 5.0
		if i % 2 == 0:
			text_x = w_min.x - 5.0 - maxf(
				ImGui.CalcTextSize(load_text).x,
				ImGui.CalcTextSize(usage_text).x,
			)

		ImGui.ImDrawList_AddText(
			draw_list,
			Vector2(text_x, wheel_center.y - unit),
			UITheme.TEXT,
			load_text,
		)
		ImGui.ImDrawList_AddText(draw_list, Vector2(text_x, wheel_center.y), fill_color, usage_text)

	var cg := Vector2(
		lerpf(right_x, left_x, clampf(left_share, 0.0, 1.0)),
		lerpf(rear_y, front_y, clampf(front_share, 0.0, 1.0)),
	)
	var mid := Vector2(center.x, (front_y + rear_y) * 0.5)

	ImGui.ImDrawList_AddLine(
		draw_list,
		mid - Vector2(unit * 0.4, 0.0),
		mid + Vector2(unit * 0.4, 0.0),
		UITheme.DIM,
	)
	ImGui.ImDrawList_AddLine(
		draw_list,
		mid - Vector2(0.0, unit * 0.4),
		mid + Vector2(0.0, unit * 0.4),
		UITheme.DIM,
	)
	ImGui.ImDrawList_AddLine(
		draw_list,
		mid,
		cg,
		Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.6),
	)
	ImGui.ImDrawList_AddCircleFilled(draw_list, cg, unit * 0.42, UITheme.ACCENT, 14)
	ImGui.ImDrawList_AddCircle(draw_list, cg, unit * 0.42 + 1.0, Color(0.0, 0.0, 0.0, 0.85))
