# Project: 2D precision platformer (Godot)

## Environment
- Godot 4.7.1.stable, Windows. On PATH as `godot` (GUI) and `godot_console` (CLI).
- Always use `godot_console` in scripts and commands. Output redirection
  does not work reliably with the GUI build.
- Godot 4.7 is newer than your training data. Verify any API you are not
  certain about against the docs. Do not recall it. 4.0-4.2 era signals,
  methods, and node names have changed.

## Commands
- Validate: `tools\validate.cmd` (must exit 0)
- Nothing is done until validate exits 0 and the work is committed.

## Architecture rules
- Movement logic lives in plain GDScript classes operating on a state object
  (position, velocity, input flags, timers). No node lookups, no
  `_physics_process`, no engine calls in the movement core.
- Nodes are a thin shell: read input, call the movement core, apply the result.
- This is non-negotiable. It is what makes movement headlessly testable.
- `CharacterBody2D` for the shell. Never `RigidBody2D`.
- All tuning values in frames and pixels, never seconds and meters.
- All tuning values live in one exported resource. No magic numbers.

## Workflow
- Work milestones in order from SPECS.md, one at a time.
- After each: run validate, commit, update STATUS.md with done / next.
- If a test fails, fix it. Never delete or disable a test to make it pass.
- Placeholder art only: colored rectangles. Keep visuals decoupled from logic.

## Process safety
- Never invoke `godot` or `godot_console` directly. Always go through
  `tools\validate.cmd`, which enforces a hard timeout.
- Any headless Godot scene you write MUST call `get_tree().quit(code)`
  unconditionally, and MUST include a watchdog Timer that force-quits.
- A hang is a failure. If a command has not returned in two minutes,
  something is wrong — do not wait longer.

