# Ascent: exploration and combat redesign

Status: design complete; implementation deliberately paused for a model switch.
User request: fix dash barriers, add active combat choices, replace repetitive
vertical progression with metroidvania exploration, deepen all bosses, put ammo
around the crosshair, remove the top-left HUD text and top-right ammo display.
Priorities: first beatable and robust, then varied and enjoyable.

## Handoff and verified baseline

- Work in `C:/godot-projects/ascent`. The main scene is `scenes/main.tscn`.
- The brief partial edits to `scenes/main.gd` and `scenes/player.gd` were removed.
  `git diff` for both is empty. This plan is the only intended content change.
- `tools/validate.cmd` passed on 2026-09-08 after restoring the baseline.
- Godot 4.7.1 is installed; use the existing timeout-managed validation wrapper.
- No implementation, export, commit, or publication was performed for this plan.
- User explicitly requested planning followed by a stop. Start implementation
  only when the user resumes after switching models. No further design approval
  is needed to implement this plan within the original creative brief.
- Do not spawn subagents unless subsequently requested. Do not publish or push.
- Read repository instructions before implementation; older SPECS/PLAN/HANDOFF
  describe a movement gym. This approved task supersedes conflicting old game
  design, while preserving the deterministic movement architecture.

Code facts:

| File | Current responsibility / relevant problem |
| --- | --- |
| `src/world/expedition_level.gd` | 43 indexed shelves, largely repeated ascent; gates and equipment tied to indices |
| `scenes/main.gd` | World, combat, gate collision, progression, checkpoints; camera x fixed at 320 or 960 |
| `scenes/player.gd` | Input, recoil, ammo, health; grounded shot 0.48s and recharge 0.85s |
| `scenes/boss_arenas.gd` | Four remote chambers, entrance shelves [11,23,29,41], timed rectangle warnings |
| `scenes/hud.gd` | Crosshair; upper-left title/zone; upper-right health/ammo |
| `scenes/scenery.gd`, `world_art.gd` | Procedural art; several assumptions about x=0..640 and altitude |
| `src/movement/` | Pure frame-based movement/collision; retain its contracts |
| `src/world/level_layout.tres` | Empty authored override, so default expedition is currently used |
| `tests/expedition_tests.gd` | Existing route search + integration checks; reproduces the old gate algorithm |

Measured with `tools/movement_envelope.gd` and the live config:

| Action | Peak rise | Same-height air range |
| --- | ---: | ---: |
| Jump | 52.7 px | 113.0 px |
| Jump + 1 downward shot | 111.3 px | 177.8 px |
| Jump + 2 downward shots | 174.5 px | 245.3 px |
| Jump + 3 downward shots | 241.6 px | 312.8 px |
| Wall kick alone | 35.7 px | 105.4 px |
| Jump + diagonal dash at frame 10 | 66.4 px | 134.0 px |
| Jump + vertical dash at frame 10 | 95.0 px | 0 px |

These are specific schedules, not universal maxima. Room collision simulation
is required; comments in the old level overstate some dash reach.

## 1. Design commitments

Keep the astronaut, recoil platforming, grounded resource refill, pixel art,
four existing bosses, and upward escape theme. Retain three base health and no
double jump. Make exploration spatial and connected: horizontal travel, drops,
short climbs, visible unreachable exits, returning with upgrades, and shortcuts.
Do not retain the 43-shelf staircase as the new main campaign, or merely append
side rooms to it. Target an initial 25–40 minute first clear, subject to playtest.

Combat loop: fire while approaching, choose a close slash or timed parry during
recharge, use recoil/pogo to reposition, then exploit enemy recovery. Ordinary
rooms need threats and choices, but also quiet landings and safe inspection time.
Avoid increasing difficulty mainly through health inflation or projectile spam.

No required random drops, damage boosts, enemy pogo, pixel-perfect jumps, or
frame-perfect inputs. Mandatory traversal must work with enemies already dead.

## 2. Fix barriers before changing the world

