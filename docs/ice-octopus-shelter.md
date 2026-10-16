# Sculpted ice, original octopus and cave refuge

Local update, 2026-10-16. Run `PLAY_FLAKI.cmd`; the published demo is unchanged.

The five floes now share a procedural mesh builder with individual outlines,
snow ridges and eroded edges. Their tapered, uneven undersides extend at most
about 1.5 metres below the water. Snow keeps the existing Poly Haven Snow 02
maps; submerged ice uses a new frost/vein shader with normal detail and a small
transmitted-light approximation for readability. Triangle collision follows
the visible shape. All 20 landing heights follow the new snow surface.

The octopus is an original procedural model: mantle, head, small amber eyes,
eight tapered curved arms and two rows of suckers on each arm. Arm and sucker
vertices share the same deformation so they move together. Mottled skin,
breathing, gentle hovering and the existing nearby-player gaze remain. The old
Poly by Google model and its license are retained as unused source assets.
This is a stylized cold-water animal, not a species reconstruction.

Swimming into the interior of the cave protects Flecky immediately. The shark
waits outside, cannot bite through the protection, then retreats toward the
bay. Leaving before it retreats resumes the hunt. The entrance itself, the
roof and positions outside the walls do not grant protection. A localized
RU/UK/EN message confirms safety inside; the existing ice protection remains.

## Verification

- Full rendered gameplay smoke test: `build/ice_octopus_review/smoke.log`, PASS.
- `tests/ice_cave_integration.gd`: four interior and five exterior positions,
  forced/contact bites, waiting, retreat completion, leaving, existing ice
  safety, all 20 landing/return positions, five shallow collidable undersides.
  Run with Godot `--headless --path . --script res://tests/ice_cave_integration.gd -- --integration`.
- Rendered above/below-water and cave captures: `build/ice_octopus_review/`.

The integration test disables save persistence via its command-line argument.
Visual captures and backups are local and excluded from Git.
