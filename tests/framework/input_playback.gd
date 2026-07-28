class_name InputPlayback

## Scripts a per-frame input timeline and steps a movement core across it,
## recording a state snapshot after every frame. This is what lets tests
## assert frame-exact behavior (coyote time, buffers, dash duration, ...)
## without touching the engine.

## Builds `frame_count` identical frames, each applying `flags`. Useful for
## "hold this input for N frames" scenarios; combine several calls (and
## `Array.append_array`) to script multi-phase input sequences.
static func hold(flags: Dictionary, frame_count: int) -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	for i in range(frame_count):
		frames.append(flags.duplicate())
	return frames

## Applies each frame's flags onto `state` (via Object.set, so it works for
## any field the state object declares) then calls
## `step_fn(state, config, solid_tiles)`. Returns one state snapshot per
## frame, oldest first.
##
## Flags not present in a given frame's dict keep whatever value they had
## on the previous frame - this matters for edge flags like jump_pressed,
## which callers must explicitly set back to false on the frames after a
## tap, or it reads as "held" forever.
static func run(state: MovementState, config: MovementConfig, frames: Array[Dictionary], step_fn: Callable, solid_tiles: Dictionary = {}) -> Array[MovementState]:
	var history: Array[MovementState] = []
	for frame_flags in frames:
		for key in frame_flags:
			state.set(key, frame_flags[key])
		step_fn.call(state, config, solid_tiles)
		history.append(state.clone())
	return history

## Builds `total_frames` frames where `flag_name` is true for exactly one
## frame (`at_frame`) and false everywhere else - a one-frame edge pulse,
## for jump_pressed/jump_released-style flags.
static func pulse(flag_name: String, at_frame: int, total_frames: int) -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	for i in range(total_frames):
		frames.append({flag_name: i == at_frame})
	return frames

## Merges two equal-length frame sequences index-wise (keys from `b`
## override `a` on collision per frame). Lets you combine an edge pulse
## with a held/one-off flag across the same timeline.
static func merge(a: Array[Dictionary], b: Array[Dictionary]) -> Array[Dictionary]:
	var merged: Array[Dictionary] = []
	for i in range(a.size()):
		var combined: Dictionary = a[i].duplicate()
		for key in b[i]:
			combined[key] = b[i][key]
		merged.append(combined)
	return merged
