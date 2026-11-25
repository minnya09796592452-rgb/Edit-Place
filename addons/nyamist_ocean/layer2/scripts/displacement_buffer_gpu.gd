extends RefCounted
class_name DisplacementBufferGPU
## One GPU texture array with four layers: m_displacementMaps[0..3].

const GRID_COUNT := 4
const CPU_READBACK_GRID_COUNT := 3

var m_displacementMaps: Texture2DArrayRD
var _device: RenderingDevice
var _texture_rid: RID

func configure(device: RenderingDevice, texture_rid: RID) -> bool:
	if device == null or not texture_rid.is_valid():
		push_error("Cannot configure GPU displacement buffer without a valid RenderingDevice texture.")
		return false
	_device = device
	_texture_rid = texture_rid
	m_displacementMaps = Texture2DArrayRD.new()
	m_displacementMaps.texture_rd_rid = _texture_rid
	return true

func get_texture_array() -> Texture2DArrayRD:
	return m_displacementMaps

func request_grid_readback(grid_index: int, callback: Callable) -> Error:
	if _device == null or not _texture_rid.is_valid():
		return ERR_UNCONFIGURED
	if grid_index < 0 or grid_index >= CPU_READBACK_GRID_COUNT:
		return ERR_INVALID_PARAMETER
	return _device.texture_get_data_async(_texture_rid, grid_index, callback)

func is_configured() -> bool:
	return _device != null and _texture_rid.is_valid()
