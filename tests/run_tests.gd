extends Node

const WATCHDOG_SECONDS := 10.0

func _ready() -> void:
	_start_watchdog()

	var runner := TestRunner.new()
	_register_tests(runner)

	var all_passed := runner.run_all()
	get_tree().quit(0 if all_passed else 1)

func _start_watchdog() -> void:
	var watchdog := Timer.new()
	watchdog.wait_time = WATCHDOG_SECONDS
	watchdog.one_shot = true
	watchdog.timeout.connect(func() -> void:
		printerr("WATCHDOG: tests did not finish in %ss, force-quitting" % WATCHDOG_SECONDS)
		get_tree().quit(1)
	)
	add_child(watchdog)
	watchdog.start()

func _register_tests(runner: TestRunner) -> void:
	runner.register("coyote_time_5_frames_after_leaving_ground_succeeds", _test_coyote_succeeds_at_5)
	runner.register("coyote_time_8_frames_after_leaving_ground_fails", _test_coyote_fails_at_8)
	runner.register("jump_buffer_6_frames_before_landing_fires_on_landing", _test_jump_buffer_fires_on_landing)
	runner.register("jump_buffer_beyond_window_does_not_fire", _test_jump_buffer_expires)
	runner.register("variable_height_early_release_peaks_lower_than_held", _test_variable_height)
	runner.register("jump_corner_near_miss_passes_through", _test_jump_corner_near_miss_passes_through)
	runner.register("jump_corner_large_overlap_still_blocks", _test_jump_corner_large_overlap_still_blocks)
	runner.register("ledge_forgiveness_keeps_grounded_while_any_overlap", _test_ledge_forgiveness_keeps_grounded_while_any_overlap)
	runner.register("ledge_forgiveness_still_falls_once_fully_clear", _test_ledge_forgiveness_still_falls_once_fully_clear)
	runner.register("never_tunnels_through_floor_at_max_fall_speed", _test_no_tunneling_at_max_fall_speed)
	runner.register("input_map_binds_move_and_jump_to_spec_keys", _test_input_map_bindings)
	runner.register("wall_jump_lockout_blocks_input_for_8_frames", _test_wall_jump_lockout)
	runner.register("wall_cling_zero_gravity_then_slide_cap", _test_wall_cling_then_slide)
	runner.register("wall_slide_caps_fall_speed_from_faster_initial_fall", _test_wall_slide_caps_fall_speed)
	runner.register("wall_jump_away_from_wall_is_strong", _test_wall_jump_away_is_strong)
	runner.register("wall_jump_neutral_is_weak_and_high", _test_wall_jump_neutral_is_weak_and_high)
	runner.register("wall_detection_from_real_collision", _test_wall_detection_from_real_collision)
	runner.register("dash_bound_to_left_shift_only", _test_dash_bound_to_left_shift_only)
	runner.register("dash_exactly_12_frames_at_constant_speed_unaffected_by_gravity", _test_dash_duration_and_constant_speed)
	runner.register("dash_refills_only_on_ground_or_wall_contact", _test_dash_refill_only_on_ground_or_wall_contact)
	runner.register("double_jump_available_once_per_airborne_period", _test_double_jump_available_once_per_airborne_period)
	runner.register("dash_direction_snapping", _test_dash_direction_snapping)
	runner.register("dash_exit_velocity_retention_horizontal", _test_dash_exit_velocity_retention)
	runner.register("dash_exit_retains_upward_vertical_velocity", _test_dash_exit_retains_upward_vertical_velocity)
	runner.register("dash_cancels_on_wall_contact_and_refills", _test_dash_cancels_on_wall_contact_and_refills)
	runner.register("dash_cooldown_blocks_second_dash_for_exactly_6_frames", _test_dash_cooldown_blocks_second_dash)
	runner.register("wall_cling_no_freeze_while_rising", _test_wall_cling_no_freeze_while_rising)
	runner.register("wall_cling_holds_remaining_budget_near_apex", _test_wall_cling_holds_remaining_budget_near_apex)
	runner.register("wall_cling_no_pause_after_long_attached_ascent", _test_wall_cling_no_pause_after_long_attached_ascent)
	runner.register("wall_cling_preserves_slow_entry_uncapped", _test_wall_cling_preserves_slow_entry_uncapped)
	runner.register("ground_jump_into_wall_does_not_overshoot_height", _test_ground_jump_into_wall_does_not_overshoot_height)
	runner.register("wall_detach_grace_keeps_cling_attached", _test_wall_detach_grace_keeps_cling_attached)
	runner.register("wall_cling_persists_indefinitely_on_neutral", _test_wall_cling_persists_indefinitely_on_neutral)
	runner.register("wall_coyote_time_allows_late_wall_jump", _test_wall_coyote_time_allows_late_wall_jump)
	runner.register("wall_detach_grace_locks_horizontal_movement", _test_wall_detach_grace_locks_horizontal_movement)
	runner.register("wall_jump_during_late_grace_does_not_burn_double_jump", _test_wall_jump_during_late_grace_does_not_burn_double_jump)
	runner.register("reset_clears_state_and_returns_to_spawn", _test_reset_clears_state_and_returns_to_spawn)
	runner.register("wall_jump_toward_wall_cannot_chain_for_unlimited_height", _test_wall_jump_toward_wall_cannot_chain_for_unlimited_height)
	runner.register("wall_jump_neutral_state_ends_after_leaving_wall", _test_wall_jump_neutral_state_ends_after_leaving_wall)
	runner.register("wall_state_ends_when_walking_off_bottom_of_wall", _test_wall_state_ends_when_walking_off_bottom_of_wall)
	runner.register("wall_jump_toward_wall_then_correcting_has_no_velocity_discontinuity", _test_wall_jump_toward_wall_then_correcting_has_no_velocity_discontinuity)

func _default_config() -> MovementConfig:
	return load("res://src/movement/default_movement_config.tres")

## Coyote and jump-buffer tests inject on_floor directly (a "collision
## flag", settable like any other state field via InputPlayback) instead
## of building real floor geometry. That isolates the timer logic from
## collision resolution, which corner-correction/tunneling tests exercise
## separately. Both paths go through the same PlayerMovement.process().

func _test_coyote_succeeds_at_5() -> String:
	var result := _run_coyote_scenario(5)
	return Expect.is_true(result < -1.0, "velocity.y after pressing jump 5 frames after leaving ground (expected a jump, i.e. strongly negative vy)")

func _test_coyote_fails_at_8() -> String:
	var result := _run_coyote_scenario(8)
	return Expect.is_true(result > 0.0, "velocity.y after pressing jump 8 frames after leaving ground (expected still falling, i.e. positive vy)")

## call index 0 = last grounded frame (on_floor seeded true, then real
## collision against an empty world flips it false by the end of that
## call). call index 1 = the first airborne frame ("0 frames after leaving
## ground"), so call index (frames_after_leaving + 1) is where the press
## lands.
func _run_coyote_scenario(frames_after_leaving_ground: int) -> float:
	var config := _default_config()
	var state := MovementState.new()
	var total_frames := frames_after_leaving_ground + 5

	var base: Array[Dictionary] = [{"on_floor": true}]
	for i in range(total_frames - 1):
		base.append({})

	var press_at_call := frames_after_leaving_ground + 1
	var jump_pulse := InputPlayback.pulse("jump_pressed", press_at_call, total_frames)
	var frames := InputPlayback.merge(base, jump_pulse)

	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)
	return history[press_at_call].velocity.y

