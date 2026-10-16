# Background fish schools

Local update, 2026-10-16. Launch with `PLAY_FLAKI.cmd`.

The four existing decorative schools still contain 13 fish each. Their home
positions, orbit parameters and non-catchable, non-collidable role remain.
The old nine-triangle silhouettes are replaced by smooth rounded bodies,
small eyes, solid dorsal/ventral fins and a forked tail. Each fish has 512
triangles; each school still uses one MultiMesh with one material surface.
There are no individual Skeleton3D, physics or animation-player nodes.

`ambient_fish_mesh.gd` builds the original geometry. `ambient_fish.gdshader`
adds dark backs, silver flanks, pale bellies and restrained reflected highlights.
Instance custom data varies tail phase, frequency and body width, while the
existing per-fish scale and heading variation remain. Extra culling margin
covers shader-driven tail movement. No external assets were downloaded.

## Validation

- Rendered review checks 4 schools / 52 fish, one surface per school, volumetric
  mesh bounds, per-instance animation data, movement, and absence of collisions
  and catchable-group membership. `build/ambient_fish_review/final_review.log`.
- Actual bay captures: `school.png` and `close.png` in that review directory.
- 1440x810 frame pacing on RTX 2070 with a 60 FPS cap: medians
  16.669 / 16.664 / 16.655 ms; p95 16.763 / 16.820 / 16.806 ms across three
  underwater views. This measures capped pacing, not maximum throughput.
- Full gameplay smoke log: `build/ambient_fish_review/smoke.log`.
- Original school script backup: `build/ambient_fish_review/school.before.txt`.

The primary catchable fish and their original skeletal animations are separate.
No release was published.
