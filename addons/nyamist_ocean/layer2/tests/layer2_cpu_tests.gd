extends SceneTree
## Run with: godot --headless --path . --script res://addons/nyamist_ocean/layer2/tests/layer2_cpu_tests.gd

const InterpolatedArray2f = preload("res://addons/nyamist_ocean/layer2/scripts/interpolated_array2f.gd")
const DisplacementBufferCPU = preload("res://addons/nyamist_ocean/layer2/scripts/displacement_buffer_cpu.gd")

func _initialize() -> void:
\t_test_bilinear_interpolation()
\t_test_cpu_double_buffer()
\tprint("NYAMIST Layer 2 CPU tests passed.")
\tquit(0)

func _test_bilinear_interpolation() -> void:
\tvar field = InterpolatedArray2f.new()
\tfield.resize(Vector2i(2, 2))
\tfield.set_value(0, 0, 0.0)
\tfield.set_value(1, 0, 1.0)
\tfield.set_value(0, 1, 2.0)
\tfield.set_value(1, 1, 3.0)
\tassert(is_equal_approx(field.sample_uv(Vector2(0.5, 0.5)), 1.5))
\tassert(is_equal_approx(field.sample_uv(Vector2.ZERO), 0.0))
\tassert(is_equal_approx(field.sample_uv(Vector2.ONE), 3.0)

func _test_cpu_double_buffer() -> void:
\tvar buffer = DisplacementBufferCPU.new()
\tbuffer.configure(4, Vector2i(2, 2))
\tvar bytes := PackedByteArray()
\tbytes.resize(2 * 2 * 8)
\tfor index in range(4):
\t\tvar offset := index * 8
\t\tbytes.encode_half(offset, float(index + 1))
\t\tbytes.encode_half(offset + 2, float(index + 11))
\t\tbytes.encode_half(offset + 4, float(index + 21))
\t\tbytes.encode_half(offset + 6, 0.0)
\tassert(buffer.write_grid_rgba16f(0, bytes))
\tassert(buffer.sample_displacement(0, Vector2.ZERO) == Vector3.ZERO)
\tbuffer.publish_grid(0)
\tassert(buffer.sample_displacement(0, Vector2.ZERO).is_equal_approx(Vector3(1.0, 11.0, 21.0)))
