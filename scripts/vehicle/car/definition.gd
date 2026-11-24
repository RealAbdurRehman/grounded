class_name CarDefinition
extends Resource

@export_group("Identity")
@export var car_name: String = "Car"

@export_multiline var credits: String = ""

@export_group("Model")
@export var model: PackedScene
@export var model_faces_plus_z: bool = true

@export var fit_to_wheelbase: bool = true
@export var model_scale: float = 1.0

@export var nudge_m: Vector3 = Vector3.ZERO

@export var show_interior: bool = true

@export_group("Part names")
@export var hidden_words: Array[String] = []
@export var interior_words: Array[String] = []

@export var tire_word: String = "TYRE"
@export var spinning_words: Array[String] = []

@export var fixed_words: Array[String] = []

@export_range(0, 3) var tire_detail: int = 2

@export_group("Paint")
@export var paint_fixes: Array[CarPaintFix] = []

@export_group("Collision")
@export var collision_parts: Array[CarCollisionPart] = []

@export_range(1, 24) var body_pieces: int = 12

@export var not_body_words: Array[String] = []

@export var collision_clearance_m: float = 0.2

@export_range(5.0, 60.0, 0.5) var approach_angle_deg: float = 25.0
@export_range(5.0, 60.0, 0.5) var departure_angle_deg: float = 25.0

@export var collision: CarCollision

@export_range(0.0, 1.0, 0.01) var body_bounce: float = 0.0
@export_range(0.0, 1.0, 0.01) var body_friction: float = 0.2

@export_group("Damage")
@export var panels: Array[CarPanel] = []

@export_group("Size and weight")
@export var mass_kg: float = 1400.0

@export var wheelbase_m: float = 2.6
@export var front_track_m: float = 1.5
@export var rear_track_m: float = 1.5

@export_range(0.3, 0.7, 0.01) var front_weight_share: float = 0.5

@export var center_of_mass_height_m: float = 0.5

@export_group("Tires and wheels")
@export var tire_radius_m: float = 0.31
@export var tire_width_m: float = 0.225
@export var rim_radius_m: float = 0.2

@export_group("Springs and dampers")
@export var front_ride_hz: float = 1.5
@export var rear_ride_hz: float = 1.6

@export var bump_damping_ratio: float = 0.25
@export var rebound_damping_ratio: float = 0.45

@export_group("Engine")
@export var torque_floor_nm: float = 100.0
@export var torque_peak_nm: float = 300.0

@export var torque_peak_rpm: float = 4000.0
@export var torque_bandwidth_rpm: float = 3000.0

@export var idle_rpm: float = 800.0
@export var rev_limiter_rpm: float = 6500.0

@export var max_rpm: float = 6800.0

@export_group("Drivetrain")
@export var gear_ratios: Array[float] = [-3.4, 0.0, 3.6, 2.05, 1.4, 1.05, 0.84]
@export var final_drive: float = 3.8

@export_range(0.5, 1.0, 0.01) var efficiency: float = 0.88

@export var automatic_upshift_rpm: float = 5200.0

@export var front_driven: bool = false
@export var rear_driven: bool = true

@export_range(0.0, 1.0, 0.05) var center_front_torque_share: float = 0.4

@export_group("Air")
@export var drag_coefficient: float = 0.31
@export var frontal_area_m2: float = 2.2

@export_group("Resources")
@export var chassis: ChassisConfig

@export var aero: AeroConfig

@export var engine: EngineConfig
@export var drivetrain: DrivetrainConfig

@export var front_differential: DifferentialConfig
@export var rear_differential: DifferentialConfig
@export var center_differential: DifferentialConfig

@export var front_suspension: SuspensionConfig
@export var rear_suspension: SuspensionConfig

@export var front_tire: Tire
@export var rear_tire: Tire


func damage_panels() -> Array[CarPanel]:
	return panels if not panels.is_empty() else CarPanel.defaults()
