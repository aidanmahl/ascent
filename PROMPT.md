Milestone 4 tuning iteration 3. Still a tuning pass. Do not advance to
milestone 5.

Everything below is a regression introduced by the last round of changes.
The existing regression suite did not catch any of it.

## Group A — wall state persists after leaving the wall

Symptom: the player keeps the slow descent rate used while clinging to a
wall, and keeps wall-jump availability, after they are no longer on a wall.
Normal gravity never resumes. The state only ends on opposite directional
input.

Consequence: I can chain wall jumps indefinitely without ever consuming a
jump, gaining unlimited height. This breaks the game outright — any level
design is trivially bypassed. Treat it as the highest priority item here.

Reproductions:
1. Wall jump while holding toward the wall.
2. Wall jump with no directional input held.
3. Walk or slide off the bottom edge of a wall without jumping at all.

All three produce the same floating state.

Expected: leaving a wall by any means ends the wall state completely.
Normal gravity resumes immediately. Wall jumps are only available while
actually on a wall or within the brief window after leaving one, and they
cannot be chained to gain height without limit.

Boundary case that currently works correctly — do not break it: wall
jumping while holding away from the wall behaves properly and does not
produce this.

## Group B — abrupt stop when correcting out of the floating state

Symptom: while in the Group A floating state, holding the direction away
from the wall — immediately after the jump or at any point after — halts
the player dead in midair. It ends the floating state, but with a visible
hitch.

Reproductions:
4. After a wall jump held toward the wall.
5. After a wall jump with no directional input.

Expected: transitioning from a toward-wall or neutral wall jump into
opposite-direction movement is seamless. Momentum carries through the
change with no pause, freeze, or velocity reset at any point.

Note that Group B may resolve on its own once Group A is fixed, since the
floating state is its precondition. Verify it directly rather than
assuming.

## New — wall cling indicator

Add a third placeholder ability indicator showing that I am currently
clinging to a wall. Match the existing two in style and placement logic —
somewhere on the player rectangle, visually distinct from the double jump
and dash indicators.

Same constraints as the others: placeholder only, fully decoupled from
movement logic, trivial to remove when real art replaces it.

## Requirements

- Every bug above gets a permanent regression test. The current suite
  missed all six, so add cases that run long input sequences and assert
  bounded outcomes — maximum height reachable from a fixed starting
  position, descent rate after leaving a wall, absence of any single-frame
  velocity drop during direction changes.
- Do not change any tuning value I did not ask you to change. If a fix
  requires one, tell me instead of doing it.
- Any new tunable values are exported alongside the existing ones. No
  magic numbers.
- Keep SPECS.md section 4 in sync with the actual values.

## Workflow

Fix -> validate.cmd exits 0 -> rebuild web export to docs/ -> commit ->
push. Report what changed and what to look for when I test.