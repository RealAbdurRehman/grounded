class_name BalanceTab
extends DebugPanel


func draw() -> void:
	fit_begin()

	_diagram()
	_loads()
	_balance()
	_transfer()
	_attitude()

	fit_end()


func _diagram() -> void:
	var unit: float = ImGui.GetFontSize()
	var width: float = ImGui.GetContentRegionAvail().x

	var loads: Array = []
	var usage: Array = []

	var total: float = 0.0
	var front: float = 0.0
	var left: float = 0.0

	for i in range(4):
		var load_n: float = weight_transfer.measured[i]

		loads.append(load_n)
		usage.append(grip_usage(i))

		total += load_n
		if i < 2:
			front += load_n
		if i % 2 == 0:
			left += load_n

	total = maxf(total, 1.0)

	Widgets.plot_title("Load on each wheel and where the weight sits")
	Plots.car_diagram(fit(1.0, unit * 12.0, width * 1.2), loads, usage, front / total, left / total)

	Widgets.gap(0.3)


func _loads() -> void:
	var measured_sum: float = 0.0
	var predicted_sum: float = 0.0
	for i in range(4):
		measured_sum += weight_transfer.measured[i]
		predicted_sum += weight_transfer.predicted[i]

	Widgets.wheel_table(
		"load_table",
		["Load N", "Predicted", "Error", ["Travel", 1.4]],
		func(i: int) -> Array:
			var measured: float = weight_transfer.measured[i]
			var predicted: float = weight_transfer.predicted[i]
			var travel: float = telemetry.wheels[i].compression

			return [
				"%.0f" % measured,
				"%.0f" % predicted,
				[
					"%+.0f" % (measured - predicted),
					Widgets.error_color(measured - predicted, measured),
				],
				{ "fraction": travel, "text": "%.0f%%" % (travel * 100.0), "color": UITheme.ACCENT },
			],
	)

	var error: float = measured_sum - predicted_sum
	Widgets.key_value(
		"Total",
		"%.0f N  (%+.0f vs predicted)" % [measured_sum, error],
		Widgets.error_color(error, measured_sum),
	)


func _balance() -> void:
	var measured: PackedFloat32Array = weight_transfer.measured
	var total: float = maxf(measured[0] + measured[1] + measured[2] + measured[3], 1.0)

	var front: float = (measured[0] + measured[1]) / total
	var left: float = (measured[0] + measured[2]) / total

	ImGui.SeparatorText("Balance")
	Widgets.labeled_bar(
		"F / R",
		front,
		"%.0f / %.0f %%" % [front * 100.0, (1.0 - front) * 100.0],
		UITheme.ACCENT,
	)
	Widgets.labeled_bar(
		"L / R",
		left,
		"%.0f / %.0f %%" % [left * 100.0, (1.0 - left) * 100.0],
		Color(0.9, 0.7, 0.2),
	)


func _transfer() -> void:
	ImGui.SeparatorText("Weight transfer")
	Widgets.key_value("Longitudinal", "%+.2f g" % (weight_transfer.accel_long / 9.81))
	Widgets.key_value("Lateral", "%+.2f g" % (weight_transfer.accel_lat / 9.81))
	Widgets.key_value(
		"Roll (measured / predicted)",
		"%.2f / %.2f deg" % [absf(weight_transfer.roll_meas_deg), weight_transfer.roll_pred_deg],
	)
	Widgets.key_value("Front roll stiffness", "%.0f%%" % (weight_transfer.front_roll_share * 100.0))
	Widgets.key_value("Lift-off oversteer at", "%.2f g" % weight_transfer.lift_off_g)

	if Widgets.section("Geometry", true):
		Widgets.key_value("Center of gravity", "%.2f m high" % weight_transfer.cg_height)
		Widgets.key_value("Wheelbase", "%.2f m" % weight_transfer.wheelbase)
		Widgets.key_value(
			"Track (front / rear)",
			"%.2f / %.2f m" % [weight_transfer.track_front, weight_transfer.track_rear],
		)


func _attitude() -> void:
	var basis: Basis = vehicle.global_transform.basis.orthonormalized()

	ImGui.SeparatorText("Attitude")
	Widgets.key_value("Roll", "%.1f deg" % rad_to_deg(asin(clampf(basis.x.y, -1.0, 1.0))))
	Widgets.key_value("Pitch", "%.1f deg" % rad_to_deg(asin(clampf(-basis.z.y, -1.0, 1.0))))
	Widgets.key_value("Heading", "%.1f deg" % rad_to_deg(atan2(-basis.z.x, -basis.z.z)))
