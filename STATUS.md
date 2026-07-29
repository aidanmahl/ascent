# Status

## Done — Milestone 3: double jump, dash
- **Fixed a real visibility bug reported during play-testing**, ahead of
  the milestone itself: the placeholder floor/walls existed only as
  collision data, never rendered, so a human running the game saw the red
  player and nothing else. Refactored world scaffolding out of
  `scenes/player.gd` into a new `scenes/main.gd` (the player shouldn't own
  world geometry — CLAUDE.md's "thin shell" rule), which now builds the
  same solid-tile data plus a `ColorRect` per tile, and hands the
  collision data to the player before its first `_physics_process`. Also
  added a `Camera2D` as a child of the player (simple continuous-follow,
  zoomed in 3x) — without it, half the scaffolding (anything left of
  spawn) was entirely off-screen regardless of visuals, which is why
  milestone 2's screenshot attempt came back blank. Verified with
  `tools/screenshot.cmd`: floor and both walls now visible, camera tracks
  the player settling onto the ground. This is still placeholder — SPEC.md
  section 7 wants a per-room snap camera, which is level-framework
  (milestone 7) territory — but continuous-follow is a reasonable stand-in
  and a large improvement over nothing.
- **Dash bound to left Shift specifically** (per your clarification, not
  just "Shift" as SPEC.md section 3 states generically). Verified
  `KEY_SHIFT` (4194325) and `KeyLocation.LEFT/RIGHT` (1/2) empirically
  against this engine rather than guessed, since modifier keys aren't
  ASCII-mapped like the letter keys used so far. The binding is checked
  with a real test (`InputMap.event_is_action()` against synthesized
  left- and right-shift events), not just eyeballed — right shift
  confirmed to NOT trigger dash.
- `src/movement/movement_config.gd`/`default_movement_config.tres`: added
  `double_jump_velocity` (-5.8) and a new Dash group —
  `dash_duration_frames` (12), `dash_speed` (7.0), `dash_cooldown_frames`
  (6), `dash_exit_horizontal_retention` (0.6).
- `src/movement/movement_state.gd`: `double_jump_available`/
  `dash_available` (ability charges), `dash_pressed` (input edge),
  `look_up`/`look_down` (W/S — SPEC.md ties these to camera look, not
  implemented yet, but they're also needed for 8-way dash direction),
  `dash_direction` (locked in per-dash), `facing` (last nonzero horizontal
  input direction, for neutral-input dashes).
- `src/movement/player_movement.gd`:
  - `_apply_jump` gained a third priority tier: ground > wall > double
    jump. `can_double_jump` requires airborne, not touching a wall, and
    the charge available; consumed on fire, doesn't touch coyote/buffer.
  - New `_apply_dash`, pre-empting jump/run/gravity entirely for every
    frame it's active (see "Surprised by" — SPEC.md only explicitly zeroes
    gravity, extending the lockout to jump/run too was a judgment call).
    Direction is 8-way-snapped from held move/look, falling back to
    `facing` when neutral. Cancels immediately on wall contact (refilling
    the charge); otherwise ends after `dash_duration_frames` with exit
    retention applied. `dash_cooldown` is checked before this frame's own
    decrement (same reasoning as coyote/buffer in milestones 1-2) so it
    blocks for exactly 6 frames, not 5.
  - New `_refill_abilities`, run after collision resolution each frame:
    on_floor or either on_wall flag refills both the double-jump and dash
    charges.
- `tests/run_tests.gd`: 11 new tests — all 3 SPEC section 10 rules for
  this milestone (dash exactly 12 frames at constant 7.0 px/frame
  unaffected by gravity, dash refills only on ground/wall contact, double
  jump available once per airborne period), plus direction snapping
  (cardinal/diagonal/neutral-facing), exit retention (horizontal and the
  upward-zeroing case), wall-contact cancellation, and the cooldown
  boundary. 24/24 pass.
- `tools/screenshot.ps1` now checks for `SCRIPT ERROR`/`Parse Error` in
  output the same way `validate.ps1` already did — it was reporting
  `=== OK ===` and saving screenshots even while a scene was erroring
  every physics frame (caught this for real: referenced `state.look_up`/
  `dash_pressed` in `player.gd` before actually adding those fields to
  `MovementState`, and the capture tool silently "succeeded" through it).
- `tools/validate.cmd` passes, 24/24 tests green.

## Milestone 4 — human tuning pass (in progress, gate still open)

Five tuning iterations so far, all against the movement core and the new
`scenes/main.gd` "movement gym" test level (not the real sample level —
that's milestone 10). Full technical detail, exact values, and the wall-
attachment architecture that emerged are in `HANDOFF.md`; this is the
summary.

- **Iteration 1**: fixed wall cling preserving upward velocity through the
  cling window (caused "jump into a wall = launch far above normal
  height" — confirmed the jump-buffer theory in the original bug report
  was wrong before fixing anything). Added `wall_detach_grace` /
  `wall_coyote_time` so wall jump isn't frame-perfect on entry or exit.
  Gravity −10%. Built the movement gym level.
- **Fixed again, properly**: the cling fix above only bounded the
  superjump rather than eliminating it. User pushed back asking why
  "preserving" velocity could ever increase height — root cause was
  freezing a still-decelerating velocity for a fixed zero-gravity window,
  which suspends deceleration a normal jump would've had. Real fix: while
  attached and still rising, gravity behaves identically to being off the
  wall; cling only catches you once you actually stop ascending.
- **Iteration 3**: removed the nudge-based corner correction entirely (it
  never helped jump-corner forgiveness and separately caused an early-
  ledge-drop bug). Replaced with a narrower collision hitbox
  (`collision_width_margin_px`, horizontal only). Run speed/accel −15%.
  Checkerboard visuals for a speed reference.
- **Iteration 4**: acceleration halved again. `wall_detach_grace` +75%.
  Found and fixed two more bugs this surfaced: wall jump during late
  grace silently consuming a double jump instead, and a jarring pause at
  the top of a wall-hugging jump (cling budget was resetting fresh at the
  exact rising-to-falling transition instead of counting continuously
  from first contact).
- **Iteration 5**: softened the wall-jump-lockout boundary (friction now
  decays imparted velocity during the lockout hold instead of a hard
  freeze). Distinguished neutral from away in wall-detach tracking so
  cling can persist indefinitely under neutral input, not just active
  into-pressing.

`tools/validate.cmd`: 37/37 green as of `11d270f`.

**Known issue going into the next session, not yet fixed**: iteration 5's
neutral-input fix appears to have an unintended consequence — wall-slide
descent rate and wall-jump eligibility can persist indefinitely after
actually leaving a wall (not just while still standing neutral beside it),
since nothing in the attachment tracking checks real proximity, only input
state. The user has a detailed bug report already drafted (currently
sitting uncommitted in `PROMPT.md`) with repro steps and test
requirements. See `HANDOFF.md`'s "Known regression" section for the full
diagnosis before starting that fix.

## Next
- **Milestone 4 gate is still open.** Do not proceed to milestone 5
  without approval. Next session starts with the regression above.

## Surprised by / flagging
- **Dash locks out jump and run, not just gravity.** SPEC.md section 4
  only explicitly says "Gravity during dash: 0"; it doesn't say whether
  jump or held movement input can interrupt a dash. Implemented as a full
  lockout (simplest, most predictable — a dash fully owns velocity for its
  duration) rather than letting a jump input cancel/combo out of a dash.
  Worth confirming feel in the milestone 4 tuning pass.
- **Exit-velocity retention lands on the dash's last active frame, not a
  separate 13th frame after it.** SPEC.md lists "Duration: 12 frames" and
  "Exit velocity retention" as separate rows, which could be read as 12
  frames fully at speed *then* retention on the frame after. Implemented
  the simpler version instead — retention is applied within the same call
  that ends the dash (frames 0-10 fully at dash speed, frame 11 already
  shows the retained value) — because deferring it a frame requires an
  extra flag and, worse, lets gravity/friction apply *on top of* the
  retained value that same frame before you can observe it cleanly. Traded
  a strictly-literal 12-frames-then-retention reading for a implementation
  that's simpler and has no observable seam. Flagging since it's a real
  interpretation choice, not a bug.
- **The stale-flag-read pattern flagged after milestones 1 and 2 showed up
  a third time, and this time it directly broke a test** (not just a
  theoretical risk): `_refill_abilities` runs *after* collision resolution
  using fresh flags, so it's the first system in this codebase that
  *can't* be tested by injecting `on_floor`/`on_wall_*` directly via
  `InputPlayback` the way every other wall/floor test does — the injected
  value gets silently overwritten by real (empty-geometry) collision
  before `_refill_abilities` ever reads it. Cost real debugging time
  before I recognized it as the same category of issue. Worth remembering
  as a standing rule: anything reading collision flags *before*
  `_resolve_collision` in the pipeline can be tested with injected flags;
  anything reading them *after* needs real geometry.
- **Camera2D added as a placeholder, ahead of the real per-room camera in
  SPEC.md section 7 (milestone 7 territory).** Simple continuous-follow,
  not the intended "snap per room" design. Flagging so it isn't mistaken
  for the final camera behavior — expect to replace it, not extend it,
  when level framework lands.
