# Handoff notes

Not part of the milestone workflow (that's `STATUS.md`, updated per-milestone
per `CLAUDE.md`). This is a looser "where things stand and what to look at
first" note for picking the session back up. Safe to keep around across
sessions; safe to delete once it's stale — `STATUS.md` and `git log` are the
authoritative history either way.

## Where we left off

Milestones 0-3 are done and committed (`git log --oneline`: `dcde3ce`
`cc35e52` `744b315` `56b096c`, plus tooling commits `31e7614` and `bc3eb4a`
in between). **We're sitting at milestone 4: the hard stop for a human
tuning pass.** Per `SPECS.md` section 11, nothing proceeds past this without
your approval — you said you'd test physics feel tomorrow, so that's the
next real action, not more milestone work.

What exists to test with: run `main.tscn` in the editor (F5). You'll see a
red 10×16 player, a brown floor, and two brown wall columns (all placeholder
`ColorRect`s), with a camera that follows the player. Controls: `A`/`D`
move, `Space` jump (tap = jump/double-jump, hold near a wall = wall jump),
`W`/`S` currently only matter for dash direction (no camera-look yet),
`left Shift` = dash.

## How to resume

- `tools\validate.cmd` runs the full headless test suite (24 tests as of
  `56b096c`). Must exit 0 before anything is considered done.
- `tools\screenshot.cmd` — I use this to actually see the game (writes a
  JSON config to `tools/capture/capture_config.json` describing a scene, a
  scripted per-frame input timeline, and which frames to save as PNGs, then
  I read the PNGs). See `tools/capture/capture_config.example.json`.
- If you want another milestone worked on before/after tuning, `PROMPT.md`
  drives it — see the loose end below, it's currently stale.
- Both tools go through `tools/godot_step.ps1`'s timeout+kill safety net.
  Never invoke `godot`/`godot_console` directly (this is a hard rule in
  `CLAUDE.md`, not just a style preference).

## Outstanding — needs a decision or a look

Roughly in order of "likely to actually matter tomorrow" first.

1. **`PROMPT.md` is stale.** It still reads "Implement milestone 3... wait,
   milestone 2 only" on disk — it never got bumped past 2, because
   milestone 3 was done from your direct chat instruction rather than by
   editing the file first. Not a functional problem (milestone 3 is
   correctly done and committed), but if anything reads `PROMPT.md`
   expecting it to reflect real progress, it doesn't right now.

2. **Wall cling's "zero gravity" is literal — no velocity reset.**
   Grabbing a wall while falling fast keeps that fall speed constant
   (not accelerating further) for 12 frames, then clamps down to the slide
   cap. It does not "catch" you with a snap to near-zero. If that feels
   wrong in testing, it's a one-line fix (zero `velocity.y` in
   `_apply_gravity` when `wall_contact` transitions 0→1) —
   `src/movement/player_movement.gd`.

3. **Dash fully locks out jump and run for its whole duration**, not just
   gravity (SPEC.md only specifies gravity=0 during dash). If you want to
   be able to jump-cancel a dash or have held movement matter mid-dash,
   that's a real change to `_apply_dash`'s pre-emption in
   `PlayerMovement.process`, not a tweak.

4. **Wall jump: pressing back into the wall (neither away nor neutral) at
   jump time falls back to the neutral (weak/high) jump.** SPEC.md only
   defines away vs. neutral. Judgment call, easy to special-case if it
   should behave differently.

5. **No coyote-style grace window on wall jump** — has to be touching the
   wall the exact frame you press. Wall cling/slide effectively gives you
   time near a wall already, so this may be moot in practice, but flagging
   since it's an asymmetry with ground jump.

6. **Untested combinatorial surface**: double jump + wall jump + dash
   interactions (e.g. dash then immediately double-jump, double-jump while
   wall-sliding, dashing into a wall jump) aren't explicitly covered by
   tests — only each mechanic in isolation. The priority ordering in
   `_apply_jump` (ground > wall > double) and the dash pre-emption should
   handle them sanely, but "should" is doing some work there. Worth poking
   at during tuning.

7. **Camera is a placeholder** — simple continuous-follow, 3x zoom, both
   arbitrary. SPEC.md section 7 wants a per-room snap camera eventually
   (milestone 7). Don't build on top of the current one expecting it to be
   final.

8. **Placeholder geometry is minimal** — one floor, two wall columns, no
   ceiling, no gaps of varying width. Fine for what's been tested so far,
   but if tuning wants to feel out jump distance/dash-gap-crossing/ceiling
   bonks, `scenes/main.gd`'s `_build_geometry()` will need more terrain.
   Trivial to extend, just flagging it's currently sparse.

9. **Discrete (non-swept) collision is only tunnel-safe because every
   current speed stays under `tile_size` (16px)** — dash at 7.0 px/frame
   is the fastest thing in the game right now and still comfortably under.
   Re-check this invariant (there's a test asserting it explicitly) if any
   future speed value approaches or exceeds 16.

## Standing rule worth remembering (bit us once already)

Collision flags (`on_floor`, `on_wall_left/right`, `on_ceiling`) are
readable two different ways depending on *where* in `PlayerMovement.process`
you are:

- **Before `_resolve_collision` runs** (jump decision, gravity/cling logic):
  these are last frame's values. Tests can inject fake values via
  `InputPlayback` frame dicts to isolate this logic from real geometry —
  this is how most of the coyote/buffer/wall tests work.
- **After `_resolve_collision` runs** (`_refill_abilities`): these are this
  frame's real, fresh values. Injected values get silently overwritten
  before this code ever sees them — `_refill_abilities` is the first place
  this actually broke a test (milestone 3), not just a theoretical risk.

New movement code touching these flags should be clear about which side of
`_resolve_collision` it's on before assuming a test-writing strategy will
work.

## Environment notes

- `nul` and `.claude/` show as untracked in `git status` — both predate
  this work, neither is mine to clean up or commit without being asked.
- Windows PowerShell 5.1's `-Encoding utf8` prepends a BOM that silently
  breaks Godot's `JSON.parse_string` (bit the screenshot tool once). Use
  `[System.IO.File]::WriteAllText(path, content, (New-Object
  System.Text.UTF8Encoding $false))` instead when writing JSON for Godot
  to read.
