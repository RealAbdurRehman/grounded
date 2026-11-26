class_name DashIcons
extends RefCounted

enum Icon {
	ENGINE,
	TEMPERATURE,
	OIL,
	BRAKES,
	STEERING,
	GEARBOX,
	AXLE,
	SUSPENSION,
	TIRE,
}

const SIZE_SCALE: float = 1.8
const SEGMENTS: int = 20


static func draw(kind: Icon, color: Color) -> void:
	var size: float = ImGui.GetFontSize() * SIZE_SCALE
	var origin: Vector2 = ImGui.GetCursorScreenPos()
	ImGui.Dummy(Vector2(size, size))

	var list = ImGui.GetWindowDrawList()
	var lit: bool = color != UITheme.DIM
	var back: Color = Color(color.r, color.g, color.b, 0.2) if lit else Color(1.0, 1.0, 1.0, 0.04)

	ImGui.ImDrawList_AddRectFilledEx(list, origin, origin + Vector2(size, size), back, 4.0, 0)

	var width: float = maxf(size * 0.065, 1.2)
	var at := Transform2D(0.0, Vector2(size, size), 0.0, origin)

	match kind:
		Icon.ENGINE:
			_engine(list, at, color, width)
		Icon.TEMPERATURE:
			_temperature(list, at, color, width, size)
		Icon.OIL:
			_oil(list, at, color, width, size)
		Icon.BRAKES:
			_brakes(list, at, color, width, size)
		Icon.STEERING:
			_steering(list, at, color, width, size)
		Icon.GEARBOX:
			_gearbox(list, at, color, width, size)
		Icon.AXLE:
			_axle(list, at, color, width, size)
		Icon.SUSPENSION:
			_suspension(list, at, color, width)
		Icon.TIRE:
			_tire(list, at, color, width, size)


static func _engine(list, at: Transform2D, color: Color, width: float) -> void:
	_path(
		list,
		at,
		[
			Vector2(0.22, 0.40),
			Vector2(0.34, 0.40),
			Vector2(0.41, 0.31),
			Vector2(0.63, 0.31),
			Vector2(0.70, 0.40),
			Vector2(0.77, 0.40),
			Vector2(0.77, 0.50),
			Vector2(0.83, 0.50),
			Vector2(0.83, 0.43),
			Vector2(0.90, 0.43),
			Vector2(0.90, 0.73),
			Vector2(0.83, 0.73),
			Vector2(0.83, 0.66),
			Vector2(0.77, 0.66),
			Vector2(0.77, 0.76),
			Vector2(0.40, 0.76),
			Vector2(0.30, 0.66),
			Vector2(0.22, 0.66),
			Vector2(0.22, 0.40),
		],
		color,
		width,
	)

	_path(list, at, [Vector2(0.10, 0.44), Vector2(0.10, 0.68)], color, width)
	_path(list, at, [Vector2(0.10, 0.56), Vector2(0.22, 0.56)], color, width)
	_path(list, at, [Vector2(0.52, 0.31), Vector2(0.52, 0.21)], color, width)
	_path(list, at, [Vector2(0.40, 0.21), Vector2(0.64, 0.21)], color, width)


static func _temperature(list, at: Transform2D, color: Color, width: float, size: float) -> void:
	_path(list, at, [Vector2(0.45, 0.14), Vector2(0.45, 0.62)], color, width * 1.6)
	_dot(list, at, Vector2(0.45, 0.65), 0.11 * size, color)

	for height in [0.18, 0.31, 0.44]:
		_path(list, at, [Vector2(0.48, height), Vector2(0.66, height)], color, width)

	_path(
		list,
		at,
		[
			Vector2(0.12, 0.87),
			Vector2(0.24, 0.81),
			Vector2(0.37, 0.87),
			Vector2(0.50, 0.81),
			Vector2(0.63, 0.87),
			Vector2(0.76, 0.81),
			Vector2(0.88, 0.87),
		],
		color,
		width,
	)


static func _oil(list, at: Transform2D, color: Color, width: float, size: float) -> void:
	_path(
		list,
		at,
		[
			Vector2(0.20, 0.46),
			Vector2(0.62, 0.46),
			Vector2(0.62, 0.72),
			Vector2(0.32, 0.72),
			Vector2(0.20, 0.58),
			Vector2(0.20, 0.46),
		],
		color,
		width,
	)

	_path(list, at, [Vector2(0.62, 0.55), Vector2(0.90, 0.36)], color, width)
	_path(list, at, [Vector2(0.20, 0.50), Vector2(0.08, 0.40)], color, width)
	_path(
		list,
		at,
		[Vector2(0.32, 0.46), Vector2(0.32, 0.34), Vector2(0.50, 0.34), Vector2(0.50, 0.46)],
		color,
		width,
	)

	_dot(list, at, Vector2(0.88, 0.58), 0.055 * size, color)


