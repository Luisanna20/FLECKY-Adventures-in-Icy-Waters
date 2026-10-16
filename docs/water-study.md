# Water study — 2026-10-15

The local game uses a revised water shader in the existing Godot 4.6.3
Compatibility renderer. Launch it with `PLAY_FLAKI.cmd`.

## Appearance and rendering

- Four displacement waves, overlapping smaller waves, and two scrolling seamless
  noise normal fields produce a less regular surface. Mipmaps and distance-based
  filtering reduce distant shimmer.
- A single `UPDATE_ONCE` reflection probe captures the static bay and sky. Layer 2
  selects the captured environment; layer 3 limits the probe's effect to water.
  Water, Flecky, fish and particles are excluded from the capture.
- Correct view-space normals drive native PBR sunlight and environment reflection.
  Refraction is attenuated with distance through the water and protected against
  pulling foreground objects into the distorted image. The already lit screen
  image is composited once through emission rather than lit and blended again.
- Contact foam uses actual scene depth instead of fixed circular floe outlines.
  Diverging wake waves follow Flecky's heading and speed.
- The underside approximates a clear upward viewing window and total internal
  reflection at shallow angles. Underwater lighting and fog vary with camera
  depth; screen-fixed light rays and caustic patterns were removed. Seabed
  caustics remain attached to the scene.

This uses an environment probe, not ray-traced or planar reflections. It does not
reflect moving characters, and nearby reflected geometry has probe parallax
limitations. Refraction is limited to opaque objects available in the screen
buffer. The underwater viewing window is an approximation, not full Snell-law
ray tracing. No new external art assets are required.

Reference documentation: [ReflectionProbe](https://docs.godotengine.org/en/4.6/classes/class_reflectionprobe.html)
and [spatial shaders](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html).

## Verification

- Full normal-renderer game smoke test: **PASS**, recorded in
  `build/water_review/final_smoke.log`. Includes swimming, surfacing, breach,
  water interaction, fish, ice transitions, idle animation, shark, menus,
  achievements and victory.
- Corrected the smoke test's surface-clamp setup: it now resurfaces in open water
  after measuring its initial swim and dive. The original randomized starting
  floe could obstruct this test with a valid ice collision. Gameplay collision
  and movement rules were not changed.
- Seven scripted camera views captured above/below water, at the shoreline,
  overhead and alongside Flecky in `build/water_review/final_*.png`.
- A scripted surface/dive/resurface camera pass was rendered by Godot and encoded
  as `build/water_review/water_motion.mp4`: H.264, 1280x720, 30 FPS, 12 seconds.
  Transition frames were visually inspected; this is an engine-rendered review
  clip, not a recording of manual gameplay.
- Separate frame-pacing runs at 1440x810, capped at 60 FPS, on the local RTX 2070:
  old-water medians 16.680 / 16.666 / 16.659 ms; new-water medians
  16.672 / 16.645 / 16.668 ms. New-water 95th percentiles were
  17.051 / 17.036 / 16.976 ms. These are three fixed scenes, 180 frames each,
  after warm-up; they demonstrate capped frame pacing, not maximum GPU throughput.
  Logs: `frame_baseline.log`, `frame_current.log`.
- Ignore CPU timing fields printed by the screenshot helper: image readback and
  PNG writing pollute that monitor. The separate frame-pacing helper records
  elapsed time between frames without screenshots.

Original water files are backed up in `build/water_review/*_before.*.txt`.
Local QA helpers are `tools/water_review.gd`, `tools/water_frame_pacing.gd` and
`tools/water_motion_review.gd`; they run scripted review scenes and disable
achievement persistence through command-line review flags.

The released Demo v0.2.0 archive is separate from this local version.
