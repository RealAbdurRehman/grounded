extends Control

var fx_norm: float = 0.0
var fy_norm: float = 0.0

func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = min(size.x, size.y) * 0.45

	draw_circle(center, radius, Color(0.1, 0.1, 0.1, 0.6))
	draw_arc(center, radius, 0, TAU, 32, Color.WHITE, 2.0)

	draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(0.4, 0.4, 0.4))
	draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(0.4, 0.4, 0.4))

	var dot_pos: Vector2 = center + Vector2(fy_norm, -fx_norm) * radius
	var dot_color: Color = Color.GREEN if Vector2(fx_norm, fy_norm).length() <= 1.0 else Color.RED

	draw_circle(dot_pos, 5.0, dot_color)
	draw_line(center, dot_pos, dot_color, 1.5)
