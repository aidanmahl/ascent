extends Node

func _ready() -> void:
	var ok := test_move_right_30_frames()
	if not ok:
		push_error("TESTS FAILED")
		get_tree().quit(1)
		return
	print("TESTS PASSED")
	get_tree().quit(0)

func test_move_right_30_frames() -> bool:
	var config: MovementConfig = load("res://src/movement/default_movement_config.tres")
	var state := MovementState.new()
	state.move_right = true

	for i in range(30):
		PlayerMovement.process(state, config)

	var expected_x: float = config.move_speed * 30.0
	var ok := is_equal_approx(state.position.x, expected_x)
	if not ok:
		push_error("move_right_30_frames: expected x=%s got x=%s" % [expected_x, state.position.x])
	return ok
