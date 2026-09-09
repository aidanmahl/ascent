# Ascent: a new interconnected world

Revision: 2026-09-08. Implemented after the subsequent user instruction to build
the campaign and new art. This document preserves the design blueprint; see
DESIGN.md and STATUS.md for shipped tuning, refinements, and validation evidence.

## 1. What must change

Build a BRAND NEW campaign. Remove the old expedition shaft from the live default
campaign, including its shelf-index progression, remote boss entrances, and E
portals. Do not retain its geometry and attach more rooms. Existing combat,
collision helpers, art primitives, and deterministic movement may be reused.

Verified current failures of scope:
- `scenes/world_rooms.gd` builds only archive/cistern/roost detours from platform
  indices 7/25/35, at remote coordinates. `enter`/`leave` teleport the player.
  Its 18-name map list is not an implemented 18-room world.
- `scenes/main.gd` still follows the old fixed-x ascent outside those detours
  and remote arenas. The replacement must remove those campaign assumptions.
- The user reports being unable to see their character in suit rooms. Room
  camera centers and coordinate handling need investigation during implementation;
  this plan does not pretend the exact cause has been reproduced.
- Dash currently chooses a 2D direction, replaces both velocity components,
  and has a diagonal-up boost. Those behaviors conflict with the new brief.

The new campaign is a ruined orbital garden wrapped around a vast hollow tree.
Descending into its roots, traversing its flooded underside, then crossing its
canopy should feel like exploring one place. The Ori inspiration is fluid routes,
layered natural spaces, distant glimpses of later paths, quiet discovery, and
revisiting transformed terrain. Create original rooms; do not copy an Ori map or
add Ori's entire ability set. Preserve the astronaut, recoil, slash/parry, and
four boss identities. Keep placeholder art independent of collision.

Non-negotiable outcomes:
- Physical rooms above, below, left, and right of one another in one coordinate
  space. Walk, jump, fall, and dash through their shared openings.
- No E-to-enter/E-to-return rooms, disguised automatic teleports, or disconnected
  boss instances. E remains available for resting and the final transmitter.
- Exploration supplies movement upgrades. Bosses do not repeatedly supply a key
  to the next colored wall. No mandatory red story walls or blue dash membranes.
- Longer horizontal-only dash; no upward, downward, or diagonal dash.
- Both suit fragments live on traversable loops with fully visible approaches,
  safe collection ledges, and a route onward to a different room.
- Replace geometry first. Combat polish does not count as map completion.

## 2. Movement contract before geometry is locked

Dash direction is LEFT or RIGHT: use held horizontal input, otherwise the last
nonzero horizontal facing. Opposing horizontal keys resolve to facing. W/S,
up/down arrows, and mouse aim never change dash direction or facing fallback.
Dash sets velocity.x only; preserve velocity.y, then apply normal gravity. It
neither cancels falling nor creates upward lift. Jump/recoil/wall kick supply
height. Remove `dash_diagonal_up_vertical_boost` and its resource serialization.
Keep cooldown, contact refill, recoil, and frame-based deterministic simulation.
No new double jump, flight, grappling, or unlimited midair dash in this campaign.

Starting tuning proposal: dash_speed 10.5 px/frame (currently 7), nominal window
16 frames (currently 12), cooldown 6. These are experiments, not measured reach.
If normal horizontal deceleration erases the extension, tune an exported dash
momentum-decay value during the nominal window; do not secretly boost jump or
recoil. Preserve responsive braking and swept collision at the higher speed.

Before authoring final tiles, record baseline and new trajectories using the
real movement core at 60 Hz: neutral and held-direction launches, ground dash,
apex dash, falling dash, both directions, and jump + each cell count + dash.
For the same apex-launch schedule, target at least 1.5x old horizontal dash
travel over the first 16 frames. Also measure complete landing reach separately.
Target 200-240 px for an accessible one-cell jump/recoil/dash crossing; if the
feel requires a different range, resize this plan's gaps using the ratios below.
Do not claim these target distances as validated results.

