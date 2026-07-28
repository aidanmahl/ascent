Milestone 4 tuning iteration 1. This is a tuning pass, NOT a milestone
advance. Do not start milestone 5. Do not add the gun, enemies, or combat.

Do the movement fixes FIRST, then build the level geometry against the
corrected values. Gravity is changing, which changes jump height and
distance — geometry authored before the fix would be wrong.

## Bugs

### 1. Wall cling preserves upward velocity
Jumping upward into a wall while holding toward it keeps my upward momentum
after I cling. Clinging should arrest all vertical movement.

Suspected cause: the cling state zeroes gravity but does not zero
velocity.y, so existing upward velocity persists through the cling window.

Fix: entering wall cling sets velocity.y = 0. Cling holds position; it does
not preserve upwards momentum. Regular downwards wall-clinging gravity should still apply afterwards.

### 2. Jumping into a wall from the ground launches me far too high
Holding toward a wall while jumping from the ground flings me straight up,
well above normal jump height. It should be an ordinary jump that ends with
me clinging to the wall.

Suspected cause: the jump buffer is not consumed by the ground jump, so when
wall contact registers a frame or two later, the still-live buffered input
immediately fires a neutral wall jump, stacking a second upward impulse.

Investigate and confirm the actual cause before fixing. Do not patch the
symptom. If it is the buffer, the fix is to consume the buffer on any
successful jump and add a short lockout preventing a wall jump within a few
frames of a ground jump.

### 3. Gravity too strong
Reduce gravity 10%: 0.45 -> 0.405.

Report the resulting max jump height and max jump distance in pixels — the
level validity constants depend on them. Leave max fall speed at 5.5 and
tell me whether it should come down too.

### 4. Wall jumping away is frame-perfect
Holding away from the wall releases the cling immediately, so jumping away
requires direction and jump on the same frame.

Add two MovementConfig parameters:
- wall_detach_grace: frames of holding away before the cling actually
  releases. Start at 8.
- wall_coyote_time: frames after losing wall contact during which a wall
  jump still fires. Start at 6.

During the detach grace the player stays attached and a wall jump remains
available.

## Test level geometry

After the fixes land, extend the test level. It is currently too plain to
exercise the moveset.

This is a movement gym for tuning, NOT the sample level from SPEC section 9.
Do not author the real level — that is milestone 10. Keep it functional and
ugly. Placeholder tiles only. But, as the game name implies, the levels will be built upwards. Build a level 
with sufficient vertical taversal for me to test. 

It must let me test, in isolation and in combination:
- overhangs and ceilings I can hit and pass under
- floating platforms that require a double jump to reach
- gaps that require a dash, and gaps that require dash + jump
- a vertical shaft requiring chained wall jumps
- facing walls at several widths, for wall-to-wall climbing
- a long flat run for top speed and stopping distance

Lay it out so I can reach every section without restarting.

## Requirements

- Every bug above gets a permanent regression test in the input-playback
  harness. These are exactly the cases it exists for.
- All new values go in MovementConfig as exported fields. No magic numbers.
- Update SPEC.md section 4 so its listed values match the config.
- Do not change any movement value I did not ask you to change. If a fix
  requires one, tell me rather than doing it.

## Workflow — this is now the standard loop

1. Fix
2. tools\validate.cmd exits 0
3. Rebuild the web export to docs/
4. Commit and push to origin/main
5. Report what changed, and what I should specifically look for when testing

Nothing is done until it is pushed. I test by refreshing the GitHub Pages
link.


After you are done with this, provide me a straightforward bullet point list of values I may want
to tweak and test myself iteratively, and where those values live. 