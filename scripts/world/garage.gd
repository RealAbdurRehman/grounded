class_name Garage
extends RefCounted

const CARS: Array[String] = [
	"res://scenes/vehicles/subaru/impreza.tscn",
	"res://scenes/vehicles/jeep/wrangler.tscn",
]

const DROP_M: float = 0.05


static func switch_to(old: Vehicle, scene: PackedScene) -> void:
	var world: Node = old.get_parent()
	var place: int = old.get_index()

	var from: Transform3D = old.global_transform
	var road: float = _road_under(old)

	var forward: Vector3 = -from.basis.z
	forward.y = 0.0
	if forward.length() < 0.1:
		forward = Vector3.FORWARD

	var car := scene.instantiate() as Vehicle
	var height: float = road - _ground_height(car) + DROP_M
	car.transform = Transform3D(
		Basis.looking_at(forward.normalized()),
		Vector3(from.origin.x, height, from.origin.z),
	)

	old.damage.reset()
	_retire(old)

	car.name = "Vehicle"
	world.add_child(car)
	world.move_child(car, place)

	world.get_tree().call_group("car_followers", "follow_car", car)


static func _retire(car: Vehicle) -> void:
	var tree: SceneTree = car.get_tree()

	car.name = "Retired"
	car.hide()
	car.process_mode = Node.PROCESS_MODE_DISABLED

	while is_instance_valid(car) and car.deformer != null and car.deformer.is_busy():
		await tree.process_frame

	if is_instance_valid(car):
		car.queue_free()


static func _road_under(car: Vehicle) -> float:
	var from: Vector3 = car.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(
		from,
		from + Vector3.DOWN * 50.0,
		1,
		[car.get_rid()],
	)

	var hit: Dictionary = car.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return car.global_position.y

	return hit["position"].y


static func _ground_height(car: Vehicle) -> float:
	var wheel := car.get_node(^"Wheels").get_child(0) as Wheel
	var suspension: SuspensionConfig = wheel.suspension_config

	var hub: float = (
		wheel.position.y - suspension.suspension_rest_length + suspension.alignment_compression
	)

	var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var load_n: float = car.config.vehicle_mass * 0.25 * gravity

	return hub - (suspension.wheel_radius - load_n / suspension.tire_stiffness)
