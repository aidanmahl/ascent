# SPEC.md — 2D Precision Platformer

Read this alongside `CLAUDE.md`. `CLAUDE.md` governs *how* you work.
This file governs *what* you build.

---

## 1. Pillars

1. **Movement first.** Ori-style expressive traversal: double jump, wall
   mechanics, dash, full air control. If movement feels wrong, nothing
   downstream matters.
2. **Readable combat.** Enemies and projectiles are always dodgeable by a
   player who is paying attention. Every projectile follows a pattern the
   player can learn.
3. **Extensible.** One level and two enemies ship now. Adding the tenth level
   and the eighth enemy type must not require touching the core.

---

## 2. Architecture (non-negotiable)

Restating from `CLAUDE.md` because it governs every milestone:

- Movement logic is a plain GDScript class operating on a state object
  (position, velocity, input flags, timers, collision flags). No node
  lookups, no `_physics_process`, no engine singletons inside it.
- The `CharacterBody2D` node is a thin shell: gather input → call the
  movement core → apply the result.
- Same rule for enemy AI and projectile motion: pure stepping functions over
  state, so a headless test can run 10,000 frames in milliseconds.
- 60 physics ticks/sec. All tuning values in **frames** and **pixels**.
- Tile size: **16px**. Player collision box: **10 wide × 16 tall** (visual
  sprite size - the actual collision width used for tile resolution is
  narrower, see `collision_width_margin_px` in section 4).

---

## 3. Controls

| Action | Binding |
|---|---|
| Move | `A` / `D` |
| Look up / down (camera offset) | `W` / `S` |
| Jump / double jump / wall jump | `Space` |
| Dash | `Shift` |
| Fire | Left mouse |
| Aim | Mouse position |
| Restart room | `R` |

Full air control. No fall damage. No terminal-velocity death.

---

## 4. Movement spec

All values live in a single `MovementConfig` resource with `@export` on every
field. These are **starting values to be tuned by hand**, not final. Treat
them as the initial state of a knob, not as a requirement.

### Run
| Param | Value |
|---|---|
| Max run speed | 2.125 px/frame (reduced 15% from 2.5 in milestone 4 tuning) |
| Ground acceleration | 0.10625 px/frame² (reduced 15% then 50% more from 0.25) |
| Ground friction | 0.40 px/frame² |
| Air acceleration | 0.0765 px/frame² (reduced 15% then 50% more from 0.18) |
| Air friction | 0.10 px/frame² |
| Turnaround multiplier | 1.8× accel when input opposes velocity |

### Gravity & jump
| Param | Value |
|---|---|
| Gravity | 0.365 px/frame² (reduced 10% from 0.45, then a further ~10% to 0.365, both in milestone 4 tuning) |
| Max fall speed | 5.5 px/frame |
| Jump velocity | -6.5 px/frame |
| Double jump velocity | -5.8 px/frame |
| Jump cut (on early release) | velocity × 0.45 |
| Apex hang | gravity × 0.60 while `abs(vy) < 1.0` |
| Coyote time | 6 frames |
| Jump buffer | 8 frames |

Double jump refills on ground contact and on wall contact.

**Corner correction was removed in milestone 4 tuning iteration 3** (the
nudge-based version only handled the ceiling case, so it never made jumping
into a platform corner more forgiving anyway, and it separately caused an
early-ledge-drop bug by nudging players off ledges during floor resolution
too). Replaced by `collision_width_margin_px` under Collider, below.

### Wall
| Param | Value |
|---|---|
| Wall slide max fall speed | 1.0 px/frame (reduced from 1.5, beyond the general gravity reduction, in milestone 4 tuning) |
| Wall cling | 13 frames of zero gravity on first touch with real momentum into the wall |
| Wall jump velocity | (±4.0, -6.0) |
| Wall jump input lockout | 8 frames of no horizontal input authority |
| Wall detach grace | 22 frames of actively holding away (or genuinely not touching) before cling actually releases (8 -> +75% -> 14, then +60% -> 22, across two milestone 4 tuning sessions) |
| Wall coyote time | 6 frames after losing wall contact during which a wall jump still fires |
| Wall cling entry speed cap | 4.0 px/frame max magnitude of velocity.y carried into a cling while falling or at rest |

