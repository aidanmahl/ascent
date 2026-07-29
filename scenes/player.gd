extends CharacterBody2D
class_name Player

@export var config: MovementConfig

var state: MovementState = MovementState.new()

## Solid tile data for the movement core's collision, provided by
## whatever owns the world (main.gd's placeholder geometry for now,
## the real level framework from milestone 7 on). Player doesn't build
## its own world - see CLAUDE.md's "thin shell" rule.
var solid_tiles: Dictionary = {}

## Set by main.gd (the level's current owner - there's no room system
## yet, so "reset" means level spawn point, not room start per PROMPT.md).
var spawn_point: Vector2 = Vector2.ZERO
## Falling below this Y triggers the same reset as pressing R. INF means
## no kill plane is configured (never triggers).
var kill_plane_y: float = INF

@onready var _double_jump_indicator: ColorRect = $DoubleJumpIndicator
@onready var _dash_indicator: ColorRect = $DashIndicator
@onready var _wall_cling_indicator: ColorRect = $WallClingIndicator

func _physics_process(_delta: float) -> void:
	state.move_left = Input.is_action_pressed("move_left")
	state.move_right = Input.is_action_pressed("move_right")
	state.look_up = Input.is_action_pressed("look_up")
	state.look_down = Input.is_action_pressed("look_down")
	state.jump_pressed = Input.is_action_just_pressed("jump")
	state.jump_released = Input.is_action_just_released("jump")
	state.dash_pressed = Input.is_action_just_pressed("dash")
	state.reset_pressed = Input.is_action_just_pressed("reset") or position.y > kill_plane_y
	state.position = position

	PlayerMovement.process(state, config, solid_tiles, spawn_point)

	position = state.position
	velocity = state.velocity

	# Placeholder ability indicators (PROMPT.md milestone 4 tuning
	# iteration 2, item 4) - purely a display mapping of state that's
	# already tested elsewhere, decoupled from movement logic and trivial
	# to remove once real art lands.
	_double_jump_indicator.visible = state.double_jump_available
	_dash_indicator.visible = state.dash_available
	_wall_cling_indicator.visible = state.wall_attached
