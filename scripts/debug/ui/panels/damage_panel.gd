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

			if state.torn:
				Widgets.key_value(label, "torn off")
			else:
				Widgets.key_value(
					label,
					"toe %+.1f  camber %+.1f  back %+.0f mm  sag %.0f mm  air %.0f%%  pull %.1f  stop %.1f m/s"
					% [
						rad_to_deg(state.wheel.damage_toe_rad),
						rad_to_deg(state.wheel.damage_camber_rad),
						state.setback_m * 1000.0,
						state.sag_m * 1000.0,
						state.air * 100.0,
						state.pull,
						state.bottom_mps,
					],
				)

				if ImGui.Button("Burst " + label):
					wheel_damage.burst(state)

				if ImGui.Button("Tear off " + label):
					wheel_damage.tear_off(state)

	_mechanical()

	Widgets.gap(0.5)
	if ImGui.Button("Repair all"):
		damage.reset()


func _mechanical() -> void:
	var mechanical_damage: MechanicalDamage = vehicle.mechanical_damage
	if mechanical_damage == null:
		return

	ImGui.SeparatorText("Mechanical")
	var toughness: Array = [vehicle.mechanical_toughness]
	if ImGui.SliderFloatEx("Toughness", toughness, 0.5, 5.0, "%.2fx", 0):
		vehicle.mechanical_toughness = toughness[0]
	Widgets.tip("Higher means less mechanical damage from crashes and landings.")
	Widgets.key_value(
		"Engine",
		"%.0f%% power%s"
		% [mechanical_damage.power_factor() * 100.0, "  SEIZED" if mechanical_damage.seized else ""],
	)
	Widgets.key_value(
		"Coolant",
		"%.0f%%  %.0f C" % [mechanical_damage.coolant * 100.0, mechanical_damage.coolant_c],
	)
	Widgets.key_value(
		"Oil",
		"%.0f%%  pressure %.0f%%"
		% [mechanical_damage.oil * 100.0, mechanical_damage.oil_pressure * 100.0],
	)
	Widgets.key_value("Boost", "%.0f%%" % (mechanical_damage.boost_factor() * 100.0))
	Widgets.key_value(
		"Steering",
		"pull %+.1f  play %.1f deg  assist %.0f%%"
		% [
			rad_to_deg(mechanical_damage.steer_offset_rad),
			rad_to_deg(mechanical_damage.steer_play_rad()),
			mechanical_damage.steering_assist() * 100.0,
		],
	)
	Widgets.key_value(
		"Brakes",
		"FL+RR %.0f%%  FR+RL %.0f%%"
		% [mechanical_damage.brake_pressure(0) * 100.0, mechanical_damage.brake_pressure(1) * 100.0],
	)

	Widgets.key_value(
		"Bodywork",
		"drag %+.0f%%  lift %.2f front  %.2f rear"
		% [
			(mechanical_damage.aero_drag - 1.0) * 100.0,
			mechanical_damage.lift_front,
			mechanical_damage.lift_rear,
		],
	)

	for wheel in vehicle.wheels:
		Widgets.key_value(
			wheel.label + " damper",
			"%.0f%%" % (mechanical_damage.damper_health(wheel) * 100.0),
		)

	Widgets.gap(0.4)
	for part in range(MechanicalDamage.PART_NAMES.size()):
		var part_name: String = MechanicalDamage.PART_NAMES[part]
		if ImGui.Button("Fix##" + part_name):
			mechanical_damage.repair_part(part)

		ImGui.SameLine()
		if ImGui.Button("Damage##" + part_name):
			mechanical_damage.break_part(part)

		ImGui.SameLine()
		var worn: float = mechanical_damage.damage[part]
		ImGui.TextColored(
			UITheme.WARN if worn > 0.0 else UITheme.DIM,
			"%.0f%%  %s" % [worn * 100.0, part_name],
		)

	for line in range(2):
		var circuit: String = "FL+RR brakes" if line == 0 else "FR+RL brakes"
		if ImGui.Button("Fix##" + circuit):
			mechanical_damage.repair_brakes(line)

		ImGui.SameLine()
		if ImGui.Button("Cut##" + circuit):
			mechanical_damage.cut_brake_line(line)

		ImGui.SameLine()
		ImGui.TextDisabled(circuit)
