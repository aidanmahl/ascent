# Handoff notes (for me, not necessarily human-readable)

Renamed from NOTES.md this session. Same deal as before: not part of the
milestone workflow (STATUS.md covers that), safe to keep across sessions,
safe to prune when stale. STATUS.md and `git log` are authoritative if this
and reality ever disagree.

## Where things are right now

Still at the **milestone 4 tuning gate** (SPECS.md section 11 - hard stop,
no milestone 5 work without explicit approval). This whole session was
tuning iterations on top of that gate, plus one piece of infra
(web export) done first. Nothing has advanced past milestone 4.

**Working tree is clean except `PROMPT.md`**, which currently holds an
uncommitted draft of the user's *next* bug report (see "Known regression
already written up" below - read that section before doing anything else
next session).

Branch `main`, tracking `origin/main`, everything below is pushed.

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

## Known regression already written up (uncommitted, in PROMPT.md right now)

**I believe iteration 5's neutral-freezes-wall_detach fix is the direct
cause.** The user's draft bug report (currently sitting uncommitted in
`PROMPT.md`) describes: wall-slide descent rate and wall-jump availability
persisting indefinitely after leaving a wall entirely (not just while still
adjacent and neutral), only ending on actively-opposite input, allowing
infinite wall-jump chaining/height. Reproductions listed: wall jump
toward-wall, wall jump neutral, walking off the bottom of a wall without
jumping - all three produce the same floating state. A second group
(abrupt stop when finally correcting out of it) is also flagged, and might
resolve on its own once the first group is fixed (user says verify, don't
assume).

**My diagnosis before even opening the file to fix it**: `_update_wall_attachment`
only resets `wall_detach` to 0 on `pressing_into`, and only increments it
on `_is_pressing_away_from_wall`. If neither is true (truly neutral input),
it freezes wall_detach *unconditionally* - including after a wall jump has
already fired and carried the player far away from the wall entirely. The
intent (this session, my own fix) was "let cling persist while standing
neutral right at the wall" - it does not distinguish that from "player is
nowhere near any wall and just isn't holding a direction," because nothing
in this function checks distance/actual proximity, only input state. A
player who wall-jumps and doesn't hold a direction afterward (or jumps
toward the wall, or lets go without ever pressing away) has `wall_detach`
frozen at whatever it was mid-jump (likely 0 or 1) - `attached` then reads
true forever, so `wall_slide_max_fall_speed` and `attached_via_grace`
(wall-jump eligibility) both persist without limit. This matches every
symptom in the draft report, including "only ends on opposite directional
input" (the only thing that still increments the timer at all).

Likely fix shape (not implemented, do NOT assume this is right without
re-deriving): attachment via grace/neutral-freeze should probably also
require *actual continued proximity* to a wall, not just input state - e.g.
reset/expire wall_detach once genuinely airborne-and-clear (some position
or timeout check), or cap how long neutral can freeze it, or only let
neutral freeze it while still within the *original* wall_detach_grace
window rather than freezing indefinitely. Whatever the fix, it needs to
preserve the two things that were actually requested and are working
correctly per the user's own boundary note ("wall jumping while holding
away from the wall behaves properly, don't break it") - away-pressing
still correctly ends things.

