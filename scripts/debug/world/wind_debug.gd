class_name WindDebug
extends MeshInstance3D

const SHADER: Shader = preload("res://shaders/wind_debug.gdshader")

@export var cell_m: float = 5.0
@export var radius_m: float = 70.0

var target: Vehicle

var _material := ShaderMaterial.new()
var _ground_y: float = 0.0


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius_m * 2.0

	mesh = plane

	_material.shader = SHADER
	material_override = _material

	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	_follow_ground()
	global_position = Vector3(target.global_position.x, _ground_y + 0.05, target.global_position.z)

	var air: AirConfig = Atmosphere.config
	var waves: Dictionary = Atmosphere.wave_data()
	var gusts: Dictionary = Atmosphere.gust_data()

	_material.set_shader_parameter("u_time", Atmosphere.time_s)

	_material.set_shader_parameter("u_cell", cell_m)
	_material.set_shader_parameter("u_radius", radius_m)

	_material.set_shader_parameter("u_gust_scale", maxf(air.gust_peak_mps, 4.0))
	_material.set_shader_parameter(
		"u_speed_scale",
		maxf(air.wind_speed_mps + air.turbulence_mps * 2.0 + air.gust_peak_mps, 10.0),
	)

	_material.set_shader_parameter("u_center", Vector2(global_position.x, global_position.z))

	_material.set_shader_parameter("u_mean", Atmosphere.mean_wind())
	_material.set_shader_parameter("u_direction", Atmosphere.wind_direction())

	_material.set_shader_parameter("u_waves", waves.waves)
	_material.set_shader_parameter("u_strengths", waves.strengths)

	_material.set_shader_parameter("u_gust_starts", gusts.starts)
	_material.set_shader_parameter("u_gust_shapes", gusts.shapes)

	_material.set_shader_parameter("u_gust_times", gusts.times)


func _follow_ground() -> void:
	var lowest: float = INF
	for wheel in [target.wheel_fl, target.wheel_fr, target.wheel_rl, target.wheel_rr]:
		if wheel.is_grounded:
			lowest = minf(lowest, wheel.contact_point.y)

	if lowest < INF:
		_ground_y = lowest
	elif _ground_y == 0.0:
		_ground_y = target.global_position.y
