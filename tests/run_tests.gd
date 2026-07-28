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
