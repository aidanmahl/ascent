class_name MovementState
extends RefCounted

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var move_left: bool = false
var move_right: bool = false
var timers: Dictionary = {}

func clone() -> MovementState:
	var copy := MovementState.new()
	copy.position = position
	copy.velocity = velocity
	copy.move_left = move_left
	copy.move_right = move_right
	copy.timers = timers.duplicate()
	return copy
