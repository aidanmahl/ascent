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
## any field the state object declares) then calls `step_fn(state, config)`.
## Returns one state snapshot per frame, oldest first.
static func run(state: MovementState, config: MovementConfig, frames: Array[Dictionary], step_fn: Callable) -> Array[MovementState]:
	var history: Array[MovementState] = []
	for frame_flags in frames:
		for key in frame_flags:
			state.set(key, frame_flags[key])
		step_fn.call(state, config)
		history.append(state.clone())
	return history