Observed failure mechanism: `gate_open()` only checks the remaining dash timer.
`_update_dangers()` restores the previous position if a closed gate overlaps the
player. The timer can expire while overlapping; restoring another overlapping
position repeatedly traps the body. Gates also use a different body size from
the movement collider and do not consistently handle swept crossings.

Implement a pure gate helper in `src/collision/gate_collision.gd`, shared by the
live player and traversal tests. Each gate has a stable id, rect, kind, required
flag, and breached state. Use the live collider dimensions conservatively.

- Save previous position and whether dash was active before movement, plus
  whether one successfully launched this frame. Resolve gates after movement
  in the player's own physics update, not a parent update one frame later.
- Test the swept body against the gate (segment against rect expanded by body
  half-size). Respect earlier solid collisions; a dash cannot open distant gates.
- A valid dash touching a blue membrane permanently breaches that membrane for
  this session. It becomes a return shortcut, visibly shattered/open. Opening
  remains valid when the dash ends or the player reverses while inside it.
- Without dash, resolve contact to the entry face, remove velocity into that
  face, and synchronize state.position and node position. A closed horizontal
  gate is a usable floor from above. Never restore an overlapping position.
- If a player starts embedded without permission, choose the nearest clear
  face; check adjacent tiles before resolving. Provide a safe spawn fallback.
- Closed story gates use the same collision helper and open from progress flags.
- Gate opening does not refresh dash/ammo and does not grant general invincibility.
- Save breached ids with other session progress; retain across death.

Regression cases: nine-frame dash expiration inside; final active frame entry;
up/down/left/right/diagonal crossings; low-speed edge contact; reversal; high-speed
sweep; no ability; closed-gate standing; embedded recovery; nearby solid wall;
death/reentry. No frame may leave a player stuck in a closed gate.

## 3. Active combat with a small, coherent input set

Keep existing controls. Add RMB / K = directional cutter slash; Tab = map.
Mouse aim remains independent of W/S movement/dash keys; J/C preserves W/S aim.
Do not bind reload to R (R already retries). Avoid charge attacks in this pass.

Create `CombatConfig` resource for combat constants, in frames and pixels at
60Hz. Initial values below are starting balance targets, not untouchable limits.

| Mechanic | Initial implementation |
| --- | --- |
| Gun | 1 damage; 12-frame cadence in air and on ground; 33-frame ground recharge after last shot |
| Landing | Preserve instant magazine refill on a new landing; standing refills after recharge delay |
| Slash | 2 damage, 44px reach, 120-degree front arc; 3-frame windup, 7 active, 14 recovery |
| Slash contact | One hit per enemy per swing, 12-frame normal-enemy stagger; cannot hit through tiles or closed gates |
| Parry | During first 5 active slash frames, reflect incoming projectiles in the aimed direction for 3 damage |
| Parry reward | Fill magazine and clear shot cooldown; distinct mint spark + sound |
| Melee reward | Recover one cell once per swing that hits an enemy; never on walls or empty swings |
| Downward slash | Enemy hit bounces player upward at vy=-5.8; one bounce per swing; no automatic dash refill |
| Damage safety | Keep 78-frame post-hit immunity; parry covers projectiles in its arc, not contact/spikes/lasers |

Snapshot slash direction at start; draw the arc throughout its short animation.
Track per-swing hit ids and parried projectile ids. Process active parry before
hostile-player collision in the same frame. A reflected shot cannot hit the
player and carries an explicit faction/damage field. Stagger must not skip
unrelated collision checks or freeze boss state indefinitely.

Centralize damage/death in one helper used by gun, melee, and reflection. Preserve
boss reward flags, clear hazards safely on death, and count each kill once.
Bosses receive damage but no repeatable normal-enemy stagger. An uninterrupted
melee spam strategy should lose to contact/attacks; a timed parry should feel strong.

Teach in-world: safe weapon alcove, a single slow projectile source, then a
single crawler. Brief prompts show shoot, slash/parry, and downward recoil.
Pause screen lists all controls, including map. Never rely on persistent HUD prose.

## 4. Replace the shelf chain with an 18-room connected world

