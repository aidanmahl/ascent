extends SceneTree

const CONFIG := preload("res://src/movement/expedition_config.tres")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("Movement envelope from live expedition_config.tres")
	_measure_jump_series()
	_measure_wall_jump()
	for label in ["horizontal", "diagonal_up", "vertical_up"]:
		_measure_dash(label)
		_measure_jump_dash(label)
	_measure_recoil_dash(2)
	_measure_recoil_dash(3)
	quit()

func _fresh() -> MovementState:
	var state := MovementState.new()
	state.position = Vector2.ZERO
	state.on_floor = true
	state.double_jump_enabled = false
	state.ground_refill_only = true
	return state

func _measure_jump_series() -> void:
	for shot_count in range(4):
		var state := _fresh()
		var peak := 0.0
		var peak_x := 0.0
		var airborne := false
		for frame in range(240):
			state.move_right = true
			state.jump_pressed = frame == 0
			PlayerMovement.process(state, CONFIG, {})
			if frame > 0:
				airborne = true
			if airborne and frame in [8, 20, 32].slice(0, shot_count):
				Player.apply_recoil(state, Vector2.DOWN)
			peak = minf(peak, state.position.y)
			peak_x = maxf(peak_x, state.position.x)
			if airborne and state.position.y >= 0.0 and state.velocity.y > 0.0:
				break
		print("jump + %d shot(s): height %.1f px, air range %.1f px" % [shot_count, -peak, peak_x])

func _measure_wall_jump() -> void:
	var state := _fresh()
	state.on_floor = false
	state.wall_jump_enabled = true
	state.wall_kick_available = true
	state.on_wall_right = true
	state.last_wall_side = 1.0
	state.move_left = true
	state.jump_pressed = true
	var start := state.position
	var peak := 0.0
	var range_x := 0.0
	for frame in range(180):
		PlayerMovement.process(state, CONFIG, {})
		peak = minf(peak, state.position.y - start.y)
		range_x = maxf(range_x, absf(state.position.x - start.x))
		state.jump_pressed = false
		if frame > 0 and state.position.y >= start.y and state.velocity.y > 0.0:
			break
	print("wall kick: height %.1f px, air range %.1f px" % [-peak, range_x])

func _measure_dash(label: String) -> void:
	var state := _fresh()
	state.on_floor = false
	state.dash_available = true
	state.dash_pressed = true
	match label:
		"horizontal": state.move_right = true
		"diagonal_up":
			state.move_right = true
			state.look_up = true
		"vertical_up": state.look_up = true
	var start := state.position
	var peak := 0.0
	var range_x := 0.0
	for frame in range(120):
		PlayerMovement.process(state, CONFIG, {})
		peak = minf(peak, state.position.y - start.y)
		range_x = maxf(range_x, absf(state.position.x - start.x))
		state.dash_pressed = false
		if frame > 10 and state.position.y >= start.y and state.velocity.y > 0.0:
			break
	print("%s dash: height %.1f px, air range %.1f px" % [label, -peak, range_x])

func _measure_jump_dash(label: String) -> void:
	var state := _fresh()
	state.dash_available = true
	var start := state.position
	var peak := 0.0
	var range_x := 0.0
	for frame in range(180):
		state.jump_pressed = frame == 0
		state.dash_pressed = frame == 10
		state.move_right = label != "vertical_up"
		state.look_up = label != "horizontal" and frame >= 10
		PlayerMovement.process(state, CONFIG, {})
		peak = minf(peak, state.position.y - start.y)
		range_x = maxf(range_x, absf(state.position.x - start.x))
		if frame > 10 and state.position.y >= start.y and state.velocity.y > 0.0:
			break
	print("jump + %s dash: height %.1f px, air range %.1f px" % [label, -peak, range_x])

func _measure_recoil_dash(shot_count: int) -> void:
	var state := _fresh()
	state.dash_available = true
	var peak := 0.0
	var range_x := 0.0
	for frame in range(240):
		state.jump_pressed = frame == 0
		state.move_right = true
		state.look_up = frame >= 38
		state.dash_pressed = frame == 38
		PlayerMovement.process(state, CONFIG, {})
		if frame in [8, 20, 32].slice(0, shot_count):
			Player.apply_recoil(state, Vector2.DOWN)
		peak = minf(peak, state.position.y)
		range_x = maxf(range_x, state.position.x)
		if frame > 40 and state.position.y >= 0.0 and state.velocity.y > 0.0:
			break
	print("jump + %d shots + diagonal dash: height %.1f px, air range %.1f px" % [shot_count, -peak, range_x])
