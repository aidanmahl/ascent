# Ascent — First Light

A playable Godot 4.7 pixel-art platformer about an astronaut climbing out of the cave where their ship crashed.

Play: https://aidanmahl.github.io/ascent/

## Controls

| Action | Input |
| --- | --- |
| Move | A/D or left/right arrows |
| Jump / air jump after recovery | Space or Z; release early for a shorter jump |
| Aim and fire | Mouse + left click |
| Keyboard fire | J or C; W/S aims up/down |
| Recoil lift | Jump, then hold S + J to shoot downward |
| Directional dash after recovery | W/A/S/D + Shift, or arrow keys + X |
| Recover at latest checkpoint | R |
| Pause | Escape or P |
| Mute | M |

Recover the pulse tool at the wreck, air jump in the lower grotto, and the vector drive below the hanging gardens. Three pulse charges refill on ground or wall contact. Shooting in the air pushes the astronaut away from the aim direction. Signal anchors restore health and set the recovery location. Reach the transmitter at the top to complete the chapter.

## Development

Open `project.godot` in Godot 4.7.1. The main scene is `scenes/main.tscn`.

- `scenes/main.gd`: authored level, enemies, projectiles, progression and checkpoints.
- `scenes/player.gd`: input, pulse recoil, astronaut animation, health and movement integration.
- `scenes/scenery.gd`: deterministic pixel scenery, wreck, vegetation and parallax.
- `scenes/hud.gd`: title, HUD, pause and completion screens.
- `scenes/sound.gd`: synthesized effects and ambient audio; no external assets.
- `src/movement/`: existing deterministic, tested movement and collision core. `expedition_config.tres` tunes the live game separately from the historical baseline.

Run `tools/validate.cmd` with `godot_console` on PATH. This runs the original 55 movement tests and 39 expedition checks, including all 26 route connections, weapon collision/recoil, progression, recovery and damage protection.

Run `tools/build-web.cmd` to export the single-threaded browser build into `docs/`. Commit the source and export together, then push `main`; GitHub Pages serves `docs/`. The existing GitHub Pages deployment is retained.

Visual capture: `godot_console --path . --audio-driver Dummy --script res://tools/capture/expedition_capture.gd`. Captures are written to the ignored `tools/screenshots/` folder.

This first chapter targets desktop keyboard/mouse browsers. Progress lasts for the current play session. The older planning/handoff documents describe the previous movement gym and are retained as history.
