class_name MovementConfig
extends Resource

## All values are in pixels and frames (60 physics ticks/sec), never
## seconds or meters, per CLAUDE.md. Starting values from SPEC.md section 4 -
## tuning knobs, not final numbers.

@export_group("Run")
@export var max_run_speed: float = 2.5
@export var ground_acceleration: float = 0.25
@export var ground_friction: float = 0.40
@export var air_acceleration: float = 0.18
@export var air_friction: float = 0.10
## Accel multiplier applied when input opposes current velocity.
@export var turnaround_multiplier: float = 1.8

@export_group("Gravity & Jump")
@export var gravity: float = 0.45
@export var max_fall_speed: float = 5.5
@export var jump_velocity: float = -6.5
## Velocity multiplier applied to an upward jump on early release.
@export var jump_cut_multiplier: float = 0.45
## Gravity multiplier applied while |vy| is below apex_hang_threshold.
@export var apex_hang_gravity_multiplier: float = 0.60
@export var apex_hang_threshold: float = 1.0
@export var coyote_frames: int = 6
@export var jump_buffer_frames: int = 8
## Max horizontal nudge (px) used to slip the player past a ledge corner
## instead of blocking a near-miss vertical collision.
@export var corner_correction_px: float = 4.0
@export var double_jump_velocity: float = -5.8

@export_group("Dash")
@export var dash_duration_frames: int = 12
@export var dash_speed: float = 7.0
## Frames after a dash ends before another can start, on top of needing
## dash_available (refilled separately by ground/wall contact).
@export var dash_cooldown_frames: int = 6
## Fraction of dash speed kept on the horizontal axis when a dash ends
## naturally (not cancelled by a wall). Vertical is zeroed instead if the
## dash was moving upward, per SPEC.md section 4.
@export var dash_exit_horizontal_retention: float = 0.6

@export_group("Wall")
@export var wall_slide_max_fall_speed: float = 1.5
## Frames of zero gravity when first pressing into a touched wall, before
## it settles into a slide capped at wall_slide_max_fall_speed.
@export var wall_cling_frames: int = 12
## Wall jump while holding away from the wall - the strong one (more
## distance). Sign is resolved at jump time from which wall is touched.
@export var wall_jump_velocity: Vector2 = Vector2(4.0, -6.0)
## Wall jump with no directional input held - more height, less distance.
@export var wall_jump_neutral_velocity: Vector2 = Vector2(3.0, -6.5)
## Frames after a wall jump during which horizontal input does not affect
## velocity.x, so the launch isn't immediately fought by held input.
@export var wall_jump_lockout_frames: int = 8

@export_group("Collider")
@export var collider_size: Vector2 = Vector2(10, 16)
@export var tile_size: int = 16
