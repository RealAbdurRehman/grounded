class_name CarPanel
extends Resource

enum Kind {
	HINGED,
	HANGING,
	GLASS,
}

@export var panel_name: String = "Panel"

@export var kind: Kind = Kind.HINGED

@export var words: Array[String] = []
@export var except_words: Array[String] = []

@export_group("Split off")

@export var split_box: AABB = AABB()
@export var split_words: Array[String] = []

@export_group("Hinge")

@export var hinge_point: Vector3 = Vector3.ZERO
@export var hinge_axis: Vector3 = Vector3.RIGHT

@export var other_end_point: Vector3 = Vector3.ZERO

@export_range(0.0, 45.0, 0.5) var droop_deg: float = 0.0
@export_range(-90.0, 90.0, 0.5) var max_angle_deg: float = 10.0

@export_group("Damage")

@export var start_mps: float = 6.0
@export var full_mps: float = 16.0

@export var reach_m: Vector3 = Vector3(0.5, 0.5, 0.5)

@export var load_direction: Vector3 = Vector3.ZERO

@export_range(0.0, 1.0, 0.05) var load_floor: float = 1.0

@export var touch_piece: String = ""
@export var touch_limit_ns: float = 0.0


func matches(node: Node) -> bool:
	var text: String = String(node.name) + "|" + String(node.get_parent().name)

	for word in except_words:
		if text.contains(word):
			return false

	for word in words:
		if text.contains(word):
			return true

	return false


static func defaults() -> Array[CarPanel]:
	var list: Array[CarPanel] = []

	var from_left := Vector3.RIGHT
	var from_right := Vector3.LEFT

	var from_front := Vector3.BACK
	var from_rear := Vector3.FORWARD

	var hood: CarPanel = _hinged(
		"Hood",
		["HOOD"],
		[],
		Vector3(0.0, 0.55, -0.9),
		Vector3.RIGHT,
		7.0,
		8.0,
		20.0,
	)

	hood.reach_m = Vector3(1.0, 0.8, 1.0)
	hood.load_direction = from_front
	hood.load_floor = 0.1

	list.append(hood)

	var boot: CarPanel = _hinged(
		"Boot",
		["BOOT"],
		["_Spoiler"],
		Vector3(0.0, 0.62, 1.5),
		Vector3.RIGHT,
		-9.0,
		10.0,
		21.0,
	)

	boot.reach_m = Vector3(0.9, 0.8, 0.8)
	boot.load_direction = from_rear
	boot.load_floor = 0.1

	list.append(boot)

	var spoiler: CarPanel = _hinged(
		"Spoiler",
		["_Spoiler"],
		[],
		Vector3(0.0, 0.8, 1.9),
		Vector3.BACK,
		8.0,
		6.0,
		14.0,
	)

	spoiler.split_words = ["BOOT"]
	spoiler.split_box = AABB(Vector3(-0.8, 0.62, 1.5), Vector3(1.6, 0.5, 1.0))
	spoiler.reach_m = Vector3(0.6, 0.6, 0.6)
	spoiler.load_direction = from_rear
	spoiler.load_floor = 0.3

	list.append(spoiler)

	var front_bumper: CarPanel = _hanging(
		"Front Bumper",
		["FRONTBUMPER"],
		Vector3(-0.8, 0.1, -1.6),
		Vector3(0.8, 0.1, -1.6),
		4.0,
		3.0,
		9.0,
		22.0,
	)

	front_bumper.reach_m = Vector3(0.7, 0.6, 0.6)
	front_bumper.load_direction = from_front
	front_bumper.load_floor = 0.3

	list.append(front_bumper)

	var rear_bumper: CarPanel = _hanging(
		"Rear Bumper",
		["REARBUMPER"],
		Vector3(-0.8, 0.1, 1.6),
		Vector3(0.8, 0.1, 1.6),
		4.0,
		3.0,
		9.0,
		22.0,
	)

	rear_bumper.reach_m = Vector3(0.7, 0.6, 0.6)
	rear_bumper.load_direction = from_rear
	rear_bumper.load_floor = 0.3

	list.append(rear_bumper)

	var door_left: CarPanel = _hinged(
		"Door Left",
		["DOOR_LEFT", "GLASS_LEFT_mm"],
		[],
		Vector3(-0.75, 0.5, -0.83),
		Vector3.UP,
		-8.0,
		5.0,
		16.0,
	)

	door_left.reach_m = Vector3(0.5, 0.8, 0.9)
	door_left.load_direction = from_left
	door_left.load_floor = 0.1

	list.append(door_left)

	var door_right: CarPanel = _hinged(
		"Door Right",
		["DOOR_RIGHT", "GLASS_RIGHT_mm"],
		[],
		Vector3(0.75, 0.5, -0.83),
		Vector3.UP,
		8.0,
		5.0,
		16.0,
	)

	door_right.reach_m = Vector3(0.5, 0.8, 0.9)
	door_right.load_direction = from_right
	door_right.load_floor = 0.1

	list.append(door_right)

	var mirror_left: CarPanel = _hinged(
		"Mirror Left",
		["MIRROR_LEFT", "MIRROR_GLASS_LEFT"],
		[],
		Vector3(-0.76, 0.62, -0.58),
		Vector3.UP,
		65.0,
		2.0,
		4.0,
	)

	mirror_left.reach_m = Vector3(0.5, 0.7, 1.1)
	mirror_left.load_direction = from_left
	mirror_left.load_floor = 0.6
	mirror_left.touch_piece = "MirrorLeft"
	mirror_left.touch_limit_ns = 2.5

	list.append(mirror_left)

	var mirror_right: CarPanel = _hinged(
		"Mirror Right",
		["MIRROR_RIGHT", "MIRROR_GLASS_RIGHT"],
		[],
		Vector3(0.76, 0.62, -0.58),
		Vector3.UP,
		-65.0,
		2.0,
		4.0,
	)

	mirror_right.reach_m = Vector3(0.5, 0.7, 1.1)
	mirror_right.load_direction = from_right
	mirror_right.load_floor = 0.6
	mirror_right.touch_piece = "MirrorRight"
	mirror_right.touch_limit_ns = 2.5

	list.append(mirror_right)

	list.append(_glass("Rear Glass", ["GLASS_REAR"], 11.0, Vector3(0.9, 0.8, 0.8), from_rear, 0.3))

	list.append(
		_glass(
			"Quarter Glass Left",
			["GLASS_LEFT_QUARTER"],
			10.0,
			Vector3(0.5, 0.8, 0.9),
			from_left,
			0.2,
		)
	)

	list.append(
		_glass(
			"Quarter Glass Right",
			["GLASS_RIGHT_QUARTER"],
			10.0,
			Vector3(0.5, 0.8, 0.9),
			from_right,
			0.2,
		)
	)

	list.append(
		_glass("Door Glass Left", ["GLASS_LEFT_mm"], 11.0, Vector3(0.5, 0.8, 0.9), from_left, 0.2)
	)

	list.append(
		_glass(
			"Door Glass Right",
			["GLASS_RIGHT_mm"],
			11.0,
			Vector3(0.5, 0.8, 0.9),
			from_right,
			0.2,
		)
	)

	return list