**Do not start fixing this from memory of my own diagnosis alone** - re-read
current `_apply_gravity`/`_update_wall_attachment`/`_apply_jump` in
`src/movement/player_movement.gd` first, the code may have context this
summary doesn't capture, and the user's PROMPT.md draft has more precise
repro steps and an explicit test-writing requirement ("long input
sequences, bounded outcomes - max height reachable, descent rate after
leaving, absence of any single-frame velocity drop during direction
changes") that should drive the actual fix and its tests.

## Wall attachment system architecture (current, as of `11d270f`)

This got fairly intricate over 5 iterations. State (`MovementState.timers`
dict keys, all in `player_movement.gd`):
- `wall_detach` (int): frames since `_is_pressing_into_wall` was last
  true. 0 = pressing in right now. Defaults to `wall_detach_grace + 1`
  (already-expired) when absent, NOT 0 - a player who's never touched a
  wall must not read as attached.
- `wall_contact` (int): consecutive ATTACHED frames (see `attached` below),
  counted continuously from first attachment including the rising phase.
  Used only to know when the cling (zero-gravity) sub-window ends.
- `wall_coyote` (int): frames-since-touching, ground-coyote-style,
  refreshed to `wall_coyote_time` whenever `touching_wall` (raw
  `on_wall_left/right`) is true. Mostly redundant now that
  `wall_detach_grace` (14) outlasts it (`can_wall_jump` also checks
  `attached_via_grace` directly), kept for when/if grace is tuned back
  down below it.
- `last_wall_side` (state field, not timers): -1/1/0, remembers which
  wall was last actually touched, since `on_wall_left/right` go false the
  instant you're not actively colliding into the wall (TileCollision only
  checks collision on nonzero-velocity axis moves) - needed by
  `_fire_wall_jump` and `_is_pressing_away_from_wall` once those raw flags
  are gone.

Key derived values, computed fresh each frame:
- `attached := not on_floor and wall_detach <= wall_detach_grace` -
  computed identically in both `_apply_jump` (as `attached_via_grace`) and
  `_apply_gravity`.
- `_update_wall_attachment` runs first (inside `if not dashing`, before
  `_apply_jump`/`_apply_run`/`_apply_gravity`) so all three see this
  frame's fresh `wall_detach`, not last frame's stale one.

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
attached_via_grace) and not on_floor`. Priority ground > wall > double,
unchanged since milestone 3.

`_apply_run`: wall_jump_lockout (8 frames) grants zero input authority but
friction still decays velocity.x (iteration 5) except on the exact fire
frame (`wall_jump_lockout == wall_jump_lockout_frames` identifies that).
Then, separately, `in_detach_grace` (`wall_detach` in `1..wall_detach_grace`)
pins velocity.x to exactly 0, no friction even - this is the "commitment
window" lock from an earlier request. `wall_detach == 0` (actively
pressing in) skips this, normal run logic applies (and gets continuously
re-collided/zeroed by TileCollision each frame, per the perpetual-bump
mechanic).

## Current MovementConfig values (src/movement/default_movement_config.tres)

```
max_run_speed = 2.125          (was 2.5; -15% then -50% more = -57.5% total)
ground_acceleration = 0.10625  (was 0.25)
ground_friction = 0.4          (untouched all session)
air_acceleration = 0.0765      (was 0.18)
air_friction = 0.1             (untouched)
turnaround_multiplier = 1.8    (untouched)
gravity = 0.405                (was 0.45, -10%)
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
wall_slide_max_fall_speed = 1.5
wall_cling_frames = 13          (was 12, +10%)
wall_cling_entry_speed_cap = 4.0        (new, now only matters for fast downward catches)
wall_jump_velocity = (4.0, -6.0)
wall_jump_neutral_velocity = (3.0, -6.5)
wall_jump_lockout_frames = 8
wall_detach_grace = 14          (new concept iter1 at 8, then +75% -> 14)
wall_coyote_time = 6            (new, mostly redundant now, see above)
collider_size = (10, 16)        (visual/nominal, unchanged)
tile_size = 16
collision_width_margin_px = 2.0 (new, replaced corner_correction_px entirely)
```

`corner_correction_px` no longer exists as a field - fully removed, not
deprecated/unused.

## Test suite

37 tests, all green as of `11d270f`. Two tests I had to rewrite mid-session
because they were accidentally exercising neutral input where they meant to
test the away-holding countdown (`_run_wall_coyote_scenario`,
`_test_wall_detach_grace_keeps_cling_attached`) - worth remembering that
distinction now exists when writing new wall tests: injecting
`{"on_wall_left": false, "move_left": false}` alone is NEUTRAL, not
"released/away" - need `"move_right": true` (or equivalent) to actually
test the away-holding path.

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
- Read `PROMPT.md` FIRST - it currently holds the user's draft next bug
  report (see "Known regression" section above), not a stale milestone
  instruction this time.
