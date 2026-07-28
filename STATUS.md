# Status

## Done — Milestone 2: wall slide, cling, wall jump
- `src/movement/movement_config.gd`/`default_movement_config.tres`: added
  the SPEC section 4 "Wall" values — `wall_slide_max_fall_speed` (1.5),
  `wall_cling_frames` (12), `wall_jump_velocity` (4.0, -6.0, the strong
  away-from-wall jump), `wall_jump_neutral_velocity` (3.0, -6.5, more
  height/less distance), `wall_jump_lockout_frames` (8).
- `src/movement/movement_state.gd`: added `on_wall_left`/`on_wall_right`
  collision flags, same pattern as `on_floor`/`on_ceiling` — written by
  the core, also directly injectable by tests.
- `src/collision/tile_collision.gd`: the X-pass now reports which side a
  horizontal collision happened on (moving left + collide → wall on the
  left, etc.), so `on_wall_left`/`on_wall_right` come from the same real
  geometry resolution as everything else, not a separate check.
- `src/movement/player_movement.gd`:
  - `_apply_jump` now branches ground vs. wall jump (`can_wall_jump` =
    touching a wall and not on a floor; only considered if a ground jump
    didn't already fire). Direction and strength are resolved at fire
    time: holding away from the touched wall gives the strong jump,
    anything else (including holding back into the wall — SPEC.md doesn't
    define this case, see "Surprised by") gives the neutral one.
  - `_apply_run` skips input entirely while `wall_jump_lockout > 0` (read
    directly off the timer `_apply_jump` already refreshed this same
    frame), so the wall jump's velocity carries through unfought.
  - `_apply_gravity` tracks `wall_contact`, consecutive frames of actively
    pressing into a touched wall while airborne (resets to 0 the instant
    either condition breaks, so letting go drops you immediately rather
    than lagging a frame). First `wall_cling_frames` of contact: gravity's
    acceleration is suspended entirely, so whatever vertical speed you
    arrived with is preserved rather than reset to zero (see "Surprised
    by" — SPEC.md's "zero gravity" is taken literally). After that, normal
    gravity resumes but clamped to `wall_slide_max_fall_speed` instead of
    `max_fall_speed`.
- `tests/run_tests.gd`: 6 new tests — the SPEC section 10 lockout rule
  (input has no authority for 8 frames after a wall jump), cling holds
  velocity.y flat for exactly 12 frames then the slide cap takes over,
  the slide cap clamps immediately even from a faster incoming fall,
  strong vs. neutral wall jump velocities, and one test using real
  `TileCollision` geometry (not injected flags) to prove
  `on_wall_left`/`on_wall_right` actually get set in practice. 15/15 pass.
- `scenes/player.gd`'s placeholder scaffolding now includes two wall
  columns flanking the existing floor, so wall slide/cling/jump has
  something to interact with once a human is testing interactively.
- `tools/validate.cmd` passes, 15/15 tests green.

## Next
- Milestone 3: double jump, dash. Then **milestone 4 is a hard stop** —
  human tuning pass, no further milestones without approval.

## Surprised by / flagging
- **"Zero gravity" during cling is taken literally as "gravity doesn't
  accelerate," not "velocity.y resets to zero."** SPEC.md section 4 says
  only "12 frames of zero gravity on first touch," nothing about resetting
  velocity. So grabbing a wall while falling fast keeps that fall speed
  constant (not accelerating further) for the cling window, then clamps
  down to the slide cap once it ends — it does not "catch" you with a
  snap to near-zero. If the intended feel is a hard catch, that's a
  one-line change (zero `velocity.y` when `wall_contact` transitions from
  0 to 1) — flagging rather than silently picking the snappier-feeling
  interpretation.
- **Pressing back into the wall (not away, not neutral) at wall-jump time
  isn't defined by SPEC.md.** It only names two cases: away (strong) and
  neutral/no-input (weak+high). Implemented so anything that isn't
  "pressing away" — including holding into the wall — falls back to the
  neutral jump. Reasonable default, but a real decision point if it feels
  wrong in the milestone 4 tuning pass.
- **Wall jump has no coyote-style grace window.** Ground jump gets coyote
  time; wall jump requires actually touching the wall *this* frame
  (`on_wall_left`/`on_wall_right` true right now). SPEC.md doesn't mention
  wall coyote, so none was added — but it's a very Ori/Celeste-ish thing
  to want later. Flagging rather than guessing.
- **Tried to visually verify the new wall geometry with the screenshot
  tool and it didn't work — but not because of a wall bug.** There is
  still no `Camera2D` in `main.tscn` (flagged, not fixed, back in
  milestone 1's status), so the viewport only ever shows raw world-space
  from (0,0). The placeholder walls sit left of spawn, and scripting the
  player to walk toward one just walked it further off the left edge of
  frame — every captured screenshot was blank gray. The tool itself
  worked fine (files saved, no errors); there was just nothing in frame
  to capture. Camera framing is now clearly worth doing sooner than
  milestone 7 if visual verification is going to keep being useful.
- **The stale-flag-read ordering bug class predicted at the end of
  milestone 1 did recur, in a milder form.** `_apply_gravity` reads
  `state.on_wall_left`/`on_wall_right` before this frame's collision
  resolution updates them (same pattern as `on_floor` in `_apply_jump`).
  Unlike the coyote bug, this one turned out to be harmless here — being
  one frame stale on wall contact for gravity purposes just means the
  cling/slide state lags a single frame behind a wall touch/release,
  which is unobservable at 60fps and doesn't compound the way the coyote
  bug did — but it's the same shape of risk, worth double-checking by
  hand again for milestone 3's dash (refill-on-wall-contact timing).
