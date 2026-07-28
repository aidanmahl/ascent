extends Node

## Headed (not --headless - there's no rendering server in that mode, so
## screenshots aren't possible there) visual-verification driver. Reads a
## JSON config describing a scene to load, a per-frame scripted input
## timeline (same frame-dict shape as tests/framework/input_playback.gd,
## but driving the real Input singleton instead of a MovementState), and
## which frames to screenshot. Always exits on its own - see the watchdog
## below - so it's safe to run through the same timeout+kill wrapper as
## every other godot_console invocation.

const CONFIG_PATH := "res://tools/capture/capture_config.json"
const WATCHDOG_SECONDS := 30.0

func _ready() -> void:
	_start_watchdog()
	await _run()
	get_tree().quit(0)

func _start_watchdog() -> void:
	var watchdog := Timer.new()
	watchdog.wait_time = WATCHDOG_SECONDS
	watchdog.one_shot = true
	watchdog.timeout.connect(func() -> void:
		printerr("WATCHDOG: capture did not finish in %ss, force-quitting" % WATCHDOG_SECONDS)
		get_tree().quit(1)
	)
	add_child(watchdog)
	watchdog.start()

func _run() -> void:
	var config := _load_config()
	if config.is_empty():
		printerr("capture_config.json missing or invalid at ", CONFIG_PATH)
		return

	var target: Node = load(config.scene).instantiate()
	add_child(target)
	await get_tree().process_frame
	await _dismiss_start_overlay()

	var frames: Array = config.get("frames", [])
	# JSON.parse_string returns every number as float, including the
	# capture_at frame indices - Array.has(int) against a float array
	# doesn't coerce, so without this cast every capture silently never
	# matches (found by tracing execution with debug prints: the frame
	# loop ran to completion but never once hit the capture branch).
	var capture_at: Array[int] = []
	for v in config.get("capture_at", []):
		capture_at.append(int(v))
	var output_dir: String = "res://" + String(config.get("output_dir", "tools/screenshots"))
	var prefix: String = config.get("prefix", "capture")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	for frame_index in range(frames.size()):
		var flags: Dictionary = frames[frame_index]
		for action in flags:
			if flags[action]:
				Input.action_press(action)
			else:
				Input.action_release(action)

		await get_tree().physics_frame

		if capture_at.has(frame_index):
			await get_tree().process_frame
			_capture(output_dir, prefix, frame_index)

## Scenes loaded here may include a click-to-start overlay (real browsers
## gate audio behind a user gesture - see CLAUDE.md "Target platform").
## Synthesize the same gesture a human tester would give so scripted
## captures still show gameplay instead of a permanently-visible overlay.
## Harmless no-op if the loaded scene has no such overlay.
func _dismiss_start_overlay() -> void:
	var viewport := get_viewport()
	var pos := viewport.get_visible_rect().size / 2.0
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	Input.parse_input_event(press)
	var release := press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame

func _capture(output_dir: String, prefix: String, frame_index: int) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s_%03d.png" % [output_dir, prefix, frame_index]
	var err := image.save_png(path)
	if err != OK:
		printerr("failed to save screenshot to ", path, " (error ", err, ")")
	else:
		print("saved ", path)

func _load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}
	var text := FileAccess.get_file_as_string(CONFIG_PATH)
	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		return {}
	return parsed
