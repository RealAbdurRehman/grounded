class_name TerrainNoise
extends RefCounted

const WEIGHTS: Array[float] = [0.6, 0.3, 0.1]
const LENGTH_RATIOS: Array[float] = [1.0, 0.4, 0.17]

const STEPS_PER_BUMP: float = 3.0
const REFERENCE_STEP_S: float = 1.0 / 120.0

static var _layers: Array[FastNoiseLite] = []


static func height(surface: SurfaceType, point: Vector3, speed_mps: float, delta: float) -> float:
	if surface.height_variation_m <= 0.0:
		return 0.0

	if _layers.is_empty():
		_build()

	var step_m: float = maxf(absf(speed_mps) * maxf(delta, REFERENCE_STEP_S), 0.001)

	var total: float = 0.0
	for i in range(_layers.size()):
		var length: float = surface.bump_length_m * LENGTH_RATIOS[i]
		var felt: float = clampf(length / step_m / STEPS_PER_BUMP - 1.0, 0.0, 1.0)

		if felt <= 0.0:
			continue

		_layers[i].frequency = 1.0 / length
		total += WEIGHTS[i] * felt * _layers[i].get_noise_2d(point.x, point.z)

	return surface.height_variation_m * total


static func _build() -> void:
	for i in range(LENGTH_RATIOS.size()):
		var layer := FastNoiseLite.new()
		layer.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		layer.seed = 1000 + i * 17

		_layers.append(layer)
