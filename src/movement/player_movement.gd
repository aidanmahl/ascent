class_name PlayerMovement

## Pure per-frame step: reads state + config (+ solid tile geometry),
## decides jump/movement, and writes the result back onto state. No node
## lookups, no engine calls beyond TileCollision's own pure Vector2/
## Vector2i/Dictionary math.
##
## solid_tiles is a Dictionary[Vector2i, bool] of solid tile coordinates;
## pass {} for open-air scenarios (tests that only care about coyote/buffer/
## gravity, not collision).
##
## A dash fully pre-empts jump/run/gravity for every frame it's active.
## SPEC.md only explicitly says gravity is 0 during a dash, but since dash
## also overrides velocity directly (not via acceleration) and nothing in
## SPEC.md describes jump-cancelling a dash, locking out all three for
## simplicity/predictability is a judgment call - flagged in STATUS.md.
static func process(state: MovementState, config: MovementConfig, solid_tiles: Dictionary = {}) -> void:
	var dashing := _apply_dash(state, config)
	if not dashing:
		_apply_jump(state, config)
		_apply_run(state, config)
		_apply_gravity(state, config)
	_resolve_collision(state, config, solid_tiles)
	_refill_abilities(state)

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
## on_floor/on_wall_* are still last frame's stale values here (collision
## resolution runs after this), so without that guard a grounded jump could
## refresh coyote to full on its own launch frame and hand out a free extra
## jump.
##
## Priority: ground > wall > double jump. can_wall_jump already requires
## not on_floor, and can_double_jump additionally requires not touching a
## wall, so at most one of the three fires per frame.
static func _apply_jump(state: MovementState, config: MovementConfig) -> void:
	var coyote: int = state.timers.get("coyote", 0)
	var jump_buffer: int = state.timers.get("jump_buffer", 0)

	var can_ground_jump := state.on_floor or coyote > 0
	var can_wall_jump := (state.on_wall_left or state.on_wall_right) and not state.on_floor
	var can_double_jump := (not state.on_floor) and (not can_wall_jump) and state.double_jump_available
	var wants_jump := state.jump_pressed or jump_buffer > 0

	var fires_ground := can_ground_jump and wants_jump
	var fires_wall := (not fires_ground) and can_wall_jump and wants_jump
	var fires_double := (not fires_ground) and (not fires_wall) and can_double_jump and wants_jump

	if fires_ground:
		state.velocity.y = config.jump_velocity
	elif fires_wall:
		_fire_wall_jump(state, config)
	elif fires_double:
		state.velocity.y = config.double_jump_velocity
		state.double_jump_available = false

	if state.jump_released and state.velocity.y < 0.0:
		state.velocity.y *= config.jump_cut_multiplier

	var fires := fires_ground or fires_wall or fires_double

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

	var wall_jump_lockout: int = state.timers.get("wall_jump_lockout", 0)
	if fires_wall:
		wall_jump_lockout = config.wall_jump_lockout_frames
	else:
		wall_jump_lockout = maxi(wall_jump_lockout - 1, 0)

	state.timers["coyote"] = coyote
	state.timers["jump_buffer"] = jump_buffer
	state.timers["wall_jump_lockout"] = wall_jump_lockout

## Away-from-wall (holding the opposite direction) is the strong jump;
## anything else - including holding back into the wall, which SPEC.md
## doesn't call out as its own case - falls back to the neutral one.
static func _fire_wall_jump(state: MovementState, config: MovementConfig) -> void:
	var away_dir: float
	var pressing_away: bool
	if state.on_wall_left:
		away_dir = 1.0
		pressing_away = state.move_right
	else:
		away_dir = -1.0
		pressing_away = state.move_left

	var launch := config.wall_jump_velocity if pressing_away else config.wall_jump_neutral_velocity
	state.velocity = Vector2(away_dir * launch.x, launch.y)

static func _apply_run(state: MovementState, config: MovementConfig) -> void:
	# The wall jump's imparted velocity.x is meant to carry through
	# un-fought for wall_jump_lockout_frames - this timer was already
	# refreshed by _apply_jump earlier this same frame.
	if state.timers.get("wall_jump_lockout", 0) > 0:
		return

	var input_dir := 0.0
	if state.move_left:
		input_dir -= 1.0
	if state.move_right:
		input_dir += 1.0

	var accel := config.ground_acceleration if state.on_floor else config.air_acceleration
	var friction := config.ground_friction if state.on_floor else config.air_friction

	if input_dir != 0.0:
		state.facing = input_dir
		var target_speed := input_dir * config.max_run_speed
		var opposing: bool = sign(state.velocity.x) != 0.0 and sign(state.velocity.x) != sign(input_dir)
		var rate := accel * (config.turnaround_multiplier if opposing else 1.0)
		state.velocity.x = move_toward(state.velocity.x, target_speed, rate)
	else:
		state.velocity.x = move_toward(state.velocity.x, 0.0, friction)

## Gravity always applies while not wall-clinging, even when grounded: a
## small unconditional downward nudge is what lets collision resolution
## re-detect on_floor every single frame at rest, rather than only on the
## frame contact first happens.
##
## wall_contact counts consecutive frames of actively pressing into a
## touched wall while airborne (reset to 0 the instant either condition
## isn't true, so letting go of the direction drops you immediately rather
## than lagging a frame). The first wall_cling_frames of contact are zero
## gravity per SPEC.md section 4 ("12 frames of zero gravity on first
## touch") - read literally, that only suspends gravity's acceleration, so
## whatever vertical speed you arrived with is preserved, not reset to
## zero. After that window, gravity resumes but clamped to
## wall_slide_max_fall_speed instead of the normal max_fall_speed.
static func _apply_gravity(state: MovementState, config: MovementConfig) -> void:
	var wall_active := _is_pressing_into_wall(state) and not state.on_floor
	var wall_contact: int = state.timers.get("wall_contact", 0)
	wall_contact = (wall_contact + 1) if wall_active else 0
	state.timers["wall_contact"] = wall_contact

	var clinging := wall_active and wall_contact <= config.wall_cling_frames
	if clinging:
		return

	var g := config.gravity
	if absf(state.velocity.y) < config.apex_hang_threshold:
		g *= config.apex_hang_gravity_multiplier
	var fall_cap := config.wall_slide_max_fall_speed if wall_active else config.max_fall_speed
	state.velocity.y = minf(state.velocity.y + g, fall_cap)

static func _is_pressing_into_wall(state: MovementState) -> bool:
	return (state.on_wall_left and state.move_left) or (state.on_wall_right and state.move_right)

## Returns true if a dash controlled this frame's velocity (start,
## continuing, or the frame it ends on), so process() knows to skip
## jump/run/gravity entirely for this frame.
##
## dash_cooldown gates a *new* dash and is checked before this frame's own
## decrement (same read-before-refresh reasoning as coyote/buffer), so it
## blocks for exactly dash_cooldown_frames after a dash ends, not one
## fewer. dash_available is a separate charge (refilled by _refill_abilities
## on ground/wall contact) - both must be satisfied to start a dash.
##
## `just_started` prevents the wall-cancel check from firing on the same
## frame a dash begins (you can legitimately dash away from a wall you're
## touching) and keeps duration at exactly dash_duration_frames regardless
## of whether the timer set on the start frame gets decremented that same
## frame or not - it does, uniformly, on every active frame including the
## first.
static func _apply_dash(state: MovementState, config: MovementConfig) -> bool:
	var dash_timer: int = state.timers.get("dash_timer", 0)
	var dash_cooldown: int = state.timers.get("dash_cooldown", 0)
	var just_started := false

	if dash_timer <= 0:
		var can_start := state.dash_pressed and state.dash_available and dash_cooldown <= 0
		if not can_start:
			state.timers["dash_timer"] = 0
			state.timers["dash_cooldown"] = maxi(dash_cooldown - 1, 0)
			return false

		state.dash_direction = _dash_direction(state)
		state.velocity = state.dash_direction * config.dash_speed
		state.dash_available = false
		dash_timer = config.dash_duration_frames
		just_started = true

	dash_timer -= 1

	var cancelled_by_wall := (not just_started) and (state.on_wall_left or state.on_wall_right)
	var ending := cancelled_by_wall or dash_timer <= 0

	if ending:
		if cancelled_by_wall:
			state.dash_available = true
		else:
			state.velocity.x *= config.dash_exit_horizontal_retention
			if state.velocity.y < 0.0:
				state.velocity.y = 0.0
		dash_timer = 0
		dash_cooldown = config.dash_cooldown_frames

	state.timers["dash_timer"] = dash_timer
	state.timers["dash_cooldown"] = dash_cooldown
	return true

## 8-way snap from held move/look directions; neutral input dashes in the
## current facing direction instead.
static func _dash_direction(state: MovementState) -> Vector2:
	var dir := Vector2.ZERO
	if state.move_left:
		dir.x -= 1.0
	if state.move_right:
		dir.x += 1.0
	if state.look_up:
		dir.y -= 1.0
	if state.look_down:
		dir.y += 1.0
	if dir == Vector2.ZERO:
		dir.x = state.facing
	return dir.normalized()

## Double jump and dash both refill on ground OR wall contact per SPEC.md
## section 4, using this frame's freshly-resolved collision flags (unlike
## the jump/gravity reads above, which intentionally use last frame's
## stale values - this runs after _resolve_collision, so there's no
## staleness here).
static func _refill_abilities(state: MovementState) -> void:
	if state.on_floor or state.on_wall_left or state.on_wall_right:
		state.double_jump_available = true
		state.dash_available = true

static func _resolve_collision(state: MovementState, config: MovementConfig, solid_tiles: Dictionary) -> void:
	var result := TileCollision.resolve(state.position, state.velocity, config.collider_size, solid_tiles, config.tile_size, config.corner_correction_px)
	state.position = result.position
	state.velocity = result.velocity
	state.on_floor = result.on_floor
	state.on_ceiling = result.on_ceiling
	state.on_wall_left = result.on_wall_left
	state.on_wall_right = result.on_wall_right
