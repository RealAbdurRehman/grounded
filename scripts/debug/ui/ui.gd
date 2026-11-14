class_name UI
extends Node

@export var vehicle: Vehicle
@export var telemetry: Telemetry
@export var weight_transfer: WeightTransfer

@export var enabled: bool = true

var _visible: bool = true
var _locked: bool = true
var _reset_layout: bool = false

var _locked_flag: Array = [true]
var _show_vectors: Array = [true]
var _time_scale: Array = [1.0]

var _ui_scale: float = 1.0
var _ui_scale_edit: Array = [1.0]

var _display: Vector2 = Vector2.ZERO
var _left_w: float = 0.0
var _right_w: float = 0.0
var _bar_h: float = 0.0

var _dashboard: VehiclePanel
var _tabs: Array = []


func _ready() -> void:
	process_priority = 100

	await get_tree().physics_frame

	_dashboard = VehiclePanel.new(vehicle, telemetry, weight_transfer)

	_tabs = [
		["Tires", TiresTab.new(vehicle, telemetry, weight_transfer)],
		["Engine", EngineTab.new(vehicle, telemetry, weight_transfer)],
		["Drive", DrivetrainTab.new(vehicle, telemetry, weight_transfer)],
		["Chassis", ChassisTab.new(vehicle, telemetry, weight_transfer)],
		["Assists", AssistsTab.new(vehicle, telemetry, weight_transfer)],
	]

	if weight_transfer != null:
		_tabs.append(["Balance", BalanceTab.new(vehicle, telemetry, weight_transfer)])


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_visible = not _visible


func _process(delta: float) -> void:
	if not enabled or _dashboard == null:
		return

	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
	_dashboard.update(real_delta)

	for tab in _tabs:
		tab[1].update(real_delta)

	if not _visible:
		return

	ImGui.GetIO().FontGlobalScale = _ui_scale

	DebugDraw3D.enabled = _show_vectors[0]
	Engine.time_scale = _time_scale[0]

	UITheme.push()

	_update_layout()
	_draw_toolbar()
	_draw_dashboard()
	_draw_tuning()

	UITheme.pop()

	_locked = _locked_flag[0]
	_reset_layout = false


func _update_layout() -> void:
	var unit: float = ImGui.GetFontSize()
	_display = ImGui.GetIO().DisplaySize

	_left_w = clampf(_display.x * 0.175, unit * 22.0, unit * 28.0)
	_right_w = clampf(_display.x * 0.225, unit * 30.0, unit * 34.0)
	_bar_h = unit * 2.9


func _begin_panel(title: String, rect: Rect2, extra_flags: int = 0) -> bool:
	var flags: int = extra_flags

	if _locked:
		ImGui.SetNextWindowPos(rect.position, ImGui.Cond_Always)
		ImGui.SetNextWindowSize(rect.size, ImGui.Cond_Always)

		flags |= (
			ImGui.WindowFlags_NoMove | ImGui.WindowFlags_NoResize | ImGui.WindowFlags_NoCollapse
			| ImGui.WindowFlags_NoSavedSettings | ImGui.WindowFlags_NoDocking
		)
	else:
		var condition: int = ImGui.Cond_Always if _reset_layout else ImGui.Cond_FirstUseEver
		ImGui.SetNextWindowPos(rect.position, condition)
		ImGui.SetNextWindowSize(rect.size, condition)

	return ImGui.Begin(title, [], flags)


func _draw_toolbar() -> void:
	var width: float = maxf(_display.x - _left_w - _right_w, 100.0)
	var rect := Rect2(_left_w, _display.y - _bar_h, width, _bar_h)

	if _begin_panel("Toolbar", rect, ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoTitleBar):
		var unit: float = ImGui.GetFontSize()

		ImGui.AlignTextToFramePadding()
		ImGui.TextColored(UITheme.ACCENT, "GROUNDED")

		_toolbar_divider()
		ImGui.Checkbox("Force vectors", _show_vectors)
		ImGui.SameLine()
		ImGui.Checkbox("Lock layout", _locked_flag)

		_toolbar_divider()
		ImGui.TextDisabled("Time")
		ImGui.SameLine()
		ImGui.SetNextItemWidth(unit * 7.0)
		ImGui.SliderFloatEx("##time_scale", _time_scale, 0.05, 1.0, "%.2fx", 0)

		_toolbar_divider()
		ImGui.TextDisabled("UI scale")
		ImGui.SameLine()
		ImGui.SetNextItemWidth(unit * 6.0)
		ImGui.SliderFloatEx("##ui_scale", _ui_scale_edit, 0.8, 1.4, "%.2f", 0)
		if ImGui.IsItemDeactivatedAfterEdit():
			_ui_scale = _ui_scale_edit[0]

		ImGui.SameLine()
		if ImGui.Button("Reset layout"):
			_reset_layout = true

	ImGui.End()


## A thin separator between groups of toolbar controls.
func _toolbar_divider() -> void:
	ImGui.SameLineEx(0.0, ImGui.GetFontSize() * 0.9)
	ImGui.AlignTextToFramePadding()
	ImGui.TextDisabled("|")
	ImGui.SameLineEx(0.0, ImGui.GetFontSize() * 0.9)


func _draw_dashboard() -> void:
	if _begin_panel("Vehicle", Rect2(0.0, 0.0, _left_w, _display.y)):
		_dashboard.draw()

	ImGui.End()


func _draw_tuning() -> void:
	var rect := Rect2(_display.x - _right_w, 0.0, _right_w, _display.y)

	if _begin_panel("Tuning", rect) and ImGui.BeginTabBar("tuning_tabs"):
		for tab in _tabs:
			if ImGui.BeginTabItem(tab[0]):
				tab[1].draw()
				ImGui.EndTabItem()

		ImGui.EndTabBar()

	ImGui.End()