func _test_jump_buffer_fires_on_landing() -> String:
	var vy := _run_buffer_scenario(3, 6)
	return Expect.is_true(vy < -1.0, "velocity.y on landing when jump was pressed 6 frames earlier (expected a jump)")

func _test_jump_buffer_expires() -> String:
	var vy := _run_buffer_scenario(3, 9)
	return Expect.is_true(vy > -1.0, "velocity.y on landing when jump was pressed 9 frames earlier, beyond the 8-frame buffer (expected no jump)")

## Presses jump at call index `press_at`, then lands (on_floor injected
## true) `gap` frames later. Never grounded before the press, so coyote
## stays at 0 throughout and only the buffer can explain a fire.
func _run_buffer_scenario(press_at: int, gap: int) -> float:
	var config := _default_config()
	var state := MovementState.new()
	var land_at := press_at + gap
	var total_frames := land_at + 3

	var base: Array[Dictionary] = []
	for i in range(total_frames):
		base.append({})
	base[land_at] = {"on_floor": true}

	var jump_pulse := InputPlayback.pulse("jump_pressed", press_at, total_frames)
	var frames := InputPlayback.merge(base, jump_pulse)

	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)
	return history[land_at].velocity.y

func _test_variable_height() -> String:
	var config := _default_config()
	var total_frames := 40

	var held_peak := _peak_height(_run_jump(config, total_frames, -1))
	var released_early_peak := _peak_height(_run_jump(config, total_frames, 2))

	# position.y is smaller (more negative) higher up, so a lower peak
	# means a numerically larger minimum y.
	return Expect.is_true(released_early_peak > held_peak + 2.0, "early-release peak height (%s) should be measurably lower than held peak (%s)" % [released_early_peak, held_peak])

## Presses jump at frame 0 (grounded), optionally releases at `release_at`
## (-1 = never release). solid_tiles is empty, so once airborne there's
## nothing to land on for the rest of the run.
func _run_jump(config: MovementConfig, total_frames: int, release_at: int) -> Array[MovementState]:
	var state := MovementState.new()
	var base: Array[Dictionary] = [{"on_floor": true, "jump_pressed": true}]
	for i in range(total_frames - 1):
		base.append({})
	if release_at >= 0:
		var release_pulse := InputPlayback.pulse("jump_released", release_at, total_frames)
		base = InputPlayback.merge(base, release_pulse)
	return InputPlayback.run(state, config, base, PlayerMovement.process)

func _peak_height(history: Array[MovementState]) -> float:
	var min_y := history[0].position.y
	for s in history:
		min_y = minf(min_y, s.position.y)
	return min_y

## Milestone 4 tuning iteration 3: replaced the old nudge-based corner
## correction (ceiling-only, and it separately caused an early-ledge-drop
## bug by nudging players off ledges during floor resolution too) with a
## horizontal-only collision_width_margin_px (2px per side) - the actual
## collision width is narrower than the visual 10px sprite, so a few
## pixels of visual overlap never registers as contact at all, on any
## axis, for any reason. A single tile at column 1, row 0 sits just beside
## the player's straight-up path. With the full 10px visual width the
## player's right edge would poke 2px into that column; with the narrower
## effective width (half = 5 - 2 = 3) it clears with zero overlap - no
## nudge needed, it just was never touching.
func _test_jump_corner_near_miss_passes_through() -> String:
	var config := _default_config()
	var solid_tiles := {Vector2i(1, 0): true}
	var state := MovementState.new()
	state.position = Vector2(13, 24)  # narrow right edge at 16: exactly clears tile [16,32)
	state.velocity = Vector2(0, config.jump_velocity)

	var frames := InputPlayback.hold({}, 5)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process, solid_tiles)

	var failure := Expect.is_true(history[-1].position.y < 0.0, "player should have risen past y=0, got y=%s" % history[-1].position.y)
	if failure != "":
		return failure
	return Expect.is_false(history[0].on_ceiling, "first frame should not register as a ceiling hit - the margin-narrowed hitbox never actually overlapped the tile")

## Same setup, but the player's narrow (margin-applied) hitbox still
## overlaps the blocking tile by a full 6px - well beyond what the margin
## forgives - so it must block normally.
func _test_jump_corner_large_overlap_still_blocks() -> String:
	var config := _default_config()
	var solid_tiles := {Vector2i(1, 0): true}
	var state := MovementState.new()
	state.position = Vector2(20, 24)  # narrow edges [17,23]: solidly inside tile [16,32)
	state.velocity = Vector2(0, config.jump_velocity)

	var frames := InputPlayback.hold({}, 1)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process, solid_tiles)

	return Expect.is_true(history[0].on_ceiling, "large overlap should still block as a normal ceiling hit")

## The other side of the same margin: standing near a ledge, the player
## should stay grounded as long as ANY part of the (margin-narrowed)
## hitbox still overlaps the floor tile below - not just most of it. A
## floor tile at column 0 spans x in [0,16); standing at x=18.9 puts the
## narrow left edge at 15.9, a hair still over the tile.
func _test_ledge_forgiveness_keeps_grounded_while_any_overlap() -> String:
	var config := _default_config()
	var solid_tiles := {Vector2i(0, 5): true}
	var state := MovementState.new()
	state.position = Vector2(18.9, float(5 * config.tile_size) - config.collider_size.y * 0.5)
	state.velocity = Vector2(0, 1.0)

	var frames := InputPlayback.hold({}, 1)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process, solid_tiles)

	return Expect.is_true(history[0].on_floor, "any overlap with the ledge, even a sliver, should keep the player grounded")

## Same setup, moved 0.2px further out so the narrow hitbox has fully
## cleared the tile (narrow left edge at 16.1, past the tile's 16px
## boundary) - the margin forgives near-misses, it doesn't hold you up
## indefinitely once you're actually clear.
func _test_ledge_forgiveness_still_falls_once_fully_clear() -> String:
	var config := _default_config()
	var solid_tiles := {Vector2i(0, 5): true}
	var state := MovementState.new()
	state.position = Vector2(19.1, float(5 * config.tile_size) - config.collider_size.y * 0.5)
	state.velocity = Vector2(0, 1.0)

	var frames := InputPlayback.hold({}, 1)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process, solid_tiles)

	return Expect.is_false(history[0].on_floor, "fully clear of the ledge (even accounting for the margin) should fall, not stay held up")

