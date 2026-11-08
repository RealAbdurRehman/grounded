extends Control

@export_group("Smoothing")
@export var smoothing_speed: float = 15.0 

var fx_norm: float = 0.0
var fy_norm: float = 0.0

var _target_fx: float = 0.0
var _target_fy: float = 0.0

func _process(delta: float) -> void:
	fx_norm = lerp(fx_norm, _target_fx, delta * smoothing_speed)
	fy_norm = lerp(fy_norm, _target_fy, delta * smoothing_speed)
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = min(size.x, size.y) * 0.45

	draw_circle(center, radius, Color(0.1, 0.1, 0.1, 0.6))
	draw_arc(center, radius, 0, TAU, 32, Color.WHITE, 2.0)

	draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(0.4, 0.4, 0.4))
	draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(0.4, 0.4, 0.4))

	
	var draw_fx = clamp(fx_norm, -1.1, 1.1)
	var draw_fy = clamp(fy_norm, -1.1, 1.1)

	
	var dot_pos: Vector2 = center + Vector2(draw_fy, -draw_fx) * radius
	
	var total_length = Vector2(fx_norm, fy_norm).length()
	var dot_color: Color = Color.GREEN if total_length <= 1.0 else Color.RED

	draw_circle(dot_pos, 5.0, dot_color)
	draw_line(center, dot_pos, dot_color, 1.5)

func update_forces(longitudinal_force: float, lateral_force: float, max_grip_force: float) -> void:
	
	
	if max_grip_force > 100.0:
		_target_fx = longitudinal_force / max_grip_force
		_target_fy = lateral_force / max_grip_force
	else:
		_target_fx = 0.0
		_target_fy = 0.0
