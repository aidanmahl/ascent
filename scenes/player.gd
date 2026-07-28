extends CharacterBody2D
class_name Player

@export var config: MovementConfig

var state: MovementState = MovementState.new()

## Placeholder scaffolding only: the real room/level framework (TileMapLayer-
## backed) is milestone 7. This is just enough flat ground to stand and jump
## on for manual testing ahead of milestone 4's human tuning gate - not the
## real level system.
var _solid_tiles: Dictionary = {}

func _ready() -> void:
	_solid_tiles = _build_placeholder_floor()

func _physics_process(_delta: float) -> void:
	state.move_left = Input.is_action_pressed("move_left")
	state.move_right = Input.is_action_pressed("move_right")
	state.jump_pressed = Input.is_action_just_pressed("jump")
	state.jump_released = Input.is_action_just_released("jump")
	state.position = position

	PlayerMovement.process(state, config, _solid_tiles)

	position = state.position
	velocity = state.velocity

func _build_placeholder_floor() -> Dictionary:
	var tiles := {}
	var row := 10
	for col in range(-20, 20):
		tiles[Vector2i(col, row)] = true
	return tiles