## Drops the player from max fall speed toward a floor and asserts the
## resolved position never sinks below the floor's surface at any frame,
## regardless of how it got there. This only holds because every speed in
## MovementConfig is below tile_size (16px) - a single frame's move can
## never fully skip a one-tile-thick floor.
func _test_no_tunneling_at_max_fall_speed() -> String:
	var config := _default_config()
	var precondition := Expect.is_true(config.max_fall_speed < config.tile_size, "precondition: max_fall_speed must stay below tile_size for discrete collision to be tunnel-safe")
	if precondition != "":
		return precondition

	var floor_row := 5
	var solid_tiles: Dictionary = {}
	for col in range(-2, 3):
		solid_tiles[Vector2i(col, floor_row)] = true

	var state := MovementState.new()
	state.position = Vector2(0, float(floor_row * config.tile_size) - 40.0)
	state.velocity = Vector2(0, config.max_fall_speed)

	var frames := InputPlayback.hold({}, 30)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process, solid_tiles)

	var floor_top: float = float(floor_row * config.tile_size)
	var resting_bottom_max: float = floor_top + 0.01
	var landed := false
	for s in history:
		var bottom: float = s.position.y + config.collider_size.y * 0.5
		if bottom > resting_bottom_max:
			return "player sank below the floor surface: bottom=%s, floor_top=%s" % [bottom, floor_top]
		if s.on_floor:
			landed = true

	return Expect.is_true(landed, "player should have landed on the floor by the end of the run")

## project.godot's [input] section is hand-written InputEventKey resource
## syntax, easy to get subtly wrong (physical_keycode vs keycode, wrong
## numeric value). SPEC.md section 3: move = A/D, jump = Space.
func _test_input_map_bindings() -> String:
	var failure := _check_action_key("move_left", KEY_A)
	if failure != "":
		return failure
	failure = _check_action_key("move_right", KEY_D)
	if failure != "":
		return failure
	failure = _check_action_key("jump", KEY_SPACE)
	if failure != "":
		return failure
	return _check_action_key("reset", KEY_R)

func _check_action_key(action: String, expected_keycode: Key) -> String:
	if not InputMap.has_action(action):
		return "InputMap is missing action '%s'" % action

	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == expected_keycode:
			return ""

	return "action '%s' has no InputEventKey bound to physical_keycode %s" % [action, expected_keycode]

## Wall tests inject on_wall_left/right directly, same reasoning as the
## coyote/buffer tests: isolates the jump/gravity/timer logic from
## collision resolution, which _test_wall_detection_from_real_collision
## covers separately.

## SPEC.md section 10's only explicitly-named wall rule. Fires a strong
## (away-from-wall) jump at frame 0, then holds the opposite direction
## (fighting the launch) for the next several frames. As implemented,
## wall_jump_lockout_frames (8) covers frames 0..7 inclusive - the launch
## frame counts as the first locked frame, since the timer is refreshed
## before _apply_run reads it that same frame.
##
## Milestone 4 tuning iteration 5: lockout no longer freezes vx outright -
## friction still decays it (just not player input), so the eventual
## input-driven reversal isn't a sudden snap from a dead-flat hold. Checks
## the exact friction-decay curve during lockout instead of an unchanging
## value, then confirms real (turnaround-boosted, since still opposing)
## acceleration takes over once lockout expires.
func _test_wall_jump_lockout() -> String:
	var config := _default_config()
	var state := MovementState.new()

	var frames: Array[Dictionary] = [{"on_wall_left": true, "jump_pressed": true, "move_right": true}]
	for i in range(9):
		frames.append({"on_wall_left": false, "move_right": false, "move_left": true, "jump_pressed": false})

	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	var launched_vx: float = history[0].velocity.x
	var failure := Expect.approx(launched_vx, config.wall_jump_velocity.x, "vx immediately after a strong (away-from-wall) wall jump")
	if failure != "":
		return failure

	var expected := launched_vx
	for i in range(1, 8):
		expected = move_toward(expected, 0.0, config.air_friction)
		failure = Expect.approx(history[i].velocity.x, expected, "vx during wall jump lockout at frame %d should decay via friction, not stay frozen or respond to input" % i)
		if failure != "":
			return failure

	return Expect.is_true(history[8].velocity.x < expected, "vx at frame 8 (lockout expired) should respond to the held opposing input, decreasing further than friction alone would")

## First wall_cling_frames (13) frames of contact: velocity.y untouched by
## gravity (SPEC.md section 4 "zero gravity", taken literally - not a
## reset). Milestone 4 tuning iteration 1 briefly zeroed velocity.y on
## entry instead; iteration 2 reverted that (it made mistiming a running
## jump into a wall corner kill all momentum instead of letting it
## bump-and-keep-rising, which felt wrong) - back to preserving whatever
## vy the player arrived with. After the cling window, gravity resumes but
## clamped to wall_slide_max_fall_speed.
func _test_wall_cling_then_slide() -> String:
	var config := _default_config()
	var state := MovementState.new()
	state.velocity = Vector2(0, 3.0)

	var frames := InputPlayback.hold({"on_wall_left": true, "move_left": true}, 30)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	for i in range(config.wall_cling_frames):
		var failure := Expect.approx(history[i].velocity.y, 3.0, "vy during wall cling at frame %d (zero gravity expected, not arrested to 0)" % i)
		if failure != "":
			return failure

	return Expect.approx(history[-1].velocity.y, config.wall_slide_max_fall_speed, "vy well after the cling window should settle at the wall-slide cap")

## Seeds wall_contact past the cling window directly, so this isolates the
## slide cap from the cling phase entirely: even arriving at a wall already
## falling faster than the cap, the very first sliding frame should clamp
## down to it immediately.
func _test_wall_slide_caps_fall_speed() -> String:
	var config := _default_config()
	var state := MovementState.new()
	state.velocity = Vector2(0, 4.0)
	state.timers["wall_contact"] = config.wall_cling_frames + 1

	var frames := InputPlayback.hold({"on_wall_left": true, "move_left": true}, 5)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	return Expect.approx(history[0].velocity.y, config.wall_slide_max_fall_speed, "vy on the first sliding frame should clamp to the wall-slide cap even from a faster initial fall")

func _test_wall_jump_away_is_strong() -> String:
	var config := _default_config()
	var state := MovementState.new()
	var frames: Array[Dictionary] = [{"on_wall_left": true, "jump_pressed": true, "move_right": true}]
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	var vel := history[0].velocity
	var failure := Expect.approx(vel.x, config.wall_jump_velocity.x, "strong wall jump vx (away from a wall on the left, so positive)")
	if failure != "":
		return failure
	return Expect.approx(vel.y, config.wall_jump_velocity.y + config.gravity, "strong wall jump vy (one frame of gravity already applied)")

func _test_wall_jump_neutral_is_weak_and_high() -> String:
	var config := _default_config()
	var state := MovementState.new()
	var frames: Array[Dictionary] = [{"on_wall_left": true, "jump_pressed": true}]
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	var vel := history[0].velocity
	var failure := Expect.approx(vel.x, config.wall_jump_neutral_velocity.x, "neutral wall jump vx (no directional input held)")
	if failure != "":
		return failure
	return Expect.approx(vel.y, config.wall_jump_neutral_velocity.y + config.gravity, "neutral wall jump vy (one frame of gravity already applied)")

## Proves on_wall_right actually gets set by real TileCollision resolution,
## not just by the direct injection every other wall test uses to isolate
## timer/gravity logic.
func _test_wall_detection_from_real_collision() -> String:
	var config := _default_config()
	# Tall enough that gravity pulling the player down while it accelerates
	# sideways (nothing else to stand on here) can't carry it past the
	# bottom of the wall before it arrives horizontally.
	var solid_tiles: Dictionary = {}
	for row in range(-5, 20):
		solid_tiles[Vector2i(1, row)] = true
	var state := MovementState.new()
	state.position = Vector2(2, 8)

	var frames := InputPlayback.hold({"move_right": true}, 40)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process, solid_tiles)

	return Expect.is_true(history[-1].on_wall_right, "player pushing right into a real wall tile should register on_wall_right")

