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

- **Iteration 6 — Group A/B regression fix (`PROMPT.md`)**: iteration 5's
  neutral-input freeze had no way to tell "still standing right at the
  wall" from "long gone, floating in open air", since `on_wall_left`/
  `on_wall_right` read identically (false) in both cases once velocity.x
  settles to 0. Symptom: wall-slide fall cap and wall-jump eligibility
  persisted indefinitely after actually leaving a wall by any means (a
  wall jump, or walking off the bottom edge), only ending on active
  opposite-directional input — unlimited wall-jump chaining, height
  unbounded. Fixed with a real position/geometry proximity check
  (`TileCollision.is_touching_wall`, no velocity or input involved) — see
  `player_movement.gd`'s `_update_wall_attachment` doc comment for the
  full diagnosis. This also exposed a second, related bug: the
  wall_detach-grace window's hard pin-to-zero (previously unreachable by
  toward/neutral-fired wall jumps, since they used to freeze wall_detach
  at 0 forever) produced a real freeze-then-snap once it became reachable
  — softened to friction-decay, the same treatment iteration 5 already
  gave the wall-jump-lockout window for the identical reason. Also added
  the wall-cling placeholder indicator (`PROMPT.md`'s third ask) — a
  violet strip on the player's left edge, visible whenever
  `state.wall_attached` (now the single source of truth for attachment,
  read by `_apply_jump`/`_apply_gravity`/the shell alike instead of each
  recomputing it). Four new regression tests cover the three Group A
  repros plus a Group B velocity-continuity check, per `PROMPT.md`'s
  testing requirement (long input sequences, bounded outcomes). One
  existing test (`wall_cling_persists_indefinitely_on_neutral`) had to be
  rewritten against real wall geometry instead of pure flag injection —
  its old technique couldn't distinguish the fixed case from the bug it
  was blind to. No tuning values changed. SPECS.md section 4 updated to
  match.

`tools/validate.cmd`: 41/41 green.

- **Iteration 7 — feel pass after the Group A/B playtest confirmed fixed**:
  - Gravity −10% again (0.405 → 0.365, on top of iteration 1's −10%).
  - `wall_slide_max_fall_speed` −33% (1.5 → 1.0), beyond the general
    gravity reduction, per explicit request ("sliding down walls too
    quickly, beyond the default gravity decrease").
  - `wall_detach_grace` +60% (14 → 22).
  - **Wall cling now initiates from real momentum into a wall, not just a
    held directional key at the moment of impact.** `on_wall_left`/
    `on_wall_right` can only become true on a frame where TileCollision
    detected a collision while resolving a *nonzero* velocity.x move — so
    a real collision already implies real momentum in that direction,
    independent of whether the matching key is currently held. Running
    into a wall off a dash, or off a running jump where the key got
    released before impact, now sticks. Renamed the gating check from
    `_is_pressing_into_wall` to `_touched_wall_with_momentum` to match.
    Explicitly verified this does NOT let a motionless touch (e.g.
    landing at rest against a wall from a purely vertical jump) initiate
    a cling — TileCollision never runs the collision check on a
    zero-velocity axis move in the first place, so there's structurally
    no way to trigger attachment without real horizontal momentum having
    been introduced by *something* (a press or otherwise). Two new
    regression tests cover both directions of this. All prior wall-related
    tests (the Group A/B suite included) re-verified green with no changes
    needed — the momentum condition is a strict relaxation of the old
    held-input condition (every case the old check accepted, the new one
    still accepts), not a separate path.

`tools/validate.cmd`: 43/43 green.

- **Iteration 8 — follow-up bug report on iteration 7's momentum change,
  same session**: "run up to a wall and neutral jump" was clinging when it
  shouldn't. Root cause: `_touched_wall_with_momentum` didn't check
  `on_floor` — grinding against a wall while grounded (holding a direction
  key into it, the "perpetual bump" pattern) is real, repeated contact that
  kept resetting `wall_detach` to 0 the whole time, even though
  `wall_attached` itself correctly stayed suppressed by `on_floor`. The
  instant the player left the ground via ANY jump — even a plain vertical
  one with zero horizontal input — `wall_attached` read that already-zero
  `wall_detach` as a fresh, genuine airborne attach, and the neutral-freeze
  proximity check kept it frozen there since the player hadn't moved away
  horizontally. Fixed by requiring `not on_floor` in
  `_touched_wall_with_momentum` itself, so only genuinely airborne contact
  can ever arm attachment. Confirmed via a failing regression test first
  (per standing practice), then fixed, then green.
  Also: the wall-cling indicator now renders on whichever side (left/right)
  the attached wall actually is, instead of always the left edge — verified
  visually on both sides via `tools/screenshot.cmd`.

`tools/validate.cmd`: 44/44 green.

- **Iteration 9 — feel pass + wall jump input authority, same session**:
  - Gravity −20% (0.365 → 0.292).
  - Jump velocity −40% (-6.5 → -3.9).
  - Ground friction +50% (0.4 → 0.6) and air acceleration roughly doubled
    (0.0765 → 0.15), both per explicit request to reduce turnaround/stop
    "inertia" without increasing general acceleration. `turnaround_
    multiplier` also increased (1.8 → 2.5, not explicitly named but the
    only lever that actually governs turnaround responsiveness — friction
    only applies when input is released, not while actively reversing;
    flagged this reasoning clearly since it goes beyond the literally-named
    values). Ground acceleration itself is untouched.
  - **Wall jumps now grant full input authority immediately — removed
    both the `wall_jump_lockout` window and the `wall_detach_grace`
    horizontal pin entirely.** Per explicit request: distance after a wall
    jump should be precisely controllable by varying hold duration, which
    a scripted no-input-authority window made impossible. This was always
    in tension with SPEC.md section 3's own "Full air control" pillar; the
    wall jump is no longer a special case. `wall_jump_lockout_frames`
    removed from `MovementConfig` entirely (fully dead once the branch
    reading it was gone) — same treatment `corner_correction_px` got when
    it was superseded.
  - Fallout from the accel/turnaround increase: two existing tests that
    held "into the wall" input for many frames after a wall jump started
    legitimately walking the player back into the same real wall (a real,
    correct collision, not a bug) — shortened both holds so they no longer
    race against the new, much stronger reversal rate. Two tests
    (`_test_wall_jump_lockout`, `_test_wall_detach_grace_locks_horizontal_
    movement`) tested mechanisms that no longer exist — rewritten to test
    the new intended behavior (immediate authority, distance scales with
    hold duration) rather than deleted. Three "exact launch velocity" wall
    jump assertions needed a one-frame accel/friction adjustment, same
    pattern already established for vy ("one frame of gravity already
    applied") — now vx gets the same treatment since input authority is
    immediate. Two geometry-fragile tests (using a wall column starting
    just below spawn height) fixed to start well above spawn height
    instead — the much larger air_acceleration let the player reach the
    wall's x-column before falling far enough to vertically overlap it,
    sailing straight through with no collision.

`tools/validate.cmd`: 44/44 green (2 rewritten, not net new — see above).

## Movement feel overhaul (approved plan, full rewrite of rules 1–5)

User: "movement feels sluggish... this changes the underlying feel model,
not individual values." Explicit process this time: read the whole
request, write a plan document (`PLAN.md`) before touching anything, wait
for approval. Plan covered four judgment-call decisions up front (see
`PLAN.md`, still on disk); all four confirmed as-proposed, then
implemented in one pass: config shape → rule 1 (ground) → rule 2 (air) →
rule 5 (wall jump tiers) → rule 3 (double jump) → rule 4 (dash, the
biggest structural change) → new tests → SPECS.md sync.

- **Rule 1 — ground direction changes are instantaneous.** Opposing input
  on the ground no longer decelerates through a turnaround: velocity.x
  drops to 0 and accelerates in the new direction on the SAME frame
  (`move_toward` starting from 0 instead of current velocity) - already
  nonzero in the new direction by the time the frame's math finishes, so
  it never reads as a stop.
- **Rule 2 — air control rewrite.** `air_acceleration` raised again (0.15
  → 0.3) and applied UNIFORMLY regardless of direction - no more
  turnaround-multiplier concept for air (or anywhere). `turnaround_
  multiplier` removed from `MovementConfig` entirely: once ground uses an
  instant snap and air uses one uniform rate, it had no remaining call
  site.
- **Rule 5 — wall jump gets a third tier.** Previously toward-the-wall and
  neutral fired identically; `_fire_wall_jump` is now a real three-way
  branch (away/neutral/toward). New `wall_jump_toward_velocity` field
  `(1.5, -6.0)`, deliberately weaker than neutral `(3.0, -6.5)`, which
  keeps its old number unchanged. Away `(4.0, -6.0)` untouched, per
  explicit instruction.
- **Rule 3 — double jump redirect.** New `double_jump_horizontal_impulse`
  (3.5) is ADDED to existing velocity.x in the held direction, never
  replaces it - vertical launch (`double_jump_velocity`, unchanged) always
  fires regardless. Additive rather than a hard assignment is what makes
  "a directional double jump countering a dash never reverses the dash
  direction" true by construction, not by luck of the tuning.
- **Rule 4 — dash overhaul, the big structural change.** `process()` no
  longer treats dash as a pre-emption branch (`if not dashing: [everything
  else]`) - dash is now just one more step that runs in its normal turn.
  `_apply_dash` renamed `_update_dash`, returns "did a dash just launch
  this frame" instead of "is dash consuming this frame." Gravity applies
  unconditionally every frame now, including a dash's own launch frame.
  Diagonal-up dashes get a new `dash_diagonal_up_vertical_boost` (1.4×,
  Y-only) to compensate for gravity now fighting them the whole way;
  straight-up dashes are explicitly not boosted. `dash_exit_horizontal_
  retention`/`dash_exit_retention_vertical` removed entirely - there's no
  scripted "exit" event left to retain velocity at, decay is continuous.
  4c: while a dash's nominal duration window is still open, even grounded,
  opposing input reuses rule 2's gradual air formula instead of rule 1's
  instant snap (can't fully cancel dash momentum in one frame). 4d: a jump
  pressed the exact frame a dash launches doesn't fire that frame -
  suppressed only in `wants_jump`, so the existing jump_buffer bookkeeping
  still runs off the real press and carries it to the next frame for free.
- **New global invariant: nothing exceeds dash_speed.** One unconditional
  `clampf` on velocity.x at the end of every `process()` call, rather than
  trusted to emerge from careful constant selection across every
  velocity-modifying function. This is also the mechanism that makes
  double jump's additive redirect safe against ever exceeding dash speed
  regardless of future retuning.

**Test suite**: 45 → 54 (9 net new - the 4 explicitly required invariants
plus 5 more per-rule coverage tests). Every existing test PLAN.md flagged
as "definitely invalidated" was rewritten in place (never deleted, per the
two testing rules): `dash_exactly_12_frames_at_constant_speed...` →
`dash_decays_under_gravity_and_normal_movement`; both dash exit-retention
tests → one boundary-continuity test plus one diagonal-boost test;
`wall_jump_neutral_is_weak_and_high` → `..._is_middle_tier` (plus a new
weakest-tier test); the two turnaround-multiplier-dependent wall tests
simplified to the new uniform air formula. Several more needed numeric
adjustment without a rename (one-frame accel/friction already applied to
vx on a wall jump's launch frame, same convention already used for vy).

Three of my own new tests were wrong on the first pass, all caught by
actually running them rather than trusting the derivation (established
practice this session): a dash-window test assumed the gating timer
stayed open one frame longer than it actually does (same read-after-
decrement-same-frame quirk the old wall-jump lockout timer already had -
not a new inconsistency, just one I mis-modeled); a global discontinuity
test read `on_floor` back out of returned state snapshots that were
already overwritten by real (empty-geometry) collision resolution by the
time they were captured - fixed by tracking "was this frame's decision
grounded" from the test's own constructed sequence instead of reading it
back unreliably; a wall-regrab test's second jump press landed inside
`wall_detach_grace`, so it fired ANOTHER (weaker) wall jump instead of the
double jump the test meant to fire, since `can_wall_jump` outranks
`can_double_jump` in priority regardless of actual distance from the wall
- fixed by waiting out the grace window first. That last one also caused
a real back-and-forth on `double_jump_horizontal_impulse` itself: weakened
it from 3.5 to 2.0 to make the (buggy) test pass, then reverted to 3.5
once the test was actually fixed and confirmed 3.5 was fine all along -
worth remembering not to re-tune a value to satisfy a test before
confirming the test itself is asking the right question.

Verified beyond the headless suite too: ran the real scene through
`tools/screenshot.cmd` (run, ground turnaround, dash, jump) - no script
errors, indicators refill correctly, nothing visually broken.

`tools/validate.cmd`: 54/54 green. `SPECS.md` section 4 rewritten in full
to match (ground/air control split, double jump, three wall jump tiers,
full dash section); a forward-looking note added to section 10 about how
future level-validity gap checks should handle non-constant dash distance
(simulate the real movement code rather than deriving a formula - milestone
9 doesn't exist yet, this is documentation only).

## Next
- **Milestone 4 gate is still open.** Do not proceed to milestone 5
  without approval. This is a from-the-plan implementation, not yet
  played by a human - genuinely new mechanics this time (instant ground
  turnaround, decaying dash, additive double jump, three wall jump tiers),
  not just retuned constants. Get this played before anything else stacks
  on top, more than any previous iteration this milestone.

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
