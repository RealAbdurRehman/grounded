class_name PerformanceSection
extends DebugPanel

const HISTORY_LENGTH: int = 150

var _fps_history: Array = []
var _frame_ms_history: Array = []


func update(_delta: float) -> void:
	_fps_history.append(Engine.get_frames_per_second())
	_frame_ms_history.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)

	if _fps_history.size() > HISTORY_LENGTH:
		_fps_history.pop_front()
		_frame_ms_history.pop_front()


func draw(chart_height: Callable = Callable()) -> void:
	if not Widgets.section("Performance", true):
		return

	var unit: float = ImGui.GetFontSize()
	var fps_height: float = unit * 2.6
	var frame_height: float = unit * 2.6

	if chart_height.is_valid():
		fps_height = chart_height.call()
		frame_height = chart_height.call()

	var fps: float = Engine.get_frames_per_second()
	var fps_color: Color = (
		UITheme.GOOD
		if fps >= 55.0
		else (UITheme.WARN if fps >= 30.0 else UITheme.BAD)
	)

	Plots.line_plot(
		"##fps",
		_fps_history,
		0.0,
		maxf(_max_of(_fps_history) * 1.2, 1.0),
		fps_height,
		fps_color,
		"FPS %.0f" % fps,
	)

	Plots.line_plot(
		"##frame_ms",
		_frame_ms_history,
		0.0,
		maxf(_max_of(_frame_ms_history) * 1.2, 1.0),
		frame_height,
		UITheme.ACCENT,
		"Frame %.2f ms" % _frame_ms_history.back(),
	)

	var process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0

	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var memory_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0

	Widgets.key_value("Process / physics", "%.2f / %.2f ms" % [process_ms, physics_ms])
	Widgets.key_value("Draw calls", "%d" % draw_calls)
	Widgets.key_value("Memory", "%.0f MB" % memory_mb)


func _max_of(values: Array) -> float:
	var result: float = 0.0
	for value in values:
		result = maxf(result, value)

	return result