static func _hinged(
	new_name: String,
	new_words: Array[String],
	new_except_words: Array[String],
	new_hinge_point: Vector3,
	new_hinge_axis: Vector3,
	new_max_angle_deg: float,
	new_start_mps: float,
	new_full_mps: float,
) -> CarPanel:
	var panel := CarPanel.new()

	panel.panel_name = new_name
	panel.words = new_words
	panel.except_words = new_except_words

	panel.hinge_point = new_hinge_point
	panel.hinge_axis = new_hinge_axis
	panel.max_angle_deg = new_max_angle_deg

	panel.start_mps = new_start_mps
	panel.full_mps = new_full_mps

	return panel


static func _hanging(
	new_name: String,
	new_words: Array[String],
	end_a: Vector3,
	end_b: Vector3,
	swing_deg: float,
	new_droop_deg: float,
	new_start_mps: float,
	new_full_mps: float,
) -> CarPanel:
	var panel := CarPanel.new()

	panel.panel_name = new_name
	panel.kind = Kind.HANGING
	panel.words = new_words

	panel.hinge_point = end_a
	panel.other_end_point = end_b
	panel.max_angle_deg = swing_deg
	panel.droop_deg = new_droop_deg

	panel.start_mps = new_start_mps
	panel.full_mps = new_full_mps

	return panel


static func _glass(
	new_name: String,
	new_words: Array[String],
	breaks_mps: float,
	reach: Vector3,
	new_load_direction: Vector3,
	new_load_floor: float,
) -> CarPanel:
	var panel := CarPanel.new()

	panel.panel_name = new_name
	panel.kind = Kind.GLASS
	panel.words = new_words

	panel.start_mps = breaks_mps
	panel.full_mps = breaks_mps

	panel.reach_m = reach
	panel.load_direction = new_load_direction
	panel.load_floor = new_load_floor

	return panel