Wall jump away from the wall is the strong one. Neutral wall jump (no
directional input) launches at (±3.0, -6.5) — more height, less distance. A
wall jump remains available for the *entire* `wall_detach_grace` window, not
just `wall_coyote_time` after losing contact — `wall_detach_grace` is now
longer than `wall_coyote_time`, so without this a jump pressed late in grace
used to silently fall through to a double jump instead, burning a charge it
shouldn't have touched.

**While attached to a wall and still rising (velocity.y < 0), gravity behaves
exactly as it would off the wall** — normal decay, no freeze. The wall only
"catches" you once you actually stop ascending: from that point, cling
applies (zero gravity, entry speed clamped to `wall_cling_entry_speed_cap`)
for `wall_cling_frames`, then the usual `wall_slide_max_fall_speed` cap.

(Milestone 4 tuning iteration 2 took three passes to get here. First: cling
preserves entry velocity outright. This reopened a bug where jumping into a
wall from the ground flung the player far above normal jump height — not
because velocity was ever *increased*, but because freezing a
still-decelerating velocity for a fixed zero-gravity window suspends the
deceleration a normal jump would have had, adding height a decaying
trajectory wouldn't have covered. Second: capped entry speed instead of
arresting it — bounded the overshoot but didn't address why it happened.
Third, this version: don't freeze rising velocity at all. Since it decays
naturally the same as off-wall, there's nothing left to bound for the rising
case — the entry cap now only matters for a genuinely fast downward catch.)

**The cling window (`wall_cling_frames`) is a total attachment-duration
budget, not a grant reset when rising stops** (milestone 4 tuning iteration
4). It starts counting the moment a wall is first touched, including while
still rising. A long attached ascent (touching a wall early in a jump, well
before its natural apex) will have already spent the budget by the time it
stops rising, so gravity resumes immediately — a normal transition into
falling. Without this, the budget reset fresh at the exact instant rising
stopped, freezing at whatever near-zero velocity was there right at the apex
for the whole window — a jarring pause. Grabbing a wall already at or near
rest still gets a hold for whatever budget remains, same as before. Since
`wall_detach_grace` (22) is now longer than `wall_cling_frames` (13), the
cling (zero-gravity) portion can run out before grace itself does — from
that point the player is still attached (wall-slide-capped falling, wall jump
still available) for the remainder of grace, just no longer frozen.

**Cling initiates from real momentum into the wall, not just a held
directional key at the moment of impact** (milestone 4 tuning iteration 7).
`on_wall_left`/`on_wall_right` can only become true on a frame where an
actual collision was detected while resolving a *nonzero* velocity.x move
into that side — so a real collision already implies real momentum in that
direction, regardless of whether the matching key happens to be held at that
exact instant. Running into a wall mid-air off a dash, or off a running jump
where the direction key got released before impact, now sticks. The reverse
also holds and was an explicit requirement: a motionless touch — e.g.
landing at rest against a wall via a purely vertical jump, zero horizontal
velocity throughout — never runs the collision check at all (it only runs
on a nonzero-velocity axis move), so it can never initiate a cling by
itself. Attachment only becomes possible once real horizontal momentum is
actually introduced, whether by a press or otherwise.

Momentum-based initiation only counts while airborne. Running into a wall
while still on the ground (e.g. holding a direction key against it before
jumping) does not arm attachment — running up to a wall and then jumping
straight up with no horizontal input (a "neutral jump" performed right next
to a wall) does not cling. Grounded wall contact is real, repeated contact
(the perpetual-bump pattern any held-into-a-wall input produces) that would
otherwise arm the same momentum check the instant the player left the
ground via any jump, even one with no horizontal component at all — not
what "momentum into the wall" is supposed to mean.