Let R(stage) be reliably landed horizontal distance with that stage's abilities,
including launch clearance and actual collider. Mandatory dash gaps use 65-80%
of R(stage), with at least 96 px landing shelves; optional challenges <=90%.
A gap used as an ability gate must exceed the measured BEST pre-upgrade reach
(including all available recoil, wall contact, and launch positions) by >=24 px,
while fitting the post-upgrade comfort envelope. If those envelopes overlap,
change the approach/landing geometry or the room, never add an invisible lock.
Mandatory rises use <=80% of measured stage-specific rise. First wall-kick
lessons have rest shelves after every transfer; no infinite kick assumptions.

## 3. Complete spatial blueprint

25 rooms occupy a 5 by 5 macro grid. Each cell is 640 by 480 world pixels,
40 by 30 tiles at 16 px. Origin of room (c,r) is (640*c,480*r); positive y is
down. This makes a 3200 by 2400 world, not a 25-screen climb. A room can have
several camera views and terraces; a cell is an authoring footprint, not a
single-screen box. Empty interior space is intentional, not an unfinished floor.

The following placement and connection ledger are authoritative. Neighboring
cells are connected ONLY where a ledger edge exists. All links use actual shared
boundaries, not offsets to distant copies. Numbers are persistent room IDs.

```text
                    WEST                                   EAST
       col 0          col 1          col 2          col 3          col 4
r0   [01 Roost]----[02 Wind Harp]--[03 Crown Nest]--[04 Launch Bough]--[05 Beacon]
         |              |              |                 |
r1   [06 Bell]-----[07 Sail Garden] [08 Heartwood]---[09 Stormwalk]---[10 Sentinel]
         |              |              |                 |               |
r2   [11 Archive]--[12 Fern Court]--[13 Hollow Tree]--[14 Mirror Lake]--[15 Spillway]
         |              |              |                 |               |
r3   [16 Wreck]----[17 Root Market]--[18 Root Loom]---[19 Pumpworks]---[20 Glass Run]
                        |              |                 |               |
r4   [21 Boot Nest]-[22 Underroot]--[23 Rootheart]---[24 Sluice]-----[25 Cistern]
```

Lines denote eventual traversability, not initial access. The table below defines
restrictions precisely. No implied 07-08 link, 10-05 link, or 16-21 link exists.

### Connection ledger and opening positions

EW openings lie on the shared vertical boundary; the offset is local y in BOTH
rooms. NS openings lie on the shared horizontal boundary; offset is local x in
BOTH rooms. Openings are 96 px clear minimum (120 px for vertical passages).
Each specified offset is the opening center. Align collisions exactly; no seam
wall, forced interaction, position reassignment, heal, or velocity reset.
`free` means traversable with starter jump + one-cell recoil after collecting
the gun in 16. Gates are within the named room, away from the seam.

