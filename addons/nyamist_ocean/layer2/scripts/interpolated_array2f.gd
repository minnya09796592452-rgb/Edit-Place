extends RefCounted
class_name InterpolatedArray2f
## Bilinearly sampled scalar 2D field used for one displacement component.

var size: Vector2i = Vector2i.ZERO
var values: PackedFloat32Array = PackedFloat32Array()

func resize(new_size: Vector2i) -> void:
	assert(new_size.x > 0 and new_size.y > 0, "Grid dimensions must be positive.")
	size = new_size
	values.resize(size.x * size.y)
	values.fill(0.0)

func clear(value: float = 0.0) -> void:
	values.fill(value)

func set_value(x: int, y: int, value: float) -> void:
	assert(x >= 0 and x < size.x and y >= 0 and y < size.y)
	values[y * size.x + x] = value

func get_value(x: int, y: int) -> float:
	assert(x >= 0 and x < size.x and y >= 0 and y < size.y)
	return values[y * size.x + x]

func sample_uv(uv: Vector2) -> float:
	if size.x == 0 or size.y == 0:
		return 0.0
	var p := Vector2(clampf(uv.x, 0.0, 1.0) * float(size.x - 1), clampf(uv.y, 0.0, 1.0) * float(size.y - 1))
	var x0 := int(floor(p.x))
	var y0 := int(floor(p.y))
	var x1 := mini(x0 + 1, size.x - 1)
	var y1 := mini(y0 + 1, size.y - 1)
	var tx := p.x - float(x0)
	var ty := p.y - float(y0)
	var a := lerpf(get_value(x0, y0), get_value(x1, y0), tx)
	var b := lerpf(get_value(x0, y1), get_value(x1, y1), tx)
	return lerpf(a, b, ty)
