# Ascent — The Orbital Garden

A Godot 4.7.1 exploration platformer about an astronaut finding a way home through
a ruined garden. The default campaign is a new 3200 × 2400 world: 25 rooms arranged
above, below and beside one another, with 37 physical connections.

Walk, jump, drop and dash across room boundaries. The world never teleports you
through an entrance. Explore the roots for boots, climb the western garden for
the horizontal thruster, and return through shortcuts with new movement options.

## Controls

| Action | Input |
| --- | --- |
| Move | A/D or left/right arrows |
| Jump / boot kick | Space or Z; release for a shorter jump |
| Aim / fire | Mouse / left click |
| Keyboard fire | J or C; W/S selects vertical aim |
| Recoil lift | Jump, then S + J near the apex |
| Horizontal dash | Shift or X; hold left/right, otherwise use last movement facing |
| Slash / projectile parry | Right click or K |
| World map | Tab |
| Rest at an anchor / transmit at Beacon | E |
| Retry at selected anchor | R |
| Pause / mute | Escape or P / M |

There is no upward or diagonal dash, and no double jump. Landing restores recoil
cells and the one-per-flight wall kick. Dash preserves existing vertical motion.
The two suit fragments together increase integrity from three to four.

Boots, the thruster and the second cell are exploration finds. Repair Rootheart's
pump and restore the Heartwood core in either order to activate the upper wind
lifts. The Warden and Sentinel are optional; Sentinel rewards a third cell.
Crown guards the final bridge to the transmitter. Equipment and world changes
persist across death for the current session; closing the game starts a fresh run.

The new art is drawn locally: a broken spacecraft, a suspended cistern, a giant
bell, sail terraces, resonators, tree hollows, machinery, an observatory, vegetation,
seed lights and water. Scenery and collision use the same room coordinates.

## Development

Open `project.godot`; main scene: `scenes/main.tscn`.

- `src/world/campaign_layout.gd`: room bounds, shared openings, terrain, natural
  movement gates, pickups, machinery and encounters.
- `scenes/world_rooms.gd`: continuous room discovery, camera targeting and physical lifts.
- `scenes/scenery.gd`, `world_art.gd`: original environment and equipment art.
- `scenes/boss_arenas.gd`: encounters in their real world locations.
- `src/movement/`: deterministic movement; `expedition_config.tres` tunes gameplay.
- `tests/campaign_tests.gd`: geometry, upgrade, camera and ability-gate checks.
- `tests/campaign_navigator.gd`, `campaign_replay.gd`: bounded movement route search.

`tools/validate.cmd` runs the movement, historical expedition and new campaign
suites. Historical rooms are an explicit `legacy_campaign` fixture and are never
built in the default campaign. Nonempty custom `LevelLayout` resources retain
an isolated authoring mode.

`tools/check-campaign.cmd` searches a fresh route through the campaign in bounded
batches, collects the real upgrades, and checks the final interaction. Its boss
defeats are supplied by the harness, so this is a traversal check rather than a
combat playthrough.

`tools/build-web.cmd` exports a local browser build to `docs/`. It does not deploy.
Render QA uses `tools/capture/campaign_capture.gd` through the timeout wrapper;
images are saved in the ignored `tools/screenshots/campaign/` folder.

See [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for the full spatial blueprint
and [DESIGN.md](DESIGN.md) for runtime contracts. Older movement plans are history.