## User confirmed dash = left Shift specifically, not either shift.
## KEY_SHIFT alone doesn't distinguish sides - Godot 4's InputEventKey has
## a separate `location` property (KeyLocation enum) for exactly this.
## Proves the binding actually excludes right shift, not just that it
## parses - synthesizes both InputEventKey variants and checks
## InputMap.event_is_action() directly rather than trusting the resource
## text alone.
func _test_dash_bound_to_left_shift_only() -> String:
	if not InputMap.has_action("dash"):
		return "InputMap is missing action 'dash'"

	var left_shift := InputEventKey.new()
	left_shift.physical_keycode = KEY_SHIFT
	left_shift.location = KeyLocation.KEY_LOCATION_LEFT

	var right_shift := InputEventKey.new()
	right_shift.physical_keycode = KEY_SHIFT
	right_shift.location = KeyLocation.KEY_LOCATION_RIGHT

	if not InputMap.event_is_action(left_shift, "dash", true):
		return "left shift should match the 'dash' action"
	if InputMap.event_is_action(right_shift, "dash", true):
		return "right shift should NOT match the 'dash' action (must be left-shift only)"
	return ""

## The dash is active for exactly dash_duration_frames frames (returns
## true from _apply_dash that many times). Exit-velocity retention is
## applied within that same last active frame rather than a 13th frame
## after it - simpler than deferring it across a frame boundary, and still
## exactly 12 frames of the dash controlling velocity, per SPEC.md. So
## frames 0..(duration-2) show fully undiminished speed, and the last
## frame already reflects the retained value.
func _test_dash_duration_and_constant_speed() -> String:
	var config := _default_config()
	var state := MovementState.new()
	state.dash_available = true

	var frames: Array[Dictionary] = [{"dash_pressed": true, "move_right": true}]
	for i in range(15):
		frames.append({})
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	for i in range(config.dash_duration_frames - 1):
		var failure := Expect.approx(history[i].velocity.x, config.dash_speed, "vx during dash at frame %d should stay at constant dash speed" % i)
		if failure != "":
			return failure
		failure = Expect.approx(history[i].velocity.y, 0.0, "vy during dash at frame %d should be untouched by gravity" % i)
		if failure != "":
			return failure

	var last_active := config.dash_duration_frames - 1
	return Expect.approx(history[last_active].velocity.x, config.dash_speed * config.dash_exit_horizontal_retention, "vx on the dash's final active frame should already reflect exit retention")

## _refill_abilities runs after _resolve_collision, using this frame's real
## (post-resolution) on_floor - unlike most other wall/floor tests, it
## can't be isolated by injecting the flag via InputPlayback, since
## _resolve_collision would just overwrite that injection with whatever
## the (empty, in that style of test) solid_tiles says. Needs real
## geometry here instead.
func _test_dash_refill_only_on_ground_or_wall_contact() -> String:
	var config := _default_config()
	var floor_row := 5
	var solid_tiles := {Vector2i(0, floor_row): true}
	var state := MovementState.new()
	state.dash_available = false
	state.position = Vector2(0, float(floor_row * config.tile_size) - 40.0)

	var frames := InputPlayback.hold({}, 30)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process, solid_tiles)

	var landed_at := -1
	for i in range(history.size()):
		if history[i].on_floor:
			landed_at = i
			break
	if landed_at <= 0:
		return "test setup problem: player never landed (or landed immediately), can't check the mid-air/landed contrast"

	var failure := Expect.is_false(history[landed_at - 1].dash_available, "dash should not be available while still airborne with no wall contact")
	if failure != "":
		return failure
	return Expect.is_true(history[landed_at].dash_available, "dash should refill the moment it lands on the floor")

## Isolated from real collision/coyote by seeding double_jump_available
## directly and waiting out the ground-jump coyote window (6 frames)
## before pressing, so only the double-jump path can explain a fire.
func _test_double_jump_available_once_per_airborne_period() -> String:
	var config := _default_config()
	var state := MovementState.new()
	state.double_jump_available = true

	var frames: Array[Dictionary] = [{"on_floor": true}]
	for i in range(9):
		frames.append({})
	frames.append({"jump_pressed": true})
	frames.append({"jump_pressed": false})
	frames.append({"jump_pressed": true})
	frames.append({"jump_pressed": false})

	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	var first_press_frame := 10
	var failure := Expect.approx(history[first_press_frame].velocity.y, config.double_jump_velocity + config.gravity, "first mid-air jump press should fire the double jump")
	if failure != "":
		return failure

	var second_press_frame := 12
	return Expect.is_true(history[second_press_frame].velocity.y > config.double_jump_velocity + 1.0, "second mid-air jump press should NOT fire another double jump (already consumed this airborne period)")

func _test_dash_direction_snapping() -> String:
	var config := _default_config()

	var s1 := MovementState.new()
	s1.dash_available = true
	var f1: Array[Dictionary] = [{"dash_pressed": true, "move_right": true}]
	var h1 := InputPlayback.run(s1, config, f1, PlayerMovement.process)
	var failure := Expect.approx(h1[0].dash_direction.x, 1.0, "cardinal-right dash x")
	if failure != "":
		return failure
	failure = Expect.approx(h1[0].dash_direction.y, 0.0, "cardinal-right dash y")
	if failure != "":
		return failure

	var s2 := MovementState.new()
	s2.dash_available = true
	var f2: Array[Dictionary] = [{"dash_pressed": true, "move_right": true, "look_up": true}]
	var h2 := InputPlayback.run(s2, config, f2, PlayerMovement.process)
	var diag: float = sqrt(0.5)
	failure = Expect.approx(h2[0].dash_direction.x, diag, "diagonal (right+up) dash x")
	if failure != "":
		return failure
	failure = Expect.approx(h2[0].dash_direction.y, -diag, "diagonal (right+up) dash y")
	if failure != "":
		return failure

	var s3 := MovementState.new()
	s3.dash_available = true
	s3.facing = -1.0
	var f3: Array[Dictionary] = [{"dash_pressed": true}]
	var h3 := InputPlayback.run(s3, config, f3, PlayerMovement.process)
	return Expect.approx(h3[0].dash_direction.x, -1.0, "neutral-input dash should use current facing, not always right")

func _test_dash_exit_velocity_retention() -> String:
	var config := _default_config()
	var state := MovementState.new()
	state.dash_available = true

	var frames: Array[Dictionary] = [{"dash_pressed": true, "move_right": true}]
	for i in range(20):
		frames.append({})
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	var exit_frame := config.dash_duration_frames - 1
	var expected_vx: float = config.dash_speed * config.dash_exit_horizontal_retention
	return Expect.approx(history[exit_frame].velocity.x, expected_vx, "vx right as a horizontal dash ends should retain dash_exit_horizontal_retention of dash speed")

