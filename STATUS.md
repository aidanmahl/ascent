# Status

## Done
- Red 16x16 square (`scenes/player.tscn`) that moves left/right with arrow keys.
- Movement core (`src/movement/`): `MovementState`, `MovementConfig` (exported
  resource, `src/movement/default_movement_config.tres`), and `PlayerMovement`
  as a plain static-method class operating on the state object. No node
  lookups, no `_physics_process`, no engine calls inside the core.
- `scenes/player.gd` is the thin `CharacterBody2D` shell: reads
  `ui_left`/`ui_right` input, calls `PlayerMovement.process`, applies the
  resulting position/velocity.
- `scenes/main.tscn` set as the project's main scene.
- Headless test runner `tests/run_tests.tscn` (`tests/run_tests.gd`) with one
  test asserting x position after 30 frames of right input; exits 1 on
  failure, 0 on success.
- `tools/validate.cmd` passes (`=== OK ===`).

## Next
- Continue with the next milestone in SPEC.md.
