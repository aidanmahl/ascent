# Movement feel overhaul — implementation plan

Written in response to `PROMPT.md`'s "read the whole prompt, then stop and
write a plan document" instruction. **Nothing in `src/` or `tests/` has been
touched.** This is research and design only — I read the current
`player_movement.gd`, `movement_config.gd`, `movement_state.gd`, the full
test registry (45 tests), and current `SPECS.md` fresh before writing this,
rather than working from memory of nine tuning sessions.

Structure: open questions first (these gate everything else and are the
part most worth your eyes before I start), then the subtask breakdown, then
the supporting detail (config diff, refactor sketch, test impact, the 4a
dash-distance proposal).

---

## Decisions I made that need your confirmation

PROMPT.md is precise about the *feel* it wants but leaves a few mechanical
specifics for me to fill in. I picked the reading that seemed most
consistent with the rest of the document and with existing patterns in the
code, but each of these is a real fork — wrong guesses here cascade into
everything downstream, so flagging before I build on top of them.

### A. `turnaround_multiplier` goes away entirely

Today, "opposing input" is a single concept used almost everywhere:
`rate := accel * (turnaround_multiplier if opposing else 1.0)`, on both
ground and air. Rules 1 and 2 split this into two genuinely different
behaviors:

- **Ground (rule 1):** opposing input snaps velocity.x to 0 *this frame*,
  then accelerates from 0 toward the new target at plain `ground_
  acceleration` — no multiplier involved at all.
- **Air (rule 2):** "raise air acceleration substantially and reduce
  carried inertia substantially" — I'm reading this as: one raised
  `air_acceleration` constant, applied at the *same rate* whether input is
  opposing or matching current velocity. No separate turnaround boost in
  the air either. The "quick but present" transition through zero rule 2
  describes is just what a single large-but-finite acceleration constant
  naturally produces over a few frames — not a distinct mechanic.

Under this reading, `turnaround_multiplier` has no remaining call site in
either domain and I'd remove it from `MovementConfig` entirely (same
treatment `corner_correction_px` and `wall_jump_lockout_frames` got when
they were superseded — CLAUDE.md's "no magic numbers" extends to not
leaving dead ones behind).