## Milestone 4 tuning iteration 2: upward dashes used to stop dead at exit
## (velocity.y zeroed) - now retained through dash_exit_retention_vertical,
## the same way horizontal exit velocity already was, so a dash upward
## feels like a launch that carries rather than a hard stop.
func _test_dash_exit_retains_upward_vertical_velocity() -> String:
	var config := _default_config()
	var state := MovementState.new()
	state.dash_available = true

	var frames: Array[Dictionary] = [{"dash_pressed": true, "look_up": true}]
	for i in range(20):
		frames.append({})
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	var exit_frame := config.dash_duration_frames - 1
	var expected_vy: float = -config.dash_speed * config.dash_exit_retention_vertical
	return Expect.approx(history[exit_frame].velocity.y, expected_vy, "vertical velocity right as an upward dash ends should retain dash_exit_retention_vertical of dash speed, not zero out")

func _test_dash_cancels_on_wall_contact_and_refills() -> String:
	var config := _default_config()
	var state := MovementState.new()
	state.dash_available = true

	var frames: Array[Dictionary] = [{"dash_pressed": true, "move_right": true}]
	frames.append({"on_wall_right": true})

	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	var failure := Expect.is_true(history[1].dash_available, "dash should refill immediately on wall-contact cancellation")
	if failure != "":
		return failure
	return Expect.approx(float(history[1].timers.get("dash_timer", -1)), 0.0, "dash should have been cancelled (timer reset to 0) rather than continuing")

func _test_dash_cooldown_blocks_second_dash() -> String:
	var config := _default_config()
	var state := MovementState.new()
	state.dash_available = true

	var frames: Array[Dictionary] = [{"dash_pressed": true, "move_right": true}]
	for i in range(config.dash_duration_frames - 1):
		frames.append({})
	InputPlayback.run(state, config, frames, PlayerMovement.process)
	# Re-grant the charge directly (it won't refill mid-air on its own) so
	# only the separate cooldown gate is under test here.
	state.dash_available = true

	var post_frames: Array[Dictionary] = []
	for i in range(config.dash_cooldown_frames):
		post_frames.append({"dash_pressed": true, "move_right": true})
	var post_history := InputPlayback.run(state, config, post_frames, PlayerMovement.process)

	for i in range(config.dash_cooldown_frames):
		var currently_dashing: bool = post_history[i].timers.get("dash_timer", 0) > 0
		var failure := Expect.is_false(currently_dashing, "pressing dash during cooldown frame %d should not start a new dash" % i)
		if failure != "":
			return failure

	var final_frames: Array[Dictionary] = [{"dash_pressed": true, "move_right": true}]
	var final_history := InputPlayback.run(state, config, final_frames, PlayerMovement.process)
	return Expect.is_true(final_history[0].timers.get("dash_timer", 0) > 0, "dash should be available again exactly dash_cooldown_frames after the previous one ended")

## Milestone 4 tuning iteration 2: this test used to assert the opposite
## (velocity.y arrested to 0 on cling entry - iteration 1's fix for the
## superjump bug). Iteration 2 went through two more attempts before this
## one: first preserving entry velocity outright (reopened the superjump -
## freezing a still-decelerating velocity for a fixed window adds height a
## naturally-decaying jump wouldn't have covered), then capping it
## (bounded the overshoot but didn't fix the actual mechanism). This is
## the mechanism-level fix: while attached and still rising, gravity
## behaves EXACTLY as it would off the wall - no freeze, no cap at all.
## Proved here by running the same starting velocity attached vs.
## unattached and requiring the two trajectories match frame-for-frame,
## not just "close enough".
func _test_wall_cling_no_freeze_while_rising() -> String:
	var config := _default_config()

	var attached_state := MovementState.new()
	attached_state.velocity = Vector2(0, -6.5)
	var attached_frames := InputPlayback.hold({"on_wall_left": true, "move_left": true}, 10)
	var attached_history := InputPlayback.run(attached_state, config, attached_frames, PlayerMovement.process)

	var free_state := MovementState.new()
	free_state.velocity = Vector2(0, -6.5)
	var free_frames := InputPlayback.hold({}, 10)
	var free_history := InputPlayback.run(free_state, config, free_frames, PlayerMovement.process)

	for i in range(10):
		var failure := Expect.approx(attached_history[i].velocity.y, free_history[i].velocity.y, "vy while still rising against a wall at frame %d should match the unattached case exactly, not be frozen or capped" % i)
		if failure != "":
			return failure
	return ""

## Milestone 4 tuning iteration 4: wall_contact now counts every attached
## frame from the moment attachment begins, including while still rising -
## the cling window is a total attachment-duration budget, not a fresh
## grant reset at the exact instant rising stops (see _apply_gravity).
## Grabbing a wall already very close to its natural apex (barely any
## attached-rising time to spend down the budget first) should still get
## a hold for whatever budget remains - shorter than a full
## wall_cling_frames window, not the full window every time.
func _test_wall_cling_holds_remaining_budget_near_apex() -> String:
	var config := _default_config()
	var state := MovementState.new()
	state.velocity = Vector2(0, -1.0)

	var frames := InputPlayback.hold({"on_wall_left": true, "move_left": true}, 30)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	var apex_frame := -1
	for i in range(history.size()):
		if history[i].velocity.y >= 0.0:
			apex_frame = i
			break
	var setup_failure := Expect.is_true(apex_frame >= 0, "test setup problem: player should have stopped rising within 30 frames")
	if setup_failure != "":
		return setup_failure

	var held_value: float = history[apex_frame].velocity.y
	var i := apex_frame
	while i < history.size() and history[i].timers.get("wall_contact", 0) <= config.wall_cling_frames:
		var failure := Expect.approx(history[i].velocity.y, held_value, "vy should stay held at %s while the attachment-duration cling budget hasn't run out (frame %d)" % [held_value, i])
		if failure != "":
			return failure
		i += 1
	var post_failure := Expect.is_true(i < history.size(), "test setup problem: cling budget should have run out within the 30-frame window")
	if post_failure != "":
		return post_failure
	return Expect.is_true(history[i].velocity.y > held_value, "vy should resume increasing once the remaining cling budget runs out")

## The bug this fixes: a jump touching a wall early in its ascent (well
## before its natural apex - the common case, e.g. climbing the wall-jump
## shaft) used to freeze at whatever near-zero vy it had right at the
## apex for the *entire* wall_cling_frames window, a jarring pause instead
## of a normal transition into falling. A full jump's worth of attached-
## rising time (~18 frames) comfortably exceeds wall_cling_frames (13), so
## the budget should already be spent by the time it naturally stops
## rising - gravity should resume immediately, not freeze.
func _test_wall_cling_no_pause_after_long_attached_ascent() -> String:
	var config := _default_config()
	var state := MovementState.new()
	state.velocity = Vector2(0, -6.5)

	var frames := InputPlayback.hold({"on_wall_left": true, "move_left": true}, 30)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	var apex_frame := -1
	for i in range(history.size()):
		if history[i].velocity.y >= 0.0:
			apex_frame = i
			break
	var setup_failure := Expect.is_true(apex_frame >= 0 and apex_frame + 1 < history.size(), "test setup problem: player should reach apex with room for one more frame within 30 frames")
	if setup_failure != "":
		return setup_failure

	return Expect.is_true(history[apex_frame + 1].velocity.y > history[apex_frame].velocity.y, "after a long attached ascent (cling budget already spent before apex), vy should keep changing normally right after apex, not freeze")

