# Status

## Done — Milestone 0: test harness, input playback, headless runner, validate.cmd passing
- `tests/framework/`: a minimal, reusable test framework.
  - `test_runner.gd` (`TestRunner`) — register `name -> Callable` test functions,
    run them all, print `[PASS]`/`[FAIL]` per test, return overall pass/fail.
    Test functions take no args and return `""` on pass or a failure message
    on fail (GDScript has no exceptions, so this is the plumbing for that).
  - `expect.gd` (`Expect`) — small assertion helpers (`equal`, `approx`,
    `is_true`, `is_false`) that return the same `""`/message convention.
  - `input_playback.gd` (`InputPlayback`) — scripts a per-frame input
    timeline (`Array[Dictionary]`) and steps a movement core across it,
    recording a state snapshot after every frame. `InputPlayback.hold(flags,
    n)` builds a run of `n` identical frames; several of these can be
    concatenated to script multi-phase sequences (hold left, then hold
    right, etc.). This is the piece that makes frame-exact assertions
    (coyote time, buffers, dash duration...) possible without touching the
    engine — required for every milestone from here on.
- Added `MovementState.clone()` so `InputPlayback` can snapshot state without
  knowing its fields — keeps the harness decoupled from whatever fields later
  milestones add to the state object.
- `tests/run_tests.gd` rewritten on top of the framework: registers 3 tests
  (constant right-hold reaches expected x, left-then-right nets correct
  displacement, no input holds position), plus a watchdog `Timer` that
  force-quits after 10s and an unconditional `get_tree().quit()` at the end
  of `_ready()`, per CLAUDE.md's process-safety rule. These are harness
  smoke tests, not SPEC section 10 rules — see "Surprised by" below for why
  none of section 10 applies yet.
- `tools/validate.ps1` now runs Godot **twice**: an `--import` pass first,
  then the actual test scene. Both steps use the same timeout+kill-by-name
  safety net as before.
- `tools/validate.cmd` passes (`=== OK ===`).

## Next
- Milestone 1: run, jump, gravity, coyote, buffer, variable height, corner
  correction — with a section 10 test for each rule.

## Surprised by / flagging
- **CLAUDE.md and PROMPT.md say `SPEC.md`; the actual file is `SPECS.md`.**
  Not renaming or editing either doc — flagging per CLAUDE.md's "flag if you
  disagree, do not silently change." (STATUS.md's own reference was already
  corrected to `SPECS.md` before I started this milestone, so this may
  already be known.)
- **Global class cache staleness had to be fixed inside `validate.cmd`
  itself.** Writing a new `class_name` script (`TestRunner`, `Expect`,
  `InputPlayback` this round) isn't visible to any scene until Godot
  rescans the project — otherwise you get `Could not find type "X" in the
  current scope` at *load* time, which happens before `_ready()` ever runs,
  so a scene's own watchdog Timer can't save you from it. Since
  CLAUDE.md's process-safety section forbids invoking `godot`/
  `godot_console` directly, the fix had to go *into* `validate.ps1`: it now
  runs `godot_console --headless --path . --import` as a first step (60s
  timeout) before running `run_tests.tscn` (120s timeout). This means
  every milestone that adds a new `class_name` script pays one extra Godot
  startup in `validate.cmd`, and it means the import step's own hang would
  need the same kill-by-name treatment as the test step — which it has.
- **No SPEC section 10 rule maps to milestone 0.** Section 10 is entirely
  about movement/combat/level mechanics that don't exist yet. PROMPT.md
  says "every rule in SPEC section 10 that applies to this milestone needs
  a test" — for milestone 0 that set is empty, so the 3 tests I wrote are
  harness self-checks (proving `InputPlayback` correctly threads multi-phase
  input through a step function), not spec-mandated tests. Milestone 1
  onward should have real section 10 coverage.
- **Not touched this round, flagging for milestone 1:** the existing
  `MovementState`/`PlayerMovement`/`scenes/player.gd` predate `SPECS.md` and
  are a minimal placeholder (left/right walk only, no `collision_flags`,
  no gravity/jump/accel/friction fields). `scenes/player.gd` also currently
  reads `ui_left`/`ui_right` (arrow keys), but SPEC section 3 specifies
  `A`/`D` for movement — the input map will need `move_left`/`move_right`
  actions bound to `A`/`D` before or during milestone 1, not the `ui_*`
  defaults.
