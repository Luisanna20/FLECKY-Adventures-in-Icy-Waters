# Fish appearance

Local material update, 2026-10-16. Launch with `PLAY_FLAKI.cmd`.

All three catchable Quaternius fish keep their original vertex positions, indices,
bone weights, skin bind poses, skeletons and animation clips. Source GLBs are
unchanged. This pass improves materials while retaining the stylized proportions.

`fish_appearance.gd` prepares and shares one mesh per species. The imported meshes
had no UV coordinates. Rest-pose side coordinates are added for procedural skin
detail, keeping it attached while bones move. Body normals are averaged across
coincident vertices and material seams for smoother shading; fins and eyes retain
their normals. No subdivision or extra vertices are introduced.

`fish_skin.gdshader` provides three muted palettes, dark backs and pale bellies,
fine staggered scales, curved gill covers, faint lateral lines, fin rays and iris
rings. Scale detail fades with pixel footprint. Strong old self-illumination is
replaced by a small ambient lift and light-dependent sheen. These are procedural
materials rather than downloaded or AI-generated bitmap textures.

Original models remain Quaternius CC0; their provenance is unchanged in
`assets/models/quaternius/LICENSE.md`. The same appearance applies to the large
victory fish. Ambient background schools and the crab are separate later steps.

## Validation

- `tests/fish_appearance_integration.gd`: compares geometry, weights, bind poses
  and verifies actual bone movement for all nine species/animation combinations;
  verifies prepared meshes are shared. PASS in
  `build/fish_material_review/integration.log`.
- Rendered studio helper checks normal/fast/caught animation transitions and
  removal after capture for all three species. Final image: `final_studio.png`.
- `underwater.png` shows the three fish staged together in the actual bay for
  lighting review; their regular school placement is unchanged.
- Full gameplay regression: `build/fish_material_review/smoke.log`.

Captures, logs and the original controller backup are in
`build/fish_material_review/`. No release was published.
