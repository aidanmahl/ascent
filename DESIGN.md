# Orbital Garden — runtime design

The authoritative spatial ledger is `CampaignLayout.LINKS`, with 25 cell-aligned
room bounds. Every opening is a real shared edge. Player coordinates, velocity,
dash state and ammo stay continuous when room membership changes. The old shaft,
remote boss rooms and optional-room teleport code exist only in the legacy test
fixture. Custom nonempty layouts use an isolated authoring path.

## Movement and progression

Live dash: horizontal impulse at 10.5 px/frame, 16-frame nominal window, six-frame
cooldown. W/S and mouse aim cannot steer it. Vertical velocity and normal gravity
are preserved. Measured ordinary jump + horizontal dash (frame 10 launch) travels
235.9 px versus 83.7 px in the previous live build. This is a fixed input schedule,
not a universal maximum. Recoil jumps retain their existing rise and cadence.

Boots now launch away at (3.6, -5.8), neutral at (2.8, -5.4), and toward at
(2.2, -4.8), once per landing. This supports the new kick wells without increasing
ordinary jump height. Natural gates use actual terrain; traversal tests simulate
the collision and also try pre-upgrade input combinations.

| Find / objective | Place | Effect |
| --- | --- | --- |
| Cutter | Wreck Orchard | One recoil cell |
| Boots | Boot Nest, below and west of the start | One airborne wall kick |
| Thruster | Sail Garden | Long horizontal dash |
| Second cell | Wind Harp | Higher recoil routes |
| Core | Heartwood's upper nest | Half of the restored wind network |
| Pump | Sluice Engine, beyond Rootheart | Lake lift; other half of wind network |
| Third cell | Optional Sentinel | Additional recoil reach |
| Suit fragments | Moss Roost and Cistern Lanterns | Both together add one integrity |
| Final bridge | Crown victory | Physical route into Beacon |

The Crown/Launch Bough connection admits the eastern approach once wind is
restored; the Beacon bridge remains Crown-locked. This supports both arena
entrances without allowing a summit bypass. Arena seals are local machinery.
Warden's optional alcove permits retreat and resets that unfinished encounter.

The western return ladder and eastern counterweight open permanently from their
far sides. Pickups and cleared bosses stay cleared on death. Resting selects any
visited anchor; checkpoint order is not a progression condition. Normal traversal
neither heals nor changes the selected anchor. Boss retry points are outside combat.

## Rendering and state

Rooms occupy a 3200 × 2400 plane, divided into 640 × 480 footprints. Scenery culls
in both axes. The camera follows the player with horizontal lookahead and a
visibility clamp; it does not center a large remote room while losing the player.
The player draws above environmental art. Terrain lips identify physical surfaces;
large background silhouettes remain behind collision and the character.

The map is generated from the same room and connection data. It distinguishes
visited rooms, glimpsed neighbors, obstacles, pickups and anchors. E only rests
at nearby anchors or transmits the final signal. Automatic shared-edge discovery
is not a position-changing transition.

Lifts are physical platforms in authored shafts. Their motion supports the player
without resetting momentum or moving them to a distant location. Closed machinery
uses the shared swept gate collision helper. Wind needs both core and pump, and
survives death. No fluid simulation, swimming or player flight was added.

## Validation limits

Movement traces and structural checks establish traversability for the tested
input schedules. The route-search harness explicitly separates traversal from
boss combat: its guardian-defeat events are harness damage, not a balance claim.
Rendered captures verify the real viewport and are inspected separately. These
checks complement playtesting; they do not measure whether every room is fun.
