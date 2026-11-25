# NYAMIST Ocean — Layer 2 FFT Foundation

Isolated four-grid FFT backend for the existing Godot 4.7 Mobile project.

## Included

- Four per-grid spectrum resources (`NyaWaveGridSettings`).
- GodotOceanWaves-derived TMA/JONSWAP directional spectrum and Stockham FFT compute pipeline.
- One four-layer GPU displacement texture array (`m_displacementMaps`, layers 0–3).
- Asynchronous GPU-to-CPU readback for grids 0–2 only.
- CPU double buffer with fixed roles: slot 0 = write, slot 1 = published read.
- `InterpolatedArray2f` bilinear scalar fields for X, Y, and Z displacement.
- Grid 3 remains GPU-only to reduce readback bandwidth.

## Mobile constraints

- Initial FFT kernel is fixed at 256x256. Its Stockham row transform uses one 256-invocation workgroup and a 256-element shared-memory row.
- Spectrum image format is RGBA32F to match the allocated R32G32B32A32_SFLOAT texture.
- Compute shaders target GLSL 450.
- The backend uses the main RenderingDevice, not a secondary local RenderingDevice.

These are conservative starting settings, not a claim that every Android driver will run the pipeline correctly. Verify on the target Mali-G925 device before increasing map size or integrating into the live scene.

## Integration status

This backend is intentionally not attached to `Atmosphere.tscn` yet. Existing Layer 1 OceanLayer, WorldEnvironment, Sky, Sun, Fog, and Moon remain unchanged. After Android runtime verification, connect Layer 2 through a small adapter without replacing the current Layer 1 API.

## CPU tests

Run from the project root with a Godot 4.7 executable:

    godot --headless --path . --script res://addons/nyamist_ocean/layer2/tests/layer2_cpu_tests.gd

## Upstream

FFT spectrum and Stockham compute implementation adapted from https://github.com/2Retr0/GodotOceanWaves. See THIRD_PARTY_LICENSES/GodotOceanWaves-MIT.txt.
