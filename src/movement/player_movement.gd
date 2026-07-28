class_name PlayerMovement

static func process(state: MovementState, config: MovementConfig) -> void:
	var direction := 0.0
	if state.move_left:
		direction -= 1.0
	if state.move_right:
		direction += 1.0

	state.velocity = Vector2(direction * config.move_speed, 0.0)
	state.position += state.velocity
