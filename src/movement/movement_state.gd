class_name MovementState
extends RefCounted

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO

## Input flags, set by the shell each frame from raw engine input.
var move_left: bool = false
var move_right: bool = false
## W/S - primarily camera look-offset (not yet implemented), also used
## for 8-way dash direction snapping per SPEC.md section 4.
var look_up: bool = false
var look_down: bool = false
## Just-pressed/just-released edges for this frame only (the shell derives
## these via Input.is_action_just_pressed/just_released so the core never
## needs to keep its own "was held last frame" bookkeeping).
var jump_pressed: bool = false
var jump_released: bool = false
var dash_pressed: bool = false
## Just-pressed edge for the reset action (R, or the shell synthesizing
## one when the player falls below the level's kill plane) - either way
## it's treated identically by PlayerMovement.process().
var reset_pressed: bool = false

## Collision flags, written by the movement core's collision resolution
## each frame. Also directly settable by tests to isolate jump/gravity
## logic from collision resolution (e.g. coyote-time tests don't need real
## tile geometry - they just need on_floor to go true -> false at a known
## frame).
var on_floor: bool = false
var on_ceiling: bool = false
var on_wall_left: bool = false
var on_wall_right: bool = false

## Ability charges: consumed on use, refilled on ground/wall contact.
var double_jump_available: bool = false
var dash_available: bool = false
## Direction locked in for the duration of the current dash.
var dash_direction: Vector2 = Vector2.ZERO
## Last nonzero horizontal input direction (+1/-1), used for a neutral-
## input dash's direction. Defaults to facing right.
var facing: float = 1.0

## Which wall was last actually touched (-1 = left, +1 = right). Needed
## because a wall jump can fire during wall_coyote_time after on_wall_*
## has already gone false - _fire_wall_jump still needs to know which
## direction is "away".
var last_wall_side: float = 0.0

var timers: Dictionary = {}

func clone() -> MovementState:
	var copy := MovementState.new()
	copy.position = position
	copy.velocity = velocity
	copy.move_left = move_left
	copy.move_right = move_right
	copy.look_up = look_up
	copy.look_down = look_down
	copy.jump_pressed = jump_pressed
	copy.jump_released = jump_released
	copy.dash_pressed = dash_pressed
	copy.reset_pressed = reset_pressed
	copy.on_floor = on_floor
	copy.on_ceiling = on_ceiling
	copy.on_wall_left = on_wall_left
	copy.on_wall_right = on_wall_right
	copy.double_jump_available = double_jump_available
	copy.dash_available = dash_available
	copy.dash_direction = dash_direction
	copy.facing = facing
	copy.last_wall_side = last_wall_side
	copy.timers = timers.duplicate()
	return copy
