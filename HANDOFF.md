# Handoff notes (for me, not necessarily human-readable)

Renamed from NOTES.md this session. Same deal as before: not part of the
milestone workflow (STATUS.md covers that), safe to keep across sessions,
safe to prune when stale. STATUS.md and `git log` are authoritative if this
and reality ever disagree.

## Where things are right now

Still at the **milestone 4 tuning gate** (SPECS.md section 11 - hard stop,
no milestone 5 work without explicit approval). Iteration 6 (Group A/B
regression fix) got played and confirmed fixed - user came back same
session with iteration 7: a normal feel-tuning pass (gravity, wall-slide
speed, detach grace) plus one real mechanism change (momentum-based cling
initiation, see "Momentum-based cling initiation" below). Both iterations
6 and 7 happened in the same session as each other, so there's only one
chronological log below covering both.

Iteration 7's changes have NOT been played yet - same standing rule as
always, don't treat a from-the-code fix as done until a human confirms it.

Check `git log`/`STATUS.md` for what's actually committed/pushed as of
whenever you're reading this.

## Chronological log this session

1. **Web export infrastructure** (commits `2ee7275` pre-existing,
   `65f10bf` mine): `tools/build-web.cmd`/`.ps1` (600s timeout, same
   pattern as `godot_step.ps1`), Web export preset fixed to output
   `docs/index.html` (was writing to project root), `.gitignore`d nothing
   extra, added `scenes/click_to_start.gd`/`.tscn` (browser audio-gesture
   overlay, pauses tree until clicked), patched
   `tools/capture/screenshot_driver.gd` to synthesize that click so
   headed screenshot verification still works, excluded `tools/`+`tests/`
   from the export filter (first export attempt had accidentally packed
   scratch screenshots into the `.pck`).

2. **Tuning iteration 1** (`ca1445f`): fixed the original two bugs from
   the user's first real playtest -
   - Wall cling preserving upward velocity through a cling window,
     causing "jump into a wall = launch way above normal height" (the
     jump-buffer theory in the original bug report was wrong - confirmed
     via a failing regression test before doing anything - buffer was
     already correctly zeroed on any fire; cling's velocity handling was
     the actual and only cause).
   - Wall jump being frame-perfect on both entry and exit; added
     `wall_detach_grace` and `wall_coyote_time`.
   - Gravity -10% (0.45->0.405) per request, reported new jump
     height/distance.
   - Built the vertical "movement gym" test level in `scenes/main.gd`
     (dash gaps, double-jump platforms, wall-jump shaft, ceiling
     corridor, dash+jump finale) - not the real sample level, milestone
     10 territory.

3. **User pushed back**: didn't understand why the superjump existed if
   velocity is only "preserved" not increased. Explained: freezing a
   still-decelerating velocity for a fixed zero-gravity window suspends
   the deceleration a normal jump would have had - it's an increase in the
   area under the velocity curve, not the instantaneous speed. User's
   fix instruction: **make gravity behave identically on-wall and off-wall
   while still rising; cling only catches you once you stop ascending.**
   Implemented in `5541da4`. This is the mechanism actually in place now -
   see "Wall attachment system" below.

4. **Tuning iteration 3** (`9418220`) - user reported (same message
   twice, "That fixed it" prefix both times, second one added the actual
   asks):
   - Corner correction removed entirely (nudge-based, ceiling-only,
     caused an early-ledge-drop bug by nudging players off ledges during
     floor resolution too - same code path as the ceiling nudge).
     Replaced with `collision_width_margin_px` (2px/side) - actual
     collision width narrower than the visual 10px sprite, horizontal
     only, height untouched.
   - `max_run_speed`/`ground_acceleration`/`air_acceleration` all -15%.
   - Checkerboard visuals (platforms + coarser 64px background layer) for
     visual speed reference. Hit a z-order bug during this (new tile
     rects drew over the player since sibling order changed once the
     background covered the whole frame instead of leaving empty space) -
     fixed with explicit `z_index` (-2 background, -1 tiles, player at
     default 0).

