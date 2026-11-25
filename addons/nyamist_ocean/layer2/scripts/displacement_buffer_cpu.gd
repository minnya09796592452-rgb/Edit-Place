extends RefCounted
class_name DisplacementBufferCPU
## Slot 0 is always the write slot; Slot 1 is always the published read slot.

const InterpolatedField = preload("res://addons/nyamist_ocean/layer2/scripts/interpolated_array2f.gd")
const SLOT_WRITE := 0
const SLOT_READ := 1
const GRID_COUNT := 4

class GridFrame extends RefCounted:
\tvar x
\tvar y
\tvar z

\tfunc _init() -> void:
\t\tx = InterpolatedField.new()
\t\ty = InterpolatedField.new()
\t\tz = InterpolatedField.new()

\tfunc resize(grid_size: Vector2i) -> void:
\t\tx.resize(grid_size)
\t\ty.resize(grid_size)
\t\tz.resize(grid_size)

var _grid_slots: Array = []
var _grid_size := Vector2i.ZERO

func configure(grid_count: int, grid_size: Vector2i) -> void:
\tassert(grid_count == GRID_COUNT, "CPU displacement buffer expects four grid slots.")
\tassert(grid_size.x > 0 and grid_size.y > 0)
\t_grid_size = grid_size
\t_grid_slots.clear()
\tfor _grid_index in range(grid_count):
\t\tvar write_frame := GridFrame.new()
\t\tvar read_frame := GridFrame.new()
\t\twrite_frame.resize(_grid_size)
\t\tread_frame.resize(_grid_size)
\t\t_grid_slots.append([write_frame, read_frame])

func write_grid_rgba16f(grid_index: int, bytes: PackedByteArray) -> bool:
\tif not _is_valid_grid(grid_index):
\t\treturn false
\tvar expected_bytes := _grid_size.x * _grid_size.y * 8
\tif bytes.size() != expected_bytes:
\t\tpush_warning("Displacement readback size mismatch for grid %d: expected %d, got %d." % [grid_index, expected_bytes, bytes.size()])
\t\treturn false
\tvar frame: GridFrame = _grid_slots[grid_index][SLOT_WRITE]
\tfor y_index in range(_grid_size.y):
\t\tfor x_index in range(_grid_size.x):
\t\t\tvar offset := (y_index * _grid_size.x + x_index) * 8
\t\t\tframe.x.set_value(x_index, y_index, bytes.decode_half(offset))
\t\t\tframe.y.set_value(x_index, y_index, bytes.decode_half(offset + 2))
\t\t\tframe.z.set_value(x_index, y_index, bytes.decode_half(offset + 4))
\treturn true

func publish_grid(grid_index: int) -> void:
\tassert(_is_valid_grid(grid_index))
\tvar slots: Array = _grid_slots[grid_index]
\tvar previous_read: GridFrame = slots[SLOT_READ]
\tslots[SLOT_READ] = slots[SLOT_WRITE]
\tslots[SLOT_WRITE] = previous_read

func sample_displacement(grid_index: int, uv: Vector2) -> Vector3:
\tif not _is_valid_grid(grid_index):
\t\treturn Vector3.ZERO
\tvar frame: GridFrame = _grid_slots[grid_index][SLOT_READ]
\treturn Vector3(frame.x.sample_uv(uv), frame.y.sample_uv(uv), frame.z.sample_uv(uv))

func get_grid_size() -> Vector2i:
\treturn _grid_size

func _is_valid_grid(grid_index: int) -> bool:
\treturn grid_index >= 0 and grid_index < _grid_slots.size()
