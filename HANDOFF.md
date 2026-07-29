# Handoff notes (for me, not necessarily human-readable)

Renamed from NOTES.md this session. Same deal as before: not part of the
milestone workflow (STATUS.md covers that), safe to keep across sessions,
safe to prune when stale. STATUS.md and `git log` are authoritative if this
and reality ever disagree.

## Where things are right now

**Read this first if you're picking up mid-overhaul: `PLAN.md` (repo
root) is the design record for the current work** - four judgment-call
decisions (turnaround removal, additive double jump, wall-jump tier
starting numbers, dash's grounded-window formula) that the user explicitly
confirmed before implementation started. Don't re-derive those from
scratch; read `PLAN.md` first, it's still on disk and current.

Still at the **milestone 4 tuning gate** (SPECS.md section 11 - hard stop,
no milestone 5 work without explicit approval). The movement feel overhaul
(see its own section below, after the chronological log) is a full rewrite
of rules 1-5 - genuinely new mechanics (instant ground turnaround, a
decaying-impulse dash, an additive double jump redirect, three wall jump
tiers), not retuned constants. It followed an explicit plan-then-approve
process this time (`PLAN.md` written and confirmed before any code
changed) rather than the usual "implement and report" iteration loop
below. **None of it has been played yet.**

Everything below this point (iterations 1-9) is PRE-overhaul history -
still accurate for what happened when it happened, but several of the
mechanisms it describes (`turnaround_multiplier`, dash's fixed-duration
pre-emption, wall jump's two-tier neutral/toward) no longer exist. Treat
the overhaul section as the current state of the wall-jump/dash/double-
jump/run code; treat everything before it as archived reasoning for how
milestone 4 got here.

**Pre-overhaul history starts here.** Iteration 6 (Group A/B
regression fix) got played and confirmed fixed - user came back same
session with iteration 7: a normal feel-tuning pass (gravity, wall-slide
speed, detach grace) plus one real mechanism change (momentum-based cling
initiation). Iteration 7's changes had NOT been played before iteration 8
came in - the user found a real bug in the momentum change (see "Grounded
wall contact must not arm momentum" below) plus asked for the indicator
to track wall side, same session, without ever confirming iteration 7's
feel changes (gravity/wall-slide/grace) played fine on their own. All of
iterations 6-8 happened in this one session, so there's only one
chronological log below covering all three.

**None of iteration 7's feel changes (gravity, wall-slide speed, detach
grace) have been confirmed played yet** - only the momentum-initiation
mechanism got direct feedback (the neutral-jump bug report), not the
tuning values from the same iteration. Don't assume those are dialed in.

Iteration 9 (same session, immediately after iteration 8) is a bigger one:
another feel pass (gravity -20% more, jump velocity -40%, ground friction
+50%, air acceleration ~2x, turnaround_multiplier way up) PLUS a real
mechanism removal - wall jumps no longer lock out horizontal input at all,
see "Full air control after wall jumps" below. None of iteration 9 has
been played yet either.

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

9. **Tuning iteration 8, same session, follow-up on iteration 7's
   momentum change**: "run up to a wall and neutral jump, I wall cling" -
   real bug (user's own "might be something to do with the sprite
   overlapping" guess was wrong, but a good enough lead to go looking).
   Fixed, see "Grounded wall contact must not arm momentum" below. Also:
   "the wall cling indicator on the player should be on the side of the
   wall, not always the left" - fixed in `player.gd`/no movement-core
   change, see that same section.

10. **Tuning iteration 9, same session**: another feel pass, plus "I
    should be able to precisely determine how far away from the wall I
    end up by holding the movement key... right now my movement is
    scripted after a wall jump" -
    - Gravity -20% (0.365 -> 0.292).
    - Jump velocity -40% (-6.5 -> -3.9).
    - "Increase air acceleration and ground friction... do not increase
      acceleration in general, just decrease inertia" - ground_friction
      +50%, air_acceleration ~2x. Also increased turnaround_multiplier
      (1.8 -> 2.5) even though not literally named - friction alone
      doesn't govern active-reversal speed in this architecture (it only
      applies when input is released, not while opposing input is held),
      so it wouldn't have fixed the stated "hard to turn around" complaint
      on its own. Flagged this reasoning explicitly rather than silently
      picking one interpretation.
    - Wall jump input lockout AND the wall_detach_grace horizontal pin
      both removed entirely - see "Full air control after wall jumps"
      below.

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

## Grounded wall contact must not arm momentum (this session, iteration 8)

Follow-up bug report on iteration 7's own change: "run up to a wall and
neutral jump, I wall cling." The user guessed sprite-visual overlap as the
cause; that guess was wrong, but the report itself was accurate and led
straight to the real mechanism once traced.

**Diagnosis, done properly this time (write a failing test FIRST, per
CLAUDE.md, before touching the fix)**: `_touched_wall_with_momentum`
(iteration 7's change) reads `state.on_wall_left`/`on_wall_right` with no
`on_floor` check at all. Running into a wall while grounded and holding a
direction key produces real, repeated collisions every single frame - the
"perpetual bump" mechanic documented since milestone 2 (input
re-accelerates velocity.x into the wall, collision zeroes it, next frame
repeats). Each of those grounded collisions was resetting `wall_detach` to
0, over and over, for as long as the player stood there holding the key -
even though `wall_attached` itself correctly stayed `false` the whole time
(it separately requires `not on_floor`). The bug: the INSTANT the player
left the ground - by firing ANY jump, including a plain vertical one with
zero horizontal input ("neutral jump") - `wall_attached` read that
already-sitting-at-0 `wall_detach` as a brand new, genuine airborne attach.
`_update_wall_attachment`'s neutral-freeze (position-proximity-gated,
correctly, per last session's Group A/B fix) then held it there, because
horizontally the player hadn't moved away from the wall at all - they'd
just gone straight up. So the neutral-freeze mechanism was working exactly
as designed; the actual defect was one level upstream, in what was allowed
to arm `wall_detach` to 0 in the first place.

Wrote `_test_neutral_jump_from_ground_against_wall_does_not_cling` first,
confirmed it failed against the pre-fix code (twice, actually - the first
version of the test had its OWN bug, a geometry setup mistake that made the
setup assertion fail before ever reaching the real check; fixed that, then
got a genuine failure against the real bug). Fix: added `not
state.on_floor` directly into `_touched_wall_with_momentum` - only
genuinely airborne contact can arm attachment now, full stop. Verified
the fix didn't just paper over the assertion by dumping per-frame debug
output (`on_floor`/`on_wall_left`/`vy`/`wall_detach`/`wall_attached`) and
confirming `wall_attached` stayed `false` for the ENTIRE post-jump
sequence, all the way through a full jump arc and landing back on the
floor - not just "the last frame happens to look fine." (The test's FIRST
attempted fix-verification also had a bug of its own: it checked `vy` at
the very last frame of a 40-frame window, but the jump is a plain vertical
hop with no horizontal escape, so the player lands back on the same spot
around frame 37 - by frame 40 `vy` is pinned at 0 from FLOOR contact, not
wall cling, which would have made the assertion misleading in both
directions. Fixed to check peak `vy` reached anywhere while still
airborne instead.) Debug prints removed before committing. 44/44 green.

Also fixed in the same request, unrelated to the movement core: the
wall-cling indicator (`scenes/player.gd`) now repositions itself onto
whichever edge (left/right) matches `state.last_wall_side` instead of
always rendering on the left - `last_wall_side` was already tracked in
`MovementState` for wall-jump-direction purposes, so this is pure
`player.gd`/`player.tscn` work, no `MovementState`/`PlayerMovement`
changes needed. Verified visually both sides via `tools/screenshot.cmd`
(temporarily pointed `main.gd`'s `SPAWN_POINT` at the wall-jump shaft's
col-82 wall, approached from the left this time for a real on_wall_right
contact, confirmed the strip rendered on the right edge; reverted after).

## Full air control after wall jumps (this session, iteration 9)

User: "I should be able to do a into wall wall jump and precisely
determine how far away from the wall I will end up by holding the
movement key for a variable amount of time - right now, it seems like
after a wall jump my movement is scripted and I cant really influence how
far I jump until jump is completed."

This is a design pivot, not a bug fix - removed the two mechanisms that
made a wall jump's aftermath deliberately unresponsive to input:
`wall_jump_lockout` (zero input authority for `wall_jump_lockout_frames`,
friction-decaying the launch velocity) and the `wall_detach_grace`
horizontal pin (same treatment, for the rest of the grace window after
that). Both were intentional "commitment window" design from earlier
sessions - explicitly documented in SPEC.md as such - but always sat in
tension with SPEC.md section 3's own "Full air control" pillar. The user's
request makes that tension resolve in favor of full air control winning
for wall jumps too, no exception.

Implementation is a deletion, not an addition: `_apply_run` no longer has
any special-cased branch before the normal input/accel/friction/turnaround
logic. `_fire_wall_jump` still assigns the launch velocity as a direct,
instant impulse (unchanged) - from the very next frame, that velocity is
just an ordinary starting point for the same rules that govern all other
airborne movement. `wall_jump_lockout` (the timer) is gone from both
`_apply_jump` (where it was set) and `_apply_run` (where it was read) -
nothing sets or reads it anymore, so `wall_jump_lockout_frames` became
fully dead in `MovementConfig` and was removed outright (same treatment
`corner_correction_px` got when milestone 4 tuning iteration 3 superseded
it - CLAUDE.md's "no magic numbers" extends to not leaving unused ones
around either). `wall_detach`/`wall_detach_grace` themselves are untouched
- they still matter for vertical cling and wall-jump re-eligibility, just
lost their one horizontal side effect.

**Real, load-bearing side effect this surfaced**: `turnaround_multiplier`
went from 1.8 to 2.5 in the same session's feel pass, and `air_acceleration`
roughly doubled - meaning the turnaround-boosted deceleration rate
(`air_acceleration * turnaround_multiplier`) more than quadrupled overall
(0.0765*1.8=0.1377 -> 0.15*2.5=0.375). Two existing tests that held "into
the wall" input for ~20 frames after firing a wall jump (to simulate the
old repro of "still holding toward the wall after the jump") started
producing a LEGITIMATE second collision with the real wall in the test
geometry - the much stronger reversal walked the player back into it for
real within the test's window, which is now correct game behavior (you
CAN walk back into a wall and wall-jump again for real), not the
chain-without-contact bug those tests exist to catch. Shortened both holds
to 3 frames (enough to prove "holding into at fire time" without enough
cumulative reversal to ever cross back through vx=0). Also found: three
"exact launch velocity" assertions across other wall-jump tests broke for
an unrelated but related reason - since `_apply_run` now runs
unconditionally, THE LAUNCH FRAME ITSELF also gets one frame of
accel/friction applied to vx, exactly the same "one frame of gravity
already applied" convention these tests already used for vy. Updated to
subtract one frame of `air_acceleration` (when the launch direction has
input pulling toward a lower `max_run_speed` target) or `air_friction`
(when neutral) from the raw launch value.

Two other tests (using a wall column starting at `range(8, 60)`, just
below the player's spawn height) started failing to make contact at all -
`air_acceleration` roughly doubling let the player reach the wall's
x-column while still above the wall's row band (hadn't fallen far enough
yet), so it sailed through empty space with no collision, then kept moving
left indefinitely once past it, never returning. Fixed by starting the row
band well above spawn height (`range(-20, 60)`) instead, removing the race
between horizontal-approach-speed and vertical-fall-speed entirely rather
than trying to re-tune frame counts against it.

New tests: `_test_wall_jump_grants_immediate_input_authority` (opposing
input decelerates via the real turnaround rate starting frame 1, not a
frozen/friction-only curve) and `_test_wall_jump_distance_scales_with_hold_
duration` (the actual functional ask - holding away longer measurably
travels farther than releasing early). `_test_wall_jump_lockout` and
`_test_wall_detach_grace_locks_horizontal_movement` rewritten in place
(renamed to `_test_wall_jump_grants_immediate_input_authority` and
`_test_wall_detach_grace_no_longer_locks_horizontal_movement`
respectively) since the mechanisms they tested no longer exist - per
CLAUDE.md, fix a failing test rather than delete it, and a test asserting
removed behavior needs the same treatment once the removal is deliberate.
44/44 green, no test count change (2 rewritten, not net new, alongside the
above fixes to unrelated pre-existing tests).

## Movement feel overhaul (rules 1-5 full rewrite, later same session)

Different process than every iteration above: user said "huge task, read
PROMPT.md, report your plan in a new document" - wrote `PLAN.md`
(repo root, still on disk, worth reading fresh rather than trusting this
summary), stopped, waited for approval. Four judgment calls flagged in the
plan (see `PLAN.md`'s "Decisions I made that need your confirmation"
section for the full reasoning on each):
- **A**: no turnaround multiplier anywhere - ground gets an instant
  snap-to-zero-then-accelerate, air gets one uniform accel rate regardless
  of direction. Confirmed.
- **B**: double jump's horizontal redirect is ADDITIVE (`velocity.x +=
  direction * impulse`), not a replacement - this is what makes "never
  reverses a dash" true by construction instead of by luck of tuning.
  Confirmed.
- **C**: toward-wall tier's starting number left as "propose one during
  implementation, report it" - not blocking. Landed on `(1.5, -6.0)`.
- **D**: dash's rule-4c grounded-window formula reuses `air_acceleration`
  rather than a new tunable. Confirmed.

All four confirmed as-proposed ("go" with no changes), implemented in one
pass rather than the usual validate-after-each-subtask cadence - GDScript
compiles `run_tests.gd` as one file, so removing a config field (`
turnaround_multiplier`, both `dash_exit_retention*` fields) makes the
ENTIRE test file fail to parse until every reference is fixed, not just
the specific test that used it. Practical effect: implemented rules 1, 2,
5, 3, 4 in that order (matching `PLAN.md`'s dependency ordering) with
`validate.cmd` genuinely broken (compile error, not test failures) the
whole way through, then fixed every touched test in one batch at the end
and got a clean run. Worth remembering for next time this shape of task
comes up: "validate after each subtask" is the right DEFAULT, but a
config-field removal is exactly the case where it can't hold literally,
and that's fine - it doesn't mean skipping validation, it means the first
achievable green checkpoint is later than usual.

**What actually changed** (SPECS.md section 4 has the full user-facing
description now - this is implementation notes, not a restatement):
- `player_movement.gd`'s `_apply_run` split into `_apply_ground_movement`
  and `_apply_air_movement` - genuinely different mechanisms now (instant
  snap vs. uniform gradual accel), not one formula with a multiplier
  switch.
- `_fire_wall_jump` is a real three-way branch now (away/neutral/toward),
  where it used to be a two-way `pressing_away ? strong : neutral` with
  "everything else" silently meaning both neutral AND toward.
- New `_fire_double_jump` (previously just `state.velocity.y =
  config.double_jump_velocity` inline) - vertical still a hard assign,
  horizontal now `+=` in the held direction.
- `_apply_dash` renamed `_update_dash`, no longer returns "is dash
  consuming this frame" (process() no longer branches on it at all) -
  returns "did a dash just launch this frame," consumed only by
  `_apply_jump`'s rule-4d suppression. `process()`'s `if not dashing: [...]`
  wrapper is GONE - wall attachment, jump, run, and gravity all run every
  single frame unconditionally now, dash included. This is the biggest
  structural change in the file - dash went from "owns the frame it's
  active" to "one more velocity-modifying step, same tier as everything
  else."
- New unconditional clamp at the end of `process()`:
  `state.velocity.x = clampf(state.velocity.x, -config.dash_speed,
  config.dash_speed)`. Not asked for explicitly, but required by the
  "no horizontal speed ever exceeds dash_speed" invariant PROMPT.md did
  explicitly require, and it's what makes double jump's additive redirect
  provably safe rather than "safe as long as nobody retunes the impulse
  too high" - flagged this reasoning in the report rather than adding it
  silently.

**Three of my own new tests were wrong on the first run, all caught by
actually executing them** (not by more careful derivation - the derivation
was the thing that was wrong each time):
1. `_test_dash_ground_window_cannot_be_fully_cancelled` assumed the
   nominal-duration gating window stayed open through its own last frame.
   It doesn't - `dash_timer` decrements every frame including the launch
   frame (same as the old, since-removed wall-jump lockout timer did), so
   by the last nominal frame the timer's already hit 0 for THAT frame's
   own decision. Not a new inconsistency, just one I mis-modeled on paper
   the first time. Fixed by checking `dash_duration_frames - 2` as the
   last gated frame instead of `- 1`.
2. `_test_no_velocity_discontinuity_except_rule_1` read `history[i].
   on_floor` back out of the returned state snapshots to classify which
   frames were "grounded" - but on_floor was injected (no real
   solid_tiles in this test), and `_resolve_collision` overwrites it to
   false by the time a snapshot is captured, even on frames where the
   injected value was true for the DECISION that frame actually made.
   Same "stale vs. fresh collision flags" distinction already documented
   further down this file, just a fresh instance of forgetting it. Fixed
   by tracking a parallel `grounded: Array[bool]` from the test's own
   frame construction instead of reading state back unreliably.
3. `_test_away_wall_jump_cannot_regrab_wall_quickly`'s second jump press
   (intended to fire a double jump back toward the wall) actually fired
   ANOTHER wall jump instead - `wall_attached` stays true for the entire
   `wall_detach_grace` window (22 frames) regardless of actual distance
   from the wall (pre-existing behavior, not touched by this overhaul),
   and `can_wall_jump` outranks `can_double_jump` in `_apply_jump`'s
   priority chain. A weak toward-tier wall jump (hard-assigned, not
   additive) fired instead, which behaves completely differently from
   what the test meant to exercise. Fixed by waiting out `wall_detach_
   grace + wall_coyote_time` before the second press, and confirming via
   the double-jump CHARGE (`double_jump_available` going false) that a
   real double jump actually fired before trusting the rest of the
   assertion. This ALSO caused a real back-and-forth on `double_jump_
   horizontal_impulse`: weakened it 3.5 → 2.0 to make the (buggy) test
   pass, then once the test itself was fixed, reverted to 3.5 and
   confirmed it still passed - 3.5 (matching rule 3's "very powerful from
   running speed" calibration guidance) was fine all along; 2.0 was
   quietly undercutting an explicit request to satisfy a test that was
   asking the wrong question. Worth remembering: a test failure on a
   brand-new test is at least as likely to be the test as the code -
   don't retune a real value to appease one before checking which side is
   actually wrong.

Verified beyond the headless suite: ran the real scene through `tools/
screenshot.cmd` (ground run, direction flip, dash, jump) - no script
errors, ability indicators refill correctly, nothing visually broken.
Config field diff: removed `turnaround_multiplier`, `dash_exit_horizontal_
retention`, `dash_exit_retention_vertical`; added `double_jump_horizontal_
impulse` (3.5), `wall_jump_toward_velocity` ((1.5, -6.0)), `dash_diagonal_
up_vertical_boost` (1.4); `air_acceleration` raised again (0.15 → 0.3).
Test count 45 → 54 (9 net new, several more rewritten in place - see
`STATUS.md` for the full old-vs-new assertion list PROMPT.md's testing
rules require).

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

**Superseded by the movement feel overhaul above - this snapshot is
pre-overhaul history, kept for the diff trail, not current values.** See
`src/movement/default_movement_config.tres` directly for what's actually
there now; the overhaul section has the specific field-level diff
(removed: `turnaround_multiplier`, both `dash_exit_retention*` fields;
added: `double_jump_horizontal_impulse`, `wall_jump_toward_velocity`,
`dash_diagonal_up_vertical_boost`; changed: `air_acceleration` 0.15→0.3).

```
max_run_speed = 2.125          (was 2.5; -15% then -50% more = -57.5% total)
ground_acceleration = 0.10625  (was 0.25; untouched this session - explicit request not to)
ground_friction = 0.6          (was 0.4, +50% this session - "decrease inertia" request)
air_acceleration = 0.15        (was 0.0765, ~+96% this session - same request)
air_friction = 0.1             (untouched)
turnaround_multiplier = 2.5    (was 1.8, this session - not literally named in the request but
                                 the only lever that actually governs active-reversal speed;
                                 friction alone doesn't touch the opposing-input case, see above)
gravity = 0.292                (was 0.45; -10% -> 0.405 -> -10% -> 0.365 -> -20% -> 0.292, three sessions)
max_fall_speed = 5.5           (untouched - user explicitly said leave it)
jump_velocity = -3.9           (was -6.5, -40% this session)
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
wall_detach_grace = 22          (new concept iter1 at 8, then +75% -> 14, then +60% -> 22)
wall_coyote_time = 6            (new, mostly redundant now, see above)
collider_size = (10, 16)        (visual/nominal, unchanged)
tile_size = 16
collision_width_margin_px = 2.0 (new, replaced corner_correction_px entirely)
```

`corner_correction_px` and `wall_jump_lockout_frames` no longer exist as
fields - both fully removed, not deprecated/unused, when the mechanisms
using them were removed/superseded.

## Test suite

54 tests, all green as of this session's movement feel overhaul (was 45
right before it - see the overhaul section above for the full breakdown of
what's net-new vs. rewritten-in-place). Everything below this point is
pre-overhaul history.

44 tests, all green earlier this session, pre-overhaul (was 37 last session, +4 for the
Group A/B fix, +2 for momentum-initiation, +1 for the grounded-contact
fix, +2 new/-2 rewritten net zero for the wall-jump-input-authority change
- see "Group A/B regression fix", "Momentum-based cling initiation",
"Grounded wall contact must not arm momentum", and "Full air control after
wall jumps" above). Two tests from last
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
  session. Iterations 7-9's feel/mechanism changes were never confirmed
  played before the movement feel overhaul landed on top of them. The
  overhaul itself (rules 1-5, full rewrite - see its own section above)
  has NOT been played at all - it's a from-the-plan implementation, not
  yet touched by a human with a keyboard.** That's the next real gate
  before milestone 5, not just "did validate.cmd pass" - and more so than
  any previous point in milestone 4, since this changed actual mechanics
  (instant ground turnaround, decaying dash, additive double jump, three
  wall jump tiers) rather than retuned constants on unchanged mechanics.
  Strongly worth getting this played in isolation before anything else
  stacks on top - `PLAN.md` (repo root) has the design reasoning if
  something feels off and you want to know whether it's a bug or a
  deliberate choice worth revisiting.