5. **Tuning iteration 4** (`ef096fb`):
   - Acceleration halved again (on top of iteration 3's -15%).
   - `wall_detach_grace` +75% (8->14).
   - Found + fixed: wall jump during late detach grace silently fell
     through to a double jump instead, because `wall_coyote_time` (6) was
     the only thing keeping `can_wall_jump` true past actual contact and
     grace now outlasts it. Added `attached_via_grace` as a third
     `can_wall_jump` condition.
   - Found + fixed: touching a wall early in a jump (common case, e.g.
     climbing the shaft) froze at near-zero velocity for the *entire*
     `wall_cling_frames` window right at the apex - a pause. Root cause:
     `wall_contact` was reset to 0 every rising frame, so crossing to
     vy>=0 always looked like a fresh cling entry. Fixed by counting
     `wall_contact` continuously from first attachment, including the
     rising phase - a long ascent spends the budget before it even
     reaches apex, so gravity just resumes normally.

6. **Tuning iteration 5** (`11d270f`) - three more reports:
   - "Wall jump into a wall janky afterwards, stops abruptly then moves
     back toward the wall" -> lockout was a hard freeze (no friction even),
     so if the player held the original into-direction the whole time, the
     instant lockout ended produced a sudden turnaround-multiplied
     reversal. Fixed: friction now decays velocity.x during the lockout
     HOLD (not the exact fire frame - identified by the timer still
     reading its just-set max value), input still has zero authority.
   - "Wall jump away is inconsistent, sometimes burns a double jump and
     jumps weakly" -> diagnosed (not just patched): neutral and away were
     treated identically in `_update_wall_attachment`, so the natural
     human transition time releasing "into" before committing to "away"
     was silently spending the same finite `wall_detach_grace` budget a
     deliberate wall-jump-away then has to fire within. Flagged to the
     user that sustained away-HOLDING for >14 frames without pressing
     jump would still eventually expire (a separate, narrower case, not
     changed).
   - "Maintain wall cling with no horizontal movement, only if cling was
     initiated by moving into the wall" -> added
     `_is_pressing_away_from_wall` (uses `last_wall_side`, same reasoning
     as `_fire_wall_jump` - `on_wall_*` flags vanish the instant you're
     not actively colliding into the wall, same TileCollision quirk noted
     since milestone 2). Only actual away-pressing now advances
     `wall_detach`; neutral freezes it wherever it is.

7. **Tuning iteration 6, this session**: fixed the Group A/B regression
   from item 6's neutral-freeze fix, per the user's detailed bug report in
   `PROMPT.md` (proximity-gated the neutral freeze, softened the
   detach-grace hard pin, added the wall-cling indicator). Full detail in
   "Group A/B regression fix" below - this item is just the log entry.

8. **Tuning iteration 7, same session**: user played iteration 6,
   confirmed "That fixed the bug," then gave five feel/mechanism asks in
   one message -
   - Gravity -10% again (0.405 -> 0.365).
   - `wall_slide_max_fall_speed` -33% (1.5 -> 1.0), explicitly "beyond the
     default gravity decrease."
   - Wall cling should initiate from momentum into a wall, not just a
     held key at the moment of impact - fixed, see "Momentum-based cling
     initiation" below.
   - Explicit requirement to ENSURE no wall-related regressions from that
     change, AND to ENSURE a motionless touch (vertical jump adjacent to a
     wall) still doesn't initiate cling until real momentum is introduced.
     Both directions covered by new tests; full existing wall suite
     re-verified green with zero test changes needed.
   - `wall_detach_grace` +60% (14 -> 22).

## Group A/B regression fix (this session, iteration 6)

Confirmed the prior session's own diagnosis by re-reading the code fresh
(not from memory) before touching anything, per its own instruction to do
so. It held up: `_update_wall_attachment` froze `wall_detach`
unconditionally on any neutral input, with nothing checking actual
proximity to a wall - so a player who wall-jumped and didn't hold a
direction afterward (or jumped toward the wall, or walked off the bottom
without ever pressing away) got `wall_detach` frozen at whatever it was
mid-jump, and `attached` read true forever.

**Root problem, one level deeper than "check proximity"**: `on_wall_left`/
`on_wall_right` genuinely *can't* distinguish "still standing right at the
wall" from "long gone" once velocity.x has decayed to 0, because
TileCollision only reports a collision on a frame with actual nonzero-
velocity movement into a wall (see "Standing rules" below). Input state
alone was never going to be enough - needed real geometry.

**Fix**: `TileCollision.is_touching_wall(position, collider_size,
solid_tiles, tile_size, collision_width_margin_px, side)` - a pure
proximity probe (no velocity, no collision response, just "is there a
solid tile immediately adjacent on this side of a collider resting here
right now"). `_update_wall_attachment` now takes `solid_tiles` and uses
this to gate the neutral-freeze: neutral only freezes `wall_detach` while
genuinely still adjacent; the moment it isn't (regardless of what
direction, if any, is held), the same countdown that already governed
active away-pressing governs this too - expires within
`wall_detach_grace` frames, same as leaving via active away-pressing
always has.

**Second bug this surfaced, not present before the fix**: toward/neutral-
fired wall jumps used to freeze `wall_detach` at 0 forever (the bug),
which meant they could never actually reach the `wall_detach_grace`
window's horizontal-lock branch in `_apply_run` - only the away case ever
got there, and only because away-pressing blows `wall_detach` straight
past `wall_detach_grace` at fire time, skipping the window entirely. Once
the proximity fix let toward/neutral jumps genuinely traverse
`1..wall_detach_grace`, they hit a branch that had only ever been
exercised by scenarios where velocity.x was already ~0 going in: a real
wall-jump launch velocity, partially decayed by the *lockout* window's
friction, met a hard pin-to-exactly-0.0 in the *grace* window right after
it - a real freeze-then-snap, i.e. Group B. Same fix as iteration 5 already
gave the lockout window for the identical symptom: friction-decay instead
of a hard pin. Confirmed by test
(`wall_jump_toward_wall_then_correcting_has_no_velocity_discontinuity`) -
this is NOT something that would have been caught by reasoning alone, it
took writing the test and running it (first version failed against the
old hard-pin code, in a way that made the mechanism obvious once seen).

**One existing test had to be rewritten, not just left passing**:
`wall_cling_persists_indefinitely_on_neutral` used to inject
`on_wall_left` once with no real geometry at all and expect the freeze to
hold forever - which is exactly the setup that let the original
regression through undetected (a synthetic "was touching once" flag,
disconnected from any real wall, froze forever). Rewrote it against a
real wall column the player is actually still resting against throughout.
This is the same category of thing HANDOFF flagged after two other tests
needed rewriting mid-session last time (neutral vs. away injection) - the
standing lesson is now: anything asserting proximity-dependent behavior
needs real `solid_tiles`, pure flag injection isn't enough once proximity
is part of the logic.

Four new regression tests
(`wall_jump_toward_wall_cannot_chain_for_unlimited_height`,
`wall_jump_neutral_state_ends_after_leaving_wall`,
`wall_state_ends_when_walking_off_bottom_of_wall`,
`wall_jump_toward_wall_then_correcting_has_no_velocity_discontinuity`)
cover the three Group A repros plus the Group B continuity check, as
bounded-outcome assertions per the user's explicit testing requirement in
`PROMPT.md` rather than internal-mechanism checks. The chain-height test's
first draft was itself wrong - it held "into" for the full 120-frame test,
which (correctly, legitimately) let the player drift back into the same
real wall via turnaround acceleration and fire a second, *legitimate* wall
jump; fixed by releasing to neutral after a short window, matching what
the repro actually describes rather than an unbounded hold no real player
would do.

Also added: the wall-cling placeholder indicator (`PROMPT.md`'s third,
unrelated ask) - a violet vertical strip on the player's left edge,
visible whenever `state.wall_attached`. That field is new on
`MovementState` and is now the single source of truth for "currently
attached to a wall" - `_apply_jump`/`_apply_gravity` read it instead of
each recomputing an equivalent expression from `wall_detach`
independently, which is exactly the kind of duplication that let this
regression's fix apply cleanly in one place instead of needing to stay in
sync across two. Verified visually via `tools/screenshot.cmd` (temporarily
moved `main.gd`'s `SPAWN_POINT` next to a wall mid-air to catch a real
attached frame, then reverted - the default spawn geometry lands on a
floor before it would ever reach a wall, so the default gym alone can't
exercise airborne wall-cling in a quick screenshot).

No tuning values were changed. SPECS.md section 4 updated to describe the
new mechanism (proximity-gated neutral freeze, friction-decay detach-grace
window, the new indicator).

## Momentum-based cling initiation (this session, iteration 7)

Renamed `_is_pressing_into_wall` to `_touched_wall_with_momentum` and
dropped its `move_left`/`move_right` requirement - it's now just
`state.on_wall_left or state.on_wall_right`. The insight that made this
safe rather than a guess: `on_wall_left`/`on_wall_right` can ONLY become
true on a frame where `TileCollision._resolve_x` actually ran a collision
check, which itself only happens on a nonzero-velocity axis move (see
`_resolve_x`'s `if vel_x == 0.0: return` guard) - so a real collision
*already* implies real momentum into that side, unconditionally, before
this change ever mattered. The old `and move_left`/`and move_right` was
therefore never doing the job it looked like it was doing - held-input
contact was always a strict subset of "any collision at all," so dropping
it is a pure relaxation (every case the old check accepted, the new one
still does), not a new or parallel code path. That's also exactly why the
motionless-touch boundary (request 5) falls out for free: zero velocity.x
never reaches the collision check in the first place, so there's no
scenario where this could fire without real horizontal momentum having
been present *somehow* - a press, residual friction-decaying momentum
from an earlier press, a dash, whatever.

Spent real effort tracing whether this would break `_test_wall_jump_lockout`
before touching anything, since that test's frame 0 injects `on_wall_left:
true` simultaneously with `move_right: true` (pressing away) - a
same-frame combination that can't arise from genuine physics (if
`move_right` were really held that frame, `_apply_run` would have already
pushed velocity.x positive before collision resolution ran, so a same-frame
`on_wall_left` requires velocity.x negative that frame, contradicting
`move_right`). Worked out that this synthetic-only combination doesn't
actually change the test's *observable* outcome even under the new logic
(traced through why: wall_jump_lockout dominates `_apply_run` regardless of
`_update_wall_attachment`'s classification for the whole 8-frame lockout,
and by the time that stops mattering the specific `wall_detach` value from
frame 0 has already been overwritten several times over) - but treat that
trace as informed prediction, not proof. Actually ran validate.cmd
afterward rather than trusting the trace alone, per the standing "run
tests, don't just reason about them" lesson from the Group B fix earlier
this same session. All 41 pre-existing tests passed unchanged; two new ones
added for the momentum-initiation behavior itself
(`wall_cling_initiates_from_momentum_without_held_input`,
`wall_cling_does_not_initiate_from_motionless_touch`), landing at 43/43.

## Wall attachment system architecture (current, as of this session)

This got fairly intricate over 7 iterations. State (`MovementState.timers`
dict keys unless noted, all in `player_movement.gd`):
- `wall_detach` (int): frames since `_touched_wall_with_momentum` was last
  true. 0 = a real collision happened this frame. Defaults to `wall_detach_grace + 1`
  (already-expired) when absent, NOT 0 - a player who's never touched a
  wall must not read as attached. Advances (not just freezes) whenever
  neither pressing into NOR genuinely still adjacent (per
  `TileCollision.is_touching_wall`) - see this session's fix, above.
- `wall_contact` (int): consecutive ATTACHED frames (see `attached` below),
  counted continuously from first attachment including the rising phase.
  Used only to know when the cling (zero-gravity) sub-window ends.
- `wall_coyote` (int): frames-since-touching, ground-coyote-style,
  refreshed to `wall_coyote_time` whenever `touching_wall` (raw
  `on_wall_left/right`) is true. Mostly redundant now that
  `wall_detach_grace` (14) outlasts it (`can_wall_jump` also checks
  `state.wall_attached` directly), kept for when/if grace is tuned back
  down below it.
- `last_wall_side` (state field, not timers): -1/1/0, remembers which
  wall was last actually touched, since `on_wall_left/right` go false the
  instant you're not actively colliding into the wall (TileCollision only
  checks collision on nonzero-velocity axis moves) - needed by
  `_fire_wall_jump` and `_is_pressing_away_from_wall` once those raw flags
  are gone, and by `TileCollision.is_touching_wall`'s `side` argument.
- `wall_attached` (state field, not timers, new this session): `not
  on_floor and wall_detach <= wall_detach_grace` - computed ONCE, in
  `_update_wall_attachment`, and read directly by `_apply_jump`/
  `_apply_gravity`/the shell (wall-cling indicator) instead of each
  recomputing an equivalent expression independently. This is the single
  source of truth for "currently treated as attached."

`_update_wall_attachment` runs first (inside `if not dashing`, before
`_apply_jump`/`_apply_run`/`_apply_gravity`) so all three see this frame's
fresh `wall_detach`/`wall_attached`, not last frame's stale ones. It now
takes `solid_tiles` (threaded through from `process()`, same dict
`_resolve_collision` uses) to run the proximity probe.

`_apply_gravity` behavior by branch:
- `attached and velocity.y < 0` (still rising): full normal gravity, IDENTICAL
  to unattached. No freeze, no cap. This is the mechanism-level superjump
  fix from step 3 above.
- Otherwise, if `attached`: cling (zero-g, entry clamped to
  `wall_cling_entry_speed_cap`) while `wall_contact <= wall_cling_frames`,
  then falls with `wall_slide_max_fall_speed` cap instead of
  `max_fall_speed`.
- Not attached: normal gravity/max_fall_speed, same as always.

`_apply_jump`: `can_wall_jump := (touching_wall or wall_coyote>0 or
state.wall_attached) and not on_floor`. Priority ground > wall > double,
unchanged since milestone 3.

`_apply_run`: wall_jump_lockout (8 frames) grants zero input authority but
friction still decays velocity.x (iteration 5) except on the exact fire
frame (`wall_jump_lockout == wall_jump_lockout_frames` identifies that).
Then, separately, `in_detach_grace` (`wall_detach` in `1..wall_detach_grace`)
grants zero input authority with velocity.x decaying via friction toward 0
(was a hard pin to exactly 0 before this session - see the Group B fix
above) - this is the "commitment window" lock from an earlier request.
`wall_detach == 0` (actively pressing in) skips this, normal run logic
applies (and gets continuously re-collided/zeroed by TileCollision each
frame, per the perpetual-bump mechanic).

## Current MovementConfig values (src/movement/default_movement_config.tres)

```
max_run_speed = 2.125          (was 2.5; -15% then -50% more = -57.5% total)
ground_acceleration = 0.10625  (was 0.25)
ground_friction = 0.4          (untouched all session)
air_acceleration = 0.0765      (was 0.18)
air_friction = 0.1             (untouched)
turnaround_multiplier = 1.8    (untouched)
gravity = 0.365                (was 0.45; -10% -> 0.405, then a further -10% -> 0.365)
max_fall_speed = 5.5           (untouched - user explicitly said leave it)
jump_velocity = -6.5           (untouched)
jump_cut_multiplier = 0.45
apex_hang_gravity_multiplier = 0.6
apex_hang_threshold = 1.0
coyote_frames = 6
jump_buffer_frames = 8
double_jump_velocity = -5.8
dash_duration_frames = 12
dash_speed = 7.0
dash_cooldown_frames = 6
dash_exit_horizontal_retention = 0.6
dash_exit_retention_vertical = 0.6      (new - was 0% i.e. hard zero)
wall_slide_max_fall_speed = 1.0 (was 1.5, -33%, beyond the general gravity decrease)
wall_cling_frames = 13          (was 12, +10%)
wall_cling_entry_speed_cap = 4.0        (new, now only matters for fast downward catches)
wall_jump_velocity = (4.0, -6.0)
wall_jump_neutral_velocity = (3.0, -6.5)
wall_jump_lockout_frames = 8
wall_detach_grace = 22          (new concept iter1 at 8, then +75% -> 14, then +60% -> 22)
wall_coyote_time = 6            (new, mostly redundant now, see above)
collider_size = (10, 16)        (visual/nominal, unchanged)
tile_size = 16
collision_width_margin_px = 2.0 (new, replaced corner_correction_px entirely)
```

`corner_correction_px` no longer exists as a field - fully removed, not
deprecated/unused.

## Test suite

43 tests, all green as of this session (was 37 last session, +4 for the
Group A/B fix +2 for momentum-initiation, 1 rewritten - see "Group A/B
regression fix" and "Momentum-based cling initiation" above). Two tests from last
session had to be rewritten because they were accidentally exercising
neutral input where they meant to test the away-holding countdown
(`_run_wall_coyote_scenario`, `_test_wall_detach_grace_keeps_cling_attached`)
- worth remembering that distinction when writing new wall tests: injecting
`{"on_wall_left": false, "move_left": false}` alone is NEUTRAL, not
"released/away" - need `"move_right": true` (or equivalent) to actually
test the away-holding path. This session added a second standing lesson on
top of that one: injecting `on_wall_left` directly with empty `solid_tiles`
is fine for testing away-pressing (input-only, doesn't need proximity) but
NOT for testing anything that depends on the neutral-freeze actually
holding - that needs real `solid_tiles` the player is actually resting
against, since `_update_wall_attachment` now checks real proximity via
`TileCollision.is_touching_wall`.

## Still-flagged items carried over from the old NOTES.md, not touched this session

- `PROMPT.md` on disk (once the current draft is committed/replaced) will
  need the milestone-3-era staleness concern re-checked - not urgent.
- Dash still fully locks out jump and run for its whole duration, not just
  gravity (judgment call from milestone 3, never revisited, SPEC only
  requires gravity=0).
- Wall jump pressing back INTO the wall at jump time still falls back to
  the neutral (weak/high) variant - SPEC never defined this case, judgment
  call from milestone 2, never revisited.
- Untested combinatorial surface: dash+wall-jump+double-jump chains beyond
  what's explicitly tested. Priority ordering and dash pre-emption should
  handle them, but genuinely untested end-to-end.
- Camera is still a placeholder (continuous-follow, 3x zoom). Milestone 7
  wants per-room snap. Don't build on top of it expecting it's final.
- Discrete (non-swept) collision is tunnel-safe only because every speed
  stays under tile_size (16px) - dash at 7.0 is the fastest thing and still
  comfortably under, but re-check if any future value approaches 16.
  `collision_width_margin_px` (2px) narrows the hitbox, doesn't change this
  invariant (still governed by full collider_size for the tunneling test).

## Standing rules worth remembering (bit us more than once)

- **Stale vs fresh collision flags**: `on_floor`/`on_wall_left/right`/
  `on_ceiling` read *before* `_resolve_collision` runs (jump decision,
  gravity/cling, `_update_wall_attachment`) are last frame's values -
  testable via `InputPlayback` frame-dict injection. Read *after*
  (`_refill_abilities`) are this frame's real, fresh values - injected
  values get silently overwritten by real (possibly empty) geometry first,
  needs actual solid_tiles in tests, not injection.
- **`on_wall_left/right` only read true while ACTIVELY moving into the
  wall** (nonzero velocity that frame, per TileCollision only checking
  collision on nonzero-velocity axis moves) - the instant velocity.x hits
  0 (blocked, or explicitly zeroed by a lock), the flag goes false again
  next frame regardless of whether you're still touching. This is why
  `last_wall_side` exists and why so much of the wall-attachment logic
  can't just read `on_wall_left/right` directly once you're not pressing
  in anymore.
- Windows PowerShell 5.1's `-Encoding utf8` prepends a BOM that breaks
  Godot's `JSON.parse_string` - use
  `[System.IO.File]::WriteAllText(path, content, (New-Object
  System.Text.UTF8Encoding $false))` for JSON Godot needs to read.
- `nul` and `.claude/` predate this work (well, `.claude/settings.json` is
  now tracked/committed as of the web-export-infra commit - has hooks +
  permissions the user set up themselves for this session, not mine to
  second-guess).

## How to resume

- `tools\validate.cmd` - full suite, must exit 0.
- `tools\build-web.cmd` - rebuilds `docs/`, NOT wired into validate, run
  separately after movement changes if shipping.
- `tools\screenshot.cmd` - headed visual check, writes
  `tools/capture/capture_config.json` (gitignored, scratch) + reads
  `tools/screenshots/*.png` (also gitignored).
- `PROMPT.md` should be back to a stale milestone-3-era instruction (or
  whatever the user last wrote there) once this session's fix is
  committed - re-check it's actually current before trusting it, same
  standing caveat as always.
- **Iteration 6 (Group A/B) got played and confirmed fixed this same
  session. Iteration 7 (feel pass + momentum initiation) has NOT been
  played yet.** That's the next real gate before milestone 5, not just
  "did validate.cmd pass."
