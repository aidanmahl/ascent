extends CharacterBody2D
class_name Player

@export var config: MovementConfig

var state: MovementState = MovementState.new()

func _physics_process(_delta: float) -> void:
	state.move_left = Input.is_action_pressed("ui_left")
	state.move_right = Input.is_action_pressed("ui_right")
	state.position = position

	PlayerMovement.process(state, config)

	position = state.position
	velocity = state.velocity
