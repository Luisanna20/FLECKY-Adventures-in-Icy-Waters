# Flecky seal model study — 2026-10-15

The local game now uses an original continuous procedural mesh for the skull,
neck, torso and tapered pelvis. It keeps Flecky's white coat and dark eyes while
replacing the old assembly of intersecting ellipsoids. This is a stylized seal
study, not a photorealistic fur groom or a new published release.

The anatomical reference is a whitecoat harp seal, including short foreflippers
and separate webbed hind feet: [NOAA Fisheries](https://www.fisheries.noaa.gov/species/harp-seal).
No third-party mesh or photo texture is included.

## Implementation

- `scripts/flaki_model.gd` builds the continuous body, tapered foreflippers,
  scalloped hind feet, eyes, nose, lips and curved, tapered whiskers.
- `shaders/flaki_fur.gdshader` adds subtle coat variation with distance filtering.
  The skull follows the existing head transform with a blended neck region.
- `scripts/flaki_controller.gd` retains gameplay collision and movement rules,
  voice, blinking, catch reactions and ice/victory states. Swimming uses smaller
  foreflipper strokes and a stronger hind-flipper stroke; its phase advances
  continuously as speed changes. Hind-foot roots follow the body's lateral sway.

Launch the current project with `PLAY_FLAKI.cmd`. Existing distribution archives
and the published Demo v0.2.0 remain separate from this local study.

## Local review

The original controller is saved as
`build/model_review/flaki_controller_before.gd.txt`; the released implementation
is also available in Git commit `5a93bab`.

Studio views and actual bay captures are in `build/model_review/`.
Local review scripts are `tools/seal_review.gd` and `tools/seal_game_review.gd`.
The studio script also checks the head's shader transform against its animated
face transform during head turns, voice and catch poses.

The full game smoke test must run with the normal renderer and `--max-fps 60`:

```powershell
& .\tools\Godot_v4.6.3-stable_win64_console.exe --path . --windowed --max-fps 60 -- --smoke-test
```

The existing test uses one-render-frame simulated input pulses and some rendered
visibility checks. An uncapped headless run is not an equivalent acceptance run:
it failed several timing/visibility checks in this study; the normal-renderer
run passed. Captures are scripted poses, not evidence of manual play.
