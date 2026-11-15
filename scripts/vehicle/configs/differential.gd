class_name DifferentialConfig
extends Resource

enum Type {
	OPEN, # Wheels spin independently.
	LOCKED, # Wheels spin together.
	LIMITED_SLIP, # Friction based.
}

@export var type: Type = Type.OPEN

@export_group("Limited Slip")
## Base locking force.
@export var preload_nm: float = 40.0

## Locking strength under acceleration.
@export_range(0.0, 1.0, 0.05) var power_lock: float = 0.3

## Locking strength when coasting.
@export_range(0.0, 1.0, 0.05) var coast_lock: float = 0.15
