extends RefCounted
class_name DisplacementBufferCPU
## Slot 0 is always the write slot; Slot 1 is always the published read slot.

const SLOT_WRITE := 0
const SLOT_READ := 1
const CPU_GRID_COUNT := 3

class GridFrame extends RefCounted:
	const InterpolatedField = preload("res://addons/nyamist_ocean/layer2/scripts/interpolated_array2f.gd")
	var x
	var y
	var z

	func _init() -> void:
		x = InterpolatedField.new()
		y = InterpolatedField.new()
		z = InterpolatedField.new()

	func resize(grid_size: Vector2i) -> void:
		x.resize(grid_size)
		y.resize(grid_size)
		z.resize(grid_size)

var _grid_slots: Array = []
var _grid_size := Vector2i.ZERO

func configure(grid_count: int, grid_size: Vector2i) -> void:
	assert(grid_count == CPU_GRID_COUNT, "CPU displacement buffer stores only grids 0–2.")
	assert(grid_size.x > 0 and grid_size.y > 0)
	_grid_size = grid_size
	_grid_slots.clear()
	for _grid_index in range(grid_count):
		var write_frame := GridFrame.new()
		var read_frame := GridFrame.new()
		write_frame.resize(_grid_size)
		read_frame.resize(_grid_size)
		_grid_slots.append([write_frame, read_frame])

func write_grid_rgba16f(grid_index: int, bytes: PackedByteArray) -> bool:
	if not _is_valid_grid(grid_index):
		return false
	var expected_bytes := _grid_size.x * _grid_size.y * 8
	if bytes.size() != expected_bytes:
		push_warning("Displacement readback size mismatch for grid %d: expected %d, got %d." % [grid_index, expected_bytes, bytes.size()])
		return false
	var frame: GridFrame = _grid_slots[grid_index][SLOT_WRITE]
	for y_index in range(_grid_size.y):
		for x_index in range(_grid_size.x):
			var offset := (y_index * _grid_size.x + x_index) * 8
			frame.x.set_value(x_index, y_index, bytes.decode_half(offset))
			frame.y.set_value(x_index, y_index, bytes.decode_half(offset + 2))
			frame.z.set_value(x_index, y_index, bytes.decode_half(offset + 4))
	return true

func publish_grid(grid_index: int) -> void:
	assert(_is_valid_grid(grid_index))
	var slots: Array = _grid_slots[grid_index]
	var previous_read: GridFrame = slots[SLOT_READ]
	slots[SLOT_READ] = slots[SLOT_WRITE]
	slots[SLOT_WRITE] = previous_read

func sample_displacement(grid_index: int, uv: Vector2) -> Vector3:
	if not _is_valid_grid(grid_index):
		return Vector3.ZERO
	var frame: GridFrame = _grid_slots[grid_index][SLOT_READ]
	return Vector3(frame.x.sample_uv(uv), frame.y.sample_uv(uv), frame.z.sample_uv(uv))

func get_grid_size() -> Vector2i:
	return _grid_size

func _is_valid_grid(grid_index: int) -> bool:
	return grid_index >= 0 and grid_index < _grid_slots.size()