static func _brakes(list, at: Transform2D, color: Color, width: float, size: float) -> void:
	_ring(list, at, Vector2(0.5, 0.5), 0.27 * size, color, width)
	_arc(list, at, Vector2(0.5, 0.5), 0.41 * size, 140.0, 220.0, color, width)
	_arc(list, at, Vector2(0.5, 0.5), 0.41 * size, -40.0, 40.0, color, width)
	_path(list, at, [Vector2(0.5, 0.35), Vector2(0.5, 0.54)], color, width * 1.4)
	_dot(list, at, Vector2(0.5, 0.65), width * 0.9, color)


static func _steering(list, at: Transform2D, color: Color, width: float, size: float) -> void:
	_ring(list, at, Vector2(0.5, 0.5), 0.36 * size, color, width * 1.4)
	_dot(list, at, Vector2(0.5, 0.52), 0.09 * size, color)
	_path(list, at, [Vector2(0.15, 0.46), Vector2(0.5, 0.52), Vector2(0.85, 0.46)], color, width)
	_path(list, at, [Vector2(0.5, 0.52), Vector2(0.5, 0.86)], color, width)


static func _gearbox(list, at: Transform2D, color: Color, width: float, size: float) -> void:
	for across in [0.24, 0.50, 0.76]:
		_path(list, at, [Vector2(across, 0.26), Vector2(across, 0.74)], color, width)
		_dot(list, at, Vector2(across, 0.24), 0.07 * size, color)
		_dot(list, at, Vector2(across, 0.76), 0.07 * size, color)

	_path(list, at, [Vector2(0.24, 0.50), Vector2(0.76, 0.50)], color, width)


static func _axle(list, at: Transform2D, color: Color, width: float, size: float) -> void:
	for left in [0.08, 0.78]:
		ImGui.ImDrawList_AddRectFilledEx(
			list,
			at * Vector2(left, 0.24),
			at * Vector2(left + 0.14, 0.76),
			color,
			2.0,
			0,
		)

	_path(list, at, [Vector2(0.22, 0.50), Vector2(0.78, 0.50)], color, width * 1.3)
	_dot(list, at, Vector2(0.5, 0.5), 0.12 * size, color)


static func _suspension(list, at: Transform2D, color: Color, width: float) -> void:
	_path(list, at, [Vector2(0.28, 0.13), Vector2(0.72, 0.13)], color, width * 1.4)
	_path(
		list,
		at,
		[
			Vector2(0.50, 0.13),
			Vector2(0.50, 0.20),
			Vector2(0.69, 0.28),
			Vector2(0.31, 0.39),
			Vector2(0.69, 0.50),
			Vector2(0.31, 0.61),
			Vector2(0.69, 0.72),
			Vector2(0.50, 0.80),
			Vector2(0.50, 0.87),
		],
		color,
		width,
	)
	_path(list, at, [Vector2(0.28, 0.87), Vector2(0.72, 0.87)], color, width * 1.4)


static func _tire(list, at: Transform2D, color: Color, width: float, size: float) -> void:
	_arc(list, at, Vector2(0.5, 0.46), 0.33 * size, 125.0, 415.0, color, width * 1.3)
	_path(list, at, [Vector2(0.20, 0.85), Vector2(0.80, 0.85)], color, width)

	for across in [0.32, 0.50, 0.68]:
		_path(list, at, [Vector2(across, 0.85), Vector2(across, 0.76)], color, width)

	_path(list, at, [Vector2(0.5, 0.27), Vector2(0.5, 0.49)], color, width * 1.4)
	_dot(list, at, Vector2(0.5, 0.61), width * 0.9, color)


static func _path(list, at: Transform2D, points: Array, color: Color, width: float) -> void:
	for i in range(points.size() - 1):
		ImGui.ImDrawList_AddLineEx(list, at * points[i], at * points[i + 1], color, width)


static func _dot(list, at: Transform2D, center: Vector2, radius: float, color: Color) -> void:
	ImGui.ImDrawList_AddCircleFilled(list, at * center, radius, color, SEGMENTS)


static func _ring(
	list,
	at: Transform2D,
	center: Vector2,
	radius: float,
	color: Color,
	width: float,
) -> void:
	ImGui.ImDrawList_AddCircleEx(list, at * center, radius, color, SEGMENTS, width)


static func _arc(
	list,
	at: Transform2D,
	center: Vector2,
	radius: float,
	from_deg: float,
	to_deg: float,
	color: Color,
	width: float,
) -> void:
	var middle: Vector2 = at * center
	var previous: Vector2 = middle + Vector2.from_angle(deg_to_rad(from_deg)) * radius

	for i in range(1, SEGMENTS + 1):
		var angle: float = deg_to_rad(lerpf(from_deg, to_deg, float(i) / SEGMENTS))
		var next: Vector2 = middle + Vector2.from_angle(angle) * radius

		ImGui.ImDrawList_AddLineEx(list, previous, next, color, width)
		previous = next
