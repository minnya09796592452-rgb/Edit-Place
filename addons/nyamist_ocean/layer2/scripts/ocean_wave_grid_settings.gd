@tool
extends Resource
class_name NyaWaveGridSettings
## Per-grid spectrum settings adapted from GodotOceanWaves (MIT).

@export_group("Grid")
@export var tile_length := Vector2(128.0, 128.0)
@export_range(0.0, 2.0, 0.01) var displacement_scale := 1.0
@export_range(0.0, 2.0, 0.01) var normal_scale := 1.0

@export_group("Wave Spectrum")
@export_enum("Phillips:0", "TMA / JONSWAP:1") var spectrum_model := 0
@export_range(0.1, 40.0, 0.1) var wind_speed := 8.0
@export_range(-360.0, 360.0, 0.1) var wind_direction := 0.0
@export_range(0.01, 1000.0, 0.1) var fetch_length := 150.0
@export_range(0.0, 2.0, 0.01) var swell := 0.8
@export_range(0.0, 1.0, 0.01) var spread := 0.2
@export_range(0.0, 1.0, 0.01) var detail := 1.0

@export_group("Foam")
@export_range(0.0, 2.0, 0.01) var whitecap := 0.5
@export_range(0.0, 10.0, 0.01) var foam_amount := 2.0

var spectrum_seed := Vector2i.ZERO
var should_generate_spectrum := true
var time := 0.0
var foam_grow_rate := 0.0
var foam_decay_rate := 0.0
