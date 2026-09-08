# Ascent — First Light

A playable Godot 4.7 pixel-art platformer about an astronaut climbing out of the cave where their ship crashed.

Play: https://aidanmahl.github.io/ascent/

## Controls

| Action | Input |
| --- | --- |
| Move | A/D or left/right arrows |
| Jump / wall kick after boot recovery | Space or Z; release early for a shorter jump |
| Aim and fire | Mouse + left click |
| Keyboard fire | J or C; W/S aims up/down |
| Recoil lift | Jump, then hold S + J to shoot downward |
| Directional dash after recovery | W/A/S/D + Shift, or arrow keys + X |
| Recover at latest checkpoint | R |
| Pause | Escape or P |
| Mute | M |

Climb a 4,520-pixel expedition across seven regions. Start unarmed with three health. There is no double jump.

- Complete the salvage trail for a one-cell pulse cutter. Fire downward to extend your jump; **only landing refills ammo and dash**.
- Defeat the Hollow Warden for a two-cell magazine.
- Cross the relay partition and shoot both targets within five seconds to earn magnetic boots. Boots allow **one weakened wall kick per landing**.
- Defeat the Glass Sentinel for the vector thruster. Direction + Shift passes blue membranes.
- Defeat Rootheart for the third magazine cell. Land three hits on the core during a single flight to open the canopy.
- Defeat the Crown and reach the rescue transmitter.

Drifters fire slow straight spreads. Your shots destroy hostile projectiles. Spikes and telegraphed geysers punish careless landings. Signal anchors restore health and record recovery locations; unfinished bosses reset when you recover, while earned equipment and opened vaults persist for the session.

See [DESIGN.md](DESIGN.md) for the current progression and balance rules.

## Development

Open `project.godot` in Godot 4.7.1. The main scene is `scenes/main.tscn`.

- `src/world/expedition_level.gd`: authored landings, challenges, hazards and encounter placement.
- `scenes/main.gd`: enemies, projectiles, progression and checkpoints.
- `scenes/world_art.gd`: equipment, cages, relay cores, membranes and hazards.
- `scenes/player.gd`: input, pulse recoil, astronaut animation, health and movement integration.
- `scenes/scenery.gd`: deterministic pixel scenery, wreck, vegetation and parallax.
- `scenes/hud.gd`: title, HUD, pause and completion screens.
- `scenes/sound.gd`: synthesized effects and ambient audio; no external assets.
- `src/movement/`: existing deterministic, tested movement and collision core. `expedition_config.tres` tunes the live game separately from the historical baseline.

Run `tools/validate.cmd` with `godot_console` on PATH. This runs the original 55 movement tests and 71 expedition checks, including all 43 route connections and negative ability-gate tests, weapon collision/recoil, progression, recovery and damage protection.

Run `tools/build-web.cmd` to export the single-threaded browser build into `docs/`. Commit the source and export together, then push `main`; GitHub Pages serves `docs/`. The existing GitHub Pages deployment is retained.

Visual capture: `godot_console --path . --audio-driver Dummy --script res://tools/capture/expedition_capture.gd`. Captures are written to the ignored `tools/screenshots/` folder.

This first chapter targets desktop keyboard/mouse browsers. Progress lasts for the current play session. The older planning/handoff documents describe the previous movement gym and are retained as history.
