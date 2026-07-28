# Status

## Done — Milestone 1: run, jump, gravity, coyote, buffer, variable height, corner correction
- `src/collision/tile_collision.gd` (`TileCollision`) — new pure module, not
  called out explicitly in SPEC.md's milestone list but required to make
  coyote/buffer/corner-correction genuinely testable rather than faked.
  Discrete (non-swept) AABB-vs-tile-grid resolution: `solid_tiles` is a
  plain `Dictionary[Vector2i, bool]`, so the same function runs against
  real level geometry later and synthetic geometry in tests. X pass then Y
  pass; Y pass attempts a corner-correction nudge (up to
  `corner_correction_px`) before blocking, per SPEC section 4. No engine
  calls — just `Vector2`/`Vector2i`/`Dictionary` math.
- `src/movement/movement_config.gd` and `default_movement_config.tres`
  extended with every SPEC section 4 "Run" and "Gravity & Jump" value
  (wall/dash fields intentionally not added yet — those are milestones 2
  and 3), plus `collider_size` (10×16 per section 2) and `tile_size` (16).
- `src/movement/movement_state.gd` extended with `jump_pressed`/
  `jump_released` (shell-computed input edges) and `on_floor`/`on_ceiling`
  (collision flags, written by the core each frame — also directly
  settable by tests to isolate timer logic from collision resolution).
- `src/movement/player_movement.gd` rewritten: jump decision (coyote +
  buffer + variable-height cut) reads timers *before* refreshing them, so
  the exact frame boundaries in SPEC section 10 land correctly instead of
  being off-by-one — see the doc comment on `_apply_jump` for the two bugs
  this caught during development (a fresh press on a grounded frame was
  getting delayed a frame through the buffer; a jump firing on a grounded
  frame could re-arm coyote to full on its own launch frame via stale
  `on_floor`, handing out a free extra jump). Then run accel/friction/
  turnaround via `move_toward`, gravity with apex-hang and max-fall-speed
  clamp, then `TileCollision.resolve`.
- `tests/framework/input_playback.gd` gained `pulse()` (one-frame edge,
  for `jump_pressed`/`jump_released`) and `merge()` (index-wise combine of
  two frame sequences) — needed once tests had more than one input
  dimension changing at different times.
- `tests/run_tests.gd`: replaced the milestone-0 smoke tests with real
  SPEC section 10 coverage — coyote succeeds at 5 frames / fails at 8,
  jump buffer fires at 6 frames before landing / expires beyond the
  8-frame window, early jump release peaks measurably lower than held,
  corner correction passes a ≤4px clip and still blocks a 9px overlap,
  never tunnels through a floor at max fall speed, plus a regression test
  for the hand-written input map (below). 9/9 pass.
- `project.godot` `[input]`: added `move_left`(A)/`move_right`(D)/`jump`
  (Space) per SPEC section 3. Hand-written `InputEventKey` resource syntax
  is easy to get subtly wrong, so it's covered by an actual test
  (`input_map_binds_move_and_jump_to_spec_keys`) rather than just eyeballed.
- `scenes/player.gd` rewritten to read `move_left`/`move_right`/`jump`
  (via `is_action_just_pressed`/`just_released` for the edges) and pass a
  placeholder flat floor into `PlayerMovement.process` — see "Surprised
  by" below. `scenes/player.tscn` collider/visual resized to 10×16 to
  match `MovementConfig.collider_size`, and given a starting position
  above the placeholder floor.
- `tools/validate.cmd` passes, 9/9 tests green.

## Next
- Milestone 2: wall slide, cling, wall jump.

## Surprised by / flagging
- **Discrete, not swept, collision.** `TileCollision` resolves by moving
  the full axis delta then clamping on overlap, not by sweeping. This is
  only tunnel-safe because every MovementConfig speed (max fall 5.5,
  max run 2.5) stays below `tile_size` (16px) — a single frame's move can
  never fully skip a one-tile-thick wall. The tunneling test asserts that
  precondition explicitly rather than assuming it silently holds, but it's
  worth re-checking once dash (7.0 px/frame, still under 16 — fine for now)
  or any faster movement lands in milestone 3.
- **Added a placeholder floor that SPEC.md doesn't ask for.** Milestone 7
  owns the real room/level framework; nothing before it gives a human
  anything to stand on. Since milestone 4 is a human tuning pass that
  requires actually jumping around and feeling the moveset, `player.gd`
  now builds a flat strip of solid tiles in code (clearly commented as
  scaffolding, not the level system) purely so the interactive scene isn't
  free-falling forever. This is a scope decision beyond "implement
  milestone 1 only" — flagging in case that's unwanted; it's a few lines
  and trivial to delete when milestone 7 lands.
- **Two ordering bugs in the jump logic, both caught by hand-tracing SPEC's
  exact frame numbers before running anything** (not by the test suite
  failing after the fact): (1) a jump press on the same frame the player
  is already grounded would silently get delayed one frame if buffer-vs-
  press weren't merged into one `wants_jump` check; (2) a fired jump could
  re-arm `coyote` to full on its own launch frame (because collision
  resolution — which would correctly flip `on_floor` false — hasn't run
  yet when the jump decision reads it), which would have granted a free
  extra jump within the coyote window immediately after every grounded
  jump. Both are fixed and covered by the coyote/buffer tests, but this
  class of bug (stale flags read before the same-frame update that would
  invalidate them) seems likely to recur in milestone 2's wall logic.
- **Did not launch the interactive game.** CLAUDE.md's process-safety
  section forbids invoking `godot`/`godot_console` outside
  `tools\validate.cmd`, so the shell/input-map wiring is verified by tests
  (including a real `InputMap` binding check) but not by actually pressing
  A/D/Space in a running window. Milestone 4's human tuning pass is the
  first point where that's expected to happen anyway.
- **`sign()` inside a `:=` expression fails GDScript's type inference**
  (`Cannot infer the type of "opposing" variable`) even though the
  expression obviously evaluates to `bool` — `sign()`'s overloaded
  int/float return type seems to be the culprit. Fixed by giving `opposing`
  an explicit `: bool` annotation instead of `:=`. Worth remembering for
  any future code that chains comparisons through `sign()`.
