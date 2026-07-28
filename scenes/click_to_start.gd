extends Control

## Browsers block audio until a user gesture (CLAUDE.md "Target platform").
## There's no audio yet, but the gate needs to exist before it does, so the
## first click here is what unlocks it later. Pauses the tree so nothing
## behind the overlay runs until that gesture happens.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		get_tree().paused = false
		get_parent().queue_free()