Use named rooms, doors, and progression flags; eliminate platform-index coupling.
Implement data in `src/world/campaign_layout.gd` and runtime transitions in
`scenes/world_rooms.gd`. The existing procedural tile renderer can be reused.
Keep custom `LevelLayout` override functional and guard empty optional content.

Room data: id, region, map cell, origin/bounds, local solid rectangles, spawn
anchors, door links, checkpoints, entities, gate ids, traversal edges, optional
reward, and landmark. Door data: id, destination room/anchor, local trigger,
requirement, optional one-way shortcut flag. Entity ids must be unique/stable.

Use 960x576 room bounds (60x36 tiles), placed at separated world origins using
an explicit room index grid. Use local coordinates in authoring. Camera clamps
to current bounds with half-viewport extents (320,180). Boss rooms can be 640x360.
Doors at boundary alcoves transition to destination anchors using E and a short
fade. These are connections between named regions, with consistent map directions
and return links, rather than repeated elevators up the old shaft. Freeze player
and combat during transition, clear projectiles, and suppress held E until release.

Campaign connections and authored identities:

| ID | Identity / route | Connections and reward |
| --- | --- | --- |
| wreck | Safe crash basin, short horizontal intro | Free cutter; east to junction |
| junction | Central hub, three visibly different exits, anchor | West wreck; north hollow via recoil; east glass blue gate; upper chimney boot latch |
| hollow | Low combat route versus raised recoil route around cover | Warden east; archive south; return junction |
| warden | First boss, two low cover islands | Victory grants second cell; opens east relay; return hollow |
| relay | Horizontal industrial galleries, two connected elevations | Persistent two-switch circuit opens boots alcove; west warden; north chimney after boots |
| boots | Quiet equipment nook, practical exit kick | Boots; immediate one-kick tutorial; return relay |
| chimney | Short offset wall transfers, side exits and rest shelves | Sentinel east; north canopy triple-cell gate; opens return shortcut to junction by wall kick |
| sentinel | Reflective boss chamber with clear lanes | Victory grants dash; return chimney |
| glass | Junction's previously visible blue passage; horizontal phase route | Reservoir east; cistern south; return junction once breached |
| reservoir | Low sheltered route versus high exposed route; vent timing | Rootheart east; return glass |
| rootheart | Root-column boss arena | Victory grants third cell; return reservoir; exit shortcut to chimney |
| canopy | Three-cell rise into lateral branches; airborne core circuit | Storm east after core; roost north; return chimney |
| storm | Alternating sheltered crossings, mixed enemies, final anchor | Crown east; one-way lever opens return shortcut to junction |
| crown | Final boss combining previously learned responses | Victory opens summit |
| summit | Short safe arrival and transmitter | E at transmitter wins; no fixed global y win condition |
| archive | Optional early recoil detour, compact combat puzzle | Suit fragment; later boots shortcut to relay |
| cistern | Optional dash detour with visible safe waiting bays | Suit fragment; return glass |
| roost | Optional advanced kick/dash loop | Full repair cache + stronger visual trail at summit; return canopy |

Two suit fragments increase maximum health from 3 to 4; both optional, explicitly
shown on map after discovery. Keep base game beatable at 3. No mandatory power
upgrade is hidden in an unmarked secret. Optional reward collection persists on death.

Critical route:
`wreck > junction > hollow > warden > relay > boots > chimney > sentinel >
junction (new shortcut) > glass > reservoir > rootheart > chimney (new shortcut) >
canopy > storm > crown > summit`.

Ability placement rules:

- Gun precedes the first required recoil jump. Warden is reachable with one cell.
- Warden grants two cells before relay; boots are an exploration reward, not another boss.
- Sentinel requires the boot route, but no dash. Every mandatory blue membrane is AFTER dash.
- Triple-cell gate is seen in chimney before obtaining its upgrade; later returning is purposeful.
- Relay switches latch independently forever; do not demand a blind five-second cross-room run.
- Canopy core still requires three airborne shots in one flight, but provide a
  broad launch platform and a target under the player's recoil path, with visible 0/3 feedback.