## Entry speeds under wall_cling_entry_speed_cap should pass through
## untouched - the cap only clips fast entries, it doesn't replace normal
## preservation.
func _test_wall_cling_preserves_slow_entry_uncapped() -> String:
	var config := _default_config()
	var state := MovementState.new()
	state.velocity = Vector2(0, 2.0)

	var frames := InputPlayback.hold({"on_wall_left": true, "move_left": true}, 3)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	return Expect.approx(history[0].velocity.y, 2.0, "vy under the entry speed cap should be preserved exactly, not clamped")

## Milestone 4 tuning iteration 1, bug 2: jumping from the ground while
## holding into a wall used to fling the player far above normal jump
## height. Investigated the suspected cause (jump buffer surviving the
## ground jump and re-firing a wall jump) and confirmed it wasn't that -
## _apply_jump already zeroes jump_buffer the same frame any jump fires.
## The real cause was the same bug as #1: wall cling preserved the jump's
## still-strongly-upward velocity.y for up to wall_cling_frames more frames
## instead of arresting it, which looked like a second, much bigger jump.
##
## Milestone 4 tuning iteration 2 went through preserve-outright (reopened
## this bug) and preserve-with-a-cap (bounded it but didn't fix the actual
## mechanism) before landing on the real fix: while still rising, gravity
## is never frozen at all (see _apply_gravity) - cling only catches you
## once you stop ascending. Since this player is still climbing when they
## first touch the wall, that means the whole ascent behaves exactly like
## an ordinary jump, so this asserts parity again (tight tolerance), not
## just a bounded overshoot. This test locks in the visible symptom (total
## rise) rather than the internal mechanism, against a real wall placed
## flush against the player one pixel away, so contact registers almost
## immediately after leaving the ground while still ascending fast.
func _test_ground_jump_into_wall_does_not_overshoot_height() -> String:
	var config := _default_config()

	var baseline_history := _run_jump(config, 40, -1)
	var baseline_peak := _peak_height(baseline_history)
	var baseline_rise: float = 0.0 - baseline_peak

	var floor_row := 10
	var wall_col := 2
	var solid_tiles: Dictionary = {}
	for col in range(-5, wall_col):
		solid_tiles[Vector2i(col, floor_row)] = true
	for row in range(floor_row - 15, floor_row):
		solid_tiles[Vector2i(wall_col, row)] = true

	var state := MovementState.new()
	# Right edge (x=32) flush against the wall's left face; collider
	# half-width 5, resting on the floor (bottom edge at floor_row*16=160).
	var start_y: float = float(floor_row * config.tile_size) - 8.0
	state.position = Vector2(27, start_y)

	var frames: Array[Dictionary] = [{"move_right": true, "jump_pressed": true, "on_floor": true}]
	for i in range(39):
		frames.append({"move_right": true, "jump_pressed": false})
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process, solid_tiles)

	var touched_wall := false
	for s in history:
		if s.on_wall_right:
			touched_wall = true
			break
	var setup_failure := Expect.is_true(touched_wall, "test setup problem: player never touched the wall while jumping toward it")
	if setup_failure != "":
		return setup_failure

	var peak: float = _peak_height(history)
	var rise: float = start_y - peak
	return Expect.is_true(rise <= baseline_rise + 2.0, "rise while jumping into a wall (%s) should not exceed an ordinary jump's rise (%s)" % [rise, baseline_rise])

## Milestone 4 tuning iteration 1, bug 4 (part 1): releasing "into the
## wall" used to drop cling attachment on the very next frame (on_wall_*
## only reads true while still actively moving into the wall - see
## TileCollision - so letting go reads as leaving the wall instantly).
## wall_detach_grace should keep the player attached for that many frames
## after release before gravity fully unattaches.
##
## Milestone 4 tuning iteration 4: wall_detach_grace (14) is now longer
## than wall_cling_frames (13), so "attached" and "clinging" (zero
## gravity) are no longer the same duration - the cling budget (see
## _apply_gravity) can run out before grace itself expires. So this now
## checks three phases instead of "held at 0 for the whole grace window":
## held at 0 while the cling budget lasts, capped at
## wall_slide_max_fall_speed for the rest of grace (still attached, just
## past the zero-gravity portion), then uncapped once grace fully expires.
##
## Milestone 4 tuning iteration 5: this specifically holds AWAY (not
## neutral) during release, since neutral no longer advances the detach
## countdown at all (see _test_wall_cling_persists_indefinitely_on_neutral
## below) - this test is about the finite countdown that still applies
## when the player is actually backing off.
func _test_wall_detach_grace_keeps_cling_attached() -> String:
	var config := _default_config()
	var state := MovementState.new()

	var frames: Array[Dictionary] = [
		{"on_wall_left": true, "move_left": true},
		{"on_wall_left": true, "move_left": true},
	]
	for i in range(config.wall_detach_grace):
		frames.append({"on_wall_left": false, "move_left": false, "move_right": true})

	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	var i := 0
	while i < history.size() and history[i].timers.get("wall_contact", 0) <= config.wall_cling_frames:
		var failure := Expect.approx(history[i].velocity.y, 0.0, "vy should stay held at 0 while the cling budget hasn't run out (frame %d)" % i)
		if failure != "":
			return failure
		i += 1

	var last_grace_index := 2 + config.wall_detach_grace - 1
	if last_grace_index < history.size() and last_grace_index >= i:
		var failure := Expect.is_true(history[last_grace_index].velocity.y <= config.wall_slide_max_fall_speed + 0.001, "vy while still within detach grace, past the cling budget, should stay capped at wall_slide_max_fall_speed")
		if failure != "":
			return failure

	var past_grace_frames: Array[Dictionary] = []
	for j in range(20):
		past_grace_frames.append({"on_wall_left": false, "move_left": false, "move_right": true})
	var post_history := InputPlayback.run(state, config, past_grace_frames, PlayerMovement.process)
	return Expect.is_true(post_history[-1].velocity.y > config.wall_slide_max_fall_speed + 0.001, "vy well after grace has fully expired (holding away the whole time) should exceed the wall-slide cap - no longer attached")

## Milestone 4 tuning iteration 5: neutral (no horizontal input at all)
## must NOT advance the detach countdown while genuinely still beside a
## wall - only actively pressing away (or actually leaving) does. Holds
## the wall, then goes fully neutral for far longer than wall_detach_grace
## would normally allow, and confirms the player is still attached
## (wall-slide-capped, not free-falling) indefinitely - matches the
## documented "no stamina meter" design intent.
##
## Milestone 4 regression fix (PROMPT.md, this session): this used to
## inject on_wall_left directly with no real wall geometry at all, which
## is exactly the setup that let the neutral-freeze regression through
## undetected - a synthetic "was touching once" flag froze wall_detach
## forever regardless of whether anything was actually still there.
## _update_wall_attachment now checks real proximity (TileCollision.
## is_touching_wall) before letting neutral freeze the countdown, so
## proving "cling persists indefinitely while genuinely at the wall" needs
## a real wall the player is actually still resting against, not just a
## flag pulsed once at the start.
func _test_wall_cling_persists_indefinitely_on_neutral() -> String:
	var config := _default_config()
	var wall_col := 0
	var solid_tiles: Dictionary = {}
	for row in range(-10, 40):
		solid_tiles[Vector2i(wall_col, row)] = true
	var state := MovementState.new()
	state.position = Vector2(30, 8)

	var attach_frames := InputPlayback.hold({"move_left": true}, 40)
	var neutral_frames := InputPlayback.hold({"move_left": false}, config.wall_detach_grace * 3)
	var frames: Array[Dictionary] = []
	frames.append_array(attach_frames)
	frames.append_array(neutral_frames)

	var history := InputPlayback.run(state, config, frames, PlayerMovement.process, solid_tiles)

	var touched_wall := false
	for i in range(attach_frames.size()):
		if history[i].on_wall_left:
			touched_wall = true
			break
	var setup_failure := Expect.is_true(touched_wall, "test setup problem: player never made real contact with the wall while pressing into it")
	if setup_failure != "":
		return setup_failure

	return Expect.is_true(history[-1].velocity.y <= config.wall_slide_max_fall_speed + 0.001, "vy should stay capped at wall_slide_max_fall_speed indefinitely under neutral input while still genuinely resting against a real wall, well beyond what wall_detach_grace alone would allow")

