class_name GaragePanel
extends DebugPanel

const KW_TO_HP: float = 1.341

var _cars: Array[PackedScene] = []
var _labels: Array[String] = []


func _build() -> void:
	Garage.start = vehicle.global_transform

	for path in Garage.CARS:
		var scene := load(path) as PackedScene
		var car := scene.instantiate() as Vehicle

		_cars.append(scene)
		_labels.append(_label(car))

		car.free()


func draw() -> void:
	for i in range(_cars.size()):
		ImGui.BeginDisabled(_cars[i].resource_path == vehicle.scene_file_path)

		if ImGui.ButtonEx(_labels[i], Vector2(-1.0, 0.0)):
			_switch.call_deferred(_cars[i])

		ImGui.EndDisabled()


func _switch(scene: PackedScene) -> void:
	Garage.switch_to(vehicle, scene)


func _label(car: Vehicle) -> String:
	var definition: CarDefinition = (car.get_node(^"Body") as CarBody).definition
	var drivetrain := car.get_node(^"Drivetrain") as Drivetrain

	var front: bool = (car.get_node(^"Wheels/WheelFL") as Wheel).is_driven
	var rear: bool = (car.get_node(^"Wheels/WheelRL") as Wheel).is_driven

	var drive: String = "RWD"
	if front:
		drive = "AWD" if rear else "FWD"

	var gearbox: String = "manual"
	if drivetrain.transmission_type == Drivetrain.TransmissionType.AUTOMATIC:
		gearbox = "automatic"

	return "%s\n%.0f hp   %.0f kg   %s   %s" % [
		definition.car_name,
		_peak_hp(car.get_node(^"Engine") as VehicleEngine),
		car.config.vehicle_mass,
		drive,
		gearbox,
	]


func _peak_hp(engine: VehicleEngine) -> float:
	var most: float = 0.0
	for rpm in range(int(engine.config.idle_rpm), int(engine.config.rev_limiter_rpm) + 1, 100):
		most = maxf(most, engine.calculate_power_kw(rpm))

	return most * KW_TO_HP