- Shortcut levers are operable from their far side and remain open. Show links on map.

Geometry authoring contract:

- Standard room floor is local y=544; leave 32px solid base and 16px walls.
  Doors/checkpoints sit on flat 64px+ safe alcoves with body-clear spawn anchors.
- Ordinary rises 16–40px, same-height gaps <=80px. One-cell rises 64–80px.
  Two-cell rises 112–136px. Three-cell rises 184–192px with generous landing width.
- Main landings >=64px wide (96 preferred); 32px clear headroom minimum.
  Wall-kick transfers need a reachable wall, first kick, and a landing before
  another kick. Do not build a chimney requiring unlimited wall kicks.
- Dash membranes 16px thick, with a clear approach and landing on both sides;
  use horizontal passages first. Retain current dash impulse unless tests expose
  a specific need; do not promise long dashes that the measured config cannot do.
- Rooms use varied motifs: horizontal cover gallery, descent loop, fork with
  high/low options, offset wall transfer, membrane corridor, vent bays, recoil core.
  No more than two consecutive recoil-jump transfers on the mandatory route.
- Every room's mandatory landing edges are data, consumed by reachability tests.
  Search real geometry and save a successful input trace; do not judge by rises alone.
- Drops have a safe return or a checkpoint fallback with retained upgrades.
  Never depend on a living enemy to leave a room.

## 5. Enemies and encounter pacing

Retain crawlers and drifters but give them purposeful behavior. Add two roles;
distinct silhouettes/colors/tells are required, not identical enemies with new stats.

| Role | Behavior and counterplay |
| --- | --- |
| Crawler / 2 HP | Patrols its supported platform; on proximity telegraphs 24 frames, lunges 30 at 90px/s, recovers 36. Slash or jump/pogo. Never walks off its support |
| Drifter / 2 HP | Hovers near home, 3-shot fan at 105px/s, 96-frame cycle and visible 24-frame tell. Parry or use cover |
| Hunter / 3 HP | Locks a direction during 30-frame tell, dives 30 at 180px/s, recovers 48. No steering during dive, no travel through walls; punish recovery |
| Sentry / 3 HP | Fixed mount; thin aiming line for 42 frames, locks last 18; fires 210px/s bolt, then 60-frame recovery. Move after lock, parry, or flank |

Activate only enemies in the current room. LOS blocks shooting through tiles and
closed gates. Centralize timers in config using frames. New arrivals get at least
60 frames before the first attack. Keep projectiles capped and expire off-room.

Encounter budget: first lesson one enemy, early rooms 2–3 across separate pockets,
mid rooms 3–4, late 4–5 with no more than 3 actively engaging at once. Mix roles:
crawler + sentry cover problem; drifter + kick transfer; hunter over broad landing.
Never aim an unavoidable shot at a spawn/checkpoint. At least one safe pause bay
per traversal room. No spikes on mandatory tiny landing centers.

Unfinished room enemies reset on death; upgrades/keys/shortcuts remain. Cleared
rooms stay cleared during ordinary backtracking; use stable ids to track clears.
No random attrition respawns. Deterministic encounter reset rules must be tested.

## 6. Four harder, readable bosses

Reuse silhouettes and warning renderer, but bind encounters to room ids instead
of platform indices. Create an explicit attack scheduler: tell, active, recovery.
Freeze target at end of aiming tell. Give every boss at least a 45-frame opening
and a 45–60-frame punish window after its major attack. Tune HP around actual
gun/slash/parry damage; initial HP 18/24/28/36. Target 45–90 second successful fights.

All bosses: full-health checkpoint immediately outside, contact deals one,
predictable enraged phase at <=50%, victory clears attacks, death resets boss,
no progression/item loss. No phase transition damage without warning.

