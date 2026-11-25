class_name DamageTab
extends DebugPanel


func draw() -> void:
	var damage: CarDamage = vehicle.damage
	if damage == null:
		ImGui.TextWrapped("This car has no damage tracking.")
		return

	ImGui.SeparatorText("Hits")
	Widgets.key_value("Last hit", "%.1f m/s  (%s)" % [damage.last_delta_v, damage.last_part])
	Widgets.key_value("Hardest hit", "%.1f m/s" % damage.peak_delta_v)
	Widgets.tip(
		"How much each hit changed the car's speed. Under %.0f m/s is ignored."
		% CarDamage.MIN_DELTA_V_MPS
	)

	ImGui.SeparatorText("Parts")
	for part_name in damage.parts:
		var part: CarDamage.Part = damage.parts[part_name]

		Widgets.labeled_bar(
			part_name,
			part.damage,
			"%.0f%%  worst %.1f m/s  x%d" % [part.damage * 100.0, part.peak_delta_v, part.hits],
			Color(0.35, 0.85, 0.45).lerp(Color(1.0, 0.3, 0.2), part.damage),
		)

	var wheel_damage: WheelDamage = vehicle.wheel_damage
	if wheel_damage != null:
		ImGui.SeparatorText("Wheels")
		for state in wheel_damage.states:
			var label: String = state.wheel.label

			Widgets.key_value(
				label,
				"toe %+.1f  camber %+.1f  back %+.0f mm  sag %.0f mm  air %.0f%%"
				% [
					rad_to_deg(state.wheel.damage_toe_rad),
					rad_to_deg(state.wheel.damage_camber_rad),
					state.setback_m * 1000.0,
					state.sag_m * 1000.0,
					state.air * 100.0,
				],
			)

			if ImGui.Button("Burst " + label):
				wheel_damage.burst(state)

	Widgets.gap(0.5)
	if ImGui.Button("Repair all"):
		damage.reset()