**If instead you want air reversal to still be faster than air
continuation-in-the-same-direction** (a real, defensible reading of
"reduce carried inertia" — "inertia" specifically means resistance to
*changing* direction, which a uniform accel doesn't especially target),
say so and I'll keep a multiplier concept for air only, dropped for
ground. Tell me now rather than after I've built the rest on top of one
reading.

### B. Double jump's redirect is additive, not a replacement

Rule 3: *"imparts a single velocity impulse"*, *"NOT an instant direction
change"*, *"with no direction held, preserves current horizontal
velocity,"* and the required invariant *"a directional double jump
countering a dash never reverses the dash direction."*

A wall jump and a dash both work by **replacing** velocity.x outright
(`state.velocity = launch_vector`). If double jump did the same thing, a
double jump fired while holding the opposite direction to a fast dash
would unconditionally reverse it — directly violating the invariant test
PROMPT.md requires. So I'm reading the double jump's horizontal component
as **additive**: `velocity.x += held_direction * double_jump_horizontal_
impulse` (0 when no direction is held, which trivially satisfies "preserves
current horizontal velocity" with no special case needed). This also
means: fired from a near-standstill it can reverse a slow drift (nothing
in rule 3 forbids that — the invariant is specifically about *dashes*,
the fastest thing in the game), but fired against dash speed it can only
*reduce* it, never flip its sign, as long as the impulse magnitude stays
under `dash_speed` — which the global "nothing exceeds dash speed"
invariant requires anyway.

Vertical: rule 3 only ever says "horizontal direction" / "impulse in it."
I'm reading this as **the vertical component is untouched** — the
existing `double_jump_velocity` field keeps meaning exactly what it means
today (a hard-set upward launch, same pattern as the primary jump), and
I'd add one new field, `double_jump_horizontal_impulse: float`, for the
new additive horizontal piece. That's "one tunable impulse value" applied
identically regardless of state, per the letter of rule 3.

**If you actually meant a single 2D impulse vector that replaces (not
adds to) horizontal velocity, with a different mechanism protecting the
anti-dash-reversal invariant (e.g. capping the impulse below whatever the
current speed is), say so** — additive vs. replacing changes the tuning
feel meaningfully (replacing means the double jump always launches at
*exactly* the same speed regardless of what you were carrying in; additive
means a double jump into an already-fast dash launches you faster than
one from a standstill).

### C. Wall jump's new third tier — starting numbers

Rule 5 wants three distinct tiers where there are two today. Concretely:
- **Away** (`wall_jump_velocity`, currently `(4.0, -6.0)`) — **unchanged**,
  you were explicit about this.
- **Neutral** — today's `wall_jump_neutral_velocity` `(3.0, -6.5)` fires
  for *both* "no input" and "holding into the wall." Under the new model
  it fires only for genuinely neutral input, and keeps this same value —
  rule 5 says to reuse today's toward/neutral number for the new neutral
  tier, and since today they're numerically identical, "keep neutral's
  number" and "reuse today's toward number" are the same instruction.
- **Toward** (new) — needs its own, weaker `Vector2`. Nothing in PROMPT.md
  gives me a starting number and you've said elsewhere you'll hand-tune
  these. I'll propose a starting point when I implement this rule
  (something meaningfully weaker than neutral on both axes, in the same
  spirit as how `wall_jump_neutral_velocity` is weaker than `wall_jump_
  velocity` today) and report the exact number in my implementation
  report rather than guessing here — this one doesn't block starting the
  rest of the work, just flagging that "less outward momentum than it
  currently does" is a direction, not a number.

This also needs a genuine 3-way branch inside `_fire_wall_jump` (pressing
away / pressing into / neither), where today there's a 2-way one. That's
the "exception for the new neutral/toward-wall change" rule 5 itself
carves out from "no special-cased wall logic."

### D. Dash's ground-window "gradual, not instant" turnaround reuses `air_acceleration`

Rule 4c: during a dash's nominal duration, even grounded, rule 1's instant
snap-to-zero is suppressed — the player can fight the dash's momentum but
not instantly cancel it. I'm proposing this reuses `air_acceleration` for
that specific window (grounded, but dash-timer still running) rather than
inventing a new tunable — it's functionally "you're on the ground but
your movement authority behaves like rule 2 until the dash timer says
otherwise," and reusing the existing air constant keeps the interaction
"fall out of the physics" (rule 2 already governs "responsive but not
absolute") instead of adding a fourth turnaround-adjacent number to track.
Flag if you'd rather this be its own tunable.

---

## Subtask breakdown

Implementing in this order, validating after each step rather than one
giant rewrite — smaller diffs are easier for both of us to reason about,
and several of these are independent enough to sanity-check in isolation
before the biggest, most structurally invasive piece (dash).

1. **Config changes** — add/remove/rename fields (full diff below),
   update `default_movement_config.tres`. No behavior change yet, just
   the shape.
2. **Rule 1 — ground instant turnaround.** Smallest, most isolated change:
   one branch inside the ground-movement path.
3. **Rule 2 — air control rewrite.** Remove the turnaround-multiplier
   branch for air, raise `air_acceleration`, verify against rule 3/4/5's
   dependencies on it (double jump, dash decay, wall jump aftermath all
   route through whatever this becomes).
4. **Rule 5 — wall jump 3-tier velocities.** Independent of dash; do it
   while the wall-jump code is already fresh in mind from step 3's
   verification pass.
5. **Rule 3 — double jump redirect.** Depends on rule 2 being in place
   ("after the redirect, normal rule 2 air movement applies immediately").
6. **Rule 4 — dash overhaul (4a–4d).** The big structural one: `process()`
   stops treating dash as a pre-emption branch; dash becomes a velocity
   impulse plus a timer that *gates* other behavior (rule-1 suppression,
   cooldown timing, same-frame jump suppression) rather than owning the
   frame outright. Saved for last because it touches `process()`'s
   top-level shape, which everything else in this list also runs inside.
7. **New tests** — the 4 explicit invariants, plus per-rule coverage
   (list below). Written test-first where practical, same as this
   session's bug fixes.
8. **Existing test triage** — fix the ones the new model invalidates
   (rewritten, never deleted — full list below), confirm everything else
   is still actually testing something real and not just no longer
   applicable in spirit.
9. **SPECS.md sync** — full section 4 rewrite to match whatever the
   values and mechanisms end up being, since this isn't a small tuning
   diff this time.
10. **`validate.cmd` clean, `build-web.cmd`, commit, push.** Per the
    workflow section — only after your approval on this plan, and (per
    the two testing rules) I'll stop and ask rather than deciding on my
    own if a failing test's status is ambiguous between "invalidated" and
    "real regression."

---

## Config field changes

| Field | Change | Why |
|---|---|---|
| `turnaround_multiplier` | **Remove** | No call site under decision A above |
| `wall_jump_lockout_frames` | *(already removed, prior session)* | — |
| `dash_exit_horizontal_retention` | **Remove** | No scripted "exit" event left to retain velocity at — decay is continuous now (4a) |
| `dash_exit_retention_vertical` | **Remove** | Same |
| `double_jump_horizontal_impulse` | **Add** (`float`) | Rule 3's new tunable (decision B) |
| `wall_jump_toward_velocity` | **Add** (`Vector2`) | Rule 5's new third tier (decision C) |
| `dash_diagonal_up_vertical_boost` | **Add** (`float`, multiplier) | Rule 4b — extra reach on diagonal-*up* dashes only, to compensate for gravity now applying throughout. Straight-up dashes get no boost (4b is explicit that gravity applying *is* their correction). Applied to the Y component only, so the horizontal component of a diagonal dash — and therefore the global "nothing exceeds dash speed" invariant — is unaffected. |
| `dash_duration_frames` | **Keep, meaning changes** | No longer "how long dash owns the frame" — now "the nominal window rule 4c/4d gate against" (ground-turnaround suppression, cooldown start, jump-buffer-not-same-frame) |
| `dash_speed` | **Keep** | Launch impulse magnitude, unchanged concept |
| `dash_cooldown_frames` | **Keep** | Still starts counting once the nominal duration ends (4c) |
| `double_jump_velocity` | **Keep, vertical only** | Decision B |
| `wall_jump_velocity` | **Keep, unchanged value** | Explicit in rule 5 |
| `wall_jump_neutral_velocity` | **Keep, unchanged value, narrower meaning** | Decision C |
| Everything else | **Unchanged** | `max_run_speed`, `ground_acceleration`, `ground_friction`, `air_friction`, `gravity`, `max_fall_speed`, `jump_velocity`, `jump_cut_multiplier`, apex hang, coyote/buffer, wall cling/slide/detach/coyote, collider fields |

`air_acceleration`'s starting value is already `0.15` from last session's
"decrease inertia" pass — rule 2 asks to raise it "substantially" again
on top of that. I'll pick a concrete new number during implementation and
report it; not blocking the plan.

---

## Refactor sketch

`process()`'s current shape:

```
_apply_dash(state, config)  → true means "skip everything else this frame"
if not dashing:
    _update_wall_attachment(...)
    _apply_jump(...)
    _apply_run(...)
    _apply_gravity(...)
_resolve_collision(...)
_refill_abilities(...)
```

New shape — dash stops being a pre-emption branch and becomes a step that
runs *inside* the normal pipeline, same tier as wall attachment:

```
_update_dash(state, config)       → launches on press (direct velocity
                                     assignment, same as today's start),
                                     decrements the nominal-duration timer,
                                     manages cooldown. Returns/sets whether
                                     a dash launched THIS frame (for 4d's
                                     jump-buffer suppression) and whether
                                     the nominal window is still open (for
                                     4c's ground-turnaround override). No
                                     longer returns "skip everything else."
_update_wall_attachment(...)      → unchanged
_apply_jump(...)                  → unchanged, plus: suppress fires_* on
                                     the exact frame a dash just launched
                                     (existing jump_buffer machinery
                                     already carries the press to next
                                     frame for free - just needs the guard)
_apply_horizontal_movement(...)   → renamed from _apply_run. Ground branch
                                     forks on "is the dash nominal window
                                     still open": instant rule-1 snap if
                                     not, air-style gradual accel (rule 2's
                                     formula, reusing air_acceleration per
                                     decision D) if so. Air branch is
                                     always rule 2, unconditionally -
                                     dash's launch is just a starting
                                     velocity to it now, no special case.
_apply_gravity(...)               → unchanged logic, just always called
                                     now (4a: "gravity applies at all
                                     times, including during every dash")
_resolve_collision(...)           → unchanged
_refill_abilities(...)            → unchanged
```

Double jump's redirect logic stays inline where double jump already fires
inside `_apply_jump` (`elif fires_double:`), just changes from a pure
vertical assignment to vertical-assign-plus-horizontal-add.

Wall jump's 3-way branch is a localized change inside `_fire_wall_jump`
only.

I'm expecting `_apply_horizontal_movement` (the rule 1/2/4c fork) to be
the single most complex function in the file once this lands — this is
exactly the kind of consolidation the "Refactor" section in PROMPT.md
asks for, so I'm not trying to keep every existing function boundary
intact where the new rules cut across them. `_is_pressing_into_wall`/
`_touched_wall_with_momentum`/`_is_pressing_away_from_wall` and the wall-
attachment machinery are untouched by any of this — none of rules 1–5
touch wall *attachment*, only wall *jump velocities* and general air
control.

---

## Dash distance and future level-validity tests (rule 4a's explicit ask)

Milestone 9 (the level-validity suite) doesn't exist yet — we're still
gated at milestone 4 — so this is a documentation-only proposal for how
that future work should approach it, not something I'm implementing now.

`SPECS.md` section 10 currently describes computing "max dash distance"
as a closed-form value derived from config, for asserting no required gap
exceeds it. Under a decaying impulse, dash distance is a function of how
long the player continues holding a direction afterward, whether they're
grounded or airborne, and gravity's pull on any vertical component — not
a single number. **Proposal: don't derive a closed-form formula at all.**
Instead, level-validity's "can this gap be crossed" tests should simulate
the real `PlayerMovement.process()` stepping function directly — the same
pattern the existing input-playback tests already use (e.g. `_test_
ground_jump_into_wall_does_not_overshoot_height` measures a real simulated
trajectory rather than computing one by hand) — running a defined "best
reasonable input" sequence (dash, then continue holding the same
direction, chain a directional double jump if the gap requires it) and
measuring the resulting displacement empirically. This is automatically
correct under any future retuning, since it's driven by the same physics
code the game actually runs rather than a duplicated formula that can
drift out of sync with it — which is exactly the failure mode a fixed
"max_dash_distance" constant has going forward. I'll leave a note to this
effect in `SPECS.md` section 10 now, without touching the (nonexistent
yet) level-validity code itself.

---

## Tests the new model invalidates

Per your two rules: rewritten in place, never deleted, and I'll list old
vs. new assertion for each in the implementation report once done. This
is my current read of which of the 45 existing tests fall into that
bucket — flagging now in case you see one I've misjudged either way.

**Definitely invalidated — testing a mechanism that's being removed or
fundamentally changed:**
- `_test_dash_duration_and_constant_speed` — asserts fixed 12-frame
  constant-speed, gravity-immune dash. Directly contradicted by 4a.
- `_test_dash_exit_velocity_retention`, `_test_dash_exit_retains_upward_
  vertical_velocity` — test the retention fields being removed; there's
  no scripted "exit" event left.
- `_test_wall_jump_grants_immediate_input_authority`, `_test_wall_
  detach_grace_no_longer_locks_horizontal_movement` — both hand-compute
  expected velocity using the current `accel * turnaround_multiplier`
  opposing-input formula, which decision A removes.
- `_test_wall_jump_neutral_is_weak_and_high` — "neutral is the weak one"
  stops being true once "toward" exists as a weaker third tier; needs
  reframing as "neutral is the middle tier," alongside a new test for the
  toward tier specifically.

**Likely needs adjustment, not full rewrite — same property, different
numbers or a widened/shifted setup:**
- `_test_wall_jump_distance_scales_with_hold_duration` — the property
  ("holding longer travels farther") should still hold under rule 2's
  model, but the internal air-formula assumptions may need updating.
- `_test_wall_jump_toward_wall_cannot_chain_for_unlimited_height`,
  `_test_wall_jump_toward_wall_then_correcting_has_no_velocity_
  discontinuity` — both fire while holding "into" at launch time, which
  now selects the new weakest tier rather than today's neutral tier;
  values and possibly hold-duration timings need re-deriving once real
  numbers exist. `_then_correcting` specifically may become redundant
  with the new global "no discontinuity except rule 1" invariant test
  rather than needing its own rewrite — will fold it in if so, subject to
  "never delete without asking" if it stops being needed as a separate
  case.
- `_test_double_jump_available_once_per_airborne_period` — the *charge*
  logic (once per airborne period) is untouched by rule 3, but its
  velocity assertions are pure-vertical and need the new horizontal-
  impulse behavior layered in (or split into a separate test for the
  redirect specifically, leaving this one for the refill/charge logic
  alone).

**Probably fine as-is, will re-verify rather than assume:**
Everything wall-attachment/cling/coyote/detach-grace related (rules 1–5
don't touch attachment, only jump velocities and general air control),
`_test_ground_jump_into_wall_does_not_overshoot_height` (continuous
same-direction ground movement, not a turnaround case), `_test_dash_
cancels_on_wall_contact_and_refills` and `_test_dash_cooldown_blocks_
second_dash` (mechanism changes shape but the specific properties they
assert — refill-on-wall-cancel, cooldown-blocks-for-N-frames — should
still hold under the new dash model), `_test_dash_direction_snapping`,
`_test_dash_bound_to_left_shift_only`, everything not wall/dash/double-
jump related at all (coyote, buffer, variable height, corner/ledge
collision, tunneling, input map).

---

## New tests to add

**The 4 explicit invariants**, as their own dedicated tests, framework-
level (not tied to one specific move) where possible:
1. No horizontal speed anywhere exceeds `dash_speed` — run a battery of
   the fastest-producing sequences (dash, dash + double jump same
   direction, wall-jump-away + double jump same direction, dash into a
   wall-jump-shaft climb) and assert `abs(velocity.x) <= dash_speed +
   epsilon` every single frame of each.
2. Directional double jump countering a dash never reverses dash
   direction — dash, then double-jump holding full opposite input;
   assert `sign(velocity.x)` never flips from the dash's original sign.
3. Away wall jump + full opposite input + double jump doesn't return to
   the same wall within N frames — real geometry, fire away, hold full
   opposite + chain a double jump, assert `on_wall_*` stays false for at
   least N frames. I'll derive a concrete N once the real away/neutral/
   double-jump-impulse numbers exist rather than guessing one now.
4. No single-frame velocity discontinuity except rule 1's intentional
   one — run long, varied input sequences (direction changes on ground,
   in air, across wall jumps, across dashes, across double jumps) and
   assert every frame-to-frame `Δv` matches what the active rule allows
   for that frame (bounded accel/friction step everywhere *except* a
   grounded opposing-input frame, which is explicitly allowed to jump by
   up to a full `target_speed` swing).

**Per-rule coverage**, roughly one test per bullet in PROMPT.md:
- Rule 1: opposing ground input reads as zero-then-accelerate within the
  same frame, not a multi-frame decel. Same-direction ground input is
  unaffected (still normal accel).
- Rule 2: air opposing input decelerates through zero over multiple
  frames (present, not instant) — the ground/air contrast test.
- Rule 3: directional double jump adds the impulse in held direction;
  no-direction double jump leaves velocity.x untouched; vertical always
  fires the same regardless of horizontal input.
- 4a: dash decays under normal accel/friction after launch, gravity
  visibly acts on it every frame including frame 0.
- 4b: diagonal-up dash reaches further (or matches an equivalent
  gravity-free reference) than an unboosted straight-up dash would at the
  same angle; straight-up dash gets no boost.
- 4c: holding full opposite input through an entire *grounded* dash
  reduces but never fully zeroes velocity.x before the nominal duration
  ends; rule-1 instant snap resumes exactly on the frame after.
- 4d: jump pressed on the same frame a dash starts does not fire that
  frame, fires exactly one frame later (buffer carries it); a double jump
  fired immediately out of a dash doesn't grant/refill a dash charge or
  disturb the cooldown clock.
- Rule 5: three-way branch fires the correct tier for away/neutral/toward
  input at launch time; toward produces measurably less outward velocity
  than neutral, which produces measurably less than away.

---

## Things I'm explicitly not touching

- Wall attachment/cling/coyote/detach-grace mechanics — none of rules 1–5
  reference wall *attachment*, only wall jump *velocities* and general
  air control. Leaving `_update_wall_attachment`, `_touched_wall_with_
  momentum`, `TileCollision` alone.
- `main.gd`'s movement-gym level geometry and its comments about
  theoretical jump/dash distances — those will go stale once dash
  distance stops being a constant, but it's placeholder milestone-4
  tuning scaffolding, not the real sample level (milestone 10). Flagging
  rather than fixing opportunistically, since touching it isn't asked for
  and the comments are non-load-bearing.
- Everything outside `src/movement/`, `src/collision/`, `tests/`, and
  `SPECS.md` section 4/10.

---

## Waiting for your go-ahead

Not implementing until you respond. If decisions A–D above all read right
to you, a plain "go" is enough — I'll pick the concrete starting numbers
for the new fields (toward-wall velocity, double-jump horizontal impulse,
diagonal-up boost, the raised air acceleration) during implementation and
report every one of them, same as previous tuning sessions. If any of A–D
should go the other way, tell me which and I'll fold it in before
starting rather than after.
