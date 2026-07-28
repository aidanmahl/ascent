class_name PlayerMovement

## Pure per-frame step: reads state + config (+ solid tile geometry),
## decides jump/movement, and writes the result back onto state. No node
## lookups, no engine calls beyond TileCollision's own pure Vector2/
## Vector2i/Dictionary math.
##
## solid_tiles is a Dictionary[Vector2i, bool] of solid tile coordinates;
## pass {} for open-air scenarios (tests that only care about coyote/buffer/
## gravity, not collision).
static func process(state: MovementState, config: MovementConfig, solid_tiles: Dictionary = {}) -> void:
	_apply_jump(state, config)
	_apply_run(state, config)
	_apply_gravity(state, config)
	_resolve_collision(state, config, solid_tiles)

## Jump decision reads timers BEFORE this frame's refresh, so the exact
## frame counts in SPEC.md section 10 (coyote: succeeds at 5 frames after
## leaving ground, fails at 8; buffer: 6 frames before landing still fires)
## land on the boundary they describe rather than being off by one.
##
## `wants_jump` includes this frame's fresh jump_pressed directly (not just
## a buffer set from a *previous* frame's press) so pressing jump on the
## same frame you're grounded fires immediately instead of being delayed a
## frame through the buffer. And a jump that fires this frame forces both
## timers to 0 outright rather than letting the refresh below re-arm them -
## on_floor is still last frame's stale value here (collision resolution
## runs after this), so without that guard a grounded jump would refresh
## coyote to full on its own launch frame and hand out a free extra jump.
static func _apply_jump(state: MovementState, config: MovementConfig) -> void:
	var coyote: int = state.timers.get("coyote", 0)
	var jump_buffer: int = state.timers.get("jump_buffer", 0)

	var can_jump := state.on_floor or coyote > 0
	var wants_jump := state.jump_pressed or jump_buffer > 0
	var fires := can_jump and wants_jump

	if fires:
		state.velocity.y = config.jump_velocity

	if state.jump_released and state.velocity.y < 0.0:
		state.velocity.y *= config.jump_cut_multiplier

	if fires:
		coyote = 0
	elif state.on_floor:
		coyote = config.coyote_frames
	else:
		coyote = maxi(coyote - 1, 0)

	if fires:
		jump_buffer = 0
	elif state.jump_pressed:
		jump_buffer = config.jump_buffer_frames
	else:
		jump_buffer = maxi(jump_buffer - 1, 0)

	state.timers["coyote"] = coyote
	state.timers["jump_buffer"] = jump_buffer

static func _apply_run(state: MovementState, config: MovementConfig) -> void:
	var input_dir := 0.0
	if state.move_left:
		input_dir -= 1.0
	if state.move_right:
		input_dir += 1.0

	var accel := config.ground_acceleration if state.on_floor else config.air_acceleration
	var friction := config.ground_friction if state.on_floor else config.air_friction

	if input_dir != 0.0:
		var target_speed := input_dir * config.max_run_speed
		var opposing: bool = sign(state.velocity.x) != 0.0 and sign(state.velocity.x) != sign(input_dir)
		var rate := accel * (config.turnaround_multiplier if opposing else 1.0)
		state.velocity.x = move_toward(state.velocity.x, target_speed, rate)
	else:
		state.velocity.x = move_toward(state.velocity.x, 0.0, friction)

## Gravity always applies, even while grounded: a small unconditional
## downward nudge is what lets collision resolution re-detect on_floor
## every single frame at rest, rather than only on the frame contact
## first happens.
static func _apply_gravity(state: MovementState, config: MovementConfig) -> void:
	var g := config.gravity
	if absf(state.velocity.y) < config.apex_hang_threshold:
		g *= config.apex_hang_gravity_multiplier
	state.velocity.y = minf(state.velocity.y + g, config.max_fall_speed)

static func _resolve_collision(state: MovementState, config: MovementConfig, solid_tiles: Dictionary) -> void:
	var result := TileCollision.resolve(state.position, state.velocity, config.collider_size, solid_tiles, config.tile_size, config.corner_correction_px)
	state.position = result.position
	state.velocity = result.velocity
	state.on_floor = result.on_floor
	state.on_ceiling = result.on_ceiling