| Link | Opening | Initial rule / how it changes |
| --- | --- | --- |
| 16-17 | EW 352 | Free; the first outward route |
| 16-11 | NS 480 | Boots climb in 11; upper route returns to wreck |
| 17-12 | NS 192 | Free terraced root climb, also safe descent |
| 17-18 | EW 304 | Free low winding path |
| 17-22 | NS 448 | Free descent and one-cell return shelves |
| 22-21 | EW 352 | Free; boots lie at end of a short sheltered lesson |
| 22-23 | EW 224 | Boots wall transfer inside 22; no sealed boss gate here |
| 18-23 | NS 192 | Boots route; enters 23's north overlook outside arena |
| 18-19 | EW 336 | Free along a dry maintenance shelf |
| 18-13 | NS 352 | Boots climb in 18 |
| 19-24 | NS 224 | Free staircase down and back; no swimming requirement |
| 19-20 | EW 192 | Dash gap inside 20; preview across the broken aqueduct |
| 19-14 | NS 448 | Pump lift, opened from 24 after Rootheart; rides physically |
| 23-24 | EW 352 | Through Rootheart arena, opens after victory |
| 24-25 | EW 352 | Free after reaching 24; fragment loop's lower route |
| 25-20 | NS 448 | Dash crossing in 25 to a reachable wall/rest-shelf climb |
| 12-11 | EW 320 | Free; archive's low aisle accessible early |
| 12-13 | EW 352 | Free; central tree's ground floor |
| 11-06 | NS 192 | Boots climb; first new western route |
| 12-07 | NS 448 | Garden return hatch opened from 07; permanent ladder |
| 06-07 | EW 304 | Boots route; dash pickup is in 07 |
| 06-01 | NS 192 | Dash gap inside 06 to wall-kick ascent; optional |
| 07-02 | NS 448 | Dash between resting sail platforms; then short kick climb |
| 13-08 | NS 192 | Two-cell recoil rise inside 13, earned in 02 |
| 13-14 | EW 352 | Dash over lake inlet inside 14 |
| 14-09 | NS 192 | Boots + dash route via outer shelves; accessible before core |
| 14-15 | EW 224 | Dash across separated dry islands |
| 15-10 | NS 448 | Boots + dash climb to Sentinel's lower entrance |
| 15-20 | NS 192 | Spillway counterweight lowered from 15; permanent return |
| 10-09 | EW 304 | Sentinel arena's west exit; opens after victory |
| 09-08 | EW 352 | Free upper gallery; 08's core ledge needs two cells |
| 09-04 | NS 448 | Wind lift activated by Heartwood core + repaired pump |
| 08-03 | NS 192 | Same restored updraft network; physical lift, no teleport |
| 01-02 | EW 304 | Dash loop; optional upper approach to Roost |
| 02-03 | EW 352 | Crown approach needs restored wind network |
| 03-04 | EW 304 | Crown arena east exit after victory |
| 04-05 | EW 304 | Free after Crown; transmitter victory interaction in 05 |
```

The restored wind network requires BOTH Rootheart's pump repair and Heartwood's
core, not Sentinel's death. Crown cannot be bypassed via 09-04: its 04 landing is
a lower observation terrace. A visible folded bridge to 05 deploys on Crown
victory. From that terrace a physical stair joins Crown's east vestibule for an
alternate arena entrance; during combat both arena exits close locally. This
single final encounter lock must be shown as a mechanical bridge, not a red wall.

### Every room's interior, purpose, and reward

Place the west/east openings at the ledger heights and connect their approach
shelves to the internal route. Vertical openings need a landing or catching
wall visible before crossing. Room descriptions specify mandatory topology;
implementers must author solid rectangles and traversal traces for each segment.
Do not substitute the same floor-and-three-platforms template in all cells.

| ID / room | Interior route and landmark | Content / checkpoint |
| --- | --- | --- |
| 16 Wreck Orchard | Crashed hull across a shallow basin; exit right through its torn bow. Left roof shows Archive above, reachable later through a boot climb. | Start anchor; gun on unavoidable safe bow shelf; no combat before pickup |
| 17 Root Market | Three terraced root balconies around a hanging cargo crate: west start, north court, east loom, south roots. Each branch readable from central rest. | Anchor; first isolated crawler and parry lesson |
| 18 Root Loom | Broad woven roots form a figure-eight around a solid trunk. Lower east maintenance route, southwest descent, upper boots branch into Hollow Tree. | One sentry guarding cover, never the seam |
| 19 Pumpworks | Broken wheel fills the background; dry spiral stair connects west and south. East window frames Glass Run's gap; a dormant real lift rises north. | Anchor; pump-state landmark; no mandatory water damage |
| 20 Glass Run | Two staggered horizontal aqueduct crossings around a central rest island; south descent to cistern, upper outlet to Spillway. See landings before takeoff. | Dash practice; sheltered hunter encounter after landing |
| 21 Boot Nest | Curled maintenance shell: walk around the bottom, collect boots, wall-kick onto its back, then descend onto the entry path. Only deliberate small equipment dead end. | Boots exploration pickup; no boss; safe teaching walls |
| 22 Underroot | Descend along giant roots into a lit floor basin; west boot nest and east raised root saddle. A stair returns north without boots. | Quiet navigation; east teaches boots with broad fallback floor |
| 23 Rootheart Basin | North overlook and west vestibule join outside arena. Fight spans dry islands over shallow hazard channels; east exit continues to Sluice. | Rootheart; exterior anchor, pump repair permission; no movement ability |
| 24 Sluice Engine | West arena outlet and north stair meet a wheel platform; east drain gallery continues into cistern. Repair wheel starts physical pump lift in 19. | Automatic repair trigger on wheel after boss; state persists |
| 25 Cistern Lanterns | Descend from north onto an outer walkway, curl beneath a suspended tank, collect fragment on a wide lit shelf, continue west along drain. Reverse route available. | Suit fragment A; 24-25-20-19 loop; local safe reset ledge |
| 11 Archive Roots | Low public aisle west/east; overhead archive balcony wraps a tree root. Boots allow ceiling route to Bell and descent to Wreck. | Lore/repair cache; no isolated item-room instance |
| 12 Fern Court | Peaceful outdoor clearing with a split stone arch; floor joins Archive/Tree, roots return south, folded north ladder foreshadows Garden. | Anchor; visual hub with four genuinely distinct exits |
| 13 Hollow Tree | Tall hollow with an open floor route and offset internal nests. Boots enter from below; two-cell rise reaches north core approach. Low exit east shows lake. | Anchor; center landmark visible across neighboring rooms |
| 14 Mirror Lake | Long reflected canopy over dry stepped islands. West approach gap, central safe island, south pump lift dock, north outer climb, east stepping route. | Optional drifter above an avoidable high path |
| 15 Spillway | Switchback dry banks around a falling water curtain; climb to Sentinel, descend toward Glass Run and lower its counterweight. | Shortcut, repair cache; no swimming mechanic |
| 06 Bell Cavern | Huge broken bell divides ascent into outside ledges and a traversable interior. East reaches Garden; later dash across bell mouth reaches northern kick wall. | Acoustic landmark; limited crawler/drifter pockets |
| 07 Sail Garden | Suspended cloth terraces: safe west arrival, dash module in sheltered center, long eastward teaching gap to rest island, north sail climb. South hatch loops to Court. | Dash exploration pickup; anchor; hatch accessible after teaching gap |
| 01 Moss Roost | Wrap around a fallen nest: lower vertical arrival, higher east exit via dash return shelf. Fragment between them on a broad ledge, never off-camera. | Suit fragment B; 06-01-02-07-06 loop |
| 02 Wind Harp | Walkable resonator ribs cross a wide chamber; dash between ribs with safe lower recovery ledges. Cell module on central resonator, accessible from south without boss. | Second cell; northwestern expedition reward; east wind gap preview |
| 08 Heartwood | Two-cell recoil climb around a luminous hollow core, with rest nests rather than a single triple-shot wall. East gallery allows inspection from Stormwalk. | Core restoration exploration objective; anchor on lower safe ledge |
| 09 Stormwalk | Low covered gallery connects Tree/Sentinel; exposed upper branch crosses timed gusts between shelters. Only restored lift reaches Launch Bough. | Anchor; readable gust cycles and safe waiting bays |
| 10 Sentinel Observatory | North-facing broken telescope; south entry and west exit on distinct arena sides. Two elevation lanes support existing boss attacks. | Optional Sentinel; third cell as optional combat/exploration power |
| 03 Crown Nest | West and lower/east vestibules converge on a wide multilevel arena. Root cover separates attack lanes; victory unfolds exit bridge in adjacent Launch Bough. | Mandatory Crown; exterior retry anchor for either entrance |
| 04 Launch Bough | Lower viewing branch reached by wind lift looks back over lake. Stairs lead west to Crown vestibule; upper bridge reaches Beacon after Crown. | Quiet payoff vista; no hidden bypass to Beacon |
| 05 Beacon | Brief safe horizontal walk along the crown of the tree to a wrecked transmitter; skyline reveals regions traversed below. | E at transmitter wins; no global altitude win threshold |

Warden is an optional encounter in Archive's upper west alcove, spatially inside
11, with an exterior perch and cache reward. It does not obstruct 11's connections
or award a required cell. Four bosses remain, but only Rootheart and Crown are
mandatory. Keep the last plan's readable attack improvements where implemented;
this revision relocates encounters and changes progression rewards.

## 4. Progression, freedom, and meaningful returns

Fresh critical route (one valid ordering, not a navigation script):
16 -> 17 -> 22 -> 21 boots -> 22 -> 17 -> 12 -> 11 -> 06 -> 07 dash ->
02 second cell -> 07 -> 12 shortcut -> 13 -> 08 core -> 13 -> 18 ->
23 Rootheart -> 24 repair -> 19 lift -> 14 -> 09 -> 08 wind lift ->
03 Crown -> 04 -> 05.

Boots are an early exploration find. Dash is another exploration find after
learning boots. The second cell is earned by traversal in Wind Harp, not a boss.
After boots, the western Garden route and southern Rootheart route can be tackled
in either order. After dash, choose the upper Harp, eastern Lake/Sentinel, or
lower Glass Run/Cistern exploration. Core and pump objectives can be completed
in either order; their combined change restores the upper tree's wind network.
Third cell, suit upgrades, Warden, Sentinel, and Roost are all optional. The final
route must be beatable with two cells, base health, and no combat pogo/refill.

Return loops must exist physically and change how the player traverses the world:
1. Starter exploration: 17 -> 18 -> 19 -> 24 -> 23 (boss blocks through passage
   until fought from west/north); the open early loop is 17 -> 12 -> 13 -> 18 -> 17
   once boots are found. Never advertise a locked loop as already traversable.
2. Western boots loop: 16 -> 17 -> 12 -> 11 -> 16.
3. Dash homecoming: 12 -> 11 -> 06 -> 07 -> newly lowered ladder -> 12.
4. Upper optional loop: 06 -> 01 -> 02 -> 07 -> 06.
5. Floodworks loop: 19 -> 20 -> 25 -> 24 -> 19 after dash.
6. Lake return: 19 -> repaired lift -> 14 -> 15 -> counterweight -> 20 -> 19.
7. Observatory loop: 14 -> 15 -> 10 -> 09 -> 14 after optional Sentinel.

No reward room returns the player to an unrelated stored entrance. Early previews
show WHY a route is inaccessible: distance over water, unreachable grip wall,
a high nest, dormant machinery. Vary the route after the ability: a broad dash
crossing, a curved wall transfer, a recoil rise, a controlled drop, a lift ride.
Colored wall + boss + same exit is not an acceptable recurring structure.

## 6. World, camera, and recovery implementation contract

Create `src/world/campaign_layout.gd` as the single authored data source: stable
room IDs, cell bounds, solids, seam intervals, internal traversal nodes/edges,
ability requirements, hazards, pickups, encounters, anchors, and persistent
world changes. Map UI consumes this actual data, not a separate decorative graph.
Keep the legacy expedition only as an explicit test/debug fixture. Live default
startup builds all 25 new rooms and none of the old shelf campaign.

Replace `scenes/world_rooms.gd` portal logic with room membership/discovery and
neighbor activation. Crossing a shared opening changes metadata only. Player
world position, velocity, ammo, dash timer, and facing remain continuous. Use
swept seam detection for high-speed crossings. Keep adjacent collision present
before entry. Activate nearby enemies with a short arrival grace and cull visuals
in both axes. Bosses occupy their actual room bounds; no remote arena copies.

Build geometry and art from identical origins. Derive camera zones from room
interiors and connected seams. Camera follows x AND y with modest directional
lookahead; do not frame a whole 640x480 room if the actual viewport cannot show
its traversal. Blend zones across seams without pulling the character outside
the visible safe frame. Near a vertical seam, reveal the receiving ledge before
crossing. Do not retain fixed x=320/960, global SUMMIT clamps, or detour offsets.

Visibility acceptance is explicit for EVERY entrance and reward:
- Render at the real supported viewport/zoom, not only the debug camera.
- Player's complete sprite and supporting surface visible on arrival, throughout
  pickup collection, and on the route onward. No foreground occlusion of sprite.
- Camera follows the route from both directions, including a falling entry and
  high-speed dash. No frame of empty off-world room caused by origin mismatch.
- Pickups, collision, enemies, scenery, and camera agree on world coordinates.
- Capture 01 and 25 before entry, at pickup, after pickup, and after death/retry.
  Inspect actual images; one platform and an unseen player fails acceptance.

Anchors store room ID + world position, never shelf indices. Traversal does not
heal or overwrite the chosen anchor. Add local hazard reset ledges for long
optional routes: recover on known safe ground with normal damage rules; death
returns to the last anchor. Retain abilities, fragments, defeated bosses,
shortcuts, and world changes through death. Two fragments raise health 3 -> 4;
collecting either first is valid, duplicates cannot grant extra health.

On death/reset clear transient attacks and velocity, synchronize previous/current
position, select correct room/camera immediately, and ensure collision/art are
ready before showing the player. Arena retry anchor is outside its seals.
No room exit depends on a living enemy, ammo from parry, or damage boosting.
Drops without pre-upgrade return access must be blocked by actual geometry until
safe, or land on a complete free return route. A death button is not an exit.

## 7. Presentation and retained combat scope

Retain slash/parry, crosshair ammo, compact health HUD, current gun/recharge
behavior unless testing identifies a regression. Do not redo working combat
instead of building the map. Preserve readable boss tells, recovery windows,
and safe exterior anchors. Close only local arena entrances during an encounter;
victory opens the opposite continuation as well as the entrance. Warden's alcove
is the sole optional arena spur; neither its fight nor Sentinel gates movement.

Tab map shows real footprints and discovered connections, player location,
anchors, collected/uncollected discovered rewards, and natural obstacle icons.
Room interiors may reveal silhouettes of adjacent terrain without prematurely
marking that room explored. Display pump/core state at their machinery and map
landmarks. Keep pause state explicit. Remove fictional altitude progression.

Use distinct silhouettes and compositions: curled root, suspended tank, huge
bell, mirrored lake, woven terraces, wind ribs. Quiet rooms and short enemy
pockets separate traversal challenges. Hazards emphasize landing choices and
rhythm; avoid tiny spike landings or enemies attacking across unseen seams.
Do not simulate fluid physics: water is scenery or a plainly marked hazard;
pump repair activates authored machinery and effects with persistent state.

## 8. Implementation sequence with concrete review gates

1. Measure old dash, implement horizontal-only longer dash in pure movement,
   update config/input/tutorials, and validate the reach envelopes. Rewrite old
   vertical/diagonal dash tests to assert the new contract; preserve unrelated
   movement coverage. No geometry tuned to guessed range.
2. Build complete 25-room graybox, shared seam data, and two-axis camera. Remove
   default shaft/teleport wiring. Include all physical connections, even where
   internal natural gates remain. Verify room placement matches the blueprint.
3. Author and replay starter -> boots -> Garden -> dash -> Court round trip.
   Review continuous crossing, camera, route variety, and the changed geography
   before detailing any rooms. A remotely teleported room fails this milestone.
4. Complete all interior paths, natural ability gates, Harp cell, core/pump
   branches, physical lifts/shortcuts, boss placements, and summit bridge. Test
   all progress states and both orders of pump/core objectives.
5. Finish optional loops and fragments; reproduce the reported visibility case
   against the replacement camera and inspect entrance/pickup/exit captures.
6. Add scenery/encounters to validated geometry, map presentation, tutorials,
   and audio. Do full fresh traversal with combat; tune pacing and dash landings.
7. Run timeout-managed `tools/validate.cmd`, then local web export/smoke test.
   Update README/DESIGN/STATUS to actual final behavior. No deploy/push unless
   requested. Do not report a plan, graph test, or harness boss kill as playtesting.

Implementation remains modular: pure frame-based movement, shared production
collision, authored world data, thin nodes. Use repository timeout/watchdog
conventions for headless tests. This planning turn requires no gameplay build.

## 9. Definition of done for the implementation

Structural checks:
- 25 unique bounds at specified grid positions; no overlaps, valid matching
  seam intervals, every opening backed by an actual adjacent room and safe path.
- Every listed edge exists, with no unlisted progression bypass. No default
  expedition builder, source platform indices, room teleport interaction, or
  remote boss copy remains in live campaign startup.
- Graph state exploration proves gun/boots/dash/two cells precede their own
  mandatory gates, both objective orders reach summit, optional rewards remain
  optional, and every entered room has a physical escape in that progress state.
- Graph edges alone are insufficient: actual collision/input traces prove every
  mandatory internal transfer and return, with launch-position/timing margins.
  Negative tests include all pre-upgrade recoil combinations and wall refills.

Movement and state checks:
- Up/down/diagonal/aim input always produces horizontal dash direction; vertical
  velocity has no dash impulse. Falling stays falling under normal gravity.
- Measured dash extension meets the target; longer sweep cannot tunnel through
  tiles or arena seals. Cooldown/refill and braking remain correct.
- Cross seams while running, jumping, falling, recoiling, and dashing: no position
  discontinuity, resource refill, unwanted heal, or lost velocity.
- Retry from each anchor, after each pickup, in optional loops, during lifts,
  before/after world changes and boss fights. No off-camera spawn or softlock.

Rendered/play checks:
- Inspect every room from every entrance, at pickups, and at anchor respawns;
  prioritize the two suit fragments and both vertical seam directions.
- Fresh playthrough obtains real upgrades, visits west/east/below/above the hub,
  completes core then pump; second route completes pump then core. Play optional
  fragment loops and revisit starter regions with dash. Confirm return routes
  work with enemies dead and no optional third cell.
- Record actual input method, completed segments, remaining failures, and
  screenshots. Harness damage may validate boss state, never combat balance.
- The final world must visibly read as the diagram above, with multiple large
  loops and distinct rooms. A familiar shaft with new labels fails acceptance
  even when all tests pass.

## 10. Scope and handoff

This document supersedes conflicting map/progression/dash sections of PLAN.md,
SPECS.md, DESIGN.md, HANDOFF.md and the prior IMPLEMENTATION_PLAN. Those files
contain historical behavior and must not silently override this revision.
The original planning-only request was followed by explicit authorization to
implement the campaign, including new art. No subagents, publication, or new dependencies are required for this plan.
No inventory, crafting, save-system expansion, swimming, or new ability beyond
the existing boots/dash/cells is needed. Physical wind/pump lifts are authored
world platforms, not player flight or teleportation.


## Implementation refinements

- The measured live baseline was 5.4 px/frame, not the 7.0 default-resource value.
  Live horizontal dash is now 10.5, with a 16-frame window and six-frame cooldown.
- Boot impulses were strengthened to make the physical kick wells practical;
  ordinary jump/recoil tuning remains unchanged. Actual terrain tests govern reach.
- Drop shafts are carved through upper terraces, not merely through shared walls.
  Vertical approaches use offset resting ledges; Bell's lower terraces are distinct.
  Free shafts also include catch ledges with tested one-cell returns before boots.
- Lift platforms are 128 px wide with matching shaft clearance and overlapping docks.
- Crown's east vestibule becomes accessible with restored wind. Beacon remains
  Crown-locked, allowing both arena approaches without a summit bypass.
- The second cell rests on an exposed Wind Harp resonator. The core is on a
  160 px recoil rise in Heartwood. Both suit fragments have original shell artwork.
- Original code-drawn environment art replaces the old altitude-based scenery.
  Large motifs use room origins; player rendering stays above environmental art.
- Native and browser UI automation were unavailable in this session. Rendered
  viewport captures and local HTTP asset checks are recorded separately from
  simulated traversal; no manual combat-playthrough claim is made.
