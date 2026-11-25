extends Node
class_name WaveSpectrum
## Four-grid FFT controller. Kept separate from the live Layer 1 scene.

signal grid_readback_completed(grid_index: int)

const GRID_COUNT := 4
const CPU_READBACK_GRID_COUNT := 3
const DEFAULT_TILE_LENGTHS := [Vector2(512.0, 512.0), Vector2(128.0, 128.0), Vector2(32.0, 32.0), Vector2(8.0, 8.0)]

@export_enum("256x256 (Mobile baseline):256") var map_size := 256
@export_range(0.0, 60.0, 1.0) var updates_per_second := 20.0
@export var grid_settings: Array[NyaWaveGridSettings] = []

var cpu_buffer := DisplacementBufferCPU.new()
var gpu_buffer := DisplacementBufferGPU.new()
var wave_generator: NyaWaveGenerator

var _elapsed_seconds := 0.0
var _next_update_time := 0.0
var _readback_pending: Array[bool] = [false, false, false, false]

func _ready() -> void:
	_ensure_grid_settings()
	cpu_buffer.configure(GRID_COUNT, Vector2i(map_size, map_size))
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		push_error("WaveSpectrum requires a RenderingDevice. Compatibility renderer is not supported.")
		return
	wave_generator = NyaWaveGenerator.new()
	wave_generator.map_size = map_size
	add_child(wave_generator)
	wave_generator.init_gpu(GRID_COUNT)
	if not wave_generator.gpu_ready:
		push_error("WaveSpectrum could not initialize the GPU FFT pipeline.")
		return
	if not gpu_buffer.configure(rd, wave_generator.descriptors[&"displacement_map"].rid):
		return
	wave_generator.cascade_updated.connect(_on_cascade_updated)

func _process(delta: float) -> void:
	if wave_generator == null or not wave_generator.gpu_ready:
		return
	_elapsed_seconds += delta
	if updates_per_second <= 0.0 or _elapsed_seconds >= _next_update_time:
		var interval := 1.0 / maxf(updates_per_second, 0.0001)
		var update_delta := delta if updates_per_second <= 0.0 else interval + (_elapsed_seconds - _next_update_time)
		_next_update_time = _elapsed_seconds + interval
		wave_generator.update(update_delta, grid_settings)

func get_gpu_displacement_maps() -> Texture2DArrayRD:
	return gpu_buffer.get_texture_array()

func get_cpu_displacement_at(world_position: Vector3, grid_index: int) -> Vector3:
	if grid_index < 0 or grid_index >= CPU_READBACK_GRID_COUNT:
		return Vector3.ZERO
	var tile := grid_settings[grid_index].tile_length
	var uv := Vector2(fposmod(world_position.x / maxf(tile.x, 0.001), 1.0), fposmod(world_position.z / maxf(tile.y, 0.001), 1.0))
	return cpu_buffer.sample_displacement(grid_index, uv)

func get_combined_cpu_displacement(world_position: Vector3) -> Vector3:
	var result := Vector3.ZERO
	for grid_index in range(CPU_READBACK_GRID_COUNT):
		result += get_cpu_displacement_at(world_position, grid_index) * grid_settings[grid_index].displacement_scale
	return result

func _ensure_grid_settings() -> void:
	while grid_settings.size() < GRID_COUNT:
		var index := grid_settings.size()
		var settings := NyaWaveGridSettings.new()
		settings.tile_length = DEFAULT_TILE_LENGTHS[index]
		settings.spectrum_seed = Vector2i(1013 + index * 1999, 7919 + index * 3571)
		grid_settings.append(settings)
	if grid_settings.size() > GRID_COUNT:
		grid_settings.resize(GRID_COUNT)
	for index in range(GRID_COUNT):
		if grid_settings[index] == null:
			grid_settings[index] = NyaWaveGridSettings.new()
			grid_settings[index].tile_length = DEFAULT_TILE_LENGTHS[index]
			grid_settings[index].spectrum_seed = Vector2i(1013 + index * 1999, 7919 + index * 3571)

func _on_cascade_updated(grid_index: int) -> void:
	if grid_index < 0 or grid_index >= CPU_READBACK_GRID_COUNT:
		return
	if _readback_pending[grid_index]:
		return
	_readback_pending[grid_index] = true
	var error := gpu_buffer.request_grid_readback(grid_index, _on_displacement_readback.bind(grid_index))
	if error != OK:
		_readback_pending[grid_index] = false
		push_warning("Grid %d displacement readback request failed: %s" % [grid_index, error_string(error)])

func _on_displacement_readback(bytes: PackedByteArray, grid_index: int) -> void:
	_readback_pending[grid_index] = false
	if not cpu_buffer.write_grid_rgba16f(grid_index, bytes):
		return
	cpu_buffer.publish_grid(grid_index)
	grid_readback_completed.emit(grid_index)
