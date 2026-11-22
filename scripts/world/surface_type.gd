class_name SurfaceType
extends Resource

const GROUP_PREFIX: String = "surface_"

static var _presets: Dictionary = { }
static var _by_body: Dictionary = { }

@export var label: String = "Asphalt"

@export_group("Grip")
## Grip compared to asphalt.
@export_range(0.05, 1.5, 0.01) var grip: float = 1.0

## Rolling resistance compared to asphalt.
@export_range(0.5, 40.0, 0.1) var rolling_resistance_scale: float = 1.0

## How much grip is lost when sliding.
@export_range(0.1, 2.0, 0.05) var slide_drop_scale: float = 1.0

@export_group("Roughness")
## Biggest change in height.
@export_range(0.0, 0.3, 0.005) var height_variation_m: float = 0.0

## Length of the longest bumps.
@export_range(0.3, 10.0, 0.1) var bump_length_m: float = 2.0

@export_group("Heat")
## How well heat transfers between the tire and the surface compared to asphalt.
@export_range(0.0, 3.0, 0.05) var heat_transfer_scale: float = 1.0

## How much the sun heats the surface compared to asphalt.
@export_range(0.0, 2.0, 0.05) var sun_heating_scale: float = 1.0

## How hot the surface can get.
@export_range(-30.0, 200.0, 1.0) var max_temperature_c: float = 200.0

@export_group("Water")
## How much of the water on the surface drains away.
@export_range(0.0, 1.0, 0.05) var drainage: float = 0.0

## Grip when wet compared to dry.
@export_range(0.05, 1.5, 0.01) var wet_grip_slow: float = 0.85
@export_range(0.05, 1.5, 0.01) var wet_grip_fast: float = 0.5

@export_range(0.05, 1.5, 0.01) var wet_smooth_slow: float = 0.7
@export_range(0.05, 1.5, 0.01) var wet_smooth_fast: float = 0.15

## How easily a tire hydroplanes.
@export_range(0.3, 2.0, 0.05) var hydroplane_scale: float = 1.0


func temperature_c(air: AirConfig) -> float:
	return minf(air.air_temperature_c + air.road_above_air_c * sun_heating_scale, max_temperature_c)


static func preset(key: StringName) -> SurfaceType:
	if _presets.is_empty():
		_build_presets()

	return _presets.get(key, _presets[&"asphalt"])


static func of_body(id: int) -> SurfaceType:
	if _by_body.has(id):
		return _by_body[id]

	var surface: SurfaceType = preset(&"asphalt")

	var body: Node = instance_from_id(id) as Node if id != 0 else null
	if body != null:
		for group in body.get_groups():
			var text: String = String(group)

			if text.begins_with(GROUP_PREFIX):
				surface = preset(StringName(text.substr(GROUP_PREFIX.length())))

				break

	if _by_body.size() > 512:
		_by_body.clear()

	_by_body[id] = surface

	return surface


static func _build_presets() -> void:
	_add(&"asphalt", "Asphalt", 1.0, 1.0, 0.0, 2.0, 1.0, 1.0, 200.0, 0.0, 0.85, 0.5, 0.7, 0.15, 1.0)
	_add(
		&"concrete",
		"Concrete",
		0.95,
		0.9,
		0.0,
		2.0,
		1.1,
		0.7,
		200.0,
		0.0,
		0.7,
		0.35,
		0.35,
		0.08,
		0.8,
	)

	_add(&"gravel", "Gravel", 0.85, 2.0, 0.02, 1.2, 0.5, 0.7, 200.0, 0.8, 0.9, 0.85, 0.6, 0.5, 1.2)
	_add(&"dirt", "Dirt", 0.9, 2.5, 0.04, 2.0, 0.5, 0.6, 200.0, 0.5, 0.6, 0.45, 0.5, 0.35, 0.6)
	_add(&"grass", "Grass", 0.8, 2.5, 0.03, 1.5, 0.3, 0.2, 200.0, 0.6, 0.6, 0.5, 0.5, 0.4, 0.7)
	_add(&"sand", "Sand", 0.75, 5.0, 0.03, 2.5, 0.4, 0.8, 200.0, 0.95, 1.05, 1.05, 1.0, 1.0, 1.0)
	_add(&"snow", "Snow", 0.25, 2.0, 0.02, 3.0, 0.3, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0)
	_add(&"ice", "Ice", 0.11, 1.0, 0.0, 2.0, 1.2, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0)

	_presets[&"gravel"].slide_drop_scale = 0.35
	_presets[&"dirt"].slide_drop_scale = 0.2
	_presets[&"grass"].slide_drop_scale = 0.35
	_presets[&"sand"].slide_drop_scale = 0.3
	_presets[&"snow"].slide_drop_scale = 1.3
	_presets[&"ice"].slide_drop_scale = 1.5


static func _add(
	key: StringName,
	label_text: String,
	grip_value: float,
	rolling: float,
	variation: float,
	bump_length: float,
	heat: float,
	sun: float,
	hottest: float,
	drain: float,
	wet_slow: float,
	wet_fast: float,
	smooth_slow: float,
	smooth_fast: float,
	hydroplane: float,
) -> void:
	var surface := SurfaceType.new()
	surface.label = label_text

	surface.grip = grip_value
	surface.rolling_resistance_scale = rolling

	surface.height_variation_m = variation
	surface.bump_length_m = bump_length

	surface.heat_transfer_scale = heat
	surface.sun_heating_scale = sun
	surface.max_temperature_c = hottest

	surface.drainage = drain

	surface.wet_grip_slow = wet_slow
	surface.wet_grip_fast = wet_fast

	surface.wet_smooth_slow = smooth_slow
	surface.wet_smooth_fast = smooth_fast

	surface.hydroplane_scale = hydroplane

	_presets[key] = surface
