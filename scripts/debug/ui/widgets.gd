class_name Widgets
extends RefCounted


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


static func center_text(text: String, color: Color = UITheme.TEXT) -> void:
	var width: float = ImGui.CalcTextSize(text).x
	var avail: float = ImGui.GetContentRegionAvail().x

	ImGui.SetCursorPosX(ImGui.GetCursorPosX() + maxf((avail - width) * 0.5, 0.0))
	ImGui.TextColored(color, text)


static func gap(amount: float = 0.5) -> void:
	ImGui.Dummy(Vector2(0.0, ImGui.GetFontSize() * amount))


static func tip(text: String) -> void:
	if text != "" and ImGui.IsItemHovered():
		ImGui.SetTooltip(text)


static func section(title: String, open: bool = false) -> bool:
	return ImGui.CollapsingHeader(title, ImGui.TreeNodeFlags_DefaultOpen if open else 0)


static func key_value(label: String, value: String, color: Color = UITheme.TEXT) -> void:
	ImGui.TextDisabled(label)
	ImGui.SameLine()

	right_text(value, color)


static func labeled_bar(title: String, fraction: float, overlay: String, color: Color) -> void:
	ImGui.AlignTextToFramePadding()

	ImGui.TextDisabled(title)
	ImGui.SameLineEx(ImGui.GetFontSize() * 3.6, -1.0)

	bar(fraction, overlay, color)


static func centered_bar(title: String, value: float, overlay: String, color: Color) -> void:
	ImGui.AlignTextToFramePadding()

	ImGui.TextDisabled(title)
	ImGui.SameLineEx(ImGui.GetFontSize() * 3.6, -1.0)

	var origin: Vector2 = ImGui.GetCursorScreenPos()
	var size := Vector2(ImGui.GetContentRegionAvail().x, ImGui.GetFrameHeight())
	ImGui.Dummy(size)

	var draw_list = ImGui.GetWindowDrawList()
	var middle: float = origin.x + size.x * 0.5
	var edge: float = middle + clampf(value, -1.0, 1.0) * size.x * 0.5

	ImGui.ImDrawList_AddRectFilled(draw_list, origin, origin + size, Color(0.08, 0.11, 0.17))
	ImGui.ImDrawList_AddRectFilled(
		draw_list,
		Vector2(minf(middle, edge), origin.y),
		Vector2(maxf(middle, edge), origin.y + size.y),
		color,
	)
	ImGui.ImDrawList_AddLine(
		draw_list,
		Vector2(middle, origin.y),
		Vector2(middle, origin.y + size.y),
		UITheme.GRID,
	)

	var text_size: Vector2 = ImGui.CalcTextSize(overlay)
	ImGui.ImDrawList_AddText(draw_list, origin + (size - text_size) * 0.5, UITheme.TEXT, overlay)


static func bar(
	fraction: float,
	overlay: String,
	color: Color,
	size: Vector2 = Vector2(-1.0, 0.0),
) -> void:
	ImGui.PushStyleColorImVec4(ImGui.Col_PlotHistogram, color)
	ImGui.ProgressBar(clampf(fraction, 0.0, 1.0), size, overlay)

	ImGui.PopStyleColor()


static func lamp(label: String, color: Color) -> void:
	ImGui.TextColored(color, label)


static func wheel_legend() -> void:
	for i in range(4):
		if i > 0:
			ImGui.SameLine()

		ImGui.TextColored(UITheme.WHEEL_COLORS[i], UITheme.WHEEL_NAMES[i])


static func error_color(error: float, ref: float) -> Color:
	var relative: float = absf(error) / maxf(absf(ref), 200.0)

	if relative > 0.15:
		return UITheme.BAD

	if relative > 0.05:
		return UITheme.WARN

	return UITheme.GOOD


static func wheel_table(id: String, headers: Array, row_fn: Callable) -> void:
	var flags: int = (
		ImGui.TableFlags_RowBg | ImGui.TableFlags_BordersInnerV | ImGui.TableFlags_SizingStretchProp
	)

	if not ImGui.BeginTable(id, headers.size() + 1, flags):
		return

	ImGui.TableSetupColumn("")
	for header in headers:
		if header is Array:
			ImGui.TableSetupColumnEx(header[0], 0, header[1])
		else:
			ImGui.TableSetupColumn(header)

	ImGui.TableHeadersRow()

	for i in range(4):
		ImGui.TableNextRow()
		_cell(UITheme.WHEEL_NAMES[i], UITheme.WHEEL_COLORS[i], Color(0.0, 0.0, 0.0, 0.0), false)

		for entry in row_fn.call(i):
			if entry is Dictionary:
				ImGui.TableNextColumn()
				bar(entry.fraction, entry.text, entry.color)
			elif entry is Array:
				var tint: Color = entry[2] if entry.size() > 2 else Color(0.0, 0.0, 0.0, 0.0)
				_cell(entry[0], entry[1], tint, true)
			else:
				_cell(str(entry), UITheme.TEXT, Color(0.0, 0.0, 0.0, 0.0), true)

	ImGui.EndTable()


static func _cell(text: String, color: Color, tint: Color, right_aligned: bool) -> void:
	ImGui.TableNextColumn()

	if tint.a > 0.0:
		ImGui.TableSetBgColor(ImGui.TableBgTarget_CellBg, tint)

	if right_aligned:
		right_text(text, color)
	else:
		ImGui.TextColored(color, text)


static func stat_row(id: String, stats: Array) -> void:
	if not ImGui.BeginTable(id, stats.size(), ImGui.TableFlags_SizingStretchSame):
		return

	ImGui.TableNextRow()
	for stat in stats:
		ImGui.TableNextColumn()
		var caption: String = stat[0]
		var width: float = ImGui.CalcTextSize(caption).x
		var avail: float = ImGui.GetContentRegionAvail().x

		ImGui.SetCursorPosX(ImGui.GetCursorPosX() + maxf((avail - width) * 0.5, 0.0))
		ImGui.TextDisabled(caption)

	ImGui.TableNextRow()
	for stat in stats:
		ImGui.TableNextColumn()
		center_text(stat[1], stat[2] if stat.size() > 2 else UITheme.TEXT)

	ImGui.EndTable()
