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

@export_group("Mounts")
@export var mount_words: Array[String] = []

@export var hinge_edge: Vector3 = Vector3.BACK
@export var hinge_axis: Vector3 = Vector3.RIGHT
@export var hinge_nudge_m: Vector3 = Vector3.ZERO

@export var clips_along: Vector3 = Vector3.RIGHT
@export_range(2, 6) var clip_count: int = 3

@export var hinge_grip_mps: float = 22.0
@export var latch_grip_mps: float = 8.0

@export_group("Loose panel")
@export var mass_kg: float = 12.0

@export var open_direction: Vector3 = Vector3.UP
@export_range(0.0, 90.0, 0.5) var open_limit_deg: float = 55.0

@export_range(0.0, 85.0, 0.5) var swing_front_deg: float = 40.0
@export_range(0.0, 85.0, 0.5) var swing_back_deg: float = 0.0
@export_range(0.0, 20.0, 0.1) var swing_damping: float = 1.0

@export_range(0.0, 45.0, 0.5) var jam_deg: float = 0.0

@export_group("Damage")
@export var reach_m: Vector3 = Vector3(0.5, 0.5, 0.5)

@export var load_direction: Vector3 = Vector3.ZERO
@export_range(0.0, 1.0, 0.05) var load_floor: float = 1.0

@export var break_mps: float = 11.0

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


func holds_mounts(node: Node) -> bool:
	var text: String = String(node.name) + "|" + String(node.get_parent().name)

	for word in mount_words:
		if text.contains(word):
			return true

	return false


