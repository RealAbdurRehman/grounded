class_name UITheme
extends RefCounted

const TEXT := Color(0.88, 0.92, 0.97)
const DIM := Color(0.52, 0.58, 0.68)
const ACCENT := Color(0.26, 0.59, 0.98)

const GOOD := Color(0.35, 0.90, 0.50)
const WARN := Color(1.0, 0.72, 0.25)
const BAD := Color(1.0, 0.35, 0.35)

const GRID := Color(0.45, 0.52, 0.65, 0.40)
const PEAK := Color(0.35, 0.80, 0.45, 0.35)

const WHEEL_NAMES: Array[String] = ["FL", "FR", "RL", "RR"]
const WHEEL_COLORS: Array[Color] = [
	Color(1.0, 0.90, 0.20),
	Color(1.0, 0.60, 0.20),
	Color(0.30, 0.90, 1.00),
	Color(1.0, 0.40, 1.00),
]

static var _pushed_colors: int = 0
static var _pushed_vars: int = 0


static func push() -> void:
	var colors: Array = [
		[ImGui.Col_Text, TEXT],
		[ImGui.Col_TextDisabled, DIM],
		[ImGui.Col_WindowBg, Color(0.035, 0.045, 0.060, 0.97)],
		[ImGui.Col_PopupBg, Color(0.05, 0.06, 0.09, 0.98)],
		[ImGui.Col_Border, Color(0.13, 0.19, 0.30, 1.0)],
		[ImGui.Col_FrameBg, Color(0.08, 0.11, 0.17, 1.0)],
		[ImGui.Col_FrameBgHovered, Color(0.12, 0.18, 0.28, 1.0)],
		[ImGui.Col_FrameBgActive, Color(0.14, 0.22, 0.34, 1.0)],
		[ImGui.Col_TitleBg, Color(0.04, 0.07, 0.12, 1.0)],
		[ImGui.Col_TitleBgActive, Color(0.06, 0.13, 0.24, 1.0)],
		[ImGui.Col_TitleBgCollapsed, Color(0.04, 0.07, 0.12, 1.0)],
		[ImGui.Col_ScrollbarBg, Color(0.03, 0.04, 0.06, 0.6)],
		[ImGui.Col_ScrollbarGrab, Color(0.18, 0.28, 0.45, 1.0)],
		[ImGui.Col_CheckMark, ACCENT],
		[ImGui.Col_SliderGrab, ACCENT],
		[ImGui.Col_SliderGrabActive, Color(0.40, 0.70, 1.0, 1.0)],
		[ImGui.Col_Button, Color(0.10, 0.20, 0.36, 1.0)],
		[ImGui.Col_ButtonHovered, Color(0.15, 0.30, 0.52, 1.0)],
		[ImGui.Col_ButtonActive, Color(0.20, 0.40, 0.70, 1.0)],
		[ImGui.Col_Header, Color(0.10, 0.22, 0.40, 1.0)],
		[ImGui.Col_HeaderHovered, Color(0.15, 0.30, 0.52, 1.0)],
		[ImGui.Col_HeaderActive, Color(0.20, 0.40, 0.70, 1.0)],
		[ImGui.Col_Separator, Color(0.15, 0.22, 0.34, 1.0)],
		[ImGui.Col_Tab, Color(0.06, 0.11, 0.20, 1.0)],
		[ImGui.Col_TabHovered, Color(0.16, 0.34, 0.60, 1.0)],
		[ImGui.Col_TabSelected, Color(0.12, 0.28, 0.52, 1.0)],
		[ImGui.Col_TabSelectedOverline, ACCENT],
		[ImGui.Col_PlotLines, ACCENT],
		[ImGui.Col_PlotHistogram, Color(0.90, 0.70, 0.20, 1.0)],
		[ImGui.Col_TableHeaderBg, Color(0.07, 0.11, 0.18, 1.0)],
		[ImGui.Col_TableBorderStrong, Color(0.15, 0.22, 0.34, 1.0)],
		[ImGui.Col_TableBorderLight, Color(0.10, 0.15, 0.24, 1.0)],
		[ImGui.Col_TableRowBg, Color(0.0, 0.0, 0.0, 0.0)],
		[ImGui.Col_TableRowBgAlt, Color(1.0, 1.0, 1.0, 0.03)],
	]

	for entry in colors:
		ImGui.PushStyleColorImVec4(entry[0], entry[1])

	_pushed_colors = colors.size()

	var scalars: Array = [
		[ImGui.StyleVar_WindowRounding, 0.0],
		[ImGui.StyleVar_WindowBorderSize, 1.0],
		[ImGui.StyleVar_FrameRounding, 2.0],
		[ImGui.StyleVar_GrabRounding, 2.0],
		[ImGui.StyleVar_TabRounding, 2.0],
		[ImGui.StyleVar_ScrollbarRounding, 2.0],
	]

	for entry in scalars:
		ImGui.PushStyleVar(entry[0], entry[1])

	var vectors: Array = [
		[ImGui.StyleVar_WindowPadding, Vector2(8.0, 6.0)],
		[ImGui.StyleVar_FramePadding, Vector2(6.0, 3.0)],
		[ImGui.StyleVar_ItemSpacing, Vector2(8.0, 4.0)],
		[ImGui.StyleVar_CellPadding, Vector2(6.0, 2.0)],
	]

	for entry in vectors:
		ImGui.PushStyleVarImVec2(entry[0], entry[1])

	_pushed_vars = scalars.size() + vectors.size()


static func pop() -> void:
	ImGui.PopStyleVarEx(_pushed_vars)
	ImGui.PopStyleColorEx(_pushed_colors)
