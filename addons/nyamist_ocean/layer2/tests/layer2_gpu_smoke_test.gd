extends Node3D
## Attach this scene as the current scene in the editor to exercise the GPU path.

@onready var wave_spectrum: WaveSpectrum = $WaveSpectrum
var _completed_grids: Array[bool] = [false, false, false]

func _ready() -> void:
	wave_spectrum.grid_readback_completed.connect(_on_grid_readback_completed)
	print("NYAMIST Layer 2 GPU smoke test started; waiting for grid 0–2 async readbacks.")

func _on_grid_readback_completed(grid_index: int) -> void:
	if grid_index < 0 or grid_index >= _completed_grids.size():
		return
	_completed_grids[grid_index] = true
	print("NYAMIST Layer 2 CPU readback completed for grid %d." % grid_index)
	if _completed_grids.all(func(value: bool) -> bool: return value):
		print("NYAMIST Layer 2 GPU/CPU smoke test: grids 0–2 received; grid 3 intentionally remains GPU-only.")
