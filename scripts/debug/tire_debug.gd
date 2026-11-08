class_name TireDebug
extends Control

@export var target_vehicle: RigidBody3D

@export var smoothing: float = 15.0

var _wheels: Array = []
var _tire_model: Tire

var _graph_rect: Rect2 = Rect2(20, 20, 280, 160)
var _lat_graph_rect: Rect2 = Rect2(20, 200, 280, 160)

var _show_kappa: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _show_mu_x: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _show_alpha: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _show_mu_y: Array[float] = [0.0, 0.0, 0.0, 0.0]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_find_vehicle()


func _find_vehicle() -> void:
	var v: Vehicle = target_vehicle as Vehicle

	_wheels = [v.wheel_fl, v.wheel_fr, v.wheel_rl, v.wheel_rr]
	_tire_model = _wheels[0].tire_model


func _process(delta: float) -> void:
	if _wheels.is_empty():
		_find_vehicle()
		return

	var blend: float = 1.0 if smoothing <= 0.0 else 1.0 - exp(-smoothing * delta)
	for i in range(4):
		var w: Wheel = _wheels[i]
		var fz: float = maxf(w.suspension_force_n, 1.0)

		_show_kappa[i] = lerpf(_show_kappa[i], w.slip_ratio, blend)
		_show_mu_x[i] = lerpf(_show_mu_x[i], w.longitudinal_force_n / fz, blend)
		_show_alpha[i] = lerpf(_show_alpha[i], w.slip_angle_rad, blend)
		_show_mu_y[i] = lerpf(_show_mu_y[i], w.lateral_force_n / fz, blend)

	queue_redraw()


func _draw() -> void:
	if _wheels.is_empty() or _tire_model == null:
		return

	_draw_slip_ratio_curve()
	_draw_slip_angle_curve()
	_draw_slip_gauges()


func _draw_slip_ratio_curve() -> void:
	var r: Rect2 = _graph_rect

	draw_rect(r, Color(0.06, 0.07, 0.10, 0.88))
	draw_rect(r, Color(0.3, 0.35, 0.45), false, 1.5)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(r.position.x + 6, r.position.y + 14),
		"Fx/Fz vs Slip Ratio (κ)",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color(0.6, 0.7, 1.0),
	)

	var ref_fz: float = _tire_model.reference_load_n
	var max_slip: float = 0.5
	var max_mu_display: float = 1.4

	var center_x: float = r.position.x + r.size.x * 0.5
	draw_line(
		Vector2(center_x, r.position.y + 20),
		Vector2(center_x, r.end.y - 5),
		Color(0.3, 0.3, 0.35),
		1.0,
	)

	var center_y: float = r.position.y + (r.size.y - 20) * 0.5 + 20
	draw_line(
		Vector2(r.position.x + 5, center_y),
		Vector2(r.end.x - 5, center_y),
		Color(0.3, 0.3, 0.35),
		1.0,
	)

	var plot_h: float = (r.size.y - 25.0) * 0.5

	var peak_k: float = _tire_model.kappa_peak()
	for sgn in [-1.0, 1.0]:
		var peak_x: float = r.position.x + ((sgn * peak_k + max_slip) / (2.0 * max_slip)) * r.size.x
		draw_line(
			Vector2(peak_x, r.position.y + 20),
			Vector2(peak_x, r.end.y - 5),
			Color(0.3, 0.5, 0.3, 0.6),
			1.0,
		)

	var prev_pos := Vector2.ZERO
	for i in range(100):
		var t: float = float(i) / 99.0
		var kappa: float = lerpf(-max_slip, max_slip, t)

		var mu_x: float = _tire_model.compute_fx(kappa, ref_fz) / ref_fz
		var px: float = r.position.x + t * r.size.x
		var py: float = center_y - (mu_x / max_mu_display) * plot_h

		var cur_pos := Vector2(px, py)
		if i > 0:
			draw_line(prev_pos, cur_pos, Color(0.3, 0.8, 1.0), 2.0)

		prev_pos = cur_pos

	var colors: Array[Color] = [Color.YELLOW, Color.ORANGE, Color.CYAN, Color.MAGENTA]
	var names: Array[String] = ["FL", "FR", "RL", "RR"]
	for idx in range(4):
		var w: Wheel = _wheels[idx]
		if not w.is_grounded:
			continue

		var kappa_clamped: float = clampf(_show_kappa[idx], -max_slip, max_slip)
		var norm_x: float = (kappa_clamped + max_slip) / (2.0 * max_slip)

		var px: float = r.position.x + norm_x * r.size.x
		var py: float = center_y - (_show_mu_x[idx] / max_mu_display) * plot_h
		py = clampf(py, r.position.y + 5, r.end.y - 5)

		draw_circle(Vector2(px, py), 4.0, colors[idx])
		draw_string(
			ThemeDB.fallback_font,
			Vector2(px + 6, py + 4),
			names[idx],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			9,
			colors[idx],
		)


