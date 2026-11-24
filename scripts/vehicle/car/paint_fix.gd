class_name CarPaintFix
extends Resource

@export var material_name: String = ""

@export_range(-1.0, 1.0, 0.01) var metallic: float = 1.0
@export_range(-1.0, 1.0, 0.01) var roughness: float = -1.0

@export var use_normal_map: bool = true
@export var clearcoat: bool = true