During `wall_detach_grace`, horizontal input has no authority — a commitment
window, not a slow release. Velocity.x decays toward 0 via friction during
this window rather than being hard-zeroed (see the lockout paragraph below —
same fix, same reason). Vertical behavior (cling/slide/preserved momentum) is
unaffected, and a wall jump remains available throughout.

**Only actively pressing away, or genuinely no longer near a wall, advances
the detach countdown — neutral input while still actually beside a wall does
not** (milestone 4 tuning iteration 5, refined in the following tuning
session after a regression report). Cling persists indefinitely under
neutral input while genuinely still at the wall, matching the "no stamina
meter" rule below. This also removes a likely source of "wall jump away
feels inconsistent" reports: the natural human transition time between
releasing into and committing to away no longer quietly spends the same
finite budget a deliberate wall-jump-away then has to fire within.

Iteration 5's first version froze the detach countdown on *any* neutral
input, with no check on whether a wall was actually still there — `on_wall_
left`/`on_wall_right` alone can't tell "released into, still standing right
at the wall" from "long gone, floating in open air with nothing held",
since both read identically (false) the moment velocity.x settles to 0 —
`on_wall_left`/`on_wall_right` only report a collision on a frame with
actual nonzero-velocity movement into a wall, so releasing "into" (letting
friction settle velocity.x to rest) reads as leaving instantly whether or
not the player is still standing right there. That let wall-
slide fall cap and wall-jump eligibility persist indefinitely after actually
leaving a wall by any means — a jump, or walking off the bottom edge — only
ending on active opposite-directional input, and made wall jumps chainable
for unlimited height. Fixed with a real position/geometry proximity check
(no velocity or input involved) instead of relying on input state alone:
neutral only freezes the countdown while genuinely still adjacent to a wall;
the moment it isn't, the same countdown that already governed active
away-pressing governs this too — a brief `wall_detach_grace`-frame window
after leaving, not forever.

