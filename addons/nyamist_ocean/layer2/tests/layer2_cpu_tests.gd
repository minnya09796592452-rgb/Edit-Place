extends SceneTree
## Run with: godot --headless --path . --script res://addons/nyamist_ocean/layer2/tests/layer2_cpu_tests.gd

const InterpolatedArray2f = preload("res://addons/nyamist_ocean/layer2/scripts/interpolated_array2f.gd")
const DisplacementBufferCPU = preload("res://addons/nyamist_ocean/layer2/scripts/displacement_buffer_cpu.gd")
const PhillipsSpectrum = preload("res://addons/nyamist_ocean/layer2/scripts/phillips_spectrum.gd")

func _initialize() -> void:
	_test_bilinear_interpolation()
	_test_cpu_double_buffer()
	_test_phillips_spectrum()
	print("NYAMIST Layer 2 CPU tests passed.")
	quit(0)

func _test_bilinear_interpolation() -> void:
	var field = InterpolatedArray2f.new()
	field.resize(Vector2i(2, 2))
	field.set_value(0, 0, 0.0)
	field.set_value(1, 0, 1.0)
	field.set_value(0, 1, 2.0)
	field.set_value(1, 1, 3.0)
	assert(is_equal_approx(field.sample_uv(Vector2(0.5, 0.5)), 1.5))
	assert(is_equal_approx(field.sample_uv(Vector2.ZERO), 0.0))
	assert(is_equal_approx(field.sample_uv(Vector2.ONE), 3.0))

func _test_cpu_double_buffer() -> void:
	var buffer = DisplacementBufferCPU.new()
	buffer.configure(4, Vector2i(2, 2))
	var bytes := PackedByteArray()
	bytes.resize(2 * 2 * 8)
	for index in range(4):
		var offset := index * 8
		bytes.encode_half(offset, float(index + 1))
		bytes.encode_half(offset + 2, float(index + 11))
		bytes.encode_half(offset + 4, float(index + 21))
		bytes.encode_half(offset + 6, 0.0)
	assert(buffer.write_grid_rgba16f(0, bytes))
	assert(buffer.sample_displacement(0, Vector2.ZERO) == Vector3.ZERO)
	buffer.publish_grid(0)
	assert(buffer.sample_displacement(0, Vector2.ZERO).is_equal_approx(Vector3(1.0, 11.0, 21.0)))

func _test_phillips_spectrum() -> void:
	var energy: float = PhillipsSpectrum.evaluate(Vector2(0.1, 0.2), 8.0, 0.0)
	assert(is_finite(energy) and energy >= 0.0)
	assert(PhillipsSpectrum.evaluate(Vector2.ZERO, 8.0, 0.0) == 0.0)
