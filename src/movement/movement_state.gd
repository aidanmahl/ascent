class_name MovementState
extends RefCounted

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO

## Input flags, set by the shell each frame from raw engine input.
var move_left: bool = false
var move_right: bool = false
## Just-pressed/just-released edges for this frame only (the shell derives
## these via Input.is_action_just_pressed/just_released so the core never
## needs to keep its own "was held last frame" bookkeeping).
var jump_pressed: bool = false
var jump_released: bool = false

## Collision flags, written by the movement core's collision resolution
## each frame. Also directly settable by tests to isolate jump/gravity
## logic from collision resolution (e.g. coyote-time tests don't need real
## tile geometry - they just need on_floor to go true -> false at a known
## frame).
var on_floor: bool = false
var on_ceiling: bool = false

var timers: Dictionary = {}

func clone() -> MovementState:
	var copy := MovementState.new()
	copy.position = position
	copy.velocity = velocity
	copy.move_left = move_left
	copy.move_right = move_right
	copy.jump_pressed = jump_pressed
	copy.jump_released = jump_released
	copy.on_floor = on_floor
	copy.on_ceiling = on_ceiling
	copy.timers = timers.duplicate()
	return copy
