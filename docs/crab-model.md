# Natural crab shell on the existing animation rig

Local update, 2026-10-16. Launch with `PLAY_FLAKI.cmd`.

`crab_model.gd` replaces the old visible monster geometry at runtime with an
original procedural mesh: low scalloped carapace, eight segmented walking legs,
two claw palms with curved fingers, stalked eyes and small mouthparts. A mottled
umber shell shader replaces the strongly emissive orange material.

The Quaternius GLB remains as the source of the skeleton, skin bind poses and
animation library. Walk, threat and dance use the original animation resources.
The rig has body/head/facial bones, not individual leg chains. The new mesh uses
continuous weights along each leg to avoid gaps when the body dances; subtle
alternating shader steps supplement the walk and stop during reactions.
This is an anatomical visual adaptation, not a species reconstruction or full
foot-contact simulation. The imported facial motion contributes only lightly
to the small eyes, mouthparts and moving claw fingers.

Both existing route controllers, voice radius and dance achievement remain.
The visual follows the sampled ground slope; the original terrain-height
convention and route positions are retained. The new mesh has 2,984 vertices
after indexing and one material surface per crab. Bounds cover skin animation
and the extra shader displacement. Source asset attribution remains Quaternius
CC0; in-game credits distinguish the new mesh from the retained animations.

## Verification

- `tests/crab_model_integration.gd`: original skin and three clip resources,
  valid normalized weights, animated bone movement, walking, threat, response
  to voice, dance completion and slope alignment. PASS in
  `build/crab_review/integration_final.log`.
- Studio captures sample all three poses; actual bay captures show walking and
  dancing on the ground. Final underwater captures are `underwater_Walk.png`
  and `underwater_Dance.png` in `build/crab_review/`.
- Full game regression log: `build/crab_review/smoke_final.log`.
- Original controller backup: `build/crab_review/controller.before.txt`.

No release was published. Earlier accepted water, fish and scenery changes remain.
