class_name Telemetry
extends Control

@export var target_vehicle: RigidBody3D

@onready var speed_label: Label = $VBoxContainer/SpeedLabel
@onready var g_force_label: Label = $VBoxContainer/GForceLabel
@onready var wheel_grid: GridContainer = $VBoxContainer/WheelGrid
@onready var friction_circle_draw: Control = $FrictionCircle

var _wheel_labels: Dictionary = {}
var _prev_velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	for wheel_name in ["FL", "FR", "RL", "RR"]:
		var lbl: Label = wheel_grid.get_node_or_null(wheel_name)
		if lbl: _wheel_labels[wheel_name] = lbl

func _process(delta: float) -> void:
	if not target_vehicle: return

	var vel: Vector3 = target_vehicle.linear_velocity
	var speed_mps: float = vel.length()
	var speed_kmh: float = speed_mps * 3.6

	var accel: Vector3 = (vel - _prev_velocity) / max(delta, 0.0001)
	_prev_velocity = vel
	var local_accel: Vector3 = target_vehicle.global_transform.basis.inverse() * accel

	var g_long: float = local_accel.z / 9.81
	var g_lat: float = local_accel.x / 9.81

	if speed_label:
		speed_label.text = "Speed: %5.1f km/h (%4.1f m/s)" % [speed_kmh, speed_mps]
	if g_force_label:
		g_force_label.text = "G-Force: Lat %4.2f g | Long %4.2f g" % [g_lat, g_long]

	if friction_circle_draw:
		friction_circle_draw.queue_redraw()

func update_wheel_telemetry(wheel_id: String, fz: float, slip_angle_deg: float, slip_ratio: float, compression: float) -> void:
	if _wheel_labels.has(wheel_id):
		_wheel_labels[wheel_id].text = "%s: Fz:%5.0f N | α:%4.1f° | κ:%4.2f | Comp:%3.0f%%" % [
			wheel_id, fz, slip_angle_deg, slip_ratio, compression * 100.0
		]
