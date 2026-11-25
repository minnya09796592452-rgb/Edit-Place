extends RefCounted
class_name PhillipsSpectrum
## CPU reference implementation of the Phillips wave spectrum used by the Layer 2 GPU shader.

const GRAVITY := 9.81
const DEFAULT_AMPLITUDE := 0.0081

static func evaluate(k_vector: Vector2, wind_speed: float, wind_direction_degrees: float, amplitude: float = DEFAULT_AMPLITUDE) -> float:
	var k_squared := k_vector.length_squared()
	if k_squared <= 0.000001 or wind_speed <= 0.0:
		return 0.0
	var largest_wave := (wind_speed * wind_speed) / GRAVITY
	var small_wave := largest_wave * 0.001
	var wind_angle := deg_to_rad(wind_direction_degrees)
	var wind_direction := Vector2(cos(wind_angle), sin(wind_angle))
	var directional := k_vector.normalized().dot(wind_direction)
	var long_wave_term := exp(-1.0 / maxf(k_squared * largest_wave * largest_wave, 0.000001))
	var short_wave_damping := exp(-k_squared * small_wave * small_wave)
	return amplitude * long_wave_term * directional * directional * short_wave_damping / (k_squared * k_squared)
