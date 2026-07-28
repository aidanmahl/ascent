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
	runner.register("move_right_30_frames_reaches_expected_x", _test_move_right_30_frames)
	runner.register("move_left_then_right_nets_correct_displacement", _test_move_left_then_right)
	runner.register("no_input_holds_position", _test_no_input_holds_position)

func _default_config() -> MovementConfig:
	return load("res://src/movement/default_movement_config.tres")

func _test_move_right_30_frames() -> String:
	var config := _default_config()
	var state := MovementState.new()
	var frames := InputPlayback.hold({"move_right": true}, 30)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	var expected_x: float = config.move_speed * 30.0
	return Expect.approx(history[-1].position.x, expected_x, "final x position")

func _test_move_left_then_right() -> String:
	var config := _default_config()
	var state := MovementState.new()

	var frames: Array[Dictionary] = InputPlayback.hold({"move_left": true, "move_right": false}, 10)
	frames.append_array(InputPlayback.hold({"move_left": false, "move_right": true}, 10))
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	var failure := Expect.approx(history[9].position.x, -config.move_speed * 10.0, "position after 10 frames left")
	if failure != "":
		return failure
	return Expect.approx(history[19].position.x, 0.0, "position after 10 frames left + 10 frames right")

func _test_no_input_holds_position() -> String:
	var config := _default_config()
	var state := MovementState.new()
	var frames := InputPlayback.hold({}, 15)
	var history := InputPlayback.run(state, config, frames, PlayerMovement.process)

	return Expect.approx(history[-1].position.x, 0.0, "position with no input held")
