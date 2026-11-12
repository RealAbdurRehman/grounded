class_name Widgets
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


static func right_text(text: String, color: Color = UITheme.TEXT) -> void:
	var width: float = ImGui.CalcTextSize(text).x
	var avail: float = ImGui.GetContentRegionAvail().x

	ImGui.SetCursorPosX(ImGui.GetCursorPosX() + maxf(avail - width, 0.0))
	ImGui.TextColored(color, text)


static func plot_title(text: String) -> void:
	var width: float = ImGui.CalcTextSize(text).x
	var avail: float = ImGui.GetContentRegionAvail().x

	ImGui.SetCursorPosX(ImGui.GetCursorPosX() + maxf((avail - width) * 0.5, 0.0))
	ImGui.TextDisabled(text)


static func gap(amount: float = 0.5) -> void:
	ImGui.Dummy(Vector2(0.0, ImGui.GetFontSize() * amount))


static func key_value(label: String, value: String, color: Color = UITheme.TEXT) -> void:
	ImGui.TextDisabled(label)
	ImGui.SameLine()

	right_text(value, color)


static func label_cell(text: String, color: Color = UITheme.TEXT) -> void:
	ImGui.TableNextColumn()
	ImGui.TextColored(color, text)


static func cell(
	text: String,
	color: Color = UITheme.TEXT,
	tint: Color = Color(0.0, 0.0, 0.0, 0.0),
) -> void:
	ImGui.TableNextColumn()

	if tint.a > 0.0:
		ImGui.TableSetBgColor(ImGui.TableBgTarget_CellBg, tint)

	right_text(text, color)


static func error_color(error: float, ref: float) -> Color:
	var relative: float = absf(error) / maxf(absf(ref), 200.0)
	if relative > 0.15:
		return UITheme.BAD
	if relative > 0.05:
		return UITheme.WARN

	return UITheme.GOOD


static func slider(
	label: String,
	id: String,
	buffer: Array,
	v_min: float,
	v_max: float,
	format: String,
) -> bool:
	var unit: float = ImGui.GetFontSize()
	ImGui.SetNextItemWidth(maxf(ImGui.GetContentRegionAvail().x - unit * 11.0, unit * 6.0))

	return ImGui.SliderFloatEx("%s##%s" % [label, id], buffer, v_min, v_max, format, 0)


static func reset_button(label: String) -> bool:
	gap(0.3)

	return ImGui.Button(label)


static func bar(
	fraction: float,
	overlay: String,
	color: Color,
	size: Vector2 = Vector2(-1.0, 0.0),
) -> void:
	ImGui.PushStyleColorImVec4(ImGui.Col_PlotHistogram, color)
	ImGui.ProgressBar(clampf(fraction, 0.0, 1.0), size, overlay)

	ImGui.PopStyleColor()


static func labeled_bar(title: String, fraction: float, overlay: String, color: Color) -> void:
	ImGui.AlignTextToFramePadding()

	ImGui.TextDisabled(title)
	ImGui.SameLineEx(ImGui.GetFontSize() * 3.6)

	bar(fraction, overlay, color)


static func bar_with_text(
	fraction: float,
	overlay: String,
	color: Color,
	side_text: String,
) -> void:
	var side_width: float = ImGui.GetFontSize() * 9.0
	var bar_width: float = maxf(ImGui.GetContentRegionAvail().x - side_width, 40.0)
	bar(fraction, overlay, color, Vector2(bar_width, 0.0))

	ImGui.SameLine()
	ImGui.Text(side_text)


static func wheel_legend() -> void:
	for i in range(4):
		if i > 0:
			ImGui.SameLine()

		ImGui.TextColored(UITheme.WHEEL_COLORS[i], UITheme.WHEEL_NAMES[i])


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