static func defaults() -> Array[CarPanel]:
	var list: Array[CarPanel] = []

	var from_left := Vector3.RIGHT
	var from_right := Vector3.LEFT

	var from_front := Vector3.BACK
	var from_rear := Vector3.FORWARD

	var hood: CarPanel = _hinged("Hood", ["HOOD"], Vector3.BACK, Vector3.RIGHT, Vector3.UP, 14.0)

	hood.open_limit_deg = 55.0
	hood.jam_deg = 12.0
	hood.latch_grip_mps = 14.0
	hood.hinge_grip_mps = 36.0
	hood.reach_m = Vector3(1.0, 0.8, 1.6)
	hood.load_direction = from_front
	hood.load_floor = 0.1

	list.append(hood)

	var boot: CarPanel = _hinged("Boot", ["BOOT"], Vector3.FORWARD, Vector3.RIGHT, Vector3.UP, 12.0)

	boot.open_limit_deg = 55.0
	boot.jam_deg = 10.0
	boot.latch_grip_mps = 17.0
	boot.hinge_grip_mps = 38.0
	boot.reach_m = Vector3(0.9, 0.8, 1.2)
	boot.load_direction = from_rear
	boot.load_floor = 0.1

	list.append(boot)

	var spoiler: CarPanel = _hanging("Spoiler", ["SPOILER"], 2, Vector3(0.0, 1.0, 0.3), 5.0)

	spoiler.swing_front_deg = 50.0
	spoiler.open_limit_deg = 30.0
	spoiler.latch_grip_mps = 12.0
	spoiler.reach_m = Vector3(0.8, 0.6, 0.8)
	spoiler.load_direction = from_rear
	spoiler.load_floor = 0.3

	list.append(spoiler)

	var front_bumper: CarPanel = _hanging(
		"Front Bumper",
		["FRONTBUMPER"],
		3,
		Vector3(0.0, -0.4, -1.0),
		11.0,
	)

	front_bumper.open_limit_deg = 25.0
	front_bumper.swing_front_deg = 10.0
	front_bumper.latch_grip_mps = 16.0
	front_bumper.reach_m = Vector3(1.1, 0.9, 1.0)
	front_bumper.load_direction = from_front
	front_bumper.load_floor = 0.3

	list.append(front_bumper)

	var rear_bumper: CarPanel = _hanging(
		"Rear Bumper",
		["REARBUMPER"],
		3,
		Vector3(0.0, -0.4, 1.0),
		11.0,
	)

	rear_bumper.open_limit_deg = 25.0
	rear_bumper.swing_front_deg = 10.0
	rear_bumper.latch_grip_mps = 16.0
	rear_bumper.reach_m = Vector3(1.1, 0.9, 1.0)
	rear_bumper.load_direction = from_rear
	rear_bumper.load_floor = 0.3

	list.append(rear_bumper)

	var door_left: CarPanel = _hinged(
		"Door Left",
		["DOOR_LEFT", "GLASS_LEFT_mm"],
		Vector3.FORWARD,
		Vector3.UP,
		Vector3.LEFT,
		22.0,
	)

	door_left.open_limit_deg = 70.0
	door_left.swing_front_deg = 40.0
	door_left.jam_deg = 6.0
	door_left.latch_grip_mps = 11.0
	door_left.hinge_grip_mps = 34.0
	door_left.reach_m = Vector3(0.6, 0.8, 1.2)
	door_left.load_direction = from_left
	door_left.load_floor = 0.1

	list.append(door_left)

	var door_right: CarPanel = _hinged(
		"Door Right",
		["DOOR_RIGHT", "GLASS_RIGHT_mm"],
		Vector3.FORWARD,
		Vector3.UP,
		Vector3.RIGHT,
		22.0,
	)

	door_right.open_limit_deg = 70.0
	door_right.swing_front_deg = 40.0
	door_right.jam_deg = 6.0
	door_right.latch_grip_mps = 11.0
	door_right.hinge_grip_mps = 34.0
	door_right.reach_m = Vector3(0.6, 0.8, 1.2)
	door_right.load_direction = from_right
	door_right.load_floor = 0.1

	list.append(door_right)

	var mirror_left: CarPanel = _hinged(
		"Mirror Left",
		["MIRROR_LEFT", "MIRROR_GLASS_LEFT"],
		Vector3.RIGHT,
		Vector3.UP,
		Vector3.BACK,
		1.5,
	)

	mirror_left.open_limit_deg = 85.0
	mirror_left.swing_front_deg = 40.0
	mirror_left.latch_grip_mps = 2.0
	mirror_left.hinge_grip_mps = 6.0
	mirror_left.swing_damping = 5.0
	mirror_left.reach_m = Vector3(0.5, 0.7, 1.1)
	mirror_left.load_direction = from_left
	mirror_left.load_floor = 0.6
	mirror_left.touch_piece = "MirrorLeft"
	mirror_left.touch_limit_ns = 1.5

	list.append(mirror_left)

	var mirror_right: CarPanel = _hinged(
		"Mirror Right",
		["MIRROR_RIGHT", "MIRROR_GLASS_RIGHT"],
		Vector3.LEFT,
		Vector3.UP,
		Vector3.BACK,
		1.5,
	)

	mirror_right.open_limit_deg = 85.0
	mirror_right.swing_front_deg = 40.0
	mirror_right.latch_grip_mps = 2.0
	mirror_right.hinge_grip_mps = 6.0
	mirror_right.swing_damping = 5.0
	mirror_right.reach_m = Vector3(0.5, 0.7, 1.1)
	mirror_right.load_direction = from_right
	mirror_right.load_floor = 0.6
	mirror_right.touch_piece = "MirrorRight"
	mirror_right.touch_limit_ns = 1.5

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
	new_hinge_edge: Vector3,
	new_hinge_axis: Vector3,
	new_open_direction: Vector3,
	new_mass_kg: float,
) -> CarPanel:
	var panel := CarPanel.new()

	panel.panel_name = new_name
	panel.words = new_words

	panel.hinge_edge = new_hinge_edge
	panel.hinge_axis = new_hinge_axis
	panel.open_direction = new_open_direction
	panel.mass_kg = new_mass_kg

	return panel


static func _hanging(
	new_name: String,
	new_words: Array[String],
	new_clip_count: int,
	new_open_direction: Vector3,
	new_mass_kg: float,
) -> CarPanel:
	var panel := CarPanel.new()

	panel.panel_name = new_name
	panel.kind = Kind.HANGING
	panel.words = new_words

	panel.clip_count = new_clip_count
	panel.open_direction = new_open_direction
	panel.mass_kg = new_mass_kg

	return panel


static func _glass(
	new_name: String,
	new_words: Array[String],
	new_break_mps: float,
	reach: Vector3,
	new_load_direction: Vector3,
	new_load_floor: float,
) -> CarPanel:
	var panel := CarPanel.new()

	panel.panel_name = new_name
	panel.kind = Kind.GLASS
	panel.words = new_words

	panel.break_mps = new_break_mps

	panel.reach_m = reach
	panel.load_direction = new_load_direction
	panel.load_floor = new_load_floor

	return panel
