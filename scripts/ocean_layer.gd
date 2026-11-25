@tool
extends Node3D
class_name OceanLayer

const WAVE_SPECTRUM_SCRIPT: Script = preload("res://addons/nyamist_ocean/layer2/scripts/wave_spectrum.gd")

@export_group("Ocean Level")
@export var ocean_level: float = 0.0
@export var tide_low: float = -0.5
@export var tide_high: float = 0.5
@export_range(30.0, 86400.0, 1.0) var tide_period_seconds: float = 600.0
@export_range(0.0, 1.0, 0.001) var tide_phase: float = 0.0
@export var tide_curve: Curve

@export_group("Wave Query")
@export_range(0.0, 2.0, 0.01) var wave_amplitude: float = 0.35
@export_range(0.0, 2.0, 0.01) var secondary_wave_amplitude: float = 0.16
@export_range(0.001, 1.0, 0.001) var wave_frequency: float = 0.12
@export_range(0.001, 1.0, 0.001) var secondary_wave_frequency: float = 0.21
@export var wave_direction: Vector2 = Vector2(1.0, 0.25)
@export var secondary_wave_direction: Vector2 = Vector2(-0.35, 1.0)
@export_range(0.0, 10.0, 0.01) var wave_speed: float = 1.0
@export_range(0.0, 10.0, 0.01) var secondary_wave_speed: float = 1.35

@export_group("Surface")
@export_range(256.0, 16384.0, 256.0) var surface_size: float = 4096.0
@export_range(8, 128, 1) var mesh_subdivisions: int = 64
@export_group("Layer 2 FFT")
@export var enable_layer2_fft: bool = true

var _elapsed_seconds: float = 0.0
var _surface: MeshInstance3D
var _material: ShaderMaterial
var _wave_spectrum: WaveSpectrum
var _fft_readback_ready := false
var _fft_readback_counts: Array[int] = [0, 0, 0]


func _ready() -> void:
	_create_surface()
	if not Engine.is_editor_hint() and enable_layer2_fft:
		_start_layer2_fft()
	set_process(true)
	if not Engine.is_editor_hint():
		call_deferred("_run_runtime_diagnostics")


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		_elapsed_seconds += delta

	var tide_offset := get_tide_offset()
	global_position.y = ocean_level + tide_offset

	var camera := get_viewport().get_camera_3d()
	if camera != null:
		global_position.x = camera.global_position.x
		global_position.z = camera.global_position.z

	_update_material_parameters()


func get_tide_offset() -> float:
	var period := maxf(tide_period_seconds, 0.001)
	var phase := fposmod((_elapsed_seconds / period) + tide_phase, 1.0)
	var normalized_tide: float

	if tide_curve != null:
		normalized_tide = clampf(tide_curve.sample(phase), 0.0, 1.0)
	else:
		normalized_tide = (sin((phase * TAU) - (PI * 0.5)) + 1.0) * 0.5

	return lerpf(tide_low, tide_high, normalized_tide)


func query_wave_height(world_position: Vector3) -> float:
	if _fft_readback_ready and _wave_spectrum != null:
		var displacement: Vector3 = _wave_spectrum.get_combined_cpu_displacement(world_position)
		return displacement.y

	var p := Vector2(world_position.x, world_position.z)
	var dir_a := _safe_direction(wave_direction)
	var dir_b := _safe_direction(secondary_wave_direction)
	var wave_a := sin(p.dot(dir_a) * wave_frequency + _elapsed_seconds * wave_speed)
	var wave_b := sin(p.dot(dir_b) * secondary_wave_frequency + _elapsed_seconds * secondary_wave_speed)
	return (wave_a * wave_amplitude) + (wave_b * secondary_wave_amplitude)


func get_surface_height_at(world_position: Vector3) -> float:
	return ocean_level + get_tide_offset() + query_wave_height(world_position)


func _safe_direction(direction: Vector2) -> Vector2:
	if direction.length_squared() < 0.000001:
		return Vector2.RIGHT
	return direction.normalized()


func _start_layer2_fft() -> void:
	print("[NYAMIST-DIAG] Layer 2 FFT startup requested.")
	_wave_spectrum = WAVE_SPECTRUM_SCRIPT.new() as WaveSpectrum
	if _wave_spectrum == null:
		push_error("[NYAMIST-DIAG] Could not instantiate the Layer 2 WaveSpectrum controller.")
		return

	_wave_spectrum.name = "WaveSpectrum"
	add_child(_wave_spectrum)
	_wave_spectrum.grid_readback_completed.connect(_on_fft_grid_readback_completed)

	var displacement_maps: Texture2DArrayRD = _wave_spectrum.get_gpu_displacement_maps()
	if displacement_maps == null:
		push_error("[NYAMIST-DIAG] WaveSpectrum returned no GPU displacement texture. Layer 1 sine displacement remains selected.")
		return

	if _material == null:
		push_error("[NYAMIST-DIAG] Ocean ShaderMaterial is missing; FFT texture cannot be assigned.")
		return

	_material.set_shader_parameter("displacement_maps", displacement_maps)
	_material.set_shader_parameter("use_fft_displacement", true)
	_apply_fft_grid_settings()
	print("[NYAMIST-DIAG] Layer 2 GPU displacement texture assigned to OceanSurface shader.")


func _apply_fft_grid_settings() -> void:
	if _wave_spectrum == null or _material == null:
		return

	var settings: Array = _wave_spectrum.grid_settings
	if settings.size() != 4:
		push_error("[NYAMIST-DIAG] Expected four FFT grid settings; found %d." % settings.size())
		return

	var tile_lengths_x := Vector4.ZERO
	var tile_lengths_y := Vector4.ZERO
	var displacement_scales := Vector4.ZERO
	for index in range(4):
		var grid: NyaWaveGridSettings = settings[index]
		tile_lengths_x[index] = maxf(grid.tile_length.x, 0.001)
		tile_lengths_y[index] = maxf(grid.tile_length.y, 0.001)
		displacement_scales[index] = grid.displacement_scale

	_material.set_shader_parameter("grid_tile_lengths_x", tile_lengths_x)
	_material.set_shader_parameter("grid_tile_lengths_y", tile_lengths_y)
	_material.set_shader_parameter("grid_displacement_scales", displacement_scales)
	print("[NYAMIST-DIAG] FFT grid settings applied: ", tile_lengths_x, " / ", tile_lengths_y)


func _on_fft_grid_readback_completed(grid_index: int) -> void:
	if grid_index < 0 or grid_index >= _fft_readback_counts.size():
		push_warning("[NYAMIST-DIAG] Unexpected CPU readback grid index: %d." % grid_index)
		return
	_fft_readback_ready = true
	_fft_readback_counts[grid_index] += 1
	if _fft_readback_counts[grid_index] == 1:
		print("[NYAMIST-DIAG] First CPU displacement readback received for grid %d." % grid_index)


func _create_surface() -> void:
	if _surface != null:
		return

	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * surface_size
	plane.subdivide_width = mesh_subdivisions
	plane.subdivide_depth = mesh_subdivisions

	_surface = MeshInstance3D.new()
	_surface.name = "OceanSurface"
	_surface.mesh = plane
	_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_surface)

	if Engine.is_editor_hint():
		_surface.owner = get_tree().edited_scene_root

	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/ocean_layer.gdshader")
	_surface.material_override = _material
	if _material.shader == null:
		push_error("[NYAMIST-DIAG] Could not load res://shaders/ocean_layer.gdshader.")
	_update_material_parameters()


func _run_runtime_diagnostics() -> void:
	await get_tree().process_frame
	print("========== NYAMIST OCEAN RUNTIME DIAGNOSTICS ==========")

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		push_error("[NYAMIST-DIAG] No active Camera3D found in the current viewport.")
	else:
		var forward := -camera.global_transform.basis.z
		if forward.y >= -0.02:
			var previous_pitch := rad_to_deg(camera.rotation.x)
			camera.rotation.x = maxf(camera.rotation.x, deg_to_rad(15.0))
			forward = -camera.global_transform.basis.z
			print("[NYAMIST-DIAG] Camera was not looking down at the ocean (pitch %.2f deg); adjusted pitch to %.2f deg." % [previous_pitch, rad_to_deg(camera.rotation.x)])
		print("[NYAMIST-DIAG] Camera current=%s position=%s forward=%s" % [camera.current, camera.global_position, forward])

	if _surface == null or not is_instance_valid(_surface):
		push_error("[NYAMIST-DIAG] OceanSurface MeshInstance3D was not created.")
	else:
		print("[NYAMIST-DIAG] OceanSurface visible=%s mesh=%s material=%s" % [_surface.visible, _surface.mesh, _surface.material_override])
		if _surface.mesh == null:
			push_error("[NYAMIST-DIAG] OceanSurface has no Mesh resource.")
		if _material == null or _material.shader == null:
			push_error("[NYAMIST-DIAG] OceanSurface ShaderMaterial or shader is missing.")
		else:
			print("[NYAMIST-DIAG] Ocean shader loaded: %s" % _material.shader.resource_path)

	var rd := RenderingServer.get_rendering_device()
	print("[NYAMIST-DIAG] RenderingDevice available=%s renderer=%s" % [rd != null, RenderingServer.get_current_rendering_method()])
	print("[NYAMIST-DIAG] Ocean level now=%.3f; FFT enabled=%s; FFT readbacks=%s" % [global_position.y, enable_layer2_fft, _fft_readback_counts])
	print("========== END NYAMIST OCEAN RUNTIME DIAGNOSTICS ==========")


func _update_material_parameters() -> void:
	if _material == null:
		return

	_material.set_shader_parameter("wave_time", _elapsed_seconds)
	_material.set_shader_parameter("wave_amplitude", wave_amplitude)
	_material.set_shader_parameter("secondary_wave_amplitude", secondary_wave_amplitude)
	_material.set_shader_parameter("wave_frequency", wave_frequency)
	_material.set_shader_parameter("secondary_wave_frequency", secondary_wave_frequency)
	_material.set_shader_parameter("wave_direction", _safe_direction(wave_direction))
	_material.set_shader_parameter("secondary_wave_direction", _safe_direction(secondary_wave_direction))
	_material.set_shader_parameter("wave_speed", wave_speed)
	_material.set_shader_parameter("secondary_wave_speed", secondary_wave_speed)
