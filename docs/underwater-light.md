# Underwater sunlight pass

Local update, 2026-10-16. Launch with `PLAY_FLAKI.cmd`.

This is the lighting step of the visual plan, before fish and crab appearance.

Caustic refinement after visual feedback: light gain reduced from 13.0 to 8.45
(-35%), spatial frequency increased from 0.60 to 0.78 (features about 23% smaller).
A rounded Gaussian profile replaces the flat bright core, with energy-preserving
pixel filtering and gentle local intensity variation. Three rendered views were
checked without shader errors: `soft_basin.png`, `soft_plants.png`, `soft_cave.png`
and `soft_caustics.log` in the review directory. These supersede the earlier
`final_*` captures for caustic appearance.

- Near surfaces keep more of their material colour. Reduced blue grading and
  height fog preserve contrast; distance fog still gives the bay a cold tone.
- The seabed shader concentrates directional light into animated, world-space
  caustic curves. Its light function uses actual shadow attenuation, so shaded
  cave interiors and the underside of ice are not painted with luminous lines.
- The water's underside has a wave-distorted transmitted sun window. The
  above-water branch keeps the existing water shading.
- A 32-step scattering pass stops at opaque scene depth and at the surface.
  It samples a 128x128 static sunlight blocker map, baked by physics rays once
  after the bay is built. Floes, cave roofs and terrain block light; moving
  actors are deliberately excluded. It fades out after resurfacing.

This is an artistic approximation, not a full underwater light simulation.
The blocker map has about 1.56 m spacing, so small silhouettes are approximate;
it must be rebuilt if static level geometry is moved. Scattering adds a full
screen pass only while underwater. No renderer migration or new texture
downloads were needed.

## Verification

- Seven matched before/final views, including upward sunlight, seabed, plants,
  cave and above-water surface: `build/underwater_light_review/`.
- `tests/underwater_light_integration.gd`: five ice blockers, three cave-roof
  samples, open water and dive/resurface visibility passed using the renderer.
- Independent 1440x810 frame pacing on the local RTX 2070, capped at 60 FPS:
  medians 16.672 / 16.663 / 16.671 ms, p95 16.821 / 16.824 / 16.825 ms for
  three underwater scenes. This verifies capped pacing, not peak throughput.
  Static blocker-map bake took 45–50 ms during scene initialization.
- Full gameplay smoke test log: `build/underwater_light_review/smoke.log`.
- Previous files are backed up as `*.before.txt` in the same review directory.

Implementation references: Godot's [spatial shader light function](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)
and [depth reconstruction](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html).

No public release was made. Earlier accepted changes remain in the working tree.
