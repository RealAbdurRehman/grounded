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

	Widgets.gap(0.5)
	if ImGui.Button("Repair all"):
		damage.reset()
