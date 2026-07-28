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
	runner.register("corner_correction_small_clip_passes_through", _test_corner_correction_passes)
	runner.register("corner_correction_large_overlap_still_blocks", _test_corner_correction_blocks)
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
	runner.register("dash_exit_zeroes_upward_vertical_velocity", _test_dash_exit_zeroes_upward_vertical_velocity)
	runner.register("dash_cancels_on_wall_contact_and_refills", _test_dash_cancels_on_wall_contact_and_refills)
	runner.register("dash_cooldown_blocks_second_dash_for_exactly_6_frames", _test_dash_cooldown_blocks_second_dash)
	runner.register("wall_cling_zeroes_velocity_on_entry", _test_wall_cling_zeroes_velocity_on_entry)
	runner.register("ground_jump_into_wall_does_not_overshoot_height", _test_ground_jump_into_wall_does_not_overshoot_height)
	runner.register("wall_detach_grace_keeps_cling_attached", _test_wall_detach_grace_keeps_cling_attached)
	runner.register("wall_coyote_time_allows_late_wall_jump", _test_wall_coyote_time_allows_late_wall_jump)

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

## A single tile at column 1, row 0 sits just beside the player's straight-
## up path. The player's AABB pokes only 2px into that column - within
## corner_correction_px (4) - so it should nudge sideways and keep rising
## instead of getting blocked underneath the tile.
func _test_corner_correction_passes() -> String:
	var config := _default_config()
	var solid_tiles := {Vector2i(1, 0): true}
	var state := MovementState.new()
	state.position = Vector2(13, 24)  # right edge at 18: 2px into tile [16,32)
	state.velocity = Vector2(0, config.jump_velocity)

	var frames := InputPlayback.hold({}, 5)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process, solid_tiles)

	var failure := Expect.is_true(history[-1].position.y < 0.0, "player should have risen past y=0 after clipping the corner, got y=%s" % history[-1].position.y)
	if failure != "":
		return failure
	return Expect.is_false(history[0].on_ceiling, "first frame should not register as a ceiling hit (corner correction should have applied instead)")

## Same setup, but the player's AABB overlaps the blocking tile by 9px -
## beyond corner_correction_px (4) - so it must block normally rather than
## nudge through.
func _test_corner_correction_blocks() -> String:
	var config := _default_config()
	var solid_tiles := {Vector2i(1, 0): true}
	var state := MovementState.new()
	state.position = Vector2(20, 24)  # right edge at 25: 9px into tile [16,32)
	state.velocity = Vector2(0, config.jump_velocity)

	var frames := InputPlayback.hold({}, 1)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process, solid_tiles)

	return Expect.is_true(history[0].on_ceiling, "large overlap should block as a normal ceiling hit, not corner-correct")

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
	return _check_action_key("jump", KEY_SPACE)

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

	for i in range(1, 8):
		failure = Expect.approx(history[i].velocity.x, launched_vx, "vx during wall jump lockout at frame %d should stay locked at the launch value" % i)
		if failure != "":
			return failure

	return Expect.is_true(history[8].velocity.x < launched_vx, "vx at frame 8 (lockout expired) should respond to the held opposing input")

## Cling arrests whatever vertical speed you arrived with (bug fix -
## previously the "12 frames of zero gravity" reading only froze gravity's
## *accumulation*, silently preserving an initial 3.0 px/frame fall for
## the entire window instead of stopping it). velocity.y should snap to 0
## on the entry frame and stay there for wall_cling_frames (12) frames of
## contact; after that, gravity resumes but clamped to
## wall_slide_max_fall_speed.
func _test_wall_cling_then_slide() -> String:
	var config := _default_config()
	var state := MovementState.new()
	state.velocity = Vector2(0, 3.0)

	var frames := InputPlayback.hold({"on_wall_left": true, "move_left": true}, 30)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	for i in range(config.wall_cling_frames):
		var failure := Expect.approx(history[i].velocity.y, 0.0, "vy during wall cling at frame %d (arrested to 0, not the initial 3.0 fall speed)" % i)
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

func _test_dash_exit_zeroes_upward_vertical_velocity() -> String:
	var config := _default_config()
	var state := MovementState.new()
	state.dash_available = true

	var frames: Array[Dictionary] = [{"dash_pressed": true, "look_up": true}]
	for i in range(20):
		frames.append({})
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	var exit_frame := config.dash_duration_frames - 1
	return Expect.approx(history[exit_frame].velocity.y, 0.0, "vertical velocity right as an upward dash ends should be zeroed")

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

