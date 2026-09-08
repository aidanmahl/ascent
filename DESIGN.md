# Ascent: recoil expedition design

This is the current playable design, superseding the older movement gym specification and the first First Light build.

## Movement and combat rules

- Three health. Damage grants 1.3 seconds of protection. Twelve signal anchors restore health and bound retries; falling far below the latest anchor also recovers the astronaut.
- No double jump. The old optional movement-core branch remains solely for regression compatibility; the live player permanently disables it.
- The cutter is found after five ordinary-jump landings, not beside the ship. Its magazine progresses from one to two to three cells.
- Downward fire adds recoil and arrests a fall. Fire cooldown is 0.19 seconds. Landing refills ammo, dash, and the wall-kick charge; touching a wall refills none of them.
- Magnetic boots are earned, not available at spawn. One wall kick per landing; vertical launch is 3.8–4.3 pixels per physics step, down from 6–6.5. No zero-gravity cling. The player retains air control.
- The vector thruster enables directional dashes and passes blue membranes. Membranes are solid to ordinary movement: taking damage cannot bypass the gate.
- Drifters hover on fixed sine paths and fire a three-shot, 20-degree spread every 1.65 seconds in range. Bullets aim once, travel at a constant 76 pixels/second, and never home. Guardian fans travel at 66 pixels/second and occasional radial volleys at 54. Wind-up rings telegraph shots.
- Friendly pulses destroy hostile projectiles. Combat and traversal share the magazine, so the player must choose whether to spend airborne shots on lift, defense, or damage.

## Progression

| Region | Challenge / reward | What it teaches or requires |
| --- | --- | --- |
| Salvage Trail | Narrow climbing ledges to the lost pulse cutter | Ordinary jumping and variable jump height before introducing recoil |
| Warden's Hollow | 96-pixel recoil shafts; defeat the Hollow Warden for cell two | Gun-required ascent and shooting down hostile spreads |
| Relay Mines | Fire at two relays within five seconds across a stone divider; claim kick boots | Reposition using recoil, then perform the finite wall transfer |
| Glass Sanctuary | Defeat the Glass Sentinel for the vector thruster | Dash through a membrane, then steer onto a separate landing |
| Rootheart | Defeat Rootheart for cell three; shoot the core three times in one flight | Full magazine management; grounded shots and partial flights do not unlock the core |
| Storm Canopy | Tall, offset ledges, another membrane, geysers and Drifters | Chain recoil, dash and limited wall recovery while managing incoming fire |
| The Crown | Final guardian, sealed roof, rescue transmitter | Final combat checkpoint and chapter completion |

The route climbs from y=480 to y=-4048 (43 authored route connections), over twice the previous chapter's vertical distance. Combat detours, partitions, stone diaphragms, hazard strips, and timed vents interrupt the ascent. Upgrades appear as caged guns, magazines, boots and thrusters; equipping them visibly changes the astronaut's weapon cells, soles, backpack and exhaust. Recoil and wall kicks have separate brief animations.

## Verification and limits

The expedition suite searches every route connection with the equipment available at that stage using the actual movement/collision implementation. Negative checks verify that the first recoil shaft, second-cell shaft, wall transfer and membrane cannot be crossed by the search policies without their intended abilities. These are practical traversal checks, not a proof against every possible speedrunning technique.

Integration checks cover projectile cancellation and constant velocity, airborne core completion using actual weapon travel/recoil, relay expiry, single-use kicks, locked cages, boss recovery, and lethal-volley cleanup. The 55 historical movement tests also remain in place.

Progress persists for the current session. Desktop keyboard/mouse controls remain the target. Hazard cycles and enemy fire introduce timing requirements beyond the geometry search; screenshots check the actual rendered rooms and equipment.
