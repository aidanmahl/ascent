Milestone 4, movement feel overhaul. This is a tuning and refactor pass.
Do not advance to milestone 5.

This changes the underlying feel model, not individual values.

## Do this first

Read the whole prompt. Then stop and write a plan document: how you intend to
break this into subtasks, what you intend to refactor, and which existing
tests the new model invalidates. Notify me and wait for approval before
implementing.

## The goal

Movement feels sluggish. It should feel snappy. Input translates to motion
with as little delay as the physics allow, without the player becoming
weightless or fully overriding momentum from actions.

## 1. Ground direction changes are instantaneous

Pressing the opposite direction while running does not decelerate through a
turnaround. Horizontal speed drops to zero and acceleration in the new
direction begins on the same frame.

Existing speed does not carry into the new direction — the player starts from
zero and accelerates normally.

This must not read as a stop. There should be no frame that feels halted.
The instant transfer is what makes it snappy rather than mushy.

Ground only. Not in the air. Not during a dash (see 4c).

## 2. Air control is responsive but not absolute

The player cannot instantly reverse direction in midair. Velocity from wall
jumps and dashes has to mean something.

Raise air acceleration substantially and reduce carried inertia
substantially. Real authority over the arc, but momentum is fought rather
than overridden.

The transition through zero velocity is quick but present. This is the
deliberate difference from rule 1.

## 3. Double jump redirect

Every double jump carries a horizontal direction and imparts a single
velocity impulse in it. It is NOT an instant direction change — dash is the
only thing that reverses direction instantly.

One tunable impulse value, applied the same way in every situation. Do not
special-case it per movement state. Its interaction with wall jumps and
dashes should fall out of the physics, not out of branching logic.

Starting calibration: from normal running speed it should feel very powerful.
I will tune it against the other cases by hand afterward.

With no direction held, the double jump preserves current horizontal
velocity.

After the redirect, normal rule 2 air movement applies immediately.

## 4. Remove action lockouts

Wall jumps and dashes currently lock the player into their motion. Input has
no authority until the action completes. This is the main source of the
sluggish feel.

The player influences midair velocity immediately during and after any
action, per rule 2. Actions impart velocity; they do not take control away.

### 4a. Dash is a decaying impulse

Dash stops being a fixed-duration, fixed-distance scripted movement. It
becomes a strong directional impulse that decays under normal movement rules.

Gravity applies at all times, including during every dash.

Maximum dash distance is therefore no longer a constant. The level validity
tests that derive gap widths from it need rethinking — propose an approach in
the plan document.

Invariant: dash remains the fastest horizontal movement in the game. Nothing
else should produce more horizontal speed.

### 4b. Dash direction adjustments

- Diagonal upward dashes: increase strength to compensate for gravity now
  applying throughout. They should retain their intended reach.
- Straight upward dashes: do not increase. They were too strong already;
  gravity applying is the correction.

### 4c. Cutting dashes short

Holding the opposite direction after dashing shortens it. Rule 2 air movement
applies during and after, so the dash's higher speed naturally makes this
slower than a normal direction change. That is the intended feel.

The instant ground turnaround from rule 1 does not apply until the dash has
finished. "Finished" is the dash's current nominal duration, and it runs on
that same clock for dashes that begin midair and land partway through. This
window gets communicated to the player through animation later. The player 
should however still be able to counteract the dashes momentum on the ground
like in the previous paragraph, just not to a degree where they can fully cancel 
their horizontal momentum before the dash timer runs out. Dash cooldown also still does not
reset until this timer is finished.

### 4d. Jumping out of a dash

The player can jump immediately after dashing, but explicitly not on the same
frame. Buffer the input so it is not dropped — it fires on the following
frame.

A double jump out of a dash follows rule 3: it slows the player meaningfully
but cannot cancel or reverse the dash, since dash must stay the fastest
horizontal movement. Ensure a dash cooldown is not retained in mid-air after
jumping immediately from a dash. Dash cooldown and timer rules apply for ground contact
from 4c. 

## 5. Wall jump outward velocity

Do not increase wall jump velocity to compensate for the raised air control.
The current values are what I want, or will tune afterwards.
The differences between wall jump types are intentional and should produce 
different outcomes under the new rules:

- Away-from-wall wall jumps carry enough outward speed that air control and a
  directional double jump cannot bleed it off fast enough to regrab the same
  wall in any meaningful timeframe. This is intended.
- Neutral and toward-wall wall jumps impart less outward velocity, so
  regrabbing the wall afterward is possible and intended. It should still not
  be instant — rules 2 and 3 govern how quickly the player can turn around,
  and that delay is what makes it a skill rather than a button press.
- A Neutral wall jump should impart more outward velocity than a toward-wall jump. 
  right now they function identically. Neutral is the middle ground between left and right.
        * Replace the current toward wall jump with the neutral jump, 
            and the new toward wall jump will have less outward momentum than it currently does.

This behavior should emerge from the velocity values and the air control
rules, not from special-cased wall logic (with an exception for the new neutral/toward-wall change,
but air movement rules listed here still apply).

## Refactor

Nine rounds of iteration have accumulated. Refactor the movement logic
wherever these changes make the current structure awkward. Take liberties
with organization, naming, and decomposition.

CLAUDE.md architecture rules hold without exception: pure functions over a
state object, no engine calls in the movement core, all tunable values
exported, no magic numbers.

## Testing

Two rules, and they are different from each other:

- You may rewrite tests that the new movement model has made invalid. Tests
  asserting fixed dash length, turnaround deceleration, or action lockouts
  are describing behavior I have deliberately replaced. Rewrite them against
  the new expected behavior. Never delete them. List every one you rewrite,
  with the old assertion and the new one, in your report.
- You may never weaken, disable, or delete a test to make failing code pass.
  If a test fails and you are not certain whether it is a real regression or
  an invalidated assertion, stop and ask me. Do not decide on your own.

Every behavior above gets regression coverage. No exceptions, no deferrals.

Add these invariant tests, which stay valid regardless of tuning:
- No horizontal speed anywhere in the game exceeds dash speed.
- A directional double jump countering a dash never reverses the dash
  direction.
- After an away-from-wall wall jump, full opposite input plus a directional
  double jump does not return the player to the same wall within a short
  window. Assert a minimum frame count before wall contact is possible.
- No single-frame velocity discontinuity during any direction change except
  the intentional one in rule 1.

Keep SPEC.md in sync with whatever the values end up being.

## Workflow

After approval: implement -> validate.cmd exits 0 -> rebuild web export to
docs/ -> commit -> push. Report what changed and what to look for when I test.