## Milestone 4 tuning iteration 1, bug 1: entering a wall cling used to only
## freeze gravity's *accumulation*, silently preserving whatever velocity.y
## the player arrived with (up or down) for the whole wall_cling_frames
## window. Seeds a strong upward velocity, injects wall contact, and checks
## it's arrested to 0 on the very frame contact starts (not just held at
## its prior value).
func _test_wall_cling_zeroes_velocity_on_entry() -> String:
	var config := _default_config()
	var state := MovementState.new()
	state.velocity = Vector2(0, -6.5)

	var frames := InputPlayback.hold({"on_wall_left": true, "move_left": true}, 3)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	return Expect.approx(history[0].velocity.y, 0.0, "vy on the first frame of wall contact should be arrested to 0, not left at the -6.5 it arrived with")

## Milestone 4 tuning iteration 1, bug 2: jumping from the ground while
## holding into a wall used to fling the player far above normal jump
## height. Investigated the suspected cause (jump buffer surviving the
## ground jump and re-firing a wall jump) and confirmed it wasn't that -
## _apply_jump already zeroes jump_buffer the same frame any jump fires.
## The real cause was the same bug as #1: wall cling preserved the jump's
## still-strongly-upward velocity.y for up to wall_cling_frames more frames
## instead of arresting it, which looked like a second, much bigger jump.
## Fixing #1 fixes this too - this test locks in the visible symptom
## (total rise) rather than the internal mechanism, against a real wall
## placed flush against the player one pixel away, so contact registers
## almost immediately after leaving the ground while still ascending fast.
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
## wall_detach_grace should keep the player attached (velocity.y held at
## 0, per the cling fix above) for that many frames after release, then
## let gravity resume on the frame after.
func _test_wall_detach_grace_keeps_cling_attached() -> String:
	var config := _default_config()
	var state := MovementState.new()

	var frames: Array[Dictionary] = [
		{"on_wall_left": true, "move_left": true},
		{"on_wall_left": true, "move_left": true},
	]
	for i in range(config.wall_detach_grace):
		frames.append({"on_wall_left": false, "move_left": false})

	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	var last_grace_frame := 2 + config.wall_detach_grace - 1
	var failure := Expect.approx(history[last_grace_frame].velocity.y, 0.0, "vy should still be held at 0 (attached) on the last frame of the detach grace window")
	if failure != "":
		return failure

	var past_grace_frames: Array[Dictionary] = [{"on_wall_left": false, "move_left": false}]
	var post_history := InputPlayback.run(state, config, past_grace_frames, PlayerMovement.process)
	return Expect.is_true(post_history[0].velocity.y > 0.0, "vy one frame past the detach grace window should resume falling")

## Milestone 4 tuning iteration 1, bug 4 (part 2): a wall jump used to
## require actually touching the wall the exact frame jump is pressed.
## wall_coyote_time gives a grace window after contact is lost (mirrors
## ground coyote), keyed off last_wall_side to know which way is "away"
## once on_wall_* has already gone false.
func _test_wall_coyote_time_allows_late_wall_jump() -> String:
	var config := _default_config()

	var within := _run_wall_coyote_scenario(config, config.wall_coyote_time - 1)
	var failure := Expect.is_true(within < -1.0, "wall jump should still fire a bit under wall_coyote_time frames after losing wall contact")
	if failure != "":
		return failure

	var beyond := _run_wall_coyote_scenario(config, config.wall_coyote_time + 2)
	return Expect.is_true(beyond > -1.0, "wall jump should NOT fire well beyond wall_coyote_time frames after losing wall contact")

## call index 0 = last frame actually touching the wall. call index
## (frames_after_losing_contact + 1) is where the press lands, mirroring
## _run_coyote_scenario's indexing for the ground coyote test.
func _run_wall_coyote_scenario(config: MovementConfig, frames_after_losing_contact: int) -> float:
	var state := MovementState.new()
	var press_at_call := frames_after_losing_contact + 1
	var total_frames := press_at_call + 3

	var base: Array[Dictionary] = [{"on_wall_left": true, "move_left": true}]
	for i in range(total_frames - 1):
		base.append({"on_wall_left": false, "move_left": false})

	var jump_pulse := InputPlayback.pulse("jump_pressed", press_at_call, total_frames)
	var frames := InputPlayback.merge(base, jump_pulse)

	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)
	return history[press_at_call].velocity.y