## Milestone 4 tuning iteration 1, bug 4 (part 2): a wall jump used to
## require actually touching the wall the exact frame jump is pressed.
## wall_coyote_time gives a grace window after contact is lost (mirrors
## ground coyote), keyed off last_wall_side to know which way is "away"
## once on_wall_* has already gone false.
##
## Milestone 4 tuning iteration 4: wall_detach_grace (14) is now longer
## than wall_coyote_time (6), and can_wall_jump also recognizes the
## detach-grace window directly (see _apply_jump) - so grace, not
## wall_coyote_time, is the binding constraint for how late a wall jump
## still fires. "Beyond" now means beyond grace.
func _test_wall_coyote_time_allows_late_wall_jump() -> String:
	var config := _default_config()

	var within := _run_wall_coyote_scenario(config, config.wall_coyote_time - 1)
	var failure := Expect.is_true(within < -1.0, "wall jump should still fire a bit under wall_coyote_time frames after losing wall contact")
	if failure != "":
		return failure

	var beyond := _run_wall_coyote_scenario(config, config.wall_detach_grace + 2)
	return Expect.is_true(beyond > -1.0, "wall jump should NOT fire well beyond wall_detach_grace frames after losing wall contact (the longer, now-binding window)")

## call index 0 = last frame actually touching the wall. call index
## (frames_after_losing_contact + 1) is where the press lands, mirroring
## _run_coyote_scenario's indexing for the ground coyote test. Holds AWAY
## (not neutral) after losing contact - milestone 4 tuning iteration 5
## made neutral no longer advance the detach countdown at all, so this
## needs genuine away-holding to test the countdown actually expiring.
func _run_wall_coyote_scenario(config: MovementConfig, frames_after_losing_contact: int) -> float:
	var state := MovementState.new()
	var press_at_call := frames_after_losing_contact + 1
	var total_frames := press_at_call + 3

	var base: Array[Dictionary] = [{"on_wall_left": true, "move_left": true}]
	for i in range(total_frames - 1):
		base.append({"on_wall_left": false, "move_left": false, "move_right": true})

	var jump_pulse := InputPlayback.pulse("jump_pressed", press_at_call, total_frames)
	var frames := InputPlayback.merge(base, jump_pulse)

	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)
	return history[press_at_call].velocity.y

## Milestone 4 tuning iteration 2, item 2: the detach grace window used to
## leave horizontal movement fully responsive, which felt like a "slow
## release" rather than a commitment window. During the grace, velocity.x
## should be pinned at 0 regardless of held input, then respond normally
## again the instant grace expires.
func _test_wall_detach_grace_locks_horizontal_movement() -> String:
	var config := _default_config()
	var state := MovementState.new()

	var frames: Array[Dictionary] = [{"on_wall_left": true, "move_left": true}]
	for i in range(config.wall_detach_grace):
		frames.append({"on_wall_left": false, "move_left": false, "move_right": true})

	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	for i in range(1, config.wall_detach_grace + 1):
		var failure := Expect.approx(history[i].velocity.x, 0.0, "vx during the detach grace window at frame %d should be pinned at 0 despite held opposing input" % i)
		if failure != "":
			return failure

	var past_grace: Array[Dictionary] = [{"on_wall_left": false, "move_left": false, "move_right": true}]
	var post_history := InputPlayback.run(state, config, past_grace, PlayerMovement.process)
	return Expect.is_true(post_history[0].velocity.x > 0.0, "vx one frame past the detach grace window should respond to held input again")

## Milestone 4 tuning iteration 4: a wall jump used to only remain
## available via wall_coyote_time (6 frames) after releasing the wall -
## now that wall_detach_grace (14) outlasts it, a jump pressed late in the
## grace window (past frame 6, still within 14) used to fall through to a
## double jump instead of firing a proper wall jump, silently burning a
## charge it shouldn't have touched. can_wall_jump now also recognizes the
## whole detach-grace window as wall-jump-eligible.
func _test_wall_jump_during_late_grace_does_not_burn_double_jump() -> String:
	var config := _default_config()
	var state := MovementState.new()
	state.double_jump_available = true

	var frames: Array[Dictionary] = [{"on_wall_left": true, "move_left": true}]
	for i in range(10):
		frames.append({"on_wall_left": false, "move_left": false, "move_right": true})
	frames.append({"on_wall_left": false, "move_right": true, "jump_pressed": true})

	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)
	var fire_frame := history.size() - 1

	var failure := Expect.approx(history[fire_frame].velocity.x, config.wall_jump_velocity.x, "pressing away during late detach grace should fire a strong (away-from-wall) wall jump")
	if failure != "":
		return failure
	failure = Expect.approx(history[fire_frame].velocity.y, config.wall_jump_velocity.y + config.gravity, "vy should match the strong wall jump's launch value (one frame of gravity already applied, same as any other wall jump)")
	if failure != "":
		return failure
	return Expect.is_true(history[fire_frame].double_jump_available, "double jump charge should NOT be consumed - this should fire as a wall jump, not a double jump")

## Milestone 4 tuning iteration 2, item 5: R (or falling below the kill
## plane, which the shell treats identically) should return the player to
## the level spawn point with velocity, timers, and ability charges all
## cleared - implemented as a pure MovementState operation so it's
## reachable from this harness rather than only from the node layer.
func _test_reset_clears_state_and_returns_to_spawn() -> String:
	var config := _default_config()
	var state := MovementState.new()
	state.position = Vector2(500, 300)
	state.velocity = Vector2(7.0, -6.5)
	state.double_jump_available = true
	state.dash_available = true
	state.facing = -1.0
	state.last_wall_side = -1.0
	state.timers["coyote"] = 4
	state.timers["dash_timer"] = 5
	state.reset_pressed = true

	var spawn := Vector2(0.0, 400.0)
	PlayerMovement.process(state, config, {}, spawn)

	var failure := Expect.approx(state.position.x, spawn.x, "position.x after reset should be at the spawn point")
	if failure != "":
		return failure
	failure = Expect.approx(state.position.y, spawn.y, "position.y after reset should be at the spawn point")
	if failure != "":
		return failure
	failure = Expect.approx(state.velocity.x, 0.0, "velocity.x after reset should be cleared")
	if failure != "":
		return failure
	failure = Expect.approx(state.velocity.y, 0.0, "velocity.y after reset should be cleared")
	if failure != "":
		return failure
	failure = Expect.is_false(state.double_jump_available, "double jump charge should be cleared by reset, not granted")
	if failure != "":
		return failure
	failure = Expect.is_false(state.dash_available, "dash charge should be cleared by reset, not granted")
	if failure != "":
		return failure
	return Expect.equal(state.timers.size(), 0, "all timers should be cleared by reset")

