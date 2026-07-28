Milestone 4 tuning iteration 2. Still a tuning pass. Do not advance to
milestone 5.

## 1. Revert the wall cling velocity change

I was wrong last round. Zeroing vertical velocity on wall cling feels bad.
Mistiming a running jump and clipping a wall corner now kills all momentum,
when it should let me bump the wall and keep rising to clear the ledge.

Revert it: entering wall cling preserves existing vertical velocity,
including upward velocity.

IMPORTANT: this must NOT reintroduce the superjump. Those were separate
causes — the superjump came from the stale jump buffer firing a wall jump,
which you fixed independently. That fix stays. The superjump regression test
must still pass after this revert. If reverting brings the superjump back,
the buffer fix was incomplete — tell me rather than re-zeroing velocity.

You have a regression test asserting velocity.y == 0 on cling. Rewrite it to
assert the opposite: upward velocity is preserved through the cling window.
This is an authorized test change because the spec changed. Do not delete
it — invert it.

Also increase the wall cling window by 10%: 12 -> 13 frames.

While you're in here: report whether corner correction is firing when I clip
a wall corner mid-jump. If it isn't, say so — don't change it yet.

## 2. Detach grace should lock horizontal movement

The 8-frame detach grace timing feels right, but the character currently
moves normally during it. It should be pinned.

During wall_detach_grace:
- Horizontal velocity is 0 and horizontal input has no authority
- Vertical behavior is completely unchanged — whatever the wall state was
  doing (cling hang, wall slide, preserved upward momentum) continues exactly
  as it would have
- Wall jump remains available
- When the grace expires, the character detaches and normal movement resumes

The grace is a commitment window, not a slow release.

## 3. Dash should preserve vertical momentum on exit

Upward and diagonal-up dashes stop dead at the end. Vertical exit velocity
should be retained the same way horizontal is — a dash upward should feel
like a launch that carries, not a hard stop.

Not extremely strong. A plausible continuation of the dash speed.

Add a separate exported param rather than reusing the horizontal one:
- dash_exit_retention_vertical: start at 0.6, matching horizontal

Report the new maximum reachable height for a dash-jump, since the level
validity constants depend on it.

## 4. Ability indicators

Add a placeholder visual for remaining abilities:
- A colored line along the TOP edge of the player rectangle = double jump
  available
- A colored line along the BOTTOM edge = dash available

Each disappears when consumed and returns on refill. Different colors.

Placeholder only — this gets replaced by real art later, so keep it fully
decoupled from movement logic and trivial to remove.

## 5. Reset

Implement R to reset (already listed in SPEC section 3, never built).
R returns the player to the level spawn point with all velocity, timers, and
ability charges cleared.

ADDITION I'm making, tell me if you disagree: also add a kill plane below the
level that triggers the same reset automatically. Falling out of the level
currently requires refreshing the page.

There is no room system yet — that's milestone 7 — so reset means level spawn
point, not room start.

## Requirements

- Every change above gets a regression test in the input-playback harness.
- New values are exported MovementConfig fields. No magic numbers.
- Update SPEC.md section 4 to match the config.
- Do not change any value I did not ask you to change. If a fix requires it,
  tell me instead.

## Workflow

Fix -> validate.cmd exits 0 -> rebuild web export to docs/ -> commit -> push.
Report what changed and what to look for when I test.