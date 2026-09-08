extends CharacterBody2D
class_name Player

@export var config: MovementConfig
var state := MovementState.new()
var solid_tiles: Dictionary = {}
var spawn_point := Vector2(120, 472)
var kill_plane_y := 580.0
var gun_unlocked := false
var wall_unlocked := false
var max_ammo := 0
var flight_id := 0
var previous_position := Vector2.ZERO
var recoil_flash := 0.0
var kick_flash := 0.0
var dash_unlocked := false
var ammo := 0
const MAX_HEALTH := 3
var health := MAX_HEALTH
var invincible := 0.0
var shot_timer := 0.0
var aim := Vector2.RIGHT
var animation := 0.0
var flash := 0.0
var active := false
var mouse_aim := false
var last_mouse := Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not active:
		return
	previous_position = position
	animation += delta
	recoil_flash = maxf(0,recoil_flash-delta)
	kick_flash = maxf(0,kick_flash-delta)
	invincible = maxf(0, invincible - delta)
	shot_timer = maxf(0, shot_timer - delta)
	flash = maxf(0, flash - delta)
	state.move_left = Input.is_action_pressed("move_left")
	state.move_right = Input.is_action_pressed("move_right")
	state.look_up = Input.is_action_pressed("look_up")
	state.look_down = Input.is_action_pressed("look_down")
	state.jump_pressed = Input.is_action_just_pressed("jump")
	state.jump_released = Input.is_action_just_released("jump")
	state.dash_pressed = dash_unlocked and Input.is_action_just_pressed("dash")
	state.reset_pressed = false
	if Input.is_action_just_pressed("reset") or position.y > minf(kill_plane_y, spawn_point.y + 450):
		respawn()
	state.double_jump_available = false
	state.double_jump_enabled = false
	state.wall_jump_enabled = wall_unlocked
	state.ground_refill_only = true
	if not dash_unlocked:
		state.dash_available = false
	var grounded := state.on_floor
	var had_kick := state.wall_kick_available
	var previous_velocity := state.velocity
	state.position = position
	PlayerMovement.process(state, config, solid_tiles, spawn_point)
	position = state.position
	velocity = state.velocity
	if grounded and not state.on_floor:
		flight_id += 1
	if had_kick and not state.wall_kick_available:
		kick_flash = 0.18
		get_parent().burst(position,Color("d4b6ec"),8)
	if state.on_floor:
		ammo = max_ammo
	if not grounded and state.on_floor and previous_velocity.y > 2:
		get_parent().burst(position + Vector2(0, 8), Color("91b5a0"), 7)
	if state.jump_pressed and state.velocity.y < -3:
		get_parent().sound("jump")
	if state.dash_pressed and int(state.timers.get("dash_timer", 0)) == config.dash_duration_frames - 1:
		get_parent().sound("dash")
	if int(state.timers.get("dash_timer", 0)) > 0:
		get_parent().burst(position, Color("72ecd3"), 2)
	# Mouse aim is sampled in world space every frame. Previously the cached
	# mouse_aim flag could remain false after a keyboard look, leaving the
	# weapon locked vertically until the cursor moved again.
	var cursor_vector := get_global_mouse_position() - position
	if state.look_down:
		aim = Vector2.DOWN
	elif state.look_up:
		aim = Vector2.UP
	elif cursor_vector.length_squared() > 9.0:
		aim = cursor_vector.normalized()
	else:
		aim = Vector2(state.facing, 0)
	if gun_unlocked and (Input.is_action_pressed("fire") or Input.is_action_pressed("fire_key")):
		shoot()
	queue_redraw()

func shoot() -> void:
	if not gun_unlocked or shot_timer > 0 or ammo <= 0:
		return
	ammo -= 1
	shot_timer = 0.19
	flash = 0.075
	recoil_flash = 0.15
	# Recoil adds velocity without taking away air control.
	if not state.on_floor:
		apply_recoil(state,aim)
	get_parent().fire(position + aim * 10, aim, not state.on_floor, flight_id)
	get_parent().sound("shot")

func hurt(from: Vector2) -> void:
	if invincible > 0 or not active:
		return
	health -= 1
	invincible = 1.3
	state.velocity = Vector2(signf(position.x - from.x) * 3.5, -3.5)
	get_parent().shake = 4.0
	get_parent().burst(position, Color("ff9671"), 14)
	get_parent().sound("hurt")
	if health <= 0:
		respawn()

func respawn() -> void:
	PlayerMovement._reset(state, spawn_point)
	position = spawn_point
	health = MAX_HEALTH
	ammo = max_ammo
	invincible = 1.5
	get_parent().on_respawn()

func _draw() -> void:
	if invincible > 0 and int(invincible * 15) % 2 == 0:
		return
	if recoil_flash > 0:
		draw_arc(Vector2.ZERO,15*(1-recoil_flash/0.15)+6,aim.angle()-0.9,aim.angle()+0.9,8,Color("efd39a"),1)
	if kick_flash > 0:
		draw_arc(Vector2(0,6),10,-PI,0,8,Color("cea4e3"),1)
	var facing := state.facing
	if gun_unlocked:
		facing = -1.0 if aim.x < -0.1 else (1.0 if aim.x > 0.1 else facing)
	var step := sin(animation * 18) * 2 if state.on_floor and absf(state.velocity.x) > 0.3 else 0.0
	draw_rect(Rect2(-7 * facing - 2, -3, 4, 9), Color("536c80"))
	draw_rect(Rect2(-4, -3, 8, 9), Color("bdcbd1"))
	draw_rect(Rect2(-3, -2, 6, 6), Color("eef0d8"))
	draw_rect(Rect2(-5, -9, 10, 8), Color("6f8798"))
	draw_rect(Rect2(-4, -10, 8, 8), Color("e7eddf"))
	draw_rect(Rect2(-3 + facing, -8, 7, 4), Color("252e42"))
	draw_rect(Rect2(-2 + facing, -8, 5, 3), Color("e6aa55"))
	draw_rect(Rect2(-1 + facing, -8, 3, 1), Color("ffdf91"))
	draw_rect(Rect2(-3, 1, 6, 2), Color("d27853"))
	draw_rect(Rect2(-4, 5, 3, 3 + step), Color("e1e7d8"))
	draw_rect(Rect2(1, 5, 3, 3 - step), Color("e1e7d8"))
	draw_rect(Rect2(-4, 7 + step, 3, 2), Color("44556b"))
	draw_rect(Rect2(1, 7 - step, 3, 2), Color("44556b"))
	if wall_unlocked:
		draw_rect(Rect2(-5,6+step,4,3),Color("ab8cab"))
		draw_rect(Rect2(1,6-step,4,3),Color("ab8cab"))
		draw_rect(Rect2(-5,7+step,2,1),Color("ece0ed"))
	if dash_unlocked:
		var back := -7*facing
		draw_rect(Rect2(back-2,-4,4,11),Color("6b9ba3"))
		draw_rect(Rect2(back-1,-3,2,6),Color("99f3d3"))
		if int(state.timers.get("dash_timer",0)) > 0:
			draw_line(Vector2(back,6),Vector2(back-state.dash_direction.x*17,6-state.dash_direction.y*17),Color("baf6dc"),3)
	if gun_unlocked:
		# The magazine gains physical cells rather than only a HUD number.
		for cell in range(max_ammo):
			draw_rect(Rect2(-4+cell*3,2,2,3),Color("ebc27c") if cell < ammo else Color("4c5c65"))
		draw_line(aim * 3, aim * 12, Color("263444"), 5)
		draw_line(aim * 4 + Vector2(0, -1), aim * 11 + Vector2(0, -1), Color("9bb4b4"), 2)
		draw_circle(aim * 8, 1.5, Color("80f2d2"))
		if flash > 0:
			draw_circle(aim * 15, 4, Color("fff0ac"))

static func apply_recoil(movement: MovementState,direction: Vector2) -> void:
	movement.velocity -= direction * 3.3
	if direction.y > 0.45:
		movement.velocity.y = minf(movement.velocity.y, -4.35)
	movement.velocity.y = maxf(movement.velocity.y, -9.5)
