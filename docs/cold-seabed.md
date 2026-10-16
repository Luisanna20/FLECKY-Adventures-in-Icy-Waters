# Cold-coast underwater environment

Completed locally on 2026-10-16. Launch with `PLAY_FLAKI.cmd`.

- `cold_seabed.gd`: a continuous 39,200-triangle seabed with matching triangle
  collision, irregular shelf slopes, 157 collidable boulders and 627 small
  decorative stones batched spatially in MultiMeshes. Ten rock variants share
  materials and meshes. Small stones have no individual collision.
- `cold_kelp.gd`: original cupped ribbon blades replace the angular imported
  plants. There are 130 coastal plant groups and four cave groups. Coastal roots
  are placed by raycast onto the actual ground or rocks after physics sync.
- `underwater_ground.gdshader`: sand, gravel and exposed rock blend by slope,
  height and broad patches; triplanar normal detail, restrained caustics, and
  scanned diffuse/normal/roughness maps replace the uniform blue ground.
- `natural_cave.gd`: a continuous irregular shell replaces the boxes and stacked
  arch stones. Interior, exterior, mouth and back wall share one mesh and matching
  triangle collision. Treasure, octopus and the existing entrance route remain.
- Crabs sample terrain height along their original routes. Boulder placement
  reserves clearance along those routes and around the cave approach.

The style is a cold rocky bay with patchy vegetation, not a scientific species
survey. Existing fish, crab, octopus and treasure assets remain stylized.

## Asset provenance

Poly Haven CC0: [Coast Sand 02](https://polyhaven.com/a/coast_sand_02), Rob Tuytel;
[Rock Boulder Dry](https://polyhaven.com/a/rock_boulder_dry), Dimitrios Savva and
Rico Cilliers. Diffuse/normal maps are 2K, roughness 1K. Exact URLs and SHA-256
hashes are in `assets/textures/cold_coast/sources.json`; source images are unedited.
Existing Low Tide Rocks texture provenance remains in its original directory.

## Verification and local review

- Full rendered gameplay smoke test: PASS in
  `build/seabed_review/final_smoke.log`.
- Physics/placement checks sample 221 ground positions, all 130 coastal roots,
  240 crab-route locations, the four cave wall directions and 25 positions along
  a seal-sized capsule's path into the cave. Rear-wall rays exclude the overlapping
  bay cliff to test the shell itself. Helper: `tools/validate_cold_seabed.gd`.
- Sampled terrain height ranges from -14.59 to -8.38 metres.
- Frame pacing at 1440x810 on the local RTX 2070, capped at 60 FPS: medians
  16.675 / 16.660 / 16.666 ms, 95th percentiles 16.797 / 16.808 / 16.802 ms across
  three underwater views. This is a capped frame-pacing check, not peak throughput.
- Before/after images, backups and logs are in `build/seabed_review/`.
  Final overview: `final_basin.png`; cave: `final_cave.png`.

No public release was made. The earlier accepted seal and water changes remain
in the same local working tree.