| Boss | Attack cycle and new behavior | Valid response |
| --- | --- | --- |
| Warden | Aimed fan; traveling floor shockwave; NEW marked ground slam followed by two spreading ground waves | Jump onto low islands; move from slam marker; parry fan; slam recovery lowers boss into melee range |
| Sentinel | Locked vertical lances; NEW ricochet bolt (one bounce, drawn trail); NEW horizontal beam sweep at one of two heights | Change lanes after lock; parry bolt; duck below high beam on floor or jump low beam using islands |
| Rootheart | Root columns; NEW falling seed bombs with ground markers; NEW alternating side vine sweeps | Move to reachable safe lane; leave seed markers; jump low sweep. Seeds burst into at most 3 slow parryable shots |
| Crown | Rotating ring with intentional gap; staggered lances; NEW marked dash across arena; alternating floor/air sweep | Follow ring gap; bait dash then cross behind; use islands and parries; long recovery after dash |

Do not globally accelerate all attacks in enrage. Add one secondary beat or
alternate pattern, preserving minimum tells (typically 45–66 frames). Never
randomly stack room-wide floor and air denial. Only one full-area denial at a time.
Rootheart safe lane must be adjacent/reachable from the player's locked target
lane within the tell, not rotate to an unreachable far edge. Projectile patterns
remain finite; parry does not affect solid beams, marked in warm red.

Represent moving shockwaves/dashes with swept collision. Attack queue updates
must remain safe when death clears the entire queue during iteration.

## 7. HUD, navigation, and presentation

- Remove top-left ASCENT/zone panel entirely during play.
- Remove top-right ammo label and cell bars. Retain a compact health-only display.
- Crosshair: center dot + one ring segment per maximum cell, around radius 10px;
  filled amber/mint for loaded, dim outline for empty, visible gaps. One-cell
  version is a nearly full ring. Ready/cooldown changes brightness, never count.
- Add a thin inner recharge sweep only while grounded and recharging. The ammo
  ring must agree with actual ammo on shots, landing, parry, upgrades, death, pause.
- Do not add another persistent combat text panel. Transient tutorials and room
  entry titles can appear near the bottom; wrap text inside viewport bounds.
- Tab toggles a paused map with discovered rooms/links, current location,
  seen-but-locked exits showing ability icons, anchors and discovered rewards.
  Unknown rooms are outlines only; avoid revealing undiscovered secrets.
- Map and Escape pause must share explicit pause state; closing one cannot
  accidentally resume the other. Hide custom crosshair while paused/in menus.
- Map layout uses authored cells, not the separated runtime room origins.
- In-world door labels identify destination or required ability. Unique region
  accents/landmarks: wreck amber, hollow purple, relay copper, glass cyan,
  reservoir green, canopy gold, crown violet. Preserve projectile contrast.
- Replace global altitude meter/rail with the map; artificial room positions
  must not display fictional altitude jumps.
- Update scenery camera culling for both axes and room bounds; hardcoded wreck,
  transmitter, sky and boot tutorial art must be attached to room-local landmarks.

## 8. Recovery and state integrity

Replace monotonically increasing checkpoint_index with active checkpoint id
and visited set. Revisiting an anchor restores health and selects it. Spawn data
includes room and position. E can explicitly rest at an anchor when already there.
Boss entries set a safe exterior retry anchor, never an interior sealed spawn.

Replace `position.y > spawn_point.y + 450` and SUMMIT-based global assumptions
with current room death bounds. Successful room transitions update room state,
camera and any safe fallback atomically, without converting every door to a heal.
Reset velocity, transient attack/input state, projectiles and camera interpolation
on respawn. Set previous_position to spawn to avoid a phantom gate sweep.

Keep session-only progress in this pass; no save/load system needed. Tests cover
death after each upgrade and after each shortcut, return to old anchors, falling
from both branches, and entering a boss immediately after a room transition.

## 9. Implementation order and checkpoints

1. Barrier helper and regression tests on old expedition. Validate movement and
   integration before world changes. This is the first independently shippable fix.
2. CombatConfig + slash/parry + unified damage + cadence + crosshair cleanup.
   Test with old enemies before adding roles. Preserve core recoil semantics.
3. Room schema/runtime + map + room-aware checkpoints/camera. Author wreck,
   junction, hollow and Warden as a vertical slice; verify a complete round trip.
4. Author remaining rooms and named progression. Place every upgrade and shortcut.
   Add graph and real movement reachability tests before decorating the campaign.