**Wall jump input lockout still grants zero input authority for its full 8
frames, but friction now applies during it** (previously velocity.x was
completely frozen, not even decaying). If the player held the original
into-the-wall direction the whole time, the instant lockout ended used to
produce a sudden turnaround-multiplied reversal back toward the wall — an
abrupt stop-then-snap-back. Friction decaying the imparted velocity during
the hold softens that transition without granting any input authority. The
detach-grace window right after it got the identical treatment for the
identical reason, once a toward/neutral-fired wall jump could actually reach
it (previously it couldn't, on account of the bug two paragraphs up).

**No stamina meter.** Wall hold is time-limited by the cling window, not by a
draining resource. This is Ori, not Celeste.

**Wall cling has a placeholder indicator**, same as double jump and dash — a
third strip on the player rectangle, visible whenever the movement core
reports the player as currently wall-attached. It renders on whichever edge
(left/right) the attached wall is actually on, not a fixed side.

### Dash
| Param | Value |
|---|---|
| Duration | 12 frames |
| Speed | 7.0 px/frame |
| Direction | 8-way snap from WASD; neutral input dashes in facing direction |
| Gravity during dash | 0 |
| Cooldown after dash ends | 6 frames |
| Exit velocity retention | 60% horizontal, 60% vertical if upward |
| Refill | on ground contact OR wall contact |

Dash cancels on wall contact. Dashing into the ground at a downward angle
preserves horizontal speed — this is the seed of an emergent speed tech and
is intentional. Do not "fix" it.

### Collider
| Param | Value |
|---|---|
| Collider size (visual) | 10 × 16 px |
| Collision width margin | 2.0 px per side |

The actual collision width used for tile resolution is `collider_size.x -
2 * collision_width_margin_px` (6px effective, vs. the 10px visual sprite) —
height is untouched. A few pixels of visual overlap on a jump-up corner or a
ledge edge never registers as contact at all: no nudge, no snap, no special
caaase, and no asymmetry between "helps" (letting a near-miss jump through) and
"hurts" (early-dropping a player standing near a ledge) the way the old
per-corner nudge correction did.

---

## 5. Gun

- Fires toward the mouse cursor from the player's chest position.
- Projectile speed: 9 px/frame. Lifetime: 90 frames. Despawns on tile
  collision or enemy hit.
- Cooldown: 24 frames. Firing is blocked until it completes.
- No ammo, no reload, no damage falloff.
- Firing does not interrupt or slow movement. No recoil.

### Cursor cooldown bar
- A small horizontal bar rendered directly beneath the mouse cursor,
  in screen space, following it every frame.
- Empty at the moment of firing, fills left-to-right over the 24-frame
  cooldown, hidden when full and idle.
- Must render above everything else. Use a `CanvasLayer`.

---

## 6. Enemies

### Base
An `Enemy` base class with:
- `max_health: int`
- `contact_damage: bool` (true = touching the player kills them)
- `on_hit(damage)` → flash white for 6 frames, knockback optional per type
- `on_death()` → particle burst, despawn
- A pure `step(state, delta_frames) -> state` AI function, testable headlessly

Behavior must be **fully deterministic** — no `randf()` in movement or firing
timing. Tests depend on this.

### Enemy 1 — "Trudger" (ground)
- Health: 2
- Walks a patrol at 0.8 px/frame. Reverses at walls and at ledge edges
  (raycast ahead-and-down).
- Kills the player on contact. Does not fire.
- No player detection, no chasing. It is a moving hazard with health.

### Enemy 2 — "Drifter" (flying)
- Health: 1
- Hovers, drifting horizontally in a sine pattern: amplitude 48px,
  period 180 frames, around its spawn point.
- Every 90 frames fires a 3-shot spread aimed at the player's position
  **at the moment of firing** (not tracking).
- Spread: 20° between shots. Projectile speed 2.2 px/frame — slow enough to
  read and dodge.
- Kills the player on contact.

### Projectile patterns
A `ProjectilePattern` resource system, so new enemies compose rather than
inherit. Implement at minimum:
- `straight` — fixed direction, fixed speed
- `aimed_once` — direction locked to player position at spawn
- `spread` — n shots, fixed angular gap
- `sine` — straight with perpendicular oscillation

Bullet-hell readable: constant speed, no acceleration, no homing. Ever.

---

## 7. Level framework

This is the part that has to outlive the first level.

### Structure
- A **room** is one scene: a `TileMapLayer` for collision/visuals, plus an
  `Entities` node holding spawn markers.
- A **level** is a `LevelData` resource: an ordered array of room scene
  paths, a spawn point, and a display name.
- `levels/manifest.tres` lists levels in play order.

Adding a level = author rooms + add a `LevelData` + append to the manifest.
Zero code changes. This is the acceptance criterion for the framework.

### Entity spawning
Spawn markers are `Node2D`s with an exported enemy scene and an exported
config resource. The room does not know what an enemy is; it knows about
markers. Adding an enemy type = new scene + new config resource, no
edits to room or level loading code.

### Death and respawn
- Contact with an enemy or an enemy projectile kills instantly.
- Death → 20 frame freeze + particle burst → instant respawn at the start of
  the **current room**, not the level.
- Death counter tracked per level, shown on completion.
- Spikes/hazard tiles kill on contact, same as enemies.

### Camera
- Snaps per-room rather than following continuously. Ori-style room framing.
- `W`/`S` offsets the camera by up to 32px for look-ahead.

---

## 8. Art

**Read this section carefully — it constrains what you can actually do.**

You cannot browse itch.io, evaluate asset licenses, or download asset packs.
Do not attempt it and do not fabricate asset URLs or license claims.

Instead:

1. **Generate placeholder pixel art from scratch**, programmatically. Write a
   script under `tools/` that outputs PNGs: a 16×24 player sprite sheet
   (idle, run, jump, fall, wall-slide, dash), a 16×16 tileset with distinct
   solid/hazard/decorative tiles, and both enemy sprites. Limit the palette
   to 16 colors and commit the palette as a file. Crude is fine — readable
   silhouettes and clear state distinction matter more than quality.
2. **Write `ART.md`**: a list of every sprite the game needs, its exact pixel
   dimensions, frame counts, and anchor points. This is the shopping list the
   human uses when sourcing or drawing real art later.
3. **Keep art fully swappable.** Every sprite path is referenced from one
   resource. Replacing the placeholder set must never require touching game
   logic.

---

## 9. Sample level

- Target clear time: **~60 seconds** for a competent player who knows the
  route. Roughly 5–7 rooms.
- **Not a tutorial.** Assume the player already understands the moveset.
  It should require chaining wall jump → dash → double jump within a single
  traversal at least three times.
- Include at least: one dash-gap that cannot be crossed by jumping alone, one
  vertical wall-jump climb, one section where a Drifter must be shot to make
  a jump survivable, and one section where a Trudger patrol forces timing.
- It should be fair. Every death should be legible as the player's mistake.
- Author it **after** the movement is tuned, not before.

---

## 10. Testing requirements

Every rule below gets a test in the input-playback harness before its
milestone is complete.

### Movement
- Coyote time: jump input 5 frames after leaving ground succeeds; 8 frames
  after fails.
- Jump buffer: jump input 6 frames before landing fires on landing.
- Variable height: released-early jump peaks measurably lower than held.
- Dash: exactly 12 frames at constant 7.0 px/frame, unaffected by gravity.
- Dash refill on ground and wall contact; no refill mid-air otherwise.
- Double jump available once per airborne period.
- Wall jump lockout: horizontal input has no authority for 8 frames.
- Collision width margin: a jump clipping a corner within the margin passes
  through cleanly (no ceiling hit); a bigger overlap still blocks. A ledge
  keeps the player grounded as long as any part of the margin-narrowed hitbox
  still overlaps solid ground, and drops them once fully clear.
- Player never tunnels through a tile at maximum possible speed.

### Combat
- Gun cooldown is exactly 24 frames; input during cooldown produces nothing.
- Projectile position at frame N matches the analytic expectation.
- Drifter fires on exactly the 90-frame cadence.
- Trudger reverses at a ledge edge and never walks off.

### Level validity (run this against every level)
- Every gap on the critical path is crossable with the current movement
  config. Compute max jump distance, max dash distance, and max dash-jump
  distance from the config, then assert no required gap exceeds them.
- Every room has a reachable exit.
- No enemy spawns inside collision geometry.

This last suite is the one that keeps future levels honest. Make it easy to
run against a new level.

---

## 11. Milestones

Work these in order. Validate, commit, and update `STATUS.md` after each.

0. Test harness, input playback, headless runner, `validate.cmd` passing
1. Run, jump, gravity, coyote, buffer, variable height, corner correction
2. Wall slide, cling, wall jump
3. Double jump, dash
4. **STOP. Human tuning pass.** Do not proceed without approval.
5. Gun, projectiles, cursor cooldown bar
6. Enemy base, projectile patterns, Trudger, Drifter
7. Room/level framework, death, respawn, camera
8. Placeholder art generation, `ART.md`
9. Level validity test suite
10. Sample level
11. Juice: hitstop on kill, screenshake, dash trail, landing squash, particles

Milestone 4 is a hard gate. Everything after it is built on movement that
has been confirmed to feel right by a human with a keyboard.

---

## 12. Decisions taken (flag if you disagree, do not silently change)

- **Dash is WASD-directional, not cursor-directional.** Aiming and dashing are
  separate systems. Changing this would couple them.
- **No stamina system.** Wall hold is bounded by the cling timer.
- **Dash refills on wall contact**, which permits chained wall-dash climbs.
  This is intended.
- **Rooms, not a scrolling level.** Simplifies respawn, camera, and testing.
- **Enemies do not chase.** They are hazards with patterns. Chasing enemies
  come later, if at all.

If a decision here makes a milestone significantly harder, say so in
`STATUS.md` rather than working around it.