@tool
extends Node3D
class_name OceanLayer

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

var _elapsed_seconds: float = 0.0
var _surface: MeshInstance3D
var _material: ShaderMaterial


func _ready() -> void:
	_create_surface()
	set_process(true)


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
	_update_material_parameters()


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