func _draw_slip_angle_curve() -> void:
	var r: Rect2 = _lat_graph_rect
	draw_rect(r, Color(0.06, 0.07, 0.10, 0.88))
	draw_rect(r, Color(0.3, 0.35, 0.45), false, 1.5)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(r.position.x + 6, r.position.y + 14),
		"Fy/Fz vs Slip Angle (α)",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color(1.0, 0.6, 0.6),
	)

	var ref_fz: float = _tire_model.reference_load_n
	var max_alpha_rad: float = deg_to_rad(20.0)
	var max_mu_display: float = 1.4

	var center_x: float = r.position.x + r.size.x * 0.5
	draw_line(
		Vector2(center_x, r.position.y + 20),
		Vector2(center_x, r.end.y - 5),
		Color(0.3, 0.3, 0.35),
		1.0,
	)

	var center_y: float = r.position.y + (r.size.y - 20) * 0.5 + 20
	draw_line(
		Vector2(r.position.x + 5, center_y),
		Vector2(r.end.x - 5, center_y),
		Color(0.3, 0.3, 0.35),
		1.0,
	)

	var plot_h: float = (r.size.y - 25.0) * 0.5

	var peak_a: float = _tire_model.alpha_peak()
	for sgn in [-1.0, 1.0]:
		var peak_x: float = r.position.x + ((sgn * peak_a + max_alpha_rad) / (2.0 * max_alpha_rad)) * r \
				.size \
				.x
		draw_line(
			Vector2(peak_x, r.position.y + 20),
			Vector2(peak_x, r.end.y - 5),
			Color(0.5, 0.3, 0.3, 0.6),
			1.0,
		)

	var prev_pos := Vector2.ZERO
	for i in range(100):
		var t: float = float(i) / 99.0
		var alpha: float = lerpf(-max_alpha_rad, max_alpha_rad, t)

		var mu_y: float = _tire_model.compute_fy(alpha, ref_fz) / ref_fz
		var px: float = r.position.x + t * r.size.x
		var py: float = center_y - (mu_y / max_mu_display) * plot_h

		var cur_pos := Vector2(px, py)
		if i > 0:
			draw_line(prev_pos, cur_pos, Color(1.0, 0.4, 0.4), 2.0)
		prev_pos = cur_pos

	var colors: Array[Color] = [Color.YELLOW, Color.ORANGE, Color.CYAN, Color.MAGENTA]
	var names: Array[String] = ["FL", "FR", "RL", "RR"]

	for idx in range(4):
		var w: Wheel = _wheels[idx]
		if not w.is_grounded:
			continue

		var alpha_clamped: float = clampf(_show_alpha[idx], -max_alpha_rad, max_alpha_rad)
		var norm_x: float = (alpha_clamped + max_alpha_rad) / (2.0 * max_alpha_rad)

		var px: float = r.position.x + norm_x * r.size.x
		var py: float = center_y - (_show_mu_y[idx] / max_mu_display) * plot_h
		py = clampf(py, r.position.y + 5, r.end.y - 5)

		draw_circle(Vector2(px, py), 4.0, colors[idx])
		draw_string(
			ThemeDB.fallback_font,
			Vector2(px + 6, py + 4),
			names[idx],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			9,
			colors[idx],
		)


func _draw_slip_gauges() -> void:
	var y_start: float = _lat_graph_rect.end.y + 15
	var x_start: float = _lat_graph_rect.position.x
	draw_string(
		ThemeDB.fallback_font,
		Vector2(x_start, y_start),
		"Wheel   κ (ratio)    α (deg)     Fx (N)      Fy (N)      Fz (N)",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		Color(0.7, 0.7, 0.75),
	)

	var names: Array[String] = ["FL", "FR", "RL", "RR"]
	for idx in range(4):
		var w: Wheel = _wheels[idx]
		var line_y: float = y_start + 14.0 * (idx + 1)

		var text: String = "  %s    %+6.3f      %+5.1f°     %+7.0f     %+7.0f     %6.0f" % [
			names[idx],
			w.slip_ratio,
			rad_to_deg(w.slip_angle_rad),
			w.longitudinal_force_n,
			w.lateral_force_n,
			w.suspension_force_n,
		]

		var color: Color = Color.WHITE
		if (
			abs(w.slip_ratio) > _tire_model.kappa_peak()
			or abs(w.slip_angle_rad) > _tire_model.alpha_peak()
		):
			color = Color(1.0, 0.5, 0.3)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x_start, line_y),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			color,
		)
