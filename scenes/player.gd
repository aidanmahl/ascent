extends CharacterBody2D
class_name Player

@export var config: MovementConfig

var state: MovementState = MovementState.new()

## Solid tile data for the movement core's collision, provided by
## whatever owns the world (main.gd's placeholder geometry for now,
## the real level framework from milestone 7 on). Player doesn't build
## its own world - see CLAUDE.md's "thin shell" rule.
var solid_tiles: Dictionary = {}

func _physics_process(_delta: float) -> void:
	state.move_left = Input.is_action_pressed("move_left")
	state.move_right = Input.is_action_pressed("move_right")
	state.look_up = Input.is_action_pressed("look_up")
	state.look_down = Input.is_action_pressed("look_down")
	state.jump_pressed = Input.is_action_just_pressed("jump")
	state.jump_released = Input.is_action_just_released("jump")
	state.dash_pressed = Input.is_action_just_pressed("dash")
	state.position = position

	PlayerMovement.process(state, config, solid_tiles)

	position = state.position
	velocity = state.velocity