5. Enemy roles, room encounter budgets, optional rewards, recovery rules.
6. Boss scheduler and four attack sets. Verify geometry/time escape routes and
   phase transitions at three base health; tune damage windows and enemy cadence.
7. Room-local art, map readability, tutorials, audio feedback, docs, full QA.
8. Validate all suites, run rendered checks and a full fresh progression replay,
   build the local Web export with `tools/build-web.cmd`, and smoke-test it.
   Report remaining limitations honestly. Do not deploy/push absent user request.

Keep implementation modular: movement remains pure; gate and combat helpers
have testable state; rooms/progression are named data. Do not expand main.gd into
one giant state machine. Use explicit GDScript types when Dictionary values make
inference ambiguous. Import via existing validator after adding class_name scripts.

## 10. Verification and completion gates

Preserve the 55 historical movement tests. Keep old expedition reachability as
a legacy fixture when replacing the live campaign; move it into an explicitly
constructed legacy world rather than deleting its coverage. Tests asserting old
gun cadence or old map indices must migrate to the new intended behavior with
equivalent assertions. Share production gate collision; do not copy the old bug
into the test search. Do not weaken tests merely to get a green result.

Add bounded suites (with unconditional quit and watchdog) for:

- Gate regressions listed above, including the original reported failure.
- Slash arc/range/occlusion; once-per-swing damage/refill; parry timing and damage;
  empty slash yields no ammo; recoil unaffected; no projectile-array mutation crash.
- All door destinations/spawns valid, reciprocal links except deliberate shortcuts,
  room bounds valid, prerequisites acyclic, every essential reward reachable before
  its own gate, optional secrets unnecessary, summit reachable with no damage boosts.
- Each mandatory physical traversal edge with actual tiles, gates, input, cooldown,
  ammo, wall kick and dash state. Multiple launch offsets and timing margins,
  plus negative tests for the intended ability locks. Save valid input traces.
- A sequential campaign integration replay collecting real pickups/switches,
  making transitions, testing gated progress and deaths. Distinguish this from
  a combat playthrough if bosses are defeated by test harness damage.
- Boss attack coverage, target locking, reachable safe lanes, phase/death reset,
  hazard clear on victory, no forbidden overlapping denial patterns.
- Health fragment cap, checkpoints/backtracking, map pause, all ammo-ring states,
  keyboard/mouse input coexistence, clean custom-layout startup.

Rendered checks: title, 0/1/2/3 cells and cooldown crosshairs, slash/parry contact,
hub with locked/unlocked paths, three visually different traversal rooms, map,
each boss tell/live/recovery phase, death/retry, summit. Update capture driver to
use room ids instead of old fixed coordinates. Inspect images, not just file existence.

Required human-like play validation: fresh character through gun, Warden, boots,
Sentinel, first blue barrier, Rootheart, core, Crown and exit; revisit an older
region with new movement; deliberately die during a gate crossing and boss phase.
Record whether validation was automated input or manual play and any untested
segments. A graph proof or screenshot alone is not proof the game is enjoyable.

Balance acceptance targets: no three consecutive identical mandatory jumps;
three meaningful return shortcuts; two early visible ability-gated routes;
all four bosses have unique new attacks; early lessons forgive mistakes; late
rooms reward movement/defense; no unavoidable entry damage or softlocks.

Update README/DESIGN/STATUS with final controls, region progression, parry rules,
tests actually run, and session save limitations. If making a local commit under
repo workflow, stage only task-owned changes after inspecting the final diff.

## Decisions already made; no blocking questions

Use RMB/K slash/parry, persistent breached membranes, an 18-room connected map,
exploration-earned boots, existing four bosses, two optional health fragments,
ground-based normal ammo refill, named doors and checkpoints, session persistence,
and a local Web build. Scope excludes inventory/crafting, procedural generation,
new external art dependencies, multiplayer, gamepad support and cloud saving.
Implementation still requires playtesting and tuning; the plan removes the main
design/architecture decisions rather than promising that a redesign is trivial.