## Regression suite for the user's Group A/B bug report (PROMPT.md,
## milestone 4 tuning iteration 5 aftermath): the neutral-input detach
## freeze didn't check real proximity, so wall-slide fall cap and wall-jump
## eligibility could persist indefinitely after actually leaving a wall by
## any means, chaining unlimited height, only ending on active opposite
## input. Fixed in _update_wall_attachment (see its doc comment) via
## TileCollision.is_touching_wall. Per PROMPT.md's testing requirement,
## these run long input sequences and assert bounded outcomes rather than
## re-deriving the internal mechanism.

## Group A repro 1: wall jump fired while STILL holding "into" the wall,
## that same direction held briefly afterward (matching the repro - it's
## the immediate aftermath of the jump that floated forever), then neutral
## for the remainder so the player can't legitimately drift back into the
## same wall for real (turnaround acceleration would eventually walk it
## back into contact if "into" were held for the full test, which would
## make a second wall jump firing later legitimate rather than a bug).
## Mashes jump throughout the neutral phase (no real contact ever
## regained) and asserts vy never jumps back upward once safely past every
## wall-jump grace window - a rise there would mean a chained wall jump
## fired with no wall to fire it from, i.e. unlimited height.
func _test_wall_jump_toward_wall_cannot_chain_for_unlimited_height() -> String:
	var config := _default_config()
	var wall_col := 0
	var solid_tiles: Dictionary = {}
	for row in range(8, 60):
		solid_tiles[Vector2i(wall_col, row)] = true
	var state := MovementState.new()
	state.position = Vector2(30, 100)

	var approach: Array[Dictionary] = InputPlayback.hold({"move_left": true}, 40)
	var setup_history := InputPlayback.run(state, config, approach, PlayerMovement.process, solid_tiles)
	var attached := false
	for s in setup_history:
		if s.on_wall_left:
			attached = true
			break
	var setup_failure := Expect.is_true(attached, "test setup problem: player never made real contact with the wall")
	if setup_failure != "":
		return setup_failure

	var frames: Array[Dictionary] = [{"jump_pressed": true, "move_left": true}]
	for i in range(20):
		frames.append({"jump_pressed": false, "move_left": true})
	for i in range(100):
		frames.append({"jump_pressed": (i % 5 == 0), "move_left": false})
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process, solid_tiles)

	var safe_cutoff := config.wall_detach_grace + config.wall_coyote_time + 2
	for i in range(safe_cutoff, history.size() - 1):
		var failure := Expect.is_true(history[i + 1].velocity.y >= history[i].velocity.y - 0.001, "vy at frame %d should never jump back upward once well past every wall-jump grace window (was %s, became %s) - a rise here means a chained wall jump fired with no real wall contact" % [i, history[i].velocity.y, history[i + 1].velocity.y])
		if failure != "":
			return failure
	return ""

## Group A repro 2: wall jump fired with no directional input held at all,
## then nothing held afterward either. No real geometry needed here - the
## whole point is that after this frame there genuinely is no wall
## anywhere nearby, which is exactly what empty solid_tiles models.
func _test_wall_jump_neutral_state_ends_after_leaving_wall() -> String:
	var config := _default_config()
	var state := MovementState.new()

	var frames: Array[Dictionary] = [{"on_wall_left": true, "jump_pressed": true}]
	for i in range(60):
		frames.append({"on_wall_left": false, "jump_pressed": false})
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	return Expect.is_true(history[-1].velocity.y > config.wall_slide_max_fall_speed + 0.001, "vy well after a neutral wall jump with no real wall nearby should exceed the wall-slide cap - normal gravity should have resumed, not stayed floating")

## Group A repro 3: walk/slide off the bottom edge of a wall without ever
## jumping or pressing away - holds "into" the wall the entire test. Real
## geometry with a wall that ends partway down, so the player naturally
## falls clear of it while cling caps the descent rate.
func _test_wall_state_ends_when_walking_off_bottom_of_wall() -> String:
	var config := _default_config()
	var wall_col := 0
	var wall_bottom_row := 15
	var solid_tiles: Dictionary = {}
	for row in range(5, wall_bottom_row):
		solid_tiles[Vector2i(wall_col, row)] = true
	var state := MovementState.new()
	state.position = Vector2(19, float((wall_bottom_row - 1) * config.tile_size))

	var frames := InputPlayback.hold({"move_left": true}, 80)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process, solid_tiles)

	var setup_failure := Expect.is_true(history[0].on_wall_left, "test setup problem: player should start in real contact with the wall")
	if setup_failure != "":
		return setup_failure

	return Expect.is_true(history[-1].velocity.y > config.wall_slide_max_fall_speed + 0.001, "vy well after falling clear of the bottom of the wall (still holding into the whole time) should exceed the wall-slide cap - the floating state should end even without ever jumping or pressing away")

## Group B: transitioning out of a toward-wall wall jump (hold into, then
## correct to away) should carry momentum through with no freeze-then-snap
## - every frame-to-frame change in vx should stay within one frame's worth
## of (turnaround-boosted) acceleration or friction, never a sudden jump.
## This is also what proves the detach-grace hard-pin-to-zero fix in
## _apply_run actually closes the gap: a toward/neutral-fired wall jump now
## genuinely traverses that window (see _update_wall_attachment's fix)
## instead of being frozen out of it, so a real launch velocity meeting a
## hard pin would have produced exactly this kind of jump if left
## unfixed.
func _test_wall_jump_toward_wall_then_correcting_has_no_velocity_discontinuity() -> String:
	var config := _default_config()
	var wall_col := 0
	var solid_tiles: Dictionary = {}
	for row in range(8, 60):
		solid_tiles[Vector2i(wall_col, row)] = true
	var state := MovementState.new()
	state.position = Vector2(30, 100)

	var approach: Array[Dictionary] = InputPlayback.hold({"move_left": true}, 40)
	InputPlayback.run(state, config, approach, PlayerMovement.process, solid_tiles)

	var frames: Array[Dictionary] = [{"jump_pressed": true, "move_left": true}]
	for i in range(20):
		frames.append({"jump_pressed": false, "move_left": true})
	for i in range(40):
		frames.append({"move_left": false, "move_right": true})
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process, solid_tiles)

	var max_expected_delta: float = maxf(config.air_friction, config.air_acceleration * config.turnaround_multiplier) + 0.02

	for i in range(1, history.size() - 1):
		var delta := absf(history[i + 1].velocity.x - history[i].velocity.x)
		var failure := Expect.is_true(delta <= max_expected_delta, "vx should never change by more than one frame's worth of (turnaround-boosted) acceleration/friction at frame %d->%d (delta %s, max expected %s) - a bigger jump means a freeze-then-snap discontinuity" % [i, i + 1, delta, max_expected_delta])
		if failure != "":
			return failure
	return ""
