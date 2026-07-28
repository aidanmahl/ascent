Read CLAUDE.md and SPECS.md in full before doing anything.

Before writing any code, verify the environment and report back:
1. `godot_console --version` returns 4.7.1
2. `godot_console --headless --path . --import` completes and .godot/ exists
3. Confirm project.godot has physics_ticks_per_second=60,
   stretch mode viewport, texture filter nearest

Then propose a plan for milestone 0 only. Wait for my approval before
implementing.

Milestone 0 scope — nothing else:
- The MovementState object and the pure-function stepping interface the
  movement core will use. No actual movement rules yet, just the shape:
  a state struct and a `step(state, input, config) -> state` signature
  with a trivial placeholder body.
- MovementConfig resource with every field from SPEC section 4, exported,
  set to the starting values given.
- tests/run_tests.tscn: headless runner. Unconditional get_tree().quit(code)
  plus a watchdog Timer that force-quits at 60s. Exits 1 on any failure.
- The input-playback harness: a test takes a list of per-frame input states,
  runs them through the movement core, and asserts on resulting state.
- Two throwaway tests proving the harness works — one that passes, one you
  temporarily make fail to prove the runner exits 1.
- tools/validate.ps1 and tools/validate.cmd exactly as written in the repo.

Definition of done:
- `tools\validate.cmd` exits 0 and prints "=== OK ==="
- Deliberately breaking a test makes it exit 1 with readable output
- Everything committed
- STATUS.md written with what exists, what's next, and any open questions

Do not start milestone 1. Do not write movement rules. Do not create
scenes, sprites, or levels. Stop when validate is green and committed